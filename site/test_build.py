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


if __name__ == "__main__":
    unittest.main()
