from types import SimpleNamespace

from selah_worker import ai, art, pipeline
from selah_worker.schemas import DayOut, SummaryOut

DAY = {
    "day_number": 1, "title": "T", "bible_reading": "Salmos 27:14", "main_idea": "I", "reflection": "R",
    "application": "A", "questions": ["q"], "prayer": "P", "start_window": 1, "end_window": 2,
}
SUMMARY = {
    "title": "T", "central_message": "M", "introduction": "I", "points": [], "key_takeaways": ["k"],
}


def test_menu_lists_only_pickable_keys():
    assert "vine-grapes:" in art.menu()
    assert "scene-welcome" not in art.menu()
    assert art.menu().startswith("Choose art_key from this list only")


def test_pickable_excludes_fixed_scenes():
    keys = [i["key"] for i in art.pickable()]
    assert len(keys) >= 30 and len(set(keys)) == len(keys)
    assert not any(k.startswith("scene-") for k in keys)


def test_valid_key_rejects_unknown_and_fixed_scenes():
    assert art.valid_key("vine-grapes") == "vine-grapes"
    assert art.valid_key("scene-welcome") is None
    assert art.valid_key("made-up") is None
    assert art.valid_key(None) is None


def test_schemas_accept_art_key():
    assert DayOut.model_validate({**DAY, "art_key": "dove"}).art_key == "dove"
    assert DayOut.model_validate(DAY).art_key is None
    assert SummaryOut.model_validate({**SUMMARY, "art_key": "dove"}).art_key == "dove"
    assert SummaryOut.model_validate(SUMMARY).art_key is None


def test_split_art_pops_and_validates():
    content = {"art_key": "dove", "introduction": "I"}
    assert pipeline.split_art(content) == "dove"
    assert "art_key" not in content
    bad = {"art_key": "scene-welcome"}
    assert pipeline.split_art(bad) is None and bad == {}
    assert pipeline.split_art({}) is None


def test_day_row_carries_validated_art_key():
    study = {"id": "s1", "output_language": "es"}
    windows = [{"index": 1, "start": 0.0, "end": 5.0}, {"index": 2, "start": 5.0, "end": 9.0}]
    day = DayOut.model_validate({**DAY, "art_key": "dove"})
    assert pipeline.day_row(study, day, windows)["art_key"] == "dove"
    day = DayOut.model_validate({**DAY, "art_key": "made-up"})
    assert pipeline.day_row(study, day, windows)["art_key"] is None


def test_missing_manifest_degrades_to_empty_library(monkeypatch, tmp_path):
    monkeypatch.setattr(art, "MANIFEST", tmp_path / "nope.json")
    art._images.cache_clear(); art._keys.cache_clear()
    try:
        assert art.pickable() == []
        assert art.menu() == ""
        assert art.valid_key("vine-grapes") is None
        assert "\n\n" not in ai._with_art("Instruction")
        assert ai._with_art("Instruction") == "Instruction"
    finally:
        monkeypatch.undo()
        art._images.cache_clear(); art._keys.cache_clear()
    assert art.valid_key("vine-grapes") == "vine-grapes"
