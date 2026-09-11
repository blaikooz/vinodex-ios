#!/usr/bin/env python3
"""Install a country's region map into the bundle. Step 4 of HANDOFF.md.

    python3 install_art.py france
    python3 install_art.py italy

DESTINATION: Sources/VinodexUI/Resources/Maps/<country>/

`Maps` already exists (it holds the globe texture), is already `.copy()`d by
Package.swift, is already named in `ArtPipelineRosterTests.ownedByOtherLoaders`
as a directory another loader owns, and is absent from `verify-art.py`'s DIRS
tuple. So these land somewhere all three gates already, correctly, do not look
— without any gate gaining an exclusion, which §6 forbids.

WHAT IT DOES: keys the exact chroma magenta to transparent on the interactive
layer and the detail maps, and copies the backdrop verbatim.

Deliberately not `art_common.strip_background`: that gained a fringe-snap and
a de-halo pass in 0.9.55's C4, both for antialiased sheet art. These are
exported nearest-neighbour from flat fills, so there is no fringe to snap, and
the runtime identifies a region by matching its fill EXACTLY — a cleanup pass
that shifted one pixel of Bordeaux's fill would make that pixel unresolvable.

The backdrop is never keyed: it is opaque by design (sea, shelf, neighbouring
land) and keying it would punch holes wherever the renderer used a
magenta-ish tone. `*-map-preview.png` is the two composited for eyeballing and
is explicitly not for shipping, so it is not installed.
"""
import json, os, shutil, sys

from PIL import Image
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))


def key_out(src, dst, key):
    im = Image.open(src).convert("RGBA")
    a = np.array(im)
    mask = (a[:, :, 0] == key[0]) & (a[:, :, 1] == key[1]) & (a[:, :, 2] == key[2])
    a[mask] = (0, 0, 0, 0)
    Image.fromarray(a, "RGBA").save(dst)
    return int(mask.sum()), a.shape[0] * a.shape[1]


def main():
    name = (sys.argv[1] if len(sys.argv) > 1 else "france").lower()
    src = os.path.join(HERE, "out", name)
    dest = os.path.join(REPO, "Sources/VinodexUI/Resources/Maps", name)
    if not os.path.isdir(src):
        sys.exit(f"no {src} — run region_map.py {name} first")
    os.makedirs(dest, exist_ok=True)

    manifest = json.load(open(os.path.join(src, f"{name}-manifest.json")))
    hexkey = manifest["base"].get("key", "#EE03E1").lstrip("#")
    key = tuple(int(hexkey[i:i + 2], 16) for i in (0, 2, 4))
    backdrop = os.path.basename(manifest["base"]["layers"]["backdrop"])
    # The index raster is DATA, not art: one byte per logical cell naming the
    # region there. Keying it would rewrite those bytes into transparency and
    # destroy the hit test. Copied verbatim, like the backdrop.
    index = f"{name}-index.png"

    # A stale detail map from a previous render would sit in the bundle
    # forever otherwise — the region set is config and can change.
    for old in os.listdir(dest):
        if old.endswith(".png") or old.endswith(".json"):
            os.remove(os.path.join(dest, old))

    kept = 0
    pngs = sorted(f for f in os.listdir(src) if f.endswith(".png"))
    for f in sorted(os.listdir(src)):
        if f.endswith("-map-preview.png"):
            continue
        if f.endswith(".json"):
            shutil.copy(os.path.join(src, f), os.path.join(dest, f))
            print(f"  {f}")
            continue
        if not f.endswith(".png"):
            continue
        if f in (backdrop, index):
            shutil.copy(os.path.join(src, f), os.path.join(dest, f))
            why = "index raster — data" if f == index else "opaque backdrop"
            print(f"  {f:28}   verbatim ({why})")
            continue
        keyed, total = key_out(os.path.join(src, f), os.path.join(dest, f), key)
        print(f"  {f:28} {keyed * 100 / total:5.1f}% keyed")
        kept += 1

    print(f"\ninstalled {name}: {kept} keyed PNGs + backdrop into Resources/Maps/{name}/")


if __name__ == "__main__":
    main()
