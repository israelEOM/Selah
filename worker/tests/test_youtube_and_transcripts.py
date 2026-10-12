import pytest

from selah_worker.transcripts import build_windows, parse_manual, render_windows, within_interval
from selah_worker.youtube import YouTubeError, extract_video_id


@pytest.mark.parametrize(("url", "expected"), [
    ("https://www.youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ"),
    ("https://youtu.be/dQw4w9WgXcQ?t=20", "dQw4w9WgXcQ"),
    ("https://www.youtube.com/live/dQw4w9WgXcQ", "dQw4w9WgXcQ"),
    ("https://m.youtube.com/watch?v=dQw4w9WgXcQ&t=5s", "dQw4w9WgXcQ"),
])
def test_extract_supported_youtube_urls(url, expected):
    assert extract_video_id(url) == expected


@pytest.mark.parametrize("url", ["https://vimeo.com/123", "https://www.youtube.com/watch?v=short", "not a url"])
def test_rejects_unsupported_youtube_url(url):
    with pytest.raises(YouTubeError):
        extract_video_id(url)


def test_interval_keeps_overlapping_boundary_segments():
    segments = [
        {"text": "antes", "start": 5, "duration": 10},
        {"text": "dentro", "start": 15, "duration": 2},
        {"text": "después", "start": 31, "duration": 2},
    ]
    assert [s["text"] for s in within_interval(segments, 10, 30)] == ["antes", "dentro"]


def test_manual_srt_preserves_start_time():
    segments = parse_manual("1\n00:01:02,000 --> 00:01:04,000\nLa gracia permanece", "srt")
    assert segments[0]["start"] == 62
    assert segments[0]["text"] == "La gracia permanece"


def test_manual_vtt_without_hours():
    segments = parse_manual("WEBVTT\n\n01:02.500 --> 01:04.000\nLa gracia permanece", "vtt")
    assert segments[0]["start"] == 62.5


def test_windows_group_segments_and_keep_first_start():
    segments = [{"text": f"s{i}", "start": i * 10.0, "duration": 10.0} for i in range(7)]
    segments.insert(1, {"text": "[Música]", "start": 5.0, "duration": 1.0})
    windows = build_windows(segments, seconds=30)
    assert [w["start"] for w in windows] == [0.0, 30.0, 60.0]
    assert windows[0]["text"] == "s0 s1 s2"
    assert render_windows(windows).splitlines()[1] == "[#1 00:00:30] s3 s4 s5"
