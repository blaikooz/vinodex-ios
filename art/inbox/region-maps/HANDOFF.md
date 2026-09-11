# Wine region maps — implementation handoff

**Scope: this is a test.** Get the maps on screen in the simulator, get taps
routing to the right catalog regions, and find out whether the interaction is
worth keeping. It is **not** a shipping feature and it must not disturb anything
that currently ships. §7 lists what is off-limits.

**Seven countries.** One script, one config file, one gate:

| | regions | admin-1 units claimed | sample pins | config fixes needed |
|---|---:|---|---:|---|
| France | 14 | 47 of 96 départements | 38 | 2 |
| Italy | 21 | 110 of 110 provinces | 39 | 0 |
| Spain | 16 | 43 of 48 provinces | 25 | 0 |
| Portugal | 10 | 18 of 18 districts | 12 | 1 |
| Argentina | 6 | 10 of 23 provinces | 11 | 0 |
| Chile | 8 | 8 of 16 regions | 12 | 1 |
| New Zealand | 10 | 12 of 16 councils | 12 | 0 |

**149 pins, all green.** Adding an eighth country is a config block, not new code.

Design rationale lives in `horizon-md/france-map-plan.md`. **Read `AUDIT.md`
beside this file first** — it is the pre-handoff audit, it lists three things
that broke and were fixed, four that are still open, and the five contracts the
Swift side has to honour. §1.4 and §1.5 there change how you should wire the hit
test; do not start without them.

This document is the build instruction: where the files are, what to run, what to
wire, and what "it worked" means.

---

## 1. What's in the drop

Everything is in `art/inbox/region-maps/`. **This supersedes `art/inbox/france-map/`**,
which has been moved to `art/inbox/_superseded/` — delete it.

```
AUDIT.md                 PRE-HANDOFF AUDIT — read first
region_map.py            renders both layers, the detail maps and the manifest
region_check.py          the gate: reads the shipped PNG, resolves coordinates
countries.py             THE ONLY HAND-WRITTEN TABLE — which admin-1 units make
                         up which wine region, per country
palette.py               computes region fills from mask adjacency (§5)
globe_tex.py             builds the globe prototype's textures (§10)

fr-departements.json     96 metropolitan départements       (Natural Earth 10m)
it-provinces.json        110 Italian provinces, each carrying its region
es-provinces.json        50 Spanish provinces, ditto
pt-districts.json        18 Portuguese districts
ar-provinces.json        23 Argentine provinces
cl-regions.json          16 Chilean regions
nz-councils.json         16 New Zealand councils
world.json               108 countries, the backdrop for all of them

pins-<country>.json      known appellation coordinates per country, standing in
                         for the catalog until the real rows exist (§4)

globe-index.png          world index raster, 2048x1024, one byte per cell:
                         0 sea, 1 land, 2+ one of 30 wine countries
rgn-<country>.png        that country's regions, same idea, cropped to its bbox
globe-meta.json          country ids, fills, and each region raster's bounds

out/<country>/           pre-rendered, so you can look before running
  <c>-index.png          THE HIT TEST: one byte per logical cell, region id
  <c>-regions.png        INTERACTIVE layer: the country only, rest is chroma key
  <c>-backdrop.png       BACKDROP layer: sea, shelf, the rest of the world
  <c>-map-preview.png    the two composited — for eyeballing, not for shipping
  map-<stem>.png         one detail map per region (85 in all)
  <c>-manifest.json      computed button fractions, palette, projection
  <c>-region-index.json  catalog id -> region stem
```

**The base map is two layers on one canvas**, pixel-aligned by construction —
same projection, same origin, same scale — so the app draws the backdrop, then
the interactive layer straight on top, with no offset arithmetic of its own.

`out/` is build output, not art masters. `region_map.py` + `countries.py` are the
masters. Requires `python3` with `numpy`, `scipy`, `pillow`. No network, ever.

---

## 2. Run it once, unchanged

```
cd art/inbox/region-maps
for c in france italy spain portugal argentina chile newzealand; do
  python3 region_map.py $c && python3 region_check.py $c
done
```

Expected:

```
france: 14 regions from 47 of 96 admin-1 units
split beaujolais/rhone at 45.62N: 9 px -> rhone
base canvas 502x496 logical, exported 2510x2480
...
marker d= 8 -> 0 collisions []
PASS — all 38 pins resolved to a wine region.

italy: 21 regions from 110 of 110 admin-1 units
palette: 21 regions, 36 touching pairs, worst adjacent ΔE = 46.4
base canvas 463x502 logical, exported 2315x2510
...
PASS — all 39 pins resolved to a wine region.
```

If any of them fails on a clean checkout, stop and say so — that is a portability
problem in the drop, not something to work around.

---

## 3. How the countries differ, and why it matters

**France is an approximation. Italy is not.**

France's wine regions are built from départements, which are not AOC boundaries.
It cost two findings, both fixed in config: Côte-Rôtie resolving to Beaujolais
(the Rhône département holds both, so it is cut at 45.62 N), and Tavel coming out
Provence (boundary pixels were going to whichever region was drawn last; they now
go to whichever covers more of the pixel). 47 of 96 départements are claimed; the
other 49 are unassigned stone.

Italy needed neither. Its wine regions **are** its administrative regions, so all
110 provinces are claimed, there is no unassigned ground anywhere in the country,
and **all 39 sample coordinates resolved correctly on the first run with no config
fixes at all.** The only departure from the 20 administrative regions is the one
the wine world insists on: Trentino-Alto Adige is two DOC territories, so Trento
and Bozen are carved apart by province. That is what takes Italy to **21**, which
is the count PLAN.md gives for the catalog.

Because Italy's regions come from the provinces' own `region` column, its config
reads `{'region': 'Toscana'}` rather than ten province names. France's
départements carry no such column, so it lists units explicitly. Both forms work
and can be mixed — that is how Alto Adige is carved out.

**The other five, and what each one taught.**

*Spain* (25 pins, no fixes) sits between the two: provinces are finer than DOs, so
Rioja is La Rioja + Álava and Ribera del Duero is Burgos + Soria. Asturias,
Cantabria, Salamanca and Ávila stay unassigned. The Canaries, Ceuta and Melilla
are `exclude`d — one Atlantic island group stretches the bounding box far enough
that the mainland shrinks to nothing.

*Portugal* (12 pins, 1 fix) repeated France's lesson exactly: **Viseu district
holds the Douro's south bank AND the Dão**, so Pinhão came out Dão. Cut at
41.00 N. `dao` is now the first region in the set with **no units of its own** —
it exists entirely as the south half of that split, which the code supports.

*Argentina* (11 pins, no fixes) needed the other new option: framed on the whole
country, its wine provinces are a thin strip against an empty pampa, so it uses
`focus='regions'` — size the canvas on the claimed regions and let the rest of
the country run off the edge.

*Chile* (12 pins, 1 fix) needed both, and turned up a **data-quality problem
rather than a modelling one**: Natural Earth's Metropolitana polygon reaches to
71.46 W at Casablanca's latitude, roughly 25 km further west than the real
regional boundary, which put Casablanca in Maipo. Fixed with a split on a
meridian — the first one — so splits now cut on either axis. Chile also needed
`frame_window`, because Valparaíso Region includes **Easter Island**, 3,500 km
out in the Pacific, which on its own turned the country's frame from
tall-and-narrow into wide-and-empty.

*New Zealand* (12 pins, no fixes) is the cleanest fit after Italy — Marlborough,
Hawke's Bay, Gisborne and Central Otago are regional councils in their own right.
Eight outlying island groups are excluded, Tokelau above all: it sits at 172 W,
on the far side of the date line from the country it is filed under.

---

## 4. The one input this needs from the repo

**The per-country rows of `shared/data/regions.ts`** — PLAN.md's 0.8.3 entry puts
France at **19**, Italy at **21** and Spain at **19**. I can't see the file, so
the `pins-*.json` files stand in.

Emit the real ones in the same shape:

```json
[ {"id": "R122", "name": "South West France", "lon": 0.6, "lat": 44.0} ]
```

`mapPosition` is authored as a **fraction of the country outline's bounding box**,
not as lon/lat, so it has to be converted back first. Do the conversion in one
place and print the resulting lon/lat so it can be eyeballed against an atlas
before anything depends on it. A fraction that decodes to open water is the 0.8.4
failure mode; this check catches it, but only if the decode is right.

```
python3 region_check.py france pins.json
```

**Every row must resolve.** Three failure kinds:

| Report | Meaning | Fix |
|---|---|---|
| `OFF-MAP` | outside the canvas | the decode is wrong, or the region isn't in that country |
| `ON-STONE -> nearest X` | inside the country, unassigned unit | add that unit to a region in `countries.py` |
| `MISMATCH` | resolved to the wrong region | one unit holding two wine regions — add a `splits` line |

**Do not add an exception table.** An authored exception list does not survive a
re-render; a config line does. Re-run `region_map.py`, then the check again.

`<c>-region-index.json` is the artefact you actually want out of this: catalog id
→ region stem, generated, never hand-edited.

---

## 5. The palette is computed, not authored

Two requirements pull against each other. The runtime identifies a region by
reading the pixel under the tap, so **every fill must be exactly unique**. And a
person has to tell **adjacent** regions apart at a glance — which, at 21 regions
on one country, is the binding constraint, and is exactly the job that produced
two indistinguishable reds in the France pilot.

So `palette.py` builds a pool of well-separated colours, reads which regions touch
from the rendered masks, and permutes the assignment until the least-separated
pair of *touching* regions is as far apart as it can get. Regions that never touch
are free to look similar, which is what makes 21 workable. Italy lands at a worst
adjacent ΔE of **46.4** across its 36 touching pairs.

France's palette was hand-tuned and reviewed, so it is authored in `countries.py`
and passed through untouched; the other six are computed. All of them end up in
the manifest the same way — the app
should build its colour→stem table from `<c>-manifest.json` at load, never from
hexes hardcoded in Swift.

---

## 6. What to wire, minimally

One test screen, reachable from wherever you park experiments.

**6.1 Draw the two layers, sized by the country rather than the canvas.**

Backdrop, then interactive layer, same rect. Do **not** aspect-fit the canvas —
scale the pair so `base.subject_rect` (x, y, w, h as canvas fractions) fills the
width you want the country to have, and let the backdrop bleed off the screen
edges under a clip. That is the whole point of the margin: the country stays
exactly the size §6.2 measured, and the world is overspill rather than something
competing for the same screen.

`MARGIN` in the script sets how much world there is — 170 logical pixels a side,
reaching Iceland, the Azores, the Sahara and Ukraine. At the scale where a country
is legible, a literal whole globe would be ~19,000 × 14,000 px, which is not a
shippable asset; a true globe is a different zoom level, which the app already has
in globe scan.

**6.2 Hit-test the index raster by nearest region, not by button and not by
colour.**

This is the load-bearing decision, and it is a measurement:

| | pt per logical px | regions under Apple's 44pt minimum |
|---|---:|---|
| France | 2.13 | **7 of 14** — including Bordeaux at 36pt |
| Italy | 2.81 | **8 of 21** — Valle d'Aosta 20pt, Molise 28pt |

Italy fares slightly better per-pixel because it is narrower, and slightly worse
overall because it has half again as many regions in the same area. Every other
country lands in the same band. 44pt tap targets do not fit anywhere. So:

1. Convert the tap to canvas space with the same transform §6.1 drew with (the
   fitted rect, not the view rect — the arithmetic 0.8.4's `C4` needed).
2. Read `<c>-index.png` at that cell. It is at **logical** scale — one byte per
   canvas cell, not per exported pixel. `1..N` is a region; `regions[].id` in the
   manifest says which.
3. `0` means the tap was outside the country: sea, a neighbour, or the coastline
   ink, which is drawn one pixel outside the border. **No hit.** Do nothing.
4. `255` means inside the country but on unassigned ground: search outward for
   the nearest non-zero, non-255 cell and take that.

**Do not identify a region by its pixel colour.** AUDIT.md §1.5 has the three
separate ways that fails on iOS, none of which announces itself. The palette
repeats across countries on purpose and is safe to change; the ids are the
contract.

Step 4 is the design, not a fallback — no dead space inside the country, and a
small region's catchment is far larger than its footprint. It does nothing on
Italy, which has no unassigned ground; on France a tap in the Charentes goes to
Bordeaux, which is the right answer for a player who doesn't know why that part is
grey.

**6.3 Markers.** `regions[stem].button` is a canvas fraction — pole of
inaccessibility, computed, same convention as `mapPosition`. Draw at **8 logical
px**; the manifest's `marker_clearance` proves zero collisions at that size for
both countries and prints the proof on every render. They are markers only. They
do not need to be tappable, because 6.2 already handles the tap.

**6.4 Tapping opens the detail map.** `map-<stem>.png`, full width, with the
region's name. These are now cut from the **same masks the base map painted**
rather than re-rasterised from the unit lists — which fixed a real bug: a
re-rasterised detail map silently ignores every split, so France's Beaujolais and
Rhône detail maps were wrong until this changed. Appellation pins wait for §4.

**6.5 Route back to the catalog** via `<c>-region-index.json`: stem → catalog ids.
Several ids shows a list; one goes straight to the entry. A stem with **none**
should render as visibly inert rather than as a dead tap, and is worth reporting —
it means the map has an area the catalog doesn't cover.

---

## 7. What not to touch

- **`entries/countries/france.png`, `italy.png` and their `mapPosition` dots.**
  Unchanged. This is a second, richer view; it does not supersede the hand-drawn
  outline system 0.8.4 made the master.
- **`outlines:check`, `icons:verify`, `find-missing-refs`.** None of them should
  gain an exclusion, an exemption, or a new tree to walk because of this. If one
  starts seeing these files, move the files — adding exclusions to `icons:verify`
  is how its zero-pixel budget stops being honest.
- **`shared/data/regions.ts`.** Read-only for this test. The region stems are art
  names by design, and must never become ids.
- **`entries.json` / the generated data layer.** No drift. Nothing here reaches it.

**Import note:** these are not tile-grid sheets and must not go through the sheet
slicer — 39 single assets across the two countries. They carry the same magenta
key `#EE03E1` as every other sheet in `art/inbox/`, **except the backdrops, which
are opaque by design.** If the importer keys everything it touches, route the
backdrops around it or they will come out full of holes.

---

## 8. Acceptance

1. `region_check.py` passes on the real catalog rows for both countries.
2. Both base maps render at phone width and read clearly — every region
   distinguishable from the ones it touches, islands present, backdrop bleeding
   off the edges rather than boxed inside them.
3. Every tap inside the country resolves; every tap outside does nothing. Try the
   hard ones: Valle d'Aosta (66 px, the smallest anywhere), Molise, Trentino
   against Alto Adige, Beaujolais, Chile's Maipo against Aconcagua, and the Bay
   of Biscay.
4. Tapping opens the right detail map and the catalog route lands on the right
   entry.
5. `outlines:check`, `icons:verify`, `find-missing-refs` and the data-drift job
   all still green, none of them changed.
6. Test count up, not sideways.

Report back on: any pin that needed a config change and which; any region stem
with no catalog ids behind it; and whether the nearest-colour hit test feels right
in the hand or merely works. That last one is the question this test exists to
answer.

---

## 9. Known limits

- **Départements are not AOCs** (France only — see §3). Real INAO delimitations
  would close the last of it and are not worth a second data pipeline for a test.
- **Cognac is not on the France map.** Charentes is unassigned, so a Cognac
  coordinate resolves to Bordeaux via §6.2. If the catalog holds it, add
  `['Charente', 'Charente-Maritime']` as one more region.
- **Northern and Southern Rhône are one area**, as are Languedoc and its
  sub-appellations, and Italy's regions are not split into their DOCG zones.
  Splitting any of them is config, not code.
- **Islands under 20 logical px are not drawn** — Ré, Oléron, Noirmoutier, Elba,
  the Tuscan specks. Each was a dot of ink around a dot of land, which broke the
  coastline into beads. Corsica (205 px), Sardinia (423) and Sicily (423) are far
  clear of it. If a catalog coordinate lands on a dropped island the check reports
  it rather than mis-resolving it.
- **The backdrop is a wide window, not the globe.** See §6.1.
- **The globe prototype is a separate question.** §10 covers it; nothing in it
  blocks the flat maps.
- **Two map systems per country** is acceptable at test scale and a smell at
  seven. Worth a decision before this wires into the app for real.
- **Germany, Australia and the USA are not here on purpose.** Their admin-1 units
  are too coarse: Mosel, Rheingau and Pfalz all sit inside one German state, and
  Barossa and Coonawarra inside one Australian one. They would need a different
  boundary source, not a config block. The USA is the near miss — its wine
  entries are state-level already (california, oregon, washington, new-york in
  `art/flags/`), so it would work, just at a coarser grain than the rest.


---

## 10. The globe prototype

`globe_tex.py` builds three kinds of texture for the interactive globe that goes
with this drop. It is a *proposal to replace globe scan*, not part of the test
above — the flat maps do not depend on it.

**It renders by sampling, not by drawing.** `globe-index.png` is the world at
2048×1024 with one byte per cell — 0 sea, 1 land, 2 and up one of 30 wine
countries. Each frame un-projects every screen pixel back to a real lon/lat and
reads that byte. So a tap resolves the same way the flat maps resolve one, and
there are no polygons or hit boxes in the app at all.

**Tapping a mapped country drops to a second tier** which is the same globe
sampling `rgn-<country>.png` instead — that country's 6 to 21 regions, in the
same equirectangular space, cropped to its bounding box. Splits are applied when
the texture is built, so the region tier and the flat map agree by construction.

**Two things had to be solved to make it hold still.**

*Small islands shimmered.* At a 264-pixel globe, one screen pixel covers about
79 km, and point-sampling a 2048-wide raster either hits a speck or misses it as
the sphere turns — so specks blink. Two fixes, both cheap: components under 9
cells are dropped from the source raster (0.28% of all land, no country lost),
and the renderer keeps two half-size mips built by majority vote, picking the one
whose cell is closest to a screen pixel for the current zoom. Neither costs
anything per frame.

*Zoom had to add detail, not just make pixels bigger.* The logical canvas stays
264 px so the art stays chunky; zooming raises the globe's radius so the same
pixel budget covers less ground, and the sampler steps up a mip. 1×, 2×, 4×, 8×.

**Four screen modes** — DARK, LIGHT, AMBER, TERMINAL — are a pure colour function
over the class ids, because the hit test reads the raster and never the pixel.
Amber and Terminal collapse to a single hue the way a monochrome screen does,
which costs nothing but looks. The page opens in whichever of DARK or LIGHT
matches the viewer's system setting.
