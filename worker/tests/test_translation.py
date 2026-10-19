import json

import pytest

from selah_worker.schemas import TranslatedDay, TranslatedPoint, TranslatedSummary, TranslationOut
from selah_worker.translation import merge_translation, source_for_translation, translation_row

STUDY = {
    "id": "s1", "title": "Título", "central_message": "Mensaje central", "updated_at": "2026-10-19T10:00:00+00:00",
    "summary": {
        "introduction": "Intro", "conclusion": "Fin", "main_passage": "2 Reyes 2:25",
        "key_takeaways": ["Uno", "Dos"],
        "points": [{"title": "P", "summary": "Resumen", "subpoints": ["a", "b"], "references": ["2 Reyes 2:25"],
                    "application": "Aplica", "start_seconds": 2183.0}],
        "quotes": [{"text": "Cita", "start_seconds": 100.0}],
    },
}
DAYS = [
    {"day_number": n, "title": f"Día {n}", "bible_reading": "Salmo 27:14", "main_idea": "Idea",
     "reflection": "Reflexión", "application": "Aplicación", "questions": ["q1", "q2"], "prayer": "Oración",
     "start_seconds": 10.0 * n, "end_seconds": 20.0 * n}
    for n in (1, 2)
]


def day(n, questions=2):
    return TranslatedDay(day_number=n, title="T", main_idea="I", reflection="R", application="A",
                         questions=["q"] * questions, prayer="P")


def out(days=None):
    return TranslationOut(
        title="Title", central_message="Msg",
        summary=TranslatedSummary(
            introduction="Intro", conclusion="End", key_takeaways=["One", "Two"], quotes=["Quote"],
            points=[TranslatedPoint(title="P", summary="S", subpoints=["a", "b"], application="Ap")]),
        days=days if days is not None else [day(1), day(2)])


def test_source_has_no_references_or_times():
    text = json.dumps(source_for_translation(STUDY, DAYS))
    for key in ("references", "start_seconds", "bible_reading", "main_passage"):
        assert key not in text


def test_merge_relabels_references_in_english():
    r = merge_translation(STUDY, DAYS, out(), "en")
    assert r["summary"]["main_passage"] == "2 Kings 2:25"
    assert r["summary"]["points"][0]["references"] == ["2 Kings 2:25"]
    assert r["days"][0]["bible_reading"] == "Psalms 27:14"
    assert r["bible_version_code"] == "NIV"


def test_merge_relabels_references_in_portuguese():
    r = merge_translation(STUDY, DAYS, out(), "pt")
    assert r["summary"]["main_passage"] == "2 Reis 2:25"
    assert r["days"][0]["bible_reading"] == "Salmos 27:14"
    assert r["bible_version_code"] == "ARA"


def test_merge_keeps_times_and_day_numbers():
    r = merge_translation(STUDY, DAYS, out(), "en")
    assert r["summary"]["points"][0]["start_seconds"] == 2183.0
    assert r["summary"]["quotes"] == [{"text": "Quote", "start_seconds": 100.0}]
    assert [d["day_number"] for d in r["days"]] == [1, 2]
    for got, src in zip(r["days"], DAYS):
        assert got["start_seconds"] == src["start_seconds"] and got["end_seconds"] == src["end_seconds"]


def test_merge_rejects_missing_day():
    with pytest.raises(RuntimeError, match="estructura"):
        merge_translation(STUDY, DAYS, out([day(1)]), "en")


def test_merge_rejects_missing_question():
    with pytest.raises(RuntimeError):
        merge_translation(STUDY, DAYS, out([day(1), day(2, questions=1)]), "en")


def test_translation_row_starts_hidden():
    merged = merge_translation(STUDY, DAYS, out(), "en")
    usage = {"model": "m", "prompt_version": "v", "input_tokens": 1, "output_tokens": 2}
    row = translation_row(STUDY, merged, "en", usage)
    assert row["hidden"] is True and row["language"] == "en"
    assert row["source_updated_at"] == STUDY["updated_at"] and row["study_id"] == "s1"
