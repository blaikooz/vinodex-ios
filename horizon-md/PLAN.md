# HGapps plan — open issues, cleanup, and next batches

**Authored by Horizon.**

*2026-07-30, written at iOS v0.6.2 (tagged, on main). This is the working
plan that consolidates the open ends of AUDIT.md, KNOWN-ISSUES.md,
V1-ROADMAP.md and the archived shipping/port reviews. Run batches with the
`dexbot` agent (`.claude/agents/dexbot.md`); it knows the pipeline and gates.*

> **Moved 0.6.5 (batch 4 phase 3).** This file lived at `HGapps\PLAN.md` — one
> level above the repo, where only one collaborator could see it. It now sits
> in `horizon-md/`, so both collaborators do; the AUDIT/auditS/arch trio it
> draws on moved alongside it and then on into `godot-md/`. The
> workspace paths it describes (`HGapps\…`) still refer to the folder **above**
> this repo. Note that several items below are already done — the pixelflags
> decision, the root-doc archive, the `README-layout.md` rewrite and this very
> move all landed in batch 4.

## Where things stand

> **Updated 2026-08-04, at iOS v0.7.3.** The line below is the 0.6.2 baseline
> this file was written at and is kept for context; the current state is the
> batch log immediately after it.

- **iOS**: v0.6.2 on `main`, tagged. 375 entries (128 grapes · 104 regions ·
  31 styles · 106 flavors · 25 countries), five rarity tiers, tools suite,
  15 skins, geographic region dots, passport stamps. All 196 tests green,
  clean xtool build, deployed.
- **Web**: still at the ScreenState-port baseline. `shared/` mirror synced to
  the 0.6.2 data but the web app has had no feature work since the split.
  This is now the widest gap in the product.
- **Docs**: AUDIT.md (52 open items) and KNOWN-ISSUES.md (runbook) live in
  vinodex-ios and are current. SHIPPING-REVIEW.md and PORT-TO-WEB.md (now in HGapps\archive\) are
  archived (banners point here). V1-ROADMAP.md carries a 2026-07-30 baseline
  correction. The 0.6 missing-data tracker (Downloads) is fully landed.

### Batch log since 0.6.2

Each row is one dexbot batch: the spec it ran from, what it changed, and the
gate result. Kept here rather than only in `AppVersion.swift`'s release notes
because that file answers "what is this build" and this one answers "what has
been happening", which is the question a planning doc is for.

| Version | Spec | Headline | Catalog | Gates |
|---|---|---|---|---|
| 0.6.3–0.6.9 | assorted | Chassis work: button band, top-bar chrome, per-mode globe, recessed button bundles, two skins, back swipe removed, still marquee. See `AppVersion.swift`. | 405 from 0.6.4 | green |
| 0.7.0 | `vinodex-0.7.0` | Sectioned pickers on both axes, WALDGLAS + HALLOWEEN skins, three chip facets, per-skin back plate, stamp drag rebuilt, tools shelf re-cut, marquee glyph table audited. | 405, untouched | 250 tests, clean build |
| 0.7.1 | `vinodex-0.7.1.md` | UI/UX fixes, the new marquee, polish — see below. | 405; South America's marker colour changed, no entry moved | 282 tests, clean build, deployed |
| 0.7.2 | `vinodex-label-reader` | **LABEL SCAN.** Camera → Apple Vision OCR on-device → match against the catalog. Matching/scoring/inference in Core (Linux-gated); Vision, camera and pickers in UI behind `LabelRecognitionProvider`. `xtool.yml` gained `infoPath` for the usage strings. | 405, untouched | 320 tests, clean build, **not deployed** |
| 0.7.2 | `vinodex-0.7.2` | **Consolidation + nine fixes.** All batch branches merged onto `testing`; stamps made draggable at last (A2); the marquee becomes a control surface — lamps are TOOLS/CUSTOMIZE, pins in the corners, PINS on open, MENU glyph, rotating toasts; Africa and Oceania get their own marker colours. | 405, untouched; two continent colours changed | 326 tests, clean build, deployed |
| 0.7.3 | `vinodex-0.7.3a` | **Device experience + the 0.7.3 Foundation.** F1 one entitlement store behind a protocol; F2 one idle timer where there were two clocks; F3 version + changelog moved into `shared/`. Then A1 boot POST, A2 demo mode, A3 firmware history, A4 cheat console, A5 bouncing-V screensaver. | 405, untouched; `firmware.json` is a new generated file | 384 tests, clean build, deployed and eyeballed |
| 0.7.3 | `vinodex-0.7.3b` | **DEVICE WORKSHOP (premium).** The six part axes that did not exist, then the builder over all eight. `DeviceAxis`/`DeviceBuild`/`CustomDeviceStore` in Core; `PartColor`, `GrilleShape` and `ChassisLook` in UI. Gated on F1's `Entitlement.workshop`; GARAGISTE unlocks it. | 405, untouched | 404 tests, clean build, deployed and eyeballed |
| 0.7.3 | `vinodex-0.7.3c` | **EXPANSION PACKS.** Twelve collectible cartridges on a PACKS shelf — three atlas, six device, three display — owned through F1's `Entitlement.expansion`, which finally covers something. Packs **collect rather than gate**. Brazil added to the catalog so the New World pack has a Brazil to name. | **405 → 407** (+2 Brazilian regions); countries 25 → 26 | 425 tests, clean build, **not deployed** |
| 0.7.4 | `vinodex-0.7.4-grapes.md` | **GRAPE OVERHAUL.** `sommbot` authored the data (+25 grapes, +6 regions, corrections to Marselan, Cabernet Gernischt, Sangiovese, Palomino, Tannat, Négrette, Fer Servadou, and the Chile/Croatia gates); `dexbot` took the code side. Two logic fixes sommbot found and left: `levelFromText` and the dead country-gate arm of `find-missing-refs.mjs`. | **407 → 438** (+25 grapes, +6 regions); flavours held at 106, countries 26 unchanged | tests green, clean build, **not deployed** |

**0.7.4, Grape Overhaul** (`vinodex-0.7.4-grapes.md`). The first batch split
across two agents: `sommbot` authored and landed the data in `shared/`, `dexbot`
took the pins, the two logic fixes and the gates. Findings and identity rulings
are in `data-review/FINDINGS.md`, which is the record for anything factual.

- **Two batches were layered uncommitted in one working tree, and they were
  separated rather than merged.** 0.7.3c was deployed but not yet eyeballed, and
  0.7.4's data sat on top of it in the same four `shared/data/*.ts` files. They
  are separable by content but not by path, so the split was done hunk by hunk —
  sommbot had labelled every line it added with the batch it belonged to, which
  is the only reason this was cheap. 0.7.3c was committed first, at its own
  catalog total of 407, with its `Resources/*.json` regenerated from the reduced
  `shared/` so the commit is internally consistent rather than carrying 0.7.4's
  data under 0.7.3c's pins. A `v0.7.4-wip-snapshot` branch holds the combined
  pre-split tree and can be deleted once both commits are confirmed on glass.
- **`levelFromText`'s default swallowed `"None"`, and 60 grapes paid for it.**
  Every test in that function is a substring test against a lowercased string,
  and `"None"` matched none of them, so all 60 whites carrying
  `details.tannin: "None"` fell through to the default of 3 and drew a
  half-full tannin bar — the one value the bar exists to communicate, rendered
  as the middle of the scale. Now 0. The ordering bugs sommbot flagged
  alongside it (`medium-high` dead below `high`; `Medium-Low`/`Low-Medium`
  falling into `medium`) are corrected in the same pass but **move nothing on
  screen**: both call sites round, and `Math.round(3.5) == 4` and
  `Math.round(2.5) == 3` are what those inputs already produced. Verified
  against the live catalog before and after — 60 tannin values moved, 0 acidity
  values moved, and Cabernet Sauvignon's pinned characteristics are untouched
  because it is a red reading "High".
- **`find-missing-refs.mjs` had a gate that had never once executed.** Its
  country arm read `COUNTRY_GATE` out of `entries.json`, a category the
  generator deliberately drops, so the array was always empty, the validation
  loop never ran, and the summary line reported "0 countries" — an honest
  number that read like a pass. It now parses `shared/data/countries.ts`
  directly and reports 30. Proved live with a negative test (a bogus grape
  injected into the Croatia gate is caught and named) rather than by trusting
  the zero.
- **Sommbot's "no Swift change needed for the six new regions" claim held, and
  was checked rather than assumed.** All six use classification strings
  `EntryDisplay.appellationName` already resolves (DO, DOC, AOC, AVA), all six
  origins are countries the catalog already had, and every soil string hits a
  covered keyword. The Azores deliberately take `DOC` over the formally correct
  EU `DOP` to avoid minting a classification string and a chip-colour probe.
- **One thing the data audit could not have caught: `icon: "fruit"`.** Two of
  the new grapes (G150 Alfrocheiro, G160 Corvinone) use an icon key that was
  present in the generator's `LUCIDE_ICONIFY` table but had never been used by
  any entry, so `lucide:apple` had never been rasterised and those two rows
  would have drawn nothing — `IconLoader.image` returns nil for a missing
  asset, and no test or build gate covers icon assets. The glyph was rasterised
  at all three scales. **`scripts/rasterize-icons.sh` was deliberately not
  used**: it prunes every PNG absent from the manifest it is handed, so a
  one-icon manifest would have deleted the other 200.

**Parked from 0.7.4:**

- **Not deployed** — stopped at the clean build by instruction. Worth an eye:
  the tannin bar on any white grape (should be empty, not half), and the apple
  glyph on Alfrocheiro and Corvinone, which is a real fruit glyph on two reds
  and may read oddly next to the grape glyph everything else uses.
- **`bodyFromText` has the same defect shape as `levelFromText` and was left
  alone on purpose.** `t.includes('full')` is tested first, so the
  `medium-full` branch below it is dead and **16 grapes reading
  `body: "Medium-Full"` render a full 5/5 body bar**, indistinguishable from
  the 34 that are actually `"Full"`. (`Light-Medium` likewise falls into
  `medium`, but rounds to the same 3 it already produced, so it is inert.)
  Unlike the tannin fix this is not a clear correction — 5/5 for "nearly full"
  is arguable — and it changes a rendered value on 16 entries, so it wants a
  decision rather than a quiet fix. Cabernet Sauvignon's pin is `"Full"` and
  would be unaffected either way.
- **`vinodex-web` was brought green rather than parked, because the sync had
  already broken it.** `sync-shared.ps1` writes into that repo too, so the
  moment 0.7.4's data landed its suite went red — leaving it there would have
  been leaving damage, not deferring work. Changes are uncommitted, on
  `batch4-into-testing`, for the release pass to pick up: coverage pins (GRAPES
  146 → 171, REGIONS 116 → 124, total 405 → 438, origins 25 → 26 — two batches
  of drift, since web never re-pinned 0.7.3c's Brazil), the quiz determinism
  goldens for both seeds, and one genuine parity bug below. `npm run typecheck`
  and all 363 tests pass.
- **Running web's suite found a 0.7.3c parity gap that iOS's own gates could
  not see.** `web/src/services/entryDisplay.ts` never got the two cases iOS
  added with the Brazilian regions: `IP` was missing outright, and Brazil's
  `DO` was not split off the Spanish one — so Campanha Gaúcha showed a bare
  abbreviation and **Serra Gaúcha printed its system in Spanish**, which no
  test was ever going to catch because a wrong-language expansion still reads
  like prose. Both mirrored from `EntryDisplay.swift`. The lesson is that
  0.7.3c's Swift-side appellation work needed a web pass and did not get one.
- **`FilterTests.filterPlusSearch` moved, and it is not a regression.** Free
  text search covers `entryDescription`, and R122 South West France is
  described as "the arc of country between Bordeaux and the Pyrenees", so the
  France-filtered search for "bordeaux" now returns two regions. Re-pinned with
  the reason recorded; if the intent is that search should *not* reach
  descriptions, that is a separate and much larger decision.

**0.7.3c, Expansion Packs** (`vinodex-0.7.3c.md`). Last of the three 0.7.3
sub-batches, and the one that fills in `Entitlement.expansion` — the case 0.7.3a
minted and left covering nothing.

- **The decision: packs collect and organise, they do not gate — and the reason
  is the passport, not caution.** The spec left it open and named collect/organise
  as the lower-risk default. It is also the only one the code permits. `PassportTier`
  is absolute counts of *tried* entries and its own doc comment states the
  invariant — "a rank you had already earned must not be taken back by a data
  batch" — while `Passport.compute` resolves the tried shelf against the whole
  database and never consults `AccessStore`. A pack that withdrew twenty
  countries' entries until bought would drop the tried count, demote a rank
  already held, empty ALL NOBLE and REGION COMPLETE, and move every denominator
  on the screen. On a shipped app that is a regression, and it decided the item.
- **What was *not* true is that gating was ever the risky half.** Reconnaissance
  found a whole content-paywall already in the tree — `tiers.json`, `db.isFree`,
  `AccessStore.isLocked`, `Entitlement.covers` — behind `starterOnly`, which is a
  *developer* switch, off on every install. So `Entitlement.covers` now reads pack
  membership, because the honest `false` had stopped being honest, and doing so
  can only ever add a key: under `starterOnly` those entries were already locked
  (they are not in the free list), and with it off nothing is locked at all. Two
  tests pin exactly that (`packsLockNothing`, `grantingOnlyUnlocks`).
- **The device and display cartridges must not re-gate what they group.** Every
  non-default skin has required `.skins` since long before packs; giving each
  collection its own entitlement would mean a user who owns the skins bundle no
  longer owns BURGUNDY. `ChassisSkin.requiredEntitlement` is therefore untouched
  and `ExpansionPack.impliedBy` names the old bundle, so owning `.skins` owns all
  six device cartridges the moment this build lands. Ownership is the union,
  never the intersection.
- **The pack catalog is Swift, not `shared/`** — the one list in the app that
  names catalog content from Swift. A pack id is persisted inside
  `Entitlement.expansion` the moment somebody owns it, so it is storage, and
  `shared/` is edited by data batches and by the `sommbot` agent. The membership
  *rules* still point at `shared/`, and `ExpansionPackTests.atlasCountriesResolve`
  is the gate `find-missing-refs.mjs` cannot be — it audits generated data against
  itself and knows nothing about a country list in a `.swift` file.
- **Brazil, because B2 named a country that was not there.** C029 plus Serra
  Gaúcha and Campanha, both in Rio Grande do Sul, added *before* the pack
  referenced them. No new grapes — all six notable grapes across the two regions
  were already in the catalog, which is the house rule for a new country. New
  `IP` appellation expansion, and `("DO", "brazil")` split off the Spanish `DO`
  the way `DOC` was already split three ways. Brazil got a chip colour rather
  than the grey fallback, and its pixel flag had been sitting unused in
  `shared/pixelflags` since the flag drop.
- **C and D disagree with the spec's spellings, and the code won.** C1 asks for
  "Transparent", "Retro Tech" and "Seasonal"; the sections have been CLEARTECH,
  RETROFIT and FESTIVE since 0.7.0 and those words are already on screen above
  the skins they group. D1 asks for "Vintage"; 0.7.1's C1 renamed that section to
  RETRO precisely because a group called VINTAGE containing a mode called VINTAGE
  read as a mislabelled tile. Taking either literally would have put two names on
  one grouping.
- **A2 was answered by promoting a component rather than writing a fifth.**
  0.7.3b's notes flagged that the workshop's chooser duplicates the settings
  picker; A2 asks the shelf to reuse that picker's style, which taken at face
  value means a fifth hand-written grid. The workshop's `partChip` — already the
  one generalised version, serving all eight axes — became `DexPickerTile`, and
  the shelf and the workshop both use it. `skinGrid` and `modeGrid` were left
  alone deliberately: they are 50pt tiles carrying real art, in a module no Linux
  gate compiles, and rewriting the two pickers a user actually looks at was not
  this batch's ask. Four bespoke grids became three plus one shared tile.
- **No cheat code, on purpose.** `CheatCodes`' own note forbids a code that
  reports success and changes nothing, and that is exactly what a pack-granting
  code would do: with `starterOnly` off, every pack already reads as owned.

**0.7.3b, the Device Workshop** (`vinodex-0.7.3b.md`). Second of the three
0.7.3 sub-batches, built on 0.7.3a rather than beside it — C1 gates on F1's
`EntitlementStoring`, `AccessStore(defaults:store:)` and `Entitlement.workshop`,
all of which are 0.7.3a's.

- **The prerequisite check failed, and that was most of the batch.** The spec
  assumes the 0.6.x/0.7.1 chassis work left seven parts individually settable.
  It did not: the device had **two** axes — `chassisSkin` and `lcdMode` — and
  every other part was a *property of the shell*. `ChassisSkin.orb`, `.accent`,
  `.control`, `.grill`, `.marqueeText` are all switches over the skin, so
  choosing BURGUNDY chose a purple orb, purple caps and a pink marquee together;
  a skin was a dye lot, not a palette. The grille had no shape axis in any form
  (four hardcoded 64×2 capsules in `bottomVents`, identical on all twenty-one
  shells), and the font colour was whatever `LcdMode.text` said. Five of the
  seven parts, plus the grille's shape, had to be *built* before a workshop over
  them could exist.
- **`DeviceAxis` is the foundation, and empty means stock.** Eight axes (the
  grille takes two — colour and pattern), one `UserDefaults` key each, and one
  invariant that makes it safe to add to a shipped app: `""` and "no stored
  value" are the same state, so a device nobody has customised is byte-identical
  to 0.7.2's. `chassisSkin` and `lcdMode` keep their spellings — those hold real
  choices on real installs — and `ChassisSkin.storageKey`/`LcdMode.storageKey`
  now *read from* `DeviceAxis` rather than restating the literal.
- **`ChassisLook` is one resolver, not six fallbacks per call site.** The wrong
  way to add overridable parts was `partOrb.map(\.orb) ?? skin.orb` at each of
  twenty call sites — F1's copy-pasted cosmetic rule with six times the surface.
  `ChassisLook` carries the same member names `ChassisSkin` does, so three views
  changed one line each: the *type* of their `skin` property. Every `skin.orb`
  still reads `skin.orb`, and the compiler found the call sites rather than a
  search doing it.
- **One authored hex per palette entry, everything else derived.** Thirteen
  colours across five axes is sixty-five hand-written ramps otherwise — sixty-five
  chances for one stop to come from the wrong colourway, which is the fault
  `ChassisAccent`'s own note calls a manufacturing defect. `PartColor` derives
  the six-stop lit ramp, the moulded cap, the orb bead and halo and the marquee's
  three phosphors through `DexRGB.mixed(with:amount:)`, calibrated against
  CLASSIC's hand-authored parts. `DexRGB` gained `hex` for the round trip.
- **The live preview is the device.** B1 asks for a live preview and the
  workshop runs *inside the LCD of the thing being customised*, so the rows write
  the keys the chassis already reads and fitting a violet orb turns the real orb
  violet under your thumb. Nothing is threaded between the two surfaces because
  there is nothing to thread. The cost is that editing is destructive, which
  REVERT (drawn in a fixed red, not an LCD token) answers.
- **No second source of truth for what the device looks like.** A `CustomDevice`
  is a *recipe*; applying one writes the same eight keys. There is deliberately
  no stored "active build id" — `CustomDeviceStore.matching(_:)` compares, so a
  build that has had one part changed since it was fitted stops matching, which
  is the truth. That was the specific trap the spec named and F1 had just spent a
  batch clearing one layer down.
- **The font axis is the only one with a rule.** Every other part is decoration;
  the font is what the screen says things with, and IVORY on the paper-white LCD
  is a device that has stopped working — recoverable only through text you can no
  longer read. `LcdMode.accepts(_:)` refuses an ink the mode cannot show (the
  four single-phosphor modes) or that will not read on its ground, and falls back
  to the mode's own. Enforced at the point of use rather than in the picker,
  because the failure can arrive *later*: pick an ink on a dark screen, then
  switch to a pale one.
- **C1 is an entitlement flag, not a paywall.** The CUSTOMIZE section is always
  visible; unowned, it describes the workshop and its button says UNLOCK, which
  raises the ordinary `UpgradePrompt`, grants through the one store, and then
  *continues into the builder* rather than stopping at "unlocked!". The six new
  axes ride `.workshop`; the two old ones keep `.skins` and `.lightMode`, so the
  workshop cannot be used to buy twenty-one shells for the price of one bundle.
  GARAGISTE is the cheat code — a real wine word for somebody building the thing
  themselves in a workshop.
- **A 0.7.3a gap closed on the way past:** `ChromeTests.allRoutes` never listed
  `.firmwareHistory` or `.cheatConsole`, so for one sub-batch the marquee-glyph
  uniqueness gate could not see them. All three 0.7.3 routes are listed now.

**0.7.3a, the Foundation batch** (`vinodex-0.7.3a.md`). First of three 0.7.3
sub-batches. Section 0 (F1–F3) is the deliverable; 0.7.3b and 0.7.3c are built
on it, so it was written to be depended on rather than shaped around what
A1–A5 happened to need.

- **F1 — one entitlement store.** The honest finding on reconnaissance was that
  most of the unifying had already happened: `AccessStore` has always been the
  only entitlement set, and there was no parallel store to fold in. What *had*
  forked was the cosmetic *rule*, copy-pasted into four view bodies as
  `option != .classic && !access.isUnlocked(.skins)` and its screen-mode twin —
  four places encoding which option is free, none reachable from a test, in a
  module Linux cannot compile. Persistence moved out into
  `LocalEntitlementStore` behind `EntitlementStoring` (same key, same encoding —
  a "cleaner" key would silently revoke every grant on real installs), and the
  cosmetic rule moved onto the options themselves via `CosmeticOption`.
  `Entitlement` gained `.expansion`, `.workshop` and `.easterEgg` for the two
  sub-batches to come.
- **F2 — one idle timer, folding in the marquee's.** The marquee kept its own
  clock (a `Task.sleep` on the chassis) and it was reset by exactly one thing in
  the entire app: tapping the marquee. Tapping a menu tile or scrolling a list
  counted as idleness. Survivable for a panel that changes a word; not
  survivable for a screensaver, which would have covered the screen of somebody
  actively reading. `IdleClock`/`IdleSchedule` in Core now hold the policy and
  the two thresholds together (10s toast, 15s screensaver), and `MarqueeStage`
  reads the 10 from `IdleSchedule` rather than restating it. Only the WELCOME!
  *beat* is still the banner's own sleep — it is a dwell, not inactivity, and
  `awaitsIdleTimer` is how the stage says which clock owns it.
- **The activity sink is a window `UIGestureRecognizer`, not a SwiftUI
  gesture.** 0.6.9's A1 removed the app-wide LCD `simultaneousGesture` for good
  reason, and adding one back would have put the stamp drag, the globe pan and
  the quiz taps back into negotiation. `IdleTouchWatcher` fails itself in
  `touchesBegan` with `cancelsTouchesInView = false`, so it never enters
  arbitration — a tap on the shoulder, not a gate. **`DeviceBackPlate.swift` is
  untouched by this batch.**
- **F3 — the version moved into `shared/`.** `AppVersion.fallback` was a Swift
  literal with forty lines of release notes above it. The number and a
  user-facing changelog now live in `shared/data/firmware.ts`, generate into
  `firmware.json`, and arrive through `FirmwareCatalog`; `fallback` reads it.
  **`AppVersion` is not a second source of truth** — it kept the half that was
  always its own, the resolution rule (a genuinely declared bundle version wins,
  xtool's stamped `1.0.0` wins nothing), and stopped restating the number. The
  long "why does this build carry this number" notes stay in `AppVersion.swift`
  as the engineering record; the changelog is what the device says about itself.
  The generator gates ordering, three-component shape, ASCII and headline
  length, and that gate was verified to fail on a deliberately mis-ordered list.
- **A1–A5.** Boot POST inside the LCD (a BIOS is something a screen does; over
  the chassis it reads as power loss), under two seconds and pinned there by a
  test. Demo mode assigns `path` directly rather than pushing — twelve stops per
  cycle would otherwise grow a stack and chirp the page sound at a device nobody
  is holding. Firmware history and the cheat console are two new System-panel
  rows under one DEVICE heading rather than three new headings. The screensaver
  bounces a `VinodexV` drawn from scratch — **no DVD trademark, asset or naming
  anywhere**, and position is a closed form in Core (`ScreensaverBounce`) so it
  cannot drift out of its box the way a per-frame simulation would.
- **Cheat codes grant real entitlements.** CELLARDOOR, PHOSPHOR, GRANDCRU and
  MAINFRAME, all four wired to something visible today — MAINFRAME's
  `verboseBoot` egg adds POST lines. A code that reports success and changes
  nothing is the one failure a cheat console cannot survive.

**Parked from 0.7.3c:**

- **Not deployed** — stopped at the clean build by instruction. Nothing in it is
  verified on glass. First things to look at: the cartridge silhouette at 46pt
  (the stepped shoulder is what makes it read as a cartridge rather than a badge,
  and it is the detail most likely to disappear at that size), the shelf under
  the four single-phosphor modes and the Retro group, and the workshop's eight
  part chips, which now render through `DexPickerTile` and should be pixel-identical
  to 0.7.3b.
- **The Brazil prose and its two regions are conservative but unaudited.** The
  claims worth a `sommbot` pass: "third-largest wine producer in South America",
  "around nine tenths of the crop in Rio Grande do Sul", the 1875 immigration date,
  and Serra Gaúcha classified `maritime` — it is humid subtropical, and `maritime`
  is the least wrong of the five classes rather than the right one. Vale dos
  Vinhedos is folded into Serra Gaúcha's `appellations` per the house rule rather
  than minted as its own region.
- **`find-missing-refs.mjs`'s country-gate arm is dead code**, and this batch is
  how it was noticed. It reads `COUNTRY_GATE` out of `entries.json`, which the
  generator deliberately never writes there, so `countries.length` prints 0 and
  the loop validating a gate's `keyRegions` and `notableGrapes` has never run.
  Brazil's were checked by hand. Cheap fix: read `countries.ts` directly.
- **The pack shelf has no route of its own**, so it cannot be linked to from
  anywhere but the settings grid. If packs ever want a tile on TOOLS or a marquee
  pin of their own, `SettingsSection.packs` is already pinnable via `QuickPinStore`
  — the wider element type parked from 0.7.1 is the thing that is missing.
- `ExpansionPack.symbol` is not policed by `ChromeTests.glyphsAreDistinct`; two
  cartridges wearing the same glyph would be a cosmetic smudge nobody catches.

**Parked from 0.7.3a and 0.7.3b:**

- 0.7.3a **was deployed and eyeballed**: the POST pacing, the demo dwells, the
  V's size, speed and colour cycle under the monochrome modes all pass, and so
  does 0.7.2's stamp drag including the top-left-corner falsifier. Both of the
  entries that stood here are closed.
- **0.7.3b was deployed and eyeballed** at the head of 0.7.3c: the derived colour
  ramps against the authored ones, the five grille patterns at real size, the
  schematic panel and the FONT row under monochrome all pass. Committed then.
- **The palette's derivation constants are authored by eye.** The mix amounts in
  `PartColor` (0.80/0.56 pale, 0.20/0.52 dark, 0.84 for the marquee's letters)
  are calibrated against CLASSIC's ramps by arithmetic, not by looking at them on
  a phone. Retuning one is one line and repaints all thirteen colours coherently,
  which is the whole point of deriving them.
- **`PartColor` and the font-readability rule are `VinodexUI`**, so neither is
  reachable from a Linux test — the thresholds in
  `PartColor.readsAsInk(onLightGround:)` are argued in a doc comment and gated by
  nothing. Moving the palette's *hex table* to Core would make the rule testable
  and is the obvious next tidy if the font axis grows.
- The demo loop's dwells and stop order are authored by eye, like the map
  coordinates. Worth tuning once seen running.
- ~~`.expansion` covers no entries yet~~ — closed by 0.7.3c, which gave it a pack
  catalog to read.
- `testing`, `v0.7.2-batch` and now `v0.7.3-batch` are all unpushed; `main` vs
  `origin/main` is still diverged and still not reconciled.

**0.7.2, the consolidation batch** (`vinodex-0.7.2-consolidation.md`). Shares
0.7.2 with the label reader rather than taking 0.7.3, because nothing had
shipped under the number — LABEL SCAN was still uncommitted when this spec
arrived, so the two land as one release instead of a tag superseded the same
day.

- **Section 0 was git.** `testing` now contains every batch branch. Most of the
  0.6.x chain already was an ancestor; the only genuinely dangling branch was
  `v0.6.4-batch` (also local `main`, tagged `v0.6.4.0`), whose three files —
  `DeviceChassis`, `DexTheme`, `RetroGlobeScreen` — are precisely the three that
  0.6.5 through 0.7.1 rewrote. All three conflicts resolved to `testing`, and
  the merge leaves its tree byte-identical: 0.6.4's globe fix is already in the
  tree under a later name (`colorized` for `tinted`, carrying the same finding
  about `SCNMaterial.multiply`), and its island lamps predate the bezel the
  lamps now live on.
- **A2, and why two batches missed it.** The stamp drag never fired because no
  touch reached it. 0.7.0's E2 moved `.frame`/`.offset` up the chain and left
  `.contentShape(Rectangle())` outside the offset; `.offset` does not change
  layout, so the contentShape — which *replaces* a subtree's hit region rather
  than describing it — pinned all six stamps to one box in the plate's top-left
  corner. Taps were dead as well, which nobody noticed because the drag was
  what was being tested. 0.7.1's D3 then shortened the hold threshold, which
  could not have helped. **A threshold change that does nothing is evidence the
  event never arrived.** The gesture is also `highPriorityGesture` now: it sat
  under an `onTapGesture`, and `TapGesture` has no maximum duration, so a
  deliberate press-and-release was a tap.
- **The marquee stopped being a nameplate.** A9 makes the two status lamps the
  TOOLS and CUSTOMIZE buttons (which is why `bandPillHeight` is 20 and why A4's
  bead had to come off — the glyph goes where the highlight was), A7 puts
  pinned sections in its top corners, A6 makes the tap a toggle that re-titles
  the panel PINS, A3 gives MENU a glyph beside the word, and A8 brings the
  0.6.9 language toasts back — now that the script has somewhere for them to
  belong, one per idle period rather than a carousel.
- **A1** gives Africa ochre and Oceania eucalypt green. They were the pink pair
  0.7.1's A3 left behind: both sat at hue 0° with identical G and B, separated
  only by lightness. Closest pair went 40 → 151.

**Parked from 0.7.2 (consolidation):**

- **Not deployed, and could not be.** `xtool dev run` fails at provisioning with
  a 409 from the Apple Developer API — "no current iOS devices on this team
  matching the provided device IDs". The phone's UDID is not registered on the
  signing team; that is an account problem, not a build one. **A2 and the whole
  marquee rework are therefore unverified on glass.** A2's fix is a hit-testing
  correction that no Linux gate can exercise, so it is the first thing to check
  on the next successful install.
- North America `#722F37` and Europe `#9B2335` are now the closest marker pair
  at 42.8 — tighter than the pair A1 just fixed was. Out of scope here because
  the spec named Africa and Oceania, but it is the same defect one notch
  quieter and the obvious A1 follow-up.
- The A4 bead removal is scoped to the two marquee pills. The island trio and
  the vent lamps keep their specular dots, on the reading that A4 named the
  marquee lights. If the dots were meant to go everywhere, it is one default
  on `RecessedLamp.bead`.
- The corner pin buttons are 26pt, under the 44pt target guidance. Deliberate —
  see `DexMetrics.marqueePinButton` — but worth an eye on device.

**0.7.2, the label reader** (`vinodex-label-reader_1.md`, "Feature Build Spec
v7.1"). The first batch since 0.7.0 to add a screen rather than rework one, and
the first feature that takes an input from outside the app.

- **The split is the point.** `LabelReading` / `LabelTextScan` /
  `LabelRecognitionService` are Foundation-only in `VinodexCore` and covered by
  `LabelReaderTests` (38 tests), so normalisation, fuzzy matching, confidence
  scoring and the inference walk are gated by the Linux CI. `OCRService`,
  `VisionOCRProvider`, `CameraCapture` and `CameraPermission` are in
  `VinodexUI`, reachable only through the `LabelRecognitionProvider` protocol —
  which is also the swap point for a future `OpenAIProvider` if the no-paid-API
  constraint is ever lifted.
- **There is no Producer entity and there never was.** The spec's heaviest
  weight (50) is for a field the catalog cannot confirm, so producer matching is
  text-only — an estate-keyword pass then the most prominent unclaimed line —
  and the weight degrades to 15 (`LabelConfidence.producerTextOnly`). A producer
  guess alone can never carry a reading over the confidence floor.
- **§8 is a walk, not a table.** `BAROLO` → the region whose `appellations` list
  it (Piedmont) → `details.origin` (Italy) → `notableGrapes` (Nebbiolo) →
  `grapeStyle` (Full-Body Red). Nothing about that is written down in the
  feature; both spec examples (Barolo and Vouvray) are pinned as tests.
- **`isInferred`** was added mid-batch: a walked field is *shown* and scores
  *nothing*, so Barolo's 35 points do not silently become 80 for consulting the
  catalog about its own cross-references.
- **`xtool.yml` gained `infoPath`.** Both that file's comment and KNOWN-ISSUES.md
  asserted no Info.plist passthrough existed; false of xtool 1.17.0. Corrected
  in both places, and `CFBundleShortVersionString` turns out to be settable too
  (M6/M37 unblocked — not taken here).

**Parked from 0.7.2:**

- Not deployed. The last attempt failed provisioning with a 409 from the Apple
  Developer API ("no current iOS devices on this team matching the provided
  device IDs") — an account/device-registration problem, not a build one. The
  label reader has therefore **never been seen on a phone**, and it is the one
  feature in the app whose core input (the camera) the simulator cannot supply.
- The vintage floor is 1900 and the ceiling is next year. Sparkling
  disgorgement dates and multi-vintage labels are unhandled by design.
- Fuzzy suggestions in the no-match state are edit-distance only. Ranking them
  by OCR confidence as well is the obvious next refinement.
- `AppVersion.fallback` could now be stamped into the bundle via `infoPath`
  rather than living only in the constant. Deliberately not done: two places to
  keep in agreement, one source of truth.

**0.7.1, by section** (all six landed; the spec's suggested A+C+E / B / D split
was used as the *sequencing* rather than as a scope cut, each phase gated
before the next started):

- **A** — MASTER SEARCH rename plus the retirement of the dead `.masterSearch`
  route it collided with; one magnifier everywhere (`DexGlyph.search`); South
  America off North America's colour (`shared/data/continents.ts` → sync →
  generate → zero dangling); header lamps 17→22pt; and `RecessedLamp`, one
  modifier now seating all eight lamps on the device.
- **B** — `MarqueeScript` (Core, tested) drives WELCOME! → MENU → CHEERS!;
  `PixelDissolve` gives the transition its pixels; the panel is a button on
  every screen opening `MarqueeDrawer`, which carries a two-slot pin bar
  (`QuickPinStore`, Core, tested).
- **C** — VINTAGE group → RETRO, WINE.OS → Emulator, GRÜNERBOY → Retro,
  HALLOWEEN → HALLOWINE (label only), and `LcdMode.chrome(face:shadow:)` so
  Emulator modes repaint the app's coloured tiles in their own ramp.
- **D** — the tried shelf now dates its entries (`BookmarkStore.triedDaysKey`,
  new — nothing recorded a date before this), which is what the activity graph
  is built on; `PassportProgress` diffs earned badges so an unlock has a
  moment; `PassportTier` is the four-rung ladder from VINODEX MASTER.
- **E** — `DexGlyph.challenge` (`target`) replaces the flame everywhere;
  IDENTIFY → BLIND TASTING, and its glyph left the magnifier family with it.
- **F** — `DexMotion`, four named curves; seventeen longhand animation call
  sites swept onto them.

**Parked from 0.7.1** (candidates for the next batch):

- The drawer opens from the marquee but nothing else on the chassis feeds
  `MarqueeScript.noteActivity()`. Today the idle timer only resets on a
  navigation or a marquee tap, which is correct but conservative — a tap
  anywhere on the LCD arguably counts as activity.
- Africa `#C48B8B` and Oceania `#D4A5A5` are as close to each other as North
  and South America were before A3. Same fix, not asked for, worth raising.
- The 0.7.1 pin bar holds `SettingsSection`s only. Pinning a *tool* or an entry
  is the obvious next ask and `QuickPinStore` would need a wider element type.
- `LcdMode.chrome` blends toward `controlAccent`; the Retro group is
  deliberately excluded because the chassis already greys and tints the whole
  LCD for it. If those modes ever lose the grayscale pass, they need the blend.

## A. Audit debt — suggested next sittings (from AUDIT.md's 52 open)

Ordered by risk-times-cheapness; IDs are AUDIT.md's, one row ≈ one sitting.

1. **Robustness spine**: H2 (element-wise entries.json decode + DexAlert),
   M2 (explicit DATA LOAD ERROR state), M3's Swift half (schemaVersion
   asserted at load). One sitting, closes the "one bad regen from critical"
   risk the audit flags at the top.
2. **Perf quick wins**: M7 (CountryScreen query reuse), L14/L15 (repeat
   scans), M8/M9 (marquee measure cache + TextScale seam), L16 (font probe).
   Mechanical, testable by inspection + device feel.
3. **A11y pass**: H11 (Dynamic Type strategy), M18 (reduce-motion), M20
   (globe VoiceOver fallback), M21 (flip discoverability). One themed PR.
4. **Icon crispness**: H6 (@2x/@3x selection in IconLoader) + L28
   (`interpolation(.none)` on DexIcon) — pairs naturally with the 0.6.2
   outline work and finishes the "icons look soft" complaint at the root.
5. **Release hygiene**: M36 (font/icon licenses + LICENSE file), M37's
   CHANGELOG.md (seed it from the tag annotations), L20 (AppIcon recompress),
   L22 (pin xtool version in the release checklist).
6. **Architecture** (when a quiet stretch exists): M30 split of
   EntryDetailScreen/DeviceChassis — both grew again in 0.6.x; do it before
   the next chassis feature, not after. M27/M29 ride along.

## B. File & folder cleanup

- **vinodex-ios repo**
  - [ ] Prune retired grape sprites: with the leaf now code-driven, only the
    `-rare` bases (+ blends' rare variants, `green-common` unused?) are
    referenced by `grapeArt`. The `-common`/`-noble` artist variants are
    dormant payload — either delete from Resources (masters stay in
    `art/icons/grapes`) or record why they stay. ~200KB.
  - [ ] `art/` and `pixelflags/` are untracked working dirs at repo root —
    decide: commit them (they are the art masters the import scripts need;
    CI can't run imports without them) or move under `HGapps\` outside the
    repo and document. Recommendation: commit `art/icons` (small, load-bearing),
    keep `pixelflags/` as-is (already partially shipped via Resources/Flags).
  - [ ] `.vscode/` at repo root is untracked — commit if the settings are the
    Swift/WSL wiring (memory says workspace settings matter), else ignore it.
  - [ ] Delete `Sources/VinodexUI/Resources/Icons` orphans again after the
    next `npm run icons` (the prune step exists; just re-run pipeline).
  - [ ] KNOWN-ISSUES.md: add a short section for the 0.6.x additions —
    find-missing-refs.mjs as the data gate, the leaf-recolor loader, and the
    "art masters vs shipped Resources" relationship.
- **HGapps root**
  - [ ] Root .md census after this pass: README-layout.md (live),
    V1-ROADMAP.md (live), PLAN.md (this file), SHIPPING-REVIEW.md +
    PORT-TO-WEB.md (archived — move to an `archive/` folder or delete once
    the method notes have been absorbed into the roadmap).
  - [ ] `HGapps` root is not a git repo — the canonical `shared/` master and
    these planning docs are unversioned. Cheap fix: `git init` at root with a
    .gitignore covering the two repos and `xtool/` — the master data deserves
    history. (Decide before the next big data batch.)
  - [ ] Downloads spec files (`vinodex-0.5.9.md`, `vinodex-0.6.2.md`,
    `vinodex-missing-data*.md`) — move into `HGapps\specs\` so batches and
    their specs live together and survive Downloads cleanup.
- **vinodex-web repo**
  - [ ] Commit the synced `shared/` (done this pass if typecheck was green —
    see commit log) and the new `shared/newicons/` art drop.
  - [ ] The SHIPPING-REVIEW hardening list is still open: CI workflow
    (install/typecheck/build), master branch protection, README truth pass
    (pivot sentence, shared/ ownership table).

## C. Product next (from V1-ROADMAP, direction updated)

1. **Web catch-up batch** — the roadmap's "web first" rule inverted while iOS
   sprinted; the highest-leverage next feature work is porting iOS 0.5–0.6
   wins to web with the Swift files as spec: chip filter tool (M1's facets),
   Wine Exam + Daily Challenge (M3), shelves/ratings (M2). Run as 2–3 dexbot
   batches in vinodex-web, one feature each, HGapps\archive\PORT-TO-WEB.md's guardrails
   (no new deps, no storage APIs beyond the agreed schema, typecheck+build
   as gates).
2. **M0 ops** — hosting decision, web CI + branch protection, privacy/support
   pages. Small, unblocks analytics and the feedback form.
3. **M4 editorial** — sources/reviewStatus fields in canonical shared (the
   one v1.0 schema change), then the long-lead content pass. Start early.
4. **iOS niceties parked from batches**: mapPosition fine-tuning by eye
   (authored coordinates are approximations), style portraits for the three
   derived stems when the artist next draws, Mexico outline art
   (`outline-mexico`) so Valle de Guadalupe gets dots.

## D. Standing conventions (so future batches stay cheap)

- Data changes: master `shared/` → sync → generate → `find-missing-refs.mjs`
  zero dangling → deliberate test-pin updates → three verification gates →
  deploy. (Encoded in dexbot.)
- Releases: one `feat(ios): vX.Y ...` commit per batch through the protected
  main, annotated tag = release notes. Bump `AppVersion.fallback`; append the
  outgoing total to `waveMilestones` when entry counts move.
- Data *accuracy* is the `sommbot` agent's beat (`.claude/agents/sommbot.md`):
  it audits `shared/` against regulator and ampelography sources, applies
  in-place corrections, and keeps `data-review/FINDINGS.md` (verification
  ledger) + `data-review/CANDIDATES.md` (ranked staging backlog). It hands
  entry additions and enum changes to dexbot rather than making them.
- Every new enum value (rarity, climate, system) touches: shared types,
  constants mapping, chipColors, generator probe+coverage lists,
  EntryDisplay names, exhaustive Swift switches (UI ones too), and test pins.
