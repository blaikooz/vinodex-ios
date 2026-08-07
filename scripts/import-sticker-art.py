#!/usr/bin/env python3
"""Imports the per-skin back-plate sticker glyphs into the app bundle (0.7.8, A1).

Sources are individual PNGs in **art/icons/chrome/stickers** (0.8.5, F1), one per
shell. Same treatment as the other importers: background removed via
art_common.py (export on a magenta chroma key for the robust path),
palette-quantised, written to Sources/VinodexUI/Resources/StickerArt.

**The source directory moved and the naming rule changed with it (0.8.5, F1),
and `STEM_FOR` below is the whole of why.** Through 0.8.4 this read
art/icons/stickers -- which never held a single file -- and copied each
filename through verbatim on the contract that an illustrator would deliver
`sticker-<skin raw value, kebab-case>.png`. The drop that actually arrived is
twenty files named for what is *drawn on them*: `champagnegold.png`,
`boxwine.png`, `vinjaune.png`. That is the right way round for the person
drawing them and the wrong way round for `ChassisSkin.stickerStem`, which
derives its lookup from the **persisted raw value** and cannot move -- the same
rawValue is an `@AppStorage` key and the FNV-1a seed for `WornOverlay`, so
renaming a skin to match its art would reset a user's shell and re-roll its
wear pattern.

So the map is written down here rather than derived. Two of the twenty needed
it beyond simple kebab-casing and both would have been silent:

- `vinhoverde.png` is the decal for **NOCTURNE**, whose display name is VINHO
  VERDE. There is also a skin whose *raw value* is `VINHO VERDE`, displayed as
  BOX WINE, and its decal is `boxwine.png`. A rule derived from either the
  display name or the raw value alone puts one of these two on the wrong shell,
  and nothing would have reported it -- a sticker that resolves is a sticker
  that resolves.
- `fiberglass.png` is **PET NAT**. The rename is 0.7.3b's and the raw value has
  not moved for the reason above.

Twenty files against twenty-two shells. CHRISTMAS and ORANGE WINE have no decal
drawn and keep `SkinEmblem`, which is the fallback working rather than a gap --
and `StickerRosterTests` names both, two-way, so the shortfall cannot rot into
an excuse and a file arriving for one of them cannot land unnoticed.

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

# Source file stem -> `ChassisSkin` raw value. The bundle stem is
# `sticker-<value, lowercased, spaces to hyphens>`, which is exactly what
# `ChassisSkin.stickerStem` computes on the Swift side; changing that expression
# changes this one. Read the module note before touching either.
#
# `StickerRosterTests` asserts this table against `ChassisSkin.allCases` in both
# directions, so a skin added without a decal and a decal named for no skin are
# both build failures rather than a blank corner of the back plate.
SKIN_FOR = {
    "vinodexclassic": "CLASSIC",
    "cotedenuits": "MIDNIGHT",
    "blancdeblancs": "ORIGINAL",
    "burgundy": "BURGUNDY",
    "vinjaune": "RIESLING",
    "boxwine": "VINHO VERDE",
    "emptybottle": "GLOUGLOU",
    "smartgrape": "SMART GRAPE",
    "champagnegold": "CHAMPAGNE",
    "retrovin": "NOUVEAU",
    "oaked": "OAKED",
    # Not VINHO VERDE. See the module note -- this is the pair that would have
    # gone wrong silently.
    "vinhoverde": "NOCTURNE",
    "steel": "STEEL",
    "blush": "BLUSH",
    "psvino": "PSVINO",
    "grisdegris": "GRIS DE GRIS",
    "fiberglass": "PET NAT",
    "waldglas": "WALDGLAS",
    "hallowine": "HALLOWEEN",
    "w64": "W64",
}

PREFIX = "sticker-"


def bundle_stem(skin_raw_value):
    """`ChassisSkin.stickerStem`, in Python. One expression, two languages."""
    return PREFIX + skin_raw_value.lower().replace(" ", "-")


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.path.join(ROOT, "art", "icons", "chrome", "stickers")


def main():
    src = source_dir()
    if not os.path.isdir(src):
        print(f"no artifact art yet ({src} absent) — the skin emblems keep the slots")
        return

    stems = sorted(
        os.path.splitext(name)[0]
        for name in os.listdir(src)
        if name.lower().endswith(".png")
    )
    if not stems:
        print(f"no artifact art yet ({src} empty) — the skin emblems keep the slots")
        return

    os.makedirs(DST, exist_ok=True)
    total_out = 0
    unmapped = []
    for stem in stems:
        skin = SKIN_FOR.get(stem)
        if skin is None:
            # Loud rather than silent, and skipped rather than guessed: a decal
            # copied through under its own name would resolve for no skin and
            # sit in the bundle looking like it had been wired.
            unmapped.append(stem)
            continue
        img = strip_background(Image.open(os.path.join(src, stem + ".png")))
        out = os.path.join(DST, bundle_stem(skin) + ".png")
        # `quantize_stable` + `save_stable` since 0.8.0 (A0b): no library
        # default decides the palette, and a run whose pixels match writes
        # nothing. See art_common for both arguments.
        save_stable(quantize_stable(img), out, optimize=True)
        total_out += os.path.getsize(out)

    done = len(stems) - len(unmapped)
    print(f"converted {done} shell decals -> {DST} ({total_out // 1024}KB)")
    if unmapped:
        print(f"  !! no skin mapped for: {', '.join(unmapped)} — add them to SKIN_FOR")


if __name__ == "__main__":
    main()
