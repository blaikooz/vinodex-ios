# Notices and credits

This file inventories the third-party assets shipped in the Vinodex app or
committed to this repository, and records the provenance of the first-party
asset groups. First-party content is covered by the top-level [LICENSE](LICENSE)
(all rights reserved); the third-party licenses below apply to their components
regardless of it.

Last verified against the tree on 2026-08-06.

## Fonts (bundled in-app)

Both fonts ship unmodified under the SIL Open Font License 1.1. The license
text with both copyright notices is at
[`Sources/VinodexUI/Resources/Fonts/OFL.txt`](Sources/VinodexUI/Resources/Fonts/OFL.txt)
and is bundled with the app beside the font files.

- **Press Start 2P** — Copyright 2012 The Press Start 2P Project Authors,
  with Reserved Font Name "Press Start 2P". SIL OFL 1.1.
- **VT323** — Copyright 2011, The VT323 Project Authors. SIL OFL 1.1.

## Icon glyphs (bundled in-app)

68 glyph ids are fetched from the Iconify distribution by
`scripts/rasterize-icons.sh`, recolored to the app palette, and rasterized to
PNG at three scales (204 files in `Sources/VinodexUI/Resources/Icons/`).

### game-icons.net — 55 icons, CC BY 3.0

Licensed under [Creative Commons Attribution 3.0 Unported](https://creativecommons.org/licenses/by/3.0/).
Created by the [game-icons.net](https://game-icons.net) artists:

- **Delapouite** (https://delapouite.com) — almond, apple-core, banana,
  banana-bunch, beehive, bell-pepper, butter, cherry, coffee-cup, cut-lemon,
  gas-pump, herbs-bundle, high-grass, honey-jar, jelly, jelly-beans,
  mushrooms, mussel, olive, peach, pear, pineapple, plum, raspberry,
  smoking-pipe, stone-pile, strawberry, teapot-leaves, tomato,
  weight-lifting-up, weight-scale
- **Lorc** (https://lorcblog.blogspot.com) — blackcurrant, elderberry,
  fluffy-cloud, honeycomb, hot-spices, leather-vest, lotus-flower, pine-tree,
  rose, salt-shaker, shiny-apple, sliced-bread, teapot, vanilla-flower,
  volcano, wine-glass
- **Caro Asercion** — bok-choy, deer, mason-jar
- **sbed** (https://opengameart.org/content/95-game-icons) — death-skull
- **Lorc and sbed** — clover
- **Lorc or John Redman** (both publish a variant under this id) — rock
- **Rihlsul** — chocolate-bar
- **Willdabeast** (https://wjbstories.blogspot.com) — gold-bar

Modifications: recolored to theme colors and rasterized to PNG; no shape edits.

### Lucide — 12 icons, ISC

circle, cloud, droplet, flame, flower-2, gem, leaf, mountain, shield,
sparkles, sun, triangle.

Copyright (c) Lucide Icons and Contributors, ISC License. `circle` and
`triangle` derive from the Feather project (MIT, Copyright (c) 2013-present
Cole Bemis). Full text, both parts:
[`licenses/LICENSE-lucide.txt`](licenses/LICENSE-lucide.txt).

### Material Design Icons (Pictogrammers) — 1 icon, Apache-2.0

help-circle-outline.

Distributed under the [Apache License 2.0](licenses/Apache-2.0.txt) per the
Iconify collection metadata and the
[Pictogrammers Free License](licenses/LICENSE-mdi.txt).

## Pixel flags — R74n PixelFlags, conditional license

The 465 PNGs under `shared/pixelflags/` (33 of them bundled in-app in
`Sources/VinodexUI/Resources/Flags/`) are from
[PixelFlags by R74n](https://r74n.com/pixelflags/), used under the
[R74n Content License v1.1](licenses/LICENSE-r74n.txt)
([original](https://r74n.com/license.txt)). Credit: **pixel flags by R74n**.

That license requires clear credit (this file provides it), forbids
commercial use without explicit permission, and reserves R74n's right to
demand removal. The app is unreleased and development builds are
non-commercial, so the R74n set keeps shipping for now, and the owner has
emailed R74n requesting permission for the eventual paid release (recorded
2026-08-06). **Before any paid release, either that written permission must
be in hand or the bundled flags swap to the first-party standby set**,
which already exists: `art/flags/` holds 33 recreations drawn in code from
the underlying flag designs — not from R74n's pixels, since under license
§4 derivatives of their artwork are theirs to reuse freely — by
`scripts/generate-flag-art.py` (2026-08-05). Flipping the flag-copy source
in `scripts/rasterize-icons.sh` is the only change the swap needs.

`shared/pixelflags/Other/` additionally contains renderings of brand
trademarks and statute-protected emblems that the app never uses; deleting
that folder is tracked as auditS M5 and this inventory does not endorse
redistributing it.

## First-party assets (all rights reserved — see LICENSE)

- **Drawn art** — the 254 assets regenerated from `art/` (the `art:*` glyph
  ids, chassis, class/flavor/grape/style art, and logo assets) are
  first-party work.
- **Pixel flags (standby set, not currently bundled)** — `art/flags/` holds
  33 first-party pixel renditions drawn in code by
  `scripts/generate-flag-art.py` (2026-08-05) from each flag's official
  construction and published colors, made without reference to R74n's
  artwork. Flag designs themselves are government insignia, which carry no
  copyright; the pixel art is original. They stand ready to replace the
  bundled R74n set before any paid release if R74n's permission is not
  granted (see the pixel-flags section above).
- **World map** — `Sources/VinodexUI/Resources/Maps/updatedglobemap.jpg` was
  created first-party (owner statement, 2026-08-05).
- **Sound effects** — `button-tap.mp3`, `correct-answer.mp3`,
  `orb-depress.mp3`, `warm-ping.mp3` in `Sources/VinodexUI/Resources/SFX/`
  were authored first-party (owner statement, 2026-08-05).
- **Wine dataset** — written first-party; provenance and the independence
  statement are recorded in [`shared/PROVENANCE.md`](shared/PROVENANCE.md).
