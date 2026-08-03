<div align="center">

<img src="AppIcon.png" alt="Vinodex" width="148" />

# VINODEX

### A wine encyclopedia that looks like a 90s handheld.

**281 grapes, regions, styles and flavours** — colour-coded, cross-linked, and
wrapped in a plastic shell you can re-skin ten different ways.

### **[Build it → `xtool dev run`](#running-it)**

`Swift 6.3` · `SwiftUI` · `iOS 17+` · `SwiftPM` · `xtool`

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

*Hand-drawn pixel flags, one per wine-producing country and state in the atlas.*

</div>

---

## What's in it

| | |
|---|---|
| **The dex** | Grapes, regions, styles, flavours and continents. Every entry cross-links to the others, and every link resolves — the tests pin that. |
| **Globe scan** | A drag-to-spin globe. Continent markers open a continent screen, then its countries, then their regions. Where you spun it to survives the trip into a region. |
| **Scanner** | Colour, body, origin, flavours — then a deduction. Flavours are ANDed, capped at three, because a fourth specific note reliably matches nothing. |
| **Filter search** | Narrow all 281 entries by colour, body, rarity and climate at once. Every chip shows the count it would produce *before* you tap it. |
| **Tasting quiz** | Three tiers — NOVICE, ENTHUSIAST, SOMMELIER — each a ten-question round, 8/10 to pass, and a pass unlocks the next. Generated from the data, so a question can never contradict the entry behind it. |
| **Daily challenge** | One five-question paper per day, the same paper for everyone, 4/5 to pass. Passing keeps the streak alive; there is no retry, because the retry would be the same paper. |
| **Tried & Passport** | Mark grapes and styles TRIED (with a 1–5 rating and a one-line note) or WANT TO TRY. The passport turns the tried shelf into progress — n of 80 grapes, countries visited, milestone stamps. |
| **What's that…?** | A daily reveal played as a guess. Deterministic from the date, so everyone gets the same entry, and a cursor that advances per open so it is replayable. |
| **Moon dial** | The biodynamic day — fruit, root, leaf or flower. |
| **Saved** | Bookmarks, stored as ids so a data regeneration never shows stale text. Your own photograph and name sit above them. |
| **Guided tour** | Opt-in from BEGIN in settings — a walk round the device with each control lit in turn. Never shown unasked. |
| **Nothing loses its place** | Scroll positions, expanded sections, searches and half-finished quiz rounds all survive Back. Home is the reset. |

Every entry ships unlocked. There is no account and no tracking; your bookmarks,
name, photo and chosen skin live on your own device, and SETTINGS carries a
CLEAR SAVED DATA button that puts all of it back to a fresh install. The paywall
machinery you can see in the ACCESS panel is a test harness — off by default,
there so the locked experience stays testable rather than hypothetical.

## Fourteen devices, not one device in fourteen colours

Each chassis skin carries its own **orb**, its own **buttons** and its own
**marquee phosphor** — the parts that look powered — on top of its moulding. The
LCD never changes with the skin, so a colourway can never hurt legibility.

| Skin | Shell | Orb | Marquee |
|---|---|---|---|
| **Vinodex Classic** | House red | Cyan | Green |
| **Côte de Nuits** | Graphite | Amethyst | Violet |
| **Blanc de Blancs** | Bone | Champagne gold | Amber |
| **Burgundy** | Velvet purple | Deep purple | Rose |
| **Electric Riesling** | Walkman yellow | Signal red | Green |
| **Box Wine** | Forest green | Pea green | Pea green |
| **Empty Bottle** | Clear smoke over mock internals, front and back | Orange | Orange |
| **Smart Grape** | Calculator black | Calculator orange | Orange |
| **Champagne Gold** | Pale champagne | Gold leaf | Gold |
| **Wine Xmas** | Pixel wrapping paper on pine | Holly red | Holly red |
| **Nouveau** | Atomic-purple smoke over mock internals | Grape purple | Lilac |
| **Oaked** | Walnut woodgrain, cream faceplate | Chestnut | Amber |
| **Vinho Verde** | Glow-in-the-dark green, glowing rim | Charged green | Green |
| **Stainless Steel** | Brushed aluminium, crisp dark seams | Ice | Ice blue |

Plus nine screen modes in three groups. **Classic** is dark and light.
**Retro** is period display hardware — monochrome VINTAGE (black on grey-green
like an old organiser), the AMBER and TERMINAL phosphors, and the GRÜNERBOY
dot-matrix. **Emulator** quotes one specific machine each — the early-GUI
WINE.OS, the VINOFD blue tube, the L-WINES console — and each Emulator mode
repaints the LCD's coloured chrome in its own palette rather than wearing the
house colours. Two text sizes, a haptics switch, and an authored SFX pack —
clicks, pings and stings, off by default — with its own switch.

## The web app is the sibling, not the source

**[`blaikooz/vinodex-web`](https://github.com/blaikooz/vinodex-web)** is a
progressive web app wearing the same device — same chassis, same screens, same
rules — built on a different stack because it is for a different moment.

| | **Vinodex for iOS** ← *this repo* | **Vinodex Web** |
|---|---|---|
| **What it is** | A native SwiftUI app for the phone in your pocket. Haptics on every button, the photo library for your avatar, and a real 3D globe. The one you open in a wine shop. | A progressive web app that runs in any browser and installs to a home screen. Nothing to download, nothing to sign. The one you send someone a link to. |
| **Built with** | `Swift 6.3` · `SwiftUI` · `iOS 17+` · `SwiftPM` · `xtool` | `React 19` · `TypeScript` · `Vite` · `Tailwind v4` |
| **Where** | [`blaikooz/vinodex-ios`](https://github.com/blaikooz/vinodex-ios) | [`blaikooz/vinodex-web`](https://github.com/blaikooz/vinodex-web) → **[open it](https://vinodex.vercel.app)** |
| **Run it** | `swift test`, then `xtool dev run` | `npm install && npm run dev` |

**This Swift source is the reference when the two disagree.** The web app is
kept deliberately close to it, and neither repo copies from the other.

> ### This repo is the app — and owns itself
>
> This repo owns its source, its data and the tooling that generates that data.
> Commit here, open pull requests here. Nothing outside it is required to
> build, test or regenerate it, and nothing outside it can write to it.
>
> **History note.** Until 2026-07-29 this repo was *assembled* from the
> `blaikooz/vinodex` monorepo by a publish script that emptied the tree and
> rebuilt it on every run, so direct commits did not survive — the merged
> [PR #1](https://github.com/blaikooz/vinodex-ios/pull/1) lost `AUDIT.md` to
> exactly that. The publish path has been deleted and the monorepo's copies of
> `ios/`, `shared/` and `pixelflags/` are frozen leftovers. This repo is
> authoritative — **an iOS data change is made here.**

## Running it

Swift 6.3, and for a device build [xtool](https://github.com/xtool-org/xtool)
with a Darwin SDK. The app builds from the committed resources alone — **Node is
not required** unless you are regenerating data. Development happens on
Linux/WSL; there is no Xcode project.

```bash
swift test                 # VinodexCore — runs anywhere Swift does
```

```bash
xtool dev build            # build the iOS app
xtool dev run              # build, install and launch on a connected device
```

`swift test` and a clean `xtool dev build` are the gates.

Tests are Swift Testing suites in `Tests/VinodexCoreTests/`, covering the model
and query layer — the only target with coverage. `swift test` does **not**
compile `VinodexUI`: on Linux the `canImport(SwiftUI)` guards reduce it to
nothing, so a syntax error there passes `swift test` and only fails under
`xtool dev build`. UI changes have to be checked on a device. The web app's
Vitest suites are ports of these, and each of its files records which Swift
cases were adapted or dropped and why.

## Deploying

To a phone, via xtool from WSL:

- The bundle ID in [`xtool.yml`](xtool.yml) (`com.example.Vinodex`) is a
  **placeholder** — change it before signing for real. A free Apple developer
  profile caps you at **three App IDs**, so burn them thoughtfully.
- **Annotated git tags are the version of record** (`v` + the version in
  `AppVersion.swift`). xtool stamps `1.0.0` into every bundle it builds, so the
  tag and `AppVersion.fallback` are the truth, not the Info.plist.
- **Deploying from Windows + WSL is where the time actually goes.**
  [`KNOWN-ISSUES.md`](KNOWN-ISSUES.md) is the runbook — start with the port
  27015 race, which is the single most likely reason a deploy fails.

## Layout

```text
vinodex-ios/
  Package.swift            SwiftPM manifest — one library product, Vinodex
  Sources/
    VinodexCore/           Foundation-only model + queries. Builds and tests on Linux.
    VinodexUI/             SwiftUI views, guarded #if canImport(SwiftUI) && canImport(UIKit)
    VinodexApp/            App entry point and routing
  Tests/
    VinodexCoreTests/      Tests for VinodexCore — the only target with coverage
  shared/                  The data + colour tables, as TypeScript. Source of truth for the JSON.
  art/icons/               Drawn icon source art, one folder per use (flavors, styles,
                           grapes, classes, subclasses, color, body, climate, soil,
                           countries, continents, styleclasses)
  art/icons/reference/     Contact sheets — the artist's originals, not imported
  art/icons/attic/         Drawn but unreferenced; kept so nothing is lost
  art/sfx/                 Audio masters, the source for Resources/SFX
  scripts/                 Data generator and icon rasteriser
  shared/pixelflags/       Pixel-art flags — cross-repo master (web consumes them too), source for Resources/Flags
  xtool.yml                Bundle ID and icon path for xtool
  godot-md/AUDIT.md        Standing work order — numbered, permanent IDs referenced in commits
  horizon-md/, godot-md/   Per-collaborator doc folders (0.6.5)
  KNOWN-ISSUES.md          Runbook: device deployment, WSL setup, traps that waste time
```

### Working on data or colours

`Sources/VinodexCore/Resources/{entries,palette,tiers,icons,countries}.json` are
generated from `shared/` and committed, so a Swift build never needs Node.
Regenerate only after changing something under `shared/`:

```bash
npm install
npm run generate           # rewrites the five JSON files
npm run icons              # Icons/ + Flags/ + the four drawn-art importers
npm run icons:verify       # checks art/ still reproduces the committed art
```

`npm run icons` needs `rsvg-convert` (`apt install librsvg2-bin`), `python3`,
Pillow (`pip install -r scripts/requirements.txt`), and network access to
`api.iconify.design`. Verify any new Iconify id resolves before adding it — the
API answers a miss with a non-SVG body rather than an error. `SKIP_ART=1` runs
the Iconify/flag half alone; `SKIP_FLAGS=1` skips the flag copy. Both announce
themselves in the log.

The drawn half of the pipeline reads `art/icons/**` and writes
`Sources/VinodexUI/Resources/{FlavorArt,GrapeArt,StyleArt,ClassArt}`.
`npm run icons:verify` re-runs those four importers into a temp directory —
never over your working copy — and compares pixels against what is committed.
It is not byte-exact by design: the 256-colour quantise resolves its palette
slightly differently across Pillow builds, so ten saturated sources land a few
pixels off. Those ten carry a recorded budget in `scripts/verify-art.py`;
anything else that moves is a real change.

Generation is deterministic: a change scoped to one table leaves the other files
byte-identical. Always check `git diff --stat Sources/VinodexCore/Resources/`
afterwards — a wider diff than expected means the change was wider than intended.
CI enforces this: a push whose `shared/` and generated JSON disagree fails the
`generated data is current` job. Note `CoverageTests` pins per-category counts,
so deliberately changing the entry selection will fail two tests that must then
be updated by hand.

The copy of `shared/` in `vinodex-web` feeds the web app only — changing it has
no effect on iOS.

## Contributing

- Branch from `main`, open a PR. CI runs `swift test` on Linux and checks the
  generated data is in step with `shared/`.
- A green CI run does not mean the app builds — the UI layer is invisible to
  Linux. Run `xtool dev build` before merging anything that touches
  `Sources/VinodexUI/` or `Sources/VinodexApp/`.
- `godot-md/AUDIT.md` carries permanent item IDs (`H3`, `M12`, `L27`). Name the ones a PR
  closes in its description and tick them in the same PR.
- `KNOWN-ISSUES.md` is where operational discoveries go — anything that cost you
  an hour and would cost the next person the same.

## Credits

- **game-icons** — wine, flavour and regional glyphs, via Iconify
  ([game-icons.net](https://game-icons.net))
- **Press Start 2P** and **VT323** — the retro and terminal faces
