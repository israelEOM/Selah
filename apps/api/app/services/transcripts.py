import re
from app.services.youtube import fetch_transcript

def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"\[.*?\]", "", text)).strip()

def within_interval(segments: list[dict], start: int, end: int | None) -> list[dict]:
    final = float("inf") if end is None else end
    return [s for s in segments if s["start"] + s.get("duration", 0) >= start and s["start"] <= final]

def parse_manual(text: str, fmt: str) -> list[dict]:
    if fmt.lower() == "txt": return [{"text": normalize(text), "start": None, "duration": None}]
    blocks = re.split(r"\n\s*\n", text.strip()); segments=[]
    for i, block in enumerate(blocks):
        lines = [line.strip() for line in block.splitlines() if line.strip()]
        timing = next((line for line in lines if "-->" in line), None)
        body = " ".join(line for line in lines if line != timing and not line.isdigit())
        start = None
        if timing:
            raw = timing.split("-->")[0].replace(",", ".").strip(); parts=raw.split(":")
            try: start = int(parts[0])*3600 + int(parts[1])*60 + float(parts[2])
            except (ValueError, IndexError): pass
        if body: segments.append({"text": normalize(body), "start": start, "duration": None})
    return segments
