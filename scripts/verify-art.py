#!/usr/bin/env python3
"""Checks that the committed drawn art still matches what art/ regenerates.

`npm run icons:verify`. Read-only against the working tree: the importers are
re-run with `ART_OUT` pointed at a temp directory, so this can never overwrite
Sources/VinodexUI/Resources/*Art.

Three outcomes per file:

  IDENTICAL      every pixel matches.
  TOLERATED      differs, but by no more than the recorded budget in
                 TOLERANCE. These are the quantiser-boundary files (below).
  CHANGED        differs beyond the budget — the art or a source moved.

Byte-identity is deliberately *not* the gate. `Image.quantize(colors=256)`
picks a palette whose ORDER varies across Pillow versions, and PNG IDAT bytes
depend on the deflate build the wheel links (Pillow 12.3 bundles zlib-ng), so
byte equality fails on a clean tree for reasons that have nothing to do with
the art. Pixels are the thing that ships.

Why TOLERANCE exists at all (AUDIT H12): ten sources carry 12k-27k distinct
colours after background removal, so the 256-colour quantise is genuinely
lossy for them and FASTOCTREE resolves the palette slightly differently than
whichever Pillow produced the committed bytes. The residue is a handful of
pixels on colour boundaries — visually identical, not byte-reproducible. The
budgets below are the measured deltas plus headroom; they are a record of a
known imprecision, not permission to change art.
"""
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BUNDLE = os.path.join(ROOT, "Sources", "VinodexUI", "Resources")
DIRS = ("FlavorArt", "GrapeArt", "StyleArt", "ClassArt")
IMPORTERS = (
    "import-flavor-art.py",
    "import-grape-art.py",
    "import-style-art.py",
    "import-class-art.py",
)

# Measured 2026-07-31 on Pillow 12.3.0 / darwin-arm64, against the bundle at
# b48ad20. Budgets are 4x the observed delta so a different Pillow's octree
# has room, while a real edit (hundreds to thousands of pixels) still fails.
TOLERANCE = {
    "FlavorArt/petrol.png": 900,
    "ClassArt/subclass-floral.png": 450,
    "ClassArt/subclass-citrus.png": 250,
    "StyleArt/crubeaujolas.png": 150,
    "GrapeArt/green-pink-rare.png": 100,
    "ClassArt/globe-north-america.png": 100,
    "FlavorArt/strawberrycandy.png": 100,
    "GrapeArt/green-pink-light-common.png": 50,
    "StyleArt/supertuscan.png": 50,
    "GrapeArt/green-pink-light-rare.png": 50,
}


def differing_pixels(a, b):
    ia = Image.open(a).convert("RGBA")
    ib = Image.open(b).convert("RGBA")
    if ia.size != ib.size:
        return None
    pa, pb = ia.load(), ib.load()
    w, h = ia.size
    return sum(1 for y in range(h) for x in range(w) if pa[x, y] != pb[x, y])


def main():
    out = tempfile.mkdtemp(prefix="vinodex-art-")
    try:
        env = dict(os.environ, ART_OUT=out)
        failed = []
        for importer in IMPORTERS:
            r = subprocess.run(
                [sys.executable, os.path.join(HERE, importer)],
                env=env, capture_output=True, text=True,
            )
            if r.returncode != 0:
                failed.append(f"{importer}: {r.stdout.strip()} {r.stderr.strip()}")

        identical = tolerated = 0
        changed, missing = [], []
        for d in DIRS:
            for name in sorted(os.listdir(os.path.join(BUNDLE, d))):
                key = f"{d}/{name}"
                committed = os.path.join(BUNDLE, d, name)
                regen = os.path.join(out, d, name)
                if not os.path.exists(regen):
                    missing.append(key)
                    continue
                n = differing_pixels(committed, regen)
                if n == 0:
                    identical += 1
                elif n is not None and n <= TOLERANCE.get(key, 0):
                    tolerated += 1
                    print(f"  TOLERATED {key} ({n}px, budget {TOLERANCE[key]})")
                else:
                    changed.append((key, "size mismatch" if n is None else f"{n}px"))

        print(f"\n{identical} identical · {tolerated} tolerated · "
              f"{len(changed)} changed · {len(missing)} not regenerated")
        for key, why in changed:
            print(f"  CHANGED  {key} — {why}")
        for key in missing:
            print(f"  NO OUTPUT {key} — no source under art/, or its table entry is gone")
        for line in failed:
            print(f"  IMPORTER FAILED {line}")

        if changed or missing or failed:
            sys.exit(1)
        print("art/ reproduces the committed bundle.")
    finally:
        shutil.rmtree(out, ignore_errors=True)


if __name__ == "__main__":
    main()
