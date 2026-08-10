#!/usr/bin/env python3
"""Imports the drawn footer button caps into the app bundle (0.8.2, coordinator 1).

Sources are individual PNGs in art/icons/chrome/footer, one per control in the
chassis band: `back`, `home`, `settings`, `user`. Same treatment as every other
importer — background removed via art_common.py, palette-quantised, written to
Sources/VinodexUI/Resources/FooterArt.

**Why this is not `import-button-art.py` with four more files in it.** The two
sets look alike and are not the same kind of thing:

- The 32 faces under `art/icons/chrome/buttons/` are *glyphs*. They sit inside a
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
from collections import deque

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
#
# **0.35 -> 0.50 in 0.8.4 (E2).** 0.8.3's B1 cleared 27,885 pixels of painted
# cast shadow at 0.35 and the caps stopped reading as having a shadow, which is
# what B1 asked for. What it did not clear was the ramp's own soft edge: taking
# the ratio histogram over the four sources, the shadow occupies 0.0-0.45 and
# the cap's own pixels start again at 0.6, with a floor of about 300 pixels per
# cap between them. 0.35 cut through the shadow's shoulder rather than through
# that gap, leaving 600-1000 plum pixels per cap.
#
# They were invisible as *art* and loud as *colour*, because `ChassisCapLoader`
# re-inks every opaque pixel above value 0.06 to the skin's hue: a leftover
# shadow pixel is not a dark smudge on the cap, it is a fully saturated skin-
# coloured one sitting outside the moulded disc, on the chassis. That is the
# bleed E2 reports, and this is one of its two halves — the other is the disc
# clip in `ChassisCapLoader`, which contains anything this misses.
#
# 0.50 is the middle of the measured gap rather than a value that looked right:
# it takes the whole ramp and leaves the cap's darkest legitimate pixel, at
# 0.6, with room to spare.
#
# **The number is unchanged in 0.8.5 and the sweep it drives is not.** E2's
# third pass found that widening the ceiling was never the missing half: at any
# ceiling, a *global* sweep also matches pixels inside the cap, and the wider
# the ceiling the more of them it takes. `strip_key_shadow` is border-connected
# now, which makes the ceiling a question about the shadow only — where it can
# be generous without costing the drawing anything.
SHADOW_GREEN_CEILING = 0.50
# How close red and blue must be to each other. Magenta is the two together, so
# this is what keeps a dark red or a dark blue in the drawing out of the sweep.
SHADOW_BALANCE_FLOOR = 0.5


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.path.join(ROOT, "art", "icons", "chrome", "footer")


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

    **Border-connected only, as of 0.8.5 (E2), and that is the whole of the
    third pass at this item.** Through 0.8.4 this was a global sweep: every
    pixel anywhere in the file that matched `_is_key_shadow` was cleared. The
    cast shadow is *behind* the cap, so on the exterior that is correct — and
    on the interior it is a hole punched through an opaque moulded part. It
    punched a lot of them: 3,276 pixels on `back` and 3,706 on `user`,
    clustered in the lower half of the disc where the cap's own darkest
    shading sits closest to the shadow's colour.

    Two things followed, and between them they are what the photographs show:

    1. The holes let the chassis through the cap, which is the mottling across
       the lower portion of a re-inked cap.
    2. Where a run of them reached the rim they cut the cel outline into
       fragments. Measured over 720 rays, the silhouette's radius had a
       standard deviation of **4.2px on a 123px disc**; border-flooding takes
       that to **1.3px**. That is the difference between an edge that reads as
       drawn and one that reads as damaged, and no amount of clipping in Swift
       could have recovered it — the pixels were gone before the app opened
       the file.

    So the flood spreads inward from the border through transparent *or*
    shadow-coloured pixels and stops at the first pixel of the cap. Anything it
    never reaches is the drawing, whatever colour it happens to be. This is the
    same rule `art_common.strip_background`'s white path already follows, and
    the reason that path was written border-first in the first place.
    """
    px = img.load()
    w, h = img.size

    def passable(x, y):
        r, g, b, a = px[x, y]
        return a == 0 or _is_key_shadow(r, g, b)

    seen = bytearray(w * h)
    queue = deque()

    def push(x, y):
        if not seen[y * w + x] and passable(x, y):
            seen[y * w + x] = 1
            queue.append((x, y))

    for x in range(w):
        push(x, 0)
        push(x, h - 1)
    for y in range(h):
        push(0, y)
        push(w - 1, y)
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                push(nx, ny)

    cleared = 0
    for y in range(h):
        for x in range(w):
            if not seen[y * w + x]:
                continue
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (r, g, b, 0)
                cleared += 1
    return img, cleared


# --- The home cap's bottom lip (0.8.92 item 3; regrafted 0.8.96) -------------
#
# Where the skirt band starts, as a fraction of the sprite height. Chosen off
# the measurement in 0.8.92: the incised house glyph bottoms out around 0.72h
# and the lip runs 0.80h-0.97h, so 0.78 clears the glyph on one side and takes
# the whole band on the other. `ChassisCapLoader.lipBandTop` is the same number
# in Swift; the two are one measurement in two languages.
LIP_BAND_TOP = 0.78


def _opaque_centroid(img):
    """Centre of mass of the opaque pixels — the same anchor the runtime's
    `fitCap` computes, so the graft and the re-ink agree on where the cap is."""
    px = img.load()
    w, h = img.size
    sx = sy = n = 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                sx += x
                sy += y
                n += 1
    return sx / max(n, 1), sy / max(n, 1)


def graft_home_skirt(img, donors):
    """Rebuild `home`'s skirt band as its siblings' — silhouette and shading
    both (0.8.96, replacing 0.8.92's `lift_home_lip`).

    **Why the lift had to go, and why a value-only graft after it was still
    not enough.** 0.8.92 lifted near-black pixels to a synthetic ramp;
    measured on what it shipped, the band still read wrong, and re-measuring
    found the reason is *material*, not colour: below y~0.87h the home
    drawing's skirt is a thin wall — 21 opaque pixels across a row where
    `back` and `user` carry ~120 — so however those pixels are painted, the
    cap's bottom bezel is mostly missing and the button reads as cut off
    against its neighbours on every colored shell. Three releases of
    colour-side fixes were correct and could not touch this, because absent
    pixels take no ink.

    So the band is adopted from the sibling drawings wholesale: for every
    band pixel, alpha comes from `back`'s silhouette (centroid-aligned) and
    value comes from the median of the donors' pixels at the same position —
    which carries their moulded mid-tones *and* their proper cel outline
    down and around the bottom edge. Written as neutral grey: hue and
    saturation are replaced by the runtime re-ink anyway, value is the
    channel it preserves. After this the four caps share one bottom bezel by
    construction, and the seam at the band top is invisible because the
    donors' values at that height already match home's (measured medians
    0.60 vs 0.60 at y=199).

    The house glyph never reaches the band — it bottoms out at ~0.72h against
    the band's 0.78h — so nothing of home's own drawing is lost but the
    too-thin wall this replaces.
    """
    px = img.load()
    w, h = img.size

    hx, hy = _opaque_centroid(img)
    donor_data = []
    for d in donors:
        dx, dy = _opaque_centroid(d)
        donor_data.append((d.load(), d.size, dx - hx, dy - hy))

    y0 = int(h * LIP_BAND_TOP)
    grafted = 0
    for y in range(y0, h):
        for x in range(w):
            samples = []
            alpha = 0
            for p, (dw, dh), sx, sy in donor_data:
                nx, ny = int(round(x + sx)), int(round(y + sy))
                if 0 <= nx < dw and 0 <= ny < dh:
                    r, g, b, a = p[nx, ny]
                    if a > 0:
                        samples.append(max(r, g, b))
                        alpha = max(alpha, a)
            if not samples:
                if px[x, y][3] != 0:
                    px[x, y] = (0, 0, 0, 0)
                    grafted += 1
                continue
            samples.sort()
            v = samples[len(samples) // 2]
            if px[x, y] != (v, v, v, alpha):
                grafted += 1
            px[x, y] = (v, v, v, alpha)
    return img, grafted


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
    total_grafted = 0

    # Two passes rather than one: `home`'s skirt takes its values *from*
    # `back` and `user`, so every cap is background-stripped first and the
    # graft runs over the processed set.
    processed = {}
    for stem in stems:
        img = strip_background(Image.open(os.path.join(src, stem + ".png")))
        img = img.convert("RGBA")
        img, cleared = strip_key_shadow(img)
        total_shadow += cleared
        processed[stem] = img

    # `home` alone: its skirt is painted black-under-bright where the
    # siblings' is a moulded mid-tone — see `graft_home_skirt`. Keyed on the
    # stem rather than measured per file, because the defect is a fact about
    # one drawing, and a fifth cap in either style should arrive untouched
    # until somebody measures it.
    donors = [processed[s] for s in ("back", "user") if s in processed]
    if "home" in processed and donors:
        processed["home"], total_grafted = graft_home_skirt(
            processed["home"], donors
        )

    for stem in stems:
        out = os.path.join(DST, PREFIX + stem + ".png")
        save_stable(quantize_stable(processed[stem]), out, optimize=True)
        total_out += os.path.getsize(out)

    print(
        f"converted {len(stems)} footer caps -> {DST} ({total_out // 1024}KB), "
        f"{total_shadow} cast-shadow pixels cleared, "
        f"{total_grafted} skirt pixels grafted on home"
    )


if __name__ == "__main__":
    main()
