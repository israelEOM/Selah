"""The app's bundled illustration manifest, as the worker sees it: a menu for the model and a key check."""
import json
import logging
from functools import lru_cache
from pathlib import Path

log = logging.getLogger("selah")
MANIFEST = Path(__file__).resolve().parents[2] / "app/assets/art/manifest.json"


@lru_cache
def _images() -> tuple[dict, ...]:
    try:
        return tuple(json.loads(MANIFEST.read_text(encoding="utf-8"))["images"])
    except (OSError, ValueError, KeyError) as exc:
        log.warning("Art manifest unavailable (%s); no illustrations will be picked.", exc)
        return ()


def pickable() -> list[dict]:
    return [i for i in _images() if i.get("pickable")]


@lru_cache
def _keys() -> frozenset[str]:
    return frozenset(i["key"] for i in pickable())


def menu() -> str:
    """The prompt section listing the choices; empty when there is no library."""
    if not pickable():
        return ""
    lines = [f"{i['key']}: {', '.join(i['tags'])}" for i in pickable()]
    return ("Choose art_key from this list only; pick the image whose tags best fit the theme.\n"
            + "\n".join(lines))


def valid_key(key: str | None) -> str | None:
    return key if key in _keys() else None
