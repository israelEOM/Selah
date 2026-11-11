"""Turns a source photo into the landing page's hero images and its link-preview image.

    python3 site/hero.py path/to/photo.png

Writes site/src/img/hero-{720,1280,1920}.webp with cwebp and site/src/img/og.png (1200×630) with sips (macOS).
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(HERE, "src", "img")

sys.path.insert(0, HERE)
from build import HERO_WIDTHS  # noqa: E402


def main(source: str) -> None:
    if not shutil.which("cwebp"):
        sys.exit("cwebp is missing: brew install webp")
    for width in HERO_WIDTHS:
        target = os.path.join(IMG, f"hero-{width}.webp")
        subprocess.run(["cwebp", "-quiet", "-q", "78", "-resize", str(width), "0", source, "-o", target], check=True)
        print(f"{target}  {os.path.getsize(target) // 1024} KB")
    # Link preview: fill 1200 wide, then crop the middle to 630 tall.
    with tempfile.TemporaryDirectory() as tmp:
        wide = os.path.join(tmp, "wide.png")
        subprocess.run(["sips", "-s", "format", "png", "--resampleWidth", "1200", source, "--out", wide],
                       check=True, capture_output=True)
        og = os.path.join(IMG, "og.png")
        subprocess.run(["sips", "--cropToHeightWidth", "630", "1200", wide, "--out", og], check=True, capture_output=True)
        print(f"{og}  {os.path.getsize(og) // 1024} KB")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
