import pytest
from app.services.transcripts import within_interval, parse_manual
from app.services.youtube import YouTubeError, extract_video_id
from app.services.bible import provider

@pytest.mark.parametrize(("url","expected"),[
    ("https://www.youtube.com/watch?v=dQw4w9WgXcQ","dQw4w9WgXcQ"),
    ("https://youtu.be/dQw4w9WgXcQ?t=20","dQw4w9WgXcQ"),
    ("https://www.youtube.com/live/dQw4w9WgXcQ","dQw4w9WgXcQ"),
])
def test_extract_supported_youtube_urls(url, expected): assert extract_video_id(url) == expected

def test_rejects_unsupported_youtube_url():
    with pytest.raises(YouTubeError): extract_video_id("https://vimeo.com/123")

def test_interval_keeps_overlapping_boundary_segments():
    segments=[{"text":"antes", "start":5,"duration":10},{"text":"dentro","start":15,"duration":2},{"text":"después","start":31,"duration":2}]
    assert [s["text"] for s in within_interval(segments,10,30)] == ["antes","dentro"]

def test_manual_srt_preserves_start_time():
    segments=parse_manual("1\n00:01:02,000 --> 00:01:04,000\nLa gracia permanece", "srt")
    assert segments[0]["start"] == 62
    assert segments[0]["text"] == "La gracia permanece"

@pytest.mark.asyncio
async def test_external_bible_reader_returns_link_without_bible_text():
    result = await provider.validate("Juan 3:16", "RVR1960")
    assert result["valid"] is True
    assert result["text_available_in_selah"] is False
    assert "biblegateway.com" in result["external_url"]
