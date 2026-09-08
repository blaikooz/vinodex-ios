# Interactive France wine map — conservative v1

A plan for the art and the contracts behind it. Three pilot regions, two zoom levels.
Written after a feasibility render, not before one — §2 is a picture of the real thing,
already produced.

---

## 1. What this is, and what it is not

**Is:** a France map where each wine region is a distinct coloured area, carrying a
button. Tapping the button opens a larger detail map of that region with its
appellations as a second tier of pins.

**Is not:** a replacement for the existing country-outline system. §3 explains why the
two coexist rather than one superseding the other.

**Pilot set — three regions:** Bordeaux, Burgundy, Champagne.
Chosen because they are the three a player looks for first, they sit far apart on the
map (so button collision is not yet a problem to solve), and their shapes are
unmistakable — if the geography is wrong, it will be obvious rather than subtle.

---

## 2. Feasibility is already established

The load-bearing assumption was that accurate French sub-national boundaries are
reachable. They are.

Natural Earth's `ne_10m_admin_1_states_provinces` resolves France to **101
départements**, not the 13 modern régions — which is exactly the granularity wine
regions are built from. All three pilots resolve on the first try:

```
Bordeaux    Gironde
Burgundy    Côte-d'Or, Saône-et-Loire, Yonne, Nièvre
Champagne   Marne, Aube, Aisne, Haute-Marne
```

`france_proof.py` renders the base map from this today: metropolitan France (overseas
départements filtered out), 120 logical pixels on the long axis, three regions filled,
Corsica present, coastline correct. **The proof render is attached to this plan.**

This is the same pipeline as the five country maps in `sheet-x1-body-regions.png`, one
level down. No new technique to invent.

### The approximation, stated plainly

**Départements are not AOC boundaries.** They are the closest reproducible proxy, and
the gap is visible in the proof: Burgundy includes **Nièvre**, which pushes the region
noticeably west of where the vineyards actually are.

Three ways to go, in increasing cost:

1. **Drop the loose départements.** Burgundy becomes Côte-d'Or + Saône-et-Loire + Yonne.
   Tighter and still one line of config. **Recommended for v1.**
2. **Accept it** and treat the map as administrative-adjacent rather than viticultural.
3. **Source real AOC delimitations** (INAO publishes them). Correct, heavy, and a
   different data pipeline. Not for a pilot.

Whichever you pick, it should be a recorded decision rather than a default, because
someone who knows Burgundy will notice.

---

## 3. Why this doesn't replace the existing map system

The app already has one: hand-drawn country outline masters, `mapPosition` dots
authored as fractions of each outline's own canvas, and `outlines:check` asserting every
dot lands on land. 0.8.4 made the hand-drawn coastlines the master and pointed the gate
at the real art. That is a working, gated system with 120/121 dots verified.

**This feature adds a second, richer view of one country. It must not disturb the
first.** Concretely:

- `entries/countries/france.png` and its `mapPosition` dots stay exactly as they are.
- The new base map is a **separate asset** under its own stem, so `outlines:check`,
  `icons:verify` and the existing France dots are untouched.
- If the two ever need to agree, that is a later reconciliation, not a v1 precondition.

The one thing worth borrowing is the **convention**: positions expressed as fractions of
the asset's own canvas. §5 keeps it.

---

## 4. Art manifest

Seven sprites. Deliberately small.

### 4.1 Base map — 1 sprite

```
france-regions.png      ~610 x 590    France, 3 regions filled, remainder neutral
```

Metropolitan France plus Corsica. Unassigned France in a neutral stone so the three
regions read as figure against ground. Near-black cel outline on the national coastline
only — **no internal département lines**, which would read as noise at this size.

**Palette — needs a fix before build.** The proof used a red for Bordeaux and a red for
Burgundy and they are nearly indistinguishable. Three regions need three clearly
separated hues:

```
bordeaux    deep claret      #8E2F45
burgundy    warm gold-brown  #A6631F
champagne   pale gold        #D6B24A
unassigned  neutral stone    #CEC6BA
outline     near-black       #1A1420
```

### 4.2 Region detail maps — 3 sprites

```
map-bordeaux.png        the Gironde, ~300px long axis
map-burgundy.png        the Bourgogne départements
map-champagne.png       the Champagne départements
```

Same renderer, same projection, region rendered alone at its own scale. Each carries its
own coastline/border outline and its region fill from the palette above.

### 4.3 Chrome — 3 sprites

```
map-button-idle.png     the region button that sits on the base map
map-button-held.png     pressed state
map-pin.png             an appellation pin for the detail maps
```

Check `art/icons/chrome/` before drawing these — if a pin or dot sprite already exists
that reads at this size, reuse it rather than minting a third visual language for "a
thing on a map".

---

## 5. The anchoring contract — the part that actually matters

Everything else here is art. This is the bit that rots if it's authored by hand.

### 5.1 Region buttons place themselves

A region button's position on the base map is **not authored**. It is the centroid of
that region's own mask, computed by the same script that renders the fill, and emitted
as a fraction of the base canvas.

Why: an authored fraction drifts the moment the base map is re-rendered at a different
size or the département grouping changes. A computed one cannot. This is 0.8.4's lesson
— six of 121 authored dots ended up in the sea when the coastline changed underneath
them — applied ahead of time instead of after.

Use the **pole of inaccessibility** (the interior point furthest from any edge), not the
arithmetic centroid. For a concave region the arithmetic centroid can land outside the
shape; Gironde's estuary is exactly the kind of notch that does it.

### 5.2 One projection, both zoom levels

Appellation pins are authored **once, as real lon/lat**, and converted to canvas
fractions by the same projection function that renders the maps.

That is what makes the two tiers consistent for free: the same authored coordinate
resolves correctly on the base map and on the detail map, because both derive from one
projection with one set of bounds. Author a fraction per zoom level instead and you have
two truths that will disagree the first time either map is re-rendered.

### 5.3 The gate

Port the spirit of `outlines:check`: **every pin must land inside its own region's
mask**, not merely inside France. Assert it against the rendered art, the way 0.8.4's
check reads the file the app opens rather than re-deriving the geometry. A pin that
drifts into a neighbouring département should fail the build, not ship.

---

## 6. Appellation pins for the pilot

19 pins, authored as lon/lat. A conservative, defensible set.

```
Bordeaux  (9)   Médoc · Margaux · Pauillac · Saint-Julien · Saint-Estèphe ·
                Pessac-Léognan · Saint-Émilion · Pomerol · Sauternes
Burgundy  (5)   Chablis · Côte de Nuits · Côte de Beaune · Côte Chalonnaise · Mâconnais
Champagne (5)   Montagne de Reims · Vallée de la Marne · Côte des Blancs ·
                Côte de Sézanne · Côte des Bar
```

**Open question for you:** do these need to be catalog entries, or are they map labels
only? If they must resolve to something tappable, they need ids in `regions.ts` (or
wherever appellations live) and that is a data task ahead of the art, not alongside it.
The plan assumes **labels only** for v1 — a pin shows a name, nothing routes.

---

## 7. Build order

Each step is independently checkable, and the first two produce no art.

1. **Settle the département grouping** — including the Nièvre decision from §2. Config
   only.
2. **Author the 19 lon/lat pins.** Data only. Verifiable by rendering them as dots over
   the proof map before any final art exists.
3. **Render the base map** at the corrected palette. One asset.
4. **Render the three detail maps.** Same script, three configs.
5. **Draw or reuse the three chrome sprites.**
6. **Emit the position manifest** — region button fractions and pin fractions, computed,
   as a generated file rather than a hand-edited one.
7. **Wire the gate** from §5.3.
8. **Wire the interaction.** Art and data are all in place before any Swift is written.

Steps 1–2 are where the decisions live. Steps 3–4 are a script run.

---

## 8. Deliberately deferred

Named so they are choices rather than oversights.

- **The other French regions.** Loire, Rhône, Alsace, Provence, Languedoc, Beaujolais,
  Jura, Savoie, Corsica, South-West. The renderer takes them as config lines when the
  pilot proves out.
- **Button collision.** The three pilots sit far apart. Loire and Burgundy do not, and
  neither do Languedoc and Provence — a full set needs a placement rule, not just
  centroids.
- **Other countries.** Italy and Spain have the same shape of problem and the same
  admin-1 data. Nothing here is France-specific except the config.
- **Reconciling with `mapPosition`.** Two map systems for one country is acceptable at
  pilot scale and a smell at full scale.
- **Zoom/pan.** v1 is two fixed zoom levels, not a continuous map.

---

## 9. Risks

| Risk | Why it bites | Mitigation |
|---|---|---|
| Départements ≠ AOCs | A player who knows Burgundy sees Nièvre and distrusts the whole map | §2, decided explicitly and recorded |
| Palette collision | Two reds already happened in the proof | §4.1 fixes it before build |
| Authored positions drift | 0.8.4 lost 6 of 121 dots to exactly this | §5.1 computes rather than authors |
| Two truths across zoom levels | Fractions authored per level disagree on re-render | §5.2 — one projection, lon/lat once |
| Pins imply navigation | 19 appellations that look tappable and aren't | §6 — settle labels-vs-entries first |
| These aren't tile-grid sheets | The slicer expects grids; these are large single assets | Needs its own importer path, or direct placement — flag before step 3 |

---

## 10. What I need from you

1. **Nièvre** — in or out of Burgundy? (Recommend out.)
2. **Appellation pins** — labels only, or must they resolve to catalog entries?
3. **The `regions.ts` France list** — I can't see it from the connected folders. If the
   pilot's three regions already have ids and prose, the map should key off those rather
   than inventing parallel names.
4. **Chrome reuse** — is there an existing pin/dot sprite in `art/icons/chrome/` I should
   be matching instead of drawing a new one?
