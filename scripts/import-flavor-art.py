#!/usr/bin/env python3
"""Imports the pixel-art flavour portraits into the app bundle.

Sources are the hand-drawn PNGs in the monorepo's shared/newicons. They ship
on a near-white opaque ground, so this pass:

  1. removes the background via the shared pass in art_common.py — the
     border-connected flood only, so interior/subject white survives
     (0.5.7 item B2);
  2. palette-quantises (flat cel shading, so 256 colours is lossless in
     practice and the files drop to a fraction of the size);
  3. writes each as <stem>.png into Sources/VinodexUI/Resources/FlavorArt.

Which stems exist is *not* decided here: the generator's FLAVOR_ART table is
the source of truth (it feeds icons.json), and this script converts exactly
the stems that table names. Run `npm run generate` first if you changed it.

Usage: python3 scripts/import-flavor-art.py [source-dir]
Source defaults to the repo's art/icons/flavors — the flat, per-use layout
that replaced the drop-folder waves under shared/newicons (0.5.8, A1).
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
DST = os.path.join(ROOT, "Sources", "VinodexUI", "Resources", "FlavorArt")


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    candidate = os.path.join(ROOT, "art", "icons", "flavors")
    if os.path.isdir(candidate):
        return candidate
    sys.exit("no source dir found; pass it explicitly")


def source_file(src, stem):
    # Stems are the source basenames with spaces kebabed, so try both ways —
    # "orange-blossom" is a real hyphen, "red-apple" was "red apple.png".
    for name in (stem + ".png", stem.replace("-", " ") + ".png"):
        path = os.path.join(src, name)
        if os.path.exists(path):
            return path
    return None


def main():
    src = source_dir()
    with open(MANIFEST, encoding="utf-8") as fh:
        stems = sorted(set(json.load(fh).get("flavorArt", {}).values()))
    if not stems:
        sys.exit("icons.json carries no flavorArt table — run 'npm run generate'")

    os.makedirs(DST, exist_ok=True)
    missing = []
    total_out = 0
    for stem in stems:
        path = source_file(src, stem)
        if path is None:
            missing.append(stem)
            continue
        img = strip_background(Image.open(path))
        out = os.path.join(DST, stem + ".png")
        img.quantize(colors=256).save(out, optimize=True)
        total_out += os.path.getsize(out)

    print(f"converted {len(stems) - len(missing)} portraits -> {DST} ({total_out // 1024}KB)")
    if missing:
        sys.exit(f"missing sources for: {', '.join(missing)}")


if __name__ == "__main__":
    main()
