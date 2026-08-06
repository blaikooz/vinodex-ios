#!/usr/bin/env python3
"""Imports the drawn footer button caps into the app bundle (0.8.2, coordinator 1).

Sources are individual PNGs in art/icons/footerbuttons, one per control in the
chassis band: `back`, `home`, `settings`, `user`. Same treatment as every other
importer — background removed via art_common.py, palette-quantised, written to
Sources/VinodexUI/Resources/FooterArt.

**Why this is not `import-button-art.py` with four more files in it.** The two
sets look alike and are not the same kind of thing:

- The 32 faces under `art/icons/buttons/` are *glyphs*. They sit inside a
  control the app draws — `DexChromeGlyph` fits them into a square and the
  circle, rim and shadow around them belong to `ChassisButton`.
- These four are *whole moulded caps*, drawn with their own rim, their own cast
  shadow and the symbol incised into the face. They replace the control rather
  than sitting in it, which is why `ChassisButton` suppresses its gradient,
  border and shadow when one resolves.

Merging them would also have collided outright: `home`, `settings` and `user`
already exist under `buttons/` as glyphs and are drawn on the menu, in Settings
and on the tools screen. Three of the four files would have overwritten a
different picture used somewhere else.

**Stems carry a `footer-` prefix.** `PixelArtLoader`'s namespace is flat and
global across every search directory, and its own note calls the `ButtonArt`
entry "the first entry that could actually collide" precisely because those
stems are bare English words. `stamp-` and `sticker-` are prefixed for the same
reason and the loader's comment describes them as safe *by construction*; this
set joins that convention rather than adding a second bare-word directory and a
second ordering argument to reason about.

Shipped at source resolution with only the palette normalised — no resize, no
crop — as `import-button-art.py` argues at length: chrome is drawn to fit its
control by the illustrator, and a downscale here would second-guess that at
import time, invisibly.

The caps are drawn once, in one cream colourway, and there are twenty-one
chassis skins. They are **re-inked at runtime** by `ChassisCapLoader`, not
shipped per skin — the rule 0.6.2 set with `GrapeSpriteLoader` and the rarity
leaf. Nothing here knows about skins.

**The cast shadow comes off here, not in Swift (0.8.3, B1).** B1 asks for the
caps to lose their shadow, and the shadow turned out to be *painted into the
source*: it is the magenta key darkened to roughly half value — (128, 12, 102)
against the key's (239, 4, 225) — laid down behind and to the lower right of
each disc. `art_common.strip_background` keys out only the pure form, so the
shadow survived import as a dark plum blob and read as black against the
chassis. Nothing in SwiftUI was drawing it; `ChassisButton` explicitly does not
(`// No .shadow: the sprite casts its own`), so there was no code change that
could have removed it.

`strip_key_shadow` below clears the rest of that ramp. It keys on *chroma*
rather than on darkness, which is what makes it safe: a shadow pixel sits on the
key's hue at any value, and every pixel of the cap itself is either cream (a
green channel far too high to qualify) or the near-neutral black of the cel
outline (a green channel level with the other two). Measured on the drop: 4,965
to 8,230 pixels cleared per cap, and the rim, the lit face, the internal shading
and the incised symbol all survive intact.

**In the importer rather than in a hand-edited PNG** for the house reason: a
correction that lives outside the script is a correction the next re-import
silently undoes.

Reproducibility is 0.8.0's A0b: `quantize_stable` pins method and dither,
`save_stable` leaves a file whose pixels already match alone, so a second run
over unchanged art writes nothing.

Deliberately tolerant of an empty or missing source dir, as the stamp, sticker
and button importers are: every cap falls back to the drawn control it replaces,
so "nothing to import" is a note rather than a failure.

Usage: python3 scripts/import-footer-art.py [source-dir]
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
DST = output_dir(ROOT, "FooterArt")

# The prefix that keeps these four out of the flat stem namespace. Matched by
# `ChassisButton.capStem` on the Swift side; changing it here changes it there.
PREFIX = "footer-"


# Below this, a pixel's hue is noise: the cel outline sits at values of 8-10 and
# a ratio taken there says nothing about what colour it was meant to be. The one
# reason the rule needs a floor at all.
SHADOW_VALUE_FLOOR = 16
# How much green a pixel may carry, as a fraction of its red/blue peak, and
# still count as the magenta key. The key itself is at 0.017; the cap's cream is
# at 0.89.
SHADOW_GREEN_CEILING = 0.35
# How close red and blue must be to each other. Magenta is the two together, so
# this is what keeps a dark red or a dark blue in the drawing out of the sweep.
SHADOW_BALANCE_FLOOR = 0.5


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.path.join(ROOT, "art", "icons", "footerbuttons")


def _is_key_shadow(r, g, b):
    """Whether this pixel is the magenta key at reduced value."""
    hi = max(r, b)
    if hi < SHADOW_VALUE_FLOOR:
        return False
    if g >= SHADOW_GREEN_CEILING * hi:
        return False
    return min(r, b) > SHADOW_BALANCE_FLOOR * hi


def strip_key_shadow(img):
    """Clear the painted cast shadow (0.8.3, B1) — see the module note.

    Runs *after* `strip_background`, over what it left opaque, so the pure key
    is already gone and this only ever sees the ramp below it.
    """
    px = img.load()
    w, h = img.size
    cleared = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and _is_key_shadow(r, g, b):
                px[x, y] = (r, g, b, 0)
                cleared += 1
    return img, cleared


def main():
    src = source_dir()
    if not os.path.isdir(src):
        print(f"no footer cap art yet ({src} absent) — the drawn caps keep the band")
        return

    stems = sorted(
        os.path.splitext(name)[0]
        for name in os.listdir(src)
        if name.lower().endswith(".png")
    )
    if not stems:
        print(f"no footer cap art yet ({src} empty) — the drawn caps keep the band")
        return

    os.makedirs(DST, exist_ok=True)
    total_out = 0
    total_shadow = 0
    for stem in stems:
        img = strip_background(Image.open(os.path.join(src, stem + ".png")))
        img = img.convert("RGBA")
        img, cleared = strip_key_shadow(img)
        total_shadow += cleared
        out = os.path.join(DST, PREFIX + stem + ".png")
        save_stable(quantize_stable(img), out, optimize=True)
        total_out += os.path.getsize(out)

    print(
        f"converted {len(stems)} footer caps -> {DST} ({total_out // 1024}KB), "
        f"{total_shadow} cast-shadow pixels cleared"
    )


if __name__ == "__main__":
    main()
