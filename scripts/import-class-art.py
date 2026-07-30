#!/usr/bin/env python3
"""Imports the taxonomy + outline pixel art into the app bundle (0.5.7, B1/B3).

Sources are the individual PNGs in shared/newicons/classes — flavour classes
and subclasses, wine colour, body, climate, soils, style classes and the
country/state outlines (the `classesicons*.png` contact sheets there are
references, not sources). Same treatment as the other importers: background
removed via the shared border-flood pass in art_common.py (interior white is
subject and survives — item B2), palette-quantised, written to
Sources/VinodexUI/Resources/ClassArt.

Which stems exist is decided by the generator's `art:` ids (they feed
icons.json); this script converts exactly the stems those ids name, resolved
against SOURCE_FOR below, which holds the artist's filenames — including the
`mediterrean` / `saltysublcass` / `rosecolor` spellings, preserved on the
`crubeaujolas` precedent. Run `npm run generate` first if you changed the
tables.

Usage: python3 scripts/import-class-art.py [source-dir]
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
DST = os.path.join(ROOT, "Sources", "VinodexUI", "Resources", "ClassArt")

# Stem -> source basename in shared/newicons/classes. The stems are namespaced
# by table (class-, subclass-, color-, body-, climate-, soil-, styleclass-,
# outline-) so one flat ClassArt directory cannot collide with itself or with
# the flavour/style/grape art the shared PixelArtLoader also searches.
SOURCE_FOR = {
    "class-sweet": "sweet.png",
    "class-sour": "sour.png",
    "class-bitter": "bitter.png",
    "class-umami": "umami.png",
    "class-salty": "saltyclass.png",
    "subclass-berry": "berry.png",
    "subclass-citrus": "citrus.png",
    "subclass-tropical": "tropical.png",
    "subclass-orchard-fruit": "orchardfruit.png",
    "subclass-stone-fruit": "stonefruit.png",
    "subclass-red-fruit": "redfruit.png",
    "subclass-dark-fruit": "darkfruit.png",
    "subclass-herbal": "herbal.png",
    "subclass-vegetal": "vegetal.png",
    "subclass-nut": "nut.png",
    "subclass-baking": "baking.png",
    "subclass-bread": "bread.png",
    "subclass-wax": "wax.png",
    "subclass-earth": "earth.png",
    "subclass-smoky": "smoky.png",
    "subclass-spice": "spice.png",
    "subclass-savory": "savory.png",
    "subclass-briny": "briny.png",
    "subclass-salty": "saltysublcass.png",
    "subclass-floral": "floral.png",
    "subclass-game": "game.png",
    "subclass-wood": "wood.png",
    "color-red": "red.png",
    "color-white": "white.png",
    "color-rose": "rosecolor.png",
    "color-orange": "orange.png",
    "color-dual": "dual.png",
    "body-light": "light.png",
    "body-medium": "medium.png",
    "body-full": "full.png",
    "climate-maritime": "maritime.png",
    "climate-continental": "continental.png",
    "climate-cool": "cool.png",
    "climate-warm": "warm.png",
    "climate-mediterranean": "mediterrean.png",
    "styleclass-type": "type.png",
    "styleclass-blend": "blend.png",
    "styleclass-origin": "origin.png",
    "styleclass-method": "method.png",
    "soil-volcanic": "volcanic.png",
    "soil-basalt": "basalt.png",
    "soil-clay": "clay.png",
    "soil-loam": "loam.png",
    "soil-sand": "sand.png",
    "soil-limestone": "limestone.png",
    "soil-chalk": "chalk.png",
    "soil-slate": "slate.png",
    "soil-shale": "shale.png",
    "soil-schist": "schist.png",
    "soil-granite": "granite.png",
    "soil-gravel": "gravel.png",
    "soil-alluvial": "alluvial.png",
    "soil-loess": "loess.png",
    "soil-laterite": "laterite.png",
    "soil-default": "default soil.png",
    "outline-france": "france.png",
    "outline-germany": "germany.png",
    "outline-italy": "italy.png",
    "outline-greece": "greece.png",
    "outline-portugal": "portugal.png",
    "outline-spain": "spain.png",
    "outline-hungary": "hungary.png",
    "outline-austria": "austria.png",
    "outline-croatia": "croatia.png",
    "outline-california": "california.png",
    "outline-oregon": "oregon.png",
    "outline-washington": "washingtonstate.png",
    "outline-new-york": "newyorkstate.png",
    "outline-georgia": "georgiacountry.png",
    "outline-switzerland": "switzerland.png",
    "outline-romania": "romania.png",
    "outline-south-africa": "southafrica.png",
    "outline-morocco": "morocco.png",
    "outline-usa": "usa.png",
    "outline-canada": "canada.png",
    "outline-argentina": "argentina.png",
    "outline-chile": "chile.png",
    "outline-uruguay": "uruguay.png",
    "outline-new-zealand": "new zealand.png",
    "outline-australia": "australia.png",
    "outline-japan": "japan.png",
    "outline-china": "china.png",
    "outline-india": "india.png",
}


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    for candidate in (
        os.path.join(ROOT, "shared", "newicons", "classes"),
        os.path.join(os.path.dirname(ROOT), "shared", "newicons", "classes"),
    ):
        if os.path.isdir(candidate):
            return candidate
    sys.exit("no source dir found; pass it explicitly")


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
    return sorted(i[len("art:"):] for i in ids if i.startswith("art:"))


def main():
    src = source_dir()
    with open(MANIFEST, encoding="utf-8") as fh:
        stems = art_stems(json.load(fh))
    if not stems:
        sys.exit("icons.json carries no art: ids — run 'npm run generate'")

    os.makedirs(DST, exist_ok=True)
    missing = []
    total_out = 0
    for stem in stems:
        name = SOURCE_FOR.get(stem)
        path = os.path.join(src, name) if name else None
        if path is None or not os.path.exists(path):
            missing.append(stem)
            continue
        img = strip_background(Image.open(path))
        out = os.path.join(DST, stem + ".png")
        img.quantize(colors=256).save(out, optimize=True)
        total_out += os.path.getsize(out)

    print(f"converted {len(stems) - len(missing)} icons -> {DST} ({total_out // 1024}KB)")
    if missing:
        sys.exit(f"missing sources for: {', '.join(missing)}")


if __name__ == "__main__":
    main()
