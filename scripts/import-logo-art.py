#!/usr/bin/env python3
"""Import the Vinodex wordmark master into the two tinted layers the app ships.

The master (``art/icons/<folder>/vinodex-dvd-icon.png``) is a 1024x1024 render
with a clean alpha channel: a white glyph face over a darker extruded edge, and
nothing else -- the glow visible in an alpha-ignoring viewer sits entirely in
pixels the alpha already discards.

**Why two files rather than one.** The mark is drawn on the LCD, and every
themed surface in this app takes its colour from an ``lcd.*`` token rather than
from a hex baked into a PNG (the house rule 0.6.2 settled on, and the reason
`GrapeSpriteLoader` recolours the rarity leaf in code). Shipping the master's
white-and-grey would put two fixed colours on a screen whose ink the user
chooses. So the import splits the glyph on luminance into a *face* and a
*shade* mask, ships both as white-on-alpha silhouettes, and lets
``ScreensaverMark`` tint them -- face to the ink, shade to a dimmed ink -- so
the mark reads as the same relief on all twenty-one LCD modes.

The split is unambiguous: the master's opaque pixels are bimodal at L=240 and
L=80 with 381 pixels between the two, so any threshold in the middle produces
the same masks. 160 is used.

Alpha is re-thresholded after the downscale so the edges stay hard. The mark is
pixel art; a Lanczos alpha ramp would fringe it against the LCD ground exactly
the way 0.6.2's glyph-fringe pass had to correct elsewhere.

Run from anywhere::

    python3 scripts/import-logo-art.py

Idempotent, and the corrections live here rather than in the shipped PNGs, so a
re-import keeps them.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from art_common import output_dir, save_stable

REPO = Path(__file__).resolve().parent.parent

# The master's folder name is an artist's filing convention and is not a name
# this project uses for anything: no type, comment, string or shipped file
# repeats it. The output below is the naming the app knows.
MASTER = REPO / "art" / "icons" / "dvd" / "vinodex-dvd-icon.png"
# Through `art_common.output_dir` rather than a literal path so `ART_OUT`
# redirects it, which is what lets `scripts/verify-art.py` re-run this importer
# into a temp tree instead of rewriting the working copy (0.7.5, A026). Every
# other importer already went through it; this one was written outside the
# roster and hard-coded the destination.
OUT_DIR = Path(output_dir(REPO, "Logo"))

FACE_OUT = OUT_DIR / "vinodex-mark-face.png"
SHADE_OUT = OUT_DIR / "vinodex-mark-shade.png"

#: Luminance above this is the lit face, below it the extruded edge.
SPLIT = 160

#: Alpha at or above this survives the downscale as fully opaque.
ALPHA_CUT = 128

#: Longest edge of the shipped masks. The screensaver draws the mark at roughly
#: a third of the LCD width, so 320 covers a 3x render on any device this build
#: targets without shipping a megabyte of transparent pixels.
TARGET = 320


def _masks(src: Image.Image) -> tuple[Image.Image, Image.Image]:
    """Split ``src`` into (face, shade) alpha masks, full resolution."""
    src = src.convert("RGBA")
    px = src.load()
    w, h = src.size
    face = Image.new("L", (w, h), 0)
    shade = Image.new("L", (w, h), 0)
    fpx, spx = face.load(), shade.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < ALPHA_CUT:
                continue
            lum = (r * 299 + g * 587 + b * 114) // 1000
            if lum >= SPLIT:
                fpx[x, y] = 255
            else:
                spx[x, y] = 255
    return face, shade


def _shipped(mask: Image.Image, size: tuple[int, int]) -> Image.Image:
    """White pixels carrying ``mask`` as alpha, downscaled with hard edges."""
    small = mask.resize(size, Image.LANCZOS).point(
        lambda p: 255 if p >= ALPHA_CUT else 0
    )
    white = Image.new("RGBA", size, (255, 255, 255, 255))
    white.putalpha(small)
    return white


def main() -> None:
    if not MASTER.exists():
        raise SystemExit(f"master not found: {MASTER}")
    src = Image.open(MASTER)

    # Crop to the glyph before scaling -- the master is a 1024 square holding a
    # 880x720 mark, and keeping the padding would waste a fifth of the target.
    bbox = src.convert("RGBA").split()[3].point(
        lambda p: 255 if p >= ALPHA_CUT else 0
    ).getbbox()
    if bbox is None:
        raise SystemExit("master has no opaque pixels")
    src = src.crop(bbox)

    face, shade = _masks(src)
    w, h = src.size
    scale = TARGET / max(w, h)
    size = (max(1, round(w * scale)), max(1, round(h * scale)))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    # `save_stable`, not `save`: the two encoders in use across this project's
    # machines write identical pixels as different bytes, so a plain save leaves
    # a modified binary in the working tree after every `npm run icons`. See
    # `art_common.save_stable` for the measurement.
    for mask, out in ((face, FACE_OUT), (shade, SHADE_OUT)):
        wrote = save_stable(_shipped(mask, size), out)
        print(f"{out.name:24} {size[0]}x{size[1]}  {'written' if wrote else 'unchanged'}")


if __name__ == "__main__":
    main()
