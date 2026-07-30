<div align="center">

<img src="AppIcon.png" alt="Vinodex" width="148" />

# VINODEX

### A wine encyclopedia that looks like a 90s handheld.

**284 grapes, regions, styles and flavours** — colour-coded, cross-linked, and
wrapped in a plastic shell you can re-skin five different ways.

<p>
<img src="Sources/VinodexUI/Resources/Flags/france.png" alt="France" height="24" />
<img src="Sources/VinodexUI/Resources/Flags/italy.png" alt="Italy" height="24" />
<img src="Sources/VinodexUI/Resources/Flags/spain.png" alt="Spain" height="24" />
<img src="Sources/VinodexUI/Resources/Flags/portugal.png" alt="Portugal" height="24" />
<img src="Sources/VinodexUI/Resources/Flags/germany.png" alt="Germany" height="24" />
<img src="Sources/VinodexUI/Resources/Flags/austria.png" alt="Austria" height="24" />
<img src="Sources/VinodexUI/Resources/Flags/greece.png" alt="Greece" height="24" />
<img src="Sources/VinodexUI/Resources/Flags/usa.png" alt="USA" height="24" />
<img src="Sources/VinodexUI/Resources/Flags/argentina.png" alt="Argentina" height="24" />
<img src="Sources/VinodexUI/Resources/Flags/chile.png" alt="Chile" height="24" />
<img src="Sources/VinodexUI/Resources/Flags/australia.png" alt="Australia" height="24" />
<img src="Sources/VinodexUI/Resources/Flags/new-zealand.png" alt="New Zealand" height="24" />
<img src="Sources/VinodexUI/Resources/Flags/south-africa.png" alt="South Africa" height="24" />
<img src="Sources/VinodexUI/Resources/Flags/japan.png" alt="Japan" height="24" />
</p>

</div>

---

## Two apps, one device

Vinodex exists twice. Same chassis, same screens, same rules — built on
different stacks because they are for different moments.

| | **Vinodex for iOS** ← *this repo* | **Vinodex Web** |
|---|---|---|
| **What it is** | A native SwiftUI app for the phone in your pocket. Haptics on every button, the photo library for your avatar, and a real 3D globe. The one you open in a wine shop. | A progressive web app that runs in any browser and installs to a home screen. Nothing to download, nothing to sign. The one you send someone a link to. |
| **Built with** | `Swift 6.3` · `SwiftUI` · `iOS 17+` · `SwiftPM` · `xtool` | `React 19` · `TypeScript` · `Vite` · `Tailwind v4` |
| **Where** | [`blaikooz/vinodex-ios`](https://github.com/blaikooz/vinodex-ios) | [`blaikooz/vinodex-web`](https://github.com/blaikooz/vinodex-web) → **[open it](https://vinodex.vercel.app)** |
| **Run it** | `swift test`, then `xtool dev run` | `npm install && npm run dev` |

**This Swift source is the reference when the two disagree.** The web app is
kept deliberately close to it, and neither repo copies from the other.

## What's in it

| | |
|---|---|
| **The dex** | Grapes, regions, styles, flavours and continents. Every entry cross-links to the others, and every link resolves — the tests pin that. |
| **Globe scan** | A drag-to-spin globe. Continent markers open a continent screen, then its countries, then their regions. Where you spun it to survives the trip into a region. |
| **Scanner** | Colour, body, origin, flavours — then a deduction. Flavours are ANDed, capped at three, because a fourth specific note reliably matches nothing. |
| **Chip filter** | Narrow all 284 entries by colour, body, rarity and climate at once. Every chip shows the count it would produce *before* you tap it. |
| **Tasting quiz** | WSET Level 1-style questions generated from the data, so a question can never contradict the entry behind it. Answer, then read the entry you just met. |
| **What's that…?** | A daily reveal played as a guess. Deterministic from the date, so everyone gets the same entry, and a cursor that advances per open so it is replayable. |
| **Moon dial** | The biodynamic day — fruit, root, leaf or flower. |
| **Saved** | Bookmarks, stored as ids so a data regeneration never shows stale text. Your own photograph and name sit above them. |
| **Guided tour** | Opt-in from BEGIN in settings — a walk round the device with each control lit in turn. Never shown unasked. |
| **Nothing loses its place** | Scroll positions, expanded sections, searches and half-finished scans all survive Back. Home is the reset. |

## Five devices, not one device in five colours

Each chassis skin carries its own **orb**, its own **buttons** and its own
**marquee phosphor** — the parts that look powered — on top of its moulding. The
LCD never changes with the skin, so a colourway can never hurt legibility.

| Skin | Shell | Orb | Marquee |
|---|---|---|---|
| **Vinodex Classic** | House red | Cyan | Green |
| **Côte de Nuits** | Graphite | Amethyst | Violet |
| **Blanc de Blancs** | Bone | Champagne gold | Amber |
| **Burgundy Velour** | Velvet purple | Gold | Rose |
| **Electric Riesling** | Walkman yellow | Electric blue | Cyan |

Plus a light screen mode and two text sizes.

## How to run it

The app builds from the committed resources alone — **Node is not required**
unless you are regenerating data. Requires Swift 6.3 and, for a device build,
[xtool](https://github.com/xtool-org/xtool) with a Darwin SDK. Development
happens on Linux/WSL; there is no Xcode project.

```bash
swift test                 # VinodexCore — runs anywhere Swift does
xtool dev build            # build the iOS app
xtool dev run              # build, install and launch on a connected device
```

`swift test` does **not** compile `VinodexUI` — on Linux the `canImport(SwiftUI)`
guards reduce it to nothing, so a syntax error there passes `swift test` and only
fails under `xtool dev build`. UI changes have to be checked on a device.

> **Deploying to a phone from Windows + WSL is where the time actually goes.**
> [`KNOWN-ISSUES.md`](KNOWN-ISSUES.md) is the runbook — start with the port 27015
> race, which is the single most likely reason a deploy fails.

## Repo ownership

**This repo is the app.** It owns its source, its data and the tooling that
generates that data. Commit here, open pull requests here. Nothing outside this
repo is required to build, test or regenerate it, and nothing outside it can
write to it.

> **History note.** Until 2026-07-29 this repo was *assembled* from the
> `blaikooz/vinodex` monorepo by a publish script that emptied the tree and
> rebuilt it on every run, so direct commits did not survive — the merged
> [PR #1](https://github.com/blaikooz/vinodex-ios/pull/1) lost `AUDIT.md` to
> exactly that. The publish path has been deleted and the monorepo's copies of
> `ios/`, `shared/` and `pixelflags/` are frozen leftovers. This repo is
> authoritative.

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
| [`AUDIT.md`](AUDIT.md) | Standing work order — numbered, permanent IDs referenced in commits |
| [`KNOWN-ISSUES.md`](KNOWN-ISSUES.md) | Runbook: device deployment, WSL setup, traps that waste time |

## Regenerating the bundled data

`Sources/VinodexCore/Resources/{entries,palette,tiers,icons,countries}.json` are
generated from `shared/` and committed, so a Swift build never needs Node.
Regenerate only after changing something under `shared/`:

```bash
npm install
npm run generate           # rewrites the five JSON files
npm run icons              # re-rasterises Icons/ and re-copies Flags/
```

`npm run icons` needs `rsvg-convert` (`apt install librsvg2-bin`), `python3`, and
network access to `api.iconify.design`. Verify any new Iconify id resolves before
adding it — the API answers a miss with a non-SVG body rather than an error.

Generation is deterministic: a change scoped to one table leaves the other files
byte-identical. Always check `git diff --stat Sources/VinodexCore/Resources/`
afterwards — a wider diff than expected means the change was wider than intended.
CI enforces this: a push whose `shared/` and generated JSON disagree fails the
`generated data is current` job.

Note `CoverageTests` pins per-category counts, so deliberately changing the entry
selection will fail two tests that must then be updated by hand.

## Contributing

- Branch from `main`, open a PR. CI runs `swift test` on Linux and checks the
  generated data is in step with `shared/`.
- A green CI run does not mean the app builds — the UI layer is invisible to
  Linux. Run `xtool dev build` before merging anything that touches
  `Sources/VinodexUI/` or `Sources/VinodexApp/`.
- `AUDIT.md` carries permanent item IDs (`H3`, `M12`, `L27`). Name the ones a PR
  closes in its description and tick them in the same PR.
- `KNOWN-ISSUES.md` is where operational discoveries go — anything that cost you
  an hour and would cost the next person the same.

## Credits

- **game-icons** — wine, flavour and regional glyphs, via Iconify
  ([game-icons.net](https://game-icons.net))
- **Press Start 2P** and **VT323** — the retro and terminal faces
