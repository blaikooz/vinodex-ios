# `art/icons/` — the drawn-art masters

Four registers. The top level answers one question: **is this a picture of
wine, or a picture of the device?** Everything else follows from that, because
the two are drawn to different briefs, imported by different scripts, and
loaded through different code paths.

Regrouped in 0.8.9a (A1) from a flat 22-directory tree. `npm run icons:verify`
reported 379 files identical across the move, so nothing below changed a pixel.

## `entries/` — art *of* what the catalog names

One picture per thing the database has an entry or a facet for. Every file
here is reached through an icon id in `Sources/VinodexCore/Resources/icons.json`,
which means the generator's `assertAssetsExist` walks it and a missing file is
a build error rather than a blank space.

| folder | importer | bundle |
|---|---|---|
| `flavors/` | `import-flavor-art.py` | `FlavorArt` |
| `grapes/` | `import-grape-art.py` | `GrapeArt` |
| `styles/` | `import-style-art.py` | `StyleArt` |
| `body/` `classes/` `climate/` `color/` `continents/` `countries/` `soil/` `styleclasses/` `subclasses/` | `import-class-art.py` | `ClassArt` |

`import-class-art.py` is the omnibus: it resolves `art:` ids to files by a
table (`SOURCE_FOR`) whose values are paths *relative to `entries/`*, so moving
the whole group together cost it one line. `countries/` is also the outline
master set — see `scripts/make-country-outlines.py`, which reads the bundle
rather than these files when it checks.

## `chrome/` — the device's own furniture

Drawn once against the chassis rather than commissioned per entry. Nothing here
appears in `icons.json`; the roster of chrome is whatever the UI puts a control
on, so these are gated by `ArtPipelineRosterTests` and `ChromeTests` instead.

| folder | importer | bundle | stem prefix |
|---|---|---|---|
| `buttons/` | `import-button-art.py` | `ButtonArt` | *(none — see below)* |
| `cartridges/` | `import-cartridge-art.py` | `CartridgeArt` | `cartridge-` |
| `footer/` | `import-footer-art.py` | `FooterArt` | `footer-` |
| `glyphs/` | `import-glyph-art.py` | `GlyphArt` | `glyph-` |
| `logo/` | `import-logo-art.py` | `Logo` | *(fixed names)* |
| `marquee/` | `import-marquee-art.py` | `MarqueeArt` | `marquee-` |
| `stamps/` | `import-stamp-art.py` | `StampArt` | `stamp-` |
| `stickers/` | `import-sticker-art.py` | `StickerArt` | `sticker-` |
| `vino/` | `import-vino-art.py` | `VinoArt` | `vino-` |

**`PixelArtLoader`'s namespace is flat and global.** It walks the bundle
directories in order and takes the first hit, so two registers holding the same
word would be resolved by list order. `buttons/` predates the convention and is
searched last as a guard; every set added since carries a prefix, and the
prefixes are what make the families disjoint by construction rather than by a
fact about today's catalog.

**Two registers, one subject, on purpose.** `chrome/buttons/` and
`chrome/marquee/` draw many of the same pages — nineteen stems collide — because
a moulded lamp on the chassis and a page glyph on a lit segment LCD are
different drawings of the same thing. `chrome/glyphs/` is the same register as
`buttons/` (magenta key, cel outline, cream palette) but a different namespace;
`chrome/marquee/` is the odd one out and is measurably so: no cel outline at
all, which is why its importer derives alpha from the green channel instead of
flood-filling a background.

`stickers/` was called `artifacts/` until 0.8.9a. It holds the per-skin
back-plate decals, which is what `PixelArtLoader`'s own comment had been calling
`art/icons/stickers/` for two releases.

## `reference/` — contact sheets and source sheets

Read by nothing. These are the sheets individual assets were cut *from*
(`profvino-sheet.png`, `newpass-sheet-1.png`, `classesicons*.png`,
`grapelist.png`), kept because the cut is not reversible and the next expression
or class glyph gets drawn against them.

## `attic/` — drawn, and not shipping

Read by nothing. See `attic/README.md`. Deleting art is not reversible in any
way that matters, so superseded and unreferenced pieces are parked here rather
than removed — including alternate takes on art that *is* live, which arrive
whenever a drop redraws something already on disk.
