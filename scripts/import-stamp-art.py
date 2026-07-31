#!/usr/bin/env python3
"""Imports the back-plate stamp & sticker glyphs into the app bundle (0.6.4, F2/F3).

Sources are individual PNGs in art/icons/stamps — `stamp-<badge>` for the
postage-stamp glyphs (see StampCatalog in VinodexCore) and `sticker-<skin>`
for the per-skin aged stickers (see ChassisSkin.stickerStem). Same treatment
as the other importers: background removed via art_common.py (export on a
magenta chroma key for the robust path), palette-quantised, written to
Sources/VinodexUI/Resources/StampArt.

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

from art_common import strip_background

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DST = os.path.join(ROOT, "Sources", "VinodexUI", "Resources", "StampArt")


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
        img.quantize(colors=256).save(out, optimize=True)
        total_out += os.path.getsize(out)

    print(f"converted {len(stems)} stamp glyphs -> {DST} ({total_out // 1024}KB)")


if __name__ == "__main__":
    main()
