#!/usr/bin/env python3
"""Imports the back-plate Passport stamp glyphs into the app bundle (0.6.4, F2).

Sources are individual PNGs in art/icons/chrome/stamps. Same treatment as the other
importers: background removed via art_common.py (export on a magenta chroma key
for the robust path), palette-quantised, written to
Sources/VinodexUI/Resources/StampArt.

**`STEM_FOR` is new in 0.8.5 (F1) and it is here for the reason the sticker
importer's `SKIN_FOR` is.** This copied each filename through verbatim on the
contract that the illustrator would deliver `stamp-first-sip.png` and the rest
-- the exact `artStem` strings on `StampCatalog`. What arrived is named for the
picture (`firstsip`, `allnoble`, `tenbottles`), which is how a person draws and
not how `StampCatalogTests` looks things up. A verbatim copy would have put ten
files in the bundle that nothing asks for, and left all six badges on their SF
Symbol stand-ins with no error anywhere: neither this family nor the stickers is
enumerated by `assertAssetsExist`, precisely because both resolve through
code-drawn stand-ins.

The drop is ten files, and only six of them are Passport badges. The other four
are back-plate decals: the barcode label and the ripped price tag, which replace
the `Canvas`-drawn versions `DeviceBackPlate` has carried since 0.6.4, and two
loose postage stamps for the plate itself. They are prefixed and mapped here for
the same reason the badges are -- so what the bundle holds is the list Swift
asks for, and `StampRosterTests` asserts the two ends against each other.

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

# Source file stem -> bundle stem. The eight badges are `StampCatalog.artStem`
# verbatim; the two decals are `BackPlateDecal.artStem` on the Swift side.
# `StampRosterTests` asserts this table against both, in both directions.
STEM_FOR = {
    # The eight Passport badges.
    "firstsip": "stamp-first-sip",
    "tenbottles": "stamp-ten-bottles",
    "allnoble": "stamp-all-noble",
    "regioncomplete": "stamp-region-complete",
    "streakweek": "stamp-streak-week",
    "sommelier": "stamp-sommelier",
    # **The two completions, and this pair of rows is 0.8.7's item 4 (A1).**
    # 0.8.6's C6 read the same two files as the plate's franking and minted
    # `stamp-all-grapes` / `stamp-all-styles` for the badges, on the grounds
    # that the decals were drawn, shipped and on screen. That decision is
    # reversed by the person who drew them: these two pictures are TRIED ALL
    # GRAPES and TRIED ALL STYLES, and the two loose decals they were wired to
    # are gone from the plate rather than re-drawn.
    #
    # The *stems* stay spelled for what they are, which is this directory's rule
    # since 0.8.5 -- what moved is which source file feeds them. Nothing here
    # derives a stem from a filename, so a file renamed on the illustrator's
    # disk is one row of this table.
    "stamp1": "stamp-all-grapes",
    "stamp2": "stamp-all-styles",
    # The two back-plate decals (0.8.5, F1). `stamp-` rather than a third
    # prefix: they ship in this directory, they are drawn to the same brief, and
    # `PixelArtLoader`'s namespace is flat -- a second prefix here would buy
    # nothing and cost the loader another entry to reason about.
    "barcode": "stamp-barcode",
    "pricesticker": "stamp-price-tag",
}


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.path.join(ROOT, "art", "icons", "chrome", "stamps")


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
    unmapped = []
    for stem in stems:
        target = STEM_FOR.get(stem)
        if target is None:
            unmapped.append(stem)
            continue
        img = strip_background(Image.open(os.path.join(src, stem + ".png")))
        out = os.path.join(DST, target + ".png")
        # `quantize_stable` + `save_stable` since 0.8.0 (A0b): no library
        # default decides the palette, and a run whose pixels match writes
        # nothing. See art_common for both arguments.
        save_stable(quantize_stable(img), out, optimize=True)
        total_out += os.path.getsize(out)

    done = len(stems) - len(unmapped)
    print(f"converted {done} stamps and decals -> {DST} ({total_out // 1024}KB)")
    if unmapped:
        print(f"  !! no stem mapped for: {', '.join(unmapped)} — add them to STEM_FOR")


if __name__ == "__main__":
    main()
