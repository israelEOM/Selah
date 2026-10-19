"""Builds and checks translations of a published study. The model only sees text; structure comes from the source."""
from selah_worker.bible import parse_reference
from selah_worker.schemas import TranslationOut

BIBLE_VERSION = {"pt": "ARA", "en": "NIV"}
STRUCTURE_ERROR = "La traducción no conserva la estructura del estudio."


def source_for_translation(study: dict, days: list[dict]) -> dict:
    summary = study["summary"]
    return {
        "title": study["title"],
        "central_message": study.get("central_message"),
        "summary": {
            "introduction": summary.get("introduction"),
            "points": [{"title": p["title"], "summary": p["summary"], "subpoints": p["subpoints"],
                        "application": p.get("application")} for p in summary["points"]],
            "conclusion": summary.get("conclusion"),
            "key_takeaways": summary["key_takeaways"],
            "quotes": [q["text"] for q in summary["quotes"]],
        },
        "days": [{"day_number": d["day_number"], "title": d["title"], "main_idea": d["main_idea"],
                  "reflection": d["reflection"], "application": d["application"],
                  "questions": d["questions"], "prayer": d["prayer"]}
                 for d in sorted(days, key=lambda d: d["day_number"])],
    }


def _label(reference: str, language: str) -> str:
    parsed = parse_reference(reference, language)
    return parsed["reference"] if parsed else reference


def merge_translation(study: dict, days: list[dict], out: TranslationOut, language: str) -> dict:
    src = study["summary"]
    days = sorted(days, key=lambda d: d["day_number"])
    new = out.summary
    same = (
        [d.day_number for d in out.days] == [d["day_number"] for d in days]
        and len(new.points) == len(src["points"])
        and all(len(n.subpoints) == len(p["subpoints"]) for n, p in zip(new.points, src["points"]))
        and all(len(n.questions) == len(d["questions"]) for n, d in zip(out.days, days))
        and len(new.key_takeaways) == len(src["key_takeaways"])
        and len(new.quotes) == len(src["quotes"])
    )
    if not same:
        raise RuntimeError(STRUCTURE_ERROR)

    summary = {
        "introduction": new.introduction,
        "points": [{**n.model_dump(), "references": [_label(r, language) for r in p["references"]],
                    "start_seconds": p.get("start_seconds")} for n, p in zip(new.points, src["points"])],
        "conclusion": new.conclusion,
        "key_takeaways": new.key_takeaways,
        "main_passage": _label(src["main_passage"], language) if src.get("main_passage") else None,
        "quotes": [{"text": text, "start_seconds": q.get("start_seconds")} for text, q in zip(new.quotes, src["quotes"])],
    }
    merged_days = [{**n.model_dump(), "bible_reading": _label(d["bible_reading"], language),
                    "start_seconds": d.get("start_seconds"), "end_seconds": d.get("end_seconds")}
                   for n, d in zip(out.days, days)]
    return {"title": out.title, "central_message": out.central_message, "summary": summary,
            "days": merged_days, "bible_version_code": BIBLE_VERSION[language]}


def translation_row(study: dict, merged: dict, language: str, usage: dict) -> dict:
    return merged | {"study_id": study["id"], "language": language, "source_updated_at": study["updated_at"],
                     **usage, "hidden": True}
