#!/usr/bin/env python3
"""Imports the grape bunch sprites into the app bundle.

Sources are the recoloured bunch set in art/icons/entries/grapes (0.5.8, A1) — one
identical bunch per file, recoloured across colour/depth/blend with the leaf
coloured by rarity. This pass canonicalises the artist's file names into the
`<color>-<depth>[-<blend>]-<leaf>` stems the generator's `grapeArt` table
points at, strips the white ground (flood fill in from the edges), palette-
quantises, and writes Sources/VinodexUI/Resources/GrapeArt.

The generator (buildGrapeArt in generate-ios-data.ts) maps the full combo
grid onto these stems with fallbacks — run `npm run generate` after changing
either side, and keep SOURCE_TO_STEM in step with the table's expectations.

The three `gold-*-rare` bunches are hand-recoloured masters with no generating
pass; they are listed in MASTERS and copied verbatim rather than re-imported.

Usage: python3 scripts/import-grape-art.py [source-dir]
Requires Pillow.
"""
import colorsys
import os
import sys

from PIL import Image

from art_common import (
    copy_master,
    output_dir,
    quantize_stable,
    resolve_source_dir,
    save_stable,
    strip_background,
)


def darken_reds(img):
    """0.6.2 (E3): the light and medium red bunches read as cherry-red berries;
    pull their red hues down to a darker, wine-dark tone. Applied here so the
    correction survives every re-import from the artist's masters."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if (hh < 0.06 or hh > 0.92) and ss > 0.4 and vv > 0.2:
                rr, gg, bb = colorsys.hsv_to_rgb(hh, min(1.0, ss * 1.05), vv * 0.68)
                px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
    return img

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DST = output_dir(ROOT, "GrapeArt")

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
    # The green blends, at all three depths since the 0.9.47 quick-fix sheet.
    # The old sources (greenpinkrare.png and friends) are retired: their
    # orange-red leaf sat outside the yellow band and broke the rarity
    # re-ink, which is half of what the sheet was commissioned to fix.
    "greenpinklight.png": "green-pink-light-rare",
    "greenpinkmedium.png": "green-pink-medium-rare",
    "greenpinkfull.png": "green-pink-full-rare",
    "greenamberlight.png": "green-amber-light-rare",
    "greenambermedium.png": "green-amber-medium-rare",
    "greenamberfull.png": "green-amber-full-rare",
    # The ampelographic portraits (0.9.47): flagships drawn as themselves.
    "pinotnoir.png": "pinotnoir",
    "cabernetsauvignon.png": "cabernetsauvignon",
    "chardonnay.png": "chardonnay",
    "merlot.png": "merlot",
    "syrah.png": "syrah",
    "sauvignonblanc.png": "sauvignonblanc",
    "riesling.png": "riesling",
    "nebbiolo.png": "nebbiolo",
    "sangiovese.png": "sangiovese",
    "grenache.png": "grenache",
    "tempranillo.png": "tempranillo",
    "malbec.png": "malbec",
    "cheninblanc.png": "cheninblanc",
    "gamay.png": "gamay",
    "zinfandel.png": "zinfandel",
    "pinotgris.png": "pinotgris",
    "gewurztraminer.png": "gewurztraminer",
    "muscatblanc.png": "muscatblanc",
    "barbera.png": "barbera",
    "viognier.png": "viognier",
    "touriganacional.png": "touriganacional",
    "assyrtiko.png": "assyrtiko",
    "furmint.png": "furmint",
    # The GODFORSAKEN tier's shared gnarl. The eight archetype masters are
    # handled separately (ARCH_SOURCES): each yields three hue variants.
    "archgodforsaken.png": "arch-godforsaken",
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
    # The gold set is hand-recoloured with no generating pass — see MASTERS.
    # Absent from this table until 0.6.4, which is why the importer produced 30
    # stems against a bundle shipping 33 and the three golds were invisible to
    # any clean-room rebuild while icons.json referenced them live (AUDIT H12).
    "goldfullrare.png": "gold-full-rare",
    "goldlightrare.png": "gold-light-rare",
    "goldmediumrare.png": "gold-medium-rare",
}

# Copied through untouched, for the reason given in art_common.copy_master.
MASTERS = {"gold-full-rare", "gold-light-rare", "gold-medium-rare"}

# The sheet-D cluster archetypes (0.9.47): drawn once in a neutral mid-red,
# multiplied here into the three catalog hues. The berry pixels are
# hue-rotated; the leaf (yellow band) and the outline (near-black) are left
# alone, so the runtime rarity re-ink keeps its contract on every variant.
ARCH_SOURCES = {
    "archpineconesmall.png": "pinecone-small",
    "archpineconelarge.png": "pinecone-large",
    "archconesmall.png": "cone-small",
    "archconelarge.png": "cone-large",
    "archpyramidsmall.png": "pyramid-small",
    "archpyramidlarge.png": "pyramid-large",
    "archloosesmall.png": "loose-small",
    "archlooselarge.png": "loose-large",
}

# hue, saturation scale, value scale per variant. Red passes through.
ARCH_HUES = {
    "red": None,
    "green": (0.24, 0.95, 1.0),
    "gold": (0.115, 1.05, 1.0),
}


def berry_hue_shift(img, variant):
    """Rotate an archetype master's berries to the variant hue. The leaf's
    yellow band and the cel outline are untouched; desaturated glints keep
    their shading."""
    target = ARCH_HUES[variant]
    if target is None:
        return img
    th, ss, vs = target
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hh, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.08 <= hh <= 0.17 and s > 0.45:
                continue  # the leaf stays yellow for the runtime re-ink
            if v < 0.22 or s < 0.18:
                continue  # outline and glints
            if hh <= 0.09 or hh >= 0.85:  # the red masters' berry range
                rr, gg, bb = colorsys.hsv_to_rgb(th, min(1.0, s * ss), min(1.0, v * vs))
                px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
    return img


def main():
    src = resolve_source_dir(ROOT, "entries", "grapes")
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
        out = os.path.join(DST, stem + ".png")
        if stem in MASTERS:
            copy_master(path, out)
        else:
            img = strip_background(Image.open(path))
            if stem.startswith("red-light") or stem.startswith("red-medium"):
                img = darken_reds(img)
            # See art_common (0.8.0, A0b): pinned quantise, and a run
            # whose pixels match leaves the file and its mtime alone.
            save_stable(quantize_stable(img), out, optimize=True)
        converted += 1
        total_out += os.path.getsize(out)

    # The archetype masters, multiplied into their three hues.
    for name, cluster in sorted(ARCH_SOURCES.items()):
        path = os.path.join(src, name)
        if not os.path.exists(path):
            missing.append(name)
            continue
        base = strip_background(Image.open(path))
        for variant in ("red", "green", "gold"):
            out = os.path.join(DST, f"arch-{cluster}-{variant}.png")
            save_stable(quantize_stable(berry_hue_shift(base, variant)), out, optimize=True)
            converted += 1
            total_out += os.path.getsize(out)

    print(f"converted {converted} bunches -> {DST} ({total_out // 1024}KB)")
    if missing:
        sys.exit(f"missing sources: {', '.join(missing)}")


if __name__ == "__main__":
    main()
