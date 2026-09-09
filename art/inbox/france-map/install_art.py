#!/usr/bin/env python3
"""Install the France map PNGs into the bundle. Step 4 of HANDOFF.md.

DESTINATION: Sources/VinodexUI/Resources/Maps/france/

`Maps` already exists (it holds the globe texture), is already `.copy()`d by
Package.swift, is already named in `ArtPipelineRosterTests.ownedByOtherLoaders`
as a directory another loader owns, and is absent from `verify-art.py`'s DIRS
tuple. So these files land somewhere all three gates already, correctly, do not
look — without any gate gaining an exclusion, which §6 forbids. A new
directory would have needed both a Package.swift line and an entry in that
test's exemption set; this needed neither.

WHAT IT DOES: keys the exact magenta #EE03E1 to transparent and nothing else.
Deliberately not `art_common.strip_background`: that gained a fringe-snap and
a de-halo pass in 0.9.55's C4, both of which exist to clean up antialiased
sheet art. These maps are exported nearest-neighbour at 5x from flat fills, so
there is no fringe to snap, and the hit test in the app identifies a region by
matching its fill colour EXACTLY. A cleanup pass that shifted one pixel of
Bordeaux's #8E2F45 would make that pixel unresolvable.

Not run by any gate or by rasterize-icons.sh — this is test scaffolding, and
the drop is not a shipping art pipeline.
"""
import json, os, shutil, sys

from PIL import Image
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SRC = os.path.join(HERE, "out")
DEST = os.path.join(REPO, "Sources/VinodexUI/Resources/Maps/france")

KEY = (238, 3, 225)   # #EE03E1, exact — see the module note


def key_out(src, dst):
    im = Image.open(src).convert("RGBA")
    a = np.array(im)
    mask = (a[:, :, 0] == KEY[0]) & (a[:, :, 1] == KEY[1]) & (a[:, :, 2] == KEY[2])
    a[mask] = (0, 0, 0, 0)
    Image.fromarray(a, "RGBA").save(dst)
    return int(mask.sum()), a.shape[1] * a.shape[0]


def main():
    if not os.path.isdir(SRC):
        sys.exit(f"no {SRC} — run france_map.py first")
    os.makedirs(DEST, exist_ok=True)

    pngs = sorted(f for f in os.listdir(SRC) if f.endswith(".png"))
    if len(pngs) != 15:
        sys.exit(f"expected 15 PNGs (1 base + 14 detail), found {len(pngs)}")

    for name in pngs:
        keyed, total = key_out(os.path.join(SRC, name), os.path.join(DEST, name))
        print(f"  {name:26} {keyed * 100 / total:5.1f}% keyed")

    # The manifest and the index travel with the art: the app builds its
    # colour -> stem table from the manifest at load rather than hardcoding
    # hexes in Swift, so the palette has exactly one definition.
    for j in ("france-manifest.json", "france-region-index.json"):
        shutil.copy(os.path.join(SRC, j), os.path.join(DEST, j))
        print(f"  {j}")

    print(f"\ninstalled {len(pngs)} PNGs + 2 JSON into Resources/Maps/france/")


if __name__ == "__main__":
    main()
