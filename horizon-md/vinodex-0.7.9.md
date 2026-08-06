# vinodex 0.7.9 — spec

*Draft for `dexbot`. Runs **after** the sommbot P1/P2 data batch lands, because
sections C and G depend on regenerated `entries.json` / `exam.json`.*

Branch from the tip that carries 0.7.8 (verify it is a strict ancestor before
cutting — see the 0.7.8 branch note in PLAN.md, which nearly went destructive on
exactly this step).

**Scope warning.** This was asked for as a "small batch" and it is not one.
Sections A, E and F are genuinely small. B, C and D are each a batch's worth on
their own. See "Suggested split" at the bottom.

---

## A. Orb — longer stadium, sized to the lamp trio

Continues 0.7.5 A2 (orb stopped being a circle), 0.7.6 E1 (became a stadium) and
0.7.8 A3 (elongated to 35.2 x 15.0 at SMALL, `islandOrbAspect = 2.35`).

**A1. The orb's width becomes the lamp trio's total width.**

Today `DexMetrics.islandOrb` is a hand-set number and `islandOrbAspect` is a
hand-set 2.35. The rule to encode instead: the orb spans the same length as the
whole three-lamp cluster, so the two island clusters read as a matched pair of
stadiums rather than a bead against a row.

- Derive the width from the trio, not from a literal:
  `3 * islandStatusDot + 2 * statusDotSpacing`. Both metrics already exist in
  `DexTheme.swift`.
- Keep height derived. `islandOrbAspect` stops being an authored constant and
  becomes the *consequence* of the new width over the retained height — or, if
  you prefer to hold the current 15.0pt height, state that as the authored value
  and let the aspect fall out. Either way **one** axis is authored and the other
  is derived, which is the rule the file already follows.
- `DeviceWorkshopScreen.swift:292` draws the miniature at `width: 11` with the
  same derived height. It must follow the new rule, or the workshop preview
  drifts from the chassis it is previewing.

**A2. Re-verify the island clearance, and do not solve it by shrinking the orb.**

`DexTheme.swift` around line 384 records the current geometry: the orb's bounding
box starts at 68.4pt (SMALL) / 68.0 (LARGE) against an island starting at ~133,
leaving ~25pt of clearance, and `islandOrbInsetLeading` is 64. Widening the orb
spends that clearance directly.

- Re-derive the clearance at both `UIScale` settings and record the new numbers
  in the doc comment, as every prior pass has.
- If it goes tight, reduce `islandOrbInsetLeading` and move the bead inboard —
  do **not** shrink the orb back. The point of the item is the size.
- If it cannot be made to fit at LARGE, stop and report rather than
  half-applying it.

**A3. The touch slot must still contain the bead.**

The hit shape is a 44pt `Rectangle` (`DeviceChassis.swift:507-531`) and the
long-running argument in that comment is that the *rectangle* is right because
the bead is small. A wider bead does not change that conclusion, but it does
change the arithmetic: if the new width exceeds `DexMetrics.islandSlot`, the slot
grows to contain it. Update that comment block with the new dimensions — it
currently states "35.2 x 15.0 at SMALL" as fact.

---

## B. "What's that...?" becomes a clue-by-clue guessing game

The tile at `ToolsScreen.swift:134` currently routes to `onDailyGrape` ->
`DailyGrapeScreen` (211 lines). Replace what is behind the door; keep the door.

**B1. The game.**

One hidden entry per round. Clue chips are revealed one at a time, and the player
guesses at any point. Fewer chips revealed = higher score.

- The hidden entry may be a **grape** or a **region** — the tile's name has never
  promised grapes, and the catalog has 171 and 124 of them respectively.
- Clues are generated from facts already in the catalog. Grape: colour, origin
  country, body, tannin, a signature flavor, a region that grows it, rarity
  tier. Region: country, climate class, a principal grape, a style it makes, an
  appellation. Order them **vague to specific**, so the first chip is
  "It's red" / "It's French" and the last is close to a giveaway.
- Clue count: aim 5-6 max. Every clue must be *true of the answer* and the set
  must be *sufficient to identify it* — a round that cannot be won on the full
  set is a bug, and that is a testable property.

**B2. Where the code lives — the house rule already written down.**

`OCRService.swift:10-15` states it: rules about *wine* live in `VinodexCore`
where `swift test` on Linux can see them; only the view layer sits in
`VinodexUI`. So clue generation, ordering, scoring and answer-matching are Core
types with tests; `WhatsThatScreen` is a thin view.

**B3. Reuse the label matcher for the guess input, do not write a second one.**

Free-text entry against a 438-entry catalog needs fuzzy matching, and
`LabelRecognitionService` in Core already does exactly that job (accent folding,
near-miss tolerance) for the label reader. Reuse it. Writing a second fuzzy
matcher is the failure mode this item is most likely to produce.

Confirm before building whether the input should be free text or a multiple
choice — free text plus the existing matcher is the better game and the larger
build.

**B4. Disposition of `DailyGrapeScreen`.**

Find every reference before deleting anything. Note there is a separate DAILY
CHALLENGE tile backed by `TastingQuiz`, so the two are not the same feature and
retiring this screen must not take the daily with it. If the "grape of the day"
idea is worth keeping, say where it went in the release notes.

---

## C. Lineage — complete the data, enlarge the UI

**C1. The data half is not dexbot's.** `shared/data/grapes.ts` carries lineage on
**57 of 171** grapes. "Complete lineage" is a sommbot job: extend to the grapes
with documented parentage, and mark the genuinely unknown ones explicitly so the
UI can tell *unknown* apart from *not yet authored*. That distinction is a data
decision that has to be made before the UI can render it honestly.

**Sequencing inverted — C1 now runs AFTER this batch, not before.** The original
draft had sommbot author the data first. Two things changed that:

- The P1/P2 batch left `swift test` red (section G's pins). Parking dexbot behind
  a 114-grape sourced-research pass keeps the repo broken for hours over a
  dependency that is soft, not hard.
- The dependency actually points the other way. C2 defining how the tree renders
  *unknown* versus *not yet authored* **is** the decision C1 was supposed to make.
  Settle the contract in the UI, then author data to it.

So dexbot builds C2 against the 61 lineages authored today, and sommbot's C1 pass
fills nodes into a UI that already handles them. Do not edit `shared/` in this
batch — that is what keeps the two passes from racing on `entries.json`.

**C2. The UI half.** `GrapeLineageScreen.swift` is 505 lines and shipped in
0.7.5. Bigger nodes, cleaner layout, per the ask. Two things to carry in:

- Gouais Blanc arrives in the sommbot batch and is named as a parent by ten
  catalog grapes — it will be the single largest node in the tree. Check the
  layout survives a node with that many children before calling C2 done.
- Whatever "unknown parentage" resolves to in C1 needs a visual state here.

---

## D. Label scanner — needs a decision before it can be specced

**The answer given was Apple's Visual Intelligence image search. I checked it
against the project and it does not fit, for three separate reasons.**

1. **Deployment target.** Visual Intelligence image search requires iOS 27+.
   `vinodex-ios/Package.swift:17` is `.iOS(.v17)`. That is a ten-version jump
   for one tool.
2. **It is the opposite integration from the one described.** The App Intents
   flow registers *your app as a provider*: the system hands your app an image
   and your app returns matches **from its own catalog**. It does not hand you
   web reverse-image-search results. Vinodex would still be doing all the
   matching against its own 438 entries — which is what the scanner already
   does. It would add a system entry point, not new knowledge.
3. **Build system.** It needs an App Intents extension target.
   `DeviceChassis.swift:486-490` already records the same class of limitation
   for ActivityKit: "a SwiftPM/xtool project has no way to add" a widget
   extension. This is very likely the same wall. Worth confirming rather than
   assuming, but do not plan around it succeeding.

**What is actually available.** The architecture is already built for this.
`OCRService.swift:88-111` defines `LabelRecognitionProvider` as the documented
extension point, and says so in as many words: swapping in a
`GoogleVisionProvider` or an `OpenAIProvider` is *one line at the
`LabelReaderViewModel` initialiser*, and neither `LabelReaderView` nor
`LabelRecognitionService` changes by a character. The on-device-only default is
called out there as a product decision about which provider is installed, not a
constraint of the design.

So the three real options are the ones from the original question, and one of
them has to be picked before D is buildable:

- **D-a. Improve the local matcher only.** No network, no key, no cost. Better
  scoring and phrase folding against the catalog. Can never name a specific
  bottle.
- **D-b. OCR plus a text web-search fallback** when the local match is weak. New
  `LabelRecognitionProvider` implementation behind the existing protocol. Needs
  network and a key; text search is much cheaper and more reliable than reverse
  image search.
- **D-c. True reverse image search** via a vision API. Best on unusual labels.
  Ships photos off-device, needs a key in the app, per-scan cost, no offline
  path.

**Ruling for this batch: build D-a. Leave D-b/D-c as the one-line swap they
already are.**

The user asked for the full spec to run, so D does not sit out — but installing a
remote provider means an API key shipped in the app, per-scan cost, and user
photos leaving the device. Those are the user's calls to make explicitly, not
assumptions for a batch to absorb, and none of them are needed for the scanner to
get materially better at its actual job.

So D-a is the scope: improve `LabelRecognitionService`'s scoring and phrase
folding against the catalog, and improve how the result screen presents a weak or
ambiguous match. Concretely, and all inside Core where `swift test` can see it:

- Better multi-line phrase folding — an appellation is routinely split across two
  or three `RecognizedString`s and is currently scored as fragments.
- Rank by `prominence` as well as text match: the producer is the biggest text on
  the label and the appellation is usually second, which is signal the matcher
  has available and does not weight.
- Distinguish "no match" from "several plausible matches" on the result screen.
  The second is common on a French label naming a region the catalog holds and a
  producer it does not, and presenting it as a failure is the wrong answer.
- Do **not** touch `LabelRecognitionProvider`. Its whole purpose is that D-b/D-c
  arrive later without any of this changing.

Report at the end what the match rate looks like before and after on whatever
sample is available, so the D-b/D-c decision has a baseline to argue against.

---

## E. Brazil and Mexico country outlines

From the sommbot review: `countryShapeIcons` has 28 keys and lacks Brazil and
Mexico, so regions R117, R118 and R098 resolve their art through the `guard let`
and draw nothing. This is the only live user-visible defect in the batch.

Add the two outlines. No pins move; nothing depends on it.

---

## F. Slovenia joins the OLD WORLD pack

The Blaufrankisch (G076) origin is ruled: **Slovenia**. Sommbot applies the data
change; this is the iOS half.

`ExpansionPacks.swift:255` lists OLD WORLD as France, Italy, Spain, Portugal,
Germany, Austria, Greece, Hungary, Switzerland, Georgia. **Slovenia is in neither
atlas pack**, so without this edit G076 falls out of OLD WORLD and into no pack
at all. Add Slovenia.

The data side is **already applied**: origin Austria -> Slovenia (VIVC 1459,
whose marker pedigree `ZIMMETTRAUBE BLAU x HEUNISCH WEISS` matches the authored
lineage), Burgenland kept as region-of-fame. The exact edit here — in
`ExpansionPacks.oldWorld`, the `.countries([...])` list:

```swift
"Austria", "Greece", "Hungary", "Switzerland", "Georgia", "Slovenia",
```

**Blaufrankisch has silently left OLD WORLD right now.** Pack membership is
**265 -> 264**, restored to **265** by this edit. `atlasCountriesResolve` passes
once Slovenia is added because `G076` supplies the origin — it would have
*failed* had the pack been edited before the data, which is why the order ran
data-first.

Nothing else moves: `FREE_COMMON_ORIGINS` gates COMMON grapes only and G076 is
UNCOMMON; `stats.countries` stays 26; `ExpansionPacks.all.count == 12` holds. The
**GODFORSAKEN pack grows 15 -> 16** on Gouais Blanc — no count is pinned and the
`allSatisfy { $0.category == .grapes }` assertion still holds.

**Related art note for section E.** The Slovenia COUNTRY gate has a blurb, a flag
gradient and a `countries.json` entry but **no outline art**, so it still reads
"Regions coming soon" for what is now a live entry origin. This is not a
generator failure — `OUTLINE_BACKLOG` correctly reports only Brazil and Mexico,
because outlines resolve *region* art and Slovenia has no region. Flagged, not
scoped: fixing it means authoring a Slovenian region, which is a data call.

---

## G. Coverage pins — exact numbers, do not re-derive

The sommbot batch landed **8 entries, 438 -> 446**: styles `S033` Madeira, `S034`
Cava; grapes `G173` Sercial, `G174` Boal, `G175` Malvasia de Sao Jorge, `G176`
Gouais Blanc, `G177` Plavac Mali, `G178` Manto Negro. Exam bank 407 -> 420.
`swift test` is **red until these land** — do this first, not last.

**`Tests/VinodexCoreTests/CoverageTests.swift`** — grapes `171`->**177**, styles
`31`->**33**, `stats.total 438`->**446**. Unchanged: regions 124, continents 6,
and `stats.countries` stays **26** (it counts distinct *region* origins, and
Slovenia has no region).

**`Sources/VinodexCore/WineDatabase.swift`** ~line 814 — append `438,` to
`waveMilestones` before `total`.

**`vinodex-web/web/src/services/coverage.test.ts`** — line 54 `171`->**177**,
line 56 `31`->**33**, line 68 `438`->**446**. Lines 55/57/58/81 unchanged.

**`Tests/VinodexCoreTests/ExamTests.swift`** — `407`->**420**, beginner
`137`->**144**, intermediate `147`->**151**, advanced `123`->**125**,
multipleChoice `234`->**246**, trueFalse `63`->**64**. Unchanged: selectAll 37,
aroma 23, matching 21, ordering 18, imageId 11, `minCellCount` **6**.

**`Tests/VinodexCoreTests/GrapeLineageTests.swift`** — `171`->**177**, authored
`57`->**61**, connectedIDs `68`->**75**.

> **Lines 87, 88 and 94 must be rewritten, not renumbered.** They use Gouais
> Blanc to prove an off-catalog ancestor is untappable — `isNavigable == false`,
> `entryID == nil`, `db.entry(named:) == nil`. Gouais Blanc is a catalog entry as
> of today, so all three assertions are now false and the property they guard is
> unguarded. Substitute **Magdeleine Noire des Charentes**, named by `G004`
> Merlot and `G012` Malbec. Line 127's `throughGouais == 9` still passes —
> sommbot verified it; leave it alone.

Finish by running `scripts/find-missing-refs.mjs`. The gate is green as of the
sommbot batch — zero dangling across 177 grapes, 124 regions, 33 styles, 106
flavors, 30 countries — so any dangling ref after this batch is yours.

---

## Suggested split

If 0.7.9 should stay small, ship **A + E + F + G** — four contained items, one of
them a real defect fix, all unblocked once sommbot lands.

Then **B** as 0.7.10 and **C2** as 0.7.11 (after sommbot's C1), with **D**
waiting on the provider decision.
