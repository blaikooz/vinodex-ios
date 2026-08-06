#!/usr/bin/env python3
"""Imports the per-skin back-plate sticker glyphs into the app bundle (0.7.8, A1).

Sources are individual PNGs in art/icons/stickers, one per shell, named
`sticker-<skin raw value, kebab-case>` (see `ChassisSkin.stickerStem` in
Sources/VinodexUI/SkinSticker.swift). Same treatment as the other importers:
background removed via art_common.py (export on a magenta chroma key for the
robust path), palette-quantised, written to
Sources/VinodexUI/Resources/StickerArt.

**Why this is not `import-stamp-art.py`.** Until 0.7.8 the per-skin sticker and
the six Passport badge stamps shared one source directory, one importer and one
bundle directory, because 0.6.5 had made the sticker *render* as a postage
stamp. A1 undoes that: the sticker is the shell's own decal, drawn on a die-cut
silhouette that has nothing to do with the stamps' perforated frame, and it is
decoration where the stamps are a collection. Two families of art commissioned
against two different briefs are two namespaces — sharing one meant an
illustrator delivering a shell decal could land it in the stamps' folder and
nothing anywhere would notice, since neither set is enumerated by
`assertAssetsExist` (both resolve through code-drawn stand-ins, so a
misfiled or missing file is silent by design).

Deliberately tolerant of an empty or missing source dir, exactly as the stamp
importer is: every skin ships with the emblem standing in for its decal, and
each authored PNG that lands here replaces its stand-in on the next
`npm run icons` — no code change involved. So "nothing to import" is a note,
not a failure.

Usage: python3 scripts/import-sticker-art.py [source-dir]
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
DST = output_dir(ROOT, "StickerArt")


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.path.join(ROOT, "art", "icons", "stickers")


def main():
    src = source_dir()
    if not os.path.isdir(src):
        print(f"no sticker art yet ({src} absent) — the skin emblems keep the slots")
        return

    stems = sorted(
        os.path.splitext(name)[0]
        for name in os.listdir(src)
        if name.lower().endswith(".png")
    )
    if not stems:
        print(f"no sticker art yet ({src} empty) — the skin emblems keep the slots")
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

    print(f"converted {len(stems)} sticker glyphs -> {DST} ({total_out // 1024}KB)")


if __name__ == "__main__":
    main()
