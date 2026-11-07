"""Tests for the app/site routing shared by the local server and Cloudflare's _redirects."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from routes import APP_ROUTES, redirects_file, resolve  # noqa: E402


class ResolveTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        for name in ["app.html", "index.html", "main.dart.js", os.path.join("pt", "index.html")]:
            path = os.path.join(self.root, name)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as f:
                f.write(name)

    def tearDown(self):
        self.tmp.cleanup()

    def rel(self, path):
        return os.path.relpath(resolve(self.root, path), self.root)

    def test_root_is_the_landing_page(self):
        self.assertEqual(self.rel("/"), "index.html")

    def test_language_pages(self):
        self.assertEqual(self.rel("/pt/"), os.path.join("pt", "index.html"))

    def test_app_routes_are_served_app_html(self):
        for path in ["/hoje", "/c/x/studies/s/day/2", "/join/abc", "/login", "/profile", "/churches/new"]:
            with self.subTest(path=path):
                self.assertEqual(self.rel(path), "app.html")

    def test_query_strings_are_ignored(self):
        self.assertEqual(self.rel("/hoje?x=1"), "app.html")
        self.assertEqual(self.rel("/?home"), "index.html")

    def test_assets_are_served_as_files(self):
        self.assertEqual(self.rel("/main.dart.js"), "main.dart.js")


class RedirectsFileTest(unittest.TestCase):
    def test_redirects_file_lists_every_app_route(self):
        lines = redirects_file().splitlines()
        for pattern in APP_ROUTES:
            with self.subTest(pattern=pattern):
                self.assertIn(f"{pattern} /app.html 200", lines)
        self.assertFalse(any(line.split()[0] == "/" for line in lines if line.strip()))


if __name__ == "__main__":
    unittest.main()
