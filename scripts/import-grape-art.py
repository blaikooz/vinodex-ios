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
    # The GODFORSAKEN gnarl moved to ARCH_SOURCES in 0.9.50: it rendered
    # its neutral mid-red for every member, which put red bunches on the
    # tier's eight white grapes. It hue-shifts like any other master now.
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
# Unmarked (no sentinel leaf), so the runtime re-ink skips them and their
# drawn leaf stands — they are dead fallbacks since every grape gained a
# portrait in 0.9.47.
MASTERS = {"gold-full-rare", "gold-light-rare", "gold-medium-rare"}

# --- The sentinel leaf (0.9.50) -------------------------------------------
#
# Runtime leaf detection by yellow-band heuristics broke the moment berries
# shared the band: Riesling's golden bunch unioned into an 81%-of-sprite
# "leaf" and NOBLE re-inked the whole thing purple. The fix moves the
# decision here, where it runs once and can be eyeballed: each sprite's
# leaf pixels are re-hued to a SENTINEL no berry uses (teal, hue 0.47,
# shading kept), and `GrapeSpriteLoader` simply repaints that band. A
# sprite that ships unmarked keeps its drawn leaf at every rarity, which
# degrades honestly.
SENTINEL_HUE = 0.47

# Hand-verified leaf boxes (x0, y0, x1, y1 in source pixels) for the
# sprites whose berries live in the leaf's own band — auto-detection is
# ambiguous there by construction. Within the box, leaf pixels are the
# ORANGE side of the band (h <= 0.125); the yellower berries stay fruit.
LEAF_BBOX = {
    "riesling": (42, 4, 100, 62),
    "chardonnay": (48, 8, 113, 60),
    "muscatblanc": (0, 6, 52, 58),
}
# Auto-detected masks above this share of opaque pixels fail the import:
# it means a bunch got captured and the stem needs a LEAF_BBOX row.
MASK_CAP = 0.32


def _leaf_pixels_auto(img):
    """The old runtime heuristic, run offline: yellow-band components,
    top-weighted largest wins, smaller lobes within its box join it."""
    px = img.load()
    w, h = img.size
    band = set()
    opaque = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a <= 40:
                continue
            opaque += 1
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.08 <= hh <= 0.17 and ss > 0.45 and vv > 0.35:
                band.add((x, y))
    if not band:
        return set(), opaque
    seen = set()
    comps = []
    for p in band:
        if p in seen:
            continue
        stack = [p]
        seen.add(p)
        comp = []
        while stack:
            c = stack.pop()
            comp.append(c)
            for n in ((c[0] - 1, c[1]), (c[0] + 1, c[1]), (c[0], c[1] - 1), (c[0], c[1] + 1)):
                if n in band and n not in seen:
                    seen.add(n)
                    stack.append(n)
        comps.append(comp)

    def score(c):
        cy = sum(p[1] for p in c) / len(c) / max(h - 1, 1)
        return len(c) * (1.0 if cy < 0.40 else 0.1)

    win = max(comps, key=score)
    xs = [p[0] for p in win]
    ys = [p[1] for p in win]
    infl = max(3, w // 40)
    x0, x1, y0, y1 = min(xs) - infl, max(xs) + infl, min(ys) - infl, max(ys) + infl
    out = set()
    for c in comps:
        if len(c) > len(win):
            continue
        cxs = [p[0] for p in c]
        cys = [p[1] for p in c]
        if min(cxs) <= x1 and max(cxs) >= x0 and min(cys) <= y1 and max(cys) >= y0:
            out.update(c)
    return out, opaque


def mark_leaf(img, stem):
    """Re-hue the sprite's leaf to the sentinel. Manual box first; auto
    detection with a hard size cap otherwise."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    if stem in LEAF_BBOX:
        bx0, by0, bx1, by1 = LEAF_BBOX[stem]
        leaf = set()
        for y in range(max(0, by0), min(h, by1)):
            for x in range(max(0, bx0), min(w, bx1)):
                r, g, b, a = px[x, y]
                if a <= 40:
                    continue
                hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                if 0.05 <= hh <= 0.125 and ss > 0.4 and vv > 0.3:
                    leaf.add((x, y))
    else:
        leaf, opaque = _leaf_pixels_auto(img)
        if opaque and len(leaf) / opaque > MASK_CAP:
            sys.exit(
                f"{stem}: auto leaf mask covers {len(leaf) / opaque:.0%} of the "
                f"sprite — berries captured; add a LEAF_BBOX row"
            )
    for (x, y) in leaf:
        r, g, b, a = px[x, y]
        hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        rr, gg, bb = colorsys.hsv_to_rgb(SENTINEL_HUE, ss, vv)
        px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
    return img

# The sheet-D cluster archetypes (0.9.47): drawn once in a neutral mid-red,
# multiplied here into the three catalog hues. The berry pixels are
# hue-rotated; the leaf (yellow band) and the outline (near-black) are left
# alone, so the runtime rarity re-ink keeps its contract on every variant.
ARCH_SOURCES = {
    "archpineconesmall.png": "pinecone-small",
    "archpineconelarge.png": "pinecone-large",
    "archconesmall.png": "cone-small",
    "archconelarge.png": "cone-large",
    # The two pyramid masters were retired by the 0.9.48 truth pass: every
    # grape they served is an elongated winged cone in the references, never
    # a broad triangle. Their slots return as longcone-small/-large when the
    # replacement sheet lands (sommbot B3).
    "archloosesmall.png": "loose-small",
    "archlooselarge.png": "loose-large",
    # The gnarl, hue-shifted like the rest since 0.9.50 so white
    # GODFORSAKEN grapes stop wearing red fruit.
    "archgodforsaken.png": "godforsaken",
    # The H sheet (0.9.51): the elongated winged cone the ex-pyramid
    # sixteen actually are, plus the three truth-variation masters from
    # sommbot's plan (extreme cylinder, tannic tiny-tight, OIV oval).
    "archlongconesmall.png": "longcone-small",
    "archlongconelarge.png": "longcone-large",
    "archlongcylindersmall.png": "longcylinder-small",
    "archtighttinysmall.png": "tighttiny-small",
    "archconeovalsmall.png": "coneoval-small",
}

# hue, saturation scale, value scale per variant. Red passes through — since
# the 0.9.48 truth pass it survives only as the interim pale-red for the
# three unverified grapes (sommbot A2); noir is the dark-skinned default,
# because no mature wine grape actually hangs mid-red: dark vinifera is
# blue-black under bloom (OIV 225). tinto is the teinturier deep; gris the
# pink-skinned whites; copper is Roussanne's russet (roux).
ARCH_HUES = {
    "red": None,
    "green": (0.24, 0.95, 1.0),
    "gold": (0.115, 1.05, 1.0),
    "noir": (0.72, 0.85, 0.60),
    "tinto": (0.76, 1.00, 0.42),
    "gris": (0.93, 0.35, 1.00),
    "copper": (0.055, 0.70, 0.92),
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
            if 0.40 <= hh <= 0.54:
                continue  # the sentinel leaf survives every variant
            if 0.08 <= hh <= 0.17 and s > 0.45:
                continue  # stem browns and any unmarked leaf pixels
            if v < 0.22 or s < 0.18:
                continue  # outline and glints
            if hh <= 0.09 or hh >= 0.85:  # the red masters' berry range
                # Floor the output value so the noir/tinto berries stay
                # separable from the near-black cel outline (sommbot A2).
                rr, gg, bb = colorsys.hsv_to_rgb(th, min(1.0, s * ss), max(0.16, min(1.0, v * vs)))
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
            img = mark_leaf(strip_background(Image.open(path)), stem)
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
        base = mark_leaf(strip_background(Image.open(path)), f"arch-{cluster}")
        for variant in ARCH_HUES:
            out = os.path.join(DST, f"arch-{cluster}-{variant}.png")
            save_stable(quantize_stable(berry_hue_shift(base, variant)), out, optimize=True)
            converted += 1
            total_out += os.path.getsize(out)

    print(f"converted {converted} bunches -> {DST} ({total_out // 1024}KB)")
    if missing:
        sys.exit(f"missing sources: {', '.join(missing)}")


if __name__ == "__main__":
    main()
