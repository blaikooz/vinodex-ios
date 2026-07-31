# Vinodex Audit — 2026-07-28

A work order, not a report. Every item below is a specific, located defect with a
proposed fix. Work through them in any order; check them off as they land.

**IDs are permanent.** Reference them in commits and PRs as `H3`, `M12`, `L27` —
they never get renumbered, even as items are resolved.

## Status

**57 resolved · 1 won't-fix · 49 open**

Re-verified item-by-item against `b48ad20` (v0.6.3) on 2026-07-31. Every open item
was re-read against current source — the `fb5dcf2` line anchors were ignored in
favour of the quoted symbols — and every claimed resolution was challenged by a
second, adversarial pass before being checked off. Results: **5 closed** (H2 H6 M9
L15 L41), **15 measurably worse** than when the audit ran, **10 partially done**,
and **8 new items** (H12, M45–M48, L43–L45) raised from findings the original eight
dimensions did not reach. Earlier reconciliations (`0a446d3`, v0.4.3, v0.6.2) are
in the update log.

**Since that pass:** the whole Performance row bar **M11**, plus both Data &
robustness items that were partially done — **M2 M3 M5 M6 M7 M8** closed
together, 2026-07-31. See the update log.

**Then 0.6.4 emptied the High row**, closing the last two — **H11** (collapse the
two multiplied text axes into one app-owned axis; symmetric font fallback; no
sub-10pt literals) and **H12** (`art/` reconstructed by re-foldering
`shared/newicons`, which turned out to be the surviving source rather than a
superseded copy — so 254 of 254 drawn assets now regenerate). Both raised
follow-ups instead of overclaiming: **M49** owns the type *range* H11 narrowed
but deliberately did not widen, **M50** a search-field sizing bug H11 surfaced.

| Severity | Open | Resolved | Won't-fix | Total |
|---|---:|---:|---:|---:|
| Critical | 0 | — | — | 0 |
| High | 0 | 12 | — | 12 |
| Medium | 24 | 25 | 1 | 50 |
| Low | 25 | 20 | — | 45 |
| **Total** | **49** | **57** | **1** | **107** |

Open items by workstream — each row is roughly one sitting's worth of related work:

| Workstream | Open | Items |
|---|---:|---|
| UI & UX polish | 13 | M17 M23 M24 · L28 L32 L35 L36 L37 L38 L39 L40 L42 L43 |
| Architecture & code quality | 10 | M27–M31 · L1 L2 L9 L10 L45 |
| Performance | 5 | M11 · L11 L12 L14 L16 |
| Accessibility | 7 | M18 M20 M21 M48 M49 M50 · L44 |
| Release & licensing | 5 | M35 M36 M37 · L20 L22 |
| Data & robustness | 2 | M45 M46 |
| Pipeline & reproducibility | 3 | M40 · L25 L26 |
| Tests & CI | 3 | M32 M33 M47 |
| Light mode & contrast | 1 | L33 |

**Worse than when the audit ran.** Fifteen items grew between v0.3.8 and v0.6.3 —
none deliberately, all by the catalog tripling and eight screens landing on top of
unfixed foundations. Ranked by how much they grew:

| ID | Then → now |
|---|---|
| **L33** | 72 → 205 inline hexes, 11 → 17 files (every new screen shipped its own tile palette) |
| **H11** | 80 → 194 `DexFont` call sites, 7 → 10 sub-10pt labels, still no Dynamic Type cap — *since fixed; the range is now M49* |
| **L20** | tracked binaries 2.8 MB → 35.6 MB (30 MB of it *source* art, not superseded — see H12) |
| **L38** | 32 → 78 haptic call sites, and the quiz's correct/wrong branch is exactly the missing case |
| **M27** | 13 → 21 `WineDatabase.shared` reads — and it escaped into Core |
| **M24** | blanket transaction now nulls 17 `withAnimation` calls, not 2 |
| **M35** | orphan-on-bundle-ID-change data 5 → 17 keys plus an Application Support file |
| **M30** | EntryDetailScreen 747 → 1067 lines, DeviceChassis 710 → 978 |
| **L9** | 48/30 → 72/42 public-but-app-unreferenced types |
| **M5** | 1 → 3 screens paying the un-debounced search, two of them per body pass — *since fixed, all three* |
| **M28** | SAVE copies 2 → 3, section headers 4 → 6, four visual treatments shipping |
| **M23** | 1 → 2 invisible daily-return features, plus the streak |
| **L26** | unguarded asset surface 1 → 5 directories |
| **L12** | keystroke-rebuilt subtree gained a 20-well recently-viewed strip |
| **M20** | globe gained a second mount (scanner) with *no* non-globe path to a continent |

**No critical items, and no High ones.** Nothing crashes, corrupts data, or
breaks the build today. The all-or-nothing database decode (**H2**) that held
this spot is fixed, and 0.6.4 closed the last two Highs — **H11** and **H12**.
The closest call left is **M46**, the two remaining whole-file decodes that H2's
fix did not cover.

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

The `file:line` reference in each item's one-line body is pinned to `fb5dcf2` and
is now badly stale — the app went from v0.3.8 to v0.6.3 under it. **Use the
`Now at:` anchor in the sub-bullet instead**, which is re-pinned to `b48ad20`
(2026-07-31). Either way the file and symbol names are the durable part; if a line
number misses, search for the quoted symbol.

---

## High — all closed

- [x] **H2** · robustness · entries.json decodes all-or-nothing — one malformed entry empties the whole database with no user-facing signal (already happened once, per generate.ts:601) · `Sources/VinodexCore/WineDatabase.swift:249` → decode element-wise via failable wrapper, keep good entries, surface decodeErrors with a DexAlert
  - **Resolved @b48ad20** (v0.6.3 "robustness spine"), both halves, and challenged
    without being refuted. `private struct FailableEntry: Decodable` has a
    non-throwing `init(from:)` that try/catches `WineEntry(from:)` and names the
    culprit via an `IdentityKeys` container; `decodeEntries(from:)` returns
    `(entries, failures)`; the real bundled load path uses it and seeds
    `decodeErrors`. User-facing: `showingDataAlert` seeds from `decodeErrors` and
    renders a `DexAlert("DATA LOAD ERROR")` inside the LCD, plus a list-screen
    error state and the DEV readout. Four regression tests pin it.
  - Now at: `WineDatabase.swift:400` (FailableEntry), `:441` (decodeEntries),
    `:451` (call site) · `VinodexApp.swift:28,109` · `DecodeRobustnessTests.swift:25`
  - Scope note: entries.json only — palette/icons/countries are now **M46**.
- [x] **H4** · light-mode · LinkedRow titles hardcode `resolved ? .white : Dex.stone600` on `lcd.surface` (#FFFFFF in light) — NOTABLE GRAPES/REGIONS and FLAVOR PROFILE rows still invisible in light mode · `Sources/VinodexUI/EntryDetailScreen.swift:706` → replace with `lcd.text`/`lcd.subtext` (thread LcdMode into LinkedRow)
  - **Resolved @0a446d3.** `LinkedRow` now reads `resolved ? lcd.text : lcd.disabledText`, with `lcd` threaded in via `@AppStorage(LcdMode.storageKey)`.
- [x] **H5** · light-mode · profile name, saved-place, state-row, and country-row titles hardcode `.white` on `lcd.surface` — invisible in light mode · `BookmarksScreen.swift:149,226` + `CountryScreen.swift:278` + `ContinentScreen.swift:162` → swap to `lcd.text` (`lcd.subtext` for unwritten states)
  - **Resolved @0a446d3.** Bookmarks profile/saved rows and the state/country titles use `lcd.text`; `ContinentScreen` uses `hasRegions ? lcd.text : lcd.disabledText`.
- [x] **H6** · assets · IconLoader never picks @2x/@3x — every glyph upscales from the 64px @1x (visibly soft app-wide) while 212 hi-res variants ship as dead payload · `Sources/VinodexUI/DexIcon.swift:24` → load the scale-matched variant via `UIImage(data:scale:)` (or stop shipping unused scales)
  - **Resolved @b48ad20** (v0.6.3 "icon crispness"). `IconLoader.init` resolves
    `preferredScale` once from `UITraitCollection.current.displayScale`, and
    `load(slug:)` walks down `@3x → @2x → @1x` loading via
    `UIImage(data:scale:)`, so the point size is preserved and a missing variant
    degrades gracefully. The 132 hi-res PNGs are no longer dead payload.
  - Now at: `DexIcon.swift:17` (init), `:52` (load walk-down), `:57`
    (`UIImage(data:scale:)`) · `Resources/Icons` = 66 base + 66 @2x + 66 @3x
  - **Not covered:** the other art sets (ClassArt, FlavorArt, GrapeArt, StyleArt,
    Flags, Chassis, Maps) ship @1x only and still load via
    `UIImage(contentsOfFile:)`. Those are the *largest* images in the app. Fold
    into the **L28** pass or raise separately if the softness is visible.
- [x] **H7** · layout · FlagSwatch hardcodes its internal 52×32 frame, so re-framed callers draw broken chrome (96×60 heroes float, 40×26/48×32 rows overflow their strokes) · `Sources/VinodexUI/EntryDetailScreen.swift:739` → add width/height params and drop callers' outer `.frame` overrides
  - **Resolved @0a446d3.** `FlagSwatch` takes `width`/`height` (default 52×32) and frames itself; all 9 call sites pass explicit sizes with no outer `.frame` override.
- [x] **H8** · perf · master-search list is an eager ScrollView+VStack — all 284 rows (icon resolve + flag decode + chips) built at once and rebuilt per query change · `Sources/VinodexUI/EncyclopediaListScreen.swift:60` → LazyVStack
  - **Resolved @0a446d3** (v0.4.1). The list is a `LazyVStack` and `results` is recomputed once per query via `.task(id:)`.
- [x] **H9** · perf · `entry(named:)`/`entry(id:)` are O(n) scans re-running Unicode folding per candidate, called per-row per-render (~20k+ foldings per list pass) · `Sources/VinodexCore/WineDatabase.swift:327,318` → precompute `[normalizedKey→entry]` and `[id→entry]` dictionaries in init
  - **Resolved @0a446d3** (v0.4.1). `WineDatabase.init` builds `byID`, `byName` (per-category) and `byNameAnyCategory`; both lookups are now hash lookups.
- [x] **H10** · a11y · Back/Home/Saved chassis buttons have no accessibilityLabel (Saved announces as a person icon) — primary navigation unlabeled for VoiceOver · `Sources/VinodexUI/DeviceChassis.swift:428` → add `.accessibilityLabel` per ChassisButton kind, matching the settings cog
- [x] **H11** · a11y · Dynamic Type strategy is incoherent: `Font.custom(_:size:)` auto-scales with system text size while every layout metric is a fixed literal and no cap is set — accessibility sizes blow out tiles/marquee/chips, and 8–9pt base labels sit below the HIG floor · `Sources/VinodexUI/DexTheme.swift:264` + `VinodexApp.swift:59` → either cap at the root and use `fixedSize` fonts (relying on in-app TEXT SIZE), or adopt `relativeTo` + ScaledMetric layouts; raise the 8–9pt floors
  - **Resolved 0.6.4**, via the first option — one app-owned axis rather than two
    multiplied together. All three obligations, in order:
    - *(a) coherent strategy.* `DexFont.retro/mono` build with
      `Font.custom(_:fixedSize:)`, so system Dynamic Type no longer reaches the
      app's type at all; `RootView` pins `.dynamicTypeSize(.large)` as a guard
      against a future stock-SwiftUI font reintroducing the second axis. The
      user-facing control is SETTINGS > TEXT SIZE, and `TextScale` gains a third
      step — **HUGE (1.15)** — because pinning the system control while the
      in-app one topped out at as-drawn would have left a low-vision user with
      strictly less than they had.
    - *(b) the asymmetry.* Gone by construction, not by matching two mechanisms:
      `fixedSize:` makes the primary path behave exactly like the `.system(size:)`
      fallback, so a CoreText registration failure now changes the typeface and
      nothing else.
    - *(c) the floors.* All ten sub-10pt call sites raised to 10, and
      `TypeScale.nominalFloor` clamps anything below it so a new one cannot be
      added silently. A CI grep holds the line the unit tests cannot see.
  - **The residual, stated rather than papered over.** The app's type range is
    now 0.85–1.15 against the system's 0.82–3.12. Vinodex is *not* a Dynamic Type
    app and must not claim to be one in App Store metadata. What did improve: the
    smallest label went 6.8pt → 8.5pt at the default step and 11.5pt at HUGE, the
    axis can now go *above* as-drawn for the first time, and a first-launch seed
    (`TextScale.seedIfUnset`) starts someone whose system text is already
    enlarged at a matching step instead of at SMALL. Closing the rest is **M49**.
  - **Note the floor is nominal, not rendered.** At SMALL (0.85, the shipped
    default) a 10pt nominal draws at 8.5pt, still under Apple's 11pt guidance. A
    rendered floor would clamp every call site up to `retro(12)` — 41 more — and
    nothing in this project can check what that does to a layout. Also **M49**.
  - Now at: `Sources/VinodexCore/TypeScale.swift` (floor + steps + seed) ·
    `DexTheme.swift:347` (`resolvedSize`), `:357`/`:372` (retro/mono) ·
    `VinodexApp.swift:157` (pin), `:163` (seed) · `TypeScaleTests.swift`
  - **Needs a device.** Everything above is either Linux-tested arithmetic or a
    provable no-op, *except* the HUGE step, which no automated check in this repo
    can see. Worth a look at HUGE on a 375pt screen: `WalkthroughScreen`,
    `DailyGrapeScreen`, `DexAlert` and `RatingPrompt` have no scroll escape, and
    `CatalogScreen`'s 96pt `StatBar` label frame is the tightest fixed box in the
    app. All four are *safer* than before — they previously scaled to ~3.1x — but
    safer is not verified.
  - Corrections to this entry's own figures, measured at `b48ad20`: **194** call
    sites, not 191 (193 literals + one variable at `DeviceChassis.swift:901`);
    the stale anchors `DexTheme.swift:264` and `VinodexApp.swift:59` pointed at a
    doc comment and a closing brace.
- [x] **H12** · pipeline · the drawn-art source tree does not exist — `README.md:173` and all five art scripts resolve sources from `art/icons/`, but `ls art` at HEAD is "No such file or directory", so the **94 bundled `art:` glyphs (~2.8 MB) cannot be regenerated**; meanwhile 30 MB of the superseded `shared/newicons/` layout the scripts themselves call replaced stays tracked · `scripts/import-flavor-art.py:19` + `import-style-art.py:4` + `import-class-art.py:4` + `import-grape-art.py:4` + `key-background.py:21` + `rasterize-icons.sh:14` → restore `art/` (or re-point the scripts and README at the real source), then drop `shared/newicons/`
  - **Resolved 0.6.4.** `art/` was never in this repo's history, so nothing could
    be "restored" — but the art was not lost either. `shared/newicons/` was never
    a superseded predecessor; it is the *same* art in the pre-0.5.8 drop-folder
    layout, and `art/icons/**` was only ever a re-foldering of it that nobody
    performed here. So the fix is that re-foldering: all 271 files `git mv`d into
    the per-use layout the five scripts already address, **not one line of
    path-resolution logic changed**. `ls art` now succeeds and all 94 `art:`
    glyphs regenerate.
  - **Measured, end to end.** `npm run icons:verify` re-runs the four importers
    into a temp tree and compares against the committed bundle: **244 of 254
    pixel-identical, 10 within a recorded budget, 0 changed, 0 without a source.**
    Getting the last of that took four things worth naming:
    - four sources chroma-keyed via the already-committed `key-background.py`
      (cherry, blackcherry, body/full, body/medium) — the only assets that did
      not reproduce from an un-keyed source. `key-background.py`'s docstring now
      lists exactly those four, which nothing recorded before;
    - the three `gold-*-rare` bunches added to `SOURCE_TO_STEM`, which was
      producing 30 stems against a bundle shipping 33 while `icons.json`
      referenced all 33 live;
    - the five hand-recoloured masters (2 style, 3 grape) promoted to tracked
      sources and copied **verbatim** by a new `MASTERS` passthrough. Re-importing
      them is lossy — it moves 62% and 49% of the two style portraits' opaque
      pixels — so the pipeline must not reprocess them;
    - the 10 residual files given per-file budgets in `scripts/verify-art.py`.
      Their sources carry 12k–27k distinct colours, so `quantize(colors=256)` is
      genuinely lossy for them and different Pillow builds resolve the palette a
      few pixels apart. Visually identical, not byte-reproducible.
  - **Byte-identity is deliberately not the gate**, and the bundle was *not*
    re-baselined. 0 of 249 are byte-identical today (palette order, plus PNG
    bytes tracking whichever deflate the Pillow wheel links — 12.3 bundles
    zlib-ng), so a `git diff --exit-code` gate would be red on a clean tree for
    reasons unrelated to the art. Re-cutting the baseline to fix that would have
    silently changed visible pixels on ten shipped glyphs, three of them inside
    the 94 this item names. Pixels are the gate; `scripts/requirements.txt`
    records the Pillow version as hygiene, not as a load-bearing pin.
  - **Loud on failure**, which it was not before: a shared `resolve_source_dir()`
    replaces four copies of `no source dir found; pass it explicitly` (a message
    naming neither the path nor the remedy) with the absolute path it wanted and
    what to do; `rasterize-icons.sh` preflights Pillow and `art/` *before* the
    network rasterize but without aborting the Iconify/flag half, which still
    works on a machine with no Pillow; and `SKIP_ART=1` finally announces itself
    the way `SKIP_FLAGS=1` always did.
  - **Correction: `shared/newicons/` was not dropped, and must not be.** This
    item's remedy assumed it was dead weight superseding `art/`. It was the
    opposite — the only surviving copy of every drawn source, plus one genuinely
    sole-copy audio master (`buttontap.mp3`, the 25,389-byte original of the
    4,653-byte bundled trim). So the 84% figure is arithmetically right and its
    conclusion is wrong: this is a **rename, not a payload win**, and **L20 gains
    nothing here**. L20's real levers are now `art/icons/reference/` (9 contact
    sheets, 11.7 MB), `art/icons/attic/` (8 unreferenced icons, 849 KB) and
    lossless recompression — all policy calls, none of them free.
  - **Correction: "~2.8 MB" is wrong by ~4x.** The 94 `art:` glyphs are 718,466 B;
    all four drawn-art directories together are 254 files / 2,325,894 B. The
    2.8 MB is L20's repo-wide tracked-binary baseline at `0a446d3`, mis-carried.
  - The per-use folder split is load-bearing and easy to lose: `chalk.png`,
    `earth.png`, `game.png` and `orange.png` each exist twice under `art/icons/`
    as different art. Only the folder decides which one a stem gets — flatten it
    and `soil-chalk` / `subclass-earth` / `subclass-game` / `color-orange`
    silently start shipping the flavour drawing. Recorded at
    `import-class-art.py:35`. This is also why "re-point the scripts at the flat
    tree" was the wrong branch of the remedy.
  - Now at: `art/icons/**` (271 moved + 5 masters) · `art/sfx/` ·
    `scripts/art_common.py` (resolver, passthrough, `ART_OUT`) ·
    `scripts/verify-art.py` · `scripts/requirements.txt`

## Medium — open

**Data & robustness**

- [x] **M1** · robustness · tiers.json decoded with `try?` — a corrupt manifest silently unlocks the entire paywall and never reaches decodeErrors · `Sources/VinodexCore/WineDatabase.swift:253` → do/catch distinguishing file-missing (unlock) from decode-failure (log to decodeErrors)
- [x] **M2** · ux-state · a DB decode failure shows a normal menu plus "NO DATA FOUND" (reads as a no-results message), truth visible only in the DEV tab · `Sources/VinodexCore/WineDatabase.swift:260` + `EncyclopediaListScreen.swift:123` → explicit "DATA LOAD ERROR" state when decodeErrors is non-empty
  - **Mostly resolved @b48ad20**, but the challenge pass found the error state is
    gated on `&& search.isEmpty` — and `SearchStateStore` persists queries across
    navigation, so the *suppressed* path is exactly the one that produces the
    reported symptom. **Remaining: drop the `search.isEmpty` gate.**
  - Also still unguarded: `DailyGrapeScreen` shows "NOTHING TODAY" and
    `ChipFilterScreen` "NOTHING MATCHES" on an empty database.
  - **Resolved.** The gate is gone; the query no longer decides whether an empty
    screen is a fault or an answer. `WineDatabase.dataState` does, off the
    loader's own facts: `decodeErrors` empty → `.noResults`; errors with entries
    → `.partialLoad`; errors with none → `.loadFailed`. All three screens now
    wrap their own panel in `DexEmptyState`, one shared view rather than a copy
    per screen — shown unchanged on a healthy database, footnoted with SOME
    RECORDS FAILED TO LOAD on a partial one, replaced by DATA LOAD ERROR when
    nothing decoded. That last shape is `EncyclopediaListScreen`'s old
    `dataLoadErrorState`, moved so the other two get it too.
  - Now at: `DexEmptyState.swift:27` (`dataState`), `:45` (the wrapper) ·
    `EncyclopediaListScreen.swift:169` · `ChipFilterScreen.swift:149` ·
    `DailyGrapeScreen.swift:66` · launch alert unchanged at `VinodexApp.swift:129`
- [x] **M3** · pipeline · no schema contract between generator and Swift (no version field, no validation; generator already emits keys Swift silently drops) — a TS rename ships as a whole-app decode failure · `scripts/generate-ios-data.ts:674` → emit a schemaVersion asserted at load plus a generator-side decode smoke test
  - **Partly prepped (`audit-fixes`).** `validateOutputs()` now re-reads the written JSON and asserts the shape the Swift structs require, failing `npm run generate` (and CI) on drift — positive+negative tested. Held: the `schemaVersion` field emitted-and-asserted-at-load (Swift side).
  - **Held half landed @b48ad20.** `SCHEMA_VERSION` is emitted and
    `expectedSchemaVersion = 1` is asserted at load, cross-referenced in comments
    on both sides so they get bumped together.
  - **Remaining (found by the challenge pass):** `validateOutputs` still checks
    only ~4 of ~18 non-optional entry keys, and covers none of the newer
    `flavorArt`/`grapeArt`/`styleArt`/`flavorClassIcons`/`flavorSubclassIcons`
    tables — those stayed optional on the Swift side, so a generator rename of
    any of them still degrades silently to tinted glyphs instead of failing the
    build. That is the original defect, in the fields added since the audit.
  - **Resolved.** `validateOutputs` now checks every non-optional property of
    every Swift struct it can reach, per category, from declared contract
    tables: `ENTRY_COMMON_REQUIRED` (5 keys), `ENTRY_REQUIRED` and
    `DETAILS_REQUIRED` (per category), `GRAPE_CHARACTERISTICS_REQUIRED`,
    `TASTING_NOTE_REQUIRED` for each element of a present profile, and
    `ENTRY_ENUMS` for the raw-value enums, which throw on decode rather than
    falling back. A category with no contract is itself reported, so adding a
    `WineEntry` variant cannot silently leave its fields unchecked. The five art
    tables plus `soilKeywords` are in `ICONS_REQUIRED_NONEMPTY`: required at
    generation, still optional at decode, and checked for *emptiness* as well as
    presence, since a renamed source table leaves the key there and the object
    empty — which decodes cleanly and drops every entry back to a tinted glyph.
  - Verified both ways: `npm run generate` is clean and byte-identical against
    `Sources/VinodexCore/Resources`, and eight injected drifts each fail it —
    dropped `color`, `grapeCharacteristics.acid` renamed to `acidity`, emptied
    `flavorArt`, `grapeArt` renamed, `rarity: "LEGENDARY"`, dropped
    `details.subclass`, a tasting note missing its `icon`, dropped continent
    `details.keyRegions`. Each names the offending entry by id. `tsc --noEmit`
    clean.
  - Now at: `generate-ios-data.ts:1050` (SCHEMA_VERSION), `:1069`
    (`ICONS_REQUIRED_NONEMPTY`), `:1073` (contract tables), `:1121`
    (validateOutputs) · `WineDatabase.swift:384` (expectedSchemaVersion), `:463`
    (stamp check)
- [ ] **M45** · robustness · the new schema stamp is reachable by *staleness*, not just corruption — a missing stamp appends a decode error unconditionally, so any build carrying pre-0.6.3 generated data raises the launch "DATA LOAD ERROR" alert on **every** start · `Sources/VinodexCore/WineDatabase.swift:463` → distinguish "no stamp / older data" from "wrong stamp" the way `tiers.json` distinguishes missing from corrupt, or fail the build instead of the launch
  - **New 2026-07-31.** Intentional per the doc comment, but it turns the alert
    H2 added into a false positive for anyone testing an older data snapshot.
- [ ] **M46** · robustness · H2's element-wise decode covers entries.json only — palette.json and icons.json are still whole-file all-or-nothing and drop into the empty-database fallback (alert fires, but the app is blank), and `countries.json` is swallowed **silently** by `(try? …) ?? [:]` with no decodeErrors entry at all · `Sources/VinodexCore/WineDatabase.swift:452,453,493` → give the three the same missing-vs-corrupt treatment `tiers.json` already has, and record failures in decodeErrors
  - **New 2026-07-31.** The countries case is the sharper one: it is the only
    remaining fully silent decode failure in the loader. It does not empty the
    database (country pages fall back to a derived summary), so it is Medium,
    not a re-run of H2.
- [x] **M4** · data · entries.json ships ~70KB (~20%) in never-read fields (grapeCard 47.7KB, callbacks 14.5KB, icon, grapeRarityTier) parsed at every launch · `Sources/VinodexCore/WineEntry.swift:89` → strip from generator output and delete the unused EntryCommon properties
  - **Resolved (`audit-fixes`).** Generator strips `grapeCard`, `grapeRarityTier`, `icon`, `iconCallback`, `tileCallback`; the three optional `EntryCommon` properties were deleted. entries.json 346KB → 175KB. Proven surgical by deep-equality against HEAD (nested `tastingProfile.icon` retained).

**Performance**

- [x] **M5** · perf · search runs un-debounced, re-folding every field of every entry and re-sorting per keystroke · `Sources/VinodexCore/EntryFilter.swift:171` + `DexSearchField.swift:69` → pre-folded haystack per entry, pre-sorted base list, ~200ms debounce
  - **Since audit:** narrowed by v0.3.9 — `task(id:)` stopped re-querying on unrelated re-renders; the per-keystroke fold+sort and missing debounce remain.
  - **Worse @b48ad20.** Still no debounce, no pre-folded haystack, no pre-sorted
    base list — and **three screens pay it instead of one**. `ChipFilterScreen`
    and `ScannerScreen` recompute per *body pass*, not per keystroke, so they are
    strictly worse than the list screen; `ChipFilterScreen` also backs its
    per-chip count badges off the same query.
  - The fold-once-at-load pattern this wants already exists in-tree —
    `WineDatabase` builds `byName`/`byNameAnyCategory` in init (see **H9**).
  - **Resolved, all three halves.** *Pre-folded haystack:* `WineEntry.searchFields`
    is now the single definition of what search scans, and `searchHaystack` folds
    it once and joins with a newline — a separator no query can contain, so a
    whole-string `contains` is exactly equivalent to the per-field scan. *Pre-sorted
    base list:* `WineDatabase` sorts once at load into `sortedEntries`, with
    `searchHaystacks` parallel to it; filtering a sorted array preserves order, so
    `entries(matching:)` does no sort at all. `entries(matching: ChipFilter)` reads
    the same list through `entriesInDisplayOrder`. *Debounce:* `awaitSearchDebounce`,
    180ms, shared by all three screens — skipped when either end of the transition
    is an empty query, so the keystroke that swaps an unfiltered list for a
    filtered one (or clears it) still feels immediate, while bursts within a query
    coalesce. `[WineEntry].apply(_:)` survives for callers holding an arbitrary
    array, documented as the unindexed path.
  - Per-body-pass work is gone from the two screens that had it:
    `ChipFilterScreen` holds `results`/`countryResults`/`chipCounts` in `@State`
    (chip badges re-cost on filter change only, not on typing — `body` read
    `results` three times per pass and costed three dozen chips at a full catalog
    scan each), and `ScannerScreen` holds `flavorMatches`.
  - Now at: `EntryFilter.swift:207` (searchFields), `:227` (searchHaystack) ·
    `WineDatabase.swift:317` (index), `:596` (entries(matching:)), `:612`
    (entriesInDisplayOrder) · `SearchDebounce.swift:25` ·
    `EncyclopediaListScreen.swift:127` · `ChipFilterScreen.swift:76`, `:175` ·
    `ScannerScreen.swift:224`
- [x] **M6** · perf · first frame blocks on the full DB decode plus six regions() queries via `Diagnostics.emit()` in App.init · `Sources/VinodexApp/VinodexApp.swift:9` → defer to a background task/DEBUG-only and warm the DB off-main
  - **Unchanged @b48ad20**, and still in *release* builds: six full filter+sort
    passes over 375 entries plus the whole decode, synchronously in `App.init`.
  - **Resolved.** `App.init` now kicks a detached `.userInitiated` task and
    returns. The task touches `WineDatabase.shared` — the off-main warm, which
    overlaps the decode with SwiftUI's scene setup rather than serialising behind
    it — and calls `Diagnostics.emit()` only under `#if DEBUG`. Release builds no
    longer pay the six `regions(in:)` passes at all, for output only a maintainer
    tailing `idevicesyslog` reads. `shared` is a `static let`, so whichever thread
    arrives second blocks on the same `swift_once` and the decode never runs twice.
  - Now at: `VinodexApp.swift:23` (the detached task) · `:372` (Diagnostics, doc-commented
    DEBUG-only and off-main)
- [x] **M7** · perf · CountryScreen re-runs the full-database `regions` query ~10× per body pass (states, grapes, appellations, counts) · `Sources/VinodexUI/CountryScreen.swift:40` → compute once per body/init and derive the rest
  - **Unchanged @b48ad20** structurally (same computed `regions`, same
    regionCount-in-ForEach); the per-pass cost grew with the catalog, 284 → 375.
  - **Resolved via the `init` option.** `regions`, `states`, `regionCounts`,
    `notableGrapes`, `grapeEntries` and `appellations` are stored `let`s resolved
    in `init` from one query and one walk over its result. `regionCount(in:)` —
    a `regions.filter` inside a `ForEach` — is gone, replaced by the
    `regionCounts` lookup. The page is `.id(country)`-keyed and the database is
    immutable for the life of the process, so no later pass can see anything this
    one cannot.
  - Now at: `CountryScreen.swift:69` (the stored derivations), `:86` (init) ·
    `:343` (regionCounts lookup)
- [x] **M8** · perf · MarqueeBanner re-measures text (UIFont + NSString sizing + two DexFont builds) up to 120×/s forever, even hidden behind the flipped back plate · `Sources/VinodexUI/DeviceChassis.swift:652` → cache cell/cycle/font per text change and pause while flipped
  - **Half done @b48ad20.** Measurement caching landed via the GeometryReader
    rewrite. **Remaining: pause while flipped** — the front face merely sits at
    opacity 0 — plus hoisting the per-frame `DexFont`/gap builds out of the
    closure. The idiom is already in-tree: `SettingsPanel.swift:1075` uses
    `TimelineView(.animation(paused:))`.
  - **Resolved, both remaining halves.** `MarqueeBanner` takes `paused` and runs
    `TimelineView(.animation(paused:))`; the chassis passes `showsBackFace`, not
    `isFlipped` — the front face is fully visible through the first half of the
    turn, and freezing a marquee still on screen reads as a hang, whereas
    `showsBackFace` flips at the exact instant the face goes to opacity 0.
    Paused rather than unmounted so the measured `copyWidth` survives the trip;
    the offset is a pure function of the clock, so resuming needs no stored phase.
  - `gap`, the segment `Font` and the symbol size are now stored `let`s resolved
    in `init`. Both `gap` and `DexFont.retro` read `TextScale.current`, which is a
    `UserDefaults` lookup, and the timeline closure touched them several times per
    frame — a banner nobody was looking at was hitting the defaults store hundreds
    of times a second. `DeviceChassis` is `.id`-keyed on the text scale, so a
    change rebuilds the view rather than needing the value re-read.
  - Now at: `DeviceChassis.swift:527` (`paused: showsBackFace`), `:851` (paused),
    `:875` (cached gap/font/symbolSize), `:887` (init), `:927` (TimelineView)
- [x] **M9** · perf · marquee measures at raw fontSize but renders through TextScale (1.2×) — the seam jumps/overlaps whenever LARGE text is set · `Sources/VinodexUI/DeviceChassis.swift:626` → measure at the effective rendered size
  - **Resolved @b48ad20**, challenged without refutation. The rewrite measures the
    real rendered label geometry; the raw-fontSize prediction path no longer
    exists. The remaining marquee work is M8's pause half.
  - Now at: `DeviceChassis.swift:855` (copyWidth), `:896` (cycle), `:911` (measure)
- [x] **M10** · perf · FlagImage does an uncached `UIImage(contentsOfFile:)` on every body eval (2× per shaped well) · `Sources/VinodexUI/EntryVisual.swift:314` → @MainActor flag cache mirroring IconLoader
  - **Resolved @0a446d3.** `@MainActor final class FlagLoader` caches `[String: UIImage?]`; `FlagImage` calls `FlagLoader.shared.image(for:)`.
- [ ] **M11** · perf · globe CADisplayLink runs at native refresh with a constant per-frame spin — 2× speed and 2× cost on 120Hz ProMotion · `Sources/VinodexUI/RetroGlobeScreen.swift:338` → time-based deltas plus `preferredFrameRateRange` 30–60
  - **Unchanged @b48ad20.** Needs `dt`-scaled autoSpin/velocity and
    `pow(damping, dt*60)` alongside the frame-rate range; the marker throttle
    should key off elapsed time too. Now at `RetroGlobeScreen.swift:399` (`start()`).
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
  - **Unchanged @b48ad20** and completely unaddressed: nothing in the repo
    declares `UISupportedInterfaceOrientations` and there is no runtime lock,
    while the chassis is a fixed portrait stack with a hard 138pt island band.
    One key in `xtool.yml` — verify xtool actually threads it into the Info.plist.
- [x] **M44** · contrast · selected-option labels in the SYSTEM screen changed from `.black` to `.white` on an `lcd.accent` fill — in dark mode the accent is #4ADE80 mint, so the selected tab/skin/screen-mode/text-size buttons are white-on-mint at ~1.8:1 (was ~12:1) · `Sources/VinodexUI/SettingsPanel.swift:98,224,262,288` → add a per-mode `lcd.onAccent` token (dark → .black, light → .white) and use it for all selected states
  - **Since audit:** new — this is a regression introduced by v0.3.9, not an original finding.

**UX & accessibility**

- [ ] **M18** · a11y · `accessibilityReduceMotion` is checked nowhere — marquee, PulseGlow, globe autospin, and the 0.7s flip are all unstoppable · `Sources/VinodexUI/DeviceChassis.swift:652` → honor the environment flag (static marquee, frozen glow, no autospin, cross-fade)
  - **Unchanged @b48ad20** — the flag is still checked nowhere in the tree, and
    the motion added since is unguarded too. One useful narrowing: `PulseGlow`
    (`DeviceChassis.swift:810`) is the **only** `repeatForever` animation in the
    whole codebase, so **L11** and this item overlap almost entirely.
- [x] **M19** · a11y · DexAlert dialogs are not VO-modal — focus escapes into obscured content and scrim-tap-to-cancel has no accessible equivalent · `Sources/VinodexUI/DexAlert.swift:36` → `.accessibilityAddTraits(.isModal)` on the dialog card
- [ ] **M20** · a11y · continent selection needs taps on continuously moving markers plus a drag for rear continents — impossible under VoiceOver · `Sources/VinodexUI/RetroGlobeScreen.swift:355` → pause autospin at rest / add a static continent-list fallback
  - **Worse @b48ad20.** Autospin is still unconditional and rear continents still
    need a drag — and it gained a second mount: the scanner's globe step
    (`ScannerScreen.swift:386`) reuses the screen with the world-search list
    fallback switched **off**, so that instance has *no* non-globe path to a
    continent at all.
  - Now at: `RetroGlobeScreen.swift:418` (unconditional autoSpin), `:100` (markers)
- [ ] **M21** · a11y+discoverability · the device flip is an unhinted 2s long-press on a non-button orb; the back plate is unreachable via VoiceOver · `Sources/VinodexUI/DeviceChassis.swift:148` → settings "About / flip" row plus an accessibilityAction on the orb
  - **Unchanged @b48ad20** — neither half landed. Only delta: the hold shortened
    2.0s → 1.0s and gained `Haptics.orbPress()` feedback
    (`DeviceChassis.swift:256`), so the item text should say 1s.
- [ ] **M48** · a11y · WalkthroughScreen's DeviceDiagram is the entire instructional payload ("this part lights up"), conveyed purely by opacity/glow, with no `accessibilityHidden` and no label — and it contains real `Text` and SF Symbols for *mock* chrome (gearshape, magnifyingglass, chevron.left, person.crop.circle, house.fill), so VoiceOver reads fake buttons interleaved with the real ones; the step dots carry no `accessibilityValue`, so "step 3 of 8" is never announced · `Sources/VinodexUI/WalkthroughScreen.swift:45` (diagram), `:61` (step dots), `:307–443` (mock chrome) → mark the diagram `.accessibilityHidden(true)` with a text equivalent per step, and give the dots an `accessibilityValue`
  - **New 2026-07-31.** The onboarding screen is currently the *least* navigable
    surface in the app under VoiceOver, which is the worst place for it.
- [ ] **M49** · a11y · **H11**'s residual: the app's type axis spans 0.85–1.15 against the system's 0.82–3.12, and the size floor is nominal rather than rendered — at the shipped SMALL step (0.85) a 10pt label still draws at 8.5pt, under Apple's 11pt guidance · `Sources/VinodexCore/TypeScale.swift:114` (`nominalFloor`) + `TextScale.huge` → make the floor a rendered one and add a step above 1.15, which needs the fixed frames below re-tuned first
  - **New 0.6.4**, raised by H11 rather than found separately: H11 closed the
    *incoherence* (one axis, symmetric fallback, no sub-10pt literals) and is
    honest that it did not close the *range*. This item owns the range.
  - Three measured blockers, all of which have to move before the ceiling can:
    `CatalogScreen.swift:249` — `StatBar`'s label sits in a hard
    `.frame(width: 96)` with no `lineLimit` and no `minimumScaleFactor`, and
    AROMATICS (9 chars at `mono(19)`, tracking 1.5) already needs ~94pt of it;
    `RetroGlobeScreen.swift:110` — continent markers are `.fixedSize()` and
    absolutely positioned in a `GeometryReader`, so they grow into each other
    rather than reflowing (overlaps **M20**); and `ChipFlow`/`FlowLayout`
    (`ChipFilterScreen.swift:410`, `CatalogScreen.swift:279`) place an over-wide
    first-in-row chip past the container edge, where `DeviceChassis.swift:458`
    clips it invisibly.
  - A rendered floor is the other half and is the cheaper one, but it re-sizes
    the 41 call sites at `retro(10)`/`retro(11)` — which nothing in this repo can
    check, since VinodexUI compiles to nothing off-device. Pair it with the
    `ios`/`ios-test` CI jobs and a `VinodexUITests` target (**M32**/**M33**/**M47**
    territory) rather than doing it blind.
- [ ] **M50** · a11y · `DexSearchField`'s UIKit path builds its `UIFont` from the raw `fontSize` with no `TextScale` term at all, so the live search field ignores the app's only text-size control — it draws at 26pt while the `DexFont.mono(26)` placeholder beside it draws at 22.1pt, an 18% mismatch under a doc comment claiming the two are "indistinguishable" · `Sources/VinodexUI/DexSearchField.swift:87` → route it through `DexFont.resolvedSize(_:)`, and derive the `.frame(height:)` at `:172` from the result instead of pinning 34
  - **New 0.6.4.** Found while doing **H11** and deliberately left out of it: the
    fix changes the size of a live control on four screens (`DexSearchBar`, plus
    hand-pinned frames at `RatingPrompt.swift:76` and `BookmarksScreen.swift:429`
    that would desynchronise), and a `UIViewRepresentable` cannot see a SwiftUI
    `.dynamicTypeSize` cap either — so it wants its own pass with a device.
    Unchanged by H11: the field was frozen before and is frozen now, just at the
    wrong number.
- [x] **M22** · ux · the PRO alert's UNLOCK button silently dismisses (no storefront exists) — indistinguishable from a broken purchase · `Sources/VinodexApp/VinodexApp.swift:78` → "COMING SOON"/OK until IAP exists
  - **Resolved @0a446d3** (v0.4.1.5). `UpgradePrompt`'s UNLOCK now calls `access.grant(offer)` (persisted via `AccessStore`) and continues navigation — a real entitlement grant, though a payment step is still to come.
- [ ] **M23** · ux · Grape of the Day is buried inside the settings screen — the daily-return feature is invisible from the main menu · `Sources/VinodexUI/SettingsPanel.swift:131` → surface it on the main menu or as an orb badge
  - **Since audit:** v0.3.9 made settings a full SYSTEM screen, but the entry point is unchanged.
  - **Worse @b48ad20.** Still behind the cog, and now **two** daily-return
    features (WHAT'S THAT…? and DAILY CHALLENGE) plus the streak are invisible
    from the main menu instead of one. Note the grid at
    `MainMenuScreen.swift:30–58` has no free slot, so this is a small layout
    decision, not a one-liner.
  - Now at: `MainMenuScreen.swift:29` · `ToolsScreen.swift:84` · `SettingsPanel.swift:57`
- [ ] **M24** · ux · the blanket `.transaction { $0.animation = nil }` strips in-screen animations (expander, daily reveal), not just nav swaps · `Sources/VinodexApp/VinodexApp.swift:71` → scope `Transaction(animation: nil)` to path mutations only
  - **Worse @b48ad20.** Untouched, and it now silently nulls **17** in-screen
    `withAnimation` calls instead of 2. Fix: drop the modifier and wrap the `path`
    writes in `push`/`goBack`/`goHome` in `withTransaction(Transaction(animation: nil))`.
  - Now at: `VinodexApp.swift:82` (the modifier), `:308–343` (the path writes) ·
    victims at `DailyGrapeScreen.swift:138`, `EntryDetailScreen.swift:872`
- [x] **M25** · a11y · the destructive remove-bookmark button is a 26×26pt target sitting on a tappable row · `Sources/VinodexUI/BookmarksScreen.swift:255` → 44pt hit area via frame/contentShape, keep the 26pt visual

**Architecture**

- [ ] **M27** · di · leaf views hard-read `WineDatabase.shared` despite the injectable init (LinkedRow, FlagImage, ContinentScreen hero) — nothing is exercisable against a fixture DB · `EntryDetailScreen.swift:690` + `EntryVisual.swift:314` + `ContinentScreen.swift:76` → inject via environment/params and drop the `.shared` reads
  - **Worse @b48ad20 — and it escaped the UI module.** 13 singleton reads at the
    audit commit, **21 at HEAD** (17 in VinodexUI). Only the ContinentScreen hero
    read was incidentally removed. The new one that matters:
    `ChipFilter.options(for:)` in **VinodexCore** reads
    `WineDatabase.shared.searchableCountries`, and `ToolsTests` iterates all
    facets — so a Core unit test now silently asserts against the *production
    bundled database* instead of a fixture. That is a boundary violation, not
    just another call site, and it is a two-line fix (pass the country list in).
    **Do that one first** — it is the highest value per line in this group.
  - Now at: `ChipFilter.swift:214` + `ToolsTests.swift:23,32` (the Core leak) ·
    `EntryDetailScreen.swift:50,989` (LinkedRow) · `EntryVisual.swift:346` (flags)
    · `SettingsPanel.swift:231`
- [ ] **M28** · duplication · hero panel, SAVE button, and section header are copy-pasted across 4 screens, and drift already shipped (EntryDetail hero still dark-theme) · `EntryDetailScreen.swift:104` + `CountryScreen.swift:72` + `StateScreen.swift:49` + `ContinentScreen.swift:70` → extract DexHero/DexSaveButton/DexSection
  - **Worse @b48ad20 on every axis.** SAVE copies 2 → 3 (`ContinentScreen.swift:126`
    is a new verbatim paste); section-header copies 4 → 6, now with **four
    distinct visual treatments** shipping and `StateScreen.swift:120` inlining
    one; hero is still 4 identical copies. Screens added since copied rather
    than reused (`PassportScreen.swift:129`).
  - Now at: heroes `EntryDetailScreen.swift:221` + `ContinentScreen.swift:93` +
    `CountryScreen.swift:109` + `StateScreen.swift:70`
- [ ] **M29** · testability · pure logic lives in the untested UI module (Palette.resolve color mapping, grapeWellColor/styleTone keyword heuristics) · `EntryTileView.swift:98` + `EntryVisual.swift:72` → move to Core returning hex strings and test beside FilterTests
  - **Unchanged @b48ad20.** `Palette.resolve` is pure Core-type table lookup with
    6 call sites and could move verbatim; `grapeWellColor`/`styleTone` need their
    return type changed from `Color` to a hex `String` to cross the boundary.
  - Now at: `EntryTileView.swift:98` · `EntryVisual.swift:87` (grapeWellColor),
    `:113` (styleTone)
- [ ] **M30** · decomposition · 745-line EntryDetailScreen and 722-line DeviceChassis each bundle 8+ types with clean seams · `EntryDetailScreen.swift` + `DeviceChassis.swift` → split at type boundaries
  - **Worse @b48ad20** — both grew: EntryDetailScreen **747 → 1067** lines,
    DeviceChassis **710 → 978** lines and 9 → 11 top-level types.
  - **The premise is half wrong, though.** EntryDetailScreen has only **4**
    top-level types (and has had 4 since the audit) — its problem is one ~920-line
    View, not type bundling. "8+ types" fits only DeviceChassis. The two halves
    want different treatments and should probably be split into two items.
  - **And it now names the wrong files:** `DexTheme.swift` is **1512** lines and
    `SettingsPanel.swift` **1262** — both larger than either file above. If this
    item is really about decomposition, they belong in it.
  - Cheapest seam is still the effects cluster at `DeviceChassis.swift:715–830`.
- [ ] **M31** · assets · LogoMark and its 139KB vinodex-logo.png are fully dead since the cog replaced the wordmark · `Sources/VinodexUI/DeviceChassis.swift:692` → delete the view and the Logo/ asset
  - **Unchanged and still fully dead @b48ad20** — LogoMark gained no caller
    despite the v0.5.6 skins/emblems work, and the 136 KB PNG ships in every
    build. Deleting `DeviceChassis.swift:959–976` and `Resources/Logo/` removes
    both with no other edits. Trivial; take it with any other sitting.

**Tests & CI**

- [~] **M32** · tests · DailyGrapeScreen's actual path `DailyPick.entry(in:)` (rotation, fallback, tier filter) has zero coverage — tests only exercise `.grape` · `Tests/VinodexCoreTests/DailyPickTests.swift:28` → add entry/category rotation and fallback tests
  - **Mostly done @b48ad20.** `DailyRevealTests` covers rotation, the free-tier
    question, every-entry coverage, and the cursor overload the screen actually
    calls. **Remaining:** the empty-category fallback (`DailyPick.swift:58–64`,
    including the `return nil`) has zero coverage because every test runs against
    the full shared database — it needs a fixture — and the pre-epoch/negative-day
    case is still unpinned.
  - Now at: `MinigameTests.swift:186` (@Suite), `:205`, `:217`, `:232` ·
    `DailyPick.swift:50` (entry(for:))
- [ ] **M33** · tests · filter branches `.type`/`.tasting`/`.soil`/`.system` are untested (all reachable from header tiles); styleClass/colorType keyword precedence unpinned · `Sources/VinodexCore/EntryFilter.swift:105` → add branch and precedence tests
  - **Unchanged @b48ad20** — none of the four branches is exercised by any test
    and precedence has zero coverage. Two refinements: `.soil` is no longer
    constructed anywhere in Sources (so it is dead-or-untested — decide which),
    and `.type`'s DUAL branch plus `.system`'s style-class inference gained
    behaviour in 0.6.2 that is still unpinned.
- [ ] **M47** · tests · two Core modules added/reworked since the audit have **zero** test references: `SearchState.swift` (`SearchStateStore`, per-listing query+anchor persistence, the composite `key(categories:filter:)`, and `EntryFilter.storageKey`) and `DexRoute.swift` (`SettingsSection`, `DexRoute.title`/`marqueeSymbol`, the `EntryCategory`/`WineEntry` extensions) · `Sources/VinodexCore/SearchState.swift:79,86` + `Sources/VinodexCore/DexRoute.swift:113,167` → pin the storage-key encoding and the route vocabulary
  - **New 2026-07-31.** `SearchState.swift:87–91` explicitly documents that the
    key is spelled out so stored queries are *not* silently orphaned when display
    copy changes — precisely the invariant a test should pin, and nothing does.
    It compounds **M33**: the same nine filter cases are untested in both their
    predicate *and* their key encoding. `DexRoute` is the app's whole navigation
    vocabulary, pure and non-UI, sitting in Core untested.
  - Everything else added since `fb5dcf2` does have coverage, including
    `Entitlements` — these two are the gaps.
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
  - **Worse @b48ad20 — the blast radius tripled.** The placeholder ID is unchanged
    at `xtool.yml:8`, there is still no migration step and no registered
    milestone, and the data a future App ID change would orphan grew from **5
    UserDefaults keys to 17** (unlocks, quiz tier, shelves+ratings, daily streak,
    recently-viewed) *plus* an Application Support avatar file added by
    `ProfileAvatar`. Every release since defers this makes the migration bigger.
  - Now at: `xtool.yml:8` · `Bookmarks.swift:66` · `EntryAccess.swift:23` ·
    `README.md:151` · `KNOWN-ISSUES.md:325`
- [~] **M36** · licensing · OFL fonts ship without license text and 87/99 icons are CC BY 3.0 with zero attribution; no repo LICENSE · `Sources/VinodexUI/Resources/Fonts/` → add OFL texts, a NOTICE/credits file (surfaced in settings), and a top-level LICENSE
  - **Related:** [KNOWN-ISSUES.md:284](KNOWN-ISSUES.md:284) records that 4.5 MB of a copyrighted wine encyclopedia is committed and public in `blaikooz/vinodex`. Out of scope for this repo, but it belongs on the same cleanup pass.
  - **Partly done @b48ad20.** `README.md:220–224` now credits game-icons and the
    two fonts. **Still missing:** OFL license texts beside the `.ttf` files, a
    top-level `LICENSE`, a `NOTICE` file, an in-app credits surface — and the 11
    lucide (ISC) + 1 mdi (Apache-2.0) glyphs are uncredited even in the new
    README section.
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
  - **@b48ad20 — CHANGELOG.md still does not exist**, and the tag half is less
    complete than the note above implies: only **four** tags exist
    (`v0.4.2.1.1`, `v0.4.3`, `v0.6.2`, `v0.6.3`). Every v0.5.x release plus
    v0.6.0/v0.6.1 shipped untagged, and the "start with v0.3.8" backfill never
    happened. The bundle-version half is genuinely blocked and now documented at
    `KNOWN-ISSUES.md:259–273` with the `AppVersion` denylist as the workaround.
- [x] **M38** · release · the only visible version string is hardcoded "v0.3.5", three releases stale · `Sources/VinodexUI/DeviceBackPlate.swift:11` → single version source read by the back plate (and DiagnosticsReport)
  - **Resolved @0a446d3.** New `AppVersion` (VinodexCore) reads `CFBundleShortVersionString`; the back plate renders `AppVersion.display`.
  - **Regressed and re-fixed at v0.4.3.** Reading the plist first was the bug: xtool
    stamps `1.0.0`, the guard only rejected `"1.0"`, so the back plate showed
    `v1.0.0` on every build from @0a446d3 until the merge. `AppVersion.placeholders`
    now rejects build-tool defaults and `AppVersionTests` pins it.

**Pipeline**

- [ ] **M40** · pipeline · icons fetched live from api.iconify.design with no version pin — non-reproducible and network-dependent · `scripts/rasterize-icons.sh:56` → vendor the SVGs or pin @iconify-json
  - **Since audit:** narrowed by `fb5dcf2` — the flag half is fixed (`pixelflags/` is committed and the script defaults to it); the live iconify fetch remains.
  - **Unchanged in substance @b48ad20.** The script improved a lot since (atomic
    multi-scale writes, orphan pruning, portable mktemp, non-silent flag skip —
    see L17/L23/L24/M43) but the Iconify half is still an unpinned network fetch,
    so a re-run is still not reproducible. See also **H12**: the *drawn* art has
    a worse version of this problem, with no source tree at all.
- [x] **M41** · pipeline · nothing verifies committed JSON matches generator output (four divergent historical versions already in pack history) · `Sources/VinodexCore/Resources/entries.json` → stamp the source SHA into outputs and add a verify-data regen-and-diff step
  - **Resolved @0a446d3.** CI's `data` job runs `npm run generate` and fails on `git diff` against `Sources/VinodexCore/Resources` (icons/PNGs excluded, since they need network). The regen-and-diff gate now exists; explicit source-SHA stamping was not needed.
- [x] **M43** · portability · rasterize-icons.sh fails on macOS (GNU-only `mktemp --suffix`, apt-only dependency hint) · `scripts/rasterize-icons.sh:54` → portable mktemp pattern plus a brew hint
  - **Prepped (`audit-fixes`).** `mktemp "${TMPDIR:-/tmp}/vinodex-icon.XXXXXX"` (no GNU `--suffix`); the missing-tool hint now names both `apt install librsvg2-bin` and `brew install librsvg`.

## Low — open

**Code quality & dead code**

- [ ] **L1** · consistency · bookmark ids rebuilt from string literals `"COUNTRY_\()"`/`"STATE_\()"` instead of SavedItem prefixes — a prefix change strands saved places · `CountryScreen.swift:28` + `StateScreen.swift:27` → use `SavedItem.country(name).storageID`/`.state(name).storageID`
  - **Unchanged @b48ad20** — same two sites, no new ones. Trivial.
- [ ] **L2** · magic-string · main-screen behavior keyed on `title == "VINODEX"` — breaks silently if the home title changes · `Sources/VinodexUI/DeviceChassis.swift:58` → pass an explicit isRoot flag from RootView
  - **Checked @b48ad20: not actively broken.** The skins/modes work
    (`ChassisSkin`, `LcdMode` incl. GRUNER BOY / VinoFD) only swaps colour tokens
    and picker labels — the home title is untouched, so this is still latent
    fragility rather than a live defect. Still worth the explicit flag.
- [x] **L3** · ux-state · the daily-grape reveal resets on every visit (plain @State) though `DailyPick.isSameDay` was built to persist it · `Sources/VinodexUI/DailyGrapeScreen.swift:16` → persist last-revealed date and initialize revealed from it
  - **Resolved (redesigned) @0a446d3.** The feature became a repeatable cursor-based guessing game (`DailyPick.RevealCursor`); per-visit reset is now intended. `DailyPick.isSameDay` is vestigial (test-only) — a candidate for L4-style dead-code removal.
- [x] **L4** · dead-code · textSection, WineEntry.iconTint, Palette.chip(country:) have no callers (and isSameDay is test-only pending L3) · `EntryDetailScreen.swift:567` + `DexIcon.swift:100` + `WineDatabase.swift:99` → delete (or wire isSameDay via L3)
  - **Narrowed @0a446d3.** `Palette.chip(country:)` now has a caller (ScannerScreen) — keep it. Still dead: `textSection` (EntryDetailScreen) and `WineEntry.iconTint` (DexIcon); `DailyPick.isSameDay` is now also dead per L3. Delete those three.
- [x] **L5** · stale-docs · comments still describe the retired 30-entry starter dataset, plus UTF-8 mojibake ("â€”") · `WineDatabase.swift:324` + `DexTheme.swift:430` → update comments to full-dataset reality and fix the em-dash
- [x] **L6** · stale-docs · the continent MARK comment contradicts the code below it (claims "no glyph"/SF Symbol while generated glyphs are used) · `Sources/VinodexUI/EntryVisual.swift:220` → rewrite to describe current behavior
- [ ] **L9** · access-control · many VinodexUI types are public but never used outside the module (CatalogScreen, IconLoader, FlowLayout, StatBar, …) · `Sources/VinodexUI/CatalogScreen.swift:12` → demote to internal except what VinodexApp imports
  - **Worse @b48ad20.** 48 public types / 30 app-unreferenced at `fb5dcf2` →
    **72 / 42** at HEAD. New files split both ways: `GrapeSpriteLoader.swift:18`
    is correctly internal and is the pattern to copy, but
    `CountryOutlineMap.swift:15` and `DiagnosticsReport.swift:9` shipped public
    and unreferenced.
  - The module disagrees with itself: `GrapeSpriteLoader` is internal while its
    siblings `PixelArtLoader` (`EntryVisual.swift:296`) and `FlagLoader`
    (`:334`) are public — same role, same call pattern. The `public` habit is
    being applied by copy, not by intent, which is why this keeps growing.
- [ ] **L10** · lifecycle · GlobeModel's CADisplayLink is invalidated only in onDisappear — a skipped callback leaves it firing forever · `Sources/VinodexUI/RetroGlobeScreen.swift:344` → invalidate in dismantleUIView/deinit as well
  - **Unchanged @b48ad20**, with two live teardown paths that bypass
    `onDisappear`: the globe is mounted a second time inside the scanner flow
    (`ScannerScreen.swift:386`), and the whole root tree is rebuilt by `.id(…)`
    on text-size/UI-scale change.
  - **Trap for the fix:** `.id("\(lcd.rawValue)|\(skinRaw)")` on `GlobeSceneView`
    (`RetroGlobeScreen.swift:68`) forces a full representable rebuild on every
    LCD-mode or skin change, and the *surviving* link is what makes that safe —
    `start()` early-returns on `guard displayLink == nil` (`:399`). Invalidating
    in `dismantleUIView` **without** confirming the restart in `attach()`/`start()`
    (`:371`) will freeze the globe the first time the user switches skin. Do the
    two edits together, not independently.

**Performance polish**

- [ ] **L11** · perf · four PulseGlow repeatForever animations blur shadow radius continuously on every screen, even behind the flipped plate · `Sources/VinodexUI/DeviceChassis.swift:587` → animate opacity of a pre-blurred circle and pause while flipped
  - **Unchanged @b48ad20**: shadow *radius* is still what animates, four instances
    per frame, nothing pauses while the back plate shows (the front face is merely
    opacity-0 at `DeviceChassis.swift:102`).
  - Worth knowing: `PulseGlow` (`DeviceChassis.swift:810`) is the **only**
    `repeatForever` animation in the entire codebase, so fixing it is the whole
    of the app's perpetual-animation cost — and it overlaps **M18**.
- [ ] **L12** · perf · BookmarksScreen renders saved rows in an eager VStack and every name-field keystroke rebuilds the whole list · `Sources/VinodexUI/BookmarksScreen.swift:44` → LazyVStack plus a child view for the name editor
  - **Worse @b48ad20.** Both halves intact, and the keystroke-rebuilt subtree grew
    — 0.6.3's recently-viewed strip (`BookmarksScreen.swift:295–332`) eagerly
    builds up to 20 icon wells inside it. BookmarksScreen is now the **only** list
    screen still using an eager VStack.
  - Now at: `:107` (eager VStack), `:131` (ForEach), `:425` (nameRow), `:429`
    (search field bound to `$displayName`)
- [ ] **L14** · perf · `hasRegions(inCountry:)` re-filters and re-sorts the whole DB per country row per render · `Sources/VinodexUI/ContinentScreen.swift:145` → precompute a Set of region-origin countries once
  - **Unchanged @b48ad20, and the fix got nearly free:** `WineDatabase.init`
    already walks region origins at `WineDatabase.swift:324–332` to build
    `searchableCountries` — capture the same loop's origins into a `Set` and make
    `hasRegions` a membership test. **Note:** `searchableCountries` stores *raw*
    origins while `hasRegions` compares through `TextNormalize.label`, so the new
    set must be the normalised one.
- [x] **L15** · perf · regionVisual runs the identical key-grape lookup scan twice (tint + iconID) per resolve · `Sources/VinodexUI/EntryVisual.swift:152` → look up once into a local
  - **Resolved @b48ad20**, challenged without refutation. The duplicated scan is
    gone — region visuals dropped key-grape lookups entirely in v0.5.7, and the
    name resolver became a hash lookup (**H9**). Now at `EntryVisual.swift:159`.
  - Nit left behind: the `EntryVisualCache` doc comment (`EntryVisual.swift:269`)
    still describes the removed key-grape walk.
- [~] **L16** · perf · DexFont.retro/mono run a UIFont availability probe plus a UserDefaults read on every Font construction · `Sources/VinodexUI/DexTheme.swift:264` → resolve availability into static lets at registration
  - **Half done, and the other half spread @b48ad20.** Availability probing is
    genuinely fixed (static lets at `DexTheme.swift:335–336`). The per-call
    `UserDefaults.standard.string` read is still in `retro`/`mono` (`:340`, `:349`)
    — and the same uncached idiom is now a house pattern: `UIScale` (`:451`),
    `LcdMode` (`:821`), plus `DexSound.swift:25` and `Haptics.swift:21`, across
    seven more per-render call sites. **Every `Text` in the app pays it.**
  - Fix this as one shared cached-setting mechanism rather than patching
    `DexFont` alone — but keep settings live: RootView keys off these values.

**Assets & data footprint**

- [x] **L17** · assets · 21 orphan icon PNGs (7 slugs × 3 scales, ~70KB) ship unreferenced because the rasterizer never prunes · `Sources/VinodexUI/Resources/Icons` + `scripts/rasterize-icons.sh:26` → delete orphans and add a prune step
  - **Prepped (`audit-fixes`).** Deleted the 21 orphans (circle, flame, oak, shield, sparkles, lucide flag, lucide globe) and added a prune step that drops any `Icons/*.png` whose slug left the manifest.
- [x] **L18** · data · palette.json ships fields nothing decodes (flagGradients, flavorClassMeta) and Palette decodes fields nothing reads (appellationChips, continentColors) · `WineDatabase.swift:91` + `scripts/generate-ios-data.ts` → drop both sides
  - **Resolved (`audit-fixes`).** Generator strips `flagGradients`, `flavorClassMeta`, `appellationChips`, `continentColors`; the two non-optional `Palette` properties (`appellationChips`, `continentColors`) and the `emptyPalette` init were updated to match.
- [x] **L19** · data · all four JSONs are pretty-printed (2-space indent), inflating ~412KB by roughly a third · `scripts/generate-ios-data.ts:674` → emit minified (keep a --pretty debug flag)
  - **Prepped (`audit-fixes`).** Minified by default via `serialize()`; `--pretty`/`PRETTY=1` for readable output. With M4/L18, entries.json 346KB → 193KB (−44%). Verified whitespace-only by JSON.parse deep-equality.
- [ ] **L20** · assets · AppIcon.png is a barely-compressed 1024² PNG at 932KB (~⅓ of the git pack) · `AppIcon.png` → recompress losslessly (oxipng/zopflipng) and note a binary-asset policy
  - **Worse @b48ad20 — and the item's priorities have inverted.** AppIcon is
    unchanged at 951,285 bytes (still ≥14% recompressible by a naive re-deflate),
    but the tracked binary payload grew **12.8× to 35.6 MB**, dominated by **30 MB
    of drawn art then under `shared/newicons/`, now `art/`** (single files up to
    1.5 MB; read as "superseded contact sheets" at the time — see the next
    bullet). AppIcon is now 2.6% of the pack, not a third.
  - So the **missing binary-asset policy is the real item now**. The "superseded"
    reading was wrong, and **H12 settled it**: those files were the *only*
    surviving art sources, so H12 moved them to `art/` rather than dropping them.
    **The 30 MB is not recoverable and L20 gained nothing from H12.** What is
    actually on the table, all of it a policy call:
    `art/icons/reference/` (9 contact sheets, 11,670,225 B — the largest single
    lever, and they are the artist's originals), `art/icons/attic/` (8 drawn but
    unreferenced icons, 849,004 B), lossless recompression of the sources
    (~24.6% on a sample, and provably cannot change any regenerated output since
    the importers consume pixels only), and AppIcon itself.
- [~] **L22** · reproducibility · the xtool version used for packaging/signing is recorded nowhere · `xtool.yml` → record the known-good version as part of the release checklist
  - **Since audit:** narrowed by `fb5dcf2` — README now pins the Swift requirement (6.3); xtool remains unpinned.
  - **Half done incidentally @b48ad20:** xtool 1.17 is now written down at
    `KNOWN-ISSUES.md:261` and `AppVersion.swift:25`, so the version in use is
    discoverable. **Still missing the actual ask:** a release checklist naming the
    known-good version, and a versioned prerequisite at `README.md:123` instead of
    an unpinned link.

**Pipeline & diagnostics**

- [x] **L23** · pipeline · a failed rsvg-convert on one scale leaves already-written variants behind — partial scale sets can be committed unnoticed · `scripts/rasterize-icons.sh:74` → render to temp names, move atomically only when all three succeed
  - **Prepped (`audit-fixes`).** Each scale renders to a `.tmp.$$` name; the three are `mv`-ed into place only if all succeed, else all are removed. (Render path not run locally — no rsvg-convert here.)
- [x] **L24** · pipeline · a missing pixelflags directory is a soft skip that still exits 0 · `scripts/rasterize-icons.sh:126` → fail hard unless SKIP_FLAGS=1
  - **Prepped (`audit-fixes`).** A missing `pixelflags/` now increments `failed` (so the run exits 1) unless `SKIP_FLAGS=1` is set explicitly.
- [ ] **L25** · pipeline · the country→slug rule is implemented twice (shell `tr` vs Swift string ops) with no shared test — divergence means a silently missing flag · `scripts/rasterize-icons.sh:110` → emit the final slug per country into icons.json and consume it on both sides
  - **Unchanged @b48ad20** — neither side reads a generated slug. No live
    breakage today: all 29 flag keys are ASCII differing only by spaces. The
    exposure is the next non-ASCII or punctuated country name.
- [ ] **L26** · diagnostics · nothing checks that every icons.json id has a bundled PNG — a rasterization gap ships as the red questionmark placeholder · `Sources/VinodexUI/DiagnosticsReport.swift:23` → probe the bundle for each `unique` id and flag misses
  - **Worse @b48ad20** — the unguarded surface grew from one directory to five.
    **No live gap, though:** the probe was scripted during this pass and
    everything resolves (66/66 icon ids, 96 flavorArt, 14 grapeArt, 31 styleArt,
    94 `art:` ids, 198 = 66×3 Icons files, 29 flags). This is purely a missing
    guardrail. Fix: loop `db.icons.unique` plus the art stems and flag slugs
    through `DexResources.url` in `DiagnosticsReport` and flag misses.
  - Now at: `DiagnosticsReport.swift:21` (count-only rows) ·
    `DexIcon.swift:110` (the questionmark placeholder)
- [ ] **L45** · stale-docs · `DexIcon.image(_:)`'s doc comment claims it returns "the glyph for an Iconify id, **or the manifest fallback**", but the implementation returns nil on a miss and the caller draws the red questionmark — `icons.fallback` (mdi:help-circle-outline) is never substituted, even though it is in `unique` and has a bundled PNG · `Sources/VinodexUI/DexIcon.swift:31` (comment), `:41` (returns nil), `:110` (placeholder) → either substitute the fallback or fix the comment
  - **New 2026-07-31.** Harmless today (see L26 — nothing is missing), but it is
    the same stale-comment class as **L5**/**L6**, and it describes the exact
    safety net **L26** assumes exists.

**UI polish**

- [x] **L27** · a11y · the settings close button is a 34×34pt target · `Sources/VinodexUI/SettingsPanel.swift:77` → 44×44 frame around the 34pt visual
  - **Resolved @0a446d3.** Settings became a pushed route with no dedicated close control; it is dismissed by the chassis Back button (`DexMetrics.footerControl` = 64pt).
- [~] **L28** · pixel-art · DexIcon omits `.interpolation(.none)` while FlagImage/LogoMark set it — glyphs blur instead of staying crisp · `Sources/VinodexUI/DexIcon.swift:54` → add `.interpolation(.none)`
  - **Half done @b48ad20.** DexIcon is fixed on both branches
    (`DexIcon.swift:94–108`) and the code cites L28. **The same omission survives
    in three places, and they are the app's *largest* pixel art:** the grape
    sprite branch (`EntryVisual.swift:402`), the region-outline branch (`:444`),
    and `CountryOutlineMap.swift:63`. Three one-line additions.
  - Same shape as **M24**: fixed for the one file the audit named while the
    pattern spread into files added since.
- [x] **L29** · light-mode · hero panels overlay a hardcoded dark-green grid that reads heavy/busy on the light hero (4 screens) · `EntryDetailScreen.swift:113` + `CountryScreen.swift:95` + `ContinentScreen.swift:99` + `StateScreen.swift:72` → mode-aware heroGrid color on LcdMode
- [x] **L30** · light-mode · EntryDetail's hero title shadow hardcodes #006400 while sibling screens use `lcd.accent.opacity(0.55)` — reads as blur in light mode · `Sources/VinodexUI/EntryDetailScreen.swift:104` → match the siblings (also resolved by M28's extraction)
- [ ] **L32** · layout · SE-class devices still reserve the 138pt island clearance for a phantom cutout, leaving a dead gap · `Sources/VinodexUI/DeviceChassis.swift:180` → collapse clearance when safe-area top is below the cutout threshold
  - **Unchanged @b48ad20.** **Trap for the fix:** `DexTheme.swift:144–147`
    documents that `.statusBarHidden()` (set at `VinodexApp.swift:125`) can
    collapse `safeAreaInsets.top` to zero *on cutout devices* — so keying the
    clearance off the top inset would collapse the band on exactly the devices
    that need it. This needs a different device signal.
- [ ] **L33** · theme-discipline · inline hex palettes bypass the token system (menu tiles, statColors, markerColors) — how light-mode surfaces got missed before · `MainMenuScreen.swift:32` + `EntryDetailScreen.swift:448` + `RetroGlobeScreen.swift:216` → hoist into Dex/palette.json tokens
  - **Worse @b48ad20 — roughly tripled.** One third fixed (globe markers are now
    data-driven), two thirds untouched, and the overall violation went **72 → 205
    inline hexes across 11 → 17 files**, because every screen added since the
    audit (ToolsScreen, WalkthroughScreen, PassportScreen, ChipFilterScreen)
    shipped its own tile palette inline.
  - **Worst offender is also a correctness hazard:** the light/dark tile livery
    tables at `SettingsPanel.swift:120–141` duplicate the same six colour pairs
    twice, switched on the tile **title string** — rename a tile and it silently
    falls through to the ACCESS default. `InternalsView.swift:36–91` is next.
  - Now at: `MainMenuScreen.swift:33,37,51,55` · `EntryDetailScreen.swift:693`
    (statColors) · `SettingsPanel.swift:125` · `InternalsView.swift:36`

**UX polish**

- [x] **L34** · search · no clear button on the search field (`clearButtonMode = .never`) — queries must be deleted character by character · `Sources/VinodexUI/DexSearchField.swift:30` → `.whileEditing` (or a retro X button)
- [ ] **L35** · search · MASTER SEARCH opens without focusing the field — an extra tap on a screen whose whole purpose is typing · `Sources/VinodexUI/DexSearchField.swift:23` → autofocus option enabled for the masterSearch route
  - **Cheaper than the audit assumed @b48ad20:** the `focusesOnAppear` plumbing
    already exists on `DexSearchField` and is proven in BookmarksScreen. Needs a
    pass-through param on `DexSearchBar` and `EncyclopediaListScreen`, set true
    only for the `.masterSearch` route.
- [ ] **L36** · empty-state · StateScreen renders a bare "REGIONS" header with zero rows and no message when a state resolves empty · `Sources/VinodexUI/StateScreen.swift:116` → "NO REGIONS FOUND" empty state matching the list screens
  - **Unchanged @b48ad20, and it has a sibling the audit missed:**
    `CountryScreen.swift:362–387` has the identical unconditional "REGIONS" header
    over an unguarded ForEach. Fix as a shared section helper, not a one-liner in
    StateScreen. (Trigger is narrow — a state route is only reachable from an
    existing region row — but a *partial* decode failure now produces exactly
    this, see H2/M46.)
- [ ] **L37** · consistency · the code comment says single-item removal deliberately skips confirmation, but every ✕ tap shows a confirm dialog · `Sources/VinodexUI/BookmarksScreen.swift:84` → drop the confirm (SAVE toggle is the undo) or fix the comment
  - **Unchanged @b48ad20 and slightly worse to read:** the comment now sits
    directly above **both** overlays (clear-all at `:165–180`, single-remove at
    `:181–194`), so it misdescribes code three lines below it.
- [ ] **L38** · haptics · only generic tap/select feedback exists — saves and destructive confirms get no distinct success/warning haptic · `Sources/VinodexUI/Haptics.swift:9` → add UINotificationFeedbackGenerator-backed success()/warning()
  - **Worse @b48ad20:** call sites roughly doubled (32 → 78), and v0.6.x added
    TastingQuizScreen/DailyChallenge whose correct/wrong branch
    (`TastingQuizScreen.swift:178`) is precisely the success/warning case.
  - **Compounded by L43:** that same wrong answer is also *silent*, because
    `Sounds.wrong()` is an empty stub. Take the two together.
  - Add `success()`/`warning()` behind the existing `enabled` gate, then wire the
    quiz branch and DexAlert's destructive confirm.
- [ ] **L39** · search · region lists never show the search bar (`showsSearch: category != .regions`), so long filtered lists can't be searched · `Sources/VinodexApp/VinodexApp.swift:118` → enable showsSearch for filtered region lists
  - **Unchanged @b48ad20** — a one-word fix (drop the `category != .regions`
    condition). Narrower than the audit implied: the single reachable case is the
    climate-filtered region list from an entry page, but it can run long.
- [ ] **L40** · battery · `isIdleTimerDisabled = true` for the app's whole lifetime — the phone never auto-locks · `Sources/VinodexApp/VinodexApp.swift:93` → make keep-awake a settings toggle
  - **Unchanged @b48ad20.** Obvious home is a third row in `systemSettings`
    (`SettingsPanel.swift:460–496`) beside HAPTICS/SOUNDS, with an `@AppStorage`
    key read by `ScreenWake`, defaulting **on** to preserve today's behaviour.
- [x] **L41** · consistency · the locked-entry alert overlays the whole chassis, contradicting the documented in-LCD dialog convention other screens follow · `Sources/VinodexApp/VinodexApp.swift:74` → present inside the LCD content area
  - **Resolved @b48ad20**, challenged without refutation. The upgrade prompt now
    renders inside the LCD like every other dialog; no chassis-level overlay
    remains. This looks like a deliberate completed sweep — all four dialog sites
    (`VinodexApp.swift:89`, `:110`, `SettingsPanel.swift:102`, `:280`) follow the
    convention now.
  - Now at: `VinodexApp.swift:79–102` (ZStack inside the chassis content closure)
    · `DeviceChassis.swift:436` (innerBezel calls `content()`)
- [~] **L42** · settings-copy · user-facing settings say "PAYWALL TESTING"/"SKIN TESTING" and hand every user a paywall-defeating toggle · `Sources/VinodexUI/SettingsPanel.swift:156,192` → user-language labels; move the paywall toggle to the DEV tab until real IAP
  - **Labels fixed, controls not @b48ad20.** The paywall-defeating FREE TIER
    toggle is still one tap from the settings grid, and the panel still describes
    itself in test-harness language ("a test harness, not a store", `:379`).
    Either move the whole `paywallTesting` panel behind DEV — as DEV itself was
    moved — or replace it with a real store front.
  - Now at: `DexRoute.swift:19` (section labels) · `SettingsPanel.swift:87`
    (ACCESS tile), `:313` (FREE TIER toggle), `:379` (the copy)
- [ ] **L43** · ux · `Sounds.page()` and `Sounds.wrong()` are empty no-op stubs — every push/pop calls `Sounds.page()` for nothing, and a wrong quiz answer is completely silent (and gets only the generic selection haptic) · `Sources/VinodexUI/DexSound.swift:43,48` + `VinodexApp.swift:309,326,339` + `TastingQuizScreen.swift:181` → fill them in or delete the calls
  - **New 2026-07-31.** Pairs with **L38**: wrong answers currently have neither
    sound nor distinct haptic, which is the one place the app most needs both.
- [ ] **L44** · a11y · quiz right/wrong is signalled only by a checkmark/xmark glyph plus a green/red border tint on an already-disabled row — no text and no accessibilityLabel says "correct" · `Sources/VinodexUI/TastingQuizScreen.swift:414`, `:433` → add a label or trait carrying the result
  - **New 2026-07-31.** Colour-plus-glyph alone also fails for colour-blind users,
    not only VoiceOver. Note the screen's *modal* handling is good
    (`accessibilityElement(children: .contain)` + `.isModal` at `:456`), matching
    DexAlert — this is the one gap. See also **M48**.

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

**2026-07-31 — H11 H12.** The last two High items, and with them the High row.
Neither was closed the way its own remedy line described, because the
investigation contradicted the remedy in both cases; both entries carry the
correction.

- **H12** turned on one fact the item had backwards. `art/` was never in this
  repo's history, so "restore `art/`" was impossible — but `shared/newicons/`
  was not the superseded layout the scripts "call replaced", it was the *only
  surviving copy* of every drawn source, in the pre-0.5.8 drop-folder shape.
  `art/icons/**` had only ever been a re-foldering of it that nobody performed
  here. So: 271 files `git mv`'d into the per-use layout the five scripts already
  address, zero path-logic changed, and the remedy's closing clause — "then drop
  `shared/newicons/`" — deliberately **not** followed, because it would have
  deleted the sources. `npm run icons:verify` (new) regenerates into a temp tree
  and reports 244/254 pixel-identical, 10 within recorded quantiser budgets, 0
  changed, 0 without a source. Getting there needed four sources chroma-keyed,
  three `gold-*-rare` stems added to a table that had been producing 30 against a
  bundle of 33, and five hand-recoloured masters promoted to tracked sources with
  a verbatim-copy path — re-importing those moves 49–62% of their pixels.
  Byte-identity is not the gate and the bundle was not re-baselined: 0 of 249 are
  byte-identical today for palette-order and zlib-build reasons, and re-cutting
  the baseline would have silently changed visible pixels on ten shipped glyphs.
- **H11** collapsed two text axes into one. `Font.custom(_:fixedSize:)` on both
  `DexFont` branches removes the primary/fallback asymmetry by construction
  rather than by matching two mechanisms; `TextScale` and a new size resolver
  moved to `VinodexCore` so the arithmetic is reachable from `swift test` at all;
  the ten sub-10pt literals were raised and a nominal floor plus a CI grep keep
  them raised. The part worth flagging is what it did *not* do: capping the
  system control while the in-app one topped out at as-drawn would have left a
  low-vision user with less than they had, so `TextScale` gained a **HUGE (1.15)**
  step and a first-launch seed — and the remaining gap to the system's 3.12x is
  filed as **M49** rather than claimed. **M50** records a `DexSearchField` sizing
  bug found on the way and deliberately left alone.
- Corrections landed with them: H12's "~2.8 MB" is ~4x high (the 94 glyphs are
  718 KB); its "84% of the tracked binary payload" is arithmetically right but its
  conclusion is not, so **L20 gains nothing here** and its lever list is rewritten;
  H11's call-site census was 191 and is 194; both of H11's file anchors pointed at
  a doc comment and a closing brace. `auditS.md`'s claim that three SFX files are
  byte-identical *to each other* is also wrong and is corrected there.

**2026-07-31 — M2 M3 M5 M6 M7 M8.** The performance row of the workstream table,
plus the two Data & robustness items the challenge pass had downgraded from
"resolved" the same day. Six closed; Medium open 28 → 22.

- **M5** is the substantial one. `WineDatabase` now carries a load-time search
  index — `sortedEntries` (sorted once, so filtering it needs no sort) alongside
  a parallel `searchHaystacks` (every searched field folded once and joined with
  a newline, which no query can contain, so a whole-string `contains` is exactly
  the old per-field scan). `entries(matching:)` is the indexed query; `apply(_:)`
  survives as the documented unindexed path for callers holding a bare array. A
  shared 180ms `awaitSearchDebounce` covers all three screens and deliberately
  skips the keystroke that enters or leaves an empty query, so entering a search
  and clearing one both stay instant. `ChipFilterScreen` and `ScannerScreen`
  stopped recomputing in `body` — the chip badges were three dozen full catalog
  scans *per body pass*.
- **M2** stopped letting the search string decide what an empty screen means.
  `WineDatabase.dataState` reads the loader's own facts, and one shared
  `DexEmptyState` wrapper gives all three screens the same three shapes — panel
  as-is, panel plus a partial-load footnote, or DATA LOAD ERROR outright. The
  chip filter and the daily grape had never had any of it.
- **M3** widened `validateOutputs` from four entry keys to every non-optional
  property of every Swift struct, per category, plus the six tables that are
  optional at decode and therefore fail silently. Proven by eight injected
  drifts, each of which now fails `npm run generate`; the clean run is
  byte-identical to the committed data.
- **M6** moved the launch diagnostics to a detached task and behind `#if DEBUG`.
  Six full filter+sort passes over the catalog were running synchronously in
  `App.init` in *release* builds.
- **M7** resolved `CountryScreen`'s six derivations in `init` from one query and
  one walk, killing the `regions.filter` that sat inside a `ForEach`.
- **M8** finished the marquee: paused on `showsBackFace`, and `gap`/font/symbol
  size hoisted out of the per-frame closure — both were `UserDefaults` reads.
- **Verification.** `swift build` clean; `npm run generate` clean with no data
  drift; `tsc --noEmit` clean; eight generator negative tests pass. **Not** run
  locally: `swift test` (the host toolchain has no `Testing` module) and any iOS
  compile (no Xcode, no iOS SDK — `xcrun --sdk iphoneos` fails). The `VinodexUI`
  changes are therefore syntax-checked but not type-checked here; CI's `ios` job
  is the first real check on them. See the note under **M32/M33**.

**2026-07-31 — full re-verification @ `b48ad20` (v0.6.3).** All 52 open items
re-read against current source by eleven parallel workstream passes; the
`fb5dcf2` anchors were ignored in favour of the quoted symbols. Every claimed
resolution was then handed to a second agent told to **refute** it, defaulting to
"still open" when it could not positively confirm the whole item. Two claimed
resolutions were downgraded that way (**M2**, **M3** — both had a second half
still missing), which is the reason this pass is trustworthy where a
read-the-checkboxes pass would not be. **52 open → 47 remaining, then 55 with the
new items.**

- **Resolved, checked off (5):**
  - **H2** — `FailableEntry` element-wise decode + a launch-time DATA LOAD ERROR
    `DexAlert` + list error state + DEV readout + four regression tests. This was
    the highest open item in the file.
  - **H6** — `IconLoader` resolves device scale in init and loads via
    `UIImage(data:scale:)` with a `@3x → @2x → @1x` walk-down.
  - **M9** — the marquee now measures real rendered label geometry.
  - **L15** — the duplicated key-grape scan disappeared with v0.5.7's region
    visuals; the name resolver is a hash lookup.
  - **L41** — dialogs are in-LCD everywhere; a deliberate completed sweep.
- **Downgraded from "resolved" by the challenge pass (2):** **M2** (the error
  state is gated on `search.isEmpty`, and `SearchStateStore` persists queries —
  so the suppressed path is the reported symptom) and **M3** (the Swift-side
  schema assert landed, but `validateOutputs` still covers ~4 of ~18 entry keys
  and none of the newer art tables).
- **Worse than at the audit (15):** H11 M5 M20 M23 M24 M27 M28 M30 M35 · L9 L12
  L20 L26 L33 L38. See the ranked table under Status. None was a regression — all
  fifteen grew because the catalog tripled and eight screens landed on top of
  unfixed foundations. **This is the argument for taking the architecture and
  theme-discipline rows before the next feature batch:** M27, M28, L9 and L33 all
  grow with every screen added.
- **New items raised (8):** **H12** (drawn-art sources missing — 94 bundled
  glyphs unregenerable), **M45** (schema stamp fires on stale data, not just
  corruption), **M46** (palette/icons/countries decodes H2 did not cover;
  countries is silent), **M47** (SearchState + DexRoute untested), **M48**
  (WalkthroughScreen reads mock chrome to VoiceOver), **L43** (empty sound
  stubs), **L44** (quiz result is colour-only), **L45** (DexIcon fallback
  comment describes behaviour that does not exist).
- **Re-pinned:** every open item now carries a `Now at:` anchor against
  `b48ad20`. The inline `file:line` in each item body is still the original
  `fb5dcf2` pin and should be read as history.
- **Bookkeeping fixed:** the workstream table had lost **H6** entirely (its
  UI & UX row counted 14 but listed 13), and the v0.6.2 entry below links a
  `../PLAN.md` that does not exist anywhere on disk.
- **Corrections to item text, for whoever takes them:** **M30**'s "each bundle
  8+ types" is wrong for EntryDetailScreen (4 types, one ~920-line View) and the
  two files it names are no longer the largest — `DexTheme.swift` (1512) and
  `SettingsPanel.swift` (1262) are. **M21**'s "2s long-press" is now 1s.
  **M33**'s `.soil` branch is no longer constructed anywhere in Sources.

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
- ~~The prioritized next-sittings pick from this set now lives in
  `../PLAN.md`.~~ **Dead link as of 2026-07-31** — no `PLAN.md` exists anywhere
  under `/opt/projects`. Use the workstream and "worse than at the audit" tables
  under Status instead.

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
