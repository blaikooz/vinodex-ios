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


# --- Rebuilding the home cap from back's drawing (0.8.99) --------------------
#
# The runtime's glyph-detection constants, in source-pixel terms — the same
# bands `ChassisCapLoader.fitCap` uses, so what this transplants is exactly
# what the re-ink will treat as the incised symbol.
GLYPH_VALUE_CEILING = 0.60 * 255
GLYPH_VALUE_FLOOR = 0.06 * 255
GLYPH_INNER_REACH = 0.20
GLYPH_OUTER_LIMIT = 0.78
# How far the *inpaint* mask grows past the chevron's dark core, in pixels.
# The groove is drawn with an anti-aliased shoulder — mid-values above the
# detection ceiling — and an inpaint that removes only the core leaves that
# shoulder behind as a ghost chevron in the face. Three pixels takes the
# shoulder; the house is stamped core-only, so no foreign face paint rides
# along with it.
INPAINT_DILATE = 3


def _fit(img):
    """Largest opaque component, its centroid, median radius and glyph mask —
    a pure-PIL port of the runtime's `fitCap`, so both ends of the pipeline
    agree on what a cap and its symbol are."""
    px = img.load()
    w, h = img.size

    def neighbours(x, y):
        if x > 0:
            yield x - 1, y
        if x < w - 1:
            yield x + 1, y
        if y > 0:
            yield x, y - 1
        if y < h - 1:
            yield x, y + 1

    # Largest 4-connected opaque region.
    seen = bytearray(w * h)
    best = set()
    for sy in range(h):
        for sx in range(w):
            if seen[sy * w + sx] or px[sx, sy][3] == 0:
                continue
            region = []
            stack = [(sx, sy)]
            seen[sy * w + sx] = 1
            while stack:
                x, y = stack.pop()
                region.append((x, y))
                for nx, ny in neighbours(x, y):
                    if not seen[ny * w + nx] and px[nx, ny][3] > 0:
                        seen[ny * w + nx] = 1
                        stack.append((nx, ny))
            if len(region) > len(best):
                best = set(region)

    cx = sum(p[0] for p in best) / len(best)
    cy = sum(p[1] for p in best) / len(best)

    import math
    radii = []
    limit = float(max(w, h))
    for i in range(360):
        t = i * 2 * math.pi / 360
        dx, dy = math.cos(t), math.sin(t)
        r, last = 0.0, 0.0
        while r < limit:
            x, y = int(round(cx + r * dx)), int(round(cy + r * dy))
            if 0 <= x < w and 0 <= y < h and (x, y) in best:
                last = r
            r += 0.5
        radii.append(last)
    radii.sort()
    radius = max(radii[180], 1.0)

    # Dark regions that start inside the inner reach and stay inside the
    # outer limit are the incised symbol.
    def value(x, y):
        r, g, b, a = px[x, y]
        return max(r, g, b)

    dark = {
        (x, y) for (x, y) in best
        if GLYPH_VALUE_FLOOR < value(x, y) < GLYPH_VALUE_CEILING
    }
    glyph = set()
    visited = set()
    for start in dark:
        if start in visited:
            continue
        region = []
        stack = [start]
        visited.add(start)
        min_r, max_r = float("inf"), 0.0
        while stack:
            x, y = stack.pop()
            region.append((x, y))
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / radius
            min_r = min(min_r, d)
            max_r = max(max_r, d)
            for n in neighbours(x, y):
                if n in dark and n not in visited:
                    visited.add(n)
                    stack.append(n)
        if min_r < GLYPH_INNER_REACH and max_r < GLYPH_OUTER_LIMIT:
            glyph.update(region)
    return best, cx, cy, radius, glyph


def rebuild_home_from_back(home, back):
    """Rebuild the home cap as **back's drawing with the house incised**
    (0.8.99, replacing 0.8.92-0.8.98's band surgery).

    **The end of the skirt saga.** 0.8.92 lifted the lip's black paint,
    0.8.96 grafted the siblings' skirt values, 0.8.97 blended the graft's
    seam, 0.8.98 widened the band — and a line survived every one of them,
    because the home drawing differs from its siblings *above* any band a
    patch draws: its face is painted as a lit lens, glossier and differently
    shaded, and wherever patched paint meets original paint there is a
    boundary to see. The only band with no seam is the whole cap.

    So home is not patched any more; it is **rebuilt**. The body is `back`'s
    drawing verbatim — face, skirt, outline, every pixel of moulded plastic —
    with back's chevron inpainted away (each symbol pixel takes the median of
    the face within a widening window) and home's house transplanted in at
    the same position relative to the cap's fitted centre. Glyph masks are
    found by the runtime's own rules, dilated `GLYPH_DILATE` px so the
    groove's anti-aliased shoulder travels with its core. After this there is
    no home-specific paint left to disagree with the neighbours: the four
    caps are one drawing family by construction, and the re-ink treats the
    transplanted house exactly as it treated the drawn one.
    """
    _, bcx, bcy, _, back_glyph = _fit(back)
    _, hcx, hcy, _, home_glyph = _fit(home)

    out = back.copy()
    opx = out.load()
    bpx = back.load()
    hpx = home.load()
    w, h = out.size
    hw, hh = home.size

    # Inpaint the chevron — core *and* anti-aliased shoulder, hence the
    # dilation — each removed pixel taking the median face value in a
    # widening window, face meaning opaque, non-symbol, and bright enough
    # not to be the cel outline.
    erase = set(back_glyph)
    for _ in range(INPAINT_DILATE):
        grown = set(erase)
        for (x, y) in erase:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h and bpx[nx, ny][3] > 0:
                    grown.add((nx, ny))
        erase = grown

    for (x, y) in erase:
        vals = []
        reach = 4
        while not vals and reach <= 40:
            for dy in range(-reach, reach + 1):
                for dx in range(-reach, reach + 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in erase:
                        r, g, b, a = bpx[nx, ny]
                        if a > 0 and max(r, g, b) >= GLYPH_VALUE_CEILING:
                            vals.append((max(r, g, b), (r, g, b)))
            reach += 4
        if vals:
            vals.sort(key=lambda t: t[0])
            _, (r, g, b) = vals[len(vals) // 2]
            opx[x, y] = (r, g, b, 255)

    # Transplant the house, core only: its own groove paint, and none of the
    # lit face around it.
    sx, sy = bcx - hcx, bcy - hcy
    stamped = 0
    for (x, y) in home_glyph:
        tx, ty = int(round(x + sx)), int(round(y + sy))
        if 0 <= tx < w and 0 <= ty < h and opx[tx, ty][3] > 0:
            r, g, b, a = hpx[x, y]
            opx[tx, ty] = (r, g, b, 255)
            stamped += 1
    return out, stamped


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
    total_stamped = 0

    # Two passes rather than one: `home` is rebuilt *from* `back`, so every
    # cap is background-stripped first and the rebuild runs over the
    # processed set.
    processed = {}
    for stem in stems:
        img = strip_background(Image.open(os.path.join(src, stem + ".png")))
        img = img.convert("RGBA")
        img, cleared = strip_key_shadow(img)
        total_shadow += cleared
        processed[stem] = img

    # `home` alone: its drawing never matched its siblings' moulding — see
    # `rebuild_home_from_back`. Keyed on the stem rather than measured per
    # file, because the defect is a fact about one drawing, and a fifth cap
    # in either style should arrive untouched until somebody measures it.
    if "home" in processed and "back" in processed:
        processed["home"], total_stamped = rebuild_home_from_back(
            processed["home"], processed["back"]
        )

    for stem in stems:
        out = os.path.join(DST, PREFIX + stem + ".png")
        save_stable(quantize_stable(processed[stem]), out, optimize=True)
        total_out += os.path.getsize(out)

    print(
        f"converted {len(stems)} footer caps -> {DST} ({total_out // 1024}KB), "
        f"{total_shadow} cast-shadow pixels cleared, "
        f"home rebuilt from back with {total_stamped} house pixels stamped"
    )


if __name__ == "__main__":
    main()
