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


# --- The home cap's bottom lip (0.8.92, item 3) -----------------------------
#
# Where the lip's near-black band starts, as a fraction of the sprite height.
# Chosen off the measurement below, not eyeballed: the incised house glyph
# bottoms out around 0.72h, and the lip's slab runs 0.80h-0.97h, so 0.78
# clears the glyph on one side and takes the whole slab on the other.
LIP_BAND_TOP = 0.78
# A pixel at or under this peak channel value is "painted black" for the
# purposes of the lift. The slab measures 9/255; the moulded mid-tones the
# siblings use start at ~0.06 * 255. 25 takes the slab and its ragged edge
# and nothing of the shading above it.
LIP_BLACK_CEILING = 25
# How much of the black stays black: pixels within this many px of the
# silhouette edge are the cel outline, which is structure — the same rule
# `ChassisCapLoader`'s re-ink applies at runtime — and the outline is exactly
# what must survive the lift or the cap loses its drawn edge. 2 rather than 3,
# measured: the lip's side walls run 3-8px thick with transparency on both
# sides, so a 3px keep from each side swallowed the wall whole and lifted
# only 573 of the slab's ~1,500 pixels.
LIP_OUTLINE_KEEP = 2
# The lift target, as a value ramp top-to-bottom of the band. The measured
# siblings (`back`, `user`) carry skirts running 0.06-0.60 with a median of
# ~0.32; a flat fill at the median would be honest but dead, so the band gets
# a gentle moulding ramp bracketing it instead.
LIP_VALUE_TOP = 0.42
LIP_VALUE_BOTTOM = 0.24


def lift_home_lip(img):
    """Repaint `home`'s bottom lip from near-black to the moulded mid-tone its
    three siblings drew theirs in (0.8.92, item 3).

    **The measurement, so the next reader does not re-litigate the clip.**
    0.8.91's D1 retired the geodesic trim and the largest-component rule does
    keep the lip — re-measured on the shipped sprites, rows y=204-247 of
    `home` sit inside the main component minus ~150px of detached speckle. What
    differs is *paint*: in the skirt band (y >= 0.85h) `home` carries 1,144 of
    1,526 pixels at value <= 0.06 where `back` and `user` carry mid-values
    (median 0.32) with only their cel lines black. `ChassisCapLoader`'s re-ink
    keeps near-black at its own colour on purpose — the cel outline is
    structure — so the whole lip rode that clause and stayed a black slab:
    invisible on the dark shells, and on a bright one indistinguishable from
    the bottom of the button being cut off. Which is §D1's complaint, still
    alive after three clip rewrites, because it was never the clip.

    So the correction is to the drawing, at import, where corrections live:
    within the bottom band, black pixels deeper than `LIP_OUTLINE_KEEP` from
    the silhouette lift to a value ramp bracketing the siblings' median. Hue
    and saturation are irrelevant — the slab is neutral, and the runtime
    re-ink replaces both — so only the value moves, which is precisely the
    channel the re-ink preserves.
    """
    px = img.load()
    w, h = img.size

    # Distance from the transparent outside, 4-connected BFS — the same
    # arithmetic the runtime coverage pass uses, so "outline" means the same
    # pixels in both places.
    INF = 1 << 30
    dist = [INF] * (w * h)
    queue = deque()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            edge = (
                x == 0 or x == w - 1 or y == 0 or y == h - 1
                or px[x - 1, y][3] == 0 or px[x + 1, y][3] == 0
                or px[x, y - 1][3] == 0 or px[x, y + 1][3] == 0
            )
            if edge:
                dist[y * w + x] = 1
                queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        nxt = dist[y * w + x] + 1
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0 \
                    and dist[ny * w + nx] > nxt:
                dist[ny * w + nx] = nxt
                queue.append((nx, ny))

    y0 = int(h * LIP_BAND_TOP)
    lifted = 0
    for y in range(y0, h):
        t = (y - y0) / max(h - 1 - y0, 1)
        value = int(255 * (LIP_VALUE_TOP + (LIP_VALUE_BOTTOM - LIP_VALUE_TOP) * t))
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 or max(r, g, b) > LIP_BLACK_CEILING:
                continue
            if dist[y * w + x] <= LIP_OUTLINE_KEEP:
                continue
            px[x, y] = (value, value, value, a)
            lifted += 1
    return img, lifted


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
    total_lifted = 0
    for stem in stems:
        img = strip_background(Image.open(os.path.join(src, stem + ".png")))
        img = img.convert("RGBA")
        img, cleared = strip_key_shadow(img)
        total_shadow += cleared
        # `home` alone: its lip is painted near-black where the siblings'
        # are moulded mid-tones — see `lift_home_lip`. Keyed on the stem
        # rather than measured per file, because the defect is a fact about
        # one drawing, and a fifth cap in either style should arrive
        # untouched until somebody measures it.
        if stem == "home":
            img, lifted = lift_home_lip(img)
            total_lifted += lifted
        out = os.path.join(DST, PREFIX + stem + ".png")
        save_stable(quantize_stable(img), out, optimize=True)
        total_out += os.path.getsize(out)

    print(
        f"converted {len(stems)} footer caps -> {DST} ({total_out // 1024}KB), "
        f"{total_shadow} cast-shadow pixels cleared, "
        f"{total_lifted} lip pixels lifted on home"
    )


if __name__ == "__main__":
    main()
