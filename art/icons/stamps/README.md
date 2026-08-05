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

## Wanted — postage stamp glyphs (one per Passport badge)

- `stamp-first-sip.png` — a first pour / single glass
- `stamp-ten-bottles.png` — a crate or row of bottles
- `stamp-all-noble.png` — a crown among vines
- `stamp-region-complete.png` — a map with a flag planted
- `stamp-streak-week.png` — a seven-notch flame or calendar
- `stamp-sommelier.png` — a tastevin or diploma

Stem names are the `artStem` field on each record in `StampCatalog`
(`Sources/VinodexCore/BackPlateStamps.swift`), and `StampCatalogTests` asserts
every one of them begins `stamp-`. Nothing derives them from a badge's title,
so a badge can be renamed without orphaning its art.
