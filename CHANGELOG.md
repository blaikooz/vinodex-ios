# Changelog

All notable changes to Vinodex for iOS. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

**Annotated git tags are the version of record** (`v` + `AppVersion.fallback`).
xtool 1.17 stamps `CFBundleShortVersionString = 1.0.0` into every bundle it
builds and offers no key to override it, so the Info.plist is not a version —
see [KNOWN-ISSUES.md](KNOWN-ISSUES.md). `AppVersion.placeholders` exists to
reject that stamp rather than display it.

**On the version numbers.** They grew a joint per release until v0.4.3 settled
on three components, which is also the most `CFBundleShortVersionString`
accepts; `AppVersionTests.versionShape` pins it there. The older four- and
five-part numbers are kept exactly as they shipped, because a changelog that
renames history is worse than one that explains it.

**This file was backfilled on 2026-08-03** (AUDIT **M37**), together with 24
annotated tags. Entries down to v0.2.1 are drawn from the commits' own bodies,
which are unusually detailed; the seven marked *(recovered)* had thin or empty
commit bodies and were reconstructed from the commit subject, the diffstat and
the version-annotated doc comments throughout `Sources/`. Nothing in them is
invented — where the record is thin the entry is short.

## [Unreleased]

### Added
- **Back up and restore** (AUDIT **M35**) — SETTINGS ▸ STORED DATA writes a
  `SavedDataArchive` holding every shelf, rating, streak and setting as one
  JSON file the user keeps outside the app's container, and reads one back.
  `SavedDataKey` is the registry of all 20 persisted keys, and both the
  exporter and the importer switch over it exhaustively, so a new key cannot
  be silently dropped from a backup.
- `reload()` on the six stores that read `UserDefaults` once in `init`, without
  which a restore would display nothing and then be overwritten by stale
  in-memory state on the next mutation.
- Tests for the filter predicate's `.type` / `.tasting` / `.soil` / `.system`
  branches and for the `styleClass` / `colorType` keyword precedence (**M33**),
  and for `SearchState` and `DexRoute`, which had zero test references
  (**M47**).

### Changed
- **The largest text size is larger** (AUDIT **M49**). HUGE goes from 1.15× to
  1.30×, and the smallest text in the app now draws at 11pt rather than 8.5pt on
  the default setting — Apple's readability minimum, and the change that affects
  people who never open Settings. Still three steps: a fourth button made the
  picker row too tight to read. Four fixed frames that would have overflowed now
  size themselves from the text, so a stat label, a search capsule, a globe
  marker and a filter chip all keep their shape at the top step.
- `CHANGELOG.md`, and 24 backfilled annotated tags (**M37**).

### Fixed
- **Rosé and Orange Wine's COLOR chip opened onto an empty list.** Neither
  colour exists on any grape — rosé is pressed from red grapes and orange wine
  from white ones, as both entries' own descriptions say — so the chip now
  leads to the grapes the style is actually made from.
- **Prosecco was labelled a rosé.** The colour inference matched substrings, and
  "rose" sits inside "p*rose*cco", so Italy's best-known sparkling white wine
  carried a ROSE chip on its own page. Colour words are matched whole now;
  Prosecco reads as DUAL, the label for a name that states no colour.
- An over-wide chip in a filter row was drawn past the edge of the screen, where
  the device casing clipped it — so it vanished instead of looking wrong.
- `SavedDataReset.wipeAll()` described its key array as complete while omitting
  three keys its store calls did clear. It iterates `SavedDataKey.allCases` now,
  which cannot drift.

### Documented
- **"Changing the bundle ID is a one-way door"** in KNOWN-ISSUES — the ordered
  preconditions, and the reason the audit's proposed "data-migration step" is
  not writable: on iOS the bundle ID *is* the container identity.

## [0.6.5] — 2026-07-31

Tagged `v0.6.5` at `f72e9a8`. Batch 3, labelled "6.3.3" by the maintainer and
mapped to the next patch per house convention.

### Added
- **PSVINO skin** — DualShock 2 charcoal moulding, console-grey deck,
  triangle/circle/cross status lamps, cross-blue powered parts, boot-blue
  marquee.
- The title returns to a moulded home: a trapezoidal lip protruding from the
  chassis top, brushed metal letters seated in its lower band. It lives on dead
  chassis, so the LCD keeps its height.
- `horizon-md/` and `godot-md/` collaborator doc folders; AUDIT.md moves into
  `horizon-md/`.
- Coming-soon flags ship for real — the 0.6.4 wiring was manifest-only because
  the flag-copy step never ran. 33 flags total.

### Changed
- The per-skin back-plate piece becomes a postage stamp, matching the badge
  stamps; the die-cut sticker is deleted.
- 26 icons replaced through the pipeline from the `newpass` masters — 14
  subclasses, the BLEND styleclass, 10 style portraits.
- Globe markers up to 18pt with matched projection bounds.
- The pixelflags master relocates into the shared assets tree.

### Fixed
- **Globe tint moves into the texture itself** via `CIColorMatrix`. Root cause
  of two failed passes: `SCNMaterial.multiply` is ignored on-device under the
  physically-based lighting model, so only LIGHT — which rewrites the texture —
  had ever changed.
- `STYLE_ART` untangles the chillable knot: "light-body red" owns
  `lightbodyred`, "chillable red" owns `chillablered`.
- The scanner's in-screen back arrow is removed; chassis Back owns stepping.

## [0.6.4] — 2026-07-31

Tagged `v0.6.4` at `bd89a0c`. The spec was authored as "0.6.3"; that number had
already shipped and been tagged, and a version naming two builds names neither.

### Added
- **Postage-stamp back plate** — code-drawn perforated frame, paper stock,
  keyline, denomination corner and a shared worn/grain overlay. `StampCatalog`
  in Core drives them off Passport badges, one stamp per unlock.
- Per-skin aged sticker, with a new `art/icons/stamps/` pipeline.

### Changed
- The VINODEX title moves into the island strip between orb and cog, brushed
  metal at 16pt with no plate; the 0.6.2 trapezoid bump is gone and the LCD
  gets its 34pt back.
- Header tiles merge icon and label into one coloured chip.
- The DATA page is fixed-height, with the growth wave absorbing the leftover
  LCD.

### Fixed
- Scanner step-4 flavour entries render as hero-icon tiles, so the drawn
  flavour portraits finally reach the scanner — the chips had been flattening
  the note's generic glyph into the chip ink.
- Chassis Back steps backward through the questionnaire; popping the route
  while state persisted had made Back look dead.
- **Globe tint keys on `LcdMode`** — the 0.6.2 pass keyed on `ChassisSkin`, so
  screen modes never changed it.
- GSM Blend's `styleArt` portrait deleted: the 0.6.2 swap had landed, but
  `EntryIconWell` draws `artName` over `iconID`, so the portrait covered it.

## [0.6.3] — 2026-07-30

Tagged `v0.6.3` at `b48ad20`. 208 tests, 12 new.

### Added
- **Element-wise `entries.json` decode** (AUDIT **H2**): one malformed entry
  costs one entry, not the database. Failures are named by id in
  `decodeErrors` and surfaced by a launch `DexAlert` and an explicit DATA LOAD
  ERROR list state (**M2**).
- `schema.json` stamp (`SCHEMA_VERSION 1`) emitted by the generator and
  asserted at load (**M3**, Swift half).
- `RecentlyViewedStore` — a capped 20-id trail on the user page.

### Fixed
- `IconLoader` picks density-matched `@2x`/`@3x` glyph variants; `DexIcon`
  samples with `interpolation(.none)` (**H6**, **L28**).

## [0.6.2] — 2026-07-30

Tagged `v0.6.2` at `518d6f7`. **v0.5.8 through v0.6.2 landed in one commit**
(`869c3b7`) and share this tag — see the note under 0.5.8 below.

### Added
- **Wine Exam** with modal verdicts and a tier ladder; scanner taxonomy tiles
  with drawn icons; **filter search** (search bar, chip dropdown, country facet
  and live counts); geographic region dots from an authored `mapPosition`,
  land-snapped.
- **GODFORSAKEN** rarity tier above NOBLE.
- Appellation systems shipped end to end with spelled-out names.

### Changed
- Catalog to **375 entries** — 128 grapes, 104 regions, 31 styles, 106
  flavours, 25 countries, with zero dangling cross-references.
- Skins: RETROVIN (purple back smoke), BLUSH, and a VIN JAUNE rename.
- Code-driven rarity leaf recolour (`GrapeSpriteLoader`), gold berries for
  sweet whites, darker light/medium red bunches, 1px `PixelOutline`.

## [0.6.1] — 2026-07-30

*(recovered — no tree exists for this number; see 0.5.8.)*

### Changed
- Chassis control sizing raised, then eased back a notch in 0.6.2.

## [0.6.0] — 2026-07-30

*(recovered — no tree exists for this number, and no source comment references
it. Listed for continuity only.)*

## [0.5.9] — 2026-07-30

*(recovered — no tree exists for this number; see 0.5.8. Reconstructed from 15
version-annotated doc comments.)*

### Added
- The chip filter's search box, and its dropdown header that unfolds six facet
  rows, folded away by default.
- Region and country outline glyphs with a red location dot, at well size.

### Changed
- TASTING QUIZ becomes **WINE EXAM** — label only; the `wsetQuiz` route case
  keeps its name because it is woven into `ScreenStateStore` keys.
- The quiz verdict is a popup over the question rather than a panel.
- NOUVEAU renamed; the drawn globes reworked at the default 0.62 scale.
- RETROVIN's back plate becomes its own atomic purple.

## [0.5.8] — 2026-07-30

*(recovered — reconstructed from 16 version-annotated doc comments.)*

> **0.5.8 through 0.6.2 landed in one commit** (`869c3b7`, whose
> `AppVersion.fallback` goes straight to `0.6.2`). They are listed separately
> because they were separate batches, but **there is no tree to check out for
> the intermediate numbers and they cannot be tagged** — a tag would point at a
> tree that never shipped.

### Added
- **A second sizing axis, `UIScale`** — chrome scale, independent of
  `TextScale`, with the same two-button shape as TEXT SIZE.
- The country's drawn outline with one red dot per region.

### Changed
- Region rows read as their state or country rather than as the region alone.
- The detail hero's icon well becomes rectangular rather than square.
- Country routes take the scan-family label — the page's own hero already names
  the country, so the marquee names the *kind* of page.
- The roster is capitalised like the rest of the app.

## [0.5.7] — 2026-07-30

Tagged `v0.5.7` at `adcd77b`. 195 tests.

### Added
- **The `art:` icon namespace**, routing drawn pixel art through `DexIcon`
  untinted — classes, subclasses, colour, body, climate, soils, style classes
  and country/state outlines (88 icons). The white pass is border-flood only,
  so interior white survives.
- Generated walnut and brushed-steel chassis tiles.
- Countries merge into search results in name order, in the entry-tile row
  style.
- The marquee runs segments with seam-equal gaps and a per-page SF Symbol.

### Changed
- Regions carry outline art instead of a key-grape glyph over a masked flag.
- Flavour blurbs describe the aroma; Liquorice merged into Licorice, and the
  umbrella Citrus replaced by real members. 284 → 282 entries.

### Fixed
- The button tap sound trimmed 1.03s → 0.17s (311ms of leading silence cut),
  with the engine primed at boot so the first tap lands on time.

## [0.5.6] — 2026-07-30

*(recovered — the commit body is a co-author trailer only. From the subject and
a 72-file diffstat.)*

### Added
- Style art; the SFX pack; skin emblems; countries in search.

### Fixed
- A general transparency fix across the imported art.

## [0.5.4] — 2026-07-30

*(recovered — subject and a 64-file diffstat.)*

### Added
- Grape bunch icons (`import-grape-art.py`); wave-2 flavours.

### Changed
- Buttons become skin-owned; several renames.

### Fixed
- A marquee fix.

## [0.5.3] — 2026-07-30

*(recovered — subject and a 113-file diffstat.)*

### Added
- **Grüner Boy** and **VinoFD** screen modes; four more skins; globe glyphs.

### Changed
- Chrome themed per screen mode; transparent flavour art.

## [0.5.1] — 2026-07-30

*(recovered — subject and a 99-file diffstat.)*

### Added
- Themed screen modes; flavour pixel art; the Wine Xmas skin.

### Changed
- Navigation polish. **Sounds are off by default from here** — they are opt-in.

## [0.5.0] — 2026-07-30

*(recovered — subject and a 33-file diffstat.)*

### Added
- **Quiz tiers**, the **daily challenge**, **shelves with ratings**, the
  **passport**, a sound pack and new skins.

## [0.4.3] — 2026-07-30

Tagged `v0.4.3` at `fbc51a0`. Three branches — `screen-state`,
`version-independent` and `audit-fixes` — all cut from `0a446d3` and developed
without seeing each other, landing together. 143 tests.

**Versioning starts fresh here.** The numbers had been growing a joint per
release and three concurrent branches each claimed a different fourth or fifth
level for overlapping work. 0.4.3 is three components and `AppVersionTests`
pins it there.

### Added
- `ScreenStateStore` covers the whole app: scroll anchors, expander flags and
  named values, keyed per screen instance and cleared only by Home. Closes
  **M26**.
- A light-mode and contrast pass, a11y labels and 44pt targets, minified JSON
  (~⅓ off the bundled data), and a generator schema self-check.

### Fixed
- **The back plate stops lying.** xtool stamps `CFBundleShortVersionString` as
  `1.0.0` and the guard only rejected `1.0`, so every build since `0a446d3`
  displayed v1.0.0 whatever anyone set. `AppVersion.placeholders` rejects
  build-tool defaults, and resolution became a pure function a test can reach.
- A scroll-restore bug across six screens: `.padding()` outside
  `scrollTargetLayout()` made every restore jump the list sideways by its own
  leading inset. `.contentMargins(_:for: .scrollContent)` is the inset the
  scroll system actually knows about.
- 21 orphan icons pruned; the rasteriser hardened.

## [0.4.2.1.1] — 2026-07-29

Tagged `v0.4.2.1.1` at `4b75fae` — **the first tagged iOS release**, cut
because AUDIT **M37** asked for tags: no binary could be traced back to a
commit. 135 tests.

### Added
- MINIGAMES becomes **TOOLS**, and the shelf gains a **chip filter** (five
  facets, with the surviving count live on every chip before you tap it) and a
  **WSET-shape tasting quiz** generated from the shipped data rather than from
  an authored bank.
- A ten-step **guided tour** behind BEGIN in settings — opt-in only, and drawn
  as a diagram of the device rather than as an overlay on the live chassis, so
  it cannot desynchronise from the navigation stack.

### Known issues
- xtool stamps `CFBundleShortVersionString` as `1.0.0` and `AppVersion` only
  rejected the literal `1.0`, so the back plate reads v1.0.0 rather than this
  number. Fixed in 0.4.3.

## [0.4.2.1] — 2026-07-29

Tagged `v0.4.2.1` at `529f89f`. The richest commit body in the history. 114
tests.

### Added
- **Screen state now covers the whole app.** `ScreenStateStore` gains named
  values — strings, numbers and JSON — because what the remaining four screens
  hold is neither a scroll position nor a boolean: the scanner's five questions
  and answers, the daily reveal's held pick, the settings panels' per-section
  scroll, and the globe's heading and tilt.
- **Skins become five devices rather than one device in five colours.** Each
  carries its own orb and halo, its own six-stop lit-button ramp
  (`ChassisAccent`) and its own marquee phosphor. Vinodex Classic is
  byte-for-byte unchanged — it is the house device the others vary from.
- A 96pt avatar holding your own photograph via `PhotosPicker` —
  out-of-process, so no permission prompt and no plist key — downscaled to
  512px and written to Application Support rather than parked in
  `UserDefaults`, which is read wholesale at launch.

### Changed
- The back plate leads with the way out: SWIPE TO RETURN moves above the
  nameplate as a recessed dark chip. It had been engraved grey at the bottom
  edge, on brushed silver, and the exit was the one thing you could not find.
- CUSTOMIZATION becomes CUSTOMIZE. The raw values are display copy, not
  storage, so nothing resets.

### Fixed
- Tapping OPEN ENTRY on a scanner reveal used to discard the questionnaire, so
  seeing the second candidate meant answering all five questions again.
- The daily reveal's "once per open" was being measured in view lifetimes, and
  the view is destroyed by any navigation away — so following a link out
  advanced the cycle and put the silhouette back up.

## [0.4.1.7] — 2026-07-29

Tagged `v0.4.1.7` at `e1786ff`. 106 tests.

### Added
- **`ScreenStateStore`** — per-screen scroll anchors and named expander flags,
  keyed per screen instance so France and Italy never share a position. Anchors
  name a section rather than a pixel offset, so a page whose content shifted
  underneath still restores somewhere sensible. `RootView` has no
  `NavigationStack` — it swaps the LCD's content on a path change — so the
  screen you leave is destroyed and rebuilt when you return, taking its
  `@State` with it.

### Removed
- The derived caption under a country's INFO blurb ("N REGIONS IN THIS
  DATABASE" plus a climate list). It described the app rather than the country,
  and the REGIONS section below already showed the count.

## [0.4.1.5] — 2026-07-29

Tagged `v0.4.1.5` at `885a62f`. *(recovered — the commit body is the
publish-script stamp only.)*

### Added
- Real entitlements; styles tuning; a bigger settings surface.
- `AppVersion` first appears here — before it, the back plate carried a
  hardcoded literal.

## [0.4.1] — 2026-07-28

Tagged `v0.4.1` at `30af72b`. *(recovered — the commit body is the
publish-script stamp only.)*

### Added
- Fast master search; the settings grid; the minigames hub.

## [0.3.9] — 2026-07-28

Tagged `v0.3.9` at `3e2c0d3`. 63 tests.

### Changed
- **Settings becomes a pushed screen rather than a side flap.** The flap could
  never be more than a strip wide, which is the wrong shape for a page of
  toggles; a route also gives it Back and Home for free.
- Cross-linked header tiles take a rounded outline instead of a corner arrow.
  The arrow read as a separate control sitting on the tile; an outline says the
  tile itself is the target.
- Country tiles link to the country page rather than to a filtered region list.

### Fixed
- **Master search was slow because `results` was a computed property**: every
  keystroke and every unrelated re-render re-filtered and re-sorted all 284
  entries, on the one screen with every category selected. Recomputed once per
  query via `task(id:)`.
- Text was vanishing in light mode wherever a view still hardcoded `.white` or
  `stone200` — grape characteristics, flavour profile rows, stat bars, chip
  galleries.

## [0.3.8] — 2026-07-28

Tagged `v0.3.8` at `8b3fcb2` — the point the original audit ran against. 63
tests.

### Changed
- **Light mode across content surfaces**, roughly 70 call sites: page grounds,
  section headers and their rules, INFO body copy, hero washes and title
  shadows, row surfaces and borders, save buttons in both states, and the
  search wells.
- The green needed replacing rather than reusing: `#4ADE80` is a dark-theme
  colour and effectively invisible on white, so light mode drops to a deep
  bottle green that still reads as "the green".

## [0.3.7] — 2026-07-28

Tagged `v0.3.7` at `c6a0a94`.

### Fixed
- **The home screen's spacing break and its missing user button were one bug**,
  and a regression from 0.3.6. Rewriting the marquee "as simply as possible"
  dropped the `GeometryReader` that gave the scrolling strip a definite width
  to clip against — the file's own comment had warned about exactly this.
  Without it the `.fixedSize()` label pair, ~1500pt wide, ignored `maxWidth`
  and squeezed the left control out of the row.

## [0.3.6] — 2026-07-28

Tagged `v0.3.6` at `aa82e5d`. 63 tests.

### Added
- `SavedItem`, resolving entries and saved places together.
- Regions take their key grape's glyph — Bordeaux reads as blackcurrant,
  Burgundy as cherry — falling back to climate. No new assets needed.

### Changed
- **Screen mode becomes its own setting** rather than riding the chassis skin:
  the shell and the screen are independent choices.
- Text size scales every font rather than the main menu only.
- The daily reveal rotates grape, region and style, one step per day.

### Fixed
- **Saved entries were going missing.** Countries and states save under
  prefixed ids because neither is an entry, and `entries(in:)` compactMaps
  against the database — so every place bookmark was silently dropped on the
  way to the screen.
- The marquee is rewritten: it had been measuring the label through an
  attributed string while rendering it italic, so measured and drawn widths
  disagreed and the seam jumped every cycle.

## [0.3.5] — 2026-07-28

Tagged `v0.3.5` at `e10b769`. 60 tests.

### Added
- **Grape of the day**, played as a reveal. The pick is derived from the date
  rather than stored, so everyone gets the same grape on a given day and
  reopening never reshuffles it. Restricted to the free tier deliberately: a
  locked pick is a daily advertisement, not a daily read.
- State screens, with the state flag as hero.
- Country pages gain INFO, NOTABLE GRAPES ordered by how often each appears
  across the country's regions, and every appellation system in use.

### Changed
- Settings is hinged on the right edge of the LCD rather than covering it.
- Text size is capped at 1.25× — the retro face has no optical sizes, so a
  larger jump breaks the tiles.

## [0.3.4] — 2026-07-28

Tagged `v0.3.4` at `da19449`. 54 tests.

### Added
- **Country pages** — flag hero, region count and the regions themselves,
  assembled from region origins rather than from a data entry, so countries
  needed no data change to exist. USA additionally gets a STATES section.
- A name field on the user screen, stored locally; there is no account, and
  inventing a backend for a display name would be the tail wagging the dog.

### Changed
- The flip moves from a settings button to a two-second hold on the orb, which
  depresses and darkens under the finger with a haptic on press, so the
  feedback lands before the flip does.

### Fixed
- **Cross-links now clear the paywall.** A header tile carries a route rather
  than an entry, so a `.detail` link was pushing straight past the gate.

## [0.3.3] — 2026-07-28

Tagged `v0.3.3` at `9c319e0`. 54 tests.

### Added
- **The full database: 284 entries**, up from 184.
- Header tiles cross-link — colour and type to filtered grapes, origin and
  country to that country's regions, climate to that climate's regions. A tile
  with nowhere to go stays inert rather than tappable-but-dead.

### Changed
- The free tier is expressed against grape properties rather than a hand-listed
  set, so it stays correct as the data grows.

### Fixed
- **`COUNTRY_GATE` is excluded, and finding out why was the interesting part.**
  One undecodable category fails the *entire* `entries.json` array, so the first
  full-database build came up with zero entries and 54 tests failing on empty
  collections rather than on anything real. (This is the defect **H2** would
  eventually fix properly, in 0.6.3.)

## [0.3.2] — 2026-07-28

Tagged `v0.3.2` at `67987d2`. 54 tests.

### Added
- **A starter-tier switch**, as the shape a real IAP would plug into: the paid
  state becomes a receipt check instead of a stored flag and nothing else moves.
  Off by default. `tiers.json` is emitted alongside the dataset.
- Soft hyphens in chip labels, so a long single word can break across two lines
  instead of shrinking — SwiftUI has no hyphenation setting for `Text`.

### Changed
- Locked rows are desaturated rather than dimmed to nothing — seeing what is
  behind the paywall is the point of showing it.
- The clear-all confirmation is drawn **in the LCD** rather than as a system
  dialog sliding up from the device.

## [0.3.1] — 2026-07-28

Tagged `v0.3.1` at `ed2a15d`. 42 tests.

### Changed
- Dataset grows to 35 grapes, picked to stress layout rather than to round out
  the canon: the two longest names in the set, umlauts, an apostrophe, and RARE
  tiers so the rarity crown is not only seen on NOBLE.
- The marquee's width is measured from the font rather than through a
  background `GeometryReader`, which only reports after a layout pass — so on a
  cold render the banner had sat blank for a frame and popped in.

### Fixed
- Continent glyphs were still generic in two places: `EntryVisual` returned a
  nil `iconID`, and `ContinentScreen` hardcoded an SF Symbol globe on the
  theory the rasterised set might be missing. The icons are committed to the
  bundle, so that hedge protected nothing while making every continent
  identical.
- Corner clipping was real and measurable: a control 10pt above the bottom edge
  is cut into by ~23pt of a 55pt corner arc.

## [0.3] — 2026-07-28

Tagged `v0.3` at `bc61a3e`. 42 tests. *(Two components, as the tree says. Not
normalised to 0.3.0 — a tag that disagrees with the tree it points at is the
exact failure M37 exists to prevent.)*

### Added
- **Bookmarks.** `BookmarkStore` lives in Core and stores ids rather than
  entries — the dataset is regenerated often and stored copies would go stale;
  an id that no longer resolves is dropped on read.
- Continent glyphs, replacing six identical `lucide:globe` rows.

### Changed
- **Chassis padding is symmetric by construction**: header and footer are both
  `controlBandHeight`, so neither can drift from the other. Net ~36pt back to
  the LCD.

### Fixed
- Appellation colour was inconsistent: the list tile keyed the literal "SYSTEM"
  against the grey table while the detail keyed "AOC" against the rose one, so
  one appellation had two colours depending on where you saw it.

## [0.2.2] — 2026-07-28

Tagged `v0.2.2` at `85d9766`.

### Added
- The MIDNIGHT chassis skin. Only the moulding changes; the LCD is untouched,
  so legibility cannot regress with the skin.

### Fixed
- **Globe markers land a quarter-turn from the coastline they name.**
  `SCNSphere` does not lay an equirectangular texture out the way three.js
  `SphereGeometry` does. Replaced the screen-space nudge with a −90° longitude
  offset: two rounds of pixel nudging had summed to roughly the globe's
  on-screen radius, which is what `sin(90°)` of a radius-scale error looks
  like. An angle stays correct as the globe spins, where a fixed pixel shift
  over-corrects away from centre.
- Entry detail keys its `ScrollView` on the entry id — following a cross-link
  reused the same scroll view, so a new entry opened halfway down a screen you
  had never seen.

## [0.2.1] — 2026-07-28

Tagged `v0.2.1` at `73e10d4`. The earliest release carrying a version number.

### Added
- The chassis: one control size throughout, with the island strip grown from 55
  to 70pt so a full control fits beside the cutout.
- A FLIP DEVICE action revealing the brushed metal back plate — engraved
  nameplate, corner screws, serial.
- Globe search opens its own screen rather than laying results over the sphere.

### Changed
- **The pixel-V wordmark becomes a brushed-silver cog.** A logo reads as
  branding, so nobody expects it to be tappable; a cog says what it does.
- Back and Home act on whatever is in front of you: they dismiss the flip or
  the panel before navigating, instead of moving underneath and appearing to do
  nothing.

---

*Earlier commits (`acdc74f`…`b732221`, 2026-07-27/28) predate version
numbering.*

### Numbers that never existed as a tree

Recorded so nobody looks for them again:

| Number | Why there is no tag |
|---|---|
| `0.4.2.1.2` | Set at `9992a37`, re-set at `226d118`, never released; superseded by the 0.4.3 collapse. It is the number `AppVersionTests.versionShape` exists to prevent. |
| `0.5.2`, `0.5.5` | No evidence they ever existed. |
| `0.5.8`–`0.6.1` | Real batches, no tree — they landed inside `869c3b7` with the rest of 0.6.2. Entries above, tags impossible. |

`v0.4.3`'s bump landed at `6cb1bde` and the tag sits two commits later at
`fbc51a0`. **Left alone deliberately:** moving an already-published tag is
worse than a two-commit offset.
