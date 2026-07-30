#!/usr/bin/env python3
"""Imports the grape bunch sprites into the app bundle.

Sources are the recoloured bunch set in shared/newicons/1new/grapes — one
identical bunch per file, recoloured across colour/depth/blend with the leaf
coloured by rarity. This pass canonicalises the artist's file names into the
`<color>-<depth>[-<blend>]-<leaf>` stems the generator's `grapeArt` table
points at, strips the white ground (flood fill in from the edges), palette-
quantises, and writes Sources/VinodexUI/Resources/GrapeArt.

The generator (buildGrapeArt in generate-ios-data.ts) maps the full combo
grid onto these stems with fallbacks — run `npm run generate` after changing
either side, and keep SOURCE_TO_STEM in step with the table's expectations.

Usage: python3 scripts/import-grape-art.py [source-dir]
Requires Pillow.
"""
import os
import sys
from collections import deque

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DST = os.path.join(ROOT, "Sources", "VinodexUI", "Resources", "GrapeArt")

WHITE_FLOOR = 240

# Artist file name -> canonical stem. `redlight.png` is a byte-duplicate of
# `redlightrare.png` and is deliberately absent; the `greeen…` typo is the
# artist's, preserved here so the mapping keeps working against the drop.
SOURCE_TO_STEM = {
    "greencommon.png": "green-common",
    "greenlightrare.png": "green-light-rare",
    "greenlightnoble.png": "green-light-noble",
    "greenmediumcommon.png": "green-medium-common",
    "greenmediumrare.png": "green-medium-rare",
    "greenmediumnoble.png": "green-medium-noble",
    "greenfullcommon.png": "green-full-common",
    "greenfullrare.png": "green-full-rare",
    "greenfullnoble.png": "green-full-noble",
    "greenambercommon.png": "green-amber-common",
    "greenamberrare.png": "green-amber-rare",
    "greenambernoble.png": "green-amber-noble",
    "greenpinklightcommon.png": "green-pink-light-common",
    "greeenpinklightrare.png": "green-pink-light-rare",
    "greenpinkrare.png": "green-pink-rare",
    "redlightcommon.png": "red-light-common",
    "redlightrare.png": "red-light-rare",
    "redlightnoble.png": "red-light-noble",
    "redmediumcommon.png": "red-medium-common",
    "redmediumrare.png": "red-medium-rare",
    "redmediumnoble.png": "red-medium-noble",
    "redfullcommon.png": "red-full-common",
    "redfullrare.png": "red-full-rare",
    "redfullnoble.png": "red-full-noble",
    "redambermediumcommon.png": "red-amber-medium-common",
    "redambermediumrare.png": "red-amber-medium-rare",
    "redambermediumnoble.png": "red-amber-medium-noble",
    "redpinkcommon.png": "red-pink-common",
    "redpinkrare.png": "red-pink-rare",
    "redpinknoble.png": "red-pink-noble",
    "redlight.png": None,  # duplicate of red-light-rare; skipped
}


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    for candidate in (
        os.path.join(ROOT, "shared", "newicons", "1new", "grapes"),
        os.path.join(os.path.dirname(ROOT), "shared", "newicons", "1new", "grapes"),
    ):
        if os.path.isdir(candidate):
            return candidate
    sys.exit("no source dir found; pass it explicitly")


def strip_background(img):
    """Flood-fills near-white to transparent, in from every edge pixel.
    Same pass as import-flavor-art.py — kept inline so each importer stays a
    single runnable file."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size

    def is_ground(x, y):
        r, g, b, a = px[x, y]
        return a > 0 and r >= WHITE_FLOOR and g >= WHITE_FLOOR and b >= WHITE_FLOOR

    queue = deque()
    seen = set()
    for x in range(w):
        for y in (0, h - 1):
            if is_ground(x, y):
                queue.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_ground(x, y):
                queue.append((x, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or not is_ground(x, y):
            continue
        seen.add((x, y))
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen:
                queue.append((nx, ny))
    return img


def main():
    src = source_dir()
    os.makedirs(DST, exist_ok=True)

    converted = 0
    total_out = 0
    missing = []
    for name, stem in sorted(SOURCE_TO_STEM.items()):
        if stem is None:
            continue
        path = os.path.join(src, name)
        if not os.path.exists(path):
            missing.append(name)
            continue
        img = strip_background(Image.open(path))
        out = os.path.join(DST, stem + ".png")
        img.quantize(colors=256).save(out, optimize=True)
        converted += 1
        total_out += os.path.getsize(out)

    print(f"converted {converted} bunches -> {DST} ({total_out // 1024}KB)")
    if missing:
        sys.exit(f"missing sources: {', '.join(missing)}")


if __name__ == "__main__":
    main()
