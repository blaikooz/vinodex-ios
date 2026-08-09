# vinodex 0.8.1 — spec

*Draft for `dexbot`. Ten items. **G is held pending a ruling** — everything else
is unblocked. Item B is a bug hunt, not a data edit.*

Cut `v0.8.1-batch` from the tip of `v0.8.0-batch` (`70f561c`).

---

## A. Chassis mockups go back to small, and appear in the shop

**A1.** In Customise, the chassis-selection mockup buttons were enlarged. Revert
them to the previous smaller size. Find the batch that grew them and restore the
metric rather than hand-picking a new number.

**A2.** The same mockups should render in the **device packs and display packs**
in the shop — the shop currently sells those packs without showing what they
look like.

0.7.9 established that the miniature chassis derive their orb through
`DexMetrics.islandOrbWidth(lamp:spacing:)`, and 0.8.0 routed the orb through
`recessedLamp`. Three miniatures already exist (Workshop, Settings, Walkthrough)
— the shop is a fourth caller of the same component, not a new drawing. If it
does not factor cleanly, say so rather than copying it.

---

## B. Prosecco reads as rosé — find where, do not patch the symptom

`shared/services/entryUtils.ts:126` already declares `'prosecco': 'WHITE'` in
`STYLE_NAME_COLOR_OVERRIDES`, and `styles.ts` gives S025 `color: C.champagne`.
The shared data is right, so **something downstream is deriving a different
answer**, and editing the override table would fix nothing.

Two candidates worth checking first:

- `normalizeLabel` — the override map is keyed on lowercase and looked up with
  `n.trim()`. If normalisation does not lowercase, every override misses and the
  regex chain runs instead.
- A **second colour derivation on the Swift side**. `EntryDisplay.StyleColorType`
  exists; if it re-derives rather than reading the generated chip, the shared
  override never reaches the device.

This is the same shape as 0.8.0's rosé-chip bug — a table that was correct while
one of its two ends disagreed about spelling. Expect a join, not a value. Pin the
result with a test that fails if Prosecco ever resolves to anything but WHITE,
and check the other 15 overrides resolve too.

---

## C. Lineage boxes and connectors

**C1.** A grape that is *named* but not in the catalog must render as a **square
box like every other node**, not as bare text.

**C2.** A grape whose parent is genuinely unknown says so **in a box**.

0.8.0 shipped exactly the vocabulary for C2: `GrapeLineage.parentageUnknown`,
rendered as `LineageNode.Target.unrecorded` — a dashed unfilled tile with a
slashed-circle glyph. C1 and C2 are the same tile treatment applied to the two
cases that still fall through to text. Do **not** invent a third visual; the
distinction the 0.8.0 log draws is that `unrecorded` means "research says nobody
knows" while an off-catalog name means "real grape, not in the dex" — those are
two labels on one shape, not two shapes.

**C3. The connector lines do not meet the boxes.** Links must attach to the box
edge, for parents *and* offspring. This is the item most likely to be a real
geometry bug rather than a nudge — 0.8.0 took `LineageTile` from 96 to 116pt and
the connector maths may still be drawing to the old anchor. Check the arithmetic
against the tile size rather than eyeballing an offset.

---

## D. Style search gains colour and country filter chips

Add **colour** and **country** as filter chips on the styles search bar.

The chip colour tables already exist and are probed in
`generate-ios-data.ts:234` (`colorTypeChips`, `countryChips`). This is wiring
existing generated data into a screen that does not yet offer it — and B may
change what colour a style reports, so **do B first**.

---

## E. "Type your guess" becomes a search bar

In WHAT'S THAT...?, the guess field becomes a proper search bar.

0.8.0 built the suggestion pool deliberately: only entries the player has already
met (bookmark shelves plus recently-viewed), never the whole catalog, because
suggesting an unmet entry hands over the answer and excluding the answer itself
would be an oracle. **That restriction survives this item unchanged.** E is the
field's *presentation* becoming a search bar; it is not permission to widen what
it searches.

---

## F. Flavor icons, naming, and chip colour

- **F1.** Flavor class and subclass icons get **bigger**.
- **F2.** Rename **class → flavor** and **subclass → family** in player-facing
  text. Same scoping rule as 0.8.0's F: user-visible strings only, not the
  underlying identifiers, and not shipped `firmware.ts` entries.
- **F3.** **Every chip in the flavor filter must be coloured.** Some are
  currently falling through to a neutral default.

F3 is very likely the same class of defect as 0.8.0's rosé chip and this batch's
item B: a probe key that disagrees with the reader's key, leaving a table row
unreachable. Check the join before assuming the colours are missing. If it is a
join bug, pin it the way `chipKeysResolve` pins the colour-type table.

---

## G. Madeira and Cava classification — HELD, do not action

The ask says the two new styles were put in a "new style class" and should be
ORIGIN, and that the style class should be deleted.

**The data does not match that description**, so this is held rather than
guessed at. As shipped: S033 Madeira and S034 Cava are both
`classification: "STYLE"`, which is not new — **27 of the 33 styles are STYLE**,
including Port, Champagne, Sherry and Prosecco, which are origin-named in
exactly the same way. No entry in the catalog uses `ORIGIN` at all, so nothing
was added to a new class and there is no new class to delete.

Three readings, and they are very different jobs:

- Reclassify only Madeira and Cava to ORIGIN. Two-line data edit, but it leaves
  Port/Champagne/Sherry/Prosecco inconsistent with them.
- Reclassify **every** origin-named style to ORIGIN. Coherent, and probably what
  "within our system they would be considered origin" means — but it moves
  roughly a dozen entries and changes what the classification filter shows.
- Retire the `STYLE` classification entirely and redistribute all 27.

**This is a `shared/data` change and therefore sommbot's, not dexbot's.** Leave
`styles.ts` alone.

---

## H. Menu glyph above the label, and the pixelize animation on return

**H1.** The menu glyph moves **above** the menu text.

**H2.** It gets the pixelized animation when returning home.

Note H1 interacts with 0.8.0's L fix: the four menu tiles only share a baseline
because a **fixed 56pt glyph box** was introduced — SF Symbols lay out at their
own bounding box, so four symbols were four heights. Moving the glyph above the
label must keep that box, or all four tiles fall out of alignment again. And see
item J: if the glyphs become PNGs, the box is what keeps them honest.

---

## I. Screensavers

**I1.** The V logo in the DVD-bounce screensaver gets **larger**.

**I2.** The marquee screensaver cycles **languages every 5 seconds**.

For I2, the marquee already holds nine languages and 0.7.6 set it to one per
idle. This changes the cadence from once-per-idle to every five seconds, so the
language choice stops being a property of the idle and becomes a property of
elapsed time. `Screensaver.swift`'s note says position is a pure function of
time — put the language on the same footing rather than adding a timer.

Also relevant: 0.8.0 took the idle delay to 60s, so a marquee idle now lasts
long enough for this to matter.

---

## J. Wire in the new button art — app wide

**32 PNGs** are sitting untracked at
`vinodex-ios/art/icons/buttons/buttons/`: backarrow, blindtasting, camera,
cheatcodes, customize, dailychallenge, data, demomode, dev, edit, firmware,
flavors, grapes, haptics, home, labelscanner, moondial, numberedstack, passport,
regions, search, settings, shop, sounds, styles, system, tools, tutorial, user,
whatsthat, wineexam, workshop.

**J1. Fix the layout first.** The directory is nested one level deeper than it
should be (`art/icons/buttons/buttons/`) and carries a `.DS_Store`. Flatten to
`art/icons/buttons/` and do not commit `.DS_Store` — check whether `.gitignore`
covers it.

**J2. These go through the importer, and the importer is now reproducible.**
0.8.0's A0b routed six importers through `quantize_stable` + `save_stable` and
proved a second run writes nothing. Use that path — do not hand-place PNGs into
`Resources/`. Expect `icons:verify` to stay green.

**J3. Replacing SF Symbols with raster art is the risk in this item.** 0.8.0's L
finding is the reason: `Image(systemName:)` sizes to the symbol's own bounding
box, which is why a fixed glyph box had to be introduced for the menu tiles.
Bitmaps have a *different* fixed aspect, so every call site that assumed symbol
metrics needs checking — the menu tiles (item H), the tools shelf, settings rows,
the back arrow, and the search field.

**J4. Not every name maps to one call site.** `search`, `backarrow`, `home` and
`edit` are used in many places; `dev`, `demomode` and `cheatcodes` are behind
developer gates. Report any of the 32 you could not find a home for, and any
call site still on an SF Symbol after the pass — do not leave the app half
converted without saying which half.

---

## Order

**B** first (it gates D), then the contained items **A, C, E, F, H, I**, then
**J** last — it is the widest blast radius and the one most likely to need a
second pass.

**G is not in this batch.**
