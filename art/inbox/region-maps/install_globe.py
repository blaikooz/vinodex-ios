#!/usr/bin/env python3
"""Build and install the wine-country globe texture.  python3 install_globe.py

`globe-index.png` is an INDEX, not a picture: 2048x1024 equirectangular, one
byte per cell naming which of 30 wine countries is there (0 = everywhere
else). `globe-meta.json` carries each country's fill. This colourises the one
with the other and installs the result as a plain texture the existing globe
can wear.

WHY COLOURISE HERE RATHER THAN AT RUNTIME: the globe's material pipeline
already inverts and re-tints its texture per screen mode
(`RetroGlobeScreen.colorized`), and adding a third per-frame pass over a
2-megapixel image to do something that never changes would be paying every
frame for a constant.

WHAT IS NOT INSTALLED: `globe-index.png` itself. Tapping the globe to pick a
country is the prototype's real interaction and AUDIT §5 is explicit that it
has never run outside a desktop browser — per-pixel un-projection at 60fps on
a phone being exactly the kind of thing that is fine until it is not. This
ships the *look* behind a setting so it can be judged on a device; the
interaction stays upstream until someone measures it.
"""
import json, os, sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DEST = os.path.join(REPO, "Sources/VinodexUI/Resources/Maps")

# The ground the wine countries sit on. Deliberately not black: the globe's
# own material multiplies and re-tints, and a pure-black land mass renders as
# a hole rather than as land in the lighter screen modes.
SEA = (14, 22, 34)
LAND = (58, 62, 70)


def main():
    idx = np.array(Image.open(os.path.join(HERE, "globe-index.png")))
    meta = json.load(open(os.path.join(HERE, "globe-meta.json")))

    out = np.zeros(idx.shape + (3,), dtype=np.uint8)
    out[:, :] = SEA

    # Everything the index calls land but does not call a wine country. The
    # index only paints the 30; there is no separate land mask, so anything
    # non-zero that is not in the table would be a bug rather than a shore.
    known = {}
    for c in meta["countries"]:
        h = c["fill"].lstrip("#")
        known[c["idx"]] = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

    painted = 0
    for value in sorted(set(idx.ravel().tolist())):
        if value == 0:
            continue
        mask = idx == value
        if value in known:
            out[mask] = known[value]
            painted += 1
        else:
            out[mask] = LAND
            print(f"  index {value} has no country in the meta — drawn as land")

    os.makedirs(DEST, exist_ok=True)
    path = os.path.join(DEST, "globe-wine.png")
    Image.fromarray(out, "RGB").save(path, optimize=True)
    kb = os.path.getsize(path) / 1024
    print(f"installed globe-wine.png — {idx.shape[1]}x{idx.shape[0]}, "
          f"{painted} wine countries, {kb:.0f} KB")


if __name__ == "__main__":
    main()
