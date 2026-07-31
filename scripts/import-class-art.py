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
import json
import os
import sys

from PIL import Image

from art_common import strip_background

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MANIFEST = os.path.join(ROOT, "Sources", "VinodexCore", "Resources", "icons.json")
DST = os.path.join(ROOT, "Sources", "VinodexUI", "Resources", "ClassArt")

# Stem -> source path relative to art/icons. The stems are namespaced by
# table (class-, subclass-, color-, body-, climate-, soil-, styleclass-,
# outline-, globe-) so one flat ClassArt directory cannot collide with itself
# or with the flavour/style/grape art the shared PixelArtLoader also searches.
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
    "outline-france": "countries/france.png",
    "outline-germany": "countries/germany.png",
    "outline-italy": "countries/italy.png",
    "outline-greece": "countries/greece.png",
    "outline-portugal": "countries/portugal.png",
    "outline-spain": "countries/spain.png",
    "outline-hungary": "countries/hungary.png",
    "outline-austria": "countries/austria.png",
    "outline-croatia": "countries/croatia.png",
    "outline-california": "countries/california.png",
    "outline-oregon": "countries/oregon.png",
    "outline-washington": "countries/washingtonstate.png",
    "outline-new-york": "countries/newyorkstate.png",
    "outline-georgia": "countries/georgiacountry.png",
    "outline-switzerland": "countries/switzerland.png",
    "outline-romania": "countries/romania.png",
    "outline-south-africa": "countries/southafrica.png",
    "outline-morocco": "countries/morocco.png",
    "outline-usa": "countries/usa.png",
    "outline-canada": "countries/canada.png",
    "outline-argentina": "countries/argentina.png",
    "outline-chile": "countries/chile.png",
    "outline-uruguay": "countries/uruguay.png",
    "outline-new-zealand": "countries/new zealand.png",
    "outline-australia": "countries/australia.png",
    "outline-japan": "countries/japan.png",
    "outline-china": "countries/china.png",
    "outline-india": "countries/india.png",
    "globe-africa": "continents/africa.png",
    "globe-asia": "continents/asia.png",
    "globe-europe": "continents/europe.png",
    "globe-north-america": "continents/northamerica.png",
    "globe-oceania": "continents/oceania.png",
    "globe-south-america": "continents/southamerica.png",
}


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    candidate = os.path.join(ROOT, "art", "icons")
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
    # Continents live in the per-entry table (the globes, 0.5.8 B1) — only
    # its art: ids are ours; Iconify ids stay with rasterize-icons.sh.
    ids.update(manifest.get("byEntry", {}).values())
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
