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

A fourth state exists for the handful of bundle PNGs no importer produces: see
`UNMANAGED`. And note what this script is *not*: it re-runs the importers and
diffs pixels, so it can only answer "did the committed art change". It has no
access to the catalog, so it cannot know which icon ids are actually requested —
that is `assertAssetsExist` in scripts/generate-ios-data.ts (0.7.5, A028).

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

# One entry per importer, and it must stay that way: `IMPORTERS` is asserted
# equal to `rasterize-icons.sh`'s roster by ArtPipelineRosterTests, because the
# two drifted apart silently for two releases (0.7.5, A027). `import-stamp-art`
# was in the rasteriser and not here — StampArt was generated and never verified
# — and `import-logo-art` was in neither.
DIRS = ("FlavorArt", "GrapeArt", "StyleArt", "ClassArt", "StampArt", "Logo")
IMPORTERS = (
    "import-flavor-art.py",
    "import-grape-art.py",
    "import-style-art.py",
    "import-class-art.py",
    "import-stamp-art.py",
    "import-logo-art.py",
)

# Bundle PNGs that no importer produces, so "not regenerated" is their correct
# state rather than a fault. `vinodex-logo.png` is the chassis badge, hand-placed
# in the original SwiftUI port (acdc74f) and never derived from art/icons/ — it
# is not the screensaver wordmark, which import-logo-art.py does produce as the
# `vinodex-mark-*` pair. The set is checked for rot below: the moment an importer
# starts emitting one of these, the exemption has to go.
UNMANAGED = {"Logo/vinodex-logo.png"}

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
    # Measured 2026-08-03 on Pillow 12.3.0 / **win32**, wiring up A026/A027.
    # These six were reported CHANGED on this machine and were CHANGED at
    # 4c308ae too, so they are not this batch's doing — `icons:verify` was
    # already red, and only the two files it now also covers were new.
    #
    # They are the same six-file family as `subclass-citrus` and
    # `subclass-floral` above, and measured against those two as controls they
    # are indistinguishable: 0.009-0.257% of pixels moved (controls 0.115-0.199%),
    # max per-channel delta 17-31 (controls 15-37), and **zero alpha pixels
    # moved** in any of the eight — nothing gained or lost a silhouette, which
    # is what an actual art edit would show first. So this is the recorded
    # imprecision crossing a platform boundary rather than a change to the art:
    # the table above was measured on darwin-arm64 and the pipeline is now also
    # run on win32 and in WSL.
    "ClassArt/subclass-herbal.png": 320,
    "ClassArt/subclass-stone-fruit.png": 320,
    "ClassArt/subclass-berry.png": 200,
    "ClassArt/subclass-red-fruit.png": 200,
    "ClassArt/subclass-baking.png": 50,
    "ClassArt/subclass-vegetal.png": 50,
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
        changed, missing, exempt = [], [], []
        for d in DIRS:
            src = os.path.join(BUNDLE, d)
            # StampArt ships empty until the glyphs are authored (0.6.4, F2/F3),
            # so its directory legitimately does not exist. An absent bundle
            # directory is not this script's business — the *generator* is what
            # fails when a shipped id has no file behind it.
            if not os.path.isdir(src):
                continue
            for name in sorted(os.listdir(src)):
                if not name.lower().endswith(".png"):
                    continue
                key = f"{d}/{name}"
                committed = os.path.join(BUNDLE, d, name)
                regen = os.path.join(out, d, name)
                if key in UNMANAGED:
                    if os.path.exists(regen):
                        exempt.append(key)
                    continue
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
              f"{len(changed)} changed · {len(missing)} not regenerated · "
              f"{len(UNMANAGED)} unmanaged")
        for key, why in changed:
            print(f"  CHANGED  {key} — {why}")
        for key in missing:
            print(f"  NO OUTPUT {key} — no source under art/, or its table entry is gone")
        for key in exempt:
            print(f"  STALE EXEMPTION {key} — an importer now produces this; drop it from UNMANAGED")
        for line in failed:
            print(f"  IMPORTER FAILED {line}")

        if changed or missing or exempt or failed:
            sys.exit(1)
        print("art/ reproduces the committed bundle.")
    finally:
        shutil.rmtree(out, ignore_errors=True)


if __name__ == "__main__":
    main()
