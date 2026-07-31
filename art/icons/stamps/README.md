# Back-plate stamp & sticker glyphs (0.6.4, F2/F3)

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

## Wanted — per-skin aged stickers (`sticker-<skin raw value, kebab-case>`)

- `sticker-christmas.png` — the Santa hat (WINE XMAS)
- `sticker-blush.png` — the little cat (BLUSH)
- one per remaining skin, a more detailed take on its emblem glyph:
  `sticker-classic`, `sticker-midnight`, `sticker-original`,
  `sticker-burgundy`, `sticker-riesling`, `sticker-vinho-verde`,
  `sticker-glouglou`, `sticker-smart-grape`, `sticker-champagne`,
  `sticker-nouveau`, `sticker-oaked`, `sticker-nocturne`, `sticker-steel`,
  `sticker-psvino` (0.6.5 — the DualShock skin; PS button glyphs territory)

Since 0.6.5 (item 8) the per-skin piece renders as a postage stamp on the
same perforated frame as the badge stamps — the stems above are unchanged;
the glyph drops into the stamp's centre instead of a die-cut sticker.

Stem names come from the *persisted* skin raw values
(`ChassisSkin.stickerStem`), not the display names — renames never move them.
