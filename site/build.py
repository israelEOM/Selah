"""Builds the landing site: one HTML template rendered per language, plus its styles, fonts and images.

    python3 site/build.py --out app/build/web

Spanish is the root page (/), Portuguese and English live at /pt/ and /en/. Pages reference shared files under
/site/ with absolute paths.
"""
import argparse
import json
import os
import re
import shutil
from string import Template

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src")

# The site's public address; change it here when Selah moves to its own domain.
ORIGIN = "https://selah-226.pages.dev"

# Language → the page's path on the site.
PAGES = {"es": "/", "pt": "/pt/", "en": "/en/"}

# Language → the Open Graph locale.
LOCALES = {"es": "es_ES", "pt": "pt_BR", "en": "en_US"}


def _strings(lang: str) -> dict:
    with open(os.path.join(SRC, "strings", f"{lang}.json"), encoding="utf-8") as f:
        return json.load(f)


def _alternates() -> str:
    links = [f'<link rel="alternate" hreflang="{lang}" href="{ORIGIN}{path}">' for lang, path in PAGES.items()]
    links.append(f'<link rel="alternate" hreflang="x-default" href="{ORIGIN}/">')
    return "\n    ".join(links)


def render(lang: str) -> str:
    """The page for [lang]. Fails when a strings file lacks a key the Spanish one has, or a placeholder is left."""
    strings = _strings(lang)
    missing = set(_strings("es")) - set(strings)
    if missing:
        raise ValueError(f"{lang}.json is missing {sorted(missing)}")
    with open(os.path.join(SRC, "index.html"), encoding="utf-8") as f:
        template = Template(f.read())
    with open(os.path.join(SRC, "redirect.js"), encoding="utf-8") as f:
        redirect_script = f.read()
    page = template.substitute(
        strings,
        redirect_script=redirect_script,
        lang=lang,
        og_locale=LOCALES[lang],
        og_image=f"{ORIGIN}/site/img/og.png",
        home=PAGES[lang],
        canonical=ORIGIN + PAGES[lang],
        alternates=_alternates(),
    )
    left = re.findall(r"\$\{[^}]*\}", page)
    if left:
        raise ValueError(f"unreplaced placeholders in {lang}: {left}")
    return page


def sitemap() -> str:
    """The three landing pages, each listing its language alternates."""
    alternates = "".join(
        f'\n    <xhtml:link rel="alternate" hreflang="{lang}" href="{ORIGIN}{path}"/>' for lang, path in PAGES.items()
    )
    urls = "".join(f"\n  <url>\n    <loc>{ORIGIN}{path}</loc>{alternates}\n  </url>" for path in PAGES.values())
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">'
        f"{urls}\n</urlset>\n"
    )


def build(out_dir: str) -> None:
    for lang, path in PAGES.items():
        target = os.path.join(out_dir, path.lstrip("/"), "index.html")
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "w", encoding="utf-8") as f:
            f.write(render(lang))
    shutil.copy(os.path.join(SRC, "robots.txt"), out_dir)
    with open(os.path.join(out_dir, "sitemap.xml"), "w", encoding="utf-8") as f:
        f.write(sitemap())
    shared = os.path.join(out_dir, "site")
    os.makedirs(shared, exist_ok=True)
    shutil.copy(os.path.join(SRC, "styles.css"), shared)
    for folder in ["fonts", "img"]:
        source = os.path.join(SRC, folder)
        if os.path.isdir(source):
            shutil.copytree(source, os.path.join(shared, folder), dirs_exist_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=os.path.join(HERE, "dist"))
    build(parser.parse_args().out)
