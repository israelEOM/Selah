import re
from datetime import datetime, timedelta
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


def _data_api(resource: str, **params) -> dict:
    """One call to the official Data API. Channel search and the lives list need the key."""
    if not settings.youtube_api_key:
        raise YouTubeError("Configura YOUTUBE_API_KEY en el worker para buscar canales.")
    try:
        response = httpx.get(f"https://www.googleapis.com/youtube/v3/{resource}",
                             params=params | {"key": settings.youtube_api_key}, timeout=10)
        if response.status_code == 403:
            raise YouTubeError("Se agotó la cuota diaria de YouTube. Inténtalo mañana o pega el enlace del video.")
        response.raise_for_status()
        return response.json()
    except httpx.HTTPError as exc:
        raise YouTubeError("No fue posible consultar YouTube. Inténtalo de nuevo.") from exc


def _thumbnail(snippet: dict, *sizes: str) -> str | None:
    thumbs = snippet.get("thumbnails") or {}
    return next((thumbs[s]["url"] for s in sizes if s in thumbs), None)


def search_channels(query: str) -> list[dict]:
    # search.list costs 100 quota units; the channels lookup that adds handles costs 1.
    found = _data_api("search", part="snippet", type="channel", q=query.strip(), maxResults=8)
    ids = [item["id"]["channelId"] for item in found.get("items", [])]
    if not ids:
        return []
    details = _data_api("channels", part="snippet,statistics", id=",".join(ids))
    by_id = {item["id"]: item for item in details.get("items", [])}
    channels = []
    for channel_id in ids:
        item = by_id.get(channel_id)
        if not item:
            continue
        snippet, stats = item["snippet"], item.get("statistics", {})
        channels.append({
            "channel_id": channel_id,
            "title": snippet.get("title"),
            "handle": snippet.get("customUrl"),
            "thumbnail_url": _thumbnail(snippet, "default", "medium"),
            "subscriber_count": None if stats.get("hiddenSubscriberCount") else int(stats.get("subscriberCount", 0)),
        })
    return channels


def _published(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def recent_lives(channel_id: str, page_token: str | None = None, days: int = 28, max_pages: int = 6) -> dict:
    """Finished live streams from about `days` of uploads, newest first. `next_page_token` continues further back."""
    channel = (_data_api("channels", part="contentDetails", id=channel_id).get("items") or [None])[0]
    if not channel:
        raise YouTubeError("No encontramos ese canal.")
    uploads = channel["contentDetails"]["relatedPlaylists"]["uploads"]
    video_ids, newest = [], None
    # Every page costs 1 unit, so walking uploads is far cheaper than search.list with eventType.
    for _ in range(max_pages):
        page = _data_api("playlistItems", part="contentDetails", playlistId=uploads, maxResults=50,
                         **({"pageToken": page_token} if page_token else {}))
        items = page.get("items", [])
        video_ids += [i["contentDetails"]["videoId"] for i in items]
        page_token = page.get("nextPageToken")
        dates = [_published(i["contentDetails"]["videoPublishedAt"]) for i in items
                 if i["contentDetails"].get("videoPublishedAt")]
        newest = newest or (dates[0] if dates else None)
        if not page_token or (newest and dates and dates[-1] < newest - timedelta(days=days)):
            break
    lives = []
    for start in range(0, len(video_ids), 50):
        videos = _data_api("videos", part="snippet,contentDetails,liveStreamingDetails",
                           id=",".join(video_ids[start:start + 50]))
        for item in videos.get("items", []):
            live = item.get("liveStreamingDetails") or {}
            if not live.get("actualEndTime"):
                continue  # a regular upload, an upcoming stream, or one still on air
            duration = item.get("contentDetails", {}).get("duration")
            lives.append({
                "youtube_video_id": item["id"],
                "youtube_url": f"https://www.youtube.com/watch?v={item['id']}",
                "title": item["snippet"].get("title"),
                "thumbnail_url": _thumbnail(item["snippet"], "medium", "high", "default")
                or f"https://i.ytimg.com/vi/{item['id']}/mqdefault.jpg",
                "started_at": live.get("actualStartTime"),
                "duration_seconds": int(isodate.parse_duration(duration).total_seconds()) if duration else None,
            })
    lives.sort(key=lambda v: v["started_at"] or "", reverse=True)
    return {"lives": lives, "next_page_token": page_token}


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
