"""Tests for the landing site build: three localized pages, assets, and the page-weight budget."""
import json
import os
import re
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from build import build  # noqa: E402

LANGUAGES = {"es": "index.html", "pt": os.path.join("pt", "index.html"), "en": os.path.join("en", "index.html")}
FONTS = ["SourceSerif4-Regular.woff2", "SourceSerif4-It.woff2", "SourceSerif4-Semibold.woff2"]


class BuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.out = cls.tmp.name
        build(cls.out)
        cls.pages = {}
        for lang, rel in LANGUAGES.items():
            with open(os.path.join(cls.out, rel), encoding="utf-8") as f:
                cls.pages[lang] = f.read()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_three_language_pages(self):
        for lang, html in self.pages.items():
            with self.subTest(lang=lang):
                self.assertIn(f'<html lang="{lang}"', html)

    def test_no_unreplaced_placeholders(self):
        for lang, html in self.pages.items():
            with self.subTest(lang=lang):
                self.assertNotIn("${", html)

    def test_hreflang_alternates(self):
        for lang, html in self.pages.items():
            with self.subTest(lang=lang):
                for alt in ["es", "pt", "en", "x-default"]:
                    self.assertRegex(html, rf'<link rel="alternate" hreflang="{alt}" href="https://[^"]+"')

    def test_strings_have_the_same_keys(self):
        def keys(lang):
            with open(os.path.join(HERE, "src", "strings", f"{lang}.json"), encoding="utf-8") as f:
                return set(json.load(f))

        self.assertEqual(keys("pt"), keys("es"))
        self.assertEqual(keys("en"), keys("es"))

    def test_assets_copied(self):
        self.assertTrue(os.path.isfile(os.path.join(self.out, "site", "styles.css")))
        for font in FONTS:
            with self.subTest(font=font):
                self.assertTrue(os.path.isfile(os.path.join(self.out, "site", "fonts", font)))

    def test_page_weight_budget(self):
        shared = os.path.getsize(os.path.join(self.out, "site", "styles.css"))
        shared += sum(os.path.getsize(os.path.join(self.out, "site", "fonts", font)) for font in FONTS)
        for lang, html in self.pages.items():
            with self.subTest(lang=lang):
                self.assertLessEqual(len(html.encode("utf-8")) + shared, 250 * 1024)

    def test_redirect_inlined_first(self):
        for lang, html in self.pages.items():
            with self.subTest(lang=lang):
                head = html.split("</head>")[0]
                self.assertIn("landingDecision", head)
                self.assertLess(head.index("<script>"), head.index('rel="stylesheet"'))

    def test_calls_to_action_point_at_the_app(self):
        for lang, html in self.pages.items():
            with self.subTest(lang=lang):
                for href in ['href="/churches"', 'href="/login?next=%2Fwelcome%3Fstep%3Dleader"', 'href="/today"']:
                    self.assertIn(href, html)

    def test_images_have_alt_and_size(self):
        for lang, html in self.pages.items():
            with self.subTest(lang=lang):
                images = re.findall(r"<img\b[^>]*>", html)
                self.assertGreaterEqual(len(images), 2)
                for img in images:
                    self.assertRegex(img, r'alt="[^"]+"')
                    self.assertRegex(img, r'width="\d+"')
                    self.assertRegex(img, r'height="\d+"')

    def test_one_h1_per_page(self):
        for lang, html in self.pages.items():
            with self.subTest(lang=lang):
                self.assertEqual(len(re.findall(r"<h1\b", html)), 1)

    def test_scripture_is_cited(self):
        for lang, html in self.pages.items():
            with self.subTest(lang=lang):
                self.assertRegex(html, r"(?s)<blockquote\b.*?<cite\b.*?</blockquote>")

    def test_language_switcher_links_every_language(self):
        for lang, html in self.pages.items():
            with self.subTest(lang=lang):
                for href in ['href="/"', 'href="/pt/"', 'href="/en/"']:
                    self.assertIn(href, html)
                self.assertIn("site.lang", html)

    def test_meta_tags(self):
        for lang, html in self.pages.items():
            with self.subTest(lang=lang):
                title = re.search(r"<title>([^<]+)</title>", html).group(1)
                description = re.search(r'<meta name="description" content="([^"]+)"', html).group(1)
                self.assertLessEqual(len(title), 60)
                self.assertLessEqual(len(description), 160)
                for prop in ["og:title", "og:description", "og:image", "og:url", "og:locale"]:
                    self.assertRegex(html, rf'<meta property="{prop}" content="[^"]+"')
                self.assertIn('<meta name="twitter:card" content="summary_large_image">', html)
                self.assertRegex(html, r'<link rel="icon" href="/[^"]+"')

    def test_og_image_is_absolute_and_exists(self):
        image = re.search(r'<meta property="og:image" content="([^"]+)"', self.pages["es"]).group(1)
        self.assertTrue(image.startswith("https://"))
        self.assertTrue(os.path.isfile(os.path.join(self.out, image.split("/", 3)[3])))

    def test_robots_and_sitemap(self):
        with open(os.path.join(self.out, "robots.txt"), encoding="utf-8") as f:
            robots = f.read()
        self.assertIn("Disallow: /today", robots)
        self.assertIn("Disallow: /c/", robots)
        self.assertIn("Sitemap: https://", robots)
        with open(os.path.join(self.out, "sitemap.xml"), encoding="utf-8") as f:
            sitemap = f.read()
        for path in ["/", "/pt/", "/en/"]:
            self.assertIn(f"<loc>https://selah-226.pages.dev{path}</loc>", sitemap)
        self.assertIn('hreflang="pt"', sitemap)

    def test_wordmark_stays_in_the_page_language(self):
        for lang, path in [("es", "/"), ("pt", "/pt/"), ("en", "/en/")]:
            with self.subTest(lang=lang):
                self.assertIn(f'<a class="wordmark" href="{path}">', self.pages[lang])

    def test_robots_hides_the_app_shell_address(self):
        with open(os.path.join(self.out, "robots.txt"), encoding="utf-8") as f:
            self.assertIn("Disallow: /app", f.read())


if __name__ == "__main__":
    unittest.main()
