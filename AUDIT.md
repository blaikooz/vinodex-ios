# Vinodex Audit — 2026-07-28

A work order, not a report. Every item below is a specific, located defect with a
proposed fix. Work through them in any order; check them off as they land.

**IDs are permanent.** Reference them in commits and PRs as `H3`, `M12`, `L27` —
they never get renumbered, even as items are resolved.

## Status

**44 resolved · 1 won't-fix · 52 open**

Reconciled against `0a446d3` on 2026-07-29, then worked on the `audit-fixes`
branch. The counts first moved because the code advanced through v0.4.1 and
v0.4.1.5 *after* the last re-verification at `fb5dcf2`, and this file was restored
from a snapshot predating those releases — so 13 items were already fixed in code
(checked off with a `Verified @0a446d3` note). The `audit-fixes` branch then landed
the verifiable pipeline pass and the low-risk Swift batches (light-mode, a11y,
data-strip, dead-code, tiers robustness) — see the update log. **The remaining 52
are the higher-risk refactors and anything needing a compiler/device to verify.**

Reconciled again at v0.4.3, when `screen-state`, `version-independent` and
`audit-fixes` were folded into `main` together. The three branches were cut from
the same commit and audited independently, so `audit-fixes` still listed **M26**
as open while the `screen-state` chain had closed it — one Medium moves across,
and that is the only count the merge changed. Anything else the three branches
overlapped on is code, not bookkeeping.

| Severity | Open | Resolved | Won't-fix | Total |
|---|---:|---:|---:|---:|
| Critical | 0 | — | — | 0 |
| High | 3 | 8 | — | 11 |
| Medium | 25 | 18 | 1 | 44 |
| Low | 24 | 18 | — | 42 |
| **Total** | **52** | **44** | **1** | **97** |

Open items by workstream — each row is roughly one sitting's worth of related work:

| Workstream | Open | Items |
|---|---:|---|
| UI & UX polish | 14 | M17 M23 M24 · L28 L32 L35–L42 |
| Performance | 11 | M5 M6 M7 M8 M9 M11 · L11 L12 L14 L15 L16 |
| Architecture & code quality | 9 | M27–M31 · L1 L2 L9 L10 |
| Release & licensing | 5 | M35 M36 M37 · L20 L22 |
| Accessibility | 4 | H11 · M18 M20 M21 |
| Data & robustness | 3 | H2 · M2 M3 |
| Pipeline & reproducibility | 3 | M40 · L25 L26 |
| Tests & CI | 2 | M32 M33 |
| Light mode & contrast | 1 | L33 |

**No critical items.** Nothing crashes, corrupts data, or breaks the build today.
The closest call is the all-or-nothing database decode (**H2**) — one bad
regeneration away from becoming critical. It is now the highest open item: the
`decodeErrors` plumbing and a diagnostics readout exist, but the array still
decodes all-or-nothing and no `DexAlert` surfaces the failure.

**Won't-fix:** **M12** (PixelOutline's eight-shadow glyph outline) — a code
comment deliberately keeps the runtime-tintable shadow approach rather than
baking outlines into cached bitmaps. Left as documented intent, not open work.

## Working on this

### Where fixes land

**Here.** This repo owns the iOS app outright as of 2026-07-29 — commit to it,
open PRs against it, and CI runs `swift test` on every one.

That was not true when this document was written, and the warning it carried was
correct. The repo was assembled from the `blaikooz/vinodex` monorepo by a publish
script that emptied the tree and rebuilt it, so a merged PR did not survive the
next publish — **this file was deleted that way**, on 2026-07-29, and restored
from `2cae512`. The publish path (script, `swift` remote, `swift-main` branch,
npm entry points) has since been deleted, and the monorepo's copies of `ios/`,
`shared/` and `pixelflags/` are frozen leftovers nobody edits. Nothing copies
between the two repos in either direction. See
[KNOWN-ISSUES.md](KNOWN-ISSUES.md#repo-layout).

### Convention

One PR per workstream row where possible, and name the IDs it closes in the
description — `Closes H4, H5, M14` — so each checkbox has a traceable commit.

### Line numbers

`file:line` references are pinned to `fb5dcf2` and drift as code moves. The file
and symbol names are the durable part; if a line number misses, search for the
quoted symbol instead.

---

## High — open

- [ ] **H2** · robustness · entries.json decodes all-or-nothing — one malformed entry empties the whole database with no user-facing signal (already happened once, per generate.ts:601) · `Sources/VinodexCore/WineDatabase.swift:249` → decode element-wise via failable wrapper, keep good entries, surface decodeErrors with a DexAlert
- [x] **H4** · light-mode · LinkedRow titles hardcode `resolved ? .white : Dex.stone600` on `lcd.surface` (#FFFFFF in light) — NOTABLE GRAPES/REGIONS and FLAVOR PROFILE rows still invisible in light mode · `Sources/VinodexUI/EntryDetailScreen.swift:706` → replace with `lcd.text`/`lcd.subtext` (thread LcdMode into LinkedRow)
  - **Resolved @0a446d3.** `LinkedRow` now reads `resolved ? lcd.text : lcd.disabledText`, with `lcd` threaded in via `@AppStorage(LcdMode.storageKey)`.
- [x] **H5** · light-mode · profile name, saved-place, state-row, and country-row titles hardcode `.white` on `lcd.surface` — invisible in light mode · `BookmarksScreen.swift:149,226` + `CountryScreen.swift:278` + `ContinentScreen.swift:162` → swap to `lcd.text` (`lcd.subtext` for unwritten states)
  - **Resolved @0a446d3.** Bookmarks profile/saved rows and the state/country titles use `lcd.text`; `ContinentScreen` uses `hasRegions ? lcd.text : lcd.disabledText`.
- [ ] **H6** · assets · IconLoader never picks @2x/@3x — every glyph upscales from the 64px @1x (visibly soft app-wide) while 212 hi-res variants ship as dead payload · `Sources/VinodexUI/DexIcon.swift:24` → load the scale-matched variant via `UIImage(data:scale:)` (or stop shipping unused scales)
- [x] **H7** · layout · FlagSwatch hardcodes its internal 52×32 frame, so re-framed callers draw broken chrome (96×60 heroes float, 40×26/48×32 rows overflow their strokes) · `Sources/VinodexUI/EntryDetailScreen.swift:739` → add width/height params and drop callers' outer `.frame` overrides
  - **Resolved @0a446d3.** `FlagSwatch` takes `width`/`height` (default 52×32) and frames itself; all 9 call sites pass explicit sizes with no outer `.frame` override.
- [x] **H8** · perf · master-search list is an eager ScrollView+VStack — all 284 rows (icon resolve + flag decode + chips) built at once and rebuilt per query change · `Sources/VinodexUI/EncyclopediaListScreen.swift:60` → LazyVStack
  - **Resolved @0a446d3** (v0.4.1). The list is a `LazyVStack` and `results` is recomputed once per query via `.task(id:)`.
- [x] **H9** · perf · `entry(named:)`/`entry(id:)` are O(n) scans re-running Unicode folding per candidate, called per-row per-render (~20k+ foldings per list pass) · `Sources/VinodexCore/WineDatabase.swift:327,318` → precompute `[normalizedKey→entry]` and `[id→entry]` dictionaries in init
  - **Resolved @0a446d3** (v0.4.1). `WineDatabase.init` builds `byID`, `byName` (per-category) and `byNameAnyCategory`; both lookups are now hash lookups.
- [x] **H10** · a11y · Back/Home/Saved chassis buttons have no accessibilityLabel (Saved announces as a person icon) — primary navigation unlabeled for VoiceOver · `Sources/VinodexUI/DeviceChassis.swift:428` → add `.accessibilityLabel` per ChassisButton kind, matching the settings cog
- [ ] **H11** · a11y · Dynamic Type strategy is incoherent: `Font.custom(_:size:)` auto-scales with system text size while every layout metric is a fixed literal and no cap is set — accessibility sizes blow out tiles/marquee/chips, and 8–9pt base labels sit below the HIG floor · `Sources/VinodexUI/DexTheme.swift:264` + `VinodexApp.swift:59` → either cap at the root and use `fixedSize` fonts (relying on in-app TEXT SIZE), or adopt `relativeTo` + ScaledMetric layouts; raise the 8–9pt floors

## Medium — open

**Data & robustness**

- [x] **M1** · robustness · tiers.json decoded with `try?` — a corrupt manifest silently unlocks the entire paywall and never reaches decodeErrors · `Sources/VinodexCore/WineDatabase.swift:253` → do/catch distinguishing file-missing (unlock) from decode-failure (log to decodeErrors)
- [ ] **M2** · ux-state · a DB decode failure shows a normal menu plus "NO DATA FOUND" (reads as a no-results message), truth visible only in the DEV tab · `Sources/VinodexCore/WineDatabase.swift:260` + `EncyclopediaListScreen.swift:123` → explicit "DATA LOAD ERROR" state when decodeErrors is non-empty
- [ ] **M3** · pipeline · no schema contract between generator and Swift (no version field, no validation; generator already emits keys Swift silently drops) — a TS rename ships as a whole-app decode failure · `scripts/generate-ios-data.ts:674` → emit a schemaVersion asserted at load plus a generator-side decode smoke test
  - **Partly prepped (`audit-fixes`).** `validateOutputs()` now re-reads the written JSON and asserts the shape the Swift structs require, failing `npm run generate` (and CI) on drift — positive+negative tested. Held: the `schemaVersion` field emitted-and-asserted-at-load (Swift side).
- [x] **M4** · data · entries.json ships ~70KB (~20%) in never-read fields (grapeCard 47.7KB, callbacks 14.5KB, icon, grapeRarityTier) parsed at every launch · `Sources/VinodexCore/WineEntry.swift:89` → strip from generator output and delete the unused EntryCommon properties
  - **Resolved (`audit-fixes`).** Generator strips `grapeCard`, `grapeRarityTier`, `icon`, `iconCallback`, `tileCallback`; the three optional `EntryCommon` properties were deleted. entries.json 346KB → 175KB. Proven surgical by deep-equality against HEAD (nested `tastingProfile.icon` retained).

**Performance**

- [ ] **M5** · perf · search runs un-debounced, re-folding every field of every entry and re-sorting per keystroke · `Sources/VinodexCore/EntryFilter.swift:171` + `DexSearchField.swift:69` → pre-folded haystack per entry, pre-sorted base list, ~200ms debounce
  - **Since audit:** narrowed by v0.3.9 — `task(id:)` stopped re-querying on unrelated re-renders; the per-keystroke fold+sort and missing debounce remain.
- [ ] **M6** · perf · first frame blocks on the full DB decode plus six regions() queries via `Diagnostics.emit()` in App.init · `Sources/VinodexApp/VinodexApp.swift:9` → defer to a background task/DEBUG-only and warm the DB off-main
- [ ] **M7** · perf · CountryScreen re-runs the full-database `regions` query ~10× per body pass (states, grapes, appellations, counts) · `Sources/VinodexUI/CountryScreen.swift:40` → compute once per body/init and derive the rest
- [ ] **M8** · perf · MarqueeBanner re-measures text (UIFont + NSString sizing + two DexFont builds) up to 120×/s forever, even hidden behind the flipped back plate · `Sources/VinodexUI/DeviceChassis.swift:652` → cache cell/cycle/font per text change and pause while flipped
- [ ] **M9** · perf · marquee measures at raw fontSize but renders through TextScale (1.2×) — the seam jumps/overlaps whenever LARGE text is set · `Sources/VinodexUI/DeviceChassis.swift:626` → measure at the effective rendered size
- [x] **M10** · perf · FlagImage does an uncached `UIImage(contentsOfFile:)` on every body eval (2× per shaped well) · `Sources/VinodexUI/EntryVisual.swift:314` → @MainActor flag cache mirroring IconLoader
  - **Resolved @0a446d3.** `@MainActor final class FlagLoader` caches `[String: UIImage?]`; `FlagImage` calls `FlagLoader.shared.image(for:)`.
- [ ] **M11** · perf · globe CADisplayLink runs at native refresh with a constant per-frame spin — 2× speed and 2× cost on 120Hz ProMotion · `Sources/VinodexUI/RetroGlobeScreen.swift:338` → time-based deltas plus `preferredFrameRateRange` 30–60
- [~] **M12** · perf · PixelOutline stacks eight zero-radius `.shadow` passes per icon (9× composite per glyph) across every list, tile, and grid · `Sources/VinodexUI/DexIcon.swift:79` → bake the outline into the cached UIImage inside IconLoader
  - **Won't-fix @0a446d3.** A code comment in `DexIcon.swift` deliberately keeps the shadow approach so glyphs stay runtime-tintable; baking outlines into cached bitmaps would block that. Documented intent, not open work.

**UI & light mode**

- [x] **M13** · light-mode · DexSearchField styles from LcdMode.current only in makeUIView — toggling SCREEN MODE leaves live fields with stale, illegible colors · `Sources/VinodexUI/DexSearchField.swift:34` → re-apply colors in updateUIView with the mode passed as a property
  - **Since audit:** latent-only since v0.3.9 — settings is now a route, so no search field is mounted during a mode toggle. Still worth fixing as hygiene.
- [x] **M14** · contrast · `Dex.stone400` secondary text is ~2.3:1 on light surfaces (appellations, CLEAR ALL) · `CountryScreen.swift:245` + `BookmarksScreen.swift:117` → use `lcd.subtext`
  - **Since audit:** narrowed by v0.3.9 — the EntryDetail state readout was fixed and `lcd.subtext` is now in use there; these two sites remain.
- [x] **M15** · light-mode · the filter banner is hardcoded stone800/stone200 — a dark web-theme strip over light lists · `Sources/VinodexUI/EncyclopediaListScreen.swift:82` → `lcd.surface`/`lcd.text`/`lcd.surfaceEdge`
- [x] **M16** · light-mode · globe screen mixes a hardcoded black page with light-mode tokens (deep-green caption ~3.2:1 on black, stark white search well) · `Sources/VinodexUI/RetroGlobeScreen.swift:33` → commit the screen to dark tokens or theme the page with `lcd.page`
  - **Resolved @0a446d3.** The screen uses `DexScreenBackground()` and rebuilds the scene on `isLight` (`.id(lcd)`), so page, grid and globe emission all follow SCREEN MODE.
- [ ] **M17** · layout · no orientation lock anywhere while chassis geometry hard-assumes a portrait island cutout · `xtool.yml` → declare portrait-only in the generated Info.plist
- [x] **M44** · contrast · selected-option labels in the SYSTEM screen changed from `.black` to `.white` on an `lcd.accent` fill — in dark mode the accent is #4ADE80 mint, so the selected tab/skin/screen-mode/text-size buttons are white-on-mint at ~1.8:1 (was ~12:1) · `Sources/VinodexUI/SettingsPanel.swift:98,224,262,288` → add a per-mode `lcd.onAccent` token (dark → .black, light → .white) and use it for all selected states
  - **Since audit:** new — this is a regression introduced by v0.3.9, not an original finding.

**UX & accessibility**

- [ ] **M18** · a11y · `accessibilityReduceMotion` is checked nowhere — marquee, PulseGlow, globe autospin, and the 0.7s flip are all unstoppable · `Sources/VinodexUI/DeviceChassis.swift:652` → honor the environment flag (static marquee, frozen glow, no autospin, cross-fade)
- [x] **M19** · a11y · DexAlert dialogs are not VO-modal — focus escapes into obscured content and scrim-tap-to-cancel has no accessible equivalent · `Sources/VinodexUI/DexAlert.swift:36` → `.accessibilityAddTraits(.isModal)` on the dialog card
- [ ] **M20** · a11y · continent selection needs taps on continuously moving markers plus a drag for rear continents — impossible under VoiceOver · `Sources/VinodexUI/RetroGlobeScreen.swift:355` → pause autospin at rest / add a static continent-list fallback
- [ ] **M21** · a11y+discoverability · the device flip is an unhinted 2s long-press on a non-button orb; the back plate is unreachable via VoiceOver · `Sources/VinodexUI/DeviceChassis.swift:148` → settings "About / flip" row plus an accessibilityAction on the orb
- [x] **M22** · ux · the PRO alert's UNLOCK button silently dismisses (no storefront exists) — indistinguishable from a broken purchase · `Sources/VinodexApp/VinodexApp.swift:78` → "COMING SOON"/OK until IAP exists
  - **Resolved @0a446d3** (v0.4.1.5). `UpgradePrompt`'s UNLOCK now calls `access.grant(offer)` (persisted via `AccessStore`) and continues navigation — a real entitlement grant, though a payment step is still to come.
- [ ] **M23** · ux · Grape of the Day is buried inside the settings screen — the daily-return feature is invisible from the main menu · `Sources/VinodexUI/SettingsPanel.swift:131` → surface it on the main menu or as an orb badge
  - **Since audit:** v0.3.9 made settings a full SYSTEM screen, but the entry point is unchanged.
- [ ] **M24** · ux · the blanket `.transaction { $0.animation = nil }` strips in-screen animations (expander, daily reveal), not just nav swaps · `Sources/VinodexApp/VinodexApp.swift:71` → scope `Transaction(animation: nil)` to path mutations only
- [x] **M25** · a11y · the destructive remove-bookmark button is a 26×26pt target sitting on a tappable row · `Sources/VinodexUI/BookmarksScreen.swift:255` → 44pt hit area via frame/contentShape, keep the 26pt visual

**Architecture**

- [ ] **M27** · di · leaf views hard-read `WineDatabase.shared` despite the injectable init (LinkedRow, FlagImage, ContinentScreen hero) — nothing is exercisable against a fixture DB · `EntryDetailScreen.swift:690` + `EntryVisual.swift:314` + `ContinentScreen.swift:76` → inject via environment/params and drop the `.shared` reads
- [ ] **M28** · duplication · hero panel, SAVE button, and section header are copy-pasted across 4 screens, and drift already shipped (EntryDetail hero still dark-theme) · `EntryDetailScreen.swift:104` + `CountryScreen.swift:72` + `StateScreen.swift:49` + `ContinentScreen.swift:70` → extract DexHero/DexSaveButton/DexSection
- [ ] **M29** · testability · pure logic lives in the untested UI module (Palette.resolve color mapping, grapeWellColor/styleTone keyword heuristics) · `EntryTileView.swift:98` + `EntryVisual.swift:72` → move to Core returning hex strings and test beside FilterTests
- [ ] **M30** · decomposition · 745-line EntryDetailScreen and 722-line DeviceChassis each bundle 8+ types with clean seams · `EntryDetailScreen.swift` + `DeviceChassis.swift` → split at type boundaries
- [ ] **M31** · assets · LogoMark and its 139KB vinodex-logo.png are fully dead since the cog replaced the wordmark · `Sources/VinodexUI/DeviceChassis.swift:692` → delete the view and the Logo/ asset

**Tests & CI**

- [ ] **M32** · tests · DailyGrapeScreen's actual path `DailyPick.entry(in:)` (rotation, fallback, tier filter) has zero coverage — tests only exercise `.grape` · `Tests/VinodexCoreTests/DailyPickTests.swift:28` → add entry/category rotation and fallback tests
- [ ] **M33** · tests · filter branches `.type`/`.tasting`/`.soil`/`.system` are untested (all reachable from header tiles); styleClass/colorType keyword precedence unpinned · `Sources/VinodexCore/EntryFilter.swift:105` → add branch and precedence tests
- [x] **M34** · ci · no CI at all — the Linux-ready test suite never runs automatically · repo root → GitHub Actions running `swift test` on push/PR
  - **Resolved 2026-07-29** in `.github/workflows/ci.yml`. Two jobs: `swift test`
    on a `swift:6.0` Linux container, and a drift check that regenerates from
    `shared/` and fails if the committed JSON disagrees. The workflow lives here
    rather than "in the monorepo or as a gate on the publish step" — that framing
    predates this repo owning itself, and there is no publish step left to gate.
    Note the job cannot see `VinodexUI`, which is invisible to Linux; it is a
    guard on the model layer and the data pipeline, not on the app.

**Release & process**

- [ ] **M35** · release · placeholder bundleID `com.example.Vinodex`; the future ID change orphans UserDefaults bookmarks/unlocks and the example ID blocks TestFlight · `xtool.yml:9` → register the real App ID as a milestone with a data-migration step
  - **Since audit:** the free-profile App ID cap forcing this is now documented in KNOWN-ISSUES.md; the decision itself is still open.
- [ ] **M36** · licensing · OFL fonts ship without license text and 87/99 icons are CC BY 3.0 with zero attribution; no repo LICENSE · `Sources/VinodexUI/Resources/Fonts/` → add OFL texts, a NOTICE/credits file (surfaced in settings), and a top-level LICENSE
  - **Related:** [KNOWN-ISSUES.md:284](KNOWN-ISSUES.md:284) records that 4.5 MB of a copyrighted wine encyclopedia is committed and public in `blaikooz/vinodex`. Out of scope for this repo, but it belongs on the same cleanup pass.
- [ ] **M37** · release · no git tags, no CHANGELOG, no bundle version — no binary can be traced to a commit · `xtool.yml` → tag releases (start with v0.3.8), keep CHANGELOG.md, set CFBundleShortVersionString/CFBundleVersion
  - **Tags done at v0.4.3.** Releases now carry annotated tags named `v` +
    `AppVersion.fallback`, and the version scheme was cut back to three components
    so the tag, the constant and a future bundle version can be one spelling.
    `v0.4.2.1.1` was the first, on the commit that became this merge.
  - **Bundle version is not achievable with xtool** — 1.17 stamps
    `CFBundleShortVersionString = 1.0.0` unconditionally with no config key to
    override it, which is why `AppVersion` has to *reject* the bundled value (see
    KNOWN-ISSUES.md). Reopen this half when there is a signing pipeline.
  - **Still open: CHANGELOG.md.** The tag annotations carry release notes today,
    which is a record but not a browsable one.
- [x] **M38** · release · the only visible version string is hardcoded "v0.3.5", three releases stale · `Sources/VinodexUI/DeviceBackPlate.swift:11` → single version source read by the back plate (and DiagnosticsReport)
  - **Resolved @0a446d3.** New `AppVersion` (VinodexCore) reads `CFBundleShortVersionString`; the back plate renders `AppVersion.display`.
  - **Regressed and re-fixed at v0.4.3.** Reading the plist first was the bug: xtool
    stamps `1.0.0`, the guard only rejected `"1.0"`, so the back plate showed
    `v1.0.0` on every build from @0a446d3 until the merge. `AppVersion.placeholders`
    now rejects build-tool defaults and `AppVersionTests` pins it.

**Pipeline**

- [ ] **M40** · pipeline · icons fetched live from api.iconify.design with no version pin — non-reproducible and network-dependent · `scripts/rasterize-icons.sh:56` → vendor the SVGs or pin @iconify-json
  - **Since audit:** narrowed by `fb5dcf2` — the flag half is fixed (`pixelflags/` is committed and the script defaults to it); the live iconify fetch remains.
- [x] **M41** · pipeline · nothing verifies committed JSON matches generator output (four divergent historical versions already in pack history) · `Sources/VinodexCore/Resources/entries.json` → stamp the source SHA into outputs and add a verify-data regen-and-diff step
  - **Resolved @0a446d3.** CI's `data` job runs `npm run generate` and fails on `git diff` against `Sources/VinodexCore/Resources` (icons/PNGs excluded, since they need network). The regen-and-diff gate now exists; explicit source-SHA stamping was not needed.
- [x] **M43** · portability · rasterize-icons.sh fails on macOS (GNU-only `mktemp --suffix`, apt-only dependency hint) · `scripts/rasterize-icons.sh:54` → portable mktemp pattern plus a brew hint
  - **Prepped (`audit-fixes`).** `mktemp "${TMPDIR:-/tmp}/vinodex-icon.XXXXXX"` (no GNU `--suffix`); the missing-tool hint now names both `apt install librsvg2-bin` and `brew install librsvg`.

## Low — open

**Code quality & dead code**

- [ ] **L1** · consistency · bookmark ids rebuilt from string literals `"COUNTRY_\()"`/`"STATE_\()"` instead of SavedItem prefixes — a prefix change strands saved places · `CountryScreen.swift:28` + `StateScreen.swift:27` → use `SavedItem.country(name).storageID`/`.state(name).storageID`
- [ ] **L2** · magic-string · main-screen behavior keyed on `title == "VINODEX"` — breaks silently if the home title changes · `Sources/VinodexUI/DeviceChassis.swift:58` → pass an explicit isRoot flag from RootView
- [x] **L3** · ux-state · the daily-grape reveal resets on every visit (plain @State) though `DailyPick.isSameDay` was built to persist it · `Sources/VinodexUI/DailyGrapeScreen.swift:16` → persist last-revealed date and initialize revealed from it
  - **Resolved (redesigned) @0a446d3.** The feature became a repeatable cursor-based guessing game (`DailyPick.RevealCursor`); per-visit reset is now intended. `DailyPick.isSameDay` is vestigial (test-only) — a candidate for L4-style dead-code removal.
- [x] **L4** · dead-code · textSection, WineEntry.iconTint, Palette.chip(country:) have no callers (and isSameDay is test-only pending L3) · `EntryDetailScreen.swift:567` + `DexIcon.swift:100` + `WineDatabase.swift:99` → delete (or wire isSameDay via L3)
  - **Narrowed @0a446d3.** `Palette.chip(country:)` now has a caller (ScannerScreen) — keep it. Still dead: `textSection` (EntryDetailScreen) and `WineEntry.iconTint` (DexIcon); `DailyPick.isSameDay` is now also dead per L3. Delete those three.
- [x] **L5** · stale-docs · comments still describe the retired 30-entry starter dataset, plus UTF-8 mojibake ("â€”") · `WineDatabase.swift:324` + `DexTheme.swift:430` → update comments to full-dataset reality and fix the em-dash
- [x] **L6** · stale-docs · the continent MARK comment contradicts the code below it (claims "no glyph"/SF Symbol while generated glyphs are used) · `Sources/VinodexUI/EntryVisual.swift:220` → rewrite to describe current behavior
- [ ] **L9** · access-control · many VinodexUI types are public but never used outside the module (CatalogScreen, IconLoader, FlowLayout, StatBar, …) · `Sources/VinodexUI/CatalogScreen.swift:12` → demote to internal except what VinodexApp imports
- [ ] **L10** · lifecycle · GlobeModel's CADisplayLink is invalidated only in onDisappear — a skipped callback leaves it firing forever · `Sources/VinodexUI/RetroGlobeScreen.swift:344` → invalidate in dismantleUIView/deinit as well

**Performance polish**

- [ ] **L11** · perf · four PulseGlow repeatForever animations blur shadow radius continuously on every screen, even behind the flipped plate · `Sources/VinodexUI/DeviceChassis.swift:587` → animate opacity of a pre-blurred circle and pause while flipped
- [ ] **L12** · perf · BookmarksScreen renders saved rows in an eager VStack and every name-field keystroke rebuilds the whole list · `Sources/VinodexUI/BookmarksScreen.swift:44` → LazyVStack plus a child view for the name editor
- [ ] **L14** · perf · `hasRegions(inCountry:)` re-filters and re-sorts the whole DB per country row per render · `Sources/VinodexUI/ContinentScreen.swift:145` → precompute a Set of region-origin countries once
- [ ] **L15** · perf · regionVisual runs the identical key-grape lookup scan twice (tint + iconID) per resolve · `Sources/VinodexUI/EntryVisual.swift:152` → look up once into a local
- [ ] **L16** · perf · DexFont.retro/mono run a UIFont availability probe plus a UserDefaults read on every Font construction · `Sources/VinodexUI/DexTheme.swift:264` → resolve availability into static lets at registration

**Assets & data footprint**

- [x] **L17** · assets · 21 orphan icon PNGs (7 slugs × 3 scales, ~70KB) ship unreferenced because the rasterizer never prunes · `Sources/VinodexUI/Resources/Icons` + `scripts/rasterize-icons.sh:26` → delete orphans and add a prune step
  - **Prepped (`audit-fixes`).** Deleted the 21 orphans (circle, flame, oak, shield, sparkles, lucide flag, lucide globe) and added a prune step that drops any `Icons/*.png` whose slug left the manifest.
- [x] **L18** · data · palette.json ships fields nothing decodes (flagGradients, flavorClassMeta) and Palette decodes fields nothing reads (appellationChips, continentColors) · `WineDatabase.swift:91` + `scripts/generate-ios-data.ts` → drop both sides
  - **Resolved (`audit-fixes`).** Generator strips `flagGradients`, `flavorClassMeta`, `appellationChips`, `continentColors`; the two non-optional `Palette` properties (`appellationChips`, `continentColors`) and the `emptyPalette` init were updated to match.
- [x] **L19** · data · all four JSONs are pretty-printed (2-space indent), inflating ~412KB by roughly a third · `scripts/generate-ios-data.ts:674` → emit minified (keep a --pretty debug flag)
  - **Prepped (`audit-fixes`).** Minified by default via `serialize()`; `--pretty`/`PRETTY=1` for readable output. With M4/L18, entries.json 346KB → 193KB (−44%). Verified whitespace-only by JSON.parse deep-equality.
- [ ] **L20** · assets · AppIcon.png is a barely-compressed 1024² PNG at 932KB (~⅓ of the git pack) · `AppIcon.png` → recompress losslessly (oxipng/zopflipng) and note a binary-asset policy
- [ ] **L22** · reproducibility · the xtool version used for packaging/signing is recorded nowhere · `xtool.yml` → record the known-good version as part of the release checklist
  - **Since audit:** narrowed by `fb5dcf2` — README now pins the Swift requirement (6.3); xtool remains unpinned.

**Pipeline & diagnostics**

- [x] **L23** · pipeline · a failed rsvg-convert on one scale leaves already-written variants behind — partial scale sets can be committed unnoticed · `scripts/rasterize-icons.sh:74` → render to temp names, move atomically only when all three succeed
  - **Prepped (`audit-fixes`).** Each scale renders to a `.tmp.$$` name; the three are `mv`-ed into place only if all succeed, else all are removed. (Render path not run locally — no rsvg-convert here.)
- [x] **L24** · pipeline · a missing pixelflags directory is a soft skip that still exits 0 · `scripts/rasterize-icons.sh:126` → fail hard unless SKIP_FLAGS=1
  - **Prepped (`audit-fixes`).** A missing `pixelflags/` now increments `failed` (so the run exits 1) unless `SKIP_FLAGS=1` is set explicitly.
- [ ] **L25** · pipeline · the country→slug rule is implemented twice (shell `tr` vs Swift string ops) with no shared test — divergence means a silently missing flag · `scripts/rasterize-icons.sh:110` → emit the final slug per country into icons.json and consume it on both sides
- [ ] **L26** · diagnostics · nothing checks that every icons.json id has a bundled PNG — a rasterization gap ships as the red questionmark placeholder · `Sources/VinodexUI/DiagnosticsReport.swift:23` → probe the bundle for each `unique` id and flag misses

**UI polish**

- [x] **L27** · a11y · the settings close button is a 34×34pt target · `Sources/VinodexUI/SettingsPanel.swift:77` → 44×44 frame around the 34pt visual
  - **Resolved @0a446d3.** Settings became a pushed route with no dedicated close control; it is dismissed by the chassis Back button (`DexMetrics.footerControl` = 64pt).
- [ ] **L28** · pixel-art · DexIcon omits `.interpolation(.none)` while FlagImage/LogoMark set it — glyphs blur instead of staying crisp · `Sources/VinodexUI/DexIcon.swift:54` → add `.interpolation(.none)`
- [x] **L29** · light-mode · hero panels overlay a hardcoded dark-green grid that reads heavy/busy on the light hero (4 screens) · `EntryDetailScreen.swift:113` + `CountryScreen.swift:95` + `ContinentScreen.swift:99` + `StateScreen.swift:72` → mode-aware heroGrid color on LcdMode
- [x] **L30** · light-mode · EntryDetail's hero title shadow hardcodes #006400 while sibling screens use `lcd.accent.opacity(0.55)` — reads as blur in light mode · `Sources/VinodexUI/EntryDetailScreen.swift:104` → match the siblings (also resolved by M28's extraction)
- [ ] **L32** · layout · SE-class devices still reserve the 138pt island clearance for a phantom cutout, leaving a dead gap · `Sources/VinodexUI/DeviceChassis.swift:180` → collapse clearance when safe-area top is below the cutout threshold
- [ ] **L33** · theme-discipline · inline hex palettes bypass the token system (menu tiles, statColors, markerColors) — how light-mode surfaces got missed before · `MainMenuScreen.swift:32` + `EntryDetailScreen.swift:448` + `RetroGlobeScreen.swift:216` → hoist into Dex/palette.json tokens

**UX polish**

- [x] **L34** · search · no clear button on the search field (`clearButtonMode = .never`) — queries must be deleted character by character · `Sources/VinodexUI/DexSearchField.swift:30` → `.whileEditing` (or a retro X button)
- [ ] **L35** · search · MASTER SEARCH opens without focusing the field — an extra tap on a screen whose whole purpose is typing · `Sources/VinodexUI/DexSearchField.swift:23` → autofocus option enabled for the masterSearch route
- [ ] **L36** · empty-state · StateScreen renders a bare "REGIONS" header with zero rows and no message when a state resolves empty · `Sources/VinodexUI/StateScreen.swift:116` → "NO REGIONS FOUND" empty state matching the list screens
- [ ] **L37** · consistency · the code comment says single-item removal deliberately skips confirmation, but every ✕ tap shows a confirm dialog · `Sources/VinodexUI/BookmarksScreen.swift:84` → drop the confirm (SAVE toggle is the undo) or fix the comment
- [ ] **L38** · haptics · only generic tap/select feedback exists — saves and destructive confirms get no distinct success/warning haptic · `Sources/VinodexUI/Haptics.swift:9` → add UINotificationFeedbackGenerator-backed success()/warning()
- [ ] **L39** · search · region lists never show the search bar (`showsSearch: category != .regions`), so long filtered lists can't be searched · `Sources/VinodexApp/VinodexApp.swift:118` → enable showsSearch for filtered region lists
- [ ] **L40** · battery · `isIdleTimerDisabled = true` for the app's whole lifetime — the phone never auto-locks · `Sources/VinodexApp/VinodexApp.swift:93` → make keep-awake a settings toggle
- [ ] **L41** · consistency · the locked-entry alert overlays the whole chassis, contradicting the documented in-LCD dialog convention other screens follow · `Sources/VinodexApp/VinodexApp.swift:74` → present inside the LCD content area
- [ ] **L42** · settings-copy · user-facing settings say "PAYWALL TESTING"/"SKIN TESTING" and hand every user a paywall-defeating toggle · `Sources/VinodexUI/SettingsPanel.swift:156,192` → user-language labels; move the paywall toggle to the DEV tab until real IAP

---

## Resolved

- [x] **H1** · pipeline · generate.ts imports ~20 modules from `../../src`, `../../data`, `../../constants.ts` that exist nowhere on disk, so the entire content pipeline is unrunnable and all 4 committed JSONs are unreproducible · `scripts/generate.ts:12`
  - **Resolved by `fb5dcf2`:** `shared/` vendored in-repo, generator renamed `scripts/generate-ios-data.ts` importing `../shared/*`, `npm run generate` wired up, regeneration verified byte-identical, and the publish script now validates that every relative import resolves inside the mirror.
- [x] **H3** · state · `.id(scaleRaw)` remounts the whole chassis when TEXT SIZE changes — the settings panel slams shut and all screen state is wiped · `Sources/VinodexApp/VinodexApp.swift:90`
  - **Resolved in effect by v0.3.9:** settings became a pushed route, so the panel-slam is gone and TEXT SIZE is only reachable from a screen whose route survives the remount. The `.id(scaleRaw)` hack itself remains at :90 as tech debt — replace it when tackling **M26**.
- [x] **M26** · nav · RootView renders only `path.last` — every push/pop rebuilds screens from scratch, losing search text, expanders, scroll, and globe orientation · `Sources/VinodexApp/VinodexApp.swift:110`
  - **Resolved by v0.4.1.7 + v0.4.2.1**, via the second option offered — route-keyed storage rather than a mounted stack. `SearchStateStore` already covered the searches; `ScreenStateStore` added scroll anchors and expanders in v0.4.1.7; v0.4.2.1 finished the list, taking in the scanner's questionnaire, the daily reveal's held pick, the settings panels' scroll and the globe's orientation. RootView still renders only `path.last` — nothing user-visible depends on that any more. The `.id(scaleRaw)` remount noted under **H3** stays as tech debt, and is now harmless for the same reason: a remount rereads the stores.
- [x] **M39** · pipeline · the regeneration command exists only in shell history (no package.json, no pinned runner; `.generate.mjs` gitignored) · `.gitignore:2`
  - **Resolved by `fb5dcf2`:** package.json with `npm run generate`/`npm run icons` via ts-node, documented in README. Residual nit: dep ranges without a lockfile or `.nvmrc`.
- [x] **M42** · docs · no README/Makefile — the xtool/WSL build, Linux test loop, syslog diagnostics, and two-script pipeline live only in scattered code comments · `Package.swift:6`
  - **Resolved by `fb5dcf2`:** README.md covers layout/build/test/regeneration with required runtimes, KNOWN-ISSUES.md is a full deploy/debug runbook, npm scripts serve as the task entry points.
- [x] **L7** · stale-docs · generate.ts header claims it "emits two files into native/Resources/Data" — it writes four into Sources/VinodexCore/Resources · `scripts/generate.ts:4`
  - **Resolved by `fb5dcf2`:** the renamed `generate-ios-data.ts` header now lists all four outputs and the real destination.
- [x] **L8** · dead-code · ~50 lines of retired starter-selection machinery survive as comments and an unused constant · `scripts/generate.ts:105`
  - **Resolved by `fb5dcf2`:** the block is now live documented code — `CURATED_SELECTION` is exported with rationale as the one-line revert path, and survives the new tsconfig's noUnusedLocals.
- [x] **L13** · perf · `results` computed property evaluated twice per body (isEmpty check + ForEach) — the full query runs 2× per keystroke · `Sources/VinodexUI/EncyclopediaListScreen.swift:49`
  - **Resolved by v0.3.9:** `results` is now @State recomputed once per query via `task(id:)`.
- [x] **L21** · git-hygiene · .gitignore misses .DS_Store (one already untracked-dirty) and .swiftpm/ · `.gitignore`
  - **Resolved by `fb5dcf2`:** .gitignore now covers .DS_Store, .swiftpm/, node_modules/, DerivedData/ and more, plus a .gitattributes normalizing line endings and marking binaries.
- [x] **L31** · affordance · the cross-link arrow on header tiles is 8pt at ~2.2:1 on the light page — tappable tiles look inert · `Sources/VinodexUI/EntryDetailScreen.swift:29`
  - **Resolved by v0.3.9:** the corner arrow was replaced with a rounded `lcd.accent` outline around the whole tile.

---

## Update log

**2026-07-30 — position check @ v0.6.2.** Five feature batches
(v0.5.8 → v0.6.2) landed since the last reconciliation; none deliberately
targeted audit IDs, so **the open set is unchanged at 52** — but line numbers
have drifted far from `fb5dcf2` (search the quoted symbols, per the note
above). Context that touches open items:

- **M12 (won't-fix)** still stands, but the tuning moved: 0.6.2 doubled
  `PixelOutline`'s shadow offsets to a full point and trimmed AA fringe on the
  rasterized glyphs — the runtime-tintable approach is still the keeper.
- **M37** — CHANGELOG.md remains open; tag annotations still carry the notes.
  Tags now run through v0.6.2.
- **M30** grew: `EntryDetailScreen` and `DeviceChassis` gained more types
  (key-grape bar, title bump, stamps). The split is more worthwhile, not less.
- **M33** narrowed slightly: `.type`'s DUAL branch and `.system`'s
  style-class inference gained behavior in 0.6.2 and are still untested.
- New surfaces worth an a11y/perf glance when their workstreams run:
  `GrapeSpriteLoader` (per-sprite pixel pass, cached), `OutlineDotPlacer`
  hints, the chip-filter countries rows, and the scanner taxonomy tiles.
- The prioritized next-sittings pick from this set now lives in
  [../PLAN.md](../PLAN.md).

**2026-07-29 — Swift batches on `audit-fixes`.** Landed the low-risk Swift work
(reviewed for compile-safety by a Swift-savvy pass, since the working environment
had no toolchain; CI `swift test` is the gate). Resolved: **M4 + L18** (finished —
deleted the unused `EntryCommon`/`Palette` properties and stripped all nine fields
from the generator; entries.json 346KB → 175KB), **M13 M14 M15 M44 L29 L30 L34**
(light-mode & contrast: new `onAccent`/`heroGrid` tokens, token swaps, live
SCREEN-MODE repaint, clear button), **H10 M19 M25** (a11y: chassis labels, modal
alerts, 44pt target), **L4** (dead `iconTint`/`textSection`), **L5 L6** (stale
comments + mojibake), **M1** (corrupt `tiers.json` now recorded, not silently
unlocking). Partial: **L16** (font-availability now cached in static lets; the
per-call `TextScale` UserDefaults read remains). Deliberately **not** attempted
here (want a compiler/device): **H2** (element-wise decode), **M2**, the
architecture refactors (**M26–M31**), the perf rewrites (**M5 M8 M9 M11**, **L10
L11 L12**), **H6/H11**, and **L33**.

> Superseded at v0.4.3: **M26** was closed by the `screen-state` chain, which had
> the compiler and device this pass lacked. The rest of that refactor range
> (**M27–M31**) is still open.

**2026-07-29 — pipeline prep on `audit-fixes`.** Verifiable data/pipeline items
prepped locally (no Swift toolchain in that environment, so Swift items are held
for a CI-gated pass). Fully done: **M43, L17, L23, L24, L19**. Partly done (pipeline
half; Swift half held): **M3** (generator `validateOutputs()` schema self-check),
**M4** (stripped `grapeCard`/`grapeRarityTier`, −19% on entries.json), **L18**
(stripped `flagGradients`/`flavorClassMeta`). Verified by regeneration +
deep-equality diff, `tsc --noEmit`, `bash -n`, and a negative test of the
self-check.

**2026-07-29 — reconciled @ `0a446d3`.** The file had been restored from a
snapshot predating v0.4.1 (`30af72b`) and v0.4.1.5 (`885a62f`), so its checkboxes
lagged the code. Every open item was re-verified against HEAD by reading the
current source (audit line numbers are pinned to `fb5dcf2` and were ignored in
favour of the quoted symbols). Result: **87 → 74 open.**

- **Resolved in code, now checked off (13):**
  - **H4** — `LinkedRow` reads `resolved ? lcd.text : lcd.disabledText` (EntryDetailScreen).
  - **H5** — profile/saved-place/state/country titles use `lcd.text` / `lcd.disabledText`.
  - **H7** — `FlagSwatch` takes `width`/`height`; all 9 callers drop outer `.frame` overrides.
  - **H8** — master-search list is a `LazyVStack`; `results` recomputed once via `.task(id:)`.
  - **H9** — `WineDatabase` builds `byID` / `byName` / `byNameAnyCategory` in init.
  - **M10** — `FlagLoader` `@MainActor` cache mirrors `IconLoader`.
  - **M16** — globe uses `DexScreenBackground` + `isLight` scene rebuild.
  - **M22** — the UNLOCK button now grants a real entitlement (`AccessStore.grant`).
  - **M38** — the back plate reads `AppVersion.display`, not a literal.
  - **M41** — CI `data` job regenerates from `shared/` and fails on drift.
  - **L27** — the 34pt settings close button is gone; dismissal is the 64pt chassis Back.
  - **L3** — daily reveal was redesigned into a repeatable cursor game; per-visit reset is now intended (`DailyPick.isSameDay` is vestigial).
  - **L4 (part)** — `Palette.chip(country:)` now has a caller (ScannerScreen); `textSection` and `WineEntry.iconTint` are still dead → L4 stays open for those two.
- **Reclassified won't-fix (1):** **M12** — PixelOutline keeps the eight-shadow approach on purpose (runtime tinting).
- **Partials worth noting (still open):** **H2** (decodeErrors + diagnostics exist; array decode still all-or-nothing, no DexAlert), **M5** (per-render recompute fixed; pre-folded haystack + debounce not), **M8** (cheap measure formula in; caching + flip-pause not), **M23** (moved to the TOOLS hub but still behind the cog), **L42** (labels fixed to ACCESS/CUSTOMIZATION; the free-tier toggle is still user-reachable, not DEV-only).

**2026-07-28 — re-verified @ `fb5dcf2`.** Two commits landed after the audit ran;
every touched item was re-checked against HEAD and all line references re-pinned.

- `fb5dcf2` *(self-contained repo: `shared/`, `pixelflags/`, docs, npm tooling — the data files the audit found missing)* — resolved **H1, M39, M42, L7, L8, L21**; narrowed **M40, M41, L22, L24**.
- `3e2c0d3` *(v0.3.9: settings screen, light-mode text, search perf)* — resolved **H3, L13, L31**; narrowed **H4, M5, M14**; **M13** is now latent-only; added **M44**, a new dark-mode contrast regression introduced by the same commit.

**2026-07-28 — audit run @ `8b3fcb2` (v0.3.8).** Eight dimensions: DevOps/process,
performance, optimization, architecture, code quality, UI, UX, workflow. 141 raw
findings. Every critical/high candidate was adversarially re-verified against the
code — 17 confirmed, 5 downgraded, 0 rejected — and cross-dimension duplicates
merged, giving **96 items: 0 critical · 11 high · 44 medium · 41 low**. M44 was
added later, bringing the total to 97.
