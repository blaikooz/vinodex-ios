#!/usr/bin/env python3
"""Gives source art a magenta chroma-key background, in place (0.5.8, B3).

The durable answer to the enclosed-white problem: once background and subject
stop sharing a colour, `art_common.strip_background()` takes its chroma path
and clears exactly the key, everywhere — border-connected or enclosed — while
every white subject pixel survives untouched.

What gets keyed:
  1. the border-connected near-white ground (what the flood pass clears), and
  2. enclosed near-white components of MIN_POCKET pixels or more — the gaps
     between cherry stems, inside handles and bowls. The floor spares small
     specular highlights, which are the only legitimately white enclosed
     regions in otherwise-coloured art.

Run it only on icons whose enclosed white IS background, and eyeball the
result: an icon with large enclosed white *subject* (Chalk, White Blossom)
must never go through this — its ground is already handled by the flood pass.

**Already keyed, and the only four that are** (0.6.4, AUDIT H12):

    art/icons/entries/flavors/cherry.png        ground 24193px + 3 pockets (3425px)
    art/icons/entries/flavors/blackcherry.png   ground 19054px + 3 pockets (2586px)
    art/icons/entries/body/full.png             ground  3756px + 1 pocket  (1063px)
    art/icons/entries/body/medium.png           ground 15259px + 2 pockets (2196px)

Those four are exactly the assets that did not reproduce from an un-keyed
source, so the list is load-bearing: re-importing them from a fresh artist
drop without keying first silently brings the enclosed-white pockets back —
the defect this file exists to fix — and `npm run icons:verify` is what
catches it. Re-running on an already-keyed file is a no-op (the ground is
magenta, so `is_white` never fires), so keying is safe to repeat.

This rewrites the source **in place**; the un-keyed masters survive only in
git history.

Usage: python3 scripts/key-background.py <png> [<png> ...]
Paths resolve as given, then relative to art/icons. Requires Pillow.
"""
import os
import sys
from collections import deque

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ART = os.path.join(ROOT, "art", "icons")

WHITE_FLOOR = 240
MIN_POCKET = 100
KEY = (255, 0, 255, 255)


def key_background(path):
    img = Image.open(path).convert("RGBA")
    px = img.load()
    w, h = img.size

    def is_white(x, y):
        r, g, b, a = px[x, y]
        return a > 0 and r >= WHITE_FLOOR and g >= WHITE_FLOOR and b >= WHITE_FLOOR

    # Border-connected ground.
    outside = set()
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_white(x, y):
                queue.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_white(x, y):
                queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        if (x, y) in outside or not is_white(x, y):
            continue
        outside.add((x, y))
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in outside:
                queue.append((nx, ny))

    # Enclosed pockets over the floor.
    keyed = set(outside)
    seen = set(outside)
    pockets = 0
    for sy in range(h):
        for sx in range(w):
            if (sx, sy) in seen or not is_white(sx, sy):
                continue
            component = []
            queue = deque([(sx, sy)])
            seen.add((sx, sy))
            while queue:
                x, y = queue.popleft()
                component.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and is_white(nx, ny):
                        seen.add((nx, ny))
                        queue.append((nx, ny))
            if len(component) >= MIN_POCKET:
                keyed.update(component)
                pockets += 1

    for x, y in keyed:
        px[x, y] = KEY
    img.save(path)
    print(f"keyed {os.path.relpath(path, ROOT)}: ground {len(outside)}px + {pockets} pockets ({len(keyed) - len(outside)}px)")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for arg in sys.argv[1:]:
        path = arg if os.path.exists(arg) else os.path.join(ART, arg)
        if not os.path.exists(path):
            sys.exit(f"not found: {arg}")
        key_background(path)


if __name__ == "__main__":
    main()
