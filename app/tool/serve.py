"""Serves build/web locally the way Cloudflare Pages does: the landing site at /, /pt/ and /en/, and app.html
for every app address (see routes.py), so deep links work."""
import http.server
import os
import sys

from routes import resolve

# The folder to serve: build/web by default, or another build given after the port (the demo uses build/demo).
ROOT = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        # A rebuilt app must show up on the next reload.
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def translate_path(self, path):
        return resolve(ROOT, path)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 3100
    http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
