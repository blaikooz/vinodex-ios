# Per-skin back-plate artifacts (0.7.8, A1; this folder since 0.8.5, F1)

**Shell decals only.** The Passport badge stamps are a different set with a
different brief and live in `../stamps/`. The two shared a directory from 0.6.4
until 0.7.8, which is exactly how a decal could be filed as a badge and nothing
anywhere would say so — neither family is enumerated by `assertAssetsExist`,
because both resolve through code-drawn stand-ins, so a misfiled or missing
file is silent by design.

**This folder replaced `../stickers/`, which never held a file.** The code still
calls the object a sticker — `SkinStickerView`, `ChassisSkin.stickerStem`, the
`sticker-` prefix, `Resources/StickerArt` — and those names are not going to
move, because `stickerStem` is derived from a **persisted** raw value that is
simultaneously an `@AppStorage` key and the FNV-1a seed for `WornOverlay`.
"Artifact" is what the drawings are filed under; "sticker" is what the app calls
the thing they are drawn for. One object, two words, and this paragraph is the
join.

Drop authored pixel-art PNGs here; `npm run icons` (via
`scripts/import-sticker-art.py`) strips the background and copies them into
`Sources/VinodexUI/Resources/StickerArt`, where they replace the emblem
stand-ins with no code change. Export on a **magenta (#FF00FF) chroma-key
background** — that is the durable transparency path (see
`scripts/art_common.py`).

## Naming

**Name the file for the picture, not for the shell.** The importer carries a
`SKIN_FOR` map from filename to `ChassisSkin` raw value, and
`ArtPipelineRosterTests.stickerRosterIsComplete` holds that map equal to this
directory *and* to the enum, in both directions — so a file added here without
a row in the map fails the build rather than being skipped in silence, and a
row for a shell that does not exist fails it too.

Two shells have no artifact drawn: **CHRISTMAS** and **ORANGE WINE**. Both are
named in `shellsWithoutADecal` in that test, so drawing one is a two-line change
(a row in `SKIN_FOR`, a name out of the backlog) and forgetting to remove it
from the backlog is a failure rather than a shrug.

## What the object is

One aged **die-cut sticker** per shell — the thing a previous owner stuck on
the back of this device and never got all the way off again. Since 0.7.8 it is
emphatically *not* a postage stamp: the silhouette is a rounded die-cut with
one corner lifted, the stock is tinted vinyl over a cream die-cut margin, there
is a gloss sweep across it, and it is inert where the badge stamps are tapped
and dragged. 0.6.5's item 8 had dressed it in the stamps' perforated frame, and
the plate read as carrying seven collectibles when it carries six and a
decoration.

The silhouette, the margin, the gloss and the weathering are all code-drawn
(`Sources/VinodexUI/SkinSticker.swift`, with the ageing pass shared from
`AgedMaterial.swift`). **Author only the inner illustration**, chunky-pixel
style like the flavour portraits, roughly square, on transparent/magenta —
it drops into the centre of the decal.

## Wanted — one per skin (`sticker-<skin raw value, kebab-case>`)

- `sticker-christmas.png` — the Santa hat (the shell reads WINE XMAS)
- `sticker-blush.png` — the little cat (BLUSH)
- one per remaining skin, a more detailed take on its emblem glyph:
  `sticker-classic`, `sticker-midnight`, `sticker-original`,
  `sticker-burgundy`, `sticker-riesling`, `sticker-vinho-verde`,
  `sticker-glouglou`, `sticker-smart-grape`, `sticker-champagne`,
  `sticker-nouveau`, `sticker-oaked`, `sticker-nocturne`, `sticker-steel`,
  `sticker-gris-de-gris`, `sticker-orange-wine`, `sticker-waldglas`,
  `sticker-pet-nat` (the shell reads FIBERGLASS),
  `sticker-halloween` (the shell reads HALLOWINE),
  `sticker-psvino` (0.6.5 — the DualShock skin; PS button glyphs territory)
- `sticker-w64.png` (0.7.6, D1 — the purple deck). **IP-safe, and this one
  needs saying out loud:** four coloured points around a centre, in the skin's
  own green/blue/red/yellow, is the illustration. No console logo, no
  controller silhouette, no trade dress, and nothing in the filename or the
  drawing referring to anyone's hardware. Same discipline as `sticker-psvino`
  above and as the screensaver's `VinodexV`.

That is 22 stems, one per `ChassisSkin` case. The five the pre-0.7.8 list
omitted are named above rather than left to "one per remaining skin", because
a roster that silently disagreed with the enum is what an illustrator would
have worked from.

Stem names come from the *persisted* skin raw values
(`ChassisSkin.stickerStem`), not the display names — renames never move them,
which is why three of the entries above carry a "the shell reads X" note.
