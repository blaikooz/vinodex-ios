#!/usr/bin/env python3
"""Probe the nearest-colour hit test against the INSTALLED map. §7.3.

The simulator offers no way to send a tap, so the acceptance criterion "every
tap inside France resolves to a region" cannot be driven through the UI from
here. This runs the same algorithm `FranceAtlas.region(atX:)` runs — exact
fill match, then an expanding-ring search — over the same keyed PNG the app
loads, and probes the cases the handoff calls hard.

It proves the data and the algorithm. Whether it feels right in the hand is
the maintainer's to answer, and this cannot answer it.
"""
import json, os, sys

from PIL import Image
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MAPS = os.path.join(REPO, "Sources/VinodexUI/Resources/Maps/france")

man = json.load(open(os.path.join(MAPS, "france-manifest.json")))
idx = json.load(open(os.path.join(MAPS, "france-region-index.json")))
im = Image.open(os.path.join(MAPS, "france-regions.png")).convert("RGBA")
a = np.array(im)
H, W = a.shape[0], a.shape[1]

fills = {}
for stem, e in man["regions"].items():
    h = e["fill"].lstrip("#")
    fills[(int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))] = stem

# One byte per pixel, exactly as the app builds it.
table = np.full((H, W), -1, dtype=np.int16)
stems = sorted(fills.values())
for (r, g, b), stem in fills.items():
    m = (a[:, :, 0] == r) & (a[:, :, 1] == g) & (a[:, :, 2] == b) & (a[:, :, 3] > 0)
    table[m] = stems.index(stem)


# Inside the coastline but unassigned (stone / outline) vs outright sea.
# The app keeps these apart so the outward search runs only from land — see
# `FranceAtlas.outside`.
INSIDE = a[:, :, 3] > 0


def hit(x, y, max_r=None):
    """Exact match, then expanding rings — `FranceAtlas.nearestIndex`."""
    if max_r is None:
        max_r = min(W, H) // 4
    if not (0 <= x < W and 0 <= y < H) or not INSIDE[y, x]:
        return None, -1          # sea: answers nothing
    if table[y, x] >= 0:
        return stems[table[y, x]], 0
    for r in range(1, max_r + 1):
        x0, x1 = max(0, x - r), min(W - 1, x + r)
        y0, y1 = max(0, y - r), min(H - 1, y + r)
        ring = []
        if y - r >= 0: ring.append(table[y - r, x0:x1 + 1])
        if y + r < H:  ring.append(table[y + r, x0:x1 + 1])
        if x - r >= 0: ring.append(table[y0:y1 + 1, x - r])
        if x + r < W:  ring.append(table[y0:y1 + 1, x + r])
        for arr in ring:
            found = arr[arr >= 0]
            if found.size:
                return stems[int(found[0])], r
    return None, -1


def at_button(stem):
    b = man["regions"][stem]["button"]
    return int(b[0] * W), int(b[1] * H)


print(f"canvas {W}x{H}, {len(fills)} fills\n")

print("--- every region's own marker resolves to itself ---")
bad = 0
for stem in sorted(man["regions"]):
    x, y = at_button(stem)
    got, r = hit(x, y)
    ok = got == stem
    bad += not ok
    print(f"  {stem:12} -> {str(got):12} {'' if ok else '   *** MISMATCH ***'}")

print("\n--- the hard cases the handoff names ---")
# Beaujolais: the smallest region at 79px.
x, y = at_button("beaujolais")
print(f"  beaujolais marker      -> {hit(x, y)[0]}")
# Its four immediate neighbours, to show the catchment is not knife-edge.
for dx, dy in ((-14, 0), (14, 0), (0, -14), (0, 14)):
    got, r = hit(x + dx, y + dy)
    print(f"    offset {dx:+4},{dy:+4}     -> {got:12} (ring {r})")

# Languedoc / Roussillon: markers 8.2 logical px apart, the tightest pair.
lx, ly = at_button("languedoc")
rx, ry = at_button("roussillon")
print(f"  languedoc marker       -> {hit(lx, ly)[0]}")
print(f"  roussillon marker      -> {hit(rx, ry)[0]}")
print(f"  midpoint between them  -> {hit((lx + rx) // 2, (ly + ry) // 2)[0]}")

# The Charentes: unassigned département, must fall to Bordeaux.
pr = man["projection"]
K, O, S = pr["x_factor"], pr["origin"], pr["scale"]
sc = man["base"]["export_scale"]
def canvas(lon, lat):
    return int(((lon * K - O[0]) * S + 2) * sc), int(((-lat - O[1]) * S + 2) * sc)
cx, cy = canvas(-0.33, 45.65)   # Cognac
got, r = hit(cx, cy)
print(f"  Cognac (unassigned)    -> {got:12} (ring {r})  [expect bordeaux]")

print("\n--- taps that should find nothing: open sea ---")
for name, (x, y) in {
    "top-left corner": (2, 2),
    "bottom-right corner": (W - 3, H - 3),
    "Atlantic, far west": (10, H // 2),
}.items():
    got, r = hit(x, y)
    print(f"  {name:22} -> {got} (ring {r})")

print("\n--- coverage: how much of the canvas answers ---")
ys, xs = np.mgrid[0:H:20, 0:W:20]
tot = res = 0
for y, x in zip(ys.ravel(), xs.ravel()):
    tot += 1
    if hit(int(x), int(y))[0] is not None:
        res += 1
print(f"  {res}/{tot} sampled points resolve ({res * 100 / tot:.0f}%)")

sys.exit(1 if bad else 0)
