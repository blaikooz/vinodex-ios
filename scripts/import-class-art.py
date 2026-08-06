#!/usr/bin/env python3
"""Imports the taxonomy + outline + globe pixel art into the app bundle.

Sources are the individual PNGs under art/icons/ (0.5.8, A1), organised by
use — flavour classes and subclasses, wine colour, body, climate, soils,
style classes, the country/state outlines and the continent globes (contact
sheets live in art/icons/reference, not here). Same treatment as the other
importers: background removed via the shared pass in art_common.py (chroma
key when present, else border flood — interior white survives), palette-
quantised, written to Sources/VinodexUI/Resources/ClassArt.

Which stems exist is decided by the generator's `art:` ids (they feed
icons.json); this script converts exactly the stems those ids name, resolved
against SOURCE_FOR below, which holds the artist's filenames — including the
`mediterrean` / `saltysublcass` / `rosecolor` spellings, preserved on the
`crubeaujolas` precedent. Run `npm run generate` first if you changed the
tables.

Usage: python3 scripts/import-class-art.py [source-dir]
Requires Pillow.
"""
import importlib.util
import json
import os
import sys

from PIL import Image

from art_common import (
    output_dir,
    quantize_stable,
    resolve_source_dir,
    save_stable,
    strip_background,
)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MANIFEST = os.path.join(ROOT, "Sources", "VinodexCore", "Resources", "icons.json")
DST = output_dir(ROOT, "ClassArt")

# The one prefix whose sources are resolved by rule rather than by table, and
# the one whose art is re-inked here rather than shipped as drawn (0.8.4, F1).
OUTLINE_PREFIX = "outline-"
OUTLINE_DIR = "countries"

# `country-outline-fills.py` is not importable by name -- the hyphens are not a
# Python identifier -- so it is loaded the way `make-country-outlines.py` loads
# the rings module, for the same reason: the tables are data files that happen
# to be Python, and renaming them to snake_case would break the two Swift tests
# that parse them off disk by name.
_spec = importlib.util.spec_from_file_location(
    "country_outline_fills", os.path.join(HERE, "country-outline-fills.py")
)
_fills = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_fills)

FILL = _fills.FILL
RING = _fills.RING
RING_WIDTH = _fills.RING_WIDTH

# Stem -> source path relative to art/icons. The stems are namespaced by
# table (class-, subclass-, color-, body-, climate-, soil-, styleclass-,
# outline-, globe-) so one flat ClassArt directory cannot collide with itself
# or with the flavour/style/grape art the shared PixelArtLoader also searches.
#
# The per-use folder split on the SOURCE side is load-bearing too, and less
# obvious: `chalk.png`, `earth.png`, `game.png` and `orange.png` each exist
# twice under art/icons/ as genuinely different art — a taxonomy glyph and a
# flavour portrait. Only the folder decides which one a stem gets. Flatten the
# tree and soil-chalk / subclass-earth / subclass-game / color-orange silently
# start shipping the flavour drawing instead. (This is why H12 was fixed by
# re-foldering rather than by re-pointing the scripts at a flat directory.)
SOURCE_FOR = {
    "class-sweet": "classes/sweet.png",
    "class-sour": "classes/sour.png",
    "class-bitter": "classes/bitter.png",
    "class-umami": "classes/umami.png",
    "class-salty": "classes/saltyclass.png",
    "subclass-berry": "subclasses/berry.png",
    "subclass-citrus": "subclasses/citrus.png",
    "subclass-tropical": "subclasses/tropical.png",
    "subclass-orchard-fruit": "subclasses/orchardfruit.png",
    "subclass-stone-fruit": "subclasses/stonefruit.png",
    "subclass-red-fruit": "subclasses/redfruit.png",
    "subclass-dark-fruit": "subclasses/darkfruit.png",
    "subclass-herbal": "subclasses/herbal.png",
    "subclass-vegetal": "subclasses/vegetal.png",
    "subclass-nut": "subclasses/nut.png",
    "subclass-baking": "subclasses/baking.png",
    "subclass-bread": "subclasses/bread.png",
    "subclass-wax": "subclasses/wax.png",
    "subclass-earth": "subclasses/earth.png",
    "subclass-smoky": "subclasses/smoky.png",
    "subclass-spice": "subclasses/spice.png",
    "subclass-savory": "subclasses/savory.png",
    "subclass-briny": "subclasses/briny.png",
    "subclass-salty": "subclasses/saltysublcass.png",
    "subclass-floral": "subclasses/floral.png",
    "subclass-game": "subclasses/game.png",
    "subclass-wood": "subclasses/wood.png",
    "color-red": "color/red.png",
    "color-white": "color/white.png",
    "color-rose": "color/rosecolor.png",
    "color-orange": "color/orange.png",
    "color-dual": "color/dual.png",
    "body-light": "body/light.png",
    "body-medium": "body/medium.png",
    "body-full": "body/full.png",
    "climate-maritime": "climate/maritime.png",
    "climate-continental": "climate/continental.png",
    "climate-cool": "climate/cool.png",
    "climate-warm": "climate/warm.png",
    "climate-mediterranean": "climate/mediterrean.png",
    "styleclass-type": "styleclasses/type.png",
    "styleclass-blend": "styleclasses/blend.png",
    "styleclass-origin": "styleclasses/origin.png",
    "styleclass-method": "styleclasses/method.png",
    "soil-volcanic": "soil/volcanic.png",
    "soil-basalt": "soil/basalt.png",
    "soil-clay": "soil/clay.png",
    "soil-loam": "soil/loam.png",
    "soil-sand": "soil/sand.png",
    "soil-limestone": "soil/limestone.png",
    "soil-chalk": "soil/chalk.png",
    "soil-slate": "soil/slate.png",
    "soil-shale": "soil/shale.png",
    "soil-schist": "soil/schist.png",
    "soil-granite": "soil/granite.png",
    "soil-gravel": "soil/gravel.png",
    "soil-alluvial": "soil/alluvial.png",
    "soil-loess": "soil/loess.png",
    "soil-laterite": "soil/laterite.png",
    "soil-default": "soil/default soil.png",
    # **No `outline-*` rows since 0.8.4 (F1).** The 30 that were here mapped a
    # stem to a master whose filename was a third spelling of the same place --
    # `outline-washington` -> `washingtonstate.png`, `outline-new-zealand` ->
    # `new zealand.png` (a space), `outline-georgia` -> `georgiacountry.png` --
    # and keeping the two in step by hand was a standing invitation to a silent
    # miss. The hand-drawn drop re-authored the whole directory, so the
    # opportunity to make the master's stem *be* the icon stem was free, and
    # `outline_source` below is now the rule rather than a table. See
    # `OUTLINE_DIR`.
    "globe-africa": "continents/africa.png",
    "globe-asia": "continents/asia.png",
    "globe-europe": "continents/europe.png",
    "globe-north-america": "continents/northamerica.png",
    "globe-oceania": "continents/oceania.png",
    "globe-south-america": "continents/southamerica.png",
}



def _hex_rgba(value):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), 255)


def ink_outline(img, stem):
    """Flat fill + cel ring, over a hand-drawn silhouette (0.8.4, F1).

    The masters are one colour: a cream shape on a magenta key, which
    `strip_background` reduces to "opaque where the country is". That is the
    whole of the information in them, and it is deliberately *more* than the
    0.8.0 rasterisations carried -- those were 106-cell approximations of a
    30-vertex ring, and these are drawn coastlines.

    What they do not carry is which country they are, and the app has always
    said that in colour: `FILL` is 0.8.0's own table, kept rather than
    re-chosen. So the silhouette is painted flat and ringed in one dark cel
    line, which is exactly the three-colour result the rasteriser produced --
    same visual language, better geography.

    **Painted here rather than in the art** for the house reason `strip_key_shadow`
    states from the other side: a correction that lives outside the importer is
    a correction the next re-import silently undoes. It also keeps every master
    a *silhouette*, so a country's colour is a one-line data edit and not a
    redraw.

    Three colours out means `quantize_stable` returns before any quantiser sees
    the image, which is what keeps `icons:verify`'s zero-pixel budget for these
    files honest on a machine that is not this one.
    """
    fill = _hex_rgba(FILL[stem])
    ring = _hex_rgba(RING)
    px = img.load()
    w, h = img.size

    # Pass 1: what is land. Read once, so pass 2 cannot see its own writes.
    land = bytearray(w * h)
    for y in range(h):
        row = y * w
        for x in range(w):
            if px[x, y][3] > 127:
                land[row + x] = 1

    # Pass 2: a land cell within `RING_WIDTH` of the sea is the cel line.
    r = RING_WIDTH
    edge = 0
    for y in range(h):
        row = y * w
        for x in range(w):
            if not land[row + x]:
                px[x, y] = (0, 0, 0, 0)
                continue
            border = False
            for dy in range(-r, r + 1):
                ny = y + dy
                for dx in range(-r, r + 1):
                    nx = x + dx
                    if nx < 0 or ny < 0 or nx >= w or ny >= h:
                        border = True
                    elif not land[ny * w + nx]:
                        border = True
                    if border:
                        break
                if border:
                    break
            px[x, y] = ring if border else fill
            edge += 1 if border else 0
    return img, edge


def outline_source(stem):
    """`outline-france` -> `countries/france.png`. The rule that replaced a table."""
    return os.path.join(OUTLINE_DIR, stem[len(OUTLINE_PREFIX):] + ".png")


def art_stems(manifest):
    """Every `art:` id the manifest carries, as bare stems."""
    ids = set()
    ids.update(manifest.get("bodyIcons", {}).values())
    ids.update(manifest.get("climateIcons", {}).values())
    ids.update(manifest.get("colorIcons", {}).values())
    ids.update(manifest.get("styleClassIcons", {}).values())
    ids.update((manifest.get("flavorClassIcons") or {}).values())
    ids.update((manifest.get("flavorSubclassIcons") or {}).values())
    ids.update(manifest.get("countryShapeIcons", {}).values())
    ids.update(v["icon"] for v in manifest.get("soilIcons", {}).values())
    # Continents live in the per-entry table (the globes, 0.5.8 B1) — only
    # its art: ids are ours; Iconify ids stay with rasterize-icons.sh.
    ids.update(manifest.get("byEntry", {}).values())
    return sorted(i[len("art:"):] for i in ids if i.startswith("art:"))


def main():
    src = resolve_source_dir(ROOT)
    with open(MANIFEST, encoding="utf-8") as fh:
        stems = art_stems(json.load(fh))
    if not stems:
        sys.exit("icons.json carries no art: ids — run 'npm run generate'")

    os.makedirs(DST, exist_ok=True)
    missing = []
    total_out = 0
    for stem in stems:
        outline = stem.startswith(OUTLINE_PREFIX)
        name = outline_source(stem) if outline else SOURCE_FOR.get(stem)
        path = os.path.join(src, name) if name else None
        if path is None or not os.path.exists(path):
            missing.append(stem)
            continue
        img = strip_background(Image.open(path))
        if outline:
            if stem[len(OUTLINE_PREFIX):] not in FILL:
                missing.append(stem + " (no fill colour)")
                continue
            img, _ = ink_outline(img.convert("RGBA"), stem[len(OUTLINE_PREFIX):])
        out = os.path.join(DST, stem + ".png")
        # `quantize_stable` + `save_stable` since 0.8.0 (A0b): no library
        # default decides the palette, and a run whose pixels match writes
        # nothing. See art_common for both arguments.
        save_stable(quantize_stable(img), out, optimize=True)
        total_out += os.path.getsize(out)

    print(f"converted {len(stems) - len(missing)} icons -> {DST} ({total_out // 1024}KB)")
    if missing:
        sys.exit(f"missing sources for: {', '.join(missing)}")


if __name__ == "__main__":
    main()
