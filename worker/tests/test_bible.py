import pytest

from selah_worker.bible import parse_reference


@pytest.mark.parametrize(("raw", "expected", "book"), [
    ("2 Reyes 4:1-7", "2 Reyes 4:1-7", "2KI"),
    ("Segunda de Reyes 4", "2 Reyes 4", "2KI"),
    ("1ª Corintios 13:4", "1 Corintios 13:4", "1CO"),
    ("Salmo 27:14", "Salmos 27:14", "PSA"),
    ("Romanos 8.28", "Romanos 8:28", "ROM"),
    ("Jn 3:16", "Juan 3:16", "JHN"),
    ("San Juan 3:16", "Juan 3:16", "JHN"),
    ("Hebreos 11:1–3", "Hebreos 11:1-3", "HEB"),
])
def test_parses_spanish_references(raw, expected, book):
    parsed = parse_reference(raw)
    assert parsed["reference"] == expected
    assert parsed["book"] == book


def test_renders_in_the_requested_language():
    assert parse_reference("2 Reyes 4:1", "pt")["reference"] == "2 Reis 4:1"
    assert parse_reference("John 3:16", "es")["reference"] == "Juan 3:16"


@pytest.mark.parametrize("raw", ["Romanos 17:1", "Hezequías 3:4", "la Biblia dice", "Judas 2:1", ""])
def test_rejects_impossible_references(raw):
    assert parse_reference(raw) is None
