#!/usr/bin/env python3
"""Draws the 30 country/state outline masters from authored lon/lat rings.

`npm run outlines`. Writes `art/icons/countries/*.png`, which is the *source*
side of the pipeline -- `import-class-art.py` then converts those into the
bundle's `ClassArt/outline-*.png`. Two steps rather than one on purpose: the
masters are what an artist would hand-edit and what `icons:verify` regenerates
against, and collapsing them would leave the bundle with no master at all.

**Why this lives in the repo** (0.8.0, A1). 0.7.9 derived two of the thirty
outlines with a scratchpad script and recorded the reasoning: "it is a one-shot
over a master, like every other derived-sprite pass." That held while 28 were
hand-drawn. With all 30 derived there is no other master -- this script *is* the
art -- so it ships, with its ring data beside it in
`country-outline-rings.py`.

--------------------------------------------------------------------------
The projection, which is the part that can break the app
--------------------------------------------------------------------------

`regions.ts` authors `mapPosition` as `{x, y}` fractions of the outline's own
canvas, and `CountryOutlineMap` places a dot at that fraction. So the canvas is
a coordinate system that 121 authored dots already live in, and the projection
is a contract rather than a rendering choice:

    x = (lon - lonMin) / (lonMax - lonMin)
    y = (latMax - lat) / (latMax - latMin)

**Uniform in x**, which 0.7.9 called out and A1 repeats: one scale factor for
the whole canvas, no per-latitude convergence. A cos(lat) term inside the
mapping would move every dot in every country by an amount that varies with how
far it is from the country's mid-latitude, and nothing in the app would say so.

The cosine is spent on the canvas *aspect* instead, where it costs nothing:

    width / height  =  (dlon * cos(midlat)) / dlat

That reproduces the two 0.7.9 canvases (Brazil 212x216 against a derived 0.974,
Mexico 216x144 against 1.60) and keeps a country from looking stretched, while
leaving the fraction-to-lon/lat mapping linear.

**The bbox is therefore the load-bearing number.** A dot's fraction resolves
against `min`/`max`, so an extreme point that is wrong by a degree moves every
dot in that country. `--check` is the gate: it re-reads every authored
`mapPosition` out of the generated catalog and reports any that land off the
silhouette.

--------------------------------------------------------------------------
The drawing
--------------------------------------------------------------------------

Cells, then an integer upscale -- the shape 0.7.9's two masters are already in
(212x216 is 106x108 at 2x). Rasterising at the cell grid is what makes the
result read as pixel art rather than as a scaled vector: one cell is one
authored unit, the cel outline is exactly one cell, and nothing lands on a half
pixel.

  1. every cell whose centre is inside the ring set (even-odd) is fill;
  2. every empty cell touching a fill cell on any of eight sides is outline;
  3. the rest is white, which `art_common.strip_background` floods away at
     import;
  4. upscale by `CELL`, nearest neighbour.

**No specular mark** (A1). 0.7.9 gave Brazil and Mexico a small white square
inside the silhouette; the ask is outline only, and the set is uniform without
it. It is also the one part of those two sprites that could not survive a
change of canvas without being re-placed by hand.

Usage:
    python3 scripts/make-country-outlines.py           # draw the masters
    python3 scripts/make-country-outlines.py --check   # dots only, no writes
"""
import importlib.util
import json
import os
import sys

from PIL import Image

from art_common import save_stable

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DST = os.path.join(ROOT, "art", "icons", "countries")
ENTRIES = os.path.join(ROOT, "Sources", "VinodexCore", "Resources", "entries.json")
ICONS = os.path.join(ROOT, "Sources", "VinodexCore", "Resources", "icons.json")

# The ring data, loaded by path because the filename has a hyphen in it (the
# convention every other script in here follows) and so cannot be imported.
_spec = importlib.util.spec_from_file_location(
    "country_outline_rings", os.path.join(HERE, "country-outline-rings.py")
)
rings_module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rings_module)

RINGS = rings_module.RINGS
FILL = rings_module.FILL
FILENAME = rings_module.FILENAME

# Cells on the long axis, and the integer upscale. 106 x 2 = 212, which is the
# canvas 0.7.9 used and the middle of the hand-drawn set's 50-246 range.
LONG_AXIS_CELLS = 106
CELL = 2
# One cell of white all round, so the outline ring has somewhere to be drawn and
# the border flood at import time has an unbroken edge to start from.
MARGIN = 2

WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)

# Regions whose place is genuinely not on their country's outline, so `--check`
# expects them to miss. **Failing in both directions**, like
# `assertOutlineCoverage`: a name in here that starts landing on land has to come
# out, or the list rots into an excuse.
#
# The Canary Islands are 1,100km off the Moroccan coast at (-15.6, 28.05). On
# Iberia's bbox that is the fraction (-0.49, 2.07) -- not a dot that is slightly
# wrong, a dot that is off the canvas. Drawing them means extending Spain's
# bounding box from 12.8 degrees of longitude to 22.5, which would rescale the
# canvas and move all fourteen other Spanish dots to fit one. The dot was in the
# sea on the hand-drawn art too. An inset, the way a real atlas solves this, is
# the only honest fix and it is a change to `CountryOutlineMap` rather than to
# the art.
OFF_MAP = {"Canary Islands"}


def hex_rgba(value):
    v = value.lstrip("#")
    return (int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16), 255)


def bbox(rings):
    lons = [p[0] for ring in rings for p in ring]
    lats = [p[1] for ring in rings for p in ring]
    return min(lons), min(lats), max(lons), max(lats)


def canvas_cells(rings):
    """Cell dimensions for a ring set, from its bbox and mid-latitude."""
    import math

    lon0, lat0, lon1, lat1 = bbox(rings)
    dlon = max(lon1 - lon0, 1e-6)
    dlat = max(lat1 - lat0, 1e-6)
    aspect = (dlon * math.cos(math.radians((lat0 + lat1) / 2))) / dlat
    if aspect >= 1:
        w = LONG_AXIS_CELLS
        h = max(int(round(LONG_AXIS_CELLS / aspect)), 8)
    else:
        h = LONG_AXIS_CELLS
        w = max(int(round(LONG_AXIS_CELLS * aspect)), 8)
    return w, h


def inside(rings, lon, lat):
    """Even-odd point-in-polygon across every ring.

    Even-odd rather than winding so a ring authored in either direction works
    and so an accidental self-intersection degrades to a hole rather than to a
    filled blob -- a hole is visible, which is the failure mode to prefer.
    """
    hit = False
    for ring in rings:
        n = len(ring)
        for i in range(n):
            x0, y0 = ring[i]
            x1, y1 = ring[(i + 1) % n]
            if (y0 > lat) != (y1 > lat):
                t = (lat - y0) / (y1 - y0)
                if lon < x0 + t * (x1 - x0):
                    hit = not hit
    return hit


def raster(stem):
    """(fill set, outline set, cells wide, cells high) for one place."""
    rings = RINGS[stem]
    lon0, lat0, lon1, lat1 = bbox(rings)
    w, h = canvas_cells(rings)
    dlon = max(lon1 - lon0, 1e-6)
    dlat = max(lat1 - lat0, 1e-6)

    fill = set()
    for cy in range(h):
        # Cell centres, so the extreme vertices land inside the first and last
        # cell rather than exactly on their boundary.
        lat = lat1 - (cy + 0.5) / h * dlat
        for cx in range(w):
            lon = lon0 + (cx + 0.5) / w * dlon
            if inside(rings, lon, lat):
                fill.add((cx, cy))

    # An empty result is a ring that missed every cell centre. `draw` refuses
    # it rather than writing a blank PNG: a blank outline is exactly the
    # silent-missing-asset failure `assertAssetsExist` was built for, except it
    # would pass, because the file exists.
    return fill, w, h


def outline_of(fill, w, h):
    ring = set()
    for (cx, cy) in fill:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (cx + dx, cy + dy)
                if n not in fill:
                    ring.add(n)
    return ring


def draw(stem):
    fill, w, h = raster(stem)
    if not fill:
        sys.exit(f"{stem}: rasterised to nothing — check its ring")
    ring = outline_of(fill, w, h)

    img_w = (w + 2 * MARGIN) * CELL
    img_h = (h + 2 * MARGIN) * CELL
    img = Image.new("RGBA", (img_w, img_h), WHITE)
    px = img.load()
    colour = hex_rgba(FILL[stem])

    def blit(cells, rgba):
        for (cx, cy) in cells:
            x0 = (cx + MARGIN) * CELL
            y0 = (cy + MARGIN) * CELL
            if x0 < 0 or y0 < 0 or x0 >= img_w or y0 >= img_h:
                continue
            for y in range(y0, min(y0 + CELL, img_h)):
                for x in range(x0, min(x0 + CELL, img_w)):
                    px[x, y] = rgba

    blit(ring, BLACK)
    blit(fill, colour)
    return img, len(fill), len(ring)


# ---------------------------------------------------------------------------
# The dot check
# ---------------------------------------------------------------------------

def silhouette(stem):
    """Cells that are land — fill or cel outline — plus the canvas size."""
    fill, w, h = raster(stem)
    ring = outline_of(fill, w, h)
    return fill | ring, w, h


def check_dots():
    """Every authored `mapPosition`, against the outline it will be drawn on.

    **A1's real risk, made mechanical.** 124 regions carry dots tuned against
    the hand-drawn silhouettes; replacing the art underneath can walk one into
    the sea, and nothing in the app would report it — `CountryOutlineMap` draws
    a dot wherever it is told. So the fractions are resolved against the new
    canvas and each one is asked the only question that matters: is there land
    under it.
    """
    with open(ENTRIES, encoding="utf-8") as fh:
        entries = json.load(fh)
    with open(ICONS, encoding="utf-8") as fh:
        shape_icons = json.load(fh)["countryShapeIcons"]

    cache = {}
    checked = off = 0
    misses, exempt, stale = [], [], []
    for entry in entries:
        if entry.get("category") != "REGIONS":
            continue
        details = entry.get("details") or {}
        position = details.get("mapPosition")
        if not position:
            continue
        # `EntryVisual.regionVisual`'s own resolution order: state first, so a
        # Willamette row reads as Oregon rather than as the whole USA.
        key = None
        for candidate in (details.get("state"), details.get("origin")):
            if candidate and candidate.lower() in shape_icons:
                key = candidate.lower()
                break
        if key is None:
            continue
        stem = shape_icons[key][len("art:outline-"):]
        if stem not in RINGS:
            continue
        if stem not in cache:
            cache[stem] = silhouette(stem)
        land, w, h = cache[stem]

        cx = min(max(int(position["x"] * w), 0), w - 1)
        cy = min(max(int(position["y"] * h), 0), h - 1)
        checked += 1
        name = entry.get("name")
        on_land = (cx, cy) in land
        if name in OFF_MAP:
            exempt.append(name)
            if on_land:
                stale.append(name)
            continue
        if not on_land:
            off += 1
            misses.append((name, stem, position["x"], position["y"]))

    print(f"{checked} authored dots checked · {checked - off - len(exempt)} on land · "
          f"{off} in the sea · {len(exempt)} off-map by exemption")
    for name, stem, x, y in misses:
        print(f"  OFF  {name:34s} {stem:16s} ({x:.2f}, {y:.2f})")
    for name in stale:
        print(f"  STALE EXEMPTION {name} — it lands on land now; drop it from OFF_MAP")
    for name in sorted(set(OFF_MAP) - set(exempt)):
        print(f"  UNREACHED EXEMPTION {name} — no region by that name carries a dot")
    return off + len(stale) + len(set(OFF_MAP) - set(exempt))


def main():
    if "--check" in sys.argv:
        sys.exit(1 if check_dots() else 0)

    os.makedirs(DST, exist_ok=True)
    written = 0
    for stem in sorted(RINGS):
        img, fill_cells, ring_cells = draw(stem)
        out = os.path.join(DST, FILENAME[stem])
        if save_stable(img, out):
            written += 1
        print(f"  {stem:16s} {img.size[0]:>4}x{img.size[1]:<4} "
              f"{fill_cells:>5} fill · {ring_cells:>4} outline")
    print(f"\n{len(RINGS)} outlines -> {DST} ({written} rewritten)")

    missing = sorted(set(FILENAME) - set(RINGS))
    if missing:
        sys.exit(f"no ring authored for: {', '.join(missing)}")


if __name__ == "__main__":
    main()
