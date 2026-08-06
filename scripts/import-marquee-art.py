#!/usr/bin/env python3
"""Imports the dot-matrix marquee glyphs into the app bundle (0.8.4, A1).

Sources are individual PNGs in art/icons/marqueeglyphs, one per page the
marquee can name (`grapescan`, `system`, `mastersearch`, `menu`, ...), drawn as
a grid of cream dots on a magenta chroma key. Written to
Sources/VinodexUI/Resources/MarqueeArt.

**Why this is not `import-button-art.py` with thirty-four more files in it.**
The 0.8.1 button faces are pictures drawn to sit *inside* a moulded control on
the chassis, in that control's colourway. These are drawn for one surface and
one surface only: a segment LCD, where the ground is what lights and the glyph
is what the liquid crystal blocks. They are a different register of the same
subject -- `grapescan` here is a bunch of grapes rendered in eleven dots, and
`grapes` under buttons/ is a painted bunch with shading -- and eleven of the
stems collide outright (`settings`, `system`, `shop`, `tools`, `data`, `dev`,
`user`, `customize`, `passport`, `firmware`, `haptics`, `whatsthat`,
`moondial`, `tutorial`, `cheatcodes`, `labelscanner`, `blindtasting`,
`dailychallenge`, `wineexam`). Merging the directories would have overwritten
seventeen button faces with dot-matrix versions of themselves.

**Stems carry a `marquee-` prefix**, following `footer-`, `cartridge-`,
`stamp-` and `sticker-` rather than adding a second bare-word directory to
`PixelArtLoader`'s flat namespace -- which is exactly what that loader's
`ButtonArt` note asks the next importer to do.

--------------------------------------------------------------------------
The one transform, and why these get one when the button faces do not
--------------------------------------------------------------------------

`import-button-art.py` argues at length for shipping chrome exactly as drawn:
the illustrator fitted it to its control and a downscale here would second-guess
that invisibly. That argument is about *geometry* and it still holds -- nothing
below resizes or crops.

What these need is an alpha ramp. `art_common.strip_background` keys out the
pure magenta and leaves everything with a green channel above 80, which on a
dot-matrix drawing is the entire antialiased rim of every dot: measured across
the drop, 4,100 pixels per file are solid cream and roughly 2,900 more are the
cream/magenta blend around them. Those survive import at full alpha, and since
`DexChromeGlyph` renders these through `flatten:` -- `.renderingMode(.template)`,
which keeps alpha and discards colour -- a partly-magenta rim is not a soft edge,
it is *part of the silhouette*. Every dot would draw one pixel fat with a hard
edge, and the grid would close up.

So alpha is derived from how far a pixel sits along the key-to-ink line, and the
green channel is that axis: the key is at g=5, the ink at g=247, and nothing in
these files is anywhere else (measured: zero pixels below value 110 in all 34,
so there is no cel outline to protect and no dark subject to misread). The
result is a two-colour image -- ink, at the alpha it was drawn with -- which
`quantize_stable` returns untouched, so these are bit-identical on any machine.

Deliberately tolerant of an empty or missing source dir, as the stamp, sticker,
button, footer and cartridge importers are: every glyph falls back to the SF
Symbol the marquee drew before, so "nothing to import" is a note, not a failure.

Usage: python3 scripts/import-marquee-art.py [source-dir]
Requires Pillow.
"""
import os
import sys

from PIL import Image

from art_common import output_dir, quantize_stable, save_stable

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
# `ART_OUT`-aware like every other importer: `verify-art.py` regenerates into a
# temp tree, and an importer ignoring the redirect turns `npm run icons:verify`
# into a write (0.7.5, A027).
DST = output_dir(ROOT, "MarqueeArt")

# The prefix that keeps these out of the flat stem namespace. Matched by
# `DexRoute.marqueeArt` on the Swift side; changing it here changes it there.
PREFIX = "marquee-"

# The colour every dot is written as. Value is irrelevant to the app -- the
# marquee draws these as a silhouette in the panel's own ink -- so one flat
# colour keeps the palette at two entries and the file at a few hundred bytes.
# Cream rather than white so a stray direct render (an inspector, a diff tool)
# still looks like the art it came from.
INK = (250, 244, 200)

# The key's green channel, and the ink's. Anything at or below `KEY_G` is
# background; at or above `INK_G` is solid; between is the drawn rim.
KEY_G = 20
INK_G = 224


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.path.join(ROOT, "art", "icons", "marqueeglyphs")


def key_to_alpha(img):
    """Magenta key -> alpha, along the green axis. See the module note."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    span = INK_G - KEY_G
    solid = 0
    for y in range(h):
        for x in range(w):
            g = px[x, y][1]
            if g <= KEY_G:
                px[x, y] = (INK[0], INK[1], INK[2], 0)
            elif g >= INK_G:
                px[x, y] = (INK[0], INK[1], INK[2], 255)
                solid += 1
            else:
                px[x, y] = (INK[0], INK[1], INK[2], int(255 * (g - KEY_G) / span))
    return img, solid


def main():
    src = source_dir()
    if not os.path.isdir(src):
        print(f"no marquee glyph art yet ({src} absent) — the SF Symbols keep the panel")
        return

    stems = sorted(
        os.path.splitext(name)[0]
        for name in os.listdir(src)
        if name.lower().endswith(".png")
    )
    if not stems:
        print(f"no marquee glyph art yet ({src} empty) — the SF Symbols keep the panel")
        return

    os.makedirs(DST, exist_ok=True)
    total_out = 0
    total_solid = 0
    for stem in stems:
        img, solid = key_to_alpha(Image.open(os.path.join(src, stem + ".png")))
        total_solid += solid
        out = os.path.join(DST, PREFIX + stem + ".png")
        # `quantize_stable` + `save_stable` since 0.8.0 (A0b): no library
        # default decides the palette, and a run whose pixels match writes
        # nothing. Two colours in means the quantiser is never reached.
        save_stable(quantize_stable(img), out, optimize=True)
        total_out += os.path.getsize(out)

    print(
        f"converted {len(stems)} marquee glyphs -> {DST} ({total_out // 1024}KB), "
        f"{total_solid} solid dot pixels"
    )


if __name__ == "__main__":
    main()
