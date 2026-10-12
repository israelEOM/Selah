"""Pipeline steps. Each takes a job row and returns the result stored on the job."""
import re
from datetime import datetime, timezone

from selah_worker import ai, youtube
from selah_worker.bible import parse_reference
from selah_worker.db import client
from selah_worker.grounding import fold, locate, window_end, window_start
from selah_worker.transcripts import build_windows, normalize, parse_manual, render_windows, within_interval


def _one(table: str, column: str, value: str, what: str) -> dict:
    rows = client().table(table).select("*").eq(column, value).limit(1).execute().data
    if not rows:
        raise RuntimeError(what)
    return rows[0]


def _windows(sermon_id: str) -> list[dict]:
    transcript = _one("transcripts", "sermon_id", sermon_id, "Primero obtén la transcripción del sermón.")
    return build_windows(transcript["segments"])


def _usage(metrics: dict) -> dict:
    return {k: metrics[k] for k in ("model", "prompt_version", "input_tokens", "output_tokens")}


def slugify(title: str) -> str:
    return re.sub(r"-+", "-", fold(title).replace("ñ", "n").replace(" ", "-")).strip("-")[:80] or "estudio"


def _unique_slug(title: str) -> str:
    base, slug, n = slugify(title), slugify(title), 1
    while client().table("studies").select("id").eq("slug", slug).execute().data:
        n += 1
        slug = f"{base}-{n}"
    return slug


def _label(reference: str, language: str) -> str:
    parsed = parse_reference(reference, language)
    return parsed["reference"] if parsed else reference


# Steps ------------------------------------------------------------------------

def probe(job: dict) -> dict:
    """Video data and the caption languages that really exist, for the import form."""
    data = youtube.metadata(job["payload"]["url"])
    return data | {"languages": youtube.transcript_languages(data["youtube_video_id"])}


def transcript(job: dict) -> dict:
    sermon = _one("sermons", "id", job["sermon_id"], "Sermón no encontrado.")
    payload = job["payload"]
    if payload.get("manual_text"):
        segments = parse_manual(payload["manual_text"], payload.get("format", "txt"))
        source, auto, language = "manual", False, payload.get("language", sermon["original_language"])
    else:
        language = payload.get("language_code", sermon["original_language"])
        segments, auto = youtube.fetch_transcript(sermon["youtube_video_id"], language)
        source = "youtube"
    segments = within_interval(segments, sermon["start_seconds"], sermon["end_seconds"])
    segments = [s | {"text": normalize(s["text"])} for s in segments if normalize(s["text"])]
    if not segments:
        raise RuntimeError("La transcripción está vacía en el intervalo seleccionado.")
    raw_text = " ".join(s["text"] for s in segments)
    client().table("transcripts").upsert({
        "sermon_id": sermon["id"], "language": language, "source": source,
        "is_auto_generated": auto, "segments": segments, "raw_text": raw_text,
    }, on_conflict="sermon_id").execute()
    return {"segments": len(segments), "words": len(raw_text.split()), "is_auto_generated": auto,
            "has_timestamps": segments[0]["start"] is not None}


def analysis(job: dict) -> dict:
    sermon = _one("sermons", "id", job["sermon_id"], "Sermón no encontrado.")
    windows = _windows(sermon["id"])
    language = sermon["original_language"]
    output, metrics = ai.analyze(render_windows(windows), language, sermon["title"], sermon["channel"])
    content = output.model_dump()

    for point in content["points"]:
        point["start_seconds"] = window_start(windows, point.pop("start_window"))
        point["end_seconds"] = window_end(windows, point.pop("end_window"))
        point["references"] = [_label(r, language) for r in point["references"]]
    content["sermon_start_seconds"] = window_start(windows, content.pop("sermon_start_window"))
    content["sermon_end_seconds"] = window_end(windows, content.pop("sermon_end_window"))
    if content["main_passage"]:
        content["main_passage"] = _label(content["main_passage"], language)

    # Quotes that are not in the transcript are dropped, never shown.
    quotes = []
    for quote in content["quotes"]:
        found = locate(quote["text"], windows, quote["window"])
        if found is not None:
            quotes.append({"text": quote["text"], "start_seconds": window_start(windows, found)})
    dropped_quotes = len(content["quotes"]) - len(quotes)
    content["quotes"] = quotes

    rows, seen, rejected = [], set(), []
    for ref in content.pop("references"):
        parsed = parse_reference(ref["reference"], language)
        if not parsed:
            rejected.append(ref["reference"])
            continue
        key = (parsed["book"], parsed["chapter"], parsed["verse_start"], parsed["verse_end"])
        if key in seen:
            continue
        seen.add(key)
        found = locate(ref["excerpt"], windows, ref["window"], threshold=0.7)
        classification = ref["classification"] if found is not None else "possible"
        index = found if found is not None else ref["window"]
        at = window_start(windows, index)
        begins, ends = content["sermon_start_seconds"], content["sermon_end_seconds"]
        if at is not None and ((begins is not None and at < begins) or (ends is not None and at > ends)):
            continue  # read during the service, not part of the sermon
        rows.append(parsed | {
            "sermon_id": sermon["id"], "classification": classification, "confidence": ref["confidence"],
            "start_seconds": at, "transcript_excerpt": ref["excerpt"],
            # Possible references stay hidden from members until an admin approves them.
            "approved": classification != "possible", "position": len(rows),
        })

    db = client()
    db.table("sermon_analyses").upsert({
        "sermon_id": sermon["id"], "content": content, "model": metrics["model"],
        "prompt_version": metrics["prompt_version"], "input_tokens": metrics["input_tokens"],
        "output_tokens": metrics["output_tokens"], "created_at": datetime.now(timezone.utc).isoformat(),
    }, on_conflict="sermon_id").execute()
    db.table("bible_references").delete().eq("sermon_id", sermon["id"]).execute()
    if rows:
        db.table("bible_references").insert(rows).execute()
    if content["preacher"] and not sermon["preacher"]:
        db.table("sermons").update({"preacher": content["preacher"]}).eq("id", sermon["id"]).execute()
    return _usage(metrics) | {"points": len(content["points"]), "references": len(rows),
                              "rejected_references": rejected, "dropped_quotes": dropped_quotes}


def summary(job: dict) -> dict:
    sermon = _one("sermons", "id", job["sermon_id"], "Sermón no encontrado.")
    stored = _one("sermon_analyses", "sermon_id", sermon["id"], "Primero analiza el sermón.")["content"]
    payload = job["payload"]
    language = payload.get("output_language", "es")
    output, metrics = ai.summarize(stored, language)
    content = output.model_dump()
    for point in content["points"]:
        index = point.pop("point_index")
        source = stored["points"][index] if 0 <= index < len(stored["points"]) else {}
        point["start_seconds"] = source.get("start_seconds")
        point["references"] = [_label(r, language) for r in point["references"]]
    content["main_passage"] = _label(stored["main_passage"], language) if stored["main_passage"] else None
    content["quotes"] = stored["quotes"]

    db = client()
    title = content.pop("title")
    fields = {
        "output_language": language, "central_message": content.pop("central_message"), "summary": content,
        "bible_version_code": payload.get("bible_version_code", "RVR1960"), "status": "generating",
    }
    existing = db.table("studies").select("id").eq("sermon_id", sermon["id"]).execute().data
    if existing:
        db.table("studies").update(fields).eq("id", existing[0]["id"]).execute()
    else:
        db.table("studies").insert(fields | {
            "sermon_id": sermon["id"], "title": title, "slug": _unique_slug(title),
            "number_of_days": payload.get("number_of_days", 5),
        }).execute()
    return _usage(metrics) | {"points": len(content["points"])}


def devotional(job: dict) -> dict:
    sermon = _one("sermons", "id", job["sermon_id"], "Sermón no encontrado.")
    stored = _one("sermon_analyses", "sermon_id", sermon["id"], "Primero analiza el sermón.")["content"]
    study = _one("studies", "sermon_id", sermon["id"], "Primero genera el resumen.")
    days = int(job["payload"].get("days", study["number_of_days"]))
    if days not in (1, 3, 5, 7):
        raise RuntimeError("El devocional debe tener 1, 3, 5 o 7 días.")
    windows = _windows(sermon["id"])
    start, end = stored.get("sermon_start_seconds"), stored.get("sermon_end_seconds")
    preached = [w for w in windows if w["start"] is None
                or ((start is None or w["start"] >= start) and (end is None or w["start"] <= end))]
    output, metrics = ai.devotional(stored, render_windows(preached or windows), days, study["output_language"])
    if sorted(d.day_number for d in output.days) != list(range(1, days + 1)):
        raise RuntimeError("La IA no devolvió todos los días solicitados. Inténtalo de nuevo.")
    rows = [{
        "study_id": study["id"], "day_number": d.day_number, "title": d.title,
        "bible_reading": _label(d.bible_reading, study["output_language"]), "main_idea": d.main_idea,
        "reflection": d.reflection, "application": d.application, "questions": d.questions, "prayer": d.prayer,
        "start_seconds": window_start(windows, d.start_window), "end_seconds": window_end(windows, d.end_window),
    } for d in output.days]
    db = client()
    db.table("devotional_days").delete().eq("study_id", study["id"]).execute()
    db.table("devotional_days").insert(rows).execute()
    # Regenerated content always goes back to review; publishing is an explicit admin action.
    db.table("studies").update({"number_of_days": days, "status": "review", "published_at": None}).eq("id", study["id"]).execute()
    return _usage(metrics) | {"days": days}


HANDLERS = {"probe": probe, "transcript": transcript, "analysis": analysis, "summary": summary, "devotional": devotional}


def run_all(url: str, language: str = "es", output_language: str = "es", days: int = 5,
            start: int = 0, end: int | None = None) -> str:
    """Runs every step for one URL without the job queue. Used from the command line."""
    db = client()
    found = probe({"payload": {"url": url}})
    codes = [l["language_code"] for l in found.pop("languages")]
    code = next((c for c in codes if c == language or c.startswith(language + "-")), None)
    if not code:
        raise RuntimeError(f"No hay subtítulos en '{language}'. Disponibles: {', '.join(codes)}")
    sermon = db.table("sermons").upsert(
        found | {"original_language": language, "start_seconds": start, "end_seconds": end},
        on_conflict="youtube_video_id").execute().data[0]
    job = {"sermon_id": sermon["id"]}
    steps = [
        ("transcript", {"language_code": code}),
        ("analysis", {}),
        ("summary", {"output_language": output_language, "number_of_days": days}),
        ("devotional", {"days": days}),
    ]
    for step, payload in steps:
        print(f"{step}: {HANDLERS[step](job | {'payload': payload})}", flush=True)
    return sermon["id"]
