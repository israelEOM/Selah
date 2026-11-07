"""Which addresses belong to the Flutter app (served from app.html) and which to the landing site.

Cloudflare Pages reads the same list from the generated _redirects file; serve.py uses resolve() locally.
"""
import fnmatch
import os
from urllib.parse import urlsplit

# Every address the app answers. `/x/*` covers the paths below /x; the bare path is listed on its own.
APP_ROUTES = [
    "/hoje",
    "/c/*",
    "/profile",
    "/churches",
    "/churches/*",
    "/login",
    "/welcome",
    "/join/*",
    "/requests",
    "/studies/*",
    "/admin",
]


def redirects_file() -> str:
    """Cloudflare's _redirects: each app address is answered by app.html with a 200, so the URL stays."""
    return "".join(f"{pattern} /app.html 200\n" for pattern in APP_ROUTES)


def _is_app_route(path: str) -> bool:
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in APP_ROUTES)


def resolve(root: str, path: str) -> str:
    """The file that answers [path]: an existing file, a folder's index.html, app.html for an app address, and
    app.html for anything else unknown too, so old links keep opening the app as they did before."""
    path = urlsplit(path).path
    local = os.path.join(root, path.lstrip("/"))
    if os.path.isfile(local):
        return local
    index = os.path.join(local, "index.html")
    if os.path.isdir(local) and os.path.isfile(index):
        return index
    if not _is_app_route(path):
        not_found = os.path.join(root, "404.html")
        if os.path.isfile(not_found):
            return not_found
    return os.path.join(root, "app.html")
