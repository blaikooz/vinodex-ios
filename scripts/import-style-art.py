#!/usr/bin/env python3
"""Imports the pixel-art style portraits into the app bundle.

Sources are the 29 individual style PNGs in shared/newicons/2new (the two
`stylesicons*.png` contact sheets there are references, not sources). Same
treatment as the flavour importer: background removed via the shared pass in
art_common.py (border flood + enclosed-gap clearing, speculars preserved),
palette-quantised, written to Sources/VinodexUI/Resources/StyleArt.

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

from art_common import strip_background

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MANIFEST = os.path.join(ROOT, "Sources", "VinodexCore", "Resources", "icons.json")
DST = os.path.join(ROOT, "Sources", "VinodexUI", "Resources", "StyleArt")


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    for candidate in (
        os.path.join(ROOT, "shared", "newicons", "2new"),
        os.path.join(os.path.dirname(ROOT), "shared", "newicons", "2new"),
    ):
        if os.path.isdir(candidate):
            return candidate
    sys.exit("no source dir found; pass it explicitly")


def main():
    src = source_dir()
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
        img = strip_background(Image.open(path))
        out = os.path.join(DST, stem + ".png")
        img.quantize(colors=256).save(out, optimize=True)
        total_out += os.path.getsize(out)

    print(f"converted {len(stems) - len(missing)} styles -> {DST} ({total_out // 1024}KB)")
    if missing:
        sys.exit(f"missing sources for: {', '.join(missing)}")


if __name__ == "__main__":
    main()
