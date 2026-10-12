import re


def normalize(text: str) -> str:
    """Drops caption cues like [Música] and collapses whitespace."""
    return re.sub(r"\s+", " ", re.sub(r"\[.*?\]", "", text)).strip()


def within_interval(segments: list[dict], start: float, end: float | None) -> list[dict]:
    """Keeps segments that overlap [start, end]. Segments without a start time are kept."""
    final = float("inf") if end is None else end
    return [
        s for s in segments
        if s["start"] is None or (s["start"] + (s.get("duration") or 0) >= start and s["start"] <= final)
    ]


def parse_manual(text: str, fmt: str) -> list[dict]:
    """Parses pasted TXT, SRT or VTT. TXT has no timings, so timestamp links are unavailable for it."""
    if fmt.lower() == "txt":
        return [{"text": normalize(text), "start": None, "duration": None}]
    segments = []
    for block in re.split(r"\n\s*\n", text.strip()):
        lines = [line.strip() for line in block.splitlines() if line.strip()]
        timing = next((line for line in lines if "-->" in line), None)
        body = " ".join(line for line in lines if line != timing and not line.isdigit() and line != "WEBVTT")
        start = None
        if timing:
            parts = timing.split("-->")[0].replace(",", ".").strip().split(":")
            try:
                seconds = [float(p) for p in parts]
                start = sum(value * 60 ** i for i, value in enumerate(reversed(seconds)))
            except ValueError:
                pass
        if body:
            segments.append({"text": normalize(body), "start": start, "duration": None})
    return segments


def build_windows(segments: list[dict], seconds: float = 30.0) -> list[dict]:
    """Merges caption segments into windows of about `seconds`.

    The model cites window numbers instead of writing timestamps, so every
    timestamp shown to members comes from the captions themselves.
    """
    windows: list[dict] = []
    current: dict | None = None
    for segment in segments:
        text = normalize(segment["text"])
        if not text:
            continue
        start = segment["start"]
        if current is None or (start is not None and current["start"] is not None and start - current["start"] >= seconds):
            current = {"index": len(windows), "start": start, "text": text}
            windows.append(current)
        else:
            current["text"] += " " + text
    return windows


def clock(seconds: float | None) -> str:
    if seconds is None:
        return "--:--:--"
    total = int(seconds)
    return f"{total // 3600:02d}:{total % 3600 // 60:02d}:{total % 60:02d}"


def render_windows(windows: list[dict]) -> str:
    return "\n".join(f"[#{w['index']} {clock(w['start'])}] {w['text']}" for w in windows)
