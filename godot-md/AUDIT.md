# Vinodex Audit — 2026-07-28

**Authored by Godot.**

A work order, not a report. Every item below is a specific, located defect with a
proposed fix. Work through them in any order; check them off as they land.

> **Path note (added 0.6.5, batch 4 — findings below are unchanged).** Read
> `pixelflags/` references as **`shared/pixelflags/`** (the cross-repo master,
> mirrored from `HGapps\shared`), and `shared/newicons/` as **`art/icons/`**
> since H12 re-foldered the drawn-art masters. This file itself moved from the
> repo root into `horizon-md/`.

**IDs are permanent.** Reference them in commits and PRs as `H3`, `M12`, `L27` —
they never get renumbered, even as items are resolved.

## Status

**102 resolved · 1 won't-fix · 4 open** — **M31 M36 M40** were all held back
deliberately, none missed, and **M37** is two-thirds done with its last third
blocked by the toolchain. See the update log.

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

**Then M11–M20**, 2026-07-31 — the four still open in that range: **M11**
(the globe's frame loop on a clock), **M17** (portrait lock), **M18** (Reduce
Motion, previously honoured nowhere in the app) and **M20** (a non-globe path
to a continent). That clears the Performance row's only Medium and two of the
Accessibility row's six. See the update log.

**Then seven Mediums, 2026-08-03** — the whole Data & robustness row
(**M45 M46**), two thirds of Architecture (**M27 M29**), two of the three
remaining Accessibility items (**M48 M50**), and the partial Tests item
(**M32**). Data & robustness empties. Three of the seven were closed by a
different mechanism than their own remedy line proposed, and each says why —
M45 by splitting the diagnostic channel rather than the message, M48 by
labelling the diagram rather than hiding it, M27 by *re-keying* two caches
rather than injecting into them. See the update log.

**Then the whole Low row, 2026-08-01** — all 25 open and partial items, L1
through L45. Four rows of the workstream table empty completely — Performance,
Pipeline & reproducibility, Light mode & contrast, and UI & UX polish, the last
of those once its four already-ticked Mediums were counted properly (see the
note under the table). Three of the fixes are structural rather than local, and
are worth knowing about before touching the areas they
landed in: `SettingsCache` (**L16**) memoises the settings every render reads,
`DexTileLivery` (**L33**) is now the only place a tile face is spelled, and
`DexAssetAudit` (**L26**) resolves every manifest id through the bundle in
SETTINGS > DEV. See the update log.

**Then M36's blockers fell, 2026-08-05** — the owner answered both deferred
questions (LICENSE: all-rights-reserved; SFX: first-party) plus the three
provenance questions auditS carried, and `LICENSE`, `NOTICE.md`, `licenses/`,
the bundled `OFL.txt` and `shared/PROVENANCE.md` landed at once. The open count
below is unchanged at 4, but the character of M36 changed: it now waits only on
the in-app credits surface, not on anyone's answer. See the update log.

| Severity | Open | Resolved | Won't-fix | Total |
|---|---:|---:|---:|---:|
| Critical | 0 | — | — | 0 |
| High | 0 | 12 | — | 12 |
| Medium | 4 | 45 | 1 | 50 |
| Low | 0 | 45 | — | 45 |
| **Total** | **4** | **102** | **1** | **107** |

Open items by workstream — each row is roughly one sitting's worth of related work:

| Workstream | Open | Items |
|---|---:|---|
| Release & licensing | 2 | M36 M37 |
| Architecture & code quality | 1 | M31 |
| Tests & CI | 0 | — |
| Accessibility | 0 | — |
| Pipeline & reproducibility | 1 | M40 |

Counting matches the checkboxes: 102 `[x]`, 4 not-done (**M31** `[ ]`, **M36**
`[~]`, **M37** `[~]`, **M40** `[ ]`), and **M12** `[~]` is the won't-fix.

**M37 is two-thirds landed.** CHANGELOG.md and the tag backfill are done; a real
bundle version is blocked by xtool 1.17 offering no key for it, and reopens when
there is a signing pipeline. **M35 is closed even though the placeholder bundle
ID is still in `xtool.yml`**: the item asked for a milestone and a migration
path, not for the ID change itself, which needs a paid account or a freed
quota.

**Medium counts corrected 2026-08-01.** The tables above said 20 Mediums open
while the checkboxes said 16 — **M21**, **M23**, **M24** and **M28** are ticked
in place with resolution notes but were never removed from the totals or the
workstream row. Nothing was re-litigated; the summary now matches the items.

**Worse than when the audit ran.** Fifteen items grew between v0.3.8 and v0.6.3 —
none deliberately, all by the catalog tripling and eight screens landing on top of
unfixed foundations. Ranked by how much they grew:

| ID | Then → now |
|---|---|
| **L33** | 72 → 205 inline hexes, 11 → 17 files (every new screen shipped its own tile palette) — *since fixed at the named sites; `DexTileLivery` is the token* |
| **H11** | 80 → 194 `DexFont` call sites, 7 → 10 sub-10pt labels, still no Dynamic Type cap — *since fixed; the range is now M49* |
| **L20** | tracked binaries 2.8 MB → 35.6 MB (30 MB of it *source* art, not superseded — see H12) — *since fixed: AppIcon −29%, policy written; the 8.4 MB in `art/` is a maintainer call* |
| **L38** | 32 → 78 haptic call sites, and the quiz's correct/wrong branch is exactly the missing case — *since fixed* |
| **M27** | 13 → 21 `WineDatabase.shared` reads — and it escaped into Core |
| **M24** | blanket transaction now nulls 17 `withAnimation` calls, not 2 |
| **M35** | orphan-on-bundle-ID-change data 5 → 17 keys plus an Application Support file |
| **M30** | EntryDetailScreen 747 → 1067 lines, DeviceChassis 710 → 978 |
| **L9** | 48/30 → 72/42 public-but-app-unreferenced types — *since fixed: 42 demoted, 30 public* |
| **M5** | 1 → 3 screens paying the un-debounced search, two of them per body pass — *since fixed, all three* |
| **M28** | SAVE copies 2 → 3, section headers 4 → 6, four visual treatments shipping |
| **M23** | 1 → 2 invisible daily-return features, plus the streak |
| **L26** | unguarded asset surface 1 → 5 directories — *since fixed; all five are probed* |
| **L12** | keystroke-rebuilt subtree gained a 20-well recently-viewed strip — *since fixed* |
| **M20** | globe gained a second mount (scanner) with *no* non-globe path to a continent — *since fixed; the fallback lives in the shared screen, so both mounts have it* |

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
- [x] **M45** · robustness · the new schema stamp is reachable by *staleness*, not just corruption — a missing stamp appends a decode error unconditionally, so any build carrying pre-0.6.3 generated data raises the launch "DATA LOAD ERROR" alert on **every** start · `Sources/VinodexCore/WineDatabase.swift:463` → distinguish "no stamp / older data" from "wrong stamp" the way `tiers.json` distinguishes missing from corrupt, or fail the build instead of the launch
  - **New 2026-07-31.** Intentional per the doc comment, but it turns the alert
    H2 added into a false positive for anyone testing an older data snapshot.
  - **Resolved 2026-08-03**, by splitting the channel rather than the message.
    `WineDatabase.loadNotices` sits beside `decodeErrors` and the dividing line
    is stated once: a **fault** means the app lost data or correctness and a
    user can see it — it drives the launch `DexAlert`, `dataState` and
    `CoverageTests`; a **notice** means a documented fallback took effect and
    only a maintainer cares — it drives the DEV panel and the test suite. A
    missing stamp is a notice. A *wrong* stamp is still a fault, and so is a
    present-but-unreadable one, which the old single `catch` conflated with
    absence and reported using the absent wording.
  - **The reason a missing stamp is not evidence of damage**, which is what
    makes the downgrade safe: data older than the stamp either decodes, in
    which case nothing is wrong, or fails per-entry — and those failures are
    already faults in their own right and say far more than the stamp could.
  - **The item's other half — fail the build, not the launch — is the part that
    could have been quietly dropped.** Routing staleness out of `decodeErrors`
    removes the only runtime detector, so `#expect(loadNotices.isEmpty)` now
    pins the *bundled* data in both `DecodeRobustnessTests` and `CoverageTests`.
    Delete `schema.json` today and CI goes red instead of every launch.
  - The re-verification pass also found the alert was not the only symptom:
    `dataState` reads `decodeErrors`, so a missing stamp footnoted **every**
    legitimately-empty screen with SOME RECORDS FAILED TO LOAD — a false
    positive on a per-render path, not just at launch.
  - Now at: `WineDatabase.swift` (`loadNotices`, the stamp `switch`) ·
    `DiagnosticsReport.swift` (the `??` notice rows) · `VinodexApp.swift`
    (`Diagnostics.emit`) · `DecodeRobustnessTests.swift` (`LoaderFallbackTests`)
- [x] **M46** · robustness · H2's element-wise decode covers entries.json only — palette.json and icons.json are still whole-file all-or-nothing and drop into the empty-database fallback (alert fires, but the app is blank), and `countries.json` is swallowed **silently** by `(try? …) ?? [:]` with no decodeErrors entry at all · `Sources/VinodexCore/WineDatabase.swift:452,453,493` → give the three the same missing-vs-corrupt treatment `tiers.json` already has, and record failures in decodeErrors
  - **New 2026-07-31.** The countries case is the sharper one: it is the only
    remaining fully silent decode failure in the loader. It does not empty the
    database (country pages fall back to a derived summary), so it is Medium,
    not a re-run of H2.
  - **Resolved 2026-08-03.** `ResourceLoad<T>` names the three outcomes
    `tiers.json` has distinguished since **M1** — loaded, missing, corrupt — and
    all five optional tables run through one `loadResource(_:from:)`, so the
    loader reads as one rule instead of five coincidences. Palette and icons
    each cost only themselves: a broken colour table now leaves the catalogue on
    screen unstyled rather than emptying the database, because degraded is
    legible and blank is not. Countries keeps its documented fallback when the
    file is *absent* and records a fault when it is *broken*.
  - **The seam is the part worth knowing about.** None of these branches was
    reachable from a test — the bundle only ever offers the healthy case, which
    is why the item survived four re-verification passes. `WineDatabase(reading:)`
    takes a `ResourceReader`, `.bundled` in the app and `.fixture([:])` in
    tests, and `LoaderFallbackTests` walks all of them.
  - **One hole closed that the item did not name:** a well-formed *empty* array
    reported nothing at all, so a build with no catalogue showed NO DATA FOUND
    on every screen and never raised the alert.
  - **And one regression this fix introduced, caught before it landed.** With
    entries surviving a broken support table, `entries.isEmpty` stopped being a
    proxy for "the app is unusable" — a corrupt `palette.json` claimed *the
    catalog is incomplete* when the catalog was whole and colourless. Hence
    `DexDataState.supportTableFailed` and its own copy, and the matching branch
    in `dataAlertMessage`. A palette failure is the sharp case: `continentCountries`
    is where the globe gets its countries, so every continent page goes empty
    while the catalogue is intact.
  - **Deliberately not taken:** per-country element-wise decode for
    `countries.json`. The fallback is a derived sentence, which is why the audit
    graded this Medium — raise it separately if a single malformed blurb ever
    costs all 33.
  - Now at: `WineDatabase.swift` (`ResourceLoad`, `ResourceReader`,
    `init(reading:)`, `emptyIcons`) · `DexEmptyState.swift` (`dataState`) ·
    `VinodexApp.swift` (`dataAlertMessage`)
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
- [x] **M11** · perf · globe CADisplayLink runs at native refresh with a constant per-frame spin — 2× speed and 2× cost on 120Hz ProMotion · `Sources/VinodexUI/RetroGlobeScreen.swift:338` → time-based deltas plus `preferredFrameRateRange` 30–60
  - **Resolved 2026-07-31**, all four parts. `tick()` measures
    `link.timestamp` deltas (clamped to `maxFrameDelta` so a stall steps once
    rather than snapping a third of a turn); `autoSpinRate` and the drag
    velocity are per *second* and scaled by `dt`; damping is
    `pow(0.94, dt*60)`; the marker throttle is a `markerClock` against
    `markerInterval` rather than `frameCount % 4`; and `start()` sets
    `CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)`.
  - The fifth part the item did not name but needed: the *throw* was the last
    event's delta, i.e. "distance per touch event", which is half as large on a
    120Hz panel for the same real finger speed. It is now `delta / interval`
    from `value.time`.
  - **Verified numerically**, since nothing in this repo can run it: a
    simulation of both implementations (`swiftc`, no UIKit) over a 200pt sweep
    plus 1s of coast. At 60Hz the rewrite is identical to the old code to three
    decimals (drag 1.904 rad, coast 0.317 rad). At 120Hz the old code doubled
    the idle autospin (−3.840 vs −1.920 rad over 10s), halved the inertia
    (0.317s vs 0.633s to decay to 10%) and cut a flick's coast by more than
    half (2.226 vs 4.903 rad); the rewrite reproduces its own 60Hz numbers on
    both panels.
  - Now at: `RetroGlobeScreen.swift:373–415` (per-second constants), `:610`
    (`start()`), `:634` (`tick()`), `:743` (`drag`), `:776` (`endDrag`)
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
- [x] **M17** · layout · no orientation lock anywhere while chassis geometry hard-assumes a portrait island cutout · `xtool.yml` → declare portrait-only in the generated Info.plist
  - **Resolved 2026-07-31 — by a different mechanism than the item proposed,
    deliberately.** The `xtool.yml` route was checked first and does not exist:
    that file is not a passthrough for the generated Info.plist. Its `version:`
    is the config-schema version, and xtool 1.17 hardcodes
    `CFBundleShortVersionString` with no key to override it (KNOWN-ISSUES.md,
    "xtool stamps a fake version into every bundle") — so the app cannot declare
    its own *version* there, let alone its orientations. A speculative
    `UISupportedInterfaceOrientations` key would have read as a lock while doing
    nothing.
  - The lock is `AppDelegate.application(_:supportedInterfaceOrientationsFor:)`
    returning `.portrait`, wired with `@UIApplicationDelegateAdaptor`
    (`VinodexApp.swift:22`). That callback is consulted per window and takes
    precedence over the plist in any case, so it is the stronger of the two
    mechanisms, not a fallback. `xtool.yml` carries a comment saying so, so the
    next person does not re-open this looking for the missing key.
- [x] **M44** · contrast · selected-option labels in the SYSTEM screen changed from `.black` to `.white` on an `lcd.accent` fill — in dark mode the accent is #4ADE80 mint, so the selected tab/skin/screen-mode/text-size buttons are white-on-mint at ~1.8:1 (was ~12:1) · `Sources/VinodexUI/SettingsPanel.swift:98,224,262,288` → add a per-mode `lcd.onAccent` token (dark → .black, light → .white) and use it for all selected states
  - **Since audit:** new — this is a regression introduced by v0.3.9, not an original finding.

**UX & accessibility**

- [x] **M18** · a11y · `accessibilityReduceMotion` is checked nowhere — marquee, PulseGlow, globe autospin, and the 0.7s flip are all unstoppable · `Sources/VinodexUI/DeviceChassis.swift:652` → honor the environment flag (static marquee, frozen glow, no autospin, cross-fade)
  - **Resolved 2026-07-31**, all four named motions plus the one added since.
    The flag is read in four places: `DeviceChassis` (the flip), `PulseGlow`,
    `MarqueeBanner`, and `RetroGlobeScreen` (autospin, via
    `GlobeModel.autoSpins` — shared with **M20**). The fifth is
    `SettingsPanel`'s `DataWave`, the 2.6s counter-and-curve sweep added after
    the audit ran, which now starts settled.
  - Two traps found by the review pass, both now closed, and worth recording
    because each turned a motion fix into a *worse* result than doing nothing:
    - **The flip's two rotations are one mechanism.** `DeviceBackPlate` carries
      a compensating 180° pre-rotation so it reads the right way round after
      the container turns. Dropping only the container's rotation leaves the
      back plate permanently mirrored — the engraved VINODEX wordmark
      backwards. Both are now conditional together.
    - **`PulseGlow`'s `@State` outlives the branch swap.** Its `on` latch is
      set once by `.onAppear`; the Reduce-Motion branch does not reset it, so
      turning the setting *off* again re-mounts the animated branch, its
      `.onAppear` writes `true` over `true`, `.animation(_:value:)` sees no
      change, and the orb plus all three lamps stay stuck at full glow forever.
      The reduce branch now clears the latch.
  - **A static marquee is not a paused marquee.** Pinning the strip to shift 0
    hides the tail of any label wider than it, and these are wider: measured
    against the bundled Press Start 2P at the strip's 256pt usable width,
    `DAILY CHALLENGE` is 288pt at the default text step, and at HUGE six of the
    app's ten page titles overflow. Reduce Motion must not cost information, so
    the still form is a separate `staticLabel` — one segment, centred,
    `minimumScaleFactor(0.6)` with tail truncation behind it.
  - **L11** is now *most* of the way closed as a side effect: `PulseGlow` is
    the only `repeatForever` in the codebase and it no longer runs at all under
    Reduce Motion. What L11 still owns is the other 99% of users — it animates
    shadow *radius* rather than the opacity of a pre-blurred circle, and it
    still runs behind the flipped plate.
  - Now at: `DeviceChassis.swift:50` (chassis flag), `:120` (back-plate
    rotation), `:135–170` (flip + cross-fade), `:841` (`PulseGlow`), `:933`
    (marquee flag), `:994` (paused timeline), `:1008` (static branch), `:1052`
    (`staticLabel`) · `RetroGlobeScreen.swift:42`, `:50` (`freezesGlobe`)
    · `SettingsPanel.swift:1079` (`DataWave`)
- [x] **M19** · a11y · DexAlert dialogs are not VO-modal — focus escapes into obscured content and scrim-tap-to-cancel has no accessible equivalent · `Sources/VinodexUI/DexAlert.swift:36` → `.accessibilityAddTraits(.isModal)` on the dialog card
- [x] **M20** · a11y · continent selection needs taps on continuously moving markers plus a drag for rear continents — impossible under VoiceOver · `Sources/VinodexUI/RetroGlobeScreen.swift:355` → pause autospin at rest / add a static continent-list fallback
  - **Resolved 2026-07-31**, both halves. Autospin is off under VoiceOver *and*
    under Reduce Motion (`freezesGlobe`, shared with **M18**) — a drag still
    spins the globe in both cases, since what has to stop is the movement
    nobody asked for, not the control. The fallback is a `CONTINENT LIST`
    toggle under the globe and a flat list of all six, opened by default when
    VoiceOver is running.
  - **The fallback lives inside `RetroGlobeScreen`, deliberately**, which is
    what fixes the second mount the item calls out: the scanner's globe step
    reuses the screen with `showsSearch: false`, so anything added to the
    scanner instead would have left the route mount unfixed, and anything added
    to the route would have left the scanner with no non-globe path at all.
    One control, both mounts, no per-caller flag.
  - Rows are built from `model.markers`, not `Continent.allCases`, so a row's
    colour swatch is the same colour as the marker it stands in for by
    construction — and the screen keeps its single `WineDatabase.shared` read
    rather than adding one (**M27**).
  - Two smaller halves: markers off the front face were still in the
    accessibility tree, so VoiceOver offered six continents of which only the
    two or three facing you did anything (`.accessibilityHidden(!visible)`);
    and `Continent.displayName` is new in VinodexCore so the list, the
    VoiceOver labels and the scanner's step title all take the name without the
    marker plate's line break, instead of the three of them stripping `\n` by
    hand. It is Linux-testable and pinned by `ContinentTests`.
  - The 12pt gutters beside the list card were passing touches through to live
    marker buttons underneath — a marker plate can reach the viewport edge —
    so the overlay is full-bleed with a `contentShape`.
  - Now at: `RetroGlobeScreen.swift:50` (`freezesGlobe`), `:97` (overlay),
    `:153` (`listToggle`), `:181` (`continentList`), `:297` (marker a11y),
    `:458` (`autoSpins`) · `WineDatabase.swift:28` (`displayName`)
- [x] **M21** · a11y+discoverability · the device flip is an unhinted 1s long-press on a non-button orb; the back plate is unreachable via VoiceOver · `Sources/VinodexUI/DeviceChassis.swift:148` → settings "About / flip" row plus an accessibilityAction on the orb
  - **Was unchanged @b48ad20** — neither half landed. Only delta then: the hold
    shortened 2.0s → 1.0s and gained `Haptics.orbPress()` feedback.
  - **Resolved 2026-08-01.** Both halves, plus the way back out, which the item
    did not ask for and needed: the plate's own swipe-to-return is the one
    gesture VoiceOver reserves for itself, so a VoiceOver user reaching the back
    could not have left it.
    - `DeviceChassis.swift:292` — the orb becomes one accessibility element
      with `.isButton`, a label, a hint naming what the gesture does, and an
      `.accessibilityAction`. The long-press easter egg is untouched.
    - `DeviceChassis.swift:123` — the back plate gains `.accessibilityAction(.escape)`
      (the two-finger scrub) and a named rotor action.
    - `ChassisFlipRouter` (new, Core) + `SettingsPanel.swift` ABOUT section —
      a signposted "TURN THE DEVICE OVER" row. A registration seam on the same
      pattern as `ScannerBackRouter`, because `isFlipped` is view-local `@State`
      driving a 0.7s rotation and a midpoint face swap; lifting it into a store
      would give one animation two owners.
- [x] **M48** · a11y · WalkthroughScreen's DeviceDiagram is the entire instructional payload ("this part lights up"), conveyed purely by opacity/glow, with no `accessibilityHidden` and no label — and it contains real `Text` and SF Symbols for *mock* chrome (gearshape, magnifyingglass, chevron.left, person.crop.circle, house.fill), so VoiceOver reads fake buttons interleaved with the real ones; the step dots carry no `accessibilityValue`, so "step 3 of 8" is never announced · `Sources/VinodexUI/WalkthroughScreen.swift:45` (diagram), `:61` (step dots), `:307–443` (mock chrome) → mark the diagram `.accessibilityHidden(true)` with a text equivalent per step, and give the dots an `accessibilityValue`
  - **New 2026-07-31.** The onboarding screen is currently the *least* navigable
    surface in the app under VoiceOver, which is the worst place for it.
  - **Resolved 2026-08-03**, by a different mechanism than the remedy line
    proposed in both halves.
  - **Not `.accessibilityHidden(true)` on the diagram.** Hiding it suppresses
    the mock chrome and the lesson together, leaving eight paragraphs of "this
    part lights up" pointing at nothing. `.accessibilityElement(children: .ignore)`
    removes the ten child elements — which is the only thing `accessibilityHidden`
    was wanted for — and the label carries the payload:
    `Highlight.diagramDescription(isolated:)` in **Core**, beside the step
    definitions, where a test can reach it. A `switch` with no `default`, so a
    thirteenth highlight cannot be drawn without someone deciding what it sounds
    like. Applied inside `DeviceDiagram.body`, not at the call site, so the
    component cannot be mounted unlabelled.
  - **`.accessibilityValue` on the step indicator is a silent no-op**, which is
    the item's literal remedy. The indicator is `Capsule()` shapes; shapes
    generate no accessibility element, so the `HStack` generates none either and
    a value modifier applied where no element exists is dropped without a
    warning. `.accessibilityElement` has to come first. Nothing in this repo can
    tell the two apart — it compiles and ships mute.
  - **And a correct value would still never be spoken.** VoiceOver focus stays
    on NEXT across a step change, and a value change on an unfocused element is
    silent. The ordinal is therefore on the *copy card*, which takes
    `@AccessibilityFocusState` on every step change — deterministic, where an
    announcement notification would race the one SwiftUI already posts for the
    swapped subtree.
  - **Corrections to the item text.** The diagram contains **zero** `Text` — every
    `Text` in the file is real copy — so "real `Text` … for mock chrome" is
    wrong; the collision is eight `Image(systemName:)`, which is **H10** unfixed
    sitting on the same screen as H10 fixed. And `isolated` is dead: no shipped
    step sets it, so both doc comments claiming "the opening step hides
    everything that is not its subject" have been false since v0.5.4 and are
    corrected here — a description written from that stale comment would have
    told a VoiceOver user the screen was blank.
  - Now at: `Walkthrough.swift` (`diagramDescription`, `CaseIterable`) ·
    `WalkthroughScreen.swift` (diagram label, progress element, focus) ·
    `ToolsTests.swift` (`WalkthroughTests`)
- [x] **M49** · a11y · **H11**'s residual: the app's type axis spans 0.85–1.15 against the system's 0.82–3.12, and the size floor is nominal rather than rendered — at the shipped SMALL step (0.85) a 10pt label still draws at 8.5pt, under Apple's 11pt guidance · `Sources/VinodexCore/TypeScale.swift:114` (`nominalFloor`) + `TextScale.huge` → make the floor a rendered one and add a step above 1.15, which needs the fixed frames below re-tuned first
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
  - **Resolved 2026-08-03, both halves — and the blockers turned out to be
    arithmetic rather than judgement, which is what made it doable here.**
    `TypeScale.renderedFloor = 11` is the rendered floor, and the top step goes
    past 1.15 — **by widening `huge` to 1.30 rather than by adding a fourth
    step**. All four fixed frames now derive from the same resolver the type
    does, which is what made either possible.
  - **There was a fourth blocker the item did not list, and it was the one M50
    had already written down.** `DexSearchBarShell`'s `.frame(height: 46)`
    against a field of `26f + 8` binds at **f = 1.462**. M50 recorded that as a
    ceiling "M49 cannot raise the factor past without a test saying so" — the
    answer was not to respect it but to remove it: the literal derived from the
    same axis it was meant to bound. The test that stated the two ceilings now
    states that the shell contains its field at every step instead.
  - **The tightest ceiling was `StatBar`, at f = 1.206, and that is why the axis
    stopped at 1.15.** VT323 is monospaced with an advance of exactly 0.4 em —
    read out of the shipped `.ttf`'s `hmtx` table, not estimated — so AROMATICS,
    nine characters at `mono(19)` with 1.5 tracking, wants `9 × (7.6f + 1.5)`
    points against a hard 96pt well. `TypeScale.monoRunWidth` / `retroRunWidth`
    put that arithmetic in Core where a test can reach it, and the well is
    `max(96, needed)` — so it is **provably unchanged at SMALL, LARGE and HUGE
    (71.6 / 81.9pt against 96) and grows at HUGE (102.4pt)** — 1.30 is past the
    1.206 ceiling, so this is the frame that proves the derivation was
    load-bearing rather than tidy. Pinned at 96 it would clip AROMATICS on every
    grape page at the top step. The search shell is unchanged at all three
    steps, since the field does not reach 46 until 1.462.
  - **The globe markers were the one blocker with no computable answer**, so
    they got a measured one: `.fixedSize()` is gone in favour of a 38%-of-width
    cap with `lineLimit(2)` and `minimumScaleFactor(0.6)`. Unbounded, SOUTH/
    AMERICA's plate goes 131 → 188pt across the four steps, which is 55% of a
    340pt LCD — two adjacent markers simply grow into each other, and nothing
    reflows them because they are absolutely positioned by projection. The cap
    binds at HUGE only (188pt unbounded, 55% of a 340pt LCD, capped to 153).
  - **`ChipFlow` and `FlowLayout` had a real bug, not just a ceiling.** Both
    correctly refuse to break on the first chip of a row — a chip wider than the
    container has to go somewhere — but then placed it at its *natural* width,
    past the container edge, where `DeviceChassis`'s clip made it invisible
    rather than obviously wrong. Both now propose the container width, in
    `sizeThatFits` as well as `placeSubviews` so the measured and placed heights
    cannot disagree.
  - **What the rendered floor costs, stated rather than buried.** At SMALL every
    nominal from 10 to 12 now draws at 11 — three authored sizes collapse onto
    one, and the 41 call sites at `retro(10)`/`retro(11)` grow by up to 29%.
    That is the trade: a ≤1.7pt distinction nobody can perceive at those sizes,
    for every label in the app clearing Apple's legibility minimum. Above 12
    nothing moves at any step, and at HUGE the floor binds on nothing.
  - **Three steps, not four — a UI/UX call by the maintainer, taken after a
    fourth had been built and measured.** A fourth button splits the TEXT SIZE
    row into ~69pt columns against a five-character SMALL wanting 84.5pt, so it
    only fitted by shrinking the labels: a control you squint at to choose a
    text size. The range went into `huge` instead. That does re-size the app for
    anyone already on HUGE, which is normally the thing `small`/`large` are
    frozen to prevent — acceptable only because `huge` is three days old (0.6.4)
    and the build is not publicly distributed. **Do not do the same to `small`
    or `large`.**
  - **1.30 is a judgement and is labelled as one.** With the frames derived there
    is no computable ceiling left — what remains is whether the *tile* layouts
    hold, and nothing in this repo can render a tile. 1.30 sits inside the range
    `UIScale` already ships at and stays under the tightest ceiling that existed
    before this pass (1.462, the search shell), so it is safe even if one of the
    four fixes is wrong. The system's range still reaches 3.12; this narrows the
    gap without pretending to close it. **A device pass on the tile layouts at
    HUGE is the one thing still outstanding**, and it is the check the item
    asked for.
  - **`StatBar`'s well now genuinely moves**, which is the proof the derivation
    was load-bearing rather than tidy: 1.30 is past the 1.206 ceiling, so the
    label well grows 96 → 102.4pt at HUGE. Pinned at 96 it would have clipped
    AROMATICS on every grape page at the top text size. SMALL and LARGE are
    untouched. The globe-marker cap now binds at HUGE too (188pt unbounded, 55%
    of the LCD, capped to 153).
  - The first-launch seed is unchanged — the whole accessibility band still
    seeds HUGE, because HUGE is still the top. What changed is what HUGE is
    worth, so the same seed hands an accessibility user meaningfully more.
  - Now at: `Sources/VinodexCore/TypeScale.swift` (`renderedFloor`,
    `monoRunWidth`, `retroRunWidth`, `TextScale.maximum`) ·
    `CatalogScreen.swift` (`StatBar.labelWidth`, `FlowLayout`) ·
    `ChipFilterScreen.swift` (`ChipFlow`) · `RetroGlobeScreen.swift`
    (`markerWidthShare`) · `DexSearchField.swift` (`shellHeight`) ·
    `Tests/VinodexCoreTests/TypeScaleTests.swift`
- [x] **M50** · a11y · `DexSearchField`'s UIKit path builds its `UIFont` from the raw `fontSize` with no `TextScale` term at all, so the live search field ignores the app's only text-size control — it draws at 26pt while the `DexFont.mono(26)` placeholder beside it draws at 22.1pt, an 18% mismatch under a doc comment claiming the two are "indistinguishable" · `Sources/VinodexUI/DexSearchField.swift:87` → route it through `DexFont.resolvedSize(_:)`, and derive the `.frame(height:)` at `:172` from the result instead of pinning 34
  - **New 0.6.4.** Found while doing **H11** and deliberately left out of it: the
    fix changes the size of a live control on four screens (`DexSearchBar`, plus
    hand-pinned frames at `RatingPrompt.swift:76` and `BookmarksScreen.swift:429`
    that would desynchronise), and a `UIViewRepresentable` cannot see a SwiftUI
    `.dynamicTypeSize` cap either — so it wants its own pass with a device.
    Unchanged by H11: the field was frozen before and is frozen now, just at the
    wrong number.
  - **Resolved 2026-08-03.** `uiFont` builds through `DexFont.resolvedSize(_:)`,
    and the three hand-pinned frames come from one
    `DexSearchField.height(nominal:atLeast:)`. `updateUIView` re-applies the
    font too, guarded — `applyColors` already rebuilt the placeholder from
    `uiFont` on every update, so leaving the face to `makeUIView` alone let the
    placeholder and the typed text disagree about size.
  - **The mismatch was worse than the item states: it reverses sign.** 26pt
    against 22.1 is **+17.6%** at SMALL — which is the shipped default — 0% at
    LARGE, and **−13.0%** at HUGE, where the live field is the *smaller* of the
    two. Same-card proof, no cross-screen comparison needed: `RatingPrompt`'s
    entry name drew at 17.0pt while the note field twenty lines below drew at
    20.0.
  - **The trap is the half that looks skippable.** Scale the font, leave
    `.frame(height: 34)` alone, and it is correct on every device today — VT323's
    line height is exactly 1.0 em, so 29.9pt at HUGE still fits. It breaks the
    moment the text axis passes `34/26 = 1.308`, which is precisely what **M49**
    proposes. Hence `+ 8`, which is not taste: it is `34 − 26`, the slack the bar
    has always carried, and padding around one line does not scale with type.
  - **Two ceilings written down for M49**, and asserted in `TypeScaleTests` so it
    cannot raise the factor without a test saying where it stops: the inner field
    clears `DexSearchBarShell`'s 46pt capsule while `26·f + 8 ≤ 46` (**f ≤ 1.462**),
    and the profile name row stays at 44 while `26·f + 8 ≤ 44` (**f ≤ 1.385**).
    Measured outcome: the field grows 3.9pt at HUGE only, and `RatingPrompt`'s
    40pt well never moves — it takes the floor rather than shrinking at SMALL,
    because the field is the tap target there and trading a type bug for a
    touch-target one is not a fix.
  - Now at: `DexSearchField.swift` (`defaultFontSize`, `uiFont`, `height(_:atLeast:)`)
    · `BookmarksScreen.swift` · `RatingPrompt.swift` · `TypeScaleTests.swift`
- [x] **M22** · ux · the PRO alert's UNLOCK button silently dismisses (no storefront exists) — indistinguishable from a broken purchase · `Sources/VinodexApp/VinodexApp.swift:78` → "COMING SOON"/OK until IAP exists
  - **Resolved @0a446d3** (v0.4.1.5). `UpgradePrompt`'s UNLOCK now calls `access.grant(offer)` (persisted via `AccessStore`) and continues navigation — a real entitlement grant, though a payment step is still to come.
- [x] **M23** · ux · Grape of the Day is buried inside the settings screen — the daily-return feature is invisible from the main menu · `Sources/VinodexUI/SettingsPanel.swift:131` → surface it on the main menu or as an orb badge
  - **Resolved 2026-08-01** — a TODAY strip under the tile grid
    (`MainMenuScreen.swift:60`, `:118`) carrying both daily features and the
    streak: WHAT'S THAT? → `.dailyGrape`, CHALLENGE → `.dailyChallenge`, with a
    tick when `StreakStore.isTodayDone()` and a flame badge when the streak is
    alight. All three were previously invisible from the screen you land on —
    the streak worst of all, since it was printed only on the profile.
  - A strip rather than a fifth tile, per the note above that the grid has no
    free slot: the four categories are what the app *is*, and demoting one for
    a minigame trades a worse problem for this one. The tiles are
    `maxHeight: .infinity`, so its 54pt is the only thing they give up. In the
    LCD's own livery, not painted plastic — six equal bright tiles would say
    these rank with GRAPES and REGIONS, which they do not.
  - No "done today" on the grape half: its reveal is session state cleared on
    Home (`DailyGrapeScreen`), so there is no honest flag to show.
  - **Since audit:** v0.3.9 made settings a full SYSTEM screen, but the entry point is unchanged.
  - **Worse @b48ad20.** Still behind the cog, and now **two** daily-return
    features (WHAT'S THAT…? and DAILY CHALLENGE) plus the streak are invisible
    from the main menu instead of one. Note the grid at
    `MainMenuScreen.swift:30–58` has no free slot, so this is a small layout
    decision, not a one-liner.
  - Now at: `MainMenuScreen.swift:29` · `ToolsScreen.swift:84` · `SettingsPanel.swift:57`
- [x] **M24** · ux · the blanket `.transaction { $0.animation = nil }` strips in-screen animations (expander, daily reveal), not just nav swaps · `Sources/VinodexApp/VinodexApp.swift:71` → scope `Transaction(animation: nil)` to path mutations only
  - **Was worse @b48ad20.** Untouched, and silently nulling **17** in-screen
    `withAnimation` calls instead of 2.
  - **Resolved 2026-08-01**, exactly as prescribed: the modifier is gone and all
    three `path` writes are wrapped — `push` (`VinodexApp.swift:377`), `goBack`
    (`:410`), `goHome` (`:423`). `Transaction.instant` is a named static rather
    than `Transaction(animation: nil)` spelled three times, so the three sites
    read as one rule instead of three coincidences.
  - The wrap has to be explicit even though nil is the default: a caller already
    inside `withAnimation` would otherwise donate its animation to the screen
    swap, which is the case the old blanket modifier was really defending
    against.
- [x] **M25** · a11y · the destructive remove-bookmark button is a 26×26pt target sitting on a tappable row · `Sources/VinodexUI/BookmarksScreen.swift:255` → 44pt hit area via frame/contentShape, keep the 26pt visual

**Architecture**

- [x] **M27** · di · leaf views hard-read `WineDatabase.shared` despite the injectable init (LinkedRow, FlagImage, ContinentScreen hero) — nothing is exercisable against a fixture DB · `EntryDetailScreen.swift:690` + `EntryVisual.swift:314` + `ContinentScreen.swift:76` → inject via environment/params and drop the `.shared` reads
  - **Worse @b48ad20 — and it escaped the UI module.** 13 singleton reads at the
    audit commit, **21 at HEAD** (17 in VinodexUI). Only the ContinentScreen hero
    read was incidentally removed. The new one that matters:
    `ChipFilter.options(for:)` in **VinodexCore** reads
    `WineDatabase.shared.searchableCountries`, and `ToolsTests` iterates all
    facets — so a Core unit test now silently asserts against the *production
    bundled database* instead of a fixture. That is a boundary violation, not
    just another call site, and it is a two-line fix (pass the country list in).
    **Do that one first** — it is the highest value per line in this group.
  - **The Core leak is closed (2026-08-01); the UI half is not.**
    `ChipFilter.options(for:)` now takes `countries:`, with
    `WineDatabase.chipOptions(for:)` / `.allChipOptions` as the call shape the
    app uses (`ChipFilter.swift:190`). `VinodexCore` holds **zero**
    `WineDatabase.shared` reads. `ToolsTests` asks the database it declares
    rather than being handed the bundled one behind its back — the assertions
    are unchanged, but they are now honest about what they assert against, and
    pointing them at a fixture is a one-line change instead of impossible.
    `ChipFilterScreen.allOptions` stopped being `static` for the same reason:
    the COUNTRY chips are a property of the data loaded, not of the type.
  - **Still open:** the 25 UI-side reads — `EntryDetailScreen` (LinkedRow),
    `EntryVisual` (flags), `SettingsPanel`, and the per-screen
    `private let db = WineDatabase.shared`.
  - **Resolved 2026-08-03.** **23** executable reads (not 25 — the count was
    re-derived; three of the 26 grep hits were comments), now **2**. The
    mechanism is a defaulted `db: WineDatabase = .shared` init parameter, which
    is already this repo's convention — `CatalogScreen`, `DexEmptyState`,
    `DiagnosticsReport` and `DexAssetAudit` all had it — rather than a SwiftUI
    `EnvironmentKey`. The environment loses on three counts: it is unreadable in
    `init`, and `ChipFilterScreen`/`CountryScreen`/`RootView` read the database
    there *on purpose* (moving the seed to `onAppear` reopens the first-frame
    "0 MATCHES" flash M5 closed); it cannot reach `FlagLoader`, `EntryVisualCache`
    or `GlobeModel`, which are not `View`s; and `.id(…)`-keyed screens re-run
    `init` on every TEXT SIZE change, which is exactly when an environment value
    is invisible and a parameter is correct.
  - **The trap, which the obvious fix walks straight into.** `EntryVisualCache`
    and `FlagLoader` are process-wide singletons keyed on `entry.id` and on
    country. Threading `db:` through every screen while leaving those keys alone
    makes injection *look* done and silently serves the first database's answers
    to the second — invisible to every check this project runs, in the one
    module no test can execute. So the caches were re-keyed rather than
    parameterised: `EntryVisualCache` is two-level on `ObjectIdentifier(db)`,
    and `FlagLoader` now takes a **slug** and caches on the filename it loads,
    which is the right key regardless of DI.
  - **Two live bugs fell out of the enumeration**, neither of them in the item:
    `EntryVisual.grapeVisual(_:db:)` received an injected `db` and called
    `grapeWellColor` without forwarding it, and `EntryVisualCache.visual(for:)`
    dropped it the same way — so an injected database got the bundled one's well
    colours. Plus **5 implicit reads** through `DexEmptyState`'s defaulted
    argument, which would have survived a naive fix and left the item falsely
    closed.
  - **Corrections to the item text.** Its `ContinentScreen.swift:76` hero read
    does not exist and never did — that screen reaches the database only through
    `EntryIconWell`. Both other anchors were stale.
  - **Residual, stated rather than claimed.** The two remaining `.shared` reads
    are `VinodexApp`'s M6 warm-up (whose whole purpose is forcing `swift_once`
    off the main thread) and `Diagnostics.emit`; `RootView` is the composition
    root and takes `.shared` as its default. Nothing in the app injects a
    *different* database — the deliverable is exercisability, not runtime
    substitution — and with no UI test runner here, "exercisable" means the seam
    type-checks, not that an assertion has run through it.
  - Now at: 29 `= .shared` seams across VinodexUI/VinodexApp ·
    `EntryVisual.swift` (both loaders) · `RetroGlobeScreen.swift`
    (`GlobeModel.init(db:)`) · `EntryDetailScreen.swift` (`LinkedRow`,
    `FlagSwatch`) · `DeviceBackPlate.swift`
- [x] **M28** · duplication · hero panel, SAVE button, and section header are copy-pasted across 4 screens, and drift already shipped (EntryDetail hero still dark-theme) · `EntryDetailScreen.swift:104` + `CountryScreen.swift:72` + `StateScreen.swift:49` + `ContinentScreen.swift:70` → extract DexHero/DexSaveButton/DexSection
  - **Was worse @b48ad20 on every axis.** SAVE copies 2 → 3; section-header
    copies 4 → 6, with **four distinct visual treatments** shipping and
    `StateScreen` inlining one; hero 4 identical copies; screens added since had
    copied rather than reused (`PassportScreen`).
  - **Resolved 2026-08-01.** All three extracted, `DexHero.swift` and
    `DexSection.swift`, net −107 lines across the six screens.
    - **`DexHero`** — the four heroes agreed on every number (14pt stack, 18pt
      vertical padding, 34pt grid at half opacity, 4pt rule, −14pt bleed) and
      differed only in the portrait, so that is the one thing passed in.
      `EntryDetailScreen` keeps its own `bookmarkButton` in the actions slot: an
      entry carries three shelves and a rating prompt off the third.
    - **`DexSaveButton`** — the three copies were byte-identical apart from
      which id they toggled.
    - **`DexSection`** — six copies in four treatments collapse to two declared
      *ranks*: `.block` for a section inside a page, `.screen` for a heading
      over a whole screen's content. Three type sizes become two.
  - **The one real bug in the pile:** Entry-detail and continent headings ruled
    themselves with a hardcoded `#166534`, a fixed dark green that disappears
    against a light theme — **H5**/**M14**/**L30** all over again. Every rule
    now comes off `lcd.accent` and follows the theme.
  - `CatalogScreen.section` is deliberately **not** converted: it is a bordered
    card on `lcd.surface`, a different component that happens to share the word.
    `BookmarksScreen.shelfHeader` likewise stays — it is a bare header whose
    rows are siblings, not children, so folding it in would mean restructuring
    the list for no gain.
- [x] **M29** · testability · pure logic lives in the untested UI module (Palette.resolve color mapping, grapeWellColor/styleTone keyword heuristics) · `EntryTileView.swift:98` + `EntryVisual.swift:72` → move to Core returning hex strings and test beside FilterTests
  - **Unchanged @b48ad20.** `Palette.resolve` is pure Core-type table lookup with
    6 call sites and could move verbatim; `grapeWellColor`/`styleTone` need their
    return type changed from `Color` to a hex `String` to cross the boundary.
  - Now at: `EntryTileView.swift:98` · `EntryVisual.swift:87` (grapeWellColor),
    `:113` (styleTone)
  - **Resolved 2026-08-03** into `Sources/VinodexCore/EntryPalette.swift`. All
    three functions were already pure over Core-only types, so this was a file
    move rather than a refactor — `Palette.resolve` cut and pasted verbatim, and
    the two heuristics split into `styleToneKey(for:)` (the ladder, which needs
    no `Palette` at all) and `grapeWellFallbackHex(style:body:)`, recombined by
    `Palette.grapeWellHex(style:body:)`. The precedent it follows is
    `GrapeArt.leafHex(rarity:)`: hex rather than `Color`, because the rule is
    the testable part.
  - **The one trap was case.** The ladder's literals were uppercase and every
    value in `palette.json` is lowercase — and `bright red`'s tone is `#dc143c`,
    the *same colour* the ladder returned as `#DC143C`. `Color(dexHex:)` parses
    case-insensitively so nothing rendered differently, but the first consumer
    to compare strings would have reported two identical answers as disagreeing.
    Every hex leaving Core is now lowercase, and a test says so.
  - **What the coverage actually buys**, beyond the item's ask: a twelve-branch
    ladder over twenty-four literal spellings is hand-written while `styleTones`
    is *generated*, and nothing could notice them parting company. Two tests do
    now — every key the ladder emits exists in the generated table, and every
    authored `grapeStyle` in the shipped data resolves or is the one known
    exception (`Sparkling Red`, which is what the fallback exists for).
  - Now at: `Sources/VinodexCore/EntryPalette.swift` ·
    `Tests/VinodexCoreTests/EntryPaletteTests.swift`
- [x] **M30** · decomposition · 745-line EntryDetailScreen and 722-line DeviceChassis each bundle 8+ types with clean seams · `EntryDetailScreen.swift` + `DeviceChassis.swift` → split at type boundaries
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
  - **Resolved 2026-08-03**, taking the item's own correction seriously and
    splitting **four** files rather than two — the note above says DexTheme and
    SettingsPanel "belong in it", and they were the two largest in the module.
    Nine new files, all pure code motion:

    | File | Was | Now | Moved to |
    |---|---:|---:|---|
    | `DeviceChassis.swift` | 1220 | **735** | `ChassisButton.swift` (130) · `ChassisEffects.swift` (155) · `MarqueeBanner.swift` (230) |
    | `EntryDetailScreen.swift` | 1079 | **574** | `EntryDetailSections.swift` (439) · `EntryDetailRows.swift` (119) |
    | `DexTheme.swift` | 1661 | **499** | `ScreenModes.swift` (~455) · `ChassisSkins.swift` (~735) |
    | `SettingsPanel.swift` | 1617 | **1250** | `SettingsControls.swift` (~280) · `SavedDataActions.swift` (~200) |

  - The effects cluster the item named as the cheapest seam is
    `ChassisEffects.swift`, and it was: four types that draw *onto* the LCD and
    know nothing about the chassis around them.
  - **EntryDetailScreen is not a type-boundary split, because the item's premise
    is wrong for it** — four top-level types, as the note above already
    corrected, and one ~930-line `View`. The seam that does exist is the
    fourteen `…Section(_:)` builders: they reach for exactly four things from
    the screen around them (`entry`, `db`, `lcd`, `onSelectRelated`) and one
    piece of `@State` nothing else touches, so `EntryDetailSections` takes its
    dependencies explicitly rather than inheriting a file's `private` scope.
    `expandedSections` moved with the code that is its only reader.
  - **Two things the move surfaced, both of which are the point of doing it.**
    `EntryDetailSections` needed one call to the parent's two-line
    `chip(_:_:key:)` shorthand — spelled out as `TileChip` rather than widening
    the parent's access, so the new file depends on nothing private. And
    `DataWave` was `private`, which at file scope meant "SettingsPanel.swift" —
    exactly the coupling the split removes, so it is `internal` now with a note
    saying why. Both were caught by `scripts/typecheck-ios-surface.sh`, which is
    the only local check that sees any of this.
- [ ] **M31** · assets · LogoMark and its 139KB vinodex-logo.png are fully dead since the cog replaced the wordmark · `Sources/VinodexUI/DeviceChassis.swift:692` → delete the view and the Logo/ asset
  - **Unchanged and still fully dead @b48ad20** — LogoMark gained no caller
    despite the v0.5.6 skins/emblems work, and the 136 KB PNG ships in every
    build. Deleting `DeviceChassis.swift:959–976` and `Resources/Logo/` removes
    both with no other edits. Trivial; take it with any other sitting.

**Tests & CI**

- [x] **M32** · tests · DailyGrapeScreen's actual path `DailyPick.entry(in:)` (rotation, fallback, tier filter) has zero coverage — tests only exercise `.grape` · `Tests/VinodexCoreTests/DailyPickTests.swift:28` → add entry/category rotation and fallback tests
  - **Mostly done @b48ad20.** `DailyRevealTests` covers rotation, the free-tier
    question, every-entry coverage, and the cursor overload the screen actually
    calls. **Remaining:** the empty-category fallback (`DailyPick.swift:58–64`,
    including the `return nil`) has zero coverage because every test runs against
    the full shared database — it needs a fixture — and the pre-epoch/negative-day
    case is still unpinned.
  - Now at: `MinigameTests.swift:186` (@Suite), `:205`, `:217`, `:232` ·
    `DailyPick.swift:50` (entry(for:))
  - **Resolved 2026-08-03**, both halves. `DBFixture`
    (`Tests/VinodexCoreTests/DatabaseFixture.swift`) is the fixture database the
    item said this needed, and five new tests in `DailyRevealTests` reach the
    `return nil` and the `continue` that no test could touch before: an empty
    database, a database with entries but none in the three rotated categories,
    and one surviving category carrying every day of the rotation.
  - **The fixture takes JSON, not Swift literals, and there is no choice about
    it.** `GrapeEntry` and its four siblings each declare `init(from:)` in the
    type body, which suppresses the synthesised memberwise initialiser — so a
    `WineEntry` cannot be constructed by hand at all. Going through
    `WineDatabase.decodeEntries(from:)` is the app's real load path, so a fixture
    that stops decoding is one that has drifted from the schema, which is the
    behaviour you want. It has one guard that must not be dropped:
    `decodeEntries` *records* a malformed record rather than throwing, so a
    missing non-optional key would otherwise yield a silently empty database and
    every assertion above it would pass for the wrong reason.
  - **The audit's "pre-epoch case is still unpinned" was half wrong** —
    `DailyPickTests.preEpoch` already pinned `grape(for:)`. What was genuinely
    unpinned, and now is: `dayIndex`'s value across the epoch, `category(for:)`
    on a negative index, both `entry(…)` overloads pre-epoch, and a negative
    *cursor*, which `RevealCursor` can produce because `advance()` wraps.
  - One test pins the fallback *order* — `[wanted] + categories.filter { … }`,
    the rotation's order rather than the database's — with the fixture loading
    the style first, so a naive "take the first entry" implementation fails it.
- [x] **M33** · tests · filter branches `.type`/`.tasting`/`.soil`/`.system` are untested (all reachable from header tiles); styleClass/colorType keyword precedence unpinned · `Sources/VinodexCore/EntryFilter.swift:105` → add branch and precedence tests
  - **Unchanged @b48ad20** — none of the four branches is exercised by any test
    and precedence has zero coverage. Two refinements: `.soil` is no longer
    constructed anywhere in Sources (so it is dead-or-untested — decide which),
    and `.type`'s DUAL branch plus `.system`'s style-class inference gained
    behaviour in 0.6.2 that is still unpinned.
  - **Resolved 2026-08-03.** Eight tests on `FilterTests` and a new
    `StyleInferenceTests` suite. `.soil` was kept rather than deleted — the
    enum is `Hashable` and `storageKey`-encoded, 36 shipped regions carry a
    `details.soilType` for it to match, and re-deriving the substring-vs-equality
    semantics when the GEOLOGY chip ships costs more than the eight lines a
    fixture test costs. `DBFixture` is the only way to reach it, since no
    shipped construction site does.
  - **The pass found two live bugs, and both are now fixed** (2026-08-03,
    same day — they were pinned as known-broken first, then taken).
  - **Bug 1: three COLOR chips opened onto nothing.** A style's COLOR tile
    emits `.type(color.rawValue)`, and `GrapeColor` has exactly two cases — so
    `.type("ROSE")` and `.type("ORANGE")` matched **zero grapes**, and `Rosé`
    and `Orange Wine` had opened onto an empty list since 0.6.2. Same defect D2
    fixed for DUAL and left unfixed for these. **The mapping was not a
    judgement call — it is authored in the shipped descriptions**: Rosé is
    *"pink wines made from **red grapes** with minimal skin contact"*, Orange
    Wine is *"**White grapes** vinified like red wine, with extended skin
    contact"*. So ROSE resolves to the red grapes and ORANGE to the white ones,
    via `StyleColorType.grapeColor`, which is where the mapping lives so the
    tile and the filter cannot disagree.
  - **Bug 2, found while fixing the first, and worse because it was *visible*
    rather than empty: `Prosecco` was labelled a rosé.** `colorType` matched
    substrings, and "rose" sits inside "p-*rose*-cco" — so Italy's best-known
    sparkling **white** wine carried a ROSE chip on its own detail page, in the
    chip text, and in the filter behind it. It now uses `matchesWholeTerm`, the
    same whole-term test `.origin` has always used, which also collapses
    hyphens so `Full-Body Red` keeps resolving. Prosecco falls to `DUAL` — the
    documented meaning of "the name names no colour" rather than a claim about
    the wine. Inferring it properly would mean reading the style's
    `notableGrapes` (Glera, white), which is a larger change and is **not**
    done here.
  - The test that had pinned the emptiness now pins the fix, and one more walks
    every shipped style asserting **no COLOR chip opens onto an empty list** —
    a per-name test would have missed the next one. Result: `Rosé` → 70 red
    grapes, `Orange Wine` → 76 white, `Prosecco` → DUAL, zero empty chips
    across all 31 styles.
  - **Two corrections to the item.** `GrapeEntry.wineType` and `grapeStyle` are
    identical for all 146 grapes in the shipped data, so `EntryFilter.swift`'s
    `wineType` clause is unreachable in practice and no test can honestly claim
    to distinguish them. And `.system` on a *style* no longer compares the raw
    classification at all — Champagne's is the near-universal "STYLE" while its
    chip says ORIGIN — so the test asserts the raw comparison **fails**, which
    reads backwards until you know why.
  - One test pins that the indexed path (`entries(matching:)`, the load-time
    index from **M5**) and the unindexed one (`[WineEntry].apply`) agree on all
    nine branches. Nothing had been comparing them.
- [x] **M47** · tests · two Core modules added/reworked since the audit have **zero** test references: `SearchState.swift` (`SearchStateStore`, per-listing query+anchor persistence, the composite `key(categories:filter:)`, and `EntryFilter.storageKey`) and `DexRoute.swift` (`SettingsSection`, `DexRoute.title`/`marqueeSymbol`, the `EntryCategory`/`WineEntry` extensions) · `Sources/VinodexCore/SearchState.swift:79,86` + `Sources/VinodexCore/DexRoute.swift:113,167` → pin the storage-key encoding and the route vocabulary
  - **New 2026-07-31.** `SearchState.swift:87–91` explicitly documents that the
    key is spelled out so stored queries are *not* silently orphaned when display
    copy changes — precisely the invariant a test should pin, and nothing does.
    It compounds **M33**: the same nine filter cases are untested in both their
    predicate *and* their key encoding. `DexRoute` is the app's whole navigation
    vocabulary, pure and non-UI, sitting in Core untested.
  - Everything else added since `fb5dcf2` does have coverage, including
    `Entitlements` — these two are the gaps.
  - **Resolved 2026-08-03** in `Tests/VinodexCoreTests/RouteAndSearchStateTests.swift`:
    `SearchStateTests` (8 tests) and `DexRouteTests` (5). The storage-key test
    is the one the item asked for and asserts the invariant the doc comment
    states — `storageKey != String(describing:)` is checked directly, since
    `String(describing: EntryFilter.origin("France"))` is `origin("France")`
    and a naive switch to it would silently orphan every stored query.
  - `everyRouteIsLabelled` walks all **28** constructible routes. Both
    properties are exhaustive switches, so a new case cannot compile without an
    answer — but an *empty* answer compiles fine and renders as a blank
    marquee, which only the walk catches.
  - Correction the item missed: `ContinentTests.swift` did already cover one
    branch of `WineEntry.destination` — the `.continent` early return. The
    `.detail` fall-through, `scanTitle` and `scanSymbol` were untouched, and
    are now.
- [x] **M34** · ci · no CI at all — the Linux-ready test suite never runs automatically · repo root → GitHub Actions running `swift test` on push/PR
  - **Resolved 2026-07-29** in `.github/workflows/ci.yml`. Two jobs: `swift test`
    on a `swift:6.0` Linux container, and a drift check that regenerates from
    `shared/` and fails if the committed JSON disagrees. The workflow lives here
    rather than "in the monorepo or as a gate on the publish step" — that framing
    predates this repo owning itself, and there is no publish step left to gate.
    Note the job cannot see `VinodexUI`, which is invisible to Linux; it is a
    guard on the model layer and the data pipeline, not on the app.

**Release & process**

- [x] **M35** · release · placeholder bundleID `com.example.Vinodex`; the future ID change orphans UserDefaults bookmarks/unlocks and the example ID blocks TestFlight · `xtool.yml:9` → register the real App ID as a milestone with a data-migration step
  - **Since audit:** the free-profile App ID cap forcing this is now documented in KNOWN-ISSUES.md; the decision itself is still open.
  - **Worse @b48ad20 — the blast radius tripled.** The placeholder ID is unchanged
    at `xtool.yml:8`, there is still no migration step and no registered
    milestone, and the data a future App ID change would orphan grew from **5
    UserDefaults keys to 17** (unlocks, quiz tier, shelves+ratings, daily streak,
    recently-viewed) *plus* an Application Support avatar file added by
    `ProfileAvatar`. Every release since defers this makes the migration bigger.
  - Now at: `xtool.yml:8` · `Bookmarks.swift:66` · `EntryAccess.swift:23` ·
    `README.md:151` · `KNOWN-ISSUES.md:325`
  - **Resolved 2026-08-03 — but not by the mechanism the remedy line names, and
    the reason matters.** "A data-migration step" is not implementable. On iOS
    the bundle ID *is* the container identity: a new App ID gets a new
    `Library/Preferences/<bundleID>.plist` and a new `Library/Application
    Support/`, and the old container is not readable, not enumerable, and is
    deleted with the old app. There is no in-place migration to write, and code
    claiming to be one would be a lie. What ships instead is an **export the
    user carries across**: `SavedDataArchive` + BACK UP / RESTORE in
    SETTINGS ▸ STORED DATA, which is also a backup and a way to move a shelf
    between phones.
  - **The count was wrong in both directions and is now enumerable.** 17 is the
    length of the literal array inside `SavedDataReset.wipeAll()`; the real
    figure is **20 distinct keys** plus the avatar file — `recentlyViewedEntryIDs`,
    `starterTierOnly` and `grantedEntitlements` are persisted and cleared
    through their stores, so they never appeared in that array. `SavedDataKey`
    (`Sources/VinodexCore/SavedData.swift`) now owns all 20 literals and every
    declaring constant derives from it, so the two spellings cannot drift.
    `wipeAll` iterates `allCases` and the hand-kept array is gone.
  - **The trap, which would have shipped looking like a success.** Writing the
    keys is only half a restore: six `@Observable` stores read `UserDefaults`
    **once, in `init`**, and hold the values for the life of the process. An
    import would have written the file, reported success, displayed nothing new
    and then overwritten the imported values with stale in-memory ones on the
    next mutation. Each of the six gained `reload()`, and
    `reloadPicksUpAnImport` demonstrates the stale read rather than describing
    it. `SavedDataReset` hits the same hazard from the other side and had
    already solved it by calling each store's own reset first.
  - **One deliberate asymmetry.** `export` records `starterTierOnly` and
    `grantedEntitlements` so the archive is a complete statement of the device;
    `apply` refuses both. Purchases come from a receipt, never from a file the
    user can edit — the day there is a store, an importable
    `grantedEntitlements` is a free unlock for anyone with a text editor. Their
    absence from the returned `[SavedDataKey]` is what the UI reports.
  - `hapticsEnabled`, `soundsEnabled` and `keepAwakeEnabled` export through
    `object(forKey:)` rather than `bool(forKey:)`: **absent is a value** for all
    three (two default *on*, one *off*), so a fresh device's archive would
    otherwise have carried three explicit falses and switched two settings off
    on restore. `dailyLastDay` keeps the same treatment for the reason
    `StreakStore` already documents.
  - The other half of the item — the milestone — is
    [KNOWN-ISSUES.md, "Changing the bundle ID is a one-way door"](../KNOWN-ISSUES.md):
    the intended ID is `com.blaikooz.vinodex` (it existed at `b59cafb`, reverted
    at `b732221` for the quota, so no naming decision is outstanding), and the
    ordered preconditions are recorded there — including that an App Group is
    the only mechanism that genuinely survives the change, needs a paid account,
    and must be added to the **old** App ID *before* the switch, because one
    added afterwards shares an empty container.
  - Now at: `Sources/VinodexCore/SavedData.swift` ·
    `Sources/VinodexCore/SavedDataArchive.swift` ·
    `Sources/VinodexUI/SavedDataActions.swift` ·
    `Tests/VinodexCoreTests/SavedDataArchiveTests.swift`
- [~] **M36** · licensing · OFL fonts ship without license text and 87/99 icons are CC BY 3.0 with zero attribution; no repo LICENSE · `Sources/VinodexUI/Resources/Fonts/` → add OFL texts, a NOTICE/credits file (surfaced in settings), and a top-level LICENSE
  - **Related:** `shared/PROVENANCE.md` (which replaced the deleted
    KNOWN-ISSUES.md:284 note) records that 4.5 MB of a copyrighted wine
    encyclopedia is committed and public in `blaikooz/vinodex`, is not a source
    for this repo's dataset, and is slated for an upstream history purge. Out of
    scope for this repo, but it belongs on the same cleanup pass.
  - **Partly done @b48ad20.** `README.md:220–224` now credits game-icons and the
    two fonts. **Still missing:** OFL license texts beside the `.ttf` files, a
    top-level `LICENSE`, a `NOTICE` file, an in-app credits surface — and the 11
    lucide (ISC) + 1 mdi (Apache-2.0) glyphs are uncredited even in the new
    README section.
  - **Deliberately held back on 2026-08-03**, at the maintainer's direction, and
    it is the one open item that cannot be closed by an engineer: the top-level
    `LICENSE` is an ownership decision (all-rights-reserved, MIT, or a split
    that keeps the drawn art proprietary), not a technical one. The
    investigation behind it is done and the numbers in the item line are stale
    — the shipped set is **68 glyphs, not 87/99**: 55 game-icons (CC BY 3.0),
    12 lucide (ISC), 1 mdi (Apache-2.0), and the revised note's "11 lucide" is
    off by one.
  - **Second question for the owner, and it blocks `NOTICE`:** `DexSound.swift`
    calls the four SFX "the authored SFX pack … authored in `art/sfx`", which
    does not distinguish "we made them" from "we licensed a pack". Asked and
    **deferred** on 2026-08-03 — so a NOTICE written today would assert
    first-party ownership of four files nobody has confirmed. Resolve before
    writing it.
  - The two fonts' licences are *not* a question and need no decision — read
    straight out of their `name` tables (nameID 13/14): Press Start 2P,
    "Copyright 2012 The Press Start 2P Project Authors, with Reserved Font
    Name", SIL OFL 1.1; VT323, "Copyright 2011, The VT323 Project Authors",
    SIL OFL 1.1, no reserved name. Both ship unmodified, so the RFN is
    satisfied.
  - **Both answers arrived 2026-08-05, and the clerical remainder landed the
    same day.** The owner chose **all-rights-reserved** (the app will
    eventually charge) and confirmed the four SFX are **first-party** — so the
    top-level `LICENSE` exists (ARR with a third-party carve-out), `NOTICE.md`
    carries the full credits inventory (all 68 icon ids credited by artist via
    the game-icons repo tree, the R74n flag pack, and the first-party map, SFX,
    drawn art and dataset), the license texts are vendored under `licenses/`,
    and `OFL.txt` ships beside the fonts inside `.copy("Resources")`. auditS
    **M1 M2 M4 L1** close on the same facts. Still open here — and the only
    reason this stays `[~]` — is the in-app credits surface the item line asks
    for ("surfaced in settings"); nothing about this item is blocked on the
    owner anymore. **Deferred at the owner's direction, 2026-08-06** — held for
    the release pass, the same way M31 is held, so the open row reads as
    scheduling, not neglect.
- [~] **M37** · release · no git tags, no CHANGELOG, no bundle version — no binary can be traced to a commit · `xtool.yml` → tag releases (start with v0.3.8), keep CHANGELOG.md, set CFBundleShortVersionString/CFBundleVersion
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
  - **Two of three halves resolved 2026-08-03; the third is still blocked, so
    this stays `[~]`.** [CHANGELOG.md](../CHANGELOG.md) exists, Keep a Changelog
    1.1, newest first, from 0.6.5 back to 0.2.1. **22 annotated tags backfilled**
    — 4 → **28** — every one carrying `GIT_COMMITTER_DATE` set to its own
    commit's date, so `git tag --sort=taggerdate` reports release order rather
    than backfill order, and every backfilled annotation says it was backfilled
    so the date is not later mistaken for a contemporaneous record.
    **Created locally and not pushed** — that is the maintainer's call.
  - **The audit's "every v0.5.x plus v0.6.0/v0.6.1 shipped untagged" is wrong in
    a way that changes what is taggable.** `0.5.2` and `0.5.5` appear nowhere in
    the history at all. `0.5.8`, `0.5.9`, `0.6.0` and `0.6.1` were real batches
    that landed inside **one commit** (`869c3b7`, whose `AppVersion.fallback`
    goes straight to `"0.6.2"`) — so there is no tree to check out for any of
    them and **they cannot be tagged**. A tag would point at a tree that never
    shipped, which is the exact failure this item exists to prevent. All four
    have CHANGELOG entries and a table at the foot of that file records why they
    have no tag. Likewise `0.4.2.1.2`, set at `9992a37` and never released.
  - **The backfill reaches further than the item's own floor.** "Start with
    v0.3.8" was a guess made before the history was reconstructed; commit
    subjects carry version numbers continuously from **v0.2.1** (`73e10d4`), and
    those commits hold the richest prose in the repo (220–395 words each), so
    the backfill starts there. `v0.3` is deliberately **not** normalised to
    `v0.3.0`: the tree at `bc61a3e` says `v0.3`, and a tag disagreeing with the
    tree it points at is the failure above in miniature.
  - Verified: 28 tags, all annotated (none lightweight); `--sort=taggerdate` is
    chronological; every tag whose tree has an `AppVersion.swift` agrees with
    its `fallback`, and every pre-`AppVersion` tag's commit subject names its
    own version; every `## [x.y.z]` heading has a tag or a recorded reason;
    CHANGELOG's topmost release equals `AppVersion.fallback` (0.6.5).
  - **Still open, and genuinely blocked: the bundle version.** Unchanged — xtool
    1.17 offers no key, so this reopens when there is a signing pipeline.
  - `v0.4.3`'s bump landed at `6cb1bde` and its existing tag sits two commits
    later at `fbc51a0`. **Left alone**: moving a published tag is worse than a
    two-commit offset.
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
  - **Deferred on 2026-08-03** at the maintainer's direction: the fix vendors 68
    SVGs (~150–250 KB) from `api.iconify.design` into `art/iconify/`, and that
    fetch was not authorised in this pass. The plan is complete and the
    verification is the interesting part, so it is recorded here rather than
    lost.
  - **The line anchor is stale**: the fetch is at `rasterize-icons.sh:81`, not
    `:56`. And two things that shape the choice were checked rather than
    assumed — `package-lock.json` **is** tracked, so a `@iconify-json` pin would
    genuinely be lockfile-pinned; it still loses, because one glyph
    (`mdi:help-circle-outline`) drags in a ~7,500-icon package, the rasteriser
    is a bash/curl/python3 script that touches Node nowhere, and consuming
    IconifyJSON means reimplementing `iconToSVG` in bash.
  - **The trap, and it is invisible if hit.** `?color=white` on the fetch URL is
    not cosmetic: the committed PNGs are white RGB with an alpha mask, and
    without it `rsvg-convert` resolves `currentColor` to black — identical
    alpha, inverted RGB, **all 204 files byte-different, and no visual symptom
    at all**, because `DexIcon` renders them as templates and UIKit discards the
    RGB. A second trap sits beside it: vendoring from `game-icons.net` directly
    rather than through Iconify yields 55 solid black squares, since Iconify
    strips a full-bleed background rect the upstream SVGs carry.
  - **A fingerprint was taken so the "not a single pixel changed" claim is
    checkable later without a renderer.** `python3 scripts/recompress-png.py
    --check Sources/VinodexUI/Resources/Icons` currently reports **204 files,
    729,772 B, 204 recompressible, 78,661 B (10.8%)** — four numbers that move
    if any PNG does. `rsvg-convert` is not installed on this host, so the
    re-rasterisation half could not have been proven here even with the fetch
    authorised.
- [x] **M41** · pipeline · nothing verifies committed JSON matches generator output (four divergent historical versions already in pack history) · `Sources/VinodexCore/Resources/entries.json` → stamp the source SHA into outputs and add a verify-data regen-and-diff step
  - **Resolved @0a446d3.** CI's `data` job runs `npm run generate` and fails on `git diff` against `Sources/VinodexCore/Resources` (icons/PNGs excluded, since they need network). The regen-and-diff gate now exists; explicit source-SHA stamping was not needed.
- [x] **M43** · portability · rasterize-icons.sh fails on macOS (GNU-only `mktemp --suffix`, apt-only dependency hint) · `scripts/rasterize-icons.sh:54` → portable mktemp pattern plus a brew hint
  - **Prepped (`audit-fixes`).** `mktemp "${TMPDIR:-/tmp}/vinodex-icon.XXXXXX"` (no GNU `--suffix`); the missing-tool hint now names both `apt install librsvg2-bin` and `brew install librsvg`.

## Low — all resolved

Every item in this row is closed as of 2026-08-01. Kept in place rather than
folded into **Resolved** so the reasoning behind each fix stays beside the
finding it answers — several of them (**L10**, **L16**, **L32**, **L33**,
**L37**) turned on a trap the item itself recorded.


**Code quality & dead code**

- [x] **L1** · consistency · bookmark ids rebuilt from string literals `"COUNTRY_\()"`/`"STATE_\()"` instead of SavedItem prefixes — a prefix change strands saved places · `CountryScreen.swift:28` + `StateScreen.swift:27` → use `SavedItem.country(name).storageID`/`.state(name).storageID`
  - **Unchanged @b48ad20** — same two sites, no new ones. Trivial.
  - **Resolved @2026-08-01.** Both sites build the id through `SavedItem.country(_:)` /
    `.state(_:)`. No string literal of either prefix survives outside
    `Bookmarks.swift` and its test.
- [x] **L2** · magic-string · main-screen behavior keyed on `title == "VINODEX"` — breaks silently if the home title changes · `Sources/VinodexUI/DeviceChassis.swift:58` → pass an explicit isRoot flag from RootView
  - **Checked @b48ad20: not actively broken.** The skins/modes work
    (`ChassisSkin`, `LcdMode` incl. GRUNER BOY / VinoFD) only swaps colour tokens
    and picker labels — the home title is untouched, so this is still latent
    fragility rather than a live defect. Still worth the explicit flag.
  - **Resolved @2026-08-01.** `DeviceChassis.isRoot`, declared by `RootView` as
    `path.isEmpty`. `isMainScreen` and the title comparison are gone; the home
    title is now a display string and nothing else.
- [x] **L3** · ux-state · the daily-grape reveal resets on every visit (plain @State) though `DailyPick.isSameDay` was built to persist it · `Sources/VinodexUI/DailyGrapeScreen.swift:16` → persist last-revealed date and initialize revealed from it
  - **Resolved (redesigned) @0a446d3.** The feature became a repeatable cursor-based guessing game (`DailyPick.RevealCursor`); per-visit reset is now intended. `DailyPick.isSameDay` is vestigial (test-only) — a candidate for L4-style dead-code removal.
- [x] **L4** · dead-code · textSection, WineEntry.iconTint, Palette.chip(country:) have no callers (and isSameDay is test-only pending L3) · `EntryDetailScreen.swift:567` + `DexIcon.swift:100` + `WineDatabase.swift:99` → delete (or wire isSameDay via L3)
  - **Narrowed @0a446d3.** `Palette.chip(country:)` now has a caller (ScannerScreen) — keep it. Still dead: `textSection` (EntryDetailScreen) and `WineEntry.iconTint` (DexIcon); `DailyPick.isSameDay` is now also dead per L3. Delete those three.
- [x] **L5** · stale-docs · comments still describe the retired 30-entry starter dataset, plus UTF-8 mojibake ("â€”") · `WineDatabase.swift:324` + `DexTheme.swift:430` → update comments to full-dataset reality and fix the em-dash
- [x] **L6** · stale-docs · the continent MARK comment contradicts the code below it (claims "no glyph"/SF Symbol while generated glyphs are used) · `Sources/VinodexUI/EntryVisual.swift:220` → rewrite to describe current behavior
- [x] **L9** · access-control · many VinodexUI types are public but never used outside the module (CatalogScreen, IconLoader, FlowLayout, StatBar, …) · `Sources/VinodexUI/CatalogScreen.swift:12` → demote to internal except what VinodexApp imports
  - **Worse @b48ad20.** 48 public types / 30 app-unreferenced at `fb5dcf2` →
    **72 / 42** at HEAD. New files split both ways: `GrapeSpriteLoader.swift:18`
    is correctly internal and is the pattern to copy, but
    `CountryOutlineMap.swift:15` and `DiagnosticsReport.swift:9` shipped public
    and unreferenced.
  - The module disagrees with itself: `GrapeSpriteLoader` is internal while its
    siblings `PixelArtLoader` (`EntryVisual.swift:296`) and `FlagLoader`
    (`:334`) are public — same role, same call pattern. The `public` habit is
    being applied by copy, not by intent, which is why this keeps growing.
  - **Resolved @2026-08-01.** All 42 app-unreferenced types demoted to internal
    (195 `public` keywords removed across 18 files), leaving 30 public — which is
    what `VinodexApp` actually names. `PixelArtLoader` and `FlagLoader` now match
    `GrapeSpriteLoader`. One knock-on the compiler caught: `WineDatabase.dataState`
    could not stay a public extension over an internal `DexDataState`.
- [x] **L10** · lifecycle · GlobeModel's CADisplayLink is invalidated only in onDisappear — a skipped callback leaves it firing forever · `Sources/VinodexUI/RetroGlobeScreen.swift:344` → invalidate in dismantleUIView/deinit as well
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
  - **Resolved @2026-08-01.** `GlobeSceneView.makeCoordinator()` returns the model so
    the static `dismantleUIView` can reach it, and calls `detach(from:)` — which
    invalidates **only if the view being dismantled is still the one the model
    holds**. That is the trap this item flagged: SwiftUI may build the replacement
    before dismantling the original on an `.id(…)` change, and an unconditional
    `stop()` there would kill the new link. `start()`'s `displayLink == nil` guard
    is the restart half and both edits landed together. `DisplayLinkProxy` also
    takes the link off the run loop when its target has gone, which is the `deinit`
    half by another route — the link retains the proxy, so a `deinit` on the model
    could never have done it.

**Performance polish**

- [x] **L11** · perf · four PulseGlow repeatForever animations blur shadow radius continuously on every screen, even behind the flipped plate · `Sources/VinodexUI/DeviceChassis.swift:587` → animate opacity of a pre-blurred circle and pause while flipped
  - **Unchanged @b48ad20**: shadow *radius* is still what animates, four instances
    per frame, nothing pauses while the back plate shows (the front face is merely
    opacity-0 at `DeviceChassis.swift:102`).
  - Worth knowing: `PulseGlow` (`DeviceChassis.swift:810`) is the **only**
    `repeatForever` animation in the entire codebase, so fixing it is the whole
    of the app's perpetual-animation cost — and it overlaps **M18**.
  - **Narrowed 2026-07-31 by M18**, which took the overlap: `PulseGlow` no
    longer animates at all under Reduce Motion. That is the correct half and
    not this item's half — L11 is about the other ~99% of users, where the
    animation still blurs shadow *radius* four times a frame rather than
    cross-fading a pre-blurred circle, and still runs behind the flipped plate.
    M18 did **not** add a `paused` term. Now at `DeviceChassis.swift:841`.
  - **Resolved @2026-08-01.** What animates is the opacity of a circle blurred once,
    not a shadow radius recomputed per frame, and `paused: showsBackFace` stops all
    four instances while the back plate is showing. The still branch now covers
    both reasons to stop, so **M18**'s Reduce Motion behaviour is unchanged.
- [x] **L12** · perf · BookmarksScreen renders saved rows in an eager VStack and every name-field keystroke rebuilds the whole list · `Sources/VinodexUI/BookmarksScreen.swift:44` → LazyVStack plus a child view for the name editor
  - **Worse @b48ad20.** Both halves intact, and the keystroke-rebuilt subtree grew
    — 0.6.3's recently-viewed strip (`BookmarksScreen.swift:295–332`) eagerly
    builds up to 20 icon wells inside it. BookmarksScreen is now the **only** list
    screen still using an eager VStack.
  - Now at: `:107` (eager VStack), `:131` (ForEach), `:425` (nameRow), `:429`
    (search field bound to `$displayName`)
  - **Resolved @2026-08-01.** `LazyVStack` for the list, and the name editor is
    `ProfileNameRow` — its own view owning both `displayName` and `editingName`, so
    a keystroke rebuilds one row instead of the profile block, the twenty-well
    recents strip, the shelf picker's three `saved(in:)` counts and every row of
    the active shelf.
- [x] **L14** · perf · `hasRegions(inCountry:)` re-filters and re-sorts the whole DB per country row per render · `Sources/VinodexUI/ContinentScreen.swift:145` → precompute a Set of region-origin countries once
  - **Unchanged @b48ad20, and the fix got nearly free:** `WineDatabase.init`
    already walks region origins at `WineDatabase.swift:324–332` to build
    `searchableCountries` — capture the same loop's origins into a `Set` and make
    `hasRegions` a membership test. **Note:** `searchableCountries` stores *raw*
    origins while `hasRegions` compares through `TextNormalize.label`, so the new
    set must be the normalised one.
  - **Resolved @2026-08-01.** `WineDatabase.regionOriginLabels`, built by the walk
    that already produced `searchableCountries`, normalised through
    `TextNormalize.label` as this item warned it had to be. `hasRegions` is a set
    lookup and `countryCount` counts the same set instead of rebuilding it.
- [x] **L15** · perf · regionVisual runs the identical key-grape lookup scan twice (tint + iconID) per resolve · `Sources/VinodexUI/EntryVisual.swift:152` → look up once into a local
  - **Resolved @b48ad20**, challenged without refutation. The duplicated scan is
    gone — region visuals dropped key-grape lookups entirely in v0.5.7, and the
    name resolver became a hash lookup (**H9**). Now at `EntryVisual.swift:159`.
  - Nit left behind: the `EntryVisualCache` doc comment (`EntryVisual.swift:269`)
    still describes the removed key-grape walk.
- [x] **L16** · perf · DexFont.retro/mono run a UIFont availability probe plus a UserDefaults read on every Font construction · `Sources/VinodexUI/DexTheme.swift:264` → resolve availability into static lets at registration
  - **Half done, and the other half spread @b48ad20.** Availability probing is
    genuinely fixed (static lets at `DexTheme.swift:335–336`). The per-call
    `UserDefaults.standard.string` read is still in `retro`/`mono` (`:340`, `:349`)
    — and the same uncached idiom is now a house pattern: `UIScale` (`:451`),
    `LcdMode` (`:821`), plus `DexSound.swift:25` and `Haptics.swift:21`, across
    seven more per-render call sites. **Every `Text` in the app pays it.**
  - Fix this as one shared cached-setting mechanism rather than patching
    `DexFont` alone — but keep settings live: RootView keys off these values.
  - **Resolved @2026-08-01** as the shared mechanism this item asked for, not a
    patch to `DexFont`. `SettingsCache` (Core, lock-guarded, invalidated wholesale
    by `UserDefaults.didChangeNotification`) now serves `TextScale.current`,
    `UIScale.current`, `LcdMode.current`, `Sounds.enabled` and `Haptics.enabled`.
    Settings stay live — the notification fires on the writing thread, before
    SwiftUI re-renders what `@AppStorage` invalidated — so the `.id()` rebuild
    contract `RootView` depends on is unchanged. Injected-defaults overloads read
    straight through, so the tests are unaffected.

**Assets & data footprint**

- [x] **L17** · assets · 21 orphan icon PNGs (7 slugs × 3 scales, ~70KB) ship unreferenced because the rasterizer never prunes · `Sources/VinodexUI/Resources/Icons` + `scripts/rasterize-icons.sh:26` → delete orphans and add a prune step
  - **Prepped (`audit-fixes`).** Deleted the 21 orphans (circle, flame, oak, shield, sparkles, lucide flag, lucide globe) and added a prune step that drops any `Icons/*.png` whose slug left the manifest.
- [x] **L18** · data · palette.json ships fields nothing decodes (flagGradients, flavorClassMeta) and Palette decodes fields nothing reads (appellationChips, continentColors) · `WineDatabase.swift:91` + `scripts/generate-ios-data.ts` → drop both sides
  - **Resolved (`audit-fixes`).** Generator strips `flagGradients`, `flavorClassMeta`, `appellationChips`, `continentColors`; the two non-optional `Palette` properties (`appellationChips`, `continentColors`) and the `emptyPalette` init were updated to match.
- [x] **L19** · data · all four JSONs are pretty-printed (2-space indent), inflating ~412KB by roughly a third · `scripts/generate-ios-data.ts:674` → emit minified (keep a --pretty debug flag)
  - **Prepped (`audit-fixes`).** Minified by default via `serialize()`; `--pretty`/`PRETTY=1` for readable output. With M4/L18, entries.json 346KB → 193KB (−44%). Verified whitespace-only by JSON.parse deep-equality.
- [x] **L20** · assets · AppIcon.png is a barely-compressed 1024² PNG at 932KB (~⅓ of the git pack) · `AppIcon.png` → recompress losslessly (oxipng/zopflipng) and note a binary-asset policy
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
  - **Resolved @2026-08-01**, as the policy call it had become. `AppIcon.png`
    951,285 → 675,776 B (−29.0%), verified pixel-and-mode identical against
    `HEAD`. `scripts/recompress-png.py` is the tool — it refuses to write a file
    that does not round-trip — and README gains a four-rule binary-asset policy.
    **Deliberately not taken:** the 8.4 MB (23.8%) available across `art/`'s 298
    masters, and the fate of `art/icons/reference/` (11.7 MB) and
    `art/icons/attic/` (849 KB). Rewriting the artist's masters is the
    maintainer's call, the command is in the README, and git keeps the old blobs
    either way. `Sources/VinodexUI/Resources/**` is left alone on purpose: 4%
    (130 KB), against permanently disagreeing with the importer that regenerates
    it.
- [x] **L22** · reproducibility · the xtool version used for packaging/signing is recorded nowhere · `xtool.yml` → record the known-good version as part of the release checklist
  - **Since audit:** narrowed by `fb5dcf2` — README now pins the Swift requirement (6.3); xtool remains unpinned.
  - **Half done incidentally @b48ad20:** xtool 1.17 is now written down at
    `KNOWN-ISSUES.md:261` and `AppVersion.swift:25`, so the version in use is
    discoverable. **Still missing the actual ask:** a release checklist naming the
    known-good version, and a versioned prerequisite at `README.md:123` instead of
    an unpinned link.
  - **Resolved @2026-08-01.** README's prerequisite pins xtool **1.17.0** with a
    release link and says why the version is load-bearing, and a **Release
    checklist** under Deploying names the toolchain, the data-currency check, the
    new **L26** asset probe, the three gates and the tag. First two lines go in
    the tag annotation, so a release is reproducible from the tag.

**Pipeline & diagnostics**

- [x] **L23** · pipeline · a failed rsvg-convert on one scale leaves already-written variants behind — partial scale sets can be committed unnoticed · `scripts/rasterize-icons.sh:74` → render to temp names, move atomically only when all three succeed
  - **Prepped (`audit-fixes`).** Each scale renders to a `.tmp.$$` name; the three are `mv`-ed into place only if all succeed, else all are removed. (Render path not run locally — no rsvg-convert here.)
- [x] **L24** · pipeline · a missing pixelflags directory is a soft skip that still exits 0 · `scripts/rasterize-icons.sh:126` → fail hard unless SKIP_FLAGS=1
  - **Prepped (`audit-fixes`).** A missing `pixelflags/` now increments `failed` (so the run exits 1) unless `SKIP_FLAGS=1` is set explicitly.
- [x] **L25** · pipeline · the country→slug rule is implemented twice (shell `tr` vs Swift string ops) with no shared test — divergence means a silently missing flag · `scripts/rasterize-icons.sh:110` → emit the final slug per country into icons.json and consume it on both sides
  - **Unchanged @b48ad20** — neither side reads a generated slug. No live
    breakage today: all 29 flag keys are ASCII differing only by spaces. The
    exposure is the next non-ASCII or punctuated country name.
  - **Resolved @2026-08-01.** `generate-ios-data.ts` emits `flagSlugs` and both
    consumers read it: `rasterize-icons.sh` names the copied PNG from it (and fails
    loudly on a missing entry rather than falling back), `IconManifest.flagSlug(for:)`
    returns it. The generator's rule folds diacritics and collapses every
    non-alphanumeric run, so it answers for the names that would have diverged —
    and is byte-identical to both old rules on all 33 current keys, verified, so no
    flag is renamed. Asserted non-empty in `ICONS_REQUIRED_NONEMPTY`.
- [x] **L26** · diagnostics · nothing checks that every icons.json id has a bundled PNG — a rasterization gap ships as the red questionmark placeholder · `Sources/VinodexUI/DiagnosticsReport.swift:23` → probe the bundle for each `unique` id and flag misses
  - **Worse @b48ad20** — the unguarded surface grew from one directory to five.
    **No live gap, though:** the probe was scripted during this pass and
    everything resolves (66/66 icon ids, 96 flavorArt, 14 grapeArt, 31 styleArt,
    94 `art:` ids, 198 = 66×3 Icons files, 29 flags). This is purely a missing
    guardrail. Fix: loop `db.icons.unique` plus the art stems and flag slugs
    through `DexResources.url` in `DiagnosticsReport` and flag misses.
  - Now at: `DiagnosticsReport.swift:21` (count-only rows) ·
    `DexIcon.swift:110` (the questionmark placeholder)
  - **Resolved @2026-08-01.** `DexAssetAudit` resolves every id the manifest names
    through the bundle and `DiagnosticsReport` reports per surface — the count-only
    rows are gone. All five directories, and icons are checked at **all three
    scales**, since `IconLoader` walks down from the device scale and a set missing
    only its `@3x` would otherwise draw softly forever. Iconify ids come from
    `unique` **plus** every table that can hand one to `DexIcon`, because those are
    the same set only while nobody has made a mistake. Current state, verified:
    68/68 icons · 94/94 `art:` · 96/96 flavorArt · 14/14 grapeArt · 30/30 styleArt ·
    33/33 flags.
- [x] **L45** · stale-docs · `DexIcon.image(_:)`'s doc comment claims it returns "the glyph for an Iconify id, **or the manifest fallback**", but the implementation returns nil on a miss and the caller draws the red questionmark — `icons.fallback` (mdi:help-circle-outline) is never substituted, even though it is in `unique` and has a bundled PNG · `Sources/VinodexUI/DexIcon.swift:31` (comment), `:41` (returns nil), `:110` (placeholder) → either substitute the fallback or fix the comment
  - **New 2026-07-31.** Harmless today (see L26 — nothing is missing), but it is
    the same stale-comment class as **L5**/**L6**, and it describes the exact
    safety net **L26** assumes exists.
  - **Resolved @2026-08-01** by fixing the comment, which is the option the code's
    own design argues for: `icons.fallback` is a *data* default already applied by
    `IconManifest.flavorClassIcon(_:)` before an id reaches the loader, and
    substituting it again at load would turn a rasterisation gap into an ordinary
    question-mark glyph that ships unnoticed. The red placeholder is deliberate;
    **L26** is the check that catches the gap first.

**UI polish**

- [x] **L27** · a11y · the settings close button is a 34×34pt target · `Sources/VinodexUI/SettingsPanel.swift:77` → 44×44 frame around the 34pt visual
  - **Resolved @0a446d3.** Settings became a pushed route with no dedicated close control; it is dismissed by the chassis Back button (`DexMetrics.footerControl` = 64pt).
- [x] **L28** · pixel-art · DexIcon omits `.interpolation(.none)` while FlagImage/LogoMark set it — glyphs blur instead of staying crisp · `Sources/VinodexUI/DexIcon.swift:54` → add `.interpolation(.none)`
  - **Half done @b48ad20.** DexIcon is fixed on both branches
    (`DexIcon.swift:94–108`) and the code cites L28. **The same omission survives
    in three places, and they are the app's *largest* pixel art:** the grape
    sprite branch (`EntryVisual.swift:402`), the region-outline branch (`:444`),
    and `CountryOutlineMap.swift:63`. Three one-line additions.
  - Same shape as **M24**: fixed for the one file the audit named while the
    pattern spread into files added since.
  - **Resolved @2026-08-01.** `.interpolation(.none)` added to all three: the
    grape-sprite/flavour-portrait branch (`EntryVisual`), the region-outline branch,
    and `CountryOutlineMap`. No `Image(uiImage:)` in the codebase is left sampling
    linearly.
- [x] **L29** · light-mode · hero panels overlay a hardcoded dark-green grid that reads heavy/busy on the light hero (4 screens) · `EntryDetailScreen.swift:113` + `CountryScreen.swift:95` + `ContinentScreen.swift:99` + `StateScreen.swift:72` → mode-aware heroGrid color on LcdMode
- [x] **L30** · light-mode · EntryDetail's hero title shadow hardcodes #006400 while sibling screens use `lcd.accent.opacity(0.55)` — reads as blur in light mode · `Sources/VinodexUI/EntryDetailScreen.swift:104` → match the siblings (also resolved by M28's extraction)
- [x] **L32** · layout · SE-class devices still reserve the 138pt island clearance for a phantom cutout, leaving a dead gap · `Sources/VinodexUI/DeviceChassis.swift:180` → collapse clearance when safe-area top is below the cutout threshold
  - **Unchanged @b48ad20.** **Trap for the fix:** `DexTheme.swift:144–147`
    documents that `.statusBarHidden()` (set at `VinodexApp.swift:125`) can
    collapse `safeAreaInsets.top` to zero *on cutout devices* — so keying the
    clearance off the top inset would collapse the band on exactly the devices
    that need it. This needs a different device signal.
  - **Resolved @2026-08-01**, using the different device signal this item said it
    needed. `DexMetrics.hasDisplayCutout(bottomSafeArea:)` keys off the **home
    indicator**, not the top inset: `.statusBarHidden()` can collapse the top inset
    to zero on cutout devices, so keying off it would have closed the gap on exactly
    the phones that need it. Nothing hides the home indicator, and the split is
    clean — every cutout display has one, no home-button device does. On a flat top
    edge the title lip's 138pt reservation drops to zero and the orb, lamps and cog
    get the width back.
- [x] **L33** · theme-discipline · inline hex palettes bypass the token system (menu tiles, statColors, markerColors) — how light-mode surfaces got missed before · `MainMenuScreen.swift:32` + `EntryDetailScreen.swift:448` + `RetroGlobeScreen.swift:216` → hoist into Dex/palette.json tokens
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
  - **Resolved @2026-08-01** at the named sites, including the correctness hazard.
    `DexTileLivery` is one seven-case token table serving both grids: the settings
    panel's two parallel six-row tables keyed on the tile *title string* are gone,
    so a renamed tile is now a compile-time concern rather than a silent fall-through
    to the ACCESS purple. The main menu's four faces were the same colours written a
    second time and had **no light-mode value at all** — they do now, which is the
    class of miss this item is named for. `statColors` and the `InternalsView` board
    palette are named constants (`Dex.stat*`, `Board`).
  - **Not a blanket sweep of all 205 hexes**, deliberately. What is left is
    overwhelmingly `Color(dexHex:)` over *generated* values from `palette.json`
    (chips, tints) — data, not a bypassed token — plus one-off chrome in screens the
    audit did not name. Raise those separately if they matter; the tile tables were
    the part that could go wrong.

**UX polish**

- [x] **L34** · search · no clear button on the search field (`clearButtonMode = .never`) — queries must be deleted character by character · `Sources/VinodexUI/DexSearchField.swift:30` → `.whileEditing` (or a retro X button)
- [x] **L35** · search · MASTER SEARCH opens without focusing the field — an extra tap on a screen whose whole purpose is typing · `Sources/VinodexUI/DexSearchField.swift:23` → autofocus option enabled for the masterSearch route
  - **Cheaper than the audit assumed @b48ad20:** the `focusesOnAppear` plumbing
    already exists on `DexSearchField` and is proven in BookmarksScreen. Needs a
    pass-through param on `DexSearchBar` and `EncyclopediaListScreen`, set true
    only for the `.masterSearch` route.
  - **Resolved @2026-08-01** via the plumbing this item found already existed:
    `focusesOnAppear` passes through `DexSearchBar` and `EncyclopediaListScreen`,
    set true only for `.masterSearch`. Suppressed when a query was restored —
    popping the keyboard over results you came back to look at would undo the
    point of `SearchStateStore` restoring them.
- [x] **L36** · empty-state · StateScreen renders a bare "REGIONS" header with zero rows and no message when a state resolves empty · `Sources/VinodexUI/StateScreen.swift:116` → "NO REGIONS FOUND" empty state matching the list screens
  - **Unchanged @b48ad20, and it has a sibling the audit missed:**
    `CountryScreen.swift:362–387` has the identical unconditional "REGIONS" header
    over an unguarded ForEach. Fix as a shared section helper, not a one-liner in
    StateScreen. (Trigger is narrow — a state route is only reachable from an
    existing region row — but a *partial* decode failure now produces exactly
    this, see H2/M46.)
  - **Resolved @2026-08-01** as a shared helper, not a one-liner: `DexSectionEmpty`
    wrapped in `DexEmptyState`, used by **both** `StateScreen` and the sibling
    `CountryScreen.regionsSection` this item spotted. The `DexEmptyState` wrapper is
    what makes it worth having — on a partial or failed load it says so rather than
    reporting "no regions" as a fact about wine.
- [x] **L37** · consistency · the code comment says single-item removal deliberately skips confirmation, but every ✕ tap shows a confirm dialog · `Sources/VinodexUI/BookmarksScreen.swift:84` → drop the confirm (SAVE toggle is the undo) or fix the comment
  - **Unchanged @b48ad20 and slightly worse to read:** the comment now sits
    directly above **both** overlays (clear-all at `:165–180`, single-remove at
    `:181–194`), so it misdescribes code three lines below it.
  - **Resolved @2026-08-01** by fixing the comment, not by dropping the confirm —
    the comment was the part that was wrong. "Cheap to redo" holds for a saved
    bookmark and does **not** hold on the TRIED shelf, where `remove(_:on:)` takes
    the rating and the written note with the row. The ✕ is a small target beside a
    scrolling list and there is nothing behind it to restore what it deletes, so
    the dialog earns its place; the tried-shelf message now says what goes with it.
- [x] **L38** · haptics · only generic tap/select feedback exists — saves and destructive confirms get no distinct success/warning haptic · `Sources/VinodexUI/Haptics.swift:9` → add UINotificationFeedbackGenerator-backed success()/warning()
  - **Worse @b48ad20:** call sites roughly doubled (32 → 78), and v0.6.x added
    TastingQuizScreen/DailyChallenge whose correct/wrong branch
    (`TastingQuizScreen.swift:178`) is precisely the success/warning case.
  - **Compounded by L43:** that same wrong answer is also *silent*, because
    `Sounds.wrong()` is an empty stub. Take the two together.
  - Add `success()`/`warning()` behind the existing `enabled` gate, then wire the
    quiz branch and DexAlert's destructive confirm.
  - **Resolved @2026-08-01.** `Haptics.success()`/`warning()` on
    `UINotificationFeedbackGenerator`, behind the same `enabled` gate. Wired to the
    quiz's correct/wrong branch, to SAVE (success on saving, the plain ping on
    un-saving), and to `DexAlert`'s destructive confirm — which is now an explicit
    `destructive:` flag rather than inferred from the button's colour, since every
    two-button alert draws its confirm red, UNLOCK included. Taken together with
    **L43**, as this item asked.
- [x] **L39** · search · region lists never show the search bar (`showsSearch: category != .regions`), so long filtered lists can't be searched · `Sources/VinodexApp/VinodexApp.swift:118` → enable showsSearch for filtered region lists
  - **Unchanged @b48ad20** — a one-word fix (drop the `category != .regions`
    condition). Narrower than the audit implied: the single reachable case is the
    climate-filtered region list from an entry page, but it can run long.
  - **Resolved @2026-08-01.** The `category != .regions` condition is gone; the
    default is `showsSearch: true`.
- [x] **L40** · battery · `isIdleTimerDisabled = true` for the app's whole lifetime — the phone never auto-locks · `Sources/VinodexApp/VinodexApp.swift:93` → make keep-awake a settings toggle
  - **Unchanged @b48ad20.** Obvious home is a third row in `systemSettings`
    (`SettingsPanel.swift:460–496`) beside HAPTICS/SOUNDS, with an `@AppStorage`
    key read by `ScreenWake`, defaulting **on** to preserve today's behaviour.
  - **Resolved @2026-08-01** in the place this item proposed: a third row beside
    HAPTICS and SOUNDS. `ScreenWake.storageKey` defaults **on**, so behaviour is
    unchanged for anyone who never looks; toggling it re-applies immediately rather
    than at the next launch, and CLEAR SAVED DATA re-applies after restoring the
    default. `keepAwake(false)` still always releases the timer — the caller saying
    "the app is going away" is not something the preference gets a vote on.
- [x] **L41** · consistency · the locked-entry alert overlays the whole chassis, contradicting the documented in-LCD dialog convention other screens follow · `Sources/VinodexApp/VinodexApp.swift:74` → present inside the LCD content area
  - **Resolved @b48ad20**, challenged without refutation. The upgrade prompt now
    renders inside the LCD like every other dialog; no chassis-level overlay
    remains. This looks like a deliberate completed sweep — all four dialog sites
    (`VinodexApp.swift:89`, `:110`, `SettingsPanel.swift:102`, `:280`) follow the
    convention now.
  - Now at: `VinodexApp.swift:79–102` (ZStack inside the chassis content closure)
    · `DeviceChassis.swift:436` (innerBezel calls `content()`)
- [x] **L42** · settings-copy · user-facing settings say "PAYWALL TESTING"/"SKIN TESTING" and hand every user a paywall-defeating toggle · `Sources/VinodexUI/SettingsPanel.swift:156,192` → user-language labels; move the paywall toggle to the DEV tab until real IAP
  - **Labels fixed, controls not @b48ad20.** The paywall-defeating FREE TIER
    toggle is still one tap from the settings grid, and the panel still describes
    itself in test-harness language ("a test harness, not a store", `:379`).
    Either move the whole `paywallTesting` panel behind DEV — as DEV itself was
    moved — or replace it with a real store front.
  - Now at: `DexRoute.swift:19` (section labels) · `SettingsPanel.swift:87`
    (ACCESS tile), `:313` (FREE TIER toggle), `:379` (the copy)
  - **Resolved @2026-08-01**, taking the "move it behind DEV" option. Every
    mutating control — the paywall-defeating FREE TIER switch, the per-bundle
    grants, REVOKE ALL — is now in the DEV panel with the rest of the developer
    plumbing. ACCESS keeps its tile and becomes a read-only readout in user
    language: what the library holds, which bundles are owned, and a plain
    statement that there is no store in this build. No test-harness copy remains
    outside DEV.
- [x] **L43** · ux · `Sounds.page()` and `Sounds.wrong()` are empty no-op stubs — every push/pop calls `Sounds.page()` for nothing, and a wrong quiz answer is completely silent (and gets only the generic selection haptic) · `Sources/VinodexUI/DexSound.swift:43,48` + `VinodexApp.swift:309,326,339` + `TastingQuizScreen.swift:181` → fill them in or delete the calls
  - **New 2026-07-31.** Pairs with **L38**: wrong answers currently have neither
    sound nor distinct haptic, which is the one place the app most needs both.
  - **Resolved @2026-08-01** by deleting both stubs and their call sites, which is
    the honest half of "fill them in or delete": no authored file exists for either,
    and `art/sfx` holds four sounds. `Sounds.page()` had nothing to add even in
    principle — a screen change already rides the click of the button that caused
    it. The wrong answer is carried by `Haptics.warning()` (**L38**). A future file
    arrives as a `Kind` case and a one-line accessor, which is the whole cost the
    stubs existed to avoid.
- [x] **L44** · a11y · quiz right/wrong is signalled only by a checkmark/xmark glyph plus a green/red border tint on an already-disabled row — no text and no accessibilityLabel says "correct" · `Sources/VinodexUI/TastingQuizScreen.swift:414`, `:433` → add a label or trait carrying the result
  - **New 2026-07-31.** Colour-plus-glyph alone also fails for colour-blind users,
    not only VoiceOver. Note the screen's *modal* handling is good
    (`accessibilityElement(children: .contain)` + `.isModal` at `:456`), matching
    DexAlert — this is the one gap. See also **M48**.

---

## Resolved

  - **Resolved @2026-08-01.** Each option row is one accessibility element with a
    label that names the outcome: "Correct answer", "Correct, your answer", "Wrong,
    your answer". Both halves of the gap — VoiceOver read every row as "dimmed", and
    a red/green pair carries nothing for a colour-blind reader — are answered by
    text rather than by a second glyph.
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

**2026-08-05 — M36 unblocked; the clerical remainder landed.** The owner
answered both deferred questions — top-level `LICENSE`: **all-rights-reserved**
(proprietary, eventually paid); the four SFX: **first-party** — plus the three
provenance questions auditS carried (map: first-party; dataset: first-party,
Sotheby's text to be purged upstream; flag pack: R74n PixelFlags, whose R74n
Content License v1.1 was located via the site's `llms.txt`). Landed together:
`LICENSE`, `NOTICE.md`, `licenses/` (Lucide ISC+MIT, Pictogrammers, Apache-2.0,
R74n v1.1), `Sources/VinodexUI/Resources/Fonts/OFL.txt`, and
`shared/PROVENANCE.md`. auditS **M1 M2 M4 L1** close; auditS **H1** goes
partial; auditS **H2**'s provenance question is answered, leaving its
commercial condition (permission or first-party recreation before a paid
release — R74n's terms are credit + non-commercial). **M36** stays `[~]` for
the in-app credits surface alone. Open count here is unchanged at 4; what
changed is that M36 is no longer blocked on anyone.

**2026-08-03 — M30 M33 M35 M37 M47 M49.** Every remaining open item except the
three that were held back: **M31** (excluded by the maintainer, as it was last
pass), **M36** (needs an ownership decision on the top-level `LICENSE` and a
factual answer on SFX provenance — both asked, both deferred) and **M40** (the
fix vendors 68 SVGs over the network; the fetch was not authorised). Medium open
9 → 4. Tests & CI and Accessibility both empty; Architecture drops to **M31**
alone, and Release & licensing to **M36** plus the blocked third of **M37**.

- **Two items were closed by a mechanism their own remedy line rules out, and
  each entry says why.** **M35**'s "data-migration step" is not implementable at
  all: on iOS the bundle ID *is* the container identity, so a new App ID gets an
  empty defaults database and an unreachable old one. What shipped instead is an
  export the user carries across — `SavedDataArchive`, plus BACK UP / RESTORE
  beside the button that destroys what it backs up. **M30** was filed as "8+
  types with clean seams" for two files; that fits `DeviceChassis` (11 types)
  and not `EntryDetailScreen` (4 types and one ~930-line `View`), so the two
  halves got different treatments — a type-boundary split and a
  dependency-explicit extraction.
- **M30 took the item's own correction and split four files, not two.** The
  2026-07-31 note says `DexTheme.swift` and `SettingsPanel.swift` "belong in
  it", and they were the two largest files in the module. 5,577 lines across
  four files became 3,058 across those four plus nine new ones, all pure code
  motion. The split immediately earned its keep: two `private` members meant
  "this file", which is exactly the coupling being removed, and both were caught
  by `typecheck-ios-surface.sh` rather than by CI.
- **M49 ships three text steps, not four.** A fourth was built, measured and
  then withdrawn on the maintainer's UI/UX call — it split the TEXT SIZE row
  into ~69pt columns against a five-character SMALL wanting 84.5pt, so it only
  fitted by shrinking its own labels. The extra range went into `huge`
  (1.15 → 1.30) instead. That is also the version of the change which *proves*
  the frame derivation was load-bearing: 1.30 is past `StatBar`'s old 1.206
  ceiling, so its label well genuinely grows at HUGE, where a fourth step would
  have left every already-shipped step untouched. It does re-size the app for
  anyone on HUGE — acceptable only because HUGE is three days old and the build
  is not publicly distributed.
- **M49's blockers turned out to be arithmetic, which is why it could be done
  here at all.** The item said its remaining gap wanted a device. Three of the
  four fixed frames are computable to the point: VT323's advance is exactly
  0.4 em and Press Start 2P's exactly 1.0 em — read out of the shipped `.ttf`
  `hmtx` tables — so `StatBar`'s 96pt well provably holds AROMATICS to
  **f = 1.206**, which is why the axis had stopped at 1.15. All four now derive,
  and every one is **unchanged at every step that has ever shipped**. The one
  genuinely unbounded case, the globe markers, got a measured cap instead: their
  plates reach 55% of the LCD unbounded at the new top step.
- **M49 also found the fourth blocker the item did not list — and it was one M50
  had already written down.** M50 recorded `26f + 8 ≤ 46` and `≤ 44` as ceilings
  "M49 cannot raise the factor past without a test saying so". The answer was
  not to respect them but to delete them: both literals derived from the axis
  they were meant to bound. Those two assertions in `TypeScaleTests` are now the
  statement that the shell contains its field at every step.
- **Two live user-visible bugs found and fixed** (M33), both on the styles'
  COLOR chip. `Rosé` and `Orange Wine` opened it onto an **empty list** — no
  grape carries either colour, the same defect D2 fixed for DUAL and left
  unfixed for these — and the mapping that fixes it is authored in the entries'
  own descriptions rather than chosen: rosé is pressed from red grapes, orange
  from white. The second was worse for being visible rather than empty:
  **`Prosecco` was labelled a rosé**, because the colour inference matched
  substrings and "rose" sits inside "p-*rose*-cco". Whole-word matching fixes
  it; Prosecco falls to DUAL. A test now walks every style asserting no COLOR
  chip opens onto nothing, since a per-name test would miss the next one.
- **A real defect fixed in passing** (M49): `ChipFlow` and `FlowLayout` both
  correctly refuse to break on the first chip of a row, then placed an over-wide
  one at its natural width past the container edge — where the chassis clip made
  it invisible rather than obviously wrong. Both propose the container width
  now, in `sizeThatFits` as well as `placeSubviews`.
- **Corrections to item text.** M35's "17 UserDefaults keys" is **20** — 17 is
  the length of a hand-kept array that had silently drifted from the stores it
  claimed to back up, and `SavedDataKey.allCases` replaces it. M37's "every
  v0.5.x plus v0.6.0/v0.6.1 shipped untagged" is wrong in a way that changes
  what is *taggable*: `0.5.2`/`0.5.5` never existed and `0.5.8`–`0.6.1` landed
  inside one commit, so four numbers get CHANGELOG entries and no tag, on
  purpose. M36's "87/99 icons" is **68** (55 game-icons, 12 lucide, 1 mdi), and
  the revised note's "11 lucide" is off by one. M40's anchor is
  `rasterize-icons.sh:81`, not `:56`. M33's `.type` description cannot
  distinguish `wineType` from `grapeStyle` — they are identical for all 146
  shipped grapes.
- **What M49 costs, on the record.** The rendered floor collapses nominals 10,
  11 and 12 onto 11pt at the SMALL step, growing 41 call sites by up to 29%.
  Above 12 nothing moves at any step. **The tile layouts at the widened HUGE
  step are the one thing still unverified**, and a device is what verifies them.
- **Verification.** `swift build` clean. `scripts/typecheck-ios-surface.sh`
  clean against the baseline after every batch — it caught both M30 access
  errors and one M35 UI error, and needed no new baseline entries. Core
  behaviour was *executed*, not merely compiled, via the scratch runner:
  **225 assertions** for M33/M47 against the real bundled database, **67** for
  M35 against real `UserDefaults` suites, and **1,540** for M49 across all four
  steps. A new `typecheck-tests.py` harness type-checks all 21 test files with
  the swift-testing macros stripped — 0 diagnostics — which is the first time
  anything local has checked the test target at all. **`swift test` itself was
  not run**: the standing gap in KNOWN-ISSUES, and CI is the first thing that
  executes these suites. The 22 backfilled tags were **created locally and not
  pushed**.

**2026-08-03 — M27 M29 M32 M45 M46 M48 M50.** Seven of the sixteen open
Mediums, taken as a single pass over the open set at the maintainer's request.
**M31 was deliberately excluded** and is untouched — it is the one open item
that was explicitly held back, not one that was missed. Medium open 16 → 9;
Data & robustness empties, Accessibility drops to **M49** alone, Tests & CI to
**M33**/**M47**.

- **Three items closed by a mechanism their own remedy line contradicted**, and
  each entry carries the reason. **M45**'s "distinguish missing from wrong"
  turned out to need a second *channel*, not a second message: `loadNotices`
  beside `decodeErrors`, with the dividing line stated once — a fault means the
  app lost data and a user can see it, a notice means a documented fallback took
  effect. **M48**'s `.accessibilityHidden(true)` would have deleted the payload
  it was meant to protect, and its `.accessibilityValue` is a **silent no-op**
  on a `Capsule`, which generates no accessibility element for a value to attach
  to. **M27**'s remedy would have left `EntryVisualCache` and `FlagLoader`
  serving one database's answers to another, so those two were re-keyed —
  two-level on `ObjectIdentifier(db)`, and on the *slug* rather than the country
  — rather than parameterised.
- **The pass found two live bugs and one it introduced.** Live:
  `EntryVisual.grapeVisual(_:db:)` and `EntryVisualCache.visual(for:)` both
  dropped an injected `db` on the floor, so an injected database got the bundled
  one's well colours; and five `DexEmptyState` call sites read `.shared` through
  a defaulted argument, which would have survived a naive M27 fix and left the
  item falsely closed. Introduced and caught before landing: M46 stopped a
  broken support table from emptying `entries`, which quietly invalidated
  `entries.isEmpty` as the severity test in **both** `dataState` and
  `dataAlertMessage` — a corrupt palette claimed "the catalog is incomplete"
  when the catalogue was whole and colourless. Hence `.supportTableFailed`.
- **Four items were understated by their own text, and the corrections are in
  the entries.** M50's mismatch *reverses sign* (+17.6% at SMALL, −13.0% at
  HUGE) rather than being a flat 18%. M27 is 23 executable reads, not 25, and
  its `ContinentScreen` anchor names a read that does not exist. M48's diagram
  contains zero `Text`, and its `isolated` flag has been dead since v0.5.4 with
  two doc comments still asserting otherwise. M32's "pre-epoch case is unpinned"
  was already half covered.
- **Two seams landed that later items will want.** `WineDatabase(reading:)` +
  `ResourceReader.fixture` makes every M45/M46 branch reachable — none of them
  was, which is why both items survived four re-verification passes — and
  `DBFixture` gives the test target a database with an **empty category**, which
  the shipped catalogue can never produce. The fixture takes JSON because there
  is no alternative: all five `WineEntry` variants declare `init(from:)` in the
  type body, suppressing the memberwise initialiser, so a `WineEntry` cannot be
  built by hand at all.
- **M50 wrote down two ceilings M49 will hit**, and asserted them:
  `26·f + 8 ≤ 46` for the search shell (**f ≤ 1.462**) and `≤ 44` for the
  profile name row (**f ≤ 1.385**). M49 cannot raise the text factor past those
  without a test saying so.
- **Verification.** `swift build` clean. `scripts/typecheck-ios-surface.sh`
  clean against the baseline over the whole UI batch — it caught one real error
  (a `FlagSwatch` reaching for a `db` that was not in its scope) and needed no
  new baseline entries. Core behaviour was *executed*, not merely compiled: 19
  loader assertions, 12 highlight descriptions, the M50 arithmetic at all three
  text steps, and 30-odd palette assertions, all against the real bundled data
  via the scratch runner. Every test file was type-checked with the swift-testing
  macros stripped, since `swift test` cannot run on this host. **`swift test`
  itself was not run** — the standing gap in KNOWN-ISSUES; CI is the first thing
  that executes these suites.

**2026-08-01 — the whole Low row (L1–L45).** All 25 open and partial items.
Low open 25 → 0; total open 45 → 20, and four workstream rows empty completely
(Performance, Pipeline & reproducibility, Light mode & contrast, Release &
licensing).

- **Three of the fixes are structural and worth knowing about before touching
  the areas they landed in.** `SettingsCache` (**L16**) memoises the five
  settings that are read on the render path, invalidated wholesale by
  `UserDefaults.didChangeNotification` — `TextScale.current` alone was a
  defaults read per `Font`, per glyph run, per render. `DexTileLivery` (**L33**)
  is now the only place a tile face is spelled, replacing two parallel tables
  keyed on the tile's *display string*. `DexAssetAudit` (**L26**) resolves every
  id the manifest names through the bundle and reports per surface in
  SETTINGS > DEV, replacing count-only rows that said nothing about whether the
  files existed.
- **Four items were closed by fixing the comment rather than the code**, and
  each says why the code was right: **L37** (single-item removal really should
  confirm — on the TRIED shelf it takes a written note with it), **L45** (the
  manifest fallback must *not* be substituted at load, or a rasterisation gap
  ships as an ordinary question-mark glyph), and the tail of **L43** and
  **L33**. An audit line is a hypothesis about which half is wrong.
- **Two items turned on the trap they had recorded, and both traps were real.**
  **L10**: invalidating the display link in `dismantleUIView` unconditionally
  would freeze the globe on the first skin change, because SwiftUI may build the
  replacement before dismantling what it replaces — so `detach(from:)` matches on
  the view and the restart in `start()` landed in the same edit. **L32**: keying
  the island clearance off `safeAreaInsets.top` would close the gap on exactly
  the cutout devices that need it open, because `.statusBarHidden()` can collapse
  that inset to zero; the home indicator is the signal that has no such trapdoor.
- **What was deliberately not done, and why.** **L20**'s 8.4 MB of provably
  lossless saving across `art/`'s 298 masters, and the fate of
  `art/icons/reference/` and `art/icons/attic/`: rewriting the artist's masters
  is a maintainer's call, not a side effect of an audit fix, and git keeps the
  old blobs either way. The tool and the policy are in place; the command is in
  the README. **L33** was fixed at the sites the item named rather than swept
  across all 205 hexes — most of the remainder is `Color(dexHex:)` over
  *generated* palette values, which is data rather than a bypassed token.
- **Verification.** `scripts/typecheck-ios-surface.sh` clean against the
  baseline after every batch — it is the only local check that sees `VinodexUI`,
  and it caught the two errors this work introduced (a `@MainActor` static read
  from a nonisolated context, and a global-actor loss converting
  `Haptics.warning` to a plain closure). One shim gap was fixed rather than the
  app, per the script's own rule: `UINotificationFeedbackGenerator` (**L38**).
  `swift build` clean. `npm run generate` reproduces byte-identically apart from
  **L25**'s new `flagSlugs`, whose 33 entries were checked against both rules it
  replaces. **L26**'s probe was re-run in Python against the real bundle: 68/68
  icons, 94/94 `art:`, 96/96 flavorArt, 14/14 grapeArt, 30/30 styleArt, 33/33
  flags. **`swift test` was not run** — swift-testing is unavailable in this
  toolchain (`no such module 'Testing'`), which is the standing gap recorded in
  KNOWN-ISSUES; CI is the first thing that runs these tests.

**2026-07-31 — M11 M17 M18 M20.** The four items still open in the M11–M20
range (**M12** is won't-fix; **M13–M16** and **M19** were already closed). Medium
open 24 → 20; the Performance row loses its only Medium and Accessibility goes
6 → 4 Mediums.

- **Two of the four were closed by a different mechanism than their own remedy
  line proposed**, and both entries carry the reason. **M17** asked for a key in
  `xtool.yml`; that file is not a passthrough for the generated Info.plist —
  xtool does not let the app declare its own *version* there, as
  KNOWN-ISSUES.md already records, so an orientation key would have read as a
  lock while doing nothing. The lock is `supportedInterfaceOrientationsFor` in
  Swift, which overrides the plist anyway. **M18**'s remedy said "static
  marquee"; a *paused* marquee hides the tail of any label wider than the strip,
  and measured against the bundled Press Start 2P in 256pt of usable width,
  `DAILY CHALLENGE` is 288pt at the default text step — so the still form is a
  separate shrink-to-fit label. Taking away motion must not take away words.
- **The review pass caught three regressions this batch introduced**, all three
  the same shape — a fix that left the feature worse than not fixing it:
  `PulseGlow`'s `@State` latch survives the Reduce-Motion branch swap, so
  turning the setting back *off* left the orb and lamps stuck at full glow
  permanently; the flip's compensating back-plate rotation is half of one
  mechanism, so dropping only the container's left the engraved wordmark
  mirrored; and a velocity ceiling placed inside `drag` rather than `endDrag`
  capped half of the rotation the finger was causing, making the globe's gain a
  function of how fast you moved it (2.0 rad slow → 1.31 rad fast over the same
  200pt). All three are fixed and described in their items.
- **M11 was verified numerically**, since nothing in this repo can run the UI:
  both implementations simulated in plain Swift over a 200pt sweep plus a
  second of coast. At 60Hz the rewrite matches the old code to three decimals;
  at 120Hz the old code doubled the autospin, halved the inertia and cut a
  flick's coast by more than half, and the rewrite reproduces its own 60Hz
  numbers on both. The marquee measurement above is CoreText against the real
  `.ttf`. Neither is a substitute for the `ios` CI job, which is still the only
  thing that type-checks any of this.
- Follow-ons, none of them claimed as closed: **L11** is narrowed but not
  resolved (Reduce Motion stops `PulseGlow` entirely; the shadow-radius
  animation and the missing flip-pause are still there for everyone else);
  **M20**'s `Continent.displayName` is new in VinodexCore and pinned by
  `ContinentTests`, which is the only part of this batch a local test run can
  reach.

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
  `../PLAN.md` that could not be found from inside the repo. *(Correction,
  0.6.5 batch 4: it did exist — at `HGapps\PLAN.md`, one level above the repo
  and therefore outside any checkout. It has since been moved here as
  [PLAN.md](PLAN.md) and is a real sibling of this file.)*
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
- The prioritized next-sittings pick from this set lives in [PLAN.md](PLAN.md).
  *(Was marked "dead link as of 2026-07-31 — no PLAN.md exists anywhere under
  `/opt/projects`". That verdict was wrong: the file lived at `HGapps\PLAN.md`,
  one level above the repo, so it was outside the checkout the audit could
  see rather than absent. Moved into this folder in 0.6.5 batch 4, at the
  user's request, precisely so both collaborators can reach it.)*

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
