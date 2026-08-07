#!/usr/bin/env python3
"""Imports the drawn pack cartridges into the app bundle (0.8.2, coordinator 5).

Sources are individual PNGs in art/icons/cartridges, one per thing the shop
sells — twelve expansion packs and five standalone upgrades. Background removed
via art_common.py, palette-quantised, written to
Sources/VinodexUI/Resources/CartridgeArt.

**Stems are the art's own, prefixed, and are mapped to entitlements in Swift.**
`CartridgeArt.stem(for:)` in VinodexCore holds the table, because the art is
named for the product as the illustrator thinks of it and the app is keyed on
entitlement ids that are *persisted* — `pack:display-retro`, `lightMode`,
`pro`. Those two vocabularies disagree in three places on purpose (see that
file), and the honest place to reconcile them is one readable table under test,
not a rename in either direction. `CartridgeArtTests` fails if a stem here has
no product or a product names a stem that is not here.

The `footer-`/`stamp-`/`sticker-` prefix convention applies for the same reason
it does there: `PixelArtLoader` resolves a flat, global stem namespace across
every search directory, and `classic`, `vessel`, `festive` and `wines` are
exactly the kind of bare word a future flavour or style could land on.

**These are per-product colour, and that is a reversal worth naming.** 0.7.3c's
A2 built `PackCartridge` out of `lcd` tokens with no per-pack hue, on the
argument that twelve chosen colours arrive as twelve identical greys under the
four single-phosphor modes. That argument was about *colour carrying the
identity*. These carry it in the drawing — a map of Europe, a crowned V, a
knurled dial — which survives `colorMultiply` down to a monochrome screen as
twelve different pictures. The code-drawn cartridge stays as the fallback for
everything with no art (country packs, the flavour wheel), so both paths remain
live rather than one being deleted on the strength of a partial art drop.

Shipped at source resolution: the shop draws these at 46pt and the splash draws
the same file three times larger, so an import-time downscale would either
starve the splash or waste the shelf.

Reproducibility is 0.8.0's A0b — `quantize_stable` and `save_stable`, so a
second run over unchanged art writes nothing.

Tolerant of an empty or missing source dir like its siblings: every cartridge
falls back to `PackCartridge`'s drawing.

Usage: python3 scripts/import-cartridge-art.py [source-dir]
Requires Pillow.
"""
import os
import sys

from PIL import Image

from art_common import output_dir, quantize_stable, save_stable, strip_background

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DST = output_dir(ROOT, "CartridgeArt")

# Matched by `CartridgeArt.prefix` on the Swift side.
PREFIX = "cartridge-"


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.path.join(ROOT, "art", "icons", "chrome", "cartridges")


def main():
    src = source_dir()
    if not os.path.isdir(src):
        print(f"no cartridge art yet ({src} absent) — the drawn cartridge keeps the shelf")
        return

    stems = sorted(
        os.path.splitext(name)[0]
        for name in os.listdir(src)
        if name.lower().endswith(".png")
    )
    if not stems:
        print(f"no cartridge art yet ({src} empty) — the drawn cartridge keeps the shelf")
        return

    os.makedirs(DST, exist_ok=True)
    total_out = 0
    for stem in stems:
        img = strip_background(Image.open(os.path.join(src, stem + ".png")))
        out = os.path.join(DST, PREFIX + stem + ".png")
        save_stable(quantize_stable(img), out, optimize=True)
        total_out += os.path.getsize(out)

    print(f"converted {len(stems)} cartridges -> {DST} ({total_out // 1024}KB)")


if __name__ == "__main__":
    main()
