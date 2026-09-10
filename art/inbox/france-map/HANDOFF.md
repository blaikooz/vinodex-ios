# France region map — implementation handoff

**Scope: this is a test.** Get the map on screen in the simulator, get taps
routing to the right catalog regions, and find out whether the interaction is
worth keeping. It is **not** a shipping feature and it must not disturb
anything that currently ships. §6 lists what is off-limits.

Design rationale lives in `horizon-md/france-map-plan.md`. This document is the
build instruction only — where the files are, what to run, what to wire, and
what "it worked" means.

---

## 1. What's in the drop

Everything is in `art/inbox/france-map/`.

```
france_map.py            renders both map layers, 14 detail maps, and the manifest
france_check.py          the gate: reads the shipped PNG, resolves coordinates
fr-departements.json     96 metropolitan départements, trimmed from Natural Earth
                         10m admin-1 (460KB). No network needed at any point.
neighbours.json          107 countries — the world as far as it reaches, same source, clipped
                         to a wide window around France (2.4MB)
pins-sample.json         38 known appellation coordinates, used to prove the
                         pipeline before the real data exists. Replace in step 3.
out/                     pre-rendered output, so you can look before running
  france-regions.png     the INTERACTIVE layer: France only, everything else the
                         chroma key. 2510x2480 (502x496 logical at 5x)
  france-backdrop.png    the BACKDROP layer: sea, continental shelf, and the
                         neighbouring countries. Same canvas, drawn underneath.
  france-map-preview.png the two composited — for eyeballing, not for shipping
  map-<stem>.png         14 detail maps, ~300px long axis
  france-manifest.json   computed button fractions, palette, projection, splits
  france-region-index.json  catalog id -> region stem
```

**The base map is two layers on one canvas.** They are pixel-aligned by
construction — same projection, same origin, same scale — so the app draws the
backdrop, then the interactive layer directly on top, with no offset arithmetic
of its own.

`out/` is committed so you can see the result without a Python environment. It
is regenerable and should be treated as build output, not as art masters —
`france_map.py` is the master.

Requires `python3` with `numpy`, `scipy`, `pillow`. Nothing else.

---

## 2. Run it once, unchanged

```
cd art/inbox/france-map
python3 france_map.py      # ~3s
python3 france_check.py    # ~1s
```

Expected tail of `france_map.py`:

```
split beaujolais/rhone at 45.62N: 9 px -> rhone
base canvas 502x496 logical, exported 2510x2480
...
marker d= 8 -> 0 collisions []
14 detail maps written
```

Expected tail of `france_check.py`: `PASS — all 38 pins resolved to a wine
region.`

If either fails on a clean checkout, stop and say so — that is a portability
problem in the drop, not something to work around.

---

## 3. The one input this needs from the repo

**The France rows of `shared/data/regions.ts`.** PLAN.md's 0.8.3 entry puts the
count at **19**. I can't see the file from here, so `pins-sample.json` stands in
for it with 38 well-known appellation coordinates.

Emit the real thing as `pins.json`, same shape:

```json
[ {"id": "R122", "name": "South West France", "lon": 0.6, "lat": 44.0} ]
```

`mapPosition` is authored as a **fraction of the France outline's bounding box**,
not as lon/lat — so it has to be converted back before it can be used here. Use
whatever `OutlineDotPlacer` uses for France's bbox; do the conversion in one
place and print the resulting lon/lat so it can be eyeballed against an atlas
before anything depends on it. A fraction that decodes to open water is the
0.8.4 failure mode and this check will catch it, but only if the decode is right.

Then:

```
python3 france_check.py pins.json
```

**Every one of the 19 must resolve.** Three failure kinds and what each means:

| Report | Meaning | Fix |
|---|---|---|
| `OFF-MAP` | coordinate outside the canvas | the decode in step 3 is wrong, or the region isn't in France |
| `ON-STONE -> nearest X` | inside France, unassigned département | add that département to a region's list in `france_map.py` |
| `MISMATCH` | resolved to the wrong region | usually one département holding two wine regions — add a `SPLITS` line |

**Do not add an exception table.** One misgrouping was already found and fixed
this way (Côte-Rôtie: the Rhône département holds Beaujolais in its north and
Ampuis in its south, so it is cut at 45.62 N). An authored exception list does
not survive a re-render; a config line does.

Re-run `france_map.py` after any config change, then `france_check.py` again.
`france-region-index.json` is the artefact you actually want out of this: catalog
id → region stem, generated, never hand-edited.

---

## 4. Getting the art in

**These are not tile-grid sheets and must not go through the sheet slicer.**
There are 15 single assets (1 base + 14 detail) plus whatever chrome you draw.
Pick an import path that treats them as whole images and keeps them **outside
the reach of `outlines:check` and `icons:verify`** — see §6.

They carry the same magenta key `#EE03E1` as every other sheet in `art/inbox/`,
so whatever keying step the existing importers use applies unchanged. The key is
exact, not approximate: no near-magenta cleanup pass is needed.

Suggested destination — your call, but the constraint is that no existing gate
should see them:

```
art/icons/maps/france/france-regions.png
art/icons/maps/france/france-backdrop.png
art/icons/maps/france/map-<stem>.png       x14
```

**The backdrop must not be keyed.** It is opaque by design — sea, shelf and
neighbouring land, no transparency anywhere. Only `france-regions.png` and the
detail maps carry the magenta key. If the importer keys everything it touches,
route the backdrop around it or it will come out full of holes.

If that folder is inside a tree either gate walks, put it somewhere else rather
than adding an exclusion to a gate. Adding exclusions to `icons:verify` is how
its zero-pixel budget stops being honest.

---

## 5. What to wire, minimally

The goal is a single test screen reachable from wherever you park experiments.

**5.1 Draw the two layers, sized by France rather than by the canvas.**

`france-backdrop.png`, then `france-regions.png` on top, same rect. Do **not**
aspect-fit the canvas — scale the pair so that `base.france_rect` (x, y, w, h as
fractions of the canvas) fills the width you want France to have, and let the
backdrop bleed off the screen edges under a clip.

That is the whole point of the margin: France stays exactly the size §5.2
measured, and the sea and neighbours are overspill rather than something
competing for the same screen. If you aspect-fit the whole canvas instead,
France shrinks to 32% of the canvas and every tap target in the table below
shrinks with it. `MARGIN` in the script controls how much world there is; it
defaults to 170 logical pixels a side, which reaches Iceland, the Azores, the
Sahara and Ukraine. It costs nothing at the France end — change it and every
number in the manifest follows.

**5.2 Hit-test by nearest region colour, not by button.**

This is the load-bearing decision and §5.2 of the plan has the measurement behind
it: at 340pt wide the map is 2.10 pt per logical pixel, and **seven of the
fourteen regions have a bounding box under Apple's 44pt minimum — Bordeaux among
them, at 38pt**. Fourteen 44pt tap targets do not fit on a phone-width France,
and France is nearly square so a taller phone buys nothing.

So:

1. Convert the tap point to canvas space using the same transform §5.1 used to
   draw (the fitted rect, not the view rect — the arithmetic 0.8.4's `C4` needed
   for the label well).
2. Sample **the interactive layer**. If the pixel matches a region fill in the
   manifest, that's the hit.
3. If it is `base.key` — the chroma magenta — the tap was outside France
   entirely: the sea, or a neighbouring country. **No hit.** Do nothing.
4. If it is stone or the coastline ink, the tap was inside France but on an
   unassigned département. Search outward for the nearest region pixel and take
   that.

Step 4 is not a fallback, it's the design: there is no dead space inside France,
and a small region's catchment is far larger than its footprint. A tap in the
Charentes goes to Bordeaux, which is the right answer for a player who doesn't
know why that part is grey.

Step 3 is what the backdrop buys beyond atmosphere: before it, everything outside
France was the same magenta as the unassigned interior, so a tap in the Atlantic
had to resolve to *something*. Now "outside France" is a thing the player can
see, so it can also be a thing that does nothing.

Build the colour→stem table from `france-manifest.json` at load; don't hardcode
hexes in Swift, or the palette has two definitions the first time it's tuned.

**5.3 Draw the markers.** `regions[stem].button` is a fraction of the base canvas
— pole of inaccessibility, computed, same convention as `mapPosition`. Draw at
**8 logical px** diameter; the manifest's `marker_clearance` proves zero
collisions at that size and prints the proof on every render. They are markers
only. They do not need to be tappable, because 5.2 already handles the tap.

**5.4 Tapping opens the detail map.** `map-<stem>.png`, full width, with the
region's name. Nothing else for the test — appellation pins are deferred until
step 3 has produced real coordinates.

**5.5 Route back to the catalog.** Use `france-region-index.json`: stem → the
catalog region ids in it. A stem with several ids shows a list; a stem with one
goes straight to the entry. A stem with **none** should render as visibly inert
rather than as a dead tap, and is worth reporting back — it means the map has an
area the catalog doesn't cover.

---

## 6. What not to touch

- **`entries/countries/france.png` and its `mapPosition` dots.** Unchanged. This
  feature is a second, richer view of one country; it does not supersede the
  hand-drawn outline system 0.8.4 made the master.
- **`outlines:check`, `icons:verify`, `find-missing-refs`.** None of them should
  gain an exclusion, an exemption, or a new tree to walk because of this. If one
  of them starts seeing these files, move the files.
- **`shared/data/regions.ts`.** Read-only for this test. The 14 stems are art
  names by design — §5.1 of the plan — and they must never become ids. If this
  test ever ships, that is still true.
- **`entries.json` / the generated data layer.** No drift. Nothing here reaches it.

---

## 7. Acceptance

The test has passed when all of these are true:

1. `france_check.py pins.json` returns PASS on all 19 real catalog regions.
2. The base map renders in the simulator at phone width and reads clearly —
   fourteen distinguishable areas, Corsica present, no colour pair ambiguous, and
   the backdrop bleeding off the edges rather than boxed inside them.
3. Every tap inside France resolves to a region; every tap outside it does
   nothing. Deliberately try the hard ones: Beaujolais (79 px, the smallest), the
   Languedoc/Roussillon pair (their markers are 8.2 logical px apart), the
   unassigned Charentes, and the Bay of Biscay.
4. Tapping opens the right detail map, and the catalog route from §5.5 lands on
   the right entry.
5. `outlines:check`, `icons:verify`, `find-missing-refs` and the data-drift job
   are all still green and none of them changed.
6. Test count went up, not sideways.

Report back on: any pin that needed a config change (and which), any region stem
with no catalog ids behind it, and whether the nearest-colour hit test feels
right in the hand or merely works. That last one is the actual question this test
exists to answer.

---

## 8. Known limits, stated so they aren't rediscovered

- **Départements are not AOCs.** They are the closest reproducible proxy. The
  error budget was measured, not assumed: 38 of 38 sample coordinates resolve
  correctly after two config fixes (the Rhône split, and boundary pixels being
  arbitrated by sub-pixel coverage rather than by iteration order — that one had
  put Tavel in Provence). Real INAO delimitations would close the remaining gap
  and are not worth a second data pipeline for a test.
- **Cognac is not on the map.** Charentes is unassigned, so a Cognac coordinate
  resolves to Bordeaux via §5.2. If the catalog holds Cognac, add
  `['Charente', 'Charente-Maritime']` as one more region and re-render.
- **Northern and Southern Rhône are one area,** as are Languedoc and its
  sub-appellations. Splitting them is a config change, not a code change.
- **Islands under 20 logical px are not drawn.** Ré, Oléron, Noirmoutier, Elba
  and the Tuscan specks. At this scale each was a dot of ink around a dot of
  land, which broke the coastline into beads. Corsica (205 px) and the Balearics
  (42 px) are well clear of the threshold. If a catalog coordinate ever lands on
  one of the dropped islands, `france_check.py` will report it as `ON-STONE` or
  `OFF-MAP` rather than silently mis-resolving it.
- **The backdrop is a wide window, not literally the whole globe.** At the scale
  where France is legible, a true world map would be **19,356 x 14,075 px** —
  not a shippable asset. The margin is as much world as fits sensibly; a genuine
  globe belongs at a different zoom level, which the app already has in globe
  scan.
- **No appellation pins yet.** Deferred until the real coordinates exist; the
  same projection in the manifest places them when they do.
- **Two map systems for one country** is acceptable at test scale and a smell at
  full scale. Worth a decision before Italy or Spain get the same treatment —
  both have the same admin-1 data and nothing here is France-specific except the
  contents of `REGIONS`.
