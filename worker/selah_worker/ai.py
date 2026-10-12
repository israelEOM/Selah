import json
import logging
import time
from functools import lru_cache
from typing import TypeVar

from pydantic import BaseModel

from selah_worker.config import settings
from selah_worker.schemas import AnalysisOut, DevotionalOut, SummaryOut

log = logging.getLogger("selah")
PROMPT_VERSION = "2026-10-12.2"
LANGUAGES = {"es": "español", "pt": "português", "en": "English"}
T = TypeVar("T", bound=BaseModel)

FIDELITY = """You are an editorial assistant for a local church. You turn a sermon into study material.
The sermon transcript is the only source for what the preacher said. Rules:
- Never invent statements, quotes, Bible references or doctrinal claims and attribute them to the preacher.
- If something is not in the transcript, return null or leave the list empty. Do not fill a field just to complete it.
- Never write out Bible verses from memory. Give the reference only.
- The transcript comes from automatic captions: expect missing punctuation and misheard words, especially book names
  and proper nouns. Correct obvious caption errors silently; do not guess beyond that.
- Each transcript line starts with [#N HH:MM:SS]. When asked for a window, give N of the line where the content is."""

ANALYSIS = """Analyse the sermon in this transcript. Write in {language}.

The recording may include songs, prayers, announcements or readings before and after the sermon. Analyse only the
sermon itself. Set sermon_start_window and sermon_end_window to the lines where the preaching begins and ends.

- Keep the preacher's own structure. Do not force a fixed number of points.
- points[].start_window and end_window delimit where that point is preached.
- quotes: 3 to 8 memorable sentences in the preacher's own words, copied word for word from the transcript.
  Not Bible text being read aloud, and not the sermon title.
- references: every Bible reference used inside the sermon (not in readings or prayers before or after it),
  written as book chapter:verse in {language}, with a verse range as 12-13.
  explicit = the preacher names book and chapter. quoted = the preacher clearly quotes a passage without naming it.
  possible = it only resembles a passage. excerpt = the preacher's exact words at that line.
- preacher: only if the name is stated in the video title or the transcript."""

SUMMARY = """Write a sermon summary in {language} from this analysis, for members to review the sermon during the week.
Concise but substantial: each point's summary is 60 to 120 words. Keep the same points in the same order and set
point_index to the index of the analysis point. Use only references that appear in the analysis.
key_takeaways: 3 to 5 short sentences."""

DEVOTIONAL = """Write a {days}-day devotional in {language} based on this sermon. You receive the analysis and the transcript.

- Divide the sermon by its natural themes. Do not mechanically assign one sermon point per day; an important point
  may span several days. Days must not repeat each other.
- bible_reading: one reference that the sermon uses (from the analysis references), fitting that day.
- main_idea: one or two sentences.
- reflection: at least 300 and at most 500 words, in three to five paragraphs separated by blank lines, that stay close to what the preacher taught in that part of the sermon. Do not put
  words in the preacher's mouth: say "en la predicación se nos recordó…" style phrasing only for things that are in
  the transcript.
- application: one concrete action or spiritual practice for today.
- questions: 2 to 4 reflection questions.
- prayer: a short prayer in first person plural or singular. It is devotional material, not a quote.
- start_window and end_window: the part of the sermon this day draws on.
- day_number runs from 1 to {days}."""


@lru_cache
def _client():
    from google import genai

    if not settings.gemini_api_key:
        raise RuntimeError("GEMINI_API_KEY no está configurada.")
    return genai.Client(api_key=settings.gemini_api_key)


def generate(instruction: str, source: str, schema: type[T]) -> tuple[T, dict]:
    """One structured call. Retries transient failures and malformed output."""
    from google.genai import errors, types

    config = types.GenerateContentConfig(
        system_instruction=FIDELITY + "\n\n" + instruction,
        response_mime_type="application/json",
        response_schema=schema,
        temperature=0.3,
    )
    last: Exception | None = None
    for attempt in range(3):
        try:
            response = _client().models.generate_content(model=settings.gemini_model, contents=source, config=config)
            parsed = response.parsed if isinstance(response.parsed, schema) else schema.model_validate_json(response.text or "")
            usage = response.usage_metadata
            return parsed, {
                "model": settings.gemini_model,
                "prompt_version": PROMPT_VERSION,
                "input_tokens": getattr(usage, "prompt_token_count", None),
                "output_tokens": getattr(usage, "candidates_token_count", None),
            }
        except errors.ClientError as exc:
            if exc.code != 429:
                raise RuntimeError(f"La IA rechazó la solicitud ({exc.code}).") from exc
            last = exc
        except (errors.ServerError, ValueError) as exc:  # ValueError covers malformed JSON
            last = exc
        log.warning("AI call failed (attempt %s): %s", attempt + 1, last)
        time.sleep(5 * (attempt + 1))
    raise RuntimeError("La IA no respondió correctamente después de varios intentos. Inténtalo de nuevo.") from last


def analyze(transcript: str, language: str, title: str | None, channel: str | None) -> tuple[AnalysisOut, dict]:
    source = f"VIDEO TITLE: {title or 'unknown'}\nCHANNEL: {channel or 'unknown'}\n\nTRANSCRIPT\n{transcript}"
    return generate(ANALYSIS.format(language=LANGUAGES.get(language, language)), source, AnalysisOut)


def summarize(analysis: dict, language: str) -> tuple[SummaryOut, dict]:
    source = "ANALYSIS\n" + json.dumps(analysis, ensure_ascii=False)
    return generate(SUMMARY.format(language=LANGUAGES.get(language, language)), source, SummaryOut)


def devotional(analysis: dict, transcript: str, days: int, language: str) -> tuple[DevotionalOut, dict]:
    source = "ANALYSIS\n" + json.dumps(analysis, ensure_ascii=False) + "\n\nTRANSCRIPT\n" + transcript
    return generate(DEVOTIONAL.format(days=days, language=LANGUAGES.get(language, language)), source, DevotionalOut)
