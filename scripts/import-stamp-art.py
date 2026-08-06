#!/usr/bin/env python3
"""Imports the back-plate Passport stamp glyphs into the app bundle (0.6.4, F2).

Sources are individual PNGs in art/icons/stamps, one per Passport badge, named
`stamp-<badge>` (see StampCatalog in VinodexCore). Same treatment as the other
importers: background removed via art_common.py (export on a magenta chroma key
for the robust path), palette-quantised, written to
Sources/VinodexUI/Resources/StampArt.

**Stamps only since 0.7.8 (A1).** The per-skin `sticker-<skin>` glyphs used to
ride this importer too, from this same directory into this same bundle folder,
because 0.6.5 had made the per-skin artifact render as a postage stamp. It is a
die-cut decal again and it has its own pipeline now:
art/icons/stickers -> scripts/import-sticker-art.py -> Resources/StickerArt.

Deliberately tolerant of an empty or missing source dir: the stamp system
ships with code-drawn frames and SF Symbol stand-in glyphs, and each authored
PNG that lands here replaces its stand-in on the next `npm run icons` — no
code change involved. So "nothing to import" is a note, not a failure.

Usage: python3 scripts/import-stamp-art.py [source-dir]
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
DST = output_dir(ROOT, "StampArt")


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.path.join(ROOT, "art", "icons", "stamps")


def main():
    src = source_dir()
    if not os.path.isdir(src):
        print(f"no stamp art yet ({src} absent) — SF stand-ins keep the slots")
        return

    stems = sorted(
        os.path.splitext(name)[0]
        for name in os.listdir(src)
        if name.lower().endswith(".png")
    )
    if not stems:
        print(f"no stamp art yet ({src} empty) — SF stand-ins keep the slots")
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

    print(f"converted {len(stems)} stamp glyphs -> {DST} ({total_out // 1024}KB)")


if __name__ == "__main__":
    main()
