# vinodex 0.8.0 — spec

*Draft for `dexbot`. Twelve items, mostly small and independent — but **A is
blocked** and must be read before anything is planned around it.*

Version is a minor bump rather than 0.7.10: section A replaces every country
outline in the app and section B renames the boot screen's authorship. Neither is
a patch-level change.

---

## A. All 30 country outlines regenerated, sheen removed — BLOCKED, read first

The ask: the Brazil and Mexico silhouettes from 0.7.9 read better than the 28
hand-drawn ones, so regenerate **all** of them the same way, and drop the
specular mark — outline only.

**Two things stand between here and that, and neither is optional.**

**A0a. The generator script no longer exists.** 0.7.9's batch log records it
plainly: *"The generator script is in the session scratchpad, not the repo — it
is a one-shot over a master, like every other derived-sprite pass."* That
scratchpad belongs to a finished session. The script has to be rewritten.

More importantly, **the one-shot argument stops being true here.** It held while
two outlines were derived and 28 were drawn by hand. Once all 30 come out of a
script, that script *is* the master art and must live in the repo alongside
`import-class-art.py` and `import-style-art.py`, with the authored lon/lat rings
as its input data. Write it to be re-runnable, not to be thrown away.

**A0b. The importers are not reproducible across machines, and this batch is
exactly where that bites.** 0.7.9 found that re-running the importers on Windows
rewrote all 123 tracked PNGs with **11 differing in decoded pixels** — up to 84
px of 42,300, `Image.quantize` choosing a different palette across Pillow
versions. `icons:verify` compares decoded pixels, so it fails on any machine but
the one that generated them. Neither importer uses `art_common.save_stable`.

Regenerating 30 outlines through that pipeline bakes one machine's Pillow build
into the repo's art.

**Fix A0b first, as its own commit, before drawing anything**: route the
outline generator and both existing importers through `art_common.save_stable`,
pin the quantisation so a palette choice is deterministic, and confirm
`icons:verify` passes on a re-run that produces byte-identical files. Then do the
art.

**A1. The outlines themselves.**

- All 30, in the treatment 0.7.9 gave Brazil and Mexico: flat fill, one-cell
  black cel outline, comparable canvas.
- **No specular mark.** Remove it from Brazil and Mexico too, so the set is
  uniform — the ask is outline only.
- The projection must stay **uniform in x**. `regions.ts` authors `mapPosition`
  as fractions of the outline's own canvas, and 0.7.9 verified Serra Gaucha and
  Campanha land in Rio Grande do Sul on a uniform projection. A non-uniform x
  scale moves every region dot on every map in the app.
- **Check every existing `mapPosition` against its new outline**, not just the
  two from last batch. This is the item's real risk: 124 regions carry authored
  dot positions tuned against the *hand-drawn* silhouettes, and replacing the
  art underneath them can walk a dot into the sea. Report any that move.
- The 28 replaced PNGs are tracked, so `git` is the undo. Do not delete the
  hand-drawn masters if any exist outside the repo.

---

## B. BIOS boot screen

- **B1.** Replace "VINODEX SOFTWARE" with **HORIZON/GODOT**.
- **B2.** Remove the "VINODEX HANDHELD SYSTEM" line entirely.
- **B3.** Centre the version line at the top.
- **B4.** Centre the HORIZON/GODOT text.
- **B5.** Scale the whole screen's UI up slightly.

`BootScreen.swift`. Note 0.7.7 rebuilt this screen and 0.7.8 moved it back
inside the display, so the surrounding comments carry two batches of reasoning —
update them rather than leaving them describing a layout that no longer exists.

The version string comes from `AppVersion` through `firmware.json`; B3 is
alignment only and must not touch resolution. `BiosChromeTests` pins that the
title is not the placeholder — expect it to need updating for B1/B2 and check
whether it is asserting the removed string.

---

## C. Orb — match the lamp height, and match the lamp *look*

**C1. Height.** The width is right and does not change. The orb's height becomes
the lamps' height, so it grows on the top and bottom edges only.

Concretely: 0.7.9 made height the authored axis at `controlButton x 0.234`
(14.98pt at SMALL) while `islandStatusDot` is `controlButton x 0.33`. C1 is those
two factors becoming one. Horizontal clearance is untouched because the width
does not move, and the row has headroom — `islandSlot` is 44pt against a bead
going to roughly 21pt — so the 0.7.9 clearance table does not need re-deriving.
Confirm that rather than assume it.

Aspect falls out at roughly 3.76 and stays **derived**. Do not re-author it.

**C2. The look.** Repass the orb's glow and treatment to match the status lamps
as they render today. 0.7.9 moved `PulseGlow` from `width x 0.3` to `height x
0.7` specifically because the halo had gone wrong at the new width — that fix
was geometric, not stylistic, and C2 is the stylistic pass it did not do. The
three miniature chassis (Workshop, Settings, Walkthrough) each derive their orb
through `DexMetrics.islandOrbWidth(lamp:spacing:)`; whatever changes here has to
reach them too, as it did last batch.

---

## D. Back plate

Remove `Text("HOLD A STAMP TO REPOSITION")` — `DeviceBackPlate.swift:778`.

Check what the surrounding layout does with the space; 0.7.8 already
reorganised this plate when the sticker stopped being a stamp.

---

## E. What's That...?

- **E1.** Scale the screen's UI up slightly, as with B5.
- **E2. The guess field autocompletes.** Suggest matching entries as the player
  types.
- **E3.** GIVE UP gets a red button treatment rather than plain text.

**E2 carries the one real design risk in this batch and needs a decision.** The
guess is judged through `LabelRecognitionService` (0.7.9 B), which deliberately
counts **only non-inferred matches** so that naming a region cannot win a grape
round. A naive autocomplete over the whole catalog undoes the game: if the player
types "neb" and the list offers *Nebbiolo*, the round is over, and every round
becomes a spelling exercise.

Options, in the order I would take them:

- **E2-a (recommended).** Suggest only from entries the player has already
  discovered, and never from the answer's own category when the round is nearly
  solved. Keeps the type-ahead convenience for known names without handing over
  unknown ones.
- **E2-b.** Suggest only after 3+ characters and cap the list at 5, ranked by the
  same folding the judge uses. Simpler, still leaks.
- **E2-c.** Autocomplete purely as spelling repair: offer a correction only when
  the typed string is already a near-match, so it fixes typos and never
  introduces a name.

**Pick one and say which in the batch log.** Whichever it is, the suggestion list
must not be able to enumerate the catalog for a player who types one letter.

---

## F. "Paper" becomes "exam"

`paper` appears **225 times across 33 files**, and the great majority are not
user-facing. Scope, explicitly:

- **In scope:** strings the player reads. `WineExamScreen`, `TastingQuizScreen`,
  `DailyResult`, `NotificationPlan`/`NotificationScheduler` (the reminder copy
  says "today's paper is live"), `ShareCards`, `DexAlert`, `StampUnlockedPrompt`.
- **Out of scope: the `ExamPaper` type and every identifier built on it.**
  Renaming the type is churn across Core and its tests to describe a change no
  player can see, and 0.7.5's D1 note is the precedent — the door keeps its name
  when the room behind it changes.
- **Out of scope and do not touch: `firmware.ts`'s shipped release notes.** The
  0.7.8 entry says "today's paper is live". That is a record of what that release
  said, and editing it rewrites history. Past entries are immutable; only
  `CURRENT` is ever authored.

Grep for user-facing "paper" after the pass and account for every remaining hit
in the batch log — either it is a type name or it is a shipped changelog line.

---

## G. Grape card attributes

- **G1.** The top two attributes (colour, type) get slightly smaller.
- **G2.** The third (origin) becomes a **slimmer button below**, in the treatment
  region cards use for KEY GRAPE.

Find the region-card key-grape component first and reuse it rather than
re-deriving the look — that is the whole point of the comparison in the ask.

---

## H. Screensaver delay

30 seconds → **60 seconds**. `Screensaver.swift` / the delay constant it reads.
0.7.6 moved this from 15 to 30 and the comment says why; extend it rather than
replacing the reasoning.

---

## I. Europe: blue, not red

The globe marker and the icon for Europe both become blue. Check first whether
red is carrying meaning anywhere else on the globe — if the six continents are
each a colour, this is one entry in a table; if red means something (selected,
locked), this needs a different fix.

---

## J. Search placeholders name their subject

The search field's placeholder should state what is being searched: "Search
grapes..." on varieties, "Search flavors..." on flavors, and so on for regions,
styles and countries.

One placeholder string per screen, sourced from whatever the screen already
knows it is listing — not a hardcoded string per call site.

---

## K. Rosé chip is pink

In styles. Match whatever the chip colour table already looks like; if the other
style chips are semantic (red/white/sparkling), this is one row.

---

## L. Home screen tile text is not aligned

The main menu buttons (GRAPES, FLAVORS, STYLES, ...) do not share a baseline —
STYLES and FLAVORS are visibly out against the others. Centre the tile text so
all of them align.

Likely a per-tile padding or a one/two-line label difference rather than a
centring bug per tile; find the cause rather than nudging the two that show it.

---

## Order and risk

Do the cheap, independent, low-risk items first so a partial batch still ships
most of the value: **D, H, K, I, L, J, F, G, B, E, C**, with **A last** because
it is gated on A0a/A0b and is the only item that can fail outright.

Do not start A's art until `icons:verify` passes on a byte-identical re-run.
