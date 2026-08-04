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
| 0.7.5 | v0.7.5 spec, sections A + B | **THE SHOP.** ACCESS becomes SHOP and the expansion packs move into it out of CUSTOMIZE — **superseding 0.7.3c's placement**. The whole storefront is redrawn in 0.7.3c's cartridge tile and every cartridge opens to a splash. `PurchaseProviding` lands beside F1's `EntitlementStoring`; **no StoreKit, no payment path**. Plus six A-list fixes: bigger marquee lamps with darker glyphs, a squared orb, a monochrome-only refresh flash, PÉT-NAT → FIBERGLASS, the real wordmark in the screensaver, and a full-screen POST. | 438, untouched | 438 tests, clean build, **not deployed** |
| 0.7.5 | v0.7.5 spec, section D | **THE WINE EXAM.** `sommbot` authored the bank (`shared/data/exam.ts`, 407 questions, 16 subjects, 7 formats, an explanation on every one); `dexbot` built everything that consumes it — the `exam.json` emit and its gate, the Swift decode, the shuffling engine, balanced paper assembly, scoring, the statistics store, the seven answering UIs and the explanation reveal. Plus the two pre-existing TS errors and the missing-outline-art gate. | 438, untouched; `exam.json` is a new generated file | 484 tests, clean build, **not deployed** |
| 0.7.5 | v0.7.5 spec, section E | **INTERACTIVE GRAPE LINEAGE.** `sommbot` authored the pedigree off VIVC passports — 57 grapes carrying a lineage, 68 of 171 in a relationship after the reverse pass. `dexbot` took the pipeline (`constants.ts` pass-through, `WineEntry` Codable, a `find-missing-refs` arm), the reverse index that derives offspring / mutations / half-siblings, and the tree screen behind a new `Entitlement.lineage`. Plus the approved `bodyFromText` fix: 16 grapes stop drawing a full-body bar they never earned. | 438, untouched; `lineage` is a new optional field on grape entries | 452 tests, clean build, **not deployed** |
| 0.7.5 | `audit-review/FINDINGS.md` A026–A028 | **THE ASSET GATE.** Three silent-missing-asset bugs in three batches and only the third left a gate behind, so this one is the general case: `assertAssetsExist` in the generator checks that every emitted `icon` / `art:` / portrait-stem / flag id resolves to a file on disk — 337 ids a run. It found a **fourth on its first run**: `icons.json` has named a Brazil flag since 0.7.3c and `Flags/brazil.png` was never copied, so every Brazilian row flew a blank swatch. Plus the pipeline wiring — `import-logo-art.py` was in no roster at all (A026), `import-stamp-art.py` in the rasteriser but not the verifier (A027), and `ArtPipelineRosterTests` now holds the four rosters equal so a seventh importer cannot land in three of them. | 438, untouched; `Flags/brazil.png` added | 489 tests, clean build, `npm run icons` + `icons:verify` green, **not deployed**; no firmware bump — nothing user-visible changed |

**0.7.5, The Wine Exam** (v0.7.5 spec, section D). The second split batch:
`sommbot` authored the 407-question bank, `dexbot` built every consumer of it.

- **D1's naming collision resolved to *absorb*, and the code decided it rather
  than taste.** The question was whether the Wine Exam replaces, absorbs or sits
  beside the existing `TastingQuiz` ladder. Four pieces of shipped evidence, all
  found by reading before writing: `DexRoute.wsetQuiz.title` has been the string
  `"WINE EXAM"` since 0.5.9; that screen's picker is headed CHOOSE YOUR EXAM and
  its way out says BACK TO EXAMS; and `StampCatalog`'s SOMMELIER stamp — a
  *shipped, earned* back-plate stamp — describes itself as "The Wine Exam's top
  tier, unlocked". There was never a second feature to sit beside. D1 asks to
  expand the Wine Exam, so `.wsetQuiz` is the same door with a different room
  behind it.
- **Two tier vocabularies, one ladder, and the device's words win.** The bank is
  authored `beginner`/`intermediate`/`advanced`; the device's ladder is
  `QuizTier`'s NOVICE/ENTHUSIAST/SOMMELIER. `ExamTier.ladder` maps them 1:1 and
  in order (`examTierMatchesLadder` pins the bijection both ways). The device's
  words win for two reasons that are not preference: `QuizTier`'s raw values are
  **persisted** in `quizTierUnlocked`/`quizTiersCompleted`, so a user's SOMMELIER
  unlock is a string on somebody's disk; and they are printed on a stamp that has
  already shipped. The bank's words never reach the screen. Everything the old
  practice paper had — the ladder, the locks, the completion stars, the passport
  badge — carries over untouched, because none of it was ever about where the
  questions came from.
- **`TastingQuiz` was not retired, and the split is deliberate rather than
  leftover.** It keeps the **daily challenge**, and it should: an authored bank
  is finite (407 questions at five a day is under three months before repeats)
  and a daily that must be the same paper for everyone, every day, forever is
  exactly what a generator answers and a bank cannot. The generated paper also
  cannot contradict an entry. What *did* go is `TastingQuizScreen`'s `.practice`
  mode and the `QuizMode` enum with it — a two-case enum with one case left is a
  parameter every call site passes and none can vary.
- **The shuffle is the whole reason the engine exists, and it is falsifiable.**
  Authored option order *is* answer order, matching pairs are authored paired and
  ordering items authored in sequence — the only sane way to author them and
  completely unusable as a presentation. `ExamPrompt` is the presentation layer:
  a seeded permutation stored alongside the question, so grading is a lookup
  rather than a second guess at what the user saw. `shufflingMovesTheAnswer` is
  the falsifier — it measures the share of questions whose answer lands in slot 0
  across every single-answer question in the bank and fails at 100% (never
  shuffled) *and* at 0% (always moved off zero, which would make slot 0 never
  correct — a bigger tell than the one it fixes).
- **Ordering is the one format where the identity permutation is a bug.** A
  three-item ordering shuffles to its authored order one run in six, and an
  ordering question presented in the authored order is presented *already
  solved*. `ExamPrompt` swaps the first two when the permutation comes back as
  the identity, and `orderingIsNeverPreSolved` checks all 18 ordering questions
  against 200 seeds each rather than sampling — the identity is precisely the
  case a sampled test misses. Options are deliberately **not** corrected this
  way, for the reason above.
- **A paper that runs dry says so.** The brief's line — a generator that silently
  repeats when a cell runs dry is worse than one that says it cannot — is
  `ExamAssemblyFailure`, returned rather than papered over. `EXAM_MIN_CELL_COUNT`
  (6), not the 407 total, is the real bound: `balancedCapacity` is the thinnest
  cell times sixteen categories, and past it a paper leans on the fat categories
  rather than failing. Both behaviours are pinned —
  `fullLengthPaperIsDistinct` asserts an exactly-even split at the ceiling and
  `beyondCeilingStillDistinct` asserts no repeat when the *whole tier* is drawn.
- **Balance is a seed-rotated round robin, which buys three things at once.** Ten
  questions over sixteen categories means ten *different* subjects per paper
  rather than three about grapes; the rotation moves *which* ten with the seed,
  so consecutive papers examine different ground rather than the same ten
  subjects with different questions; and an exhausted category is skipped, never
  re-drawn, which is what makes "no question twice" structural rather than
  checked afterwards.
- **`ExamRun` stores the seed, not the paper.** `ExamPaper.assemble` is pure, so
  a run round-trips through `ScreenStateStore` as one integer and re-derives ten
  questions with their options, explanations and shuffles exactly. `QuizSession`'s
  arrangement, applied to a much larger payload — the alternative was a few
  kilobytes of question text re-encoded on every tap.
- **All-or-nothing on `selectAll`, and the reveal is where the nuance goes.**
  Partial credit was considered and rejected: `correct` is an integer out of
  `length` on a results card and against a pass mark, and a paper where one
  question is worth two thirds makes both numbers a lie. The reveal still marks
  each option individually, so nothing is hidden — the *score* just does not
  claim a precision it has no scale for.
- **Matching and ordering are tap-only, and 0.7.2's A2 is why.** They are the two
  formats a desktop would do with drag and drop. Adding a third drag gesture to a
  2.5-inch LCD that already arbitrates the stamp drag and the globe pan is how
  0.7.2 spent two batches on a control that never received a touch — and
  `VinodexUI` is invisible to the Linux tests, so nothing would have caught it.
  Matching is *arm a left row, tap its right*; ordering is *tap in order, tap
  again to unset*. Neither negotiates with anything.
- **D7 is the reveal, not a results-screen appendix.** Verdict, then the
  explanation, then the source where the claim needed one, then the question's
  `entryRefs` as the same `EntryTileView`s they are everywhere else — which
  **generalises the old quiz's best idea** rather than losing it. The generated
  quiz's reveal worked because every option was a real entry with a page behind
  it; an authored bank cannot promise that, but 316 of 407 questions carry
  catalog ids, so a question you got wrong still ends one tap from the page that
  would have told you. Capped at three tiles: a reveal is a moment, not a reading
  list.
- **D6 reuses three stores and forks none.** `QuizProgress` keeps the ladder
  (`ExamRecordStore.record` calls straight through to `recordPass`), `StreakStore`
  keeps the *calendar* streak, and the new store holds only what neither had: a
  bounded history of results. Every statistic is **derived** from it —
  accuracy, full marks, best-by-tier, per-category — rather than incremented
  beside it, because a counter and a list are two facts that can disagree and it
  is always the counter that is wrong. `passStreak` is deliberately not folded
  into `StreakStore`: that one counts *days* at one sitting per day, and you can
  sit four papers in an evening.
- **The pass streak saturates at 100 and the test says so rather than being
  written around it.** It is derived from a history bounded at `historyLimit`, so
  120 consecutive passes read as 100. The test was written expecting 120, failed,
  and the *finding* was kept: the alternative is a stored counter beside a stored
  list, which is the thing the store exists to avoid. Pinned at
  `historyLimit` with the reasoning, so the saturation is a decision.
- **The statistics screen's useful half is the weakest subject, and it has a
  sample floor.** One wrong answer in one FORTIFIED question is 0% and would sit
  atop a weakness list forever, ahead of a subject genuinely being failed half
  the time. `weakest(minimumAsked: 3)` is the floor, and
  `weakestNeedsASample` pins that removing it changes the answer.
- **`sommbot`'s handoff item 1 was half wrong, and checking it saved an edit.**
  It asked for `Package.swift` resource wiring alongside the `exam.json` emit.
  `VinodexCore` declares `.copy("Resources")` — the whole directory, not a file
  list — so a new `Resources/*.json` needs no Package.swift change at all. The
  emit was real and is done; the wiring never existed to do.
- **The exam arm of `find-missing-refs.mjs` is the lineage arm's shape and was
  proved the same way.** Like lineage it does **not** go through the name index,
  for the reason sommbot gives: `entryRefs` are ids because the grape-name index
  over-lumps, so a *name* here is a mis-authored ref rather than a resolvable one
  — and it is tested against the name index precisely so it can be reported as
  "write this as an id". Three failure modes, all verified against injected data
  (bad id, a name where an id belongs, a bad `entryIcon` image key), all three
  named correctly, exit 1. **774 refs to 205 distinct entries, 47% of the
  catalog, printed rather than asserted** — editorial reach is not correctness,
  but an unmeasured number is one that quietly goes to zero.
- **The split of who checks what is by ownership.** `find-missing-refs` walks
  references *into the catalog*; the generator's new `assertExam` walks
  everything the generator itself owns — the closed vocabularies, per-format
  payload invariants (empty and all-correct `selectAll` answers, a repeated
  matching *right* column, out-of-range indices), the tier counts against
  `EXAM_AUTHORED_TIER_COUNTS`, every cell against `EXAM_MIN_CELL_COUNT`, and the
  two asset tables (`FLAVOR_ART`, `COUNTRY_SHAPE_ICONS`) that exist nowhere else.
  ASCII on every shipped string, on `assertFirmware`'s precedent: the question
  card is Press Start 2P over VT323 and a pasted accented place name renders as a
  blank box.
- **The missing outline art is a real art job, and the gate is the deliverable.**
  Verified: `countryShapeIcons` has 28 keys against 34 flag gradients, and three
  live regions fall through — R117 Serra Gaúcha, R118 Campanha Gaúcha (Brazil)
  and R098 Valle de Guadalupe (Mexico). The brief's diagnosis was right about
  `CountryOutlineMap.swift:29` (its `if let` has **no `else`** — the country page
  draws nothing) and slightly off about `EntryVisual.swift:186`, which has a
  `?? db.icons.climateIcon(...)` fallback and degrades to a climate glyph rather
  than to nothing. **Drawing them was declined**: the 28 existing outlines are
  hand-drawn pixel art in `art/icons/countries/` at sizes from 50x185 to 232x140,
  and a silhouette synthesised by a script would be visibly not of that set. So
  **two gates instead**, in both places that can hold one: the generator's
  `assertOutlineCoverage` hard-fails on any place with regions and no outline
  unless it is named in `OUTLINE_BACKLOG` (and *also* fails if a backlog entry
  stops being missing, so the list cannot rot into an excuse), and
  `CoverageTests.regionsHaveOutlineArt` pins the set as **exactly** `["Brazil",
  "Mexico"]` — failing in both directions, the pleasant one being "somebody drew
  it, delete this line". This is the third silent-missing-asset bug in three
  batches, after `icon: "fruit"` (0.7.4) and the two logo layers (0.7.5, A5), and
  it is the first of the three to leave a gate behind.
- **The two pre-existing TS errors were `noUncheckedIndexedAccess` and are fixed
  at the cause.** `FIRMWARE_RELEASES[i - 1]` was read twice under an `i > 0`
  guard, which does not narrow an index expression. Bound once into a local,
  behaviour identical. `npx tsc -p tsconfig.json` is clean for the first time in
  the repo's history.
- **`exam.json` is the eighth generated file and it carries its own
  vocabularies.** Labels, tier order and `minCellCount` ship *with* the bank
  rather than being restated as Swift literals, on the same reasoning F3 used for
  the firmware version travelling with its changelog: a literal here would
  silently disagree with the bank the first time somebody added questions.
  `ExamCatalog` decodes element-wise like `WineDatabase`, so a malformed question
  costs one question — which makes it silent by construction, which is why
  `DiagnosticsReport` now prints the bank's count and its decode errors.
- The FIRMWARE headline moved from THE SHOP to **THE WINE EXAM**. The headline
  names the release on the panel, and a release whose largest item is a
  407-question exam was describing its second-largest feature.

**Parked from 0.7.5 (D):**

- **Brazil and Mexico still have no outline art**, and four more countries (UK,
  Slovenia, Bulgaria, Lebanon) have flag gradients and no outline — *latent*,
  because no region names them, so the new gate correctly says nothing about
  them. Both gates are set to fail the moment either changes. This is the art
  backlog's item, not a data one.
- **Not deployed** — stopped at the clean build by instruction, and this is the
  section with the most that only glass can settle. Worth an eye, in order: the
  **matching** card at four pairs (the right column is a hand-rolled flow layout,
  `DexFlowRow`, and "Grapes dried after picking" beside "Chardonnay" is the case
  it was written for); the **ordering** card at seven items, which is the longest
  authored and the one most likely to need scrolling mid-answer; the three
  **aroma glyphs** at 62pt on a real display; the **country outlines** at 128pt,
  which have never been drawn at that size before; and the reveal card when a
  question carries three entry tiles *and* a long explanation.
- **`selectAll` has no "how many" hint**, deliberately — the count is part of the
  question. Worth watching whether that reads as under-specified on device.
- **The `entryIcon` image kind is implemented and unexercised.** All 11
  `imageIdentification` questions authored are `countryOutline`; the `entryIcon`
  arm is covered by the refs gate's negative test but by no live data.
- **No new passport badge.** D6 asks for achievement unlocks and the exam already
  has one — SOMMELIER, which `Passport.compute` earns from
  `QuizProgress.highestUnlocked` and which now means the authored top paper. A
  seventh badge (full marks, say) is cheap — `Passport.Badge` plus a
  `BackPlateStamp`, 1:1 and pinned by `StampCatalogTests` — but `PassportProgress.seed`
  runs **once ever**, so a badge shipped to existing users fires one popup for
  something they already qualified for. Worth doing deliberately in its own
  sitting rather than as the tail of this one.

**0.7.5, Interactive Grape Lineage** (v0.7.5 spec, section E; `sommbot` ran D in
parallel and owns `shared/data/exam.ts`).

- **The tree is not offered on 103 of the 171 grapes, and that is the design
  rather than a gap in it.** Coverage is 40% and will stay short of 100% —
  Zinfandel's parents are genuinely unresolved and Rkatsiteli's marker line names
  a reconstructed genotype rather than a variety. The three options were an
  always-present section that opens an empty tree (three grapes in five, and the
  fastest way to teach somebody a button does nothing), a greyed NO LINEAGE DATA
  row (a paywall-shaped reminder of an absence on every second grape), and
  drawing nothing. `EntryDetailScreen.lineageSection` draws nothing, gated on
  `WineDatabase.lineage.hasLineage`, and the SHOP listing is where the feature is
  discoverable independently of which grape you happen to have open. The button
  that *is* drawn carries its own counts — "2 PARENTS · 6 OFFSPRING · 3
  MUTATIONS" — so a thin tree is honest about being thin before you open it.
- **Off-catalog ancestors are terminal, not broken.** Gouais Blanc is the mother
  of ten grapes here and will never be an entry; half the pedigree would go with
  it if named ancestors were dropped. `LineageTile` draws them on the *well* with
  a dashed border and no art — a different kind of thing, plainly not a door —
  rather than through `LinkedRow`'s greyed-out treatment, which in this app means
  "a cross-link that failed to resolve" and would say the data is broken. They
  still do one job in the graph: they are **sibling keys**, which is the only
  reason Chardonnay and Riesling know they are half-siblings at all.
- **Contested edges are drawn as contested from both ends.** The reverse pass
  carries `contested` through, so Palomino's offspring row for Listán Negro says
  what Listán Negro's parents row says — without that, the app declines to assert
  a direction from one side and quietly asserts it from the other. A dashed
  connector and a `?` badge mark it; the authored sentence lands in an ON THE
  RECORD footnote block, de-duplicated by the index. A question mark rather than
  a warning triangle: nothing here is wrong, two sources disagree.
- **`related` is reversed even though nothing in today's data reverses.** Both
  authored `related` refs are Sangiovese's and both are off-catalog. It is built
  anyway because "first-degree relative of undetermined direction" is symmetric
  by definition, and the day one names a catalog grape, that grape's tree would
  otherwise be missing an edge its partner draws. Exercised by a fixture
  (`relatedIsSymmetric`) rather than left as untested scaffolding.
- **The tree is a column, not a canvas.** The LCD is about 2.5 inches wide;
  pan-and-zoom on it would be a worse list. What a graph gives that a list cannot
  is *direction*, so ancestors sit above the subject with rails running down into
  it, descendants below with rails running out, and everything sideways is a
  labelled section underneath. Half-siblings are **grouped by the relative they
  came through** — Chardonnay's eleven are nine Gouais Blanc children and two
  Pinot Noir ones, and a flat list of eleven names says none of that. The rails
  are a single `Canvas` path in `lcd.accent`, so they come out as ink in VINTAGE
  and as phosphor in the four single-colour modes.
- **A new `Entitlement.lineage`, not a fold into `.pro`.** The shop can only sell
  what the entitlement set can name, and this behaves exactly as `.workshop`
  does: it gates a door, `covers(_:)` answers `false` because it is not a slice of
  the catalog, and `.pro` supersedes it. It sells through B2's
  `PurchaseProviding` / `AccessStore.purchase` like everything else — no second
  store — and continues to the tree on success (0.7.3's C1), which is the first
  time `EntryDetailScreen` has raised an `UpgradePrompt` of its own; every *entry*
  paywall is still handled a level up in `RootView.open(_:)`.
- **`bodyFromText` had `levelFromText`'s exact defect and it cost a rendered
  value.** `t.includes('full')` sat above the `medium-full` branch and every test
  in the function is a substring test, so `'Medium-Full'.includes('full')` was
  true and that branch had never once executed: **16 grapes authored
  `"Medium-Full"` drew the same 5/5 bar as the 34 authored `"Full"`**. Chardonnay
  and Merlot read as full-bodied as Cabernet Sauvignon. They are 4/5 now, on iOS
  and on web, which read the same `GRAPE_CARDS`. `light-medium` was dead the same
  way and is corrected for the function's sake only — those 22 grapes round to 3
  either way, because `Math.round(2.5) === 3` is what `medium` already returned.
  Nothing caught this because Cabernet Sauvignon is the only grape whose
  characteristics are pinned anywhere and it is genuinely `"Full"`;
  `CoverageTests.bodyBarsAreDistinct` now pins the whole distribution, because
  what broke was a *branch* and a branch is only observable across the set.
- **The lineage gate is the only arm of `find-missing-refs.mjs` that does not go
  through the name index**, deliberately: in-catalog links are ids, so a typo'd id
  is a hard failure and a *name* is never checked against the grape list — a hit
  would mean the ref was mis-authored, not resolved. Four failure modes are
  caught (bad id, both keys, neither key, and a name matching a catalog grape's
  primary name), all four verified against injected data. The off-catalog count
  is **printed rather than asserted**: 47 refs to 36 distinct ancestors is
  backlog, not breakage, and silence there would read as "none", which is the
  exact failure the dead COUNTRY_GATE arm taught in 0.7.4.

**Parked from 0.7.5 (E):**

- **`grapeBodyClass` still disagrees with the body bar on some grapes, and it is
  a different derivation.** `getGrapeBodyClass` in `constants.ts` reads
  `legacy.wineType` *first* — so Chardonnay, whose style label is "Full-Body
  White" and whose authored body is `"Medium-Full"`, resolves to the class `Full`
  while its bar now reads 4/5. The function's own ordering is correct (it tests
  `medium full` before `full`); what is arguable is that a *style label* outranks
  an authored body at all. Out of scope here — only `bodyFromText` was approved —
  and worth a ruling of its own, because fixing it moves the body **chip** on an
  unmeasured number of grapes.
- **`Mammolo` is both an authored off-catalog ancestor of Verdicchio and a
  synonym of G168 Sciaccarellu.** VIVC folds Sciaccarellu and Mammolo into one
  record; whether Verdicchio's parent is that entry is a factual question for
  `data-review/FINDINGS.md`. The gate prints it as an authored, non-fault
  collision rather than ruling on it, and the index does **not** resolve it —
  in-catalog links are ids, and a name that resolves through synonyms is exactly
  the wiring the id rule exists to prevent.
- **Not deployed** — stopped at the clean build by instruction. Worth an eye: the
  fan connectors at their widest (Pinot Noir, nine descendants, which wrap), the
  dashed external tiles against the well in the light modes, and the `?` badge at
  its 13pt size on a real display.

**0.7.5, The Shop** (v0.7.5 spec, sections A and B; C, D and E are separate and
were deliberately not speculated about).

- **B supersedes 0.7.3c's placement, and the reason 0.7.3c gave was never about
  the packs.** That batch put the shelf behind a door inside CUSTOMIZE because
  the settings grid is a fixed three-by-two sized to fill the LCD, so a seventh
  tile would have been an orphan on a fourth row — a constraint about the *grid*,
  which the packs then paid for. B1 dissolves it without touching the grid at
  all: packs are paid content and ACCESS was already the paid-content tile, so
  the shelf moves into a tile that exists. `SettingsSection.packs` retires with
  the door — it was minted only to buy a marquee title, a glyph, Back behaviour
  and `ChromeTests` coverage, all of which SHOP now provides — which takes the
  route count 32 → 31 and the marquee's chip row back to four, the number its own
  comment has claimed since 0.7.1 and which stopped being true when PACKS landed.
  CUSTOMIZE is a scrolling column of sections, so losing one shortens it and
  moves nothing.
- **"Bundles" was already gone, and the word that had to move was ACCESS.**
  B1 asks the packs to replace BUNDLES in the access area; 0.7.3c had already
  renamed that heading to EXPANSION PACKS, so the check was worth doing and the
  answer was "nothing to rename". ACCESS was the real one, and it is
  **persisted** — `QuickPinStore` writes `SettingsSection` raw values into
  `marqueeQuickPins` and its decoder silently drops what it does not recognise,
  so a rename unpins rather than failing. `displayName` per the house rule; the
  doc comment claiming "no `SettingsSection` is persisted anywhere" has been
  wrong since 0.7.2 (A7) and is corrected.
- **The shop's Decision #2 was not in the spec, so nothing was invented for it.**
  What was built is the shape F1 already argued for, one layer up:
  `PurchaseProviding` / `LocalPurchaseProvider` beside `EntitlementStoring` /
  `LocalEntitlementStore`, injected through `AccessStore(defaults:store:purchases:)`
  exactly as the store is. It is `async` because `Product.purchase()` is, and a
  synchronous seam would be unimplementable by the one adapter it exists for.
  The local provider grants immediately, which is precisely what the three
  `UpgradePrompt` call sites did inline before — **no StoreKit, no payment
  path, and no empty shell of one**. What an adapter must fill in is written out
  on `LocalPurchaseProvider`: a product-id table (`Entitlement.id` is *storage*
  and pinned by tests, so it cannot double as one), twenty-one products, a
  `Transaction.updates` listener that must land through `AccessStore` or the
  observable mirror goes stale, restore, and verification.
- **No RESTORE PURCHASES button.** `LocalPurchaseProvider.restore()` returns
  nothing, so the button would report success and change nothing — the exact
  fault `CheatCodes`' own note forbids. It arrives with the adapter.
- **B3 finished the grid consolidation for every surface but the two that carry
  art.** 0.7.3c took four bespoke grids to three plus `DexPickerTile` and said
  the rest was a sitting of its own. The shop's toggle rows are now cartridges,
  and `PackCartridge` takes a glyph rather than an `ExpansionPack` so one
  cartridge serves packs and plain upgrades alike. **`skinGrid` and `modeGrid`
  remain hand-written** — 50pt tiles carrying real art (a fake device, a fake
  LCD running the monochrome pass), which is not the same problem and was not
  this batch's ask.
- **The old ACCESS harness was a developer test rig, and B replaced it rather
  than dressing it up.** What is lost is revoking *one* entitlement without the
  rest; FREE TIER plus REVOKE ALL still reaches every combination, one more tap
  at a time.
- **A1's clearance is the footer's, not the island's, and that was worth
  checking.** The lamps that nearly touched the Dynamic Island are
  `islandStatusDot` and are untouched at 22.1pt (SMALL) / 15.2pt (LARGE). The
  marquee pills share a column with the panel that sums to `bandHeight` exactly,
  so 20 → 24 is 4pt straight out of `marqueeHeight` (109 → 105 SMALL, 127 → 123
  LARGE, floor 60/69) and nothing else in the chassis moves — the same trade
  0.7.2's A9 made, made again with the sum re-derived rather than assumed.
- **A2 does not go through `RecessedLamp`, and the spec's hunch was worth
  testing.** That modifier is generic over `InsettableShape`, but it draws parts
  *recessed* into the deck and the orb is the one part that stands **proud** —
  its own note says so. Routing the orb through it to get a rounded rectangle
  would invert the lighting on the only part meant to catch light. The shape is
  parameterised in `lcdOrb` instead. `islandTopInset`'s corner-arc note claimed
  the controls survive the 26pt cut "because they are circles"; re-derived, that
  is true of the trio and never was what saved the orb, whose box starts 68pt in.
- **A5 does not go through `IconLoader` either, and 0.7.4's parked finding is
  why.** `IconLoader` resolves Iconify slugs, and `rasterize-icons.sh` *deletes*
  any PNG in `Resources/Icons` absent from the generated manifest — an asset
  parked there survives until the next `npm run icons`. The mark ships in
  `Resources/Logo`, beside the wordmark, loaded the way `LogoMark` already loads.
  It is split on luminance into a face and a shade mask by
  `scripts/import-logo-art.py` and tinted in code, because the LCD's ink is the
  user's choice and the master's white-and-grey would be two fixed colours on a
  screen with twenty-one colourways. **The folder the master sits in is not a
  name this project uses**: no type, comment, shipped string or shipped file
  repeats it, which is the line 0.7.3a drew and this keeps.
- **`LogoLayerTests` is the gate 0.7.4 could only write down.** It reads the two
  PNGs off disk through `#filePath` — `VinodexUI` has no test target and linking
  it would make the test uncompilable on the host, which is the whole reason no
  such gate existed — and checks the PNG signature, the IHDR dimensions, that the
  two layers register, and that the mark is landscape. **Scoped to these two
  files on purpose**: auditing all 207 rasterised icons and the five drawn-art
  directories belongs in the generator or `verify-art.py`, next to the tables it
  would check, and is still open.
- **A6 moved no timing.** `BootSequence.duration` is still 1.9s and
  `BootSequenceTests.brief` is untouched: A6 is entirely type sizes, and a POST
  that filled the screen by running longer would be a worse POST. Both of 0.7.3a's
  rules survive — inside the LCD, skippable on a tap. The sizes are bounded by two
  faces with very different metrics (`VT323` advances ~0.4em, `PressStart2P` a
  full em), which is why the lines went 16 → 28 and the header only 11 → 15, and
  why all three gained a `lineLimit(1)` they did not need at the old sizes.
- **A3's gate is derived, not listed.** `lcd.monochromeTint != nil`, the same
  predicate `honorsFontInk` uses, so a fifth single-phosphor mode is covered the
  day it is added and a colour mode cannot opt in. The flash draws white *inside*
  the existing `grayscale`/`colorMultiply` pass, so it comes out in the mode's
  own phosphor. It keys off the chassis's marquee `title` — one string that
  changes on every navigation and is already threaded there — and Reduce Motion
  removes it outright, on the screensaver's reading rather than the POST's: the
  POST keeps its content because the content is information, and this has none.
- **A4 was checked before it was done.** `"PET NAT"` is the `chassisSkin`
  `@AppStorage` value, the FNV-1a seed for the back plate's procedural wear
  (`WornOverlay.seed`), and the stem `stickerStem` derives — all three of
  HALLOWINE's reasons, present on this skin too. Label only. The `petnat` hits in
  `icons.json` and `art/icons/styles/` are the wine style Pétillant Naturel and
  are unrelated.
- **A data batch that is not this one was sitting in the master `shared/`, and
  it was separated rather than absorbed.** `npm run generate` after the version
  bump moved `entries.json` as well as `firmware.json`: four grapes (G159
  Colorino, G162 Espadeiro, G166 Nerello Cappuccio, G169 St. Laurent) carrying
  identity rulings that postdate the 0.7.4 commit — descriptions, one synonym,
  one `keyRegions` entry. `vinodex-ios/shared/data/grapes.ts` was reverted to
  HEAD and regenerated, so this commit carries only `firmware.ts`. **Nothing is
  lost**: `HGapps\shared` is the master and still holds the work for whichever
  batch lands it. This is 0.7.4's own lesson applied on the first run rather than
  hunk by hunk afterwards.

**Parked from 0.7.5:**

- **Not deployed** — stopped at the clean build by instruction. Worth an eye:
  the refresh flash on VINTAGE/AMBER/TERMINAL/GRÜNERBOY (subtle by design, and
  the one item here that is a judgement call about *how much*), the squared orb
  against the shell it sits on, the POST at its new size on a real display, and
  the splash's fanned cartridge trio.
- **`skinGrid` and `modeGrid` are the last two hand-written pickers.** See above;
  they carry real art and are a sitting of their own, still.
- **The general icon-asset gate is still open.** `LogoLayerTests` covers two
  files. The 207 in `Resources/Icons` and the five drawn-art directories do not
  have one.
- **`vinodex-web` was left where 0.7.4 parked it.** `sync-shared.ps1` writes into
  that repo too, so the version bump landed `shared/data/firmware.ts` there as a
  new untracked file (web has never carried it) on top of the uncommitted
  `batch4-into-testing` tree. Nothing was reconciled and nothing was reverted —
  unwinding that tree would have risked the parked 0.7.4 work — but the release
  pass should know the file is there.
- **`bodyFromText`'s `medium-full` defect is untouched**, as instructed. It did
  not collide with anything here. (**Fixed in section E**, same version — see the
  0.7.5 lineage entry above for the measurement.)

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

> **Superseded in part by 0.7.5 (B).** The packs no longer live behind a door
> inside CUSTOMIZE and `SettingsSection.packs` no longer exists — the shelves are
> the shop's own body, IAP-backed. Everything below about *what a pack is* stands
> unchanged: they still collect rather than gate, ownership is still the union
> through `impliedBy`, the catalog is still Swift, and Brazil is still Brazil.
> What changed is where the shelf is and what the tile beside it is called. See
> the 0.7.5 entry above for why the grid constraint that put it in CUSTOMIZE
> stopped applying.

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

**0.7.5, The asset gate** (`audit-review/FINDINGS.md` A026–A028). A small batch
that closes the three asset-gate findings, run while `auditbot` worked the
safe-tier housekeeping.

- **The gate found a live bug on its first run, which is the whole argument for
  it.** `assertAssetsExist` reported `flag: Brazil — expected
  Sources/VinodexUI/Resources/Flags/brazil.png`. `icons.json` has listed a Brazil
  flag since 0.7.3c; the master was in `shared/pixelflags/South America/brazil/`
  the whole time; nobody re-ran `npm run icons`, so it was never copied into the
  bundle, and `FlagLoader` returned nil for every Brazilian region. That is the
  **fourth** silent-missing-asset bug in four batches, after `icon: "fruit"`
  (0.7.4), the screensaver layers (0.7.5 A5) and the Brazil/Mexico outlines
  (0.7.5 D) — and the first one found by a machine rather than by reading.
- **auditbot's placement held: the generator, not `verify-art.py`.** Verified
  rather than assumed. `verify-art.py` re-runs the importers into a temp tree
  with `ART_OUT` and diffs pixels, so it can only answer "did the committed art
  change" — it never loads the catalog and cannot know which ids are
  *requested*. The generator already holds the manifest it just built. It is
  also the half that runs in CI: the `data` job runs `npm run generate` on every
  push, while `icons:verify` needs Pillow and is run by hand.
- **One refinement to the placement: it runs *after* the writes.** The other
  assertions throw before `writeFileSync`. This one cannot, because
  `rasterize-icons.sh` reads the `unique` list *out of* `icons.json` — a gate
  that threw first would refuse to emit the manifest the rasteriser needs in
  order to produce the file the gate is demanding, and a new icon id would be
  unbootstrappable. Ordered after the write, adding an icon is: generate (fails,
  naming the id) → `npm run icons` → generate (passes).
- **No backlog list, deliberately.** `OUTLINE_BACKLOG` earns its keep because
  drawing an outline to match the other 28 is a job that can be honestly
  outstanding. Nothing this gate checks is: every id is satisfied by `npm run
  icons`, one command and no drawing. An allowlist with nothing in it is rot
  waiting to happen.
- **Proved against injected data, all four resolution classes.** With the file
  removed, the gate names `game-icons:almond`, `art:outline-france (via
  icons.countryShapeIcons.france)`, `flavorArt: almond` and `flag: France`
  respectively. It also matches `IconLoader`'s scale walk exactly: with only
  `@3x` present and `@1x`/`@2x` gone it **passes**, because that is an icon the
  app draws.
- **The `art:` ids are collected by walking the manifest, not by listing tables.**
  Nine tables carry them today in three value shapes, and a hand-kept list of
  tables is precisely what went stale in `COUNTRY_SHAPE_ICONS`. The walk covers
  the tenth for free. The three portrait tables (`flavorArt`, `grapeArt`,
  `styleArt`) ship bare stems a walk cannot tell from prose, so those are named.
- **A026/A027: the four rosters now agree, and a test holds them there.**
  `import-logo-art.py` shipped in A5 wired into nothing — not `package.json`,
  not `rasterize-icons.sh`, not `verify-art.py` — so the screensaver wordmark was
  reproducible from `art/icons/dvd/` only by someone who knew the file existed.
  `import-stamp-art.py` had been in the rasteriser and not the verifier since
  0.6.4, so `StampArt` was generated and never checked. Both are now in all
  three, and `ArtPipelineRosterTests` treats `scripts/import-*-art.py` **on
  disk** as the authority: the rasteriser's roster, `IMPORTERS`, `DIRS` (through
  each importer's `output_dir(..., "Name")` call) and the `package.json` scripts
  are all checked against it. Injecting each of the four drifts fails the suite;
  restoring makes it green.
- **Two importers had to learn `ART_OUT` first.** `import-logo-art.py` and
  `import-stamp-art.py` hard-coded their destinations, so adding them to
  `verify-art.py` as they stood would have turned `npm run icons:verify` — a
  command whose docstring promises it "can never overwrite" the bundle — into a
  write over 256 tracked binaries.
- **`icons:verify` was already red, on six files, and is now green.** Not this
  batch's doing: the same six `ClassArt/subclass-*` files were CHANGED at
  `4c308ae`. Measured against `subclass-citrus` and `subclass-floral`, which
  already carry budgets, they are indistinguishable — 0.009–0.257% of pixels
  moved (controls 0.115–0.199%), max per-channel delta 17–31 (controls 15–37),
  and **zero alpha pixels moved** in any of the eight, which is what an actual
  art edit would show first. So they went into `TOLERANCE` as what the table
  says it is: a record of the quantiser's imprecision, here crossing a platform
  boundary — the existing budgets were measured on darwin-arm64 and the pipeline
  now also runs on win32 and in WSL.
- **The icon half is byte-reproducible, which is worth writing down.** Rasterised
  fresh in WSL into a temp tree and diffed against the bundle: all 207 PNGs
  identical, 0 of 34 flags differing but the one that was absent. `npm run icons`
  is not a lossy step for the Iconify half.
- **The silent failure itself is still silent, by design.** `IconLoader.image`
  and `PixelArtLoader.image` still end in `return nil` with no diagnostic. That
  is correct at runtime — a shipped build should degrade, not trap — and the
  point of A028 is that the id can no longer *reach* a shipped build.

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

> **Swept 0.7.5 (A029).** This section was written at 0.6.2 and four of its
> items had been done for five releases while still reading as open, which is
> its own kind of rot — a checklist nobody trusts is a checklist nobody reads.
> Done items are struck with the release that closed them; the ones still open
> keep their box, and the three that are now tracked as audit findings say so.
> The **live** items are: grape-sprite prune, KNOWN-ISSUES.md 0.6.x section,
> `HGapps` git init (A033), the spec-file move, and the web hardening list.

- **vinodex-ios repo**
  - [ ] Prune retired grape sprites: with the leaf now code-driven, only the
    `-rare` bases (+ blends' rare variants, `green-common` unused?) are
    referenced by `grapeArt`. The `-common`/`-noble` artist variants are
    dormant payload — either delete from Resources (masters stay in
    `art/icons/grapes`) or record why they stay. ~200KB.
    *Still live, and now measurable: 0.7.5's asset gate reports `grapeArt` uses
    **14 distinct stems** against **33 files** in `Resources/GrapeArt`. Note the
    gate only proves every referenced stem exists — it says nothing about
    unreferenced ones, so this stays a judgement call.*
  - [x] ~~`art/` and `pixelflags/` are untracked working dirs at repo root —
    decide: commit them or move them out.~~ **Done, and the recommendation was
    taken.** `art/` is tracked (310 files) and `pixelflags/` moved to
    `shared/pixelflags` in 0.6.5 (batch 4, phase 1) — the cross-repo master,
    because the flags are the one art asset both apps consume. There is no
    `pixelflags/` at this repo's root any more.
  - [x] ~~`.vscode/` at repo root is untracked~~ — committed; it carries the
    Swift/WSL `swift.path` wiring, as suspected.
  - [x] ~~Delete `Resources/Icons` orphans again after the next `npm run
    icons`~~ — the prune step ran clean in 0.7.5: 207 PNGs, 0 orphans, and all
    207 byte-identical when re-rasterised. Superseded as a standing chore by
    `assertAssetsExist`, which fails the *other* direction (a referenced id with
    no file) on every `npm run generate`.
  - [ ] KNOWN-ISSUES.md: add a short section for the 0.6.x additions —
    find-missing-refs.mjs as the data gate, the leaf-recolor loader, and the
    "art masters vs shipped Resources" relationship. *Add the 0.7.5 gates to the
    same section while there: `assertOutlineCoverage`, `assertAssetsExist` and
    `ArtPipelineRosterTests`.*
- **HGapps root**
  - [x] ~~Root .md census: move SHIPPING-REVIEW.md + PORT-TO-WEB.md to an
    `archive/` folder~~ — done in 0.6.5. Both have lived in `HGapps\archive\`
    since, alongside four retired scratch drops (including
    `shared-newicons-retired-0.6.5`). The live root docs are `README-layout.md`
    and `V1-ROADMAP.md`; this file moved to `vinodex-ios\horizon-md\`.
  - [ ] `HGapps` root is not a git repo — the canonical `shared/` master and
    these planning docs are unversioned. Cheap fix: `git init` at root with a
    .gitignore covering the two repos and `xtool/` — the master data deserves
    history. **Now tracked as `audit-review/FINDINGS.md` A033**, which adds the
    consequence: it is *why* the hub↔repo syncs are one-way. Still a user
    decision.
  - [ ] Downloads spec files (`vinodex-0.5.9.md`, `vinodex-0.6.2.md`,
    `vinodex-missing-data*.md`) — move into `HGapps\specs\` so batches and
    their specs live together and survive Downloads cleanup. *Still open;
    `HGapps\specs\` does not exist yet, and specs since 0.7.0 have arrived
    pasted as often as as files.*
- **vinodex-web repo**
  - [x] ~~Commit the synced `shared/` and the new `shared/newicons/` art
    drop.~~ The `shared/` sync is standing practice (behind web `npm run
    typecheck`). **`shared/newicons/` no longer exists** — it was retired in
    0.6.5 when the drawn-art masters moved to `art/icons/`, and the drop is in
    `HGapps\archive\shared-newicons-retired-0.6.5`. Committing it is not a thing
    that can be done.
  - [ ] The SHIPPING-REVIEW hardening list is still open: CI workflow
    (install/typecheck/build), master branch protection, README truth pass
    (pivot sentence, shared/ ownership table). *`paritybot`'s beat; overlaps
    A001–A004 and A031 in the audit ledger.*

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
