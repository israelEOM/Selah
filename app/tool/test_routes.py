"""Tests for the app/site routing shared by the local server and Cloudflare's _redirects."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from routes import APP_ROUTES, html_redirect, redirects_file, resolve  # noqa: E402


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
        for path in ["/today", "/c/x/studies/s/day/2", "/join/abc", "/login", "/profile", "/churches/new"]:
            with self.subTest(path=path):
                self.assertEqual(self.rel(path), "app.html")

    def test_query_strings_are_ignored(self):
        self.assertEqual(self.rel("/today?x=1"), "app.html")
        self.assertEqual(self.rel("/?home"), "index.html")

    def test_assets_are_served_as_files(self):
        self.assertEqual(self.rel("/main.dart.js"), "main.dart.js")

    def test_unknown_paths_get_the_landing_page_like_cloudflare(self):
        # Cloudflare Pages answers unknown paths with the root index.html when there's no 404.html.
        self.assertEqual(self.rel("/nope"), "index.html")
        self.assertEqual(self.rel("/today/"), "index.html")

    def test_the_rewrite_target_serves_the_app(self):
        self.assertEqual(self.rel("/app"), "app.html")


class HtmlRedirectTest(unittest.TestCase):
    """Cloudflare Pages always redirects *.html to the address without it; the local server does the same."""

    def test_html_addresses_redirect_without_the_extension(self):
        self.assertEqual(html_redirect("/app.html"), "/app")
        self.assertEqual(html_redirect("/index.html"), "/")
        self.assertEqual(html_redirect("/pt/index.html"), "/pt/")
        self.assertEqual(html_redirect("/app.html?x=1"), "/app?x=1")

    def test_other_addresses_do_not_redirect(self):
        for path in ["/", "/today", "/pt/", "/main.dart.js"]:
            with self.subTest(path=path):
                self.assertIsNone(html_redirect(path))


class RedirectsFileTest(unittest.TestCase):
    def test_redirects_file_lists_every_app_route(self):
        lines = redirects_file().splitlines()
        for pattern in APP_ROUTES:
            with self.subTest(pattern=pattern):
                # Not /app.html: Cloudflare would turn that rewrite into a redirect to /app and lose the address.
                self.assertIn(f"{pattern} /app 200", lines)
        self.assertFalse(any(line.split()[0] == "/" for line in lines if line.strip()))


if __name__ == "__main__":
    unittest.main()
