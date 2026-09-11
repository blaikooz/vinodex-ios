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

ALSO INSTALLED (0.9.55, maintainer order): `globe-index.png` and
`globe-meta.json` themselves, because the interaction is now wired — tapping
the sphere picks a country. AUDIT §5's worry was per-pixel un-projection at
60fps, and that is not what this does: SceneKit's own `hitTest` answers ONE
ray when a finger lands, which is a hit test rather than a render pass. The
index is read once per tap, not once per frame.
"""
import json, os, shutil, sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DEST = os.path.join(REPO, "Sources/VinodexUI/Resources/Maps")

# The ground the wine countries sit on. Deliberately not black: the globe's
# own material multiplies and re-tints, and a pure-black land mass renders as
# a hole rather than as land in the lighter screen modes.
SEA = (10, 16, 26)
LAND = (52, 56, 64)
# Every border and coastline, drawn where two index values meet. Dark rather
# than light: on a sphere at 8x the outline is the only thing separating two
# neighbouring fills, and a light line reads as a third country between them.
OUTLINE = (6, 9, 16)

# **The wine countries are drawn bright, and the app no longer tints them.**
# `colorized` used to reduce this whole texture to luma and multiply it by the
# screen tint, so thirty authored colours landed on one green and "which
# countries can I tap" had no answer. With the tint gone these fills are what
# reaches the glass, and the authored palette was chosen to sit UNDER that
# tint — muted, because the tint was going to supply the light. Lifted toward
# white so they carry themselves.
def brighten(rgb):
    # Lifted in HSV rather than blended toward white. Blending raises value and
    # drops saturation together, which is why the first pass came out pastel:
    # thirty washed colours are harder to tell apart than thirty muted ones.
    # Raising value and holding saturation keeps them distinct AND bright.
    import colorsys
    h, s_, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    v = min(1.0, v * 2.05)
    s_ = min(1.0, s_ * 1.18)
    return tuple(int(round(c * 255)) for c in colorsys.hsv_to_rgb(h, s_, v))


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
            out[mask] = brighten(known[value])
            painted += 1
        else:
            out[mask] = LAND
            print(f"  index {value} has no country in the meta — drawn as land")

    os.makedirs(DEST, exist_ok=True)
    for f in ("globe-index.png", "globe-meta.json"):
        shutil.copy(os.path.join(HERE, f), os.path.join(DEST, f))
        print(f"  {f}   verbatim (index + meta — data)")
    # Outlines last, so they sit on top of every fill. A cell is a border when
    # the cell to its right or below carries a different index — one pass, no
    # neighbour search, and it catches coastlines and land borders alike
    # because the sea is an index value too.
    right = np.zeros_like(idx, dtype=bool)
    down = np.zeros_like(idx, dtype=bool)
    right[:, :-1] = idx[:, :-1] != idx[:, 1:]
    down[:-1, :] = idx[:-1, :] != idx[1:, :]
    edges = right | down
    out[edges] = OUTLINE
    print(f"  outlines   {edges.sum():,} cells")

    path = os.path.join(DEST, "globe-wine.png")
    Image.fromarray(out, "RGB").save(path, optimize=True)
    kb = os.path.getsize(path) / 1024
    print(f"installed globe-wine.png — {idx.shape[1]}x{idx.shape[0]}, "
          f"{painted} wine countries, {kb:.0f} KB")


if __name__ == "__main__":
    main()
