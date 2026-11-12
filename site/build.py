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


# The hero photo at each width written by site/hero.py, smallest first.
HERO_WIDTHS = [720, 1280, 1920]


def _hero_media(alt: str) -> str:
    """The hero <picture>, or nothing when the photo hasn't been added yet (the CSS gradient stands in)."""
    files = [(w, f"hero-{w}.webp") for w in HERO_WIDTHS if os.path.isfile(os.path.join(SRC, "img", f"hero-{w}.webp"))]
    if not files:
        return ""
    srcset = ", ".join(f"/site/img/{name} {w}w" for w, name in files)
    largest = files[-1][1]
    return (
        f'<picture class="hero-media"><img src="/site/img/{largest}" srcset="{srcset}" sizes="100vw" '
        f'width="1920" height="1280" alt="{alt}" fetchpriority="high" decoding="async"></picture>'
    )


# The Today demo's week: the date, then how much was done (Monday finished, Tuesday two parts, Wednesday is today).
WEEK = [(9, "done"), (10, "partial"), (11, "today"), (12, "future"), (13, "future"), (14, "future"), (15, "future")]
PARTS = ["reading", "reflection", "prayer"]


def _ring(number: int) -> str:
    """One week ring after the app's WeekRings: a pale track, an arc per part, and a green disc with a check."""
    arcs = "".join(f'<circle class="wk-arc a-{part}" cx="18" cy="18" r="15" pathLength="100"/>' for part in PARTS)
    return (
        '<svg viewBox="0 0 36 36" aria-hidden="true"><g transform="rotate(-90 18 18)"><circle class="wk-track" cx="18" cy="18" r="15" pathLength="100"/>'
        f'{arcs}</g><circle class="wk-disc" cx="18" cy="18" r="16.5"/><path class="wk-check" d="M12.5 18.5l3.8 3.8 7.4-8" pathLength="1"/>'
        f'</svg><span class="wk-num">{number}</span>'
    )


def _week_rings(days: str) -> str:
    """The demo's seven rings, Monday first, with the weekday letters from strings."""
    letters = days.split(",")
    items = []
    for letter, (number, state) in zip(letters, WEEK):
        classes = f"wk wk-{state}"
        if state == "done":
            classes += " on-reading on-reflection on-prayer is-done"
        elif state == "partial":
            classes += " on-reading on-reflection"
        items.append(f'<li class="{classes}"><span class="wk-day">{letter}</span><span class="wk-ring">{_ring(number)}</span></li>')
    return "".join(items)


def _art_gallery(lang: str) -> str:
    """Two drifting rows of the app's illustrations; each row is repeated once, hidden from screen readers, so it loops."""
    with open(os.path.join(SRC, "art.json"), encoding="utf-8") as f:
        art = json.load(f)
    half = (len(art) + 1) // 2
    rows = []
    for row in (art[:half], art[half:]):
        tiles = "".join(
            f'<li><img src="/site/img/art/{a["key"]}.webp" width="640" height="480" alt="{a["alt"][lang]}" loading="lazy" decoding="async"></li>'
            for a in row
        )
        copy = "".join(
            f'<li><img src="/site/img/art/{a["key"]}.webp" width="640" height="480" alt="" loading="lazy" decoding="async"></li>'
            for a in row
        )
        rows.append(f'<div class="art-row"><ul class="art-strip">{tiles}</ul><ul class="art-strip" aria-hidden="true">{copy}</ul></div>')
    return "".join(rows)


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
    with open(os.path.join(SRC, "motion.js"), encoding="utf-8") as f:
        motion_script = f.read()
    page = template.substitute(
        strings,
        redirect_script=redirect_script,
        motion_script=motion_script,
        lang=lang,
        og_locale=LOCALES[lang],
        og_image=f"{ORIGIN}/site/img/og.png",
        home=PAGES[lang],
        canonical=ORIGIN + PAGES[lang],
        alternates=_alternates(),
        hero_media=_hero_media(strings["alt_hero"]),
        week_rings=_week_rings(strings["week_days"]),
        art_gallery=_art_gallery(lang),
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
