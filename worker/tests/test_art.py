from selah_worker import art
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
    assert len(keys) == 36
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
