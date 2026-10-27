import httpx
import pytest

from selah_worker import youtube
from selah_worker.youtube import YouTubeError, recent_lives, search_channels


def _video(video_id, start=None, end=None):
    item = {"id": video_id, "snippet": {"title": video_id, "thumbnails": {"medium": {"url": f"{video_id}.jpg"}}},
            "contentDetails": {"duration": "PT1H30M"}}
    if start:
        item["liveStreamingDetails"] = {"actualStartTime": start, **({"actualEndTime": end} if end else {})}
    return item


def _fake_api(monkeypatch, responses, calls=None):
    monkeypatch.setattr(youtube.settings, "youtube_api_key", "key")

    def get(url, params, timeout):
        resource = url.rsplit("/", 1)[1]
        if calls is not None:
            calls.append((resource, params))
        body = responses[resource](params) if callable(responses[resource]) else responses[resource]
        return httpx.Response(200, json=body, request=httpx.Request("GET", url))

    monkeypatch.setattr(youtube.httpx, "get", get)


def test_lives_keep_only_finished_streams_newest_first(monkeypatch):
    _fake_api(monkeypatch, {
        "channels": {"items": [{"contentDetails": {"relatedPlaylists": {"uploads": "UU1"}}}]},
        "playlistItems": {"items": [
            {"contentDetails": {"videoId": v, "videoPublishedAt": "2026-10-25T15:00:00Z"}}
            for v in ("upload", "older", "newer", "on_air")]},
        "videos": {"items": [
            _video("upload"),
            _video("older", "2026-10-18T14:00:00Z", "2026-10-18T16:00:00Z"),
            _video("newer", "2026-10-25T14:00:00Z", "2026-10-25T16:00:00Z"),
            _video("on_air", "2026-10-26T14:00:00Z"),
        ]},
    })
    result = recent_lives("UC1")
    assert [v["youtube_video_id"] for v in result["lives"]] == ["newer", "older"]
    assert result["lives"][0]["duration_seconds"] == 5400
    assert result["lives"][0]["youtube_url"] == "https://www.youtube.com/watch?v=newer"
    assert result["next_page_token"] is None


def test_lives_stop_paging_once_past_the_window(monkeypatch):
    pages = {
        None: {"nextPageToken": "p2", "items": [
            {"contentDetails": {"videoId": "a", "videoPublishedAt": "2026-10-25T00:00:00Z"}},
            {"contentDetails": {"videoId": "b", "videoPublishedAt": "2026-10-10T00:00:00Z"}}]},
        "p2": {"nextPageToken": "p3", "items": [
            {"contentDetails": {"videoId": "c", "videoPublishedAt": "2026-09-20T00:00:00Z"}}]},
    }
    calls = []
    _fake_api(monkeypatch, {
        "channels": {"items": [{"contentDetails": {"relatedPlaylists": {"uploads": "UU1"}}}]},
        "playlistItems": lambda params: pages[params.get("pageToken")],
        "videos": {"items": []},
    }, calls)
    assert recent_lives("UC1")["next_page_token"] == "p3"
    assert [c for c, _ in calls].count("playlistItems") == 2


def test_search_returns_handles_in_search_order(monkeypatch):
    _fake_api(monkeypatch, {
        "search": {"items": [{"id": {"channelId": "UC2"}}, {"id": {"channelId": "UC1"}}]},
        "channels": {"items": [
            {"id": "UC1", "snippet": {"title": "Uno", "customUrl": "@uno"}, "statistics": {"subscriberCount": "12"}},
            {"id": "UC2", "snippet": {"title": "Dos"}, "statistics": {"hiddenSubscriberCount": True}},
        ]},
    })
    channels = search_channels("iglesia")
    assert [c["channel_id"] for c in channels] == ["UC2", "UC1"]
    assert channels[0]["subscriber_count"] is None
    assert channels[1]["handle"] == "@uno" and channels[1]["subscriber_count"] == 12


def test_channel_tools_need_the_api_key(monkeypatch):
    monkeypatch.setattr(youtube.settings, "youtube_api_key", "")
    with pytest.raises(YouTubeError):
        search_channels("iglesia")
