# The second index plane — agreed format

**Status: agreed by both sides. Nothing open.** Rev 2, 13 Sep 2026.

Rev 1 was the art session accepting the terminal's proposal with three additions
and one scope correction. Rev 2 folds in the terminal's replies: Châteauneuf
accepted (six children, not five), and the child-tap question answered — with a
better answer than the question assumed. See §2a, which rev 1 got half wrong.

---

## 1. Accepted as proposed

- `<country>-index2.png`, **optional per country**. Same dimensions and the same
  *logical* scale as `<country>-index.png` — one byte per logical cell, not per
  `export_scale` pixel.
- `0` = no child here. `1..M` = child index.
- A `children` block in the manifest: child index → stem, plus each child's
  parent stem.
- Hit test reads plane 2 first; non-zero wins, otherwise fall back to plane 1.
- Optional is the important part. No existing file changes, no migration, the
  six frozen countries stay byte-identical, and a country without children ships
  no second file and no `children` key.

I have nothing to add to any of that. It is the smallest change that does the
job, and "absent means empty" is the right default.

---

## 2. Three additions

### 2a. Where a child is drawn — three tiers, one drawing

**Rev 1 said "plane 2 is data only" and that was half right.** It is true of the
flat base map and false of the globe, and the difference is what settles the tap
question below.

| tier | what plane 2 does there | new art |
|---|---|---|
| flat base map (`<c>-regions.png`) | nothing — unchanged, and this is what keeps the frozen six byte-identical | none |
| globe region tier | `RegionAtlas.cutout(stem)` builds the raised shape straight from the raster; point it at plane 2 and the child's own outline rises out of the parent at radius × 1.022 | **none** |
| `RegionMapScreen` | the only screen that needs a picture of a child | **one drawing per child** |

Plane 2 needs no `export_scale` of its own: nothing composites it as art.

**The tap opens the child.** Terminal's ruling, and the principle is the one
already in `RegionMap.primaryEntryID` — answer the thing pointed at, not its
container or its contents. You pointed at Wachau.

The objection rev 1 was circling — plane 2 is invisible, so the base map shows
Niederösterreich and tapping it gives you Wachau, which is a surprise — does not
survive contact with how the globe actually draws. The raised cutout reads the
index raster directly, so switching it to plane 2 makes Wachau's own shape stand
up out of Niederösterreich and the tap explains itself. It costs the terminal a
plane switch instead of costing me a drawing.

So the one drawing I owe is for `RegionMapScreen`, and it is **the child inside
its parent's frame** — you want to see where Wachau sits in Niederösterreich,
which is exactly what the globe's raised cutout cannot show. Not a child on its
own, and not a re-cropped parent.

### 2b. Four invariants, asserted at render, not discovered on a device

1. **Containment.** Every non-zero cell of plane 2 lies inside its declared
   parent in plane 1. A child that leaks over a parent boundary is the exact bug
   nobody can see: the tap resolves, to the wrong thing.
2. **Same shape.** `index2.shape == index.shape`, asserted, because the two are
   read with the same coordinates.
3. **Namespace.** A child stem may not collide with any region stem in the same
   country. They share one `byId` map (see 2c), so a collision is silent.
4. **Non-empty.** Every declared child owns at least one cell. A child that
   renders to nothing is a config error, and the assert costs nothing.

Overlap between children needs no assert: one byte per cell makes it impossible.

Ceiling is 255 children per country, which is not close to binding — the largest
case on the board is one child.

### 2c. Children resolve through the existing `byId` map

`<country>-region-index.json` maps catalog id → stem. Child stems go in the same
map. No new file, no second lookup, and `region_check.py` gets the child answer
by reading plane 2 first — the same order the app does, which is the whole
discipline of that gate.

`byStem` gains the child stems as keys alongside the region stems. The parent
link stays in the manifest, where it belongs, because it is geometry rather than
catalog.

Note this makes `region_check.py` the thing that proves containment end to end:
R011 must come back `sauternes`, not `bordeaux`, from the shipped rasters.

---

## 3. The scope: six, agreed

Rev 1 argued the terminal's five should be six. **Accepted**, in its words:
*Vaucluse is the Southern Rhône, so handing it over would paint Gigondas,
Vacqueyras and Rasteau as Châteauneuf-du-Pape.*

| catalog | child | parent | why it is nesting, not siblings |
|---|---|---|---|
| R040 | Wachau | R062 Niederösterreich | a Weinbaugebiet inside the Bundesland |
| R011 | Sauternes | R001 Bordeaux | a commune group inside the Gironde |
| **R099** | **Châteauneuf-du-Pape** | **R004 Rhône Valley** | **a commune inside the Vaucluse** |
| R071 | Valpolicella | R023 Veneto | Verona province, inside the region |
| R073 | Etna | R024 Sicily | Catania province, inside the island |
| R074 | Collio | R026 Friuli-Venezia Giulia | Gorizia, inside the region |

Châteauneuf-du-Pape resolves to `rhone` today. It is one commune; there is no
admin-1 unit to give it and no cut of the Vaucluse that leaves the rest of the
Southern Rhône intact. Same shape as Sauternes exactly.

Everything else on the old §3.2 list is siblings and you were right about that.

### The sibling case, since it is the one costing you something now

`RegionMap.primaryEntryID` exists because SOUTH WEST FRANCE was answering with
Gaillac. That is four catalog rows on one painted region:

- R122 South West France, R079 Gaillac, R108 Cahors, R155 Jurançon → `southwest`

They are three separate départements — Tarn, Lot, Pyrénées-Atlantiques — so
**plane 1 handles it**: three new region stems, one département each, and
`southwest` keeps the residual. No second plane, no `primaryEntryID` call to
make. Same for R010 Chablis, which is the whole Yonne and currently painted as
`burgundy`.

I have not made either change. Both are ordinary `countries.py` edits and both
change `southwest` and `burgundy` art, so they want to ride with a batch and a
re-render rather than land on their own.

---

## 4. Order of work

Nothing is blocking on either side.

1. **Austria first** — one child, one parent, the smallest thing that proves the
   pipeline end to end. `at-index2.png`, a one-entry `children` block, Wachau's
   detail map drawn inside Niederösterreich's frame.
2. Terminal points `RegionAtlas.cutout` at plane 2 where one exists, and adds
   the plane-2-first order to the hit test.
3. `region_check.py` gains the same read order, and R040 must come back
   `wachau` from the shipped rasters — which is what proves containment.
4. Then France (Sauternes, Châteauneuf-du-Pape) and Italy (Etna, Valpolicella,
   Collio), in one batch each, since both re-render a country that is currently
   frozen.

Wachau stays unpainted until step 1 lands. A wrong boundary is worse than an
absent one, because nothing can detect it.
