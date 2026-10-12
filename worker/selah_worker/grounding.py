"""Checks that what the model attributes to the preacher is really in the transcript."""
import re
import unicodedata
from difflib import SequenceMatcher


def fold(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text.lower())
    plain = "".join(c for c in decomposed if not unicodedata.combining(c))
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9ñ ]+", " ", plain)).strip()


def window_start(windows: list[dict], index: int | None) -> float | None:
    if index is None or not 0 <= index < len(windows):
        return None
    return windows[index]["start"]


def window_end(windows: list[dict], index: int | None) -> float | None:
    """End of a window is the start of the next one."""
    if index is None or not 0 <= index < len(windows):
        return None
    return windows[index + 1]["start"] if index + 1 < len(windows) else None


def locate(text: str, windows: list[dict], near: int | None, threshold: float = 0.8) -> int | None:
    """Returns the window where `text` is spoken, or None when it is not in the transcript.

    Looks around the window the model cited first, then everywhere. Captions are noisy,
    so a close match is accepted.
    """
    needle = fold(text)
    if len(needle) < 12:
        return None
    order = list(range(len(windows)))
    if near is not None and 0 <= near < len(windows):
        order.sort(key=lambda i: abs(i - near))
    own = [fold(w["text"]) for w in windows]
    # A quote can straddle two windows.
    joined = [own[i] + " " + (own[i + 1] if i + 1 < len(own) else "") for i in range(len(own))]
    for haystacks in (own, joined):
        for i in order:
            if needle in haystacks[i]:
                return i
    best_index, best_score = None, 0.0
    for i in order:
        blocks = SequenceMatcher(None, needle, joined[i], autojunk=False).get_matching_blocks()
        # Short accidental matches do not count; only runs of real shared wording do.
        score = sum(b.size for b in blocks if b.size >= 5) / len(needle)
        if score > best_score:
            best_index, best_score = i, score
    return best_index if best_score >= threshold else None
