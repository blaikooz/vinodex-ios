# Handoff prompt — paste this into the terminal session

---

You're picking up a finished art-and-data drop and wiring it into vinodex-ios as
a **test**, not a shipping feature. Everything you need is in
`art/inbox/region-maps/`. Read `AUDIT.md` first, then `HANDOFF.md`. Design
rationale, if you want it, is `horizon-md/france-map-plan.md`.

## What you're building

A region map screen for seven wine countries — France, Italy, Spain, Portugal,
Argentina, Chile, New Zealand — 85 regions between them. Tapping a region opens
its detail map and routes to the catalog entries behind it. One test screen,
reachable from wherever you park experiments.

There is also a **Globe Scan prototype** in the drop. Do not wire it this batch.
`AUDIT.md` §5 says why, and the short version is that it has never run outside a
desktop browser.

## Start here

```
cd art/inbox/region-maps
for c in france italy spain portugal argentina chile newzealand; do
  python3 region_map.py $c && python3 region_check.py $c
done
```

Every one must print `PASS`. If any fails on a clean checkout, stop and say so —
that's a portability problem in the drop, not something to work around.

Then run the two catalog files you already made, which are the real acceptance
test:

```
python3 region_check.py france pins-france-catalog.json
python3 region_check.py italy  pins-italy-catalog.json
```

Both passed here (20/20 and 21/21) against the current build. **Your `make_pins.py`
premise correction was right and is now the assumed one** — `mapPosition` is a
fraction of a stylised outline and decodes to geography that drifts a median of
61 km, so the town coordinates you authored are the input, not the `regions.ts`
fractions. If you extend the same treatment to the other five countries, the
`pins-<country>.json` files in the drop are the shape to match.

## The five contracts

Break any of these and the failure is quiet. `AUDIT.md` §3 has the long form.

1. **Hit-test `<country>-index.png`. Never a pixel colour.** One byte per
   *logical* canvas cell — not per exported pixel. `0` = outside the country,
   `255` = inside but unassigned, `1..N` = a region, `regions[].id` in the
   manifest. The palette repeats across countries on purpose; ids are the
   contract. AUDIT §1.5 has the three separate ways colour-matching fails on iOS.
2. **Resolve a tap to the nearest region**, not only the cell under the finger.
   Seven of fourteen French regions are under Apple's 44pt minimum — Bordeaux at
   36pt — so buttons cannot be the tap target. Markers are markers.
3. **Never re-derive the projection.** The manifest's `projection` block is the
   single source of truth for lon/lat → canvas. If Swift recomputes it with its
   own constants the two drift and nothing says so.
4. **Compute nothing the manifest already computed.** Button positions are poles
   of inaccessibility, emitted as canvas fractions. 0.8.4 lost 6 of 121 authored
   dots to exactly this.
5. **Keep these files out of `outlines:check` and `icons:verify`.** If a gate
   starts walking them, move the files — don't add an exclusion. That's how
   `icons:verify`'s zero-pixel budget stops being honest.

## What not to touch

- `entries/countries/*.png` and their `mapPosition` dots. Unchanged. This is a
  second, richer view; it does not supersede the hand-drawn outline system.
- `shared/data/regions.ts` — read-only for this test. The region stems are art
  names by design and must never become ids.
- `entries.json` and the generated data layer. No drift.
- `outlines:check`, `icons:verify`, `find-missing-refs` — none of them should
  change.

Also: **these are not tile-grid sheets.** Don't send them through the sheet
slicer; they're 39 single assets plus the index rasters. The art carries the
usual magenta key `#EE03E1`, **except the backdrops, which are opaque by
design** — if the importer keys everything it touches, route those around it or
they come out full of holes.

## Done looks like

1. `region_check.py` passes for all seven countries and both catalog files.
2. Both map layers render at phone width, sized so `base.subject_rect` fills the
   width you want the country to have — **not** aspect-fit to the canvas, which
   shrinks France to 32% and takes every tap target with it.
3. Every tap inside a country resolves; every tap outside does nothing. Try the
   hard ones: Valle d'Aosta (66 px, smallest anywhere), Molise, Trentino against
   Alto Adige, Beaujolais, Chile's Maipo against Aconcagua, and the Bay of
   Biscay.
4. Tapping opens the right detail map and the catalog route lands on the right
   entry.
5. All existing gates still green, none of them changed.
6. Test count up, not sideways.

## Report back on

- Any pin that needed a config change, and which.
- Any region stem with no catalog ids behind it — that means the map has an area
  the catalog doesn't cover.
- **AUDIT §1.6**: the numbers you get on a device. Memory with seven index
  rasters resident, decode time at launch, whether the pixel art holds at 3× on a
  Retina panel. Nothing in this drop has run on a simulator.
- Whether the nearest-region hit test *feels* right in the hand, or merely works.
  That's the question this test exists to answer.

One correction for `PLAN.md` while you're in there: **France is 20 catalog
regions, not 19.**

---

*Drop built and audited upstream. 149 sample pins and 41 catalog rows green;
five defects found and fixed during the audit; two items left open and named in
`AUDIT.md` §1.6 and §1.7.*
