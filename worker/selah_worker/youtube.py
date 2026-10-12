import re
from urllib.parse import parse_qs, urlparse

import httpx
import isodate

from selah_worker.config import settings

VIDEO_ID = re.compile(r"^[A-Za-z0-9_-]{11}$")


class YouTubeError(Exception):
    """Raised with a message the admin can read."""


def extract_video_id(url: str) -> str:
    parsed = urlparse(url.strip())
    host = parsed.netloc.lower().removeprefix("www.").removeprefix("m.")
    parts = [p for p in parsed.path.split("/") if p]
    candidate = None
    if host == "youtu.be" and parts:
        candidate = parts[0]
    elif host == "youtube.com":
        if parsed.path == "/watch":
            candidate = parse_qs(parsed.query).get("v", [None])[0]
        elif len(parts) == 2 and parts[0] in ("live", "embed", "shorts"):
            candidate = parts[1]
    if not candidate or not VIDEO_ID.match(candidate):
        raise YouTubeError("URL de YouTube no compatible. Usa youtube.com/watch, youtube.com/live o youtu.be.")
    return candidate


def metadata(url: str) -> dict:
    video_id = extract_video_id(url)
    watch_url = f"https://www.youtube.com/watch?v={video_id}"
    # oEmbed is public; duration and date need the official Data API when a key is configured.
    try:
        response = httpx.get("https://www.youtube.com/oembed", params={"url": watch_url, "format": "json"}, timeout=10)
        if response.status_code in (401, 403, 404):
            raise YouTubeError("El video no está disponible o es privado.")
        response.raise_for_status()
        data = response.json()
    except httpx.HTTPError as exc:
        raise YouTubeError("No fue posible cargar los datos públicos del video.") from exc
    result = {
        "youtube_video_id": video_id,
        "youtube_url": watch_url,
        "title": data.get("title"),
        "channel": data.get("author_name"),
        "thumbnail_url": f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg",
        "duration_seconds": None,
        "sermon_date": None,
    }
    if settings.youtube_api_key:
        try:
            official = httpx.get(
                "https://www.googleapis.com/youtube/v3/videos",
                params={"part": "snippet,contentDetails,liveStreamingDetails", "id": video_id, "key": settings.youtube_api_key},
                timeout=10,
            )
            official.raise_for_status()
            item = (official.json().get("items") or [None])[0]
            if item:
                snippet = item.get("snippet", {})
                started = item.get("liveStreamingDetails", {}).get("actualStartTime") or snippet.get("publishedAt")
                duration = item.get("contentDetails", {}).get("duration")
                result["sermon_date"] = started[:10] if started else None
                result["duration_seconds"] = int(isodate.parse_duration(duration).total_seconds()) if duration else None
        except (httpx.HTTPError, ValueError, TypeError):
            pass  # the public data is still usable; the UI shows the duration as unknown
    return result


def _api():
    from youtube_transcript_api import YouTubeTranscriptApi
    from youtube_transcript_api.proxies import GenericProxyConfig

    if settings.youtube_proxy_url:
        proxy = GenericProxyConfig(http_url=settings.youtube_proxy_url, https_url=settings.youtube_proxy_url)
        return YouTubeTranscriptApi(proxy_config=proxy)
    return YouTubeTranscriptApi()


def _explain(exc: Exception) -> YouTubeError:
    name = type(exc).__name__
    if name in ("TranscriptsDisabled", "NoTranscriptFound"):
        return YouTubeError("No fue posible obtener los subtítulos de este video. Puedes subir un archivo SRT o VTT.")
    if name in ("VideoUnavailable", "VideoUnplayable", "InvalidVideoId", "AgeRestricted"):
        return YouTubeError("El video no está disponible.")
    if name in ("RequestBlocked", "IpBlocked"):
        return YouTubeError("YouTube bloqueó la solicitud desde esta conexión. Inténtalo más tarde o sube un archivo SRT o VTT.")
    return YouTubeError("No fue posible consultar los subtítulos en YouTube. Inténtalo de nuevo.")


def transcript_languages(video_id: str) -> list[dict]:
    try:
        return [
            {"language_code": t.language_code, "language": t.language, "is_generated": t.is_generated}
            for t in _api().list(video_id)
        ]
    except Exception as exc:
        raise _explain(exc) from exc


def fetch_transcript(video_id: str, language_code: str) -> tuple[list[dict], bool]:
    """Returns (segments, is_auto_generated). Segments are {text, start, duration} in seconds."""
    try:
        fetched = _api().fetch(video_id, languages=[language_code])
        segments = [
            {"text": s["text"], "start": float(s["start"]), "duration": float(s["duration"])}
            for s in fetched.to_raw_data()
        ]
        return segments, bool(fetched.is_generated)
    except Exception as exc:
        raise _explain(exc) from exc
