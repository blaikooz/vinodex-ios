#!/usr/bin/env python3
"""Imports the painted UI glyphs into the app bundle (0.8.9a, A2).

Sources are individual PNGs in art/icons/chrome/glyphs, one per glyph, named
for the thing drawn rather than for the control it lands on (`cog`, `firmware`,
`trophy`, `level1`...). Written to Sources/VinodexUI/Resources/GlyphArt with a
`glyph-` prefix.

**Why this is not `import-button-art.py` with twenty more files in it.**
Register-wise it would be: measured across the drop these are the same drawing
as `chrome/buttons` — magenta chroma key, a near-black cel outline over
13-25% of the canvas, cream highlights at (247, 222, 182) — where the marquee
set beside them carries no outline at all. What differs is *namespace*.
`ButtonArt`'s own note in `PixelArtLoader.subdirectories` says its stems are
bare words in a flat global namespace, that ordering it last is a guard rather
than a guarantee, and asks the next directory to carry a prefix the way
`footer-`, `cartridge-`, `stamp-`, `sticker-` and `marquee-` do. This is that
directory, and the ask is not theoretical here: `tools`, `firmware`, `seal`
and `stamp` are words already spoken for by `ButtonArt`, `MarqueeArt` or
`StampArt`, and three of those are live art an unprefixed stem could have
shadowed by list order.

**No rename map, deliberately.** `import-stamp-art.py` and
`import-sticker-art.py` carry a dict from the picture's name to the app's name
because both drops arrived named for what is drawn on them; a wrong row in
either is invisible at runtime, which is why `ArtPipelineRosterTests` checks
them at three joints. These files were renamed *once*, on the way in from the
delivery folder, so the stem is the filename and there is nothing to drift. The
gate that remains is `UIGlyph`, which names the twenty in Core so the directory,
the type and the bundle can be held equal.

Shipped at source resolution with only the palette normalised, on
`import-button-art.py`'s argument: chrome is drawn to fit by the illustrator and
a downscale here would second-guess that at import time, on somebody's laptop,
invisibly.

Deliberately tolerant of an empty or missing source dir, as every chrome
importer is: each call site passes an SF Symbol to `DexChromeGlyph`, so
"nothing to import" is a note, not a failure.

Usage: python3 scripts/import-glyph-art.py [source-dir]
Requires Pillow.
"""
import os
import sys

from PIL import Image

from art_common import output_dir, quantize_stable, save_stable, strip_background

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
# `ART_OUT`-aware like every other importer: `verify-art.py` regenerates into a
# temp tree, and an importer ignoring the redirect turns `npm run icons:verify`
# into a write (0.7.5, A027).
DST = output_dir(ROOT, "GlyphArt")

# The prefix that keeps these out of the flat stem namespace. Restated by
# `UIGlyph.artStem` on the Swift side; changing it here changes it there, and
# `ArtPipelineRosterTests.glyphRosterIsComplete` is where the two are held
# together.
PREFIX = "glyph-"


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.path.join(ROOT, "art", "icons", "chrome", "glyphs")


def main():
    src = source_dir()
    if not os.path.isdir(src):
        print(f"no UI glyph art yet ({src} absent) — the SF Symbols keep the rows")
        return

    stems = sorted(
        os.path.splitext(name)[0]
        for name in os.listdir(src)
        if name.lower().endswith(".png")
    )
    if not stems:
        print(f"no UI glyph art yet ({src} empty) — the SF Symbols keep the rows")
        return

    os.makedirs(DST, exist_ok=True)
    total_out = 0
    for stem in stems:
        img = strip_background(Image.open(os.path.join(src, stem + ".png")))
        out = os.path.join(DST, PREFIX + stem + ".png")
        # `quantize_stable` + `save_stable` since 0.8.0 (A0b): no library
        # default decides the palette, and a run whose pixels match writes
        # nothing. See art_common for both arguments.
        save_stable(quantize_stable(img), out, optimize=True)
        total_out += os.path.getsize(out)

    print(f"converted {len(stems)} UI glyphs -> {DST} ({total_out // 1024}KB)")


if __name__ == "__main__":
    main()
