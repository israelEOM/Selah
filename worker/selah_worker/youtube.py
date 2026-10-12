import re
import isodate
from dataclasses import dataclass
from urllib.parse import parse_qs, urlparse
import httpx
from selah_worker.config import settings

VIDEO_ID = re.compile(r"^[A-Za-z0-9_-]{11}$")
class YouTubeError(Exception): pass

def extract_video_id(url: str) -> str:
    parsed = urlparse(url)
    host = parsed.netloc.lower().removeprefix("www.")
    candidate = None
    if host == "youtu.be": candidate = parsed.path.strip("/").split("/")[0]
    elif host == "youtube.com":
        if parsed.path == "/watch": candidate = parse_qs(parsed.query).get("v", [None])[0]
        elif parsed.path.startswith("/live/"): candidate = parsed.path.split("/")[2] if len(parsed.path.split("/")) > 2 else None
    if not candidate or not VIDEO_ID.match(candidate): raise YouTubeError("URL de YouTube no compatible. Use youtube.com/watch, youtube.com/live o youtu.be.")
    return candidate

async def metadata(url: str) -> dict:
    video_id = extract_video_id(url)
    # oEmbed is public metadata; duration requires official Data API when configured.
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get("https://www.youtube.com/oembed", params={"url": f"https://www.youtube.com/watch?v={video_id}", "format": "json"})
            response.raise_for_status(); data = response.json()
    except httpx.HTTPError as exc: raise YouTubeError("No fue posible cargar los metadatos públicos del video.") from exc
    result = {"video_id": video_id, "title": data.get("title"), "channel_name": data.get("author_name"), "thumbnail_url": f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg", "duration_seconds": None, "published_at": None}
    if settings.youtube_api_key:
        try:
            async with httpx.AsyncClient(timeout=10) as client:
                official = await client.get("https://www.googleapis.com/youtube/v3/videos", params={"part":"snippet,contentDetails","id":video_id,"key":settings.youtube_api_key})
                official.raise_for_status(); item = official.json().get("items", [None])[0]
                if item:
                    snippet=item.get("snippet",{}); result.update({"title":snippet.get("title",result["title"]),"channel_name":snippet.get("channelTitle",result["channel_name"]),"published_at":snippet.get("publishedAt"),"duration_seconds":int(isodate.parse_duration(item.get("contentDetails",{}).get("duration","PT0S")).total_seconds())})
        except (httpx.HTTPError, ValueError, TypeError):
            # Public oEmbed data remains usable; the UI makes the unknown duration explicit.
            pass
    return result

def transcript_languages(video_id: str) -> list[dict]:
    from youtube_transcript_api import YouTubeTranscriptApi
    try:
        transcripts = YouTubeTranscriptApi().list(video_id)
        return [{"language": t.language, "language_code": t.language_code, "is_generated": t.is_generated} for t in transcripts]
    except Exception as exc: raise YouTubeError("No se pudieron consultar los subtítulos. Puede importar TXT, SRT o VTT manualmente.") from exc

def fetch_transcript(video_id: str, language: str) -> tuple[list[dict], bool]:
    from youtube_transcript_api import YouTubeTranscriptApi
    try:
        transcript = YouTubeTranscriptApi().fetch(video_id, languages=[language])
        snippets = transcript.to_raw_data()
        return ([{"text": s["text"], "start": float(s["start"]), "duration": float(s["duration"])} for s in snippets], False)
    except Exception as exc: raise YouTubeError("Los subtítulos seleccionados no están disponibles o YouTube rechazó la solicitud.") from exc
