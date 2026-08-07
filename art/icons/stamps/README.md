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

## The eight Passport badges

- `firstsip.png` → `stamp-first-sip` — a first pour / single glass
- `tenbottles.png` → `stamp-ten-bottles` — a crate or row of bottles
- `allnoble.png` → `stamp-all-noble` — a crown among vines
- `regioncomplete.png` → `stamp-region-complete` — a map with a flag planted
- `streakweek.png` → `stamp-streak-week` — a seven-notch flame or calendar
- `sommelier.png` → `stamp-sommelier` — a tastevin or diploma
- `stamp1.png` → `stamp-all-grapes` — TRIED ALL GRAPES
- `stamp2.png` → `stamp-all-styles` — TRIED ALL STYLES

Target stems are the `artStem` field on each record in `StampCatalog`
(`Sources/VinodexCore/BackPlateStamps.swift`), and `StampCatalogTests` asserts
every one of them begins `stamp-`. Nothing derives them from a badge's title,
so a badge can be renamed without orphaning its art.

**Nothing is outstanding.** `ArtPipelineRosterTests.undrawnStampStems` is empty,
and it is checked both ways: a stem the app asks for that nobody has drawn must
be listed there, and a stem listed there that *has* been drawn fails the roster
until the row comes out. So this section going stale is a build failure.

## The last two names, and how they were settled (0.8.7, item 4)

`stamp1.png` and `stamp2.png` arrived in the 0.8.4 drop with no brief attached
to them. 0.8.5's F1 read them as two loose postage stamps and printed them on
the back plate as `BackPlateDecal.decalOne` / `.decalTwo`. 0.8.6's C6 was then
asked to give those same two names to the two new completion badges, declined
on the grounds that the decals were already drawn and on screen, and minted
`stamp-all-grapes` / `stamp-all-styles` with no art behind them.

**0.8.7 settles it the other way, on the authority of the person who drew
them**: the two pictures are the badges. So the rows above point at them, the
two decals are gone from `BackPlateDecal` and from the plate, and the backlog
list emptied itself.

Worth writing down because of what the reversal cost: **two rows of `STEM_FOR`
and two deleted enum cases.** Nothing anywhere derives a bundle stem from a
source filename — that is the whole reason `STEM_FOR` exists — so re-pointing a
picture at a different meaning never touched the Swift stems, the bundle names,
or any call site. Had either end been spelled `stamp1`, this would have been a
rename across four files.

## The two back-plate decals

Not badges — printed on the device rather than earned, and drawn whole rather
than as an illustration inside a code-drawn frame. Their roster is
`BackPlateDecal` in the same Core file.

- `barcode.png` → `stamp-barcode` — replaces the `Canvas`-drawn barcode label
- `pricesticker.png` → `stamp-price-tag` — replaces the code-drawn ripped tag

Both keep their code-drawn versions as fallbacks (`PlateDecal` in
`DeviceBackPlate.swift`), so a lookup that misses shows the old sticker rather
than nothing. That is also why losing `decalOne` and `decalTwo` cost the plate
nothing structural: those two had no fallback, because nothing was ever drawn
for them in code. If a future drop wants loose franking back, it is a new file,
a new row here and a new case — not a name taken from something else.
