"""Which addresses belong to the Flutter app (served from app.html) and which to the landing site.

Cloudflare Pages reads the same list from the generated _redirects file; serve.py uses resolve() and
html_redirect() locally to behave the way Pages does.
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
    """Cloudflare's _redirects: each app address is answered by the app with a 200, so the URL stays.

    The target is /app, not /app.html: Pages redirects every *.html address to the one without the extension,
    and does it to a rewrite's target too, which would send the browser to /app and lose the address.
    """
    return "".join(f"{pattern} /app 200\n" for pattern in APP_ROUTES)


def html_redirect(path: str):
    """Where Pages sends an address ending in .html (index.html to its folder), or None for any other address."""
    parts = urlsplit(path)
    if not parts.path.endswith(".html"):
        return None
    if parts.path.endswith("/index.html"):
        target = parts.path[: -len("index.html")]
    else:
        target = parts.path[: -len(".html")]
    return target + (f"?{parts.query}" if parts.query else "")


def _is_app_route(path: str) -> bool:
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in APP_ROUTES)


def resolve(root: str, path: str) -> str:
    """The file that answers [path], as Pages would: an existing file, a folder's index.html, app.html for an app
    address or for /app (the rewrite target), and otherwise 404.html if there is one, else the root index.html
    (the landing page)."""
    path = urlsplit(path).path
    local = os.path.join(root, path.lstrip("/"))
    if os.path.isfile(local):
        return local
    index = os.path.join(local, "index.html")
    if os.path.isdir(local) and os.path.isfile(index):
        return index
    if path == "/app" or _is_app_route(path):
        return os.path.join(root, "app.html")
    not_found = os.path.join(root, "404.html")
    return not_found if os.path.isfile(not_found) else os.path.join(root, "index.html")
