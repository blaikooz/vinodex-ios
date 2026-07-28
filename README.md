# Vinodex — iOS

A SwiftUI port of [Vinodex](https://github.com/blaikooz/vinodex), a retro-handheld
wine field guide covering grape varieties, regions, styles and tasting profiles.

> **This repo is generated.** It is assembled and published from the
> [`blaikooz/vinodex`](https://github.com/blaikooz/vinodex) monorepo by
> `scripts/publish-swift.mjs`. Commits made directly here will be overwritten on
> the next publish — send changes to the monorepo instead.

Everything needed to build, run **and regenerate** the app is in this repo. No
part of the build reaches outside it.

## Layout

| Path | What it is |
|---|---|
| `Package.swift` | SwiftPM manifest — one library product, `Vinodex` |
| `Sources/VinodexCore/` | Foundation-only model + queries. Builds and tests on Linux. |
| `Sources/VinodexUI/` | SwiftUI views, guarded `#if canImport(SwiftUI) && canImport(UIKit)` |
| `Sources/VinodexApp/` | App entry point and routing |
| `Tests/VinodexCoreTests/` | Tests for `VinodexCore` — the only target with coverage |
| `shared/` | The data + colour tables, as TypeScript. Source of truth for the JSON. |
| `scripts/` | Data generator and icon rasteriser |
| `pixelflags/` | Pixel-art country/state flags, the source for `Resources/Flags` |
| `xtool.yml` | Bundle ID and icon path for [xtool](https://github.com/xtool-org/xtool) |

## Build and run

The app builds from the committed resources alone — **Node is not required**
unless you are regenerating data.

Requires Swift 6.3 and, for a device build, [xtool](https://github.com/xtool-org/xtool)
with a Darwin SDK. Development happens on Linux/WSL; there is no Xcode project.

```bash
swift test                 # VinodexCore, runs anywhere Swift does
xtool dev build            # build the iOS app
xtool dev run              # build, install and launch on a connected device
```

`swift test` does **not** compile `VinodexUI` — on Linux the `canImport(SwiftUI)`
guards reduce it to nothing, so a syntax error there passes `swift test` and only
fails under `xtool dev build`. UI changes have to be checked on a device.

## Regenerating the bundled data

`Sources/VinodexCore/Resources/{entries,palette,tiers,icons}.json` are generated
from `shared/` and committed, so a Swift build never needs Node. Regenerate only
after changing something under `shared/`:

```bash
npm install
npm run generate           # rewrites the four JSON files
npm run icons              # re-rasterises Icons/ and re-copies Flags/
```

`npm run icons` needs `rsvg-convert` (`apt install librsvg2-bin`), `python3`, and
network access to `api.iconify.design`.

Generation is deterministic: a change scoped to one table leaves the other files
byte-identical. Always check `git diff --stat Sources/VinodexCore/Resources/`
afterwards — a wider diff than expected means the change was wider than intended.

Note `CoverageTests` pins per-category counts, so deliberately changing the entry
selection will fail two tests that must then be updated by hand.

## Operational notes

`KNOWN-ISSUES.md` is the runbook — device deployment, the WSL build setup, and
the traps that produce false readings. Read it before debugging a failed deploy.
