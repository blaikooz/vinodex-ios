# Interactive France wine map — full coverage

**Revision 2.** v1 was three pilot regions. This is the same plan grown to cover
every French region the catalog holds, which is what §8 of v1 deferred and what
this revision resolves. Two things changed shape in the process — the
naming problem dissolved, and the button problem turned out to be a *hit-test*
problem — so this is a rewrite rather than an amendment.

Everything below is written after the render, not before it. `france_full.py`
produces the attached art and `france-manifest.json` today.

---

## 1. What this is

A France map where each wine region is a distinct coloured area. Tapping a
region opens a larger detail map of it with its appellations as a second tier.

**It does not replace the existing country-outline system.** §4 explains why the
two coexist. `entries/countries/france.png` and its `mapPosition` dots are
untouched; the new base map is a separate asset under its own stem, so
`outlines:check` and `icons:verify` never see it.

---

## 2. Coverage — 14 areas

```
bordeaux     Gironde
southwest    Dordogne · Lot · Lot-et-Garonne · Tarn · Tarn-et-Garonne · Gers ·
             Landes · Pyrénées-Atlantiques · Hautes-Pyrénées · Aveyron ·
             Ariège · Haute-Garonne
loire        Loire-Atlantique · Maine-et-Loire · Indre-et-Loire · Loir-et-Cher ·
             Loiret · Cher · Nièvre · Indre
burgundy     Côte-d'Or · Saône-et-Loire · Yonne
beaujolais   Rhône, north of 45.62 N  (see §3)
champagne    Marne · Aube · Aisne · Haute-Marne
alsace       Bas-Rhin · Haute-Rhin
jura         Jura
savoie       Savoie · Haute-Savoie
rhone        Ardèche · Drôme · Vaucluse · Gard + Rhône south of 45.62 N
provence     Var · Bouches-du-Rhône · Alpes-de-Haute-Provence · Alpes-Maritimes
languedoc    Hérault · Aude
roussillon   Pyrénées-Orientales
corsica      Corse-du-Sud · Haute-Corse
```

47 of France's 96 metropolitan départements are claimed; the remaining 49 are
neutral stone. The script asserts no département is claimed twice, so the areas
cannot silently overlap. (Natural Earth resolves France to 101 admin-1 units —
96 metropolitan plus 5 overseas, which are filtered out.)

**Nièvre resolved.** v1 asked whether to keep it in Burgundy. It goes to the
**Loire** instead — Pouilly-sur-Loire is in the Nièvre — which is both more
accurate than dropping it and more accurate than leaving it in Burgundy.

**Deliberately absent:** Charentes (Cognac is brandy, not wine — add
`['Charente','Charente-Maritime']` as one config line if the catalog disagrees),
Bugey, Lorraine, Auvergne, Île-de-France. Northern and Southern Rhône are one
area, not two.

---

## 3. Départements are not AOCs — and where that actually bit

v1 stated the approximation. Revision 2 measured it: 39 real appellation
coordinates were projected and read off the rendered masks (`france_pins.py`).
**38 of 39 landed in the right area on the first run.** The one failure is worth
recording because it is the shape of every future one:

> **Côte-Rôtie resolved to `beaujolais`.** The Rhône *département* holds
> Beaujolais in its north and the head of the Northern Rhône — Ampuis,
> Côte-Rôtie — in its south. One administrative unit, two wine regions.

The fix is in the config, not in an exception list: the Rhône département is
**cut at 45.62 N**, where Beaujolais stops and the Côte-Rôtie escarpment starts.
North of the line is Beaujolais, south is Rhône. It is computed from the same
projection as everything else, so it survives a re-render — which an authored
exception table would not.

**A second one surfaced when the check was pointed at the shipped PNG** rather
than at the geometry it came from — which is exactly why the gate reads the file
the app opens. Each region is rasterised independently and max-pooled (so a
one-subpixel cape survives), which makes neighbours overlap by a pixel along
every shared border; the last region written then won, and **Tavel, which is in
the Gard, came out Provence.** Contested pixels are now arbitrated by sub-pixel
coverage — whichever region actually covers more of the pixel takes it — with
ties broken by declaration order, deterministically. All 38 sample coordinates
resolve correctly after that.

The remaining known gap: Cognac's coordinate lands on unassigned stone, which is
correct behaviour rather than a bug (see §5.2 for what happens to a tap there).

That is the whole error budget at this granularity. Sourcing real INAO
delimitations would close it and is still not worth it for this feature.

---

## 4. Why this doesn't disturb the existing map system

0.8.4 made the hand-drawn coastlines the master, pointed `outlines:check` at the
real art, and got 120/121 dots verified for the trouble. That system keeps
working untouched:

- `entries/countries/france.png` and its `mapPosition` dots: unchanged.
- The new base map is a **separate asset**, so no existing gate sees it.
- Reconciling the two is a later decision, not a v1 precondition.

The convention worth borrowing is positions-as-fractions-of-the-asset's-own-canvas.
§6 keeps it.

---

## 5. The two contracts that matter

### 5.1 Catalog regions are never named twice

This was v1's open question — "the map should key off `regions.ts` ids rather
than inventing parallel names" — and at 14 areas it stops being a question,
because the map does not need to know the catalog's names at all.

Every catalog region already carries a `mapPosition` as real lon/lat. Project it
with the same projection that renders the map, read the pixel, and **the mask
tells you which area it belongs to.** The 14 area names in §2 are *art stems*.
They never appear in `regions.ts`, they never need an id, and a region renamed
in the catalog changes nothing here.

This is what §3's 39-pin run was: the derivation, exercised end to end, against
the rendered art rather than against the geometry it came from — the same
discipline `outlines:check` earned in 0.8.4.

**The one thing needed from the app side** is the France rows of `regions.ts`
(id + `mapPosition`) so the derivation can be run against the real 19 rather
than my 39 stand-ins. That is a paste, not a data task.

### 5.2 The button is a marker; the map is the tap target

This is the finding that changed the plan, and it is a measurement.

The base map drawn 340pt wide is **2.10 pt per logical pixel**. Minimum side of
each region's bounding box, in points:

| region | pt | | region | pt |
|---|---:|---|---|---:|
| beaujolais | 23 | | languedoc | 44 |
| jura | 23 | | provence | 57 |
| roussillon | 23 | | rhone | 59 |
| corsica | 25 | | burgundy | 63 |
| alsace | 31 | | champagne | 67 |
| **bordeaux** | **38** | | loire | 69 |
| savoie | 38 | | southwest | 105 |

Seven of fourteen are under Apple's 44pt minimum — **including Bordeaux**, the
one region a player looks for first. And 44pt buttons at this scale need 21
logical px of separation; Beaujolais and Burgundy's computed positions are 3.6
apart. Fourteen 44pt tap targets do not fit on a phone-width France. France is
nearly square, so a taller phone buys almost nothing.

So do not try to make them fit. **Hit-test by nearest region mask**, sampling the
interactive layer. Any tap inside France resolves to the nearest coloured area;
any tap on the chroma key — the sea, or a neighbouring country — is no hit at
all. So:

- there is no dead space and no missed tap inside France;
- a small region's catchment is far larger than its footprint;
- unassigned stone still routes somewhere sensible — a tap in the Charentes goes
  to Bordeaux, which is the right answer for a player who doesn't know why that
  part is grey;
- and a tap in the Bay of Biscay does nothing, which it could not do before the
  backdrop gave the player something to see out there.

The drawn buttons then only have to be *visible*, not tappable. At **8 logical
px** diameter the fourteen computed positions have **zero collisions** — checked
in the script, printed on every run. Ten is fine too if Languedoc and Roussillon
are allowed to touch.

### 5.3 Both consequences of 5.1/5.2

- Region buttons are **not authored**. Each is the **pole of inaccessibility** of
  its own mask — the interior point furthest from any edge — computed by the
  script that renders the fill and emitted as a canvas fraction. The arithmetic
  centroid lands outside concave shapes; Gironde's estuary is exactly that notch.
- Appellation pins are authored **once as lon/lat** and converted by the same
  projection for both zoom levels. Author a fraction per level and you have two
  truths that disagree on the first re-render.

---

## 6. Art manifest

**19 sprites**, up from v1's seven.

### 6.1 Base map — 2 layers, one canvas

```
france-backdrop.png    2510 x 2480   sea, continental shelf, 107 countries
france-regions.png     2510 x 2480   France only, everything else the chroma key
```

Both are 502 x 496 logical at 5x. France occupies the middle 162 x 156 of that;
the other 170 logical pixels on each side are **backdrop margin** — the Atlantic
out to the Azores, Iceland and Scandinavia at the top, the Sahara at the bottom,
Ukraine at the right, and every coastline in between.

**How much world is possible, stated plainly.** At the scale where France is
legible, a literal whole-globe backdrop would be **19,356 x 14,075 pixels**. That
is not a shippable asset, so `MARGIN` buys as much world as fits: 170 a side is
2510 x 2480 and 60 KB, because flat colour with one-pixel lines compresses to
almost nothing. A true globe is a different zoom level — which the app already
has, in globe scan.

The margin moves the projection **origin** and leaves the **scale** alone, so
France is drawn at exactly the size it was before the backdrop existed and every
number in §5.2 still holds. `france_rect` in the manifest gives France's box as
canvas fractions; the app scales the pair so that rect fills the intended width
and lets the backdrop bleed off the screen edges. Aspect-fitting the whole canvas
instead would shrink France to 75% and take every tap target down with it.

France itself: metropolitan plus Corsica, 14 areas filled, remainder neutral
stone. Near-black cel outline on the national coastline only — **no internal
département lines**, which read as noise at this size. That outline is the
strongest line on the map, and with a backdrop underneath it is doing real work:
it is what makes France read as the subject rather than as one more country.

**The border is one clean line, and getting there took two rules.**

*Draw it 4-connected.* An 8-connected dilation is the obvious way to ring a mask
and it is wrong: at every diagonal staircase it paints both the pixel above and
the pixel beside, so the line comes out two and three pixels thick along any
coast that isn't axis-aligned. A cross kernel gives a line exactly one pixel
thick everywhere and still visually continuous, because the result is itself
8-connected. Measured: 846 ink pixels down to 615, and **zero 2×2 solid ink
blocks** — which is the actual test for "one pixel thick", not the eye.

*Drop the islets.* A 2-pixel island still gets a full border, so it renders as a
dot of ink around a dot of land — noise strung along a coast that is otherwise
clean. Land masses under 20 px go: Ré, Oléron and Noirmoutier off the Atlantic,
Elba and the Tuscan specks in the Med. Corsica is 205 px and the Balearics 42;
both stay.

**The backdrop earns something beyond atmosphere.** Before it, everything outside
France was the same magenta as the unassigned interior, so a tap in the Atlantic
had to resolve to *some* region. Now "outside France" is visible, so it can also
be inert — see §5.2.

```
sea              #38506B      foreign land       #8C8778
shallow shelf    #4E6985      foreign borders    #6B6759
```

Neighbours are dimmer and cooler than France's stone, and their borders are drawn
in a quiet grey rather than the near-black France gets, so the exterior reads as
context at a glance and as countries on a second look. The shelf is two pixels of
lighter blue hugging every coast — the way a printed atlas shades shallow water,
and enough at this size to stop the sea reading as flat backing paper.

**Palette.** Fourteen hues that survive being adjacent. v1's two-reds collision
is fixed; the constraint applied here is that no two *touching* areas share a
hue family, and value carries the pairs that do sit near each other (rhone /
provence, jura / savoie).

```
bordeaux    deep claret     #8E2F45      rhone       brick           #A8412C
southwest   wheat gold      #C9A24C      provence    terracotta rose #D98F7A
loire       sage green      #6E9464      languedoc   olive           #8C8F3E
burgundy    amber brown     #A6631F      roussillon  indigo          #5F5B8C
beaujolais  raspberry       #D0577A      corsica     forest green    #4E7A4A
champagne   pale straw      #E4D08A      unassigned  neutral stone   #CEC6BA
alsace      teal            #3E8C8A      outline     near-black      #1A1420
jura        lilac           #8A7BB0
savoie      ice blue        #7FA8C9
```

### 6.2 Region detail maps — 14

`map-<stem>.png` for each of the 14 stems, ~300px long axis. Same renderer, same
projection, one config line each — the region rendered alone at its own scale
with its own outline and fill.

### 6.3 Chrome — 3

```
map-button-idle.png    the region marker on the base map
map-button-held.png    pressed state
map-pin.png            an appellation pin for the detail maps
```

Check `art/icons/chrome/` before drawing — if a dot or pin already reads at this
size, reuse it rather than minting a third visual language for "a thing on a map".

---

## 7. Generated output

`france-manifest.json` ships beside the art. Generated, never hand-edited:

```json
{ "canvas": [162, 156],
  "regions": { "bordeaux": { "button": [0.3086, 0.6346],
                             "clearance_px": 6.7,
                             "departements": ["Gironde"],
                             "fill": "#8E2F45" }, ... } }
```

`clearance_px` is the pole's distance to the nearest edge — it is what tells you
whether a marker of a given size fits inside its own area, and it is why the
script can prove the zero-collision claim in §5.2 rather than assert it.

---

## 8. Build order

Steps 1–2 produce no art and are where the decisions live. 3–5 are script runs.

1. **Paste the France rows of `regions.ts`** (id + `mapPosition`). One paste.
2. **Run the derivation** against the real 19. Every region must resolve to an
   area; anything that lands on stone or in the wrong area is a §3-class finding
   and gets a config line, not an exception.
3. **Render the base map.** One asset, palette above.
4. **Render the 14 detail maps.** Same script, 14 configs.
5. **Emit the manifest.** Generated file.
6. **Draw or reuse the three chrome sprites.**
7. **Wire the gate** — assert every catalog region resolves to a non-stone area,
   read off the shipped PNG, failing both ways like `OFF_MAP`.
8. **Wire the interaction** — nearest-mask hit test, markers drawn at 8 logical px.

---

## 9. Deliberately deferred

- **Appellation pins.** v1 listed 19 for three regions. At 14 regions that is a
  hundred-odd coordinates and it should wait until §8 step 2 has run, because
  the same derivation decides where they live.
- **Other countries.** Italy and Spain have the same shape of problem and the
  same admin-1 data. Nothing here is France-specific except the config.
- **Reconciling with `mapPosition`.** Two map systems for one country was
  acceptable at pilot scale and is a smell at this one. Worth a decision before
  Italy gets the same treatment.
- **Zoom/pan.** Two fixed levels, not a continuous map.
- **INAO boundaries.** §3 costs one known misgrouping, already fixed. Not worth
  a second data pipeline.

---

## 10. Risks

| Risk | Why it bites | Mitigation |
|---|---|---|
| Départements ≠ AOCs | A player who knows the Rhône sees Côte-Rôtie in Beaujolais | §3 — measured, one found, fixed by config |
| Tap targets too small | 7 of 14 under 44pt, Bordeaux among them | §5.2 — hit-test by mask, not by button |
| Palette collision | Two reds already happened in v1 | §6.1 — no shared hue family between touching areas |
| Authored positions drift | 0.8.4 lost 6 of 121 dots to exactly this | §5.3 — computed poles, emitted as fractions |
| Parallel region names | Two naming systems for one country | §5.1 — the map has no names the catalog can disagree with |
| Not a tile-grid sheet | The slicer expects grids; these are 15 large single assets | Needs its own importer path or direct placement — flag before step 3 |

---

## 11. What I still need

1. **The France rows of `regions.ts`** — ids and `mapPosition` values, 19 of them.
   Everything in §8 after step 1 is a script run.
2. **Does the catalog hold Cognac?** If so, Charentes is one more config line.
3. **Chrome reuse** — is there an existing pin/dot sprite in `art/icons/chrome/`
   I should match instead of drawing a new one?
