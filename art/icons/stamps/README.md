# Back-plate Passport stamp glyphs (0.6.4, F2)

**Passport stamps only.** The per-skin sticker used to be commissioned out of
this same folder — from 0.6.5 it even rendered as a postage stamp — and since
0.7.8 (A1) it has its own brief, its own importer and its own namespace in
`../stickers/`. If you are drawing a shell's decal, you are in the wrong
directory.

Drop authored pixel-art PNGs here; `npm run icons` (via
`scripts/import-stamp-art.py`) strips the background and copies them into
`Sources/VinodexUI/Resources/StampArt`, where they replace the SF Symbol
stand-ins with no code change. Export on a **magenta (#FF00FF) chroma-key
background** — that is the durable transparency path (see
`scripts/art_common.py`).

The frame is code-drawn (`StampFrame.swift`): perforated edge, keyline,
denomination corner, worn/aged overlay. Author only the inner illustration,
chunky-pixel style like the flavour portraits, roughly square.

## Naming (0.8.5, F1)

**Name the file for the picture, not for the stem.** This directory used to
specify the exact `artStem` as the filename and the importer copied it through
verbatim; the drop that arrived was named `firstsip.png`, `allnoble.png`,
`tenbottles.png`, which is how a person draws. `import-stamp-art.py` carries a
`STEM_FOR` map instead, and `ArtPipelineRosterTests.stampRosterIsComplete` holds
it equal to this directory, to the stems the app asks for, and to the PNGs that
came out — all three, both ways. A file added here without a row in the map is a
build failure rather than a file skipped in silence.

## The six Passport badges

- `firstsip.png` → `stamp-first-sip` — a first pour / single glass
- `tenbottles.png` → `stamp-ten-bottles` — a crate or row of bottles
- `allnoble.png` → `stamp-all-noble` — a crown among vines
- `regioncomplete.png` → `stamp-region-complete` — a map with a flag planted
- `streakweek.png` → `stamp-streak-week` — a seven-notch flame or calendar
- `sommelier.png` → `stamp-sommelier` — a tastevin or diploma

Target stems are the `artStem` field on each record in `StampCatalog`
(`Sources/VinodexCore/BackPlateStamps.swift`), and `StampCatalogTests` asserts
every one of them begins `stamp-`. Nothing derives them from a badge's title,
so a badge can be renamed without orphaning its art.

## The four back-plate decals

Not badges — printed on the device rather than earned, and drawn whole rather
than as an illustration inside a code-drawn frame. Their roster is
`BackPlateDecal` in the same Core file.

- `barcode.png` → `stamp-barcode` — replaces the `Canvas`-drawn barcode label
- `pricesticker.png` → `stamp-price-tag` — replaces the code-drawn ripped tag
- `stamp1.png` → `stamp-decal-one`, `stamp2.png` → `stamp-decal-two` — two loose
  postage stamps the plate is franked with

The first two keep their code-drawn versions as fallbacks (`PlateDecal` in
`DeviceBackPlate.swift`), so a lookup that misses shows the old sticker rather
than nothing.
