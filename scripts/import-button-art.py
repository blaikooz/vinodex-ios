#!/usr/bin/env python3
"""Imports the drawn button faces into the app bundle (0.8.1, J2).

Sources are individual PNGs in art/icons/buttons, one per button face, named
for the control they sit on (`search`, `passport`, `labelscanner`, ...). Same
treatment as the other importers: background removed via art_common.py (export
on a magenta chroma key for the robust path), palette-quantised, written to
Sources/VinodexUI/Resources/ButtonArt.

**These are chrome, not catalog art.** Every other importer here converts a
picture *of* something the database names — a flavour, a grape, a style, a
place. This one converts the app's own furniture: the glyph on a button face,
drawn once against the chassis rather than commissioned per entry. That is why
there is no stem table and no manifest to check against, only the directory
listing — the roster of buttons is whatever the UI puts a button on, and the
gate on a missing one is the view that draws nothing, not a generator error.

Shipped at source resolution with only the palette normalised. No resize, no
crop, no padding: chrome is drawn to fit its control by the illustrator, and a
downscale here would be this script second-guessing that at import time, on
somebody's laptop, invisibly. The one transform is the quantise, and it exists
to hold the bundle down rather than to change how anything looks.

Reproducibility is 0.8.0's A0b, same as everywhere else: `quantize_stable`
pins the method and dither so no library default picks the palette, and
`save_stable` leaves a file whose pixels already match alone. So a second run
over unchanged art writes nothing, and `git status` after `npm run icons` stays
a real signal.

Deliberately tolerant of an empty or missing source dir, as the stamp and
sticker importers are: the button faces resolve through code-drawn stand-ins,
so "nothing to import" is a note, not a failure.

Usage: python3 scripts/import-button-art.py [source-dir]
Requires Pillow.
"""
import os
import sys

from PIL import Image

from art_common import output_dir, quantize_stable, save_stable, strip_background

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
# `ART_OUT`-aware for the same reason as every other importer: `verify-art.py`
# regenerates into a temp tree, and an importer that ignored the redirect would
# turn `npm run icons:verify` into a write (0.7.5, A027).
DST = output_dir(ROOT, "ButtonArt")


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.path.join(ROOT, "art", "icons", "buttons")


def main():
    src = source_dir()
    if not os.path.isdir(src):
        print(f"no button art yet ({src} absent) — the stand-in glyphs keep the faces")
        return

    stems = sorted(
        os.path.splitext(name)[0]
        for name in os.listdir(src)
        if name.lower().endswith(".png")
    )
    if not stems:
        print(f"no button art yet ({src} empty) — the stand-in glyphs keep the faces")
        return

    os.makedirs(DST, exist_ok=True)
    total_out = 0
    for stem in stems:
        img = strip_background(Image.open(os.path.join(src, stem + ".png")))
        out = os.path.join(DST, stem + ".png")
        # `quantize_stable` + `save_stable` since 0.8.0 (A0b): no library
        # default decides the palette, and a run whose pixels match writes
        # nothing. See art_common for both arguments.
        save_stable(quantize_stable(img), out, optimize=True)
        total_out += os.path.getsize(out)

    print(f"converted {len(stems)} button faces -> {DST} ({total_out // 1024}KB)")


if __name__ == "__main__":
    main()
