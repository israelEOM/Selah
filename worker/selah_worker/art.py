"""The app's bundled illustration manifest, as the worker sees it: a menu for the model and a key check."""
import json
from functools import lru_cache
from pathlib import Path

MANIFEST = Path(__file__).resolve().parents[2] / "app/assets/art/manifest.json"


@lru_cache
def _images() -> list[dict]:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))["images"]


def pickable() -> list[dict]:
    return [i for i in _images() if i.get("pickable")]


def menu() -> str:
    lines = [f"{i['key']}: {', '.join(i['tags'])}" for i in pickable()]
    return ("Choose art_key from this list only; pick the image whose tags best fit the theme.\n"
            + "\n".join(lines))


def valid_key(key: str | None) -> str | None:
    return key if key in {i["key"] for i in pickable()} else None
