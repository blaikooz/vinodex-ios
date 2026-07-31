#!/usr/bin/env python3
"""Imports the pixel-art style portraits into the app bundle.

Sources are the 31 individual style PNGs in art/icons/styles (contact sheets
live in art/icons/reference, not here — 0.5.8, A1). Same
treatment as the flavour importer: background removed via the shared
border-flood pass in art_common.py (interior white preserved — 0.5.7 B2),
palette-quantised, written to Sources/VinodexUI/Resources/StyleArt.

One of the 31 is a hand-recoloured master that never went through this pass
and is copied verbatim — see MASTERS below.

Which stems exist is decided by the generator's STYLE_ART table (it feeds
icons.json); this script converts exactly the stems that table names. Run
`npm run generate` first if you changed it.

Usage: python3 scripts/import-style-art.py [source-dir]
Requires Pillow.
"""
import json
import os
import sys

from PIL import Image

from art_common import copy_master, output_dir, resolve_source_dir, strip_background

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MANIFEST = os.path.join(ROOT, "Sources", "VinodexCore", "Resources", "icons.json")
DST = output_dir(ROOT, "StyleArt")

# Hand-recoloured, no generating pass — copied through untouched: a per-colour
# recolour of a reproducible sibling with an identical alpha silhouette, but
# with dozens of distinct HSV deltas it is hand work, not a formula.
# Re-quantising moves ~49% of its opaque pixels, so it must not go through
# strip_background. See art_common.copy_master (AUDIT H12).
#
# `mediumbodywhite` left this set in the testing merge: the 0.6.5 newpass
# batch delivered a real raw master for it (art/icons/styles), so it goes
# through the normal strip/quantise pass like any other style now.
MASTERS = {"sweetwhite"}


def main():
    src = resolve_source_dir(ROOT, "styles")
    with open(MANIFEST, encoding="utf-8") as fh:
        stems = sorted(set(json.load(fh).get("styleArt", {}).values()))
    if not stems:
        sys.exit("icons.json carries no styleArt table — run 'npm run generate'")

    os.makedirs(DST, exist_ok=True)
    missing = []
    total_out = 0
    for stem in stems:
        path = os.path.join(src, stem + ".png")
        if not os.path.exists(path):
            missing.append(stem)
            continue
        out = os.path.join(DST, stem + ".png")
        if stem in MASTERS:
            copy_master(path, out)
        else:
            strip_background(Image.open(path)).quantize(colors=256).save(out, optimize=True)
        total_out += os.path.getsize(out)

    print(f"converted {len(stems) - len(missing)} styles -> {DST} ({total_out // 1024}KB)")
    if missing:
        sys.exit(f"missing sources for: {', '.join(missing)}")


if __name__ == "__main__":
    main()
