"""Bible reference parsing. Selah stores references, never Bible text."""
import re
import unicodedata
from urllib.parse import urlencode

from selah_worker.config import settings

# (canonical id, chapters, Spanish, Portuguese, English, comma-separated aliases)
_BOOKS = [
    ("GEN", 50, "Génesis", "Gênesis", "Genesis", "gn, gen"),
    ("EXO", 40, "Éxodo", "Êxodo", "Exodus", "ex, exo"),
    ("LEV", 27, "Levítico", "Levítico", "Leviticus", "lv, lev"),
    ("NUM", 36, "Números", "Números", "Numbers", "nm, num"),
    ("DEU", 34, "Deuteronomio", "Deuteronômio", "Deuteronomy", "dt, deut"),
    ("JOS", 24, "Josué", "Josué", "Joshua", "jos"),
    ("JDG", 21, "Jueces", "Juízes", "Judges", "jue, jz"),
    ("RUT", 4, "Rut", "Rute", "Ruth", "rt"),
    ("1SA", 31, "1 Samuel", "1 Samuel", "1 Samuel", "1 s, 1 sam, 1 sm"),
    ("2SA", 24, "2 Samuel", "2 Samuel", "2 Samuel", "2 s, 2 sam, 2 sm"),
    ("1KI", 22, "1 Reyes", "1 Reis", "1 Kings", "1 r, 1 re, 1 rs"),
    ("2KI", 25, "2 Reyes", "2 Reis", "2 Kings", "2 r, 2 re, 2 rs"),
    ("1CH", 29, "1 Crónicas", "1 Crônicas", "1 Chronicles", "1 cr, 1 cro"),
    ("2CH", 36, "2 Crónicas", "2 Crônicas", "2 Chronicles", "2 cr, 2 cro"),
    ("EZR", 10, "Esdras", "Esdras", "Ezra", "esd"),
    ("NEH", 13, "Nehemías", "Neemias", "Nehemiah", "neh, ne"),
    ("EST", 10, "Ester", "Ester", "Esther", "est"),
    ("JOB", 42, "Job", "Jó", "Job", ""),
    ("PSA", 150, "Salmos", "Salmos", "Psalms", "salmo, sal, sl, psalm, ps"),
    ("PRO", 31, "Proverbios", "Provérbios", "Proverbs", "pr, prov, pv"),
    ("ECC", 12, "Eclesiastés", "Eclesiastes", "Ecclesiastes", "ec, ecl"),
    ("SNG", 8, "Cantares", "Cânticos", "Song of Songs", "cantar de los cantares, cnt, ct, song of solomon"),
    ("ISA", 66, "Isaías", "Isaías", "Isaiah", "is, isa"),
    ("JER", 52, "Jeremías", "Jeremias", "Jeremiah", "jer, jr"),
    ("LAM", 5, "Lamentaciones", "Lamentações", "Lamentations", "lam, lm"),
    ("EZK", 48, "Ezequiel", "Ezequiel", "Ezekiel", "ez"),
    ("DAN", 12, "Daniel", "Daniel", "Daniel", "dn, dan"),
    ("HOS", 14, "Oseas", "Oseias", "Hosea", "os"),
    ("JOL", 3, "Joel", "Joel", "Joel", "jl"),
    ("AMO", 9, "Amós", "Amós", "Amos", "am"),
    ("OBA", 1, "Abdías", "Obadias", "Obadiah", "abd, ob"),
    ("JON", 4, "Jonás", "Jonas", "Jonah", "jon"),
    ("MIC", 7, "Miqueas", "Miqueias", "Micah", "miq, mq"),
    ("NAM", 3, "Nahúm", "Naum", "Nahum", "nah, na"),
    ("HAB", 3, "Habacuc", "Habacuque", "Habakkuk", "hab, hc"),
    ("ZEP", 3, "Sofonías", "Sofonias", "Zephaniah", "sof, sf"),
    ("HAG", 2, "Hageo", "Ageu", "Haggai", "hag, ag"),
    ("ZEC", 14, "Zacarías", "Zacarias", "Zechariah", "zac, zc"),
    ("MAL", 4, "Malaquías", "Malaquias", "Malachi", "mal, ml"),
    ("MAT", 28, "Mateo", "Mateus", "Matthew", "mt, mat"),
    ("MRK", 16, "Marcos", "Marcos", "Mark", "mr, mc, mk"),
    ("LUK", 24, "Lucas", "Lucas", "Luke", "lc, lk"),
    ("JHN", 21, "Juan", "João", "John", "jn, jo"),
    ("ACT", 28, "Hechos", "Atos", "Acts", "hch, at, hechos de los apostoles"),
    ("ROM", 16, "Romanos", "Romanos", "Romans", "ro, rom, rm"),
    ("1CO", 16, "1 Corintios", "1 Coríntios", "1 Corinthians", "1 co, 1 cor"),
    ("2CO", 13, "2 Corintios", "2 Coríntios", "2 Corinthians", "2 co, 2 cor"),
    ("GAL", 6, "Gálatas", "Gálatas", "Galatians", "ga, gal, gl"),
    ("EPH", 6, "Efesios", "Efésios", "Ephesians", "ef, eph"),
    ("PHP", 4, "Filipenses", "Filipenses", "Philippians", "fil, fp, php"),
    ("COL", 4, "Colosenses", "Colossenses", "Colossians", "col, cl"),
    ("1TH", 5, "1 Tesalonicenses", "1 Tessalonicenses", "1 Thessalonians", "1 ts, 1 tes"),
    ("2TH", 3, "2 Tesalonicenses", "2 Tessalonicenses", "2 Thessalonians", "2 ts, 2 tes"),
    ("1TI", 6, "1 Timoteo", "1 Timóteo", "1 Timothy", "1 ti, 1 tim, 1 tm"),
    ("2TI", 4, "2 Timoteo", "2 Timóteo", "2 Timothy", "2 ti, 2 tim, 2 tm"),
    ("TIT", 3, "Tito", "Tito", "Titus", "tit, tt"),
    ("PHM", 1, "Filemón", "Filemom", "Philemon", "flm, fm"),
    ("HEB", 13, "Hebreos", "Hebreus", "Hebrews", "he, heb, hb"),
    ("JAS", 5, "Santiago", "Tiago", "James", "stg, tg"),
    ("1PE", 5, "1 Pedro", "1 Pedro", "1 Peter", "1 p, 1 pe"),
    ("2PE", 3, "2 Pedro", "2 Pedro", "2 Peter", "2 p, 2 pe"),
    ("1JN", 5, "1 Juan", "1 João", "1 John", "1 jn, 1 jo"),
    ("2JN", 1, "2 Juan", "2 João", "2 John", "2 jn, 2 jo"),
    ("3JN", 1, "3 Juan", "3 João", "3 John", "3 jn, 3 jo"),
    ("JUD", 1, "Judas", "Judas", "Jude", "jud, jd"),
    ("REV", 22, "Apocalipsis", "Apocalipse", "Revelation", "ap, apoc, rev"),
]
_NAMES = {"es": 2, "pt": 3, "en": 4}
_ORDINALS = {
    "1": ("primera", "primero", "primer", "primeira", "primeiro", "first", "1a", "1ra", "1ª", "1º", "i"),
    "2": ("segunda", "segundo", "second", "2a", "2da", "2ª", "2º", "ii"),
    "3": ("tercera", "tercero", "tercer", "terceira", "terceiro", "third", "3a", "3ra", "3ª", "3º", "iii"),
}


def _fold(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text.lower())
    return re.sub(r"\s+", " ", "".join(c for c in decomposed if not unicodedata.combining(c))).strip()


def _build_aliases() -> dict[str, tuple]:
    aliases: dict[str, tuple] = {}
    for book in _BOOKS:
        extra = [alias.strip() for alias in book[5].split(",") if alias.strip()]
        for name in [_fold(n) for n in book[2:5]] + extra:
            aliases.setdefault(name, book)
    return aliases


_ALIASES = _build_aliases()
_REFERENCE = re.compile(
    r"^(?P<book>.+?)\s+(?P<chapter>\d{1,3})"
    r"(?:\s*[:.,]\s*(?P<verse>\d{1,3})(?:\s*[-–—]\s*(?P<end>\d{1,3}))?)?"
    r"(?:\s*[-–—]\s*\d{1,3}\s*[:.]\s*\d{1,3})?$"
)


def _find_book(raw: str) -> tuple | None:
    name = _fold(raw).replace(".", "")
    name = re.sub(r"\b(de|of|a los|aos|a|carta|epistola|libro|evangelio|segun|san)\b", " ", name)
    words = name.split()
    if words:
        for number, forms in _ORDINALS.items():
            if words[0] in forms:
                words[0] = number
    return _ALIASES.get(" ".join(words))


def parse_reference(reference: str, language: str = "es") -> dict | None:
    """Returns {reference, book, chapter, verse_start, verse_end} or None when it is not a real reference.

    Chapter ranges are checked against the book; verse numbers are only sanity-checked.
    """
    match = _REFERENCE.match(reference.strip().rstrip("."))
    if not match:
        return None
    book = _find_book(match["book"])
    if not book:
        return None
    chapter = int(match["chapter"])
    verse = int(match["verse"]) if match["verse"] else None
    end = int(match["end"]) if match["end"] else None
    if not 1 <= chapter <= book[1] or (verse is not None and not 1 <= verse <= 176):
        return None
    if end is not None and end <= (verse or 0):
        end = None
    label = f"{book[_NAMES.get(language, 2)]} {chapter}"
    if verse:
        label += f":{verse}" + (f"-{end}" if end else "")
    return {"reference": label, "book": book[0], "chapter": chapter, "verse_start": verse, "verse_end": end}


def external_reader_url(reference: str, version_code: str = "RVR1960") -> str:
    return f"{settings.bible_external_reader_base_url}?{urlencode({'search': reference, 'version': version_code})}"
