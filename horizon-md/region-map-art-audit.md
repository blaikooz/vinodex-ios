# Region map screen — art audit and generation brief

**Status:** the screen is built and running (branch `france-map-test`, France
and Italy). This document is the art half: what it still borrows from Apple,
what it should draw for itself, and the brief to hand the image-generation
session.

**Scope note.** The *maps themselves are not art* and are not in this brief.
They are rendered by `region_map.py` from Natural Earth admin-1 data and
regenerate on demand; drawing them by hand would break the pipeline the whole
feature rests on. What follows is the chrome **around** the maps.

---

## 1. The audit — what the screen currently borrows

Four SF Symbols are doing work on a screen where every neighbouring surface
has drawn art. They are listed with the exact call sites so nothing has to be
hunted for.

| # | Stand-in | Where | What it has to say |
|---|---|---|---|
| A1 | `map.fill` | `RegionMapScreen.swift:118`, section heading over the map | "this block is a map of a country" |
| A2 | `mappin.and.ellipse` | `RegionMapScreen.swift:263`, heading over the chosen region | "this block is one region within it" |
| A3 | `map.slash` | `:106`, empty state | "the map failed to load" |
| A4 | `mappin.slash` | `:324`, empty state | "the catalog has no region here" |

**A1 and A2 are the ones that matter.** They sit at the top of the two
sections a player actually reads, beside `DexFont.retro` headings, next to
pages where the same slot carries a painted face. A3 and A4 are failure
states most players never see — worth drawing eventually, not worth a sheet
of their own.

**Two more gaps, lower priority:**

- **A5 — the detail-map well.** The chosen region's close-up sits in a plain
  `RoundedRectangle` (`:266`). Every other framed thing on the device has
  moulding. A drawn well or passepartout would seat it.
- **A6 — the marquee.** `.regionMap` borrows `marquee-countryscan`
  (`DexRoute.swift`). Legal — art may repeat where `marqueeSymbol` may not —
  but a map-specific marquee would distinguish the two screens.

**Explicitly NOT needed:**

- Region markers. They were drawn and then removed by ruling: at phone width
  they swallowed the areas they marked, and the tap is a colour lookup on the
  map beneath them, so they were never targets. Do not regenerate them.
- Per-region iconography. Fourteen French and twenty-one Italian areas already
  have their own close-up drawings from the renderer.

---

## 2. What to generate

**Priority 1 — a five-tile sheet.** One sheet, five tiles, one row.

| Tile | Stem | Subject |
|---|---|---|
| 1 | `atlas` | A folded paper map, three-quarter view, one fold standing proud. Reads as *a map of somewhere* at 22pt. Not a globe — the globe screen owns that, and this must not be mistaken for it. |
| 2 | `region-pin` | A map pin pushed into a small patch of contoured ground, the ground reading as a *bounded area* rather than a point. Its job is "one region within a country". |
| 3 | `atlas-lost` | The folded map of tile 1, torn or blank-faced. The failure state for A3. |
| 4 | `region-empty` | The pin of tile 2, lying on its side beside an empty patch. The failure state for A4 — the catalog has no region here. |
| 5 | `map-well` | A rectangular frame/moulding for A5, drawn as an empty well with depth — a mounted plate for a small drawing to sit inside. Squarish, roughly 1:1. |

**Priority 2 (optional, only if the sheet has room):** a `marquee-regionmap`
tile for A6 — see §4 for why its specification differs.

---

## 3. Generation specification

**These are the house rules every previous drop has followed. They are not
negotiable — the importers gate on them.**

- **Background: pure magenta `#EE03E1`**, exact, flat, no gradient, no
  antialiasing into it. The importer keys this colour to transparency and
  asserts at least 1% coverage; a white-ground master is rejected outright.
- **No antialiasing against the key.** Hard pixel edges. The slicer's
  fringe-snap will clean stray key-blend, but art drawn soft against magenta
  comes out with a violet rim.
- **Pixel art**, in the register of the existing glyphs — see
  `art/icons/chrome/glyphs/seal.png`, `bell.png`, `stamp.png` for the hand to
  match. Painted rather than dithered, chunky pixels, readable silhouette.
- **Tile size: 200 × 200 px** per tile, laid out in one row. Sheet is
  therefore **1000 × 200** for five tiles. Existing glyphs land at 165–197px
  square, so 200 gives room without a downscale that softens edges.
- **One subject per tile, centred, with a few pixels of margin.** No tile may
  bleed into its neighbour — the slicer cuts on exact tile boundaries.
- **Palette:** these sit on the LCD beside `lcd.accent` green and read at
  22pt. Warm parchment, ink-black linework and one muted accent works; avoid
  saturated greens (they vanish into the accent) and avoid pure white fills
  larger than a highlight (the de-halo pass erodes near-white edges adjacent
  to transparency).

**Deliver as:** `art/inbox/sheet-<letter>-mapglyphs.png`, plus a one-line note
of which tile is which if the order differs from §2.

---

## 4. Why the marquee tile is specified separately

Marquee art is not glyph art. It is drawn to a different size, imported by
`import-marquee-art.py`, and — this is the part that catches people — the
marquee importer reads **green as an ink axis**, not as a colour. A
marquee tile drawn in the glyph palette imports as a solid block. If tile 6 is
attempted, it must be near-monochrome with the subject in light values on the
key, and it should be on its own sheet rather than sharing this one.

Given that, **the recommendation is to skip A6 for now.** Borrowing
`marquee-countryscan` is defensible and costs nothing; a wrong marquee costs a
re-render.

---

## 5. After the sheet lands

The wiring, so the work is not stranded:

1. Slice to `art/icons/chrome/glyphs/` — these are glyphs and go through
   `import-glyph-art.py`, which is manifest-driven, so `npm run generate`
   runs **before** the importer when new `art:` ids are involved.
2. Add the cases to `UIGlyph` (`Sources/VinodexCore/UIGlyph.swift`). A glyph
   with no call site belongs in that file's `unwired` set, by its own rule —
   but these four all have call sites waiting, so none should land there.
3. Replace the four `symbol:` arguments listed in §1 with `art:` stems.
   `DexSection` and `DexSectionEmpty` both already take a drawn face with an
   SF Symbol fallback, so the SF names stay as the fallback rather than being
   deleted.
4. `npm run icons:verify` must stay at zero changed. The region maps live in
   `Resources/Maps/`, which that gate correctly does not walk — but these
   glyphs land in `GlyphArt/`, which it does.

---

## 6. Honest limits

- **The maps will still look machine-made**, because they are. This brief
  makes the *frame* hand-drawn; the countries inside it stay projections of
  Natural Earth polygons. That contrast is either a feature — precise data in
  a drawn device — or the next thing to dislike, and it is worth deciding
  which before commissioning more.
- **Two glyphs may be enough.** A1 and A2 are seen constantly; A3 and A4 only
  when something is wrong or missing. If the sheet is expensive, tiles 1 and 2
  are the whole of the value.
- **Italy has three painted regions the catalog does not cover** — Liguria,
  Molise and Valle d'Aosta — so A4's empty state is reachable today by tapping
  any of them. That is a catalog gap rather than an art one, but it is why
  tile 4 is worth drawing rather than deferring.
