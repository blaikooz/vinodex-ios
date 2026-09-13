# Wine region maps — expansion prompt

**Hand this whole file to the session doing the work.** It is written to be
pasted, not summarised.

Everything below was measured against the repo at v0.9.56, not recalled. Where
a number appears, it came from a query; where a trap appears, it was paid for
once already.

> **Revision 3, 13 Sep 2026.** Revision 2 held up: nothing in it has been
> retracted. What changed is that four of its open items are now closed, and
> two of its numbers are now queries instead of claims.
>
> Closed since revision 2: **the globe is rebuilt** at the 34 §2 asked for — a
> first pass carried ten and six of them had no catalog entry; §2 has the
> derivation that was wrong and the assert that now prevents it. **Austria and
> China are built and installed** (§4).
> **The Natural Earth sources are in the repo**, so `globe_tex.py` and
> `extract_admin1.py` can actually run (§5.1). **The gate §5.4 asked for
> exists** — `coverage_check.py` (§5.4).
>
> New in this revision: §3.3, the second index plane, agreed on both sides and
> specified in `horizon-md/index2-agreed.md`; sommbot's corrections to seven
> of §6's staging entries; four traps in §8, three of them bugs found and fixed
> in the 13 Sep drop; and §12, which is the standing list of what is still owed.
>
> Every count in §3 now comes from `python3 coverage_check.py`. Do not quote a
> number here without re-running it — three of the four documents in this
> project contradicted the repo within a week of being written.

---

## 0. The ask

Seven countries have painted region maps. Extend the set — **at wine fidelity**.

Four rulings set the standard. They are not up for re-litigation inside the work:

1. **Hybrid source, by country.** Keep admin-1 where it genuinely *is* the wine
   geography — Italy's regions, China's provinces — and source real appellation
   boundaries where it is not. Both kinds of map ship side by side.
2. **One painted area per catalog region.** The map becomes a direct visual index
   of the encyclopedia. Today it is not: 25 painted areas have no entry behind
   them, and 15 catalog entries have no area of their own. §3.
3. **Official registers** where real boundaries are needed — INAO, TTB, the
   German states, SAWIS. Not scraped, not hand-drawn. §5.1.
4. **New countries first.** The seven already installed at 0.9.56 stay as they
   are for now; their 1:1 debt is recorded in §3.2 and paid later.

This is still **mostly config and data work**. The drop's handoff says *"adding
an eighth country is a config block, not new code"* and that stays true for every
country in the admin-1 column of §4. It stops being true the moment you need an
appellation polygon: that is a new source type and it needs `region_map.py` to
learn one new thing. Do not sprawl beyond that.

---

## 1. Read these first, in this order

| File | Why |
|---|---|
| `art/inbox/region-maps/AUDIT.md` | The pre-handoff audit, revision 2. §3 lists five contracts; §1.5 is why the hit test reads an index raster and not a colour. |
| `art/inbox/region-maps/HANDOFF.md` | The build instruction. §2 runs it, §3 is how the countries differ, §4 is the pins, §5 is why the palette is computed. |
| `horizon-md/france-map-plan.md` | Design rationale, revision 2 (full coverage). §3 is honest about the approximation this revision is now walking back. |
| `horizon-md/spaced-repetition-plan.md` | Not about maps — but §7 explains why content ranks above surface, which applies here too. See §9. |

---

## 2. State of play

**Painted today (9):** France 14 regions, Italy 21, Spain 16, Portugal 10,
Argentina 6, Chile 8, New Zealand 10, **Austria 3, China 4**. 92 areas. The
first seven were installed at 0.9.56; Austria and China are rendered, gated and
in `art/inbox/region-maps/out/`, awaiting the coupled Swift commit (§8).

**~~Four catalog wine countries are not on the globe at all.~~ Done.** Moldova,
Armenia, Cyprus and Turkey shipped in the 13 Sep drop. The globe carries **34**.

A first pass carried ten and it was wrong, in a way worth writing down because
the same shortcut is available on every future country decision. The gap was
derived from `art/icons/entries/countries/*.png` (51 stems) minus the globe's
table — but **the art is not the catalog**. Outlines exist for countries the
catalog does not carry, and six of the ten — bosnia, czechia, israel, serbia,
slovakia, ukraine — are in neither `regions.ts` nor `countries.ts`. Landing them
would have made six countries tappable that open nothing:
`GlobeIndexTests.everyCountryResolves` exists for exactly that, after the USA
shipped an empty country page for all of 0.9.55.

**The rule, now enforced rather than remembered:** the globe's country set equals
the set of `origin` values in `shared/data/regions.ts`. `catalog.py` reads it
(read-only; never imported into `shared/`) and `globe_tex.py` asserts against it
before painting. Put a country on the globe that has no entry and the build stops
and names it.

*The catalog leads and the map follows.* Same ruling that puts the 25 dead stems
ahead of new countries (§3.1, §9).

Two Natural Earth spellings are recorded in `globe_tex.py` for when the six do
land: Serbia is **"Republic of Serbia"**, Bosnia is **"Bosnia and
Herzegovina"**. Both would fail the `ADMIN` join. The display-name correction
belongs beside the USA one in `GlobeIndex.catalogName`.

**Eleven stems admin-0 cannot give you at all** — arizona, california, idaho,
michigan, missouri, new-mexico, new-york, oregon, texas, virginia, washington.
They are US states; on the globe they are all `usa`. Separating them is the
admin-1 plane, not another `WINE` entry, and it is the same question as §4.1.

**The globe carries 34 wine countries; 25 of them have no region map.**

---

## 3. The two gaps — now a query, not a count

Ruling 2 says one painted area per catalog region. Neither side of that holds
today, and the two gaps have opposite causes.

**Run it, do not read it:**

```
$ python3 coverage_check.py
...
92 painted areas: 25 dead, 15 catalog rows without an area of their own
```

`coverage_check.py` shipped 13 Sep and is the gate §5.4 asked for. It reads the
`out/<c>/<c>-region-index.json` files — the same artefact the app reads — so it
asks the app's question and needs no access to `shared/`. It is **not fatal by
default**; every number below is known debt with a plan attached, and a gate that
is red on arrival gets switched off. Turn on `--strict` in CI once the debt is
paid, so a twenty-sixth cannot appear unnoticed.

The tables below are its output on 13 Sep 2026, reproduced for reading. They
match revision 2's hand-counted figures exactly, which is the last time either
number should be a claim in a document.

### 3.1 Twenty-five painted areas with no entry behind them

| Country | Dead stems | Which |
|---|---:|---|
| New Zealand | 7 | northland, auckland, waikatobop, gisborne, wairarapa, nelson, canterbury |
| Chile | 5 | coquimbo, rapel, maule, biobio, malleco |
| Spain | 4 | aragon, madrid, andalucia, extremadura |
| Argentina | 3 | sanjuan, catamarca, cordoba |
| Italy | 3 | valledaosta, liguria, molise |
| Portugal | 3 | beirainterior, setubal, algarve |
| France, Austria, China | 0 | — |

Tap one today and you get "NO CATALOG ENTRY HERE YET" — honest, but a dead end on
art already paid for and already on screen.

**Three more areas are excluded by design and are not in this count**: the
Canaries, Madeira and the Azores, dropped by `exclude` because they blow up their
country's bounding box (§8). They are wine regions and they are not on any map.
Say so when someone asks why Spain stops at Cádiz.

**Every one of the 25 is a real, named appellation.** None is an artefact of the
grouping. So the fix is to write the entries, not to delete the areas. §6 lists
them, ready to stage.

### 3.2 Fifteen catalog entries with no area of their own

The reverse, and the more interesting one:

| Country | Painted area | Catalog rows sharing it |
|---|---|---|
| France | bordeaux | R001 Bordeaux, **R011 Sauternes** |
| France | burgundy | R002 Burgundy, **R010 Chablis** |
| France | rhone | R004 Rhône Valley, **R099 Châteauneuf-du-Pape** |
| France | southwest | R122 South West France, **R079 Gaillac, R108 Cahors, R155 Jurançon** |
| Italy | friuli | R026 Friuli-Venezia Giulia, **R074 Collio** |
| Italy | sicily | R024 Sicily, **R073 Etna** |
| Italy | veneto | R023 Veneto, **R071 Valpolicella** |
| Spain | catalonia | R032 Priorat, **R102 Penedès, R104 Conca de Barberà** |
| Spain | galicia | R033 Rías Baixas, **R088 Valdeorras, R116 Ribeira Sacra, R119 Ribeiro** |
| Spain | ruedatoro | R034 Rueda, **R113 Toro** |

**This is the whole fidelity argument in one table.** Sauternes is not a
département. Etna is not a province. Every bolded row is a sub-appellation that
the administrative grouping cannot express, which is precisely why ruling 1 and
ruling 2 are the same ruling: you cannot do 1:1 on admin-1 alone.

But most of it is cheaper than it looks. **Eleven of the fifteen close by going
one admin level finer** — not by changing source:

```
Chablis        Yonne (whole département; burgundy keeps Côte-d'Or + Saône-et-Loire)
Gaillac        Tarn
Cahors         Lot
Jurançon       Pyrénées-Atlantiques
Collio         Gorizia province
Etna           Catania province
Valpolicella   Verona province
Priorat        Tarragona
Penedès        Barcelona
Rueda          Valladolid
Toro           Zamora
```

**Four genuinely need appellation polygons**, because a finer admin unit either
does not isolate them or is already claimed by a sibling:

```
Sauternes           a sub-AOC inside the Gironde — no admin unit isolates it
Conca de Barberà    also Tarragona; collides with Priorat
Valdeorras          also Ourense; collides with Ribeiro
Ribeira Sacra       spans Lugo and Ourense; collides with both
```

~~Châteauneuf-du-Pape is the borderline case: giving it Vaucluse and leaving the
Rhône with Ardèche, Drôme and Gard is crude but expressible.~~ **Withdrawn.** It
is one commune, and Vaucluse *is* the Southern Rhône — handing the whole
département over would paint Gigondas, Vacqueyras, Rasteau and the Côtes du Rhône
Villages as "Châteauneuf-du-Pape", which is a worse answer than the one it
replaces. It belongs with Sauternes in §3.3.

Under ruling 4 none of this is your first batch — it is France, Italy and Spain,
all already installed. Record it, do not start it.

### 3.3 The second index plane — for the six that cannot be siblings

**Agreed on both sides, rev 2, specified in `horizon-md/index2-agreed.md`.** Read
that before painting anything against it; the summary here is orientation only.

`<country>-index2.png`, **optional per country**, same dimensions and same
logical scale as the base index. `0` = no child, `1..M` = child index. A
`children` block in the manifest gives child index → stem and each child's
parent. The hit test reads plane 2 first; non-zero wins, else it falls back to
plane 1. Nothing existing changes and no country is migrated.

**Most of §3.2 does not need it.** Chablis taking Yonne while Burgundy keeps
Côte-d'Or and Saône-et-Loire makes them *siblings*, and one plane handles
siblings. The same is true of Gaillac / Cahors / Jurançon against South West
France — three separate départements — which is the case
`RegionMap.primaryEntryID` was added to paper over.

**Six genuinely nest.** Queried against `regions.ts`, not recalled:

| catalog | child | parent | why |
|---|---|---|---|
| R040 | Wachau | Niederösterreich | Weinbaugebiet inside the Bundesland |
| R011 | Sauternes | Bordeaux | commune group inside the Gironde |
| R099 | Châteauneuf-du-Pape | Rhône Valley | one commune inside the Vaucluse |
| R071 | Valpolicella | Veneto | Verona province |
| R073 | Etna | Sicily | Catania province |
| R074 | Collio | Friuli-Venezia Giulia | Gorizia |

**A tap on a child opens the child** — the principle already in
`RegionMap.primaryEntryID`: answer the thing pointed at, not its container. The
apparent problem, that plane 2 is invisible so the base map shows the parent,
does not arise on the globe: `RegionAtlas.cutout` builds the raised shape
straight from the raster, so pointing it at plane 2 lifts the child's own outline
out of the parent and the tap explains itself. **No new globe art.** The one
drawing per child is for `RegionMapScreen`, and it is the child *inside its
parent's frame* — the view the raised cutout cannot give you.

**Wachau is deliberately unpainted until the plane exists.** The terminal's
ruling, and it is the right one: *a wrong boundary is worse than an absent one,
because nothing can detect it.*

Austria goes first when the plane lands — one child, one parent, the smallest
thing that proves the pipeline — before France or Italy.

---

## 4. Priority, corrected

Revision 1 ranked by catalog region count alone, which is the right *value*
measure and says nothing about whether a country can be built. Both columns
matter. Buildability below was checked against Natural Earth 10m admin-1 —
counts and unit names verified, not assumed.

| Country | Regions | Admin-1 fit | Verdict |
|---|---:|---|---|
| USA | 9 | 51 states present | **Decide first** — §4.1. Highest value; the answer depends on what the nine rows actually are. |
| China | 4 | Ningxia, Shandong, Xinjiang, Hebei are all provinces | **BUILT.** 4 regions, 4 pins, PASS. One approximation, stated in the config: Shangri-La is Diqing prefecture and the map paints all of Yunnan, so a tap on Honghe answers "Shangri-La". |
| Austria | 4 | 9 states | **BUILT — 3 of 4.** Burgenland, Niederösterreich and Steiermark are exact 1:1 units. Wachau is left unpainted on purpose; it needs the second plane (§3.3), not a split. Best fit on the board. |
| Greece | 6 | 14 *peripheries* only | **Next.** Needs one split. See below — revision 1's example config was wrong, and it also omits Dytiki Ellada, which is where Patras is. |
| Germany | 5 | 16 states | **Out of the priority column entirely.** Not "blocked pending a split" — three of the catalog's five German regions (Mosel, Rheinhessen, Pfalz) are in Rheinland-Pfalz, a two-cut proposal was measured and bisects the Nahe and paints the Ahr as "Mosel", and Germany needs Landkreise or real polygons before it is worth a line here. The catalog carries **five** German regions, not thirteen. |
| South Africa | 4 | 9 provinces | **Blocked on source.** Stellenbosch, Paarl, Swartland, Walker Bay and Constantia are all inside Western Cape. |
| Australia, Hungary, Georgia, Croatia, Romania | 3 each | Georgia's Kakheti and Croatia's Istarska are units | Marginal on count. Map only if the catalog grows first. |
| Japan, India, Canada, Switzerland, Uruguay, Morocco, Mexico, Brazil, Bulgaria, Lebanon, Slovenia, UK | 2 each | — | **Not yet.** A two-colour map is not a map. |
| Moldova, Armenia, Cyprus, Turkey | 2 each | — | Blocked — not on the globe (§2). |

**Three corrections to revision 1, each of which would have cost the executing
session real time:**

- **Revision 1's Greece example does not run.** It uses `['Korinthia']` and
  `['Imathia']`, which are NUTS-3 regional units. Natural Earth 10m gives Greece
  **14 admin-1 features** — the 13 peripheries plus Mount Athos — and
  `region_map.py`'s first assert fails with "no such admin-1 unit". Build Greek
  regions from peripheries (`Peloponnisos`, `Kentriki Makedonia`, `Notio Aigaio`,
  `Kriti`, `Thessalia`…), and expect at least one `splits` line, because Nemea
  and Mantinia both fall in Peloponnisos.
- **"Germany — Anbaugebiete map cleanly onto admin-1" is wrong.** Four of the
  five sit inside a single state. `splits` cuts one parallel or meridian per
  line and cannot carve four regions out of one unit. Germany needs a real
  boundary source or it does not get a map.
- **South Africa is worse, and revision 1 said "Map it."** Four catalog regions,
  one admin-1 unit. Not buildable from admin-1 at all.
- **China's caveat was backwards.** Revision 1 said "confirm the four are real
  wine districts and not provinces." Being provinces is exactly what makes China
  work; it is the one country in the list that needs no split and no new source.

### 4.1 The USA is a different problem, and should be decided before it is started

Nine catalog regions, more than any unmapped country. Under ruling 2 the question
resolves itself into a factual one: **read the nine rows in `regions.ts` and see
what they are.**

- **If they are states** — California, Oregon, Washington, New York — build them
  from admin-1 today. Truthful, cheap, consistent, done in an hour.
- **If they are AVAs** — Napa Valley, Sonoma, Willamette, Columbia Valley, Finger
  Lakes — then ruling 2 requires AVA polygons and the USA joins Germany and South
  Africa in the source column. TTB publishes AVA boundaries and they are US
  Government work, so licensing is the easy part; the geometry pipeline is not.

Do not half-build it. If the rows are AVAs, the USA waits for the source work and
China goes first.

---

## 5. The recipe, per country

### 5.1 Choose the source — the decision that comes before everything else

Ask one question of each catalog region: **is there an admin-1 unit, or a small
group of them, that this wine region actually is?**

- **Yes → admin-1.** Natural Earth 1:10m, admin-1, **public domain**, no
  attribution required though the project credits it anyway.

  **The source itself is now in the repo** (13 Sep): `ne-admin1.json.gz` (4596
  units, 9.7 MB) and `ne.json.gz` (258 countries, 4.3 MB), properties trimmed to
  what the pipeline reads, **no coordinate rounded** — the frozen countries have
  to re-render byte-identical and a moved vertex can flip a boundary cell.
  `geosrc.py` opens either the plain or the gzipped spelling.

  So producing a new country's extract is now one command:

  ```
  python3 extract_admin1.py "New Zealand" nz-councils.json --list   # see the names
  python3 extract_admin1.py Austria at-states.json                  # write the file
  python3 verify_extracts.py                                        # 9 of 9 reproduce
  ```

  Nine extracts exist (`fr-departements`, `it-provinces`, `es-provinces`,
  `pt-districts`, `ar-provinces`, `cl-regions`, `nz-councils`, `at-states`,
  `cn-provinces`) plus `world.json`. `verify_extracts.py` regenerates each from
  source and compares bytes, so a hand-edited extract cannot survive. Produce new
  ones with the tool, in the same shape, and add the country to
  `verify_extracts.ADMIN`.

  **Never hand-cut an extract.** `fr-departements.json` was cut down to
  metropolitan-only before the tool existed, and the five overseas départements
  it dropped would have reframed France from the Channel to Réunion the first
  time anyone regenerated it, with no assert firing. Units the map should not be
  framed by go in the config's `exclude`, where the pipeline can see the
  decision. §8. Check whether the source carries a `region` column — Italy's
  provinces do, which is why Italy is expressed as `{'region': 'Toscana'}`;
  France's départements do not, so France names units explicitly. Both forms are
  legal and mixable.
- **Nearly → admin-1 plus a `splits` line.** One unit holding two wine regions is
  the case `splits` exists for. France's is
  `('beaujolais', 'rhone', 45.62)` — the Rhône département holds Beaujolais in
  its north and the head of the Northern Rhône in its south, cut where Beaujolais
  stops. Reproducible, and it survives a re-render. Chile's is a meridian.
- **No → an official register.** Leads below. **None of these has been fetched or
  licence-checked by anyone yet** — treat each as a starting point that needs its
  own diligence, and record what you find so the next country does not repeat it.

| Need | Likely source | What to verify |
|---|---|---|
| French AOC delimitations | INAO, published via data.gouv.fr | Licence Ouverte terms; parcel-level vs *aire géographique* — you want the latter |
| US AVAs | TTB | US Government work, so likely public domain; confirm the digital boundaries, not just the eCFR prose |
| German Anbaugebiete | the wine-growing states' geodata portals (Rheinland-Pfalz, Hessen, Baden-Württemberg, Bayern) | Availability varies by state; licence varies by state |
| South African Wine of Origin | SAWIS / WOSA | Whether GIS boundaries are published at all, or only cartographic maps |
| Spanish DO | Ministerio de Agricultura | Coverage of the four in §3.2 |

**A boundary source that cannot be cited is not a source.** If a country's
geometry cannot be traced to a register, it does not get a real-boundary map —
it gets an admin-1 approximation with the approximation stated, or it waits.

### 5.2 Write the config block

In `countries.py`, beside the existing seven. Greece, corrected:

```python
GREECE = dict(
    admin1='gr-peripheries.json',
    subject='Greece',          # excluded from the world backdrop
    log=160, margin=170,
    splits=[('nemea', 'mantinia', 37.62)],   # both fall in Peloponnisos
    regions={
        'macedonia':  ['Kentriki Makedonia', 'Dytiki Makedonia'],
        'nemea':      ['Peloponnisos'],
        'mantinia':   [],            # entirely the south half of the split
        'santorini':  ['Notio Aigaio'],
        'crete':      ['Kriti'],
        ...
    },
)
```

Two things that block sessions if they are not said: a region may have **no units
of its own** and exist entirely as the product of a split — Portugal's `dao` does
— and the split cut value is a real parallel or meridian, chosen where the wine
regions actually divide, not a canvas coordinate.

**Do not author `fills`.** The palette is computed: `palette.py` reads which
regions actually touch from the rendered masks and permutes the assignment so the
least-separated *adjacent* pair is as far apart as possible. France's palette is
hand-tuned and passed through untouched for historical reasons; the other eight
are computed and yours should be too. Italy lands at a worst adjacent ΔE of 51.0
across its touching pairs — that is the bar. Austria is 71.8, Argentina 103.2.

Two things about `palette.py` worth knowing before you trust a number it prints:

- **The pool has four value bands, not three.** Three gave a hard ceiling of 21,
  which Italy hits exactly. And `pool()` used to return the first *n* colours,
  so a three-region country got three colours from one band — Austria's first
  render was three browns at ΔE 24.1. `assign()` now picks *which* colours, not
  only their arrangement.
- **Measure in the space the colour is seen in.** The country fills on the globe
  are optimised *after* `install_globe.py`'s brighten, because that transform
  clips and a pair 15 apart in the manifest can arrive 2 apart on glass. See §8.

### 5.3 Author the pins

`pins-<country>.json`, **one row per catalog region** — which under ruling 2 is
also one row per painted area:

```json
[ {"id": "R122", "name": "South West France", "lon": 0.6, "lat": 44.0} ]
```

**Author these from the towns each appellation is named for.** Do **not** decode
them from `mapPosition` in `regions.ts`. That field is a fraction of the country
outline's bounding box authored for dot placement and snapped to land; it drifts
a median 61 km and a worst 134 km, and decoding it put Alsace in Champagne and
Jurançon in Spain. `outlines:check` independently flags Jurançon as off the
France silhouette, which corroborates it.

The pins are a **test fixture, not catalog data**. They must not be imported into
`shared/`.

### 5.4 Render and gate

```bash
cd art/inbox/region-maps
python3 region_map.py greece && python3 region_check.py greece
```

**Every pin must resolve.** Three failure kinds and their only correct fixes:

| Report | Meaning | Fix |
|---|---|---|
| `OFF-MAP` | outside the canvas | the coordinate is wrong, or the region is not in that country |
| `ON-STONE -> nearest X` | inside the country, on an unassigned unit | add that unit to a region in `countries.py` |
| `MISMATCH` | resolved to the wrong region | one unit holding two wine regions — add a `splits` line |

**Do not add an exception table.** An authored exception list does not survive a
re-render; a config line does.

**~~Add one gate this drop does not have.~~ It exists:** `coverage_check.py`,
shipped 13 Sep. It asserts every painted stem has at least one catalog id behind
it, reports both directions of the gap, and takes `--strict` to exit 1. Run it
after adding a country. Nothing else stops the next country shipping with dead
areas — which is how the 25 in §3.1 accumulated.

The artefact you actually want is `<c>-region-index.json` — catalog id → region
stem, generated, never hand-edited.

**Two pin files, and only one of them may write that artefact.** The seven older
countries carry `pins-<c>.json` (dense, name-only, better coverage for the check)
*and* `pins-<c>-catalog.json` (the real `regions.ts` rows, with ids). Austria and
China have one file that is both. `region_check.py` writes the region index from
whichever pins carry ids, and a run whose pins have none writes nothing and says
so. Before 13 Sep it fell back to the pin *name*, so the documented invocation
`python3 region_check.py france` silently replaced `R001 → bordeaux` with
`Medoc → bordeaux` and still printed PASS. §8.

### 5.5 Install

```bash
python3 install_art.py greece
```

Keys the exact chroma magenta to transparent on the interactive layer, copies the
backdrop and the index raster **verbatim** (they are data, not art), and clears
stale files from a previous render.

---

## 6. Catalog entries to stage — hand this section to the deploybot

The 25 from §3.1. Every one is a real appellation with a named authority; none is
an artefact of the grouping. Each needs a `regions.ts` row so the painted area
stops being a dead end. Written as a staging list, not as prose.

> **Seven of the 25 were corrected by sommbot after revision 2 went out.** The
> corrections are folded in below and marked **(sommbot)**. They are not
> stylistic: three of them name appellations the original line omitted, and two
> conflate registered GIs that are not one thing.

**Italy (3)**
- `valledaosta` — Valle d'Aosta DOC
- `liguria` — Liguria: Riviera Ligure di Ponente DOC, Cinque Terre DOC,
  **Rossese di Dolceacqua DOC (sommbot — omitted, and it is the region's
  best-known red)**
- `molise` — Molise DOC / Biferno DOC, **Tintilia del Molise DOC (sommbot —
  the native grape's own DOC)**

**Spain (4)**
- `aragon` — Cariñena DO, Calatayud DO, Campo de Borja DO, Somontano DO
- `madrid` — Vinos de Madrid DO
- `andalucia` — Montilla-Moriles DO, Málaga DO
- `extremadura` — Ribera del Guadiana DO

**Portugal (3)**
- `beirainterior` — Beira Interior DOC
- `setubal` — Setúbal DOC / Palmela DOC
- `algarve` — **four DOCs, not one (sommbot): Lagos, Portimão, Lagoa, Tavira.**
  "Algarve DOC" does not exist; Algarve is a Vinho Regional with four DOCs inside
  it. Write it as the VR with the four named, or the row is wrong on its face.

**Argentina (3)**
- `sanjuan` — San Juan IG (Tulum, Pedernal, Zonda)
- `catamarca` — **two provinces merged (sommbot).** Catamarca IG and La Rioja IG
  are separate; Famatina is in La Rioja, not Catamarca. Either write two rows and
  split the painted area, or write one row that says plainly it covers both.
- `cordoba` — Córdoba IG (Traslasierra, Calamuchita)

**Chile (5)**
- `coquimbo` — Coquimbo DO (Elqui, Limarí, Choapa)
- `rapel` — Rapel Valley DO (Cachapoal, Colchagua)
- `maule` — Maule Valley DO, **and Curicó Valley DO (sommbot).** The painted
  area covers both; Curicó is a separate DO and the larger name commercially.
- `biobio` — Bío Bío Valley DO
- `malleco` — Malleco Valley DO

**New Zealand (7)**
- `northland` — Northland GI
- `auckland` — Auckland GI (Waiheke Island, Kumeu)
- `waikatobop` — **not a registered GI (sommbot).** Waikato and Bay of Plenty are
  two separate GIs and the pairing is a convention, not a registration. Say so in
  the row, or the entry asserts something untrue.
- `gisborne` — Gisborne GI
- `wairarapa` — Wairarapa GI (Martinborough)
- `nelson` — Nelson GI
- `canterbury` — **conflates three GIs (sommbot):** Canterbury, North Canterbury
  and Waipara Valley are separately registered. One row must name all three.

Two notes for whoever writes them. The stem on the left is the **art name**, not
an id — it is what `<c>-region-index.json` will key on once an entry exists, and
it must not become an id in `regions.ts`. And these are the ones the maps already
paint; §3.2's fifteen are the opposite problem and are deferred under ruling 4.

---

## 7. Five contracts the app honours — do not break them from this side

Quoted from `AUDIT.md` §3. *"Break any one and the failure is quiet."*

1. **Hit-test `<country>-index.png`, never a pixel colour.** The index is at
   logical scale, not `export_scale` — one byte per canvas cell.
2. **Never re-derive geometry in the app.** The manifest's projection block is
   the single source of truth for lon/lat → canvas.
3. **Compute nothing the manifest already computed.** Button positions are poles
   of inaccessibility, emitted as canvas fractions.
4. **Resolve a tap to the nearest region, not the one under the finger.**
5. **Keep these files away from `outlines:check` and `icons:verify`.** If a gate
   starts walking them, move the files rather than adding an exclusion.

Practically, from the generator's side: emit the index raster at logical scale,
emit the projection block, emit `subject_rect` and the button fractions, and
install into `Sources/VinodexUI/Resources/Maps/<country>/` — which all three
gates already, correctly, ignore.

---

## 8. Traps already paid for

- **The magenta key is exact.** `#EE03E1` only. The art is exported
  nearest-neighbour from flat fills, so there is no fringe to snap — and a
  cleanup pass that shifted one pixel of a fill would make that pixel
  unresolvable. Do not run `art_common.strip_background` over these.
- **The backdrop is never keyed.** It is opaque by design (sea, shelf,
  neighbouring land) and keying it punches holes wherever the renderer used a
  magenta-ish tone.
- **Islands blow up a country's bounding box.** Portugal owns the Azores and
  Madeira a thousand miles out; Spain owns the Canaries; Chile's Valparaíso
  Region owns Easter Island, 3,500 km into the Pacific, which on its own turned
  Chile's frame from tall-and-narrow into wide-and-empty. `exclude` and
  `frame_window` are the two answers. Check that `subject_rect` frames the
  mainland and not the ocean between it and its islands.
- **`subject_rect` is fractions of the canvas, not the canvas.** Scale both
  layers together so that rect fills the intended width; do not aspect-fit the
  whole canvas, which shrinks the country to a third of the frame.
- **A nearest-region search must refuse the sea.** Without that guard a tap in
  open water answers from 135 px away. Alpha is the coastline.
- **Renaming a manifest field breaks both layers silently.** `france_rect` →
  `subject_rect` was a non-optional decode and produced "MAP NOT INSTALLED" on
  every country at once.
- **~~Regenerating the globe reshuffles all 30 country colours.~~ Handled.**
  `globe_tex.py` now carries every authored `fill` forward from the
  `globe-meta.json` on disk and colours only countries that have none. Verified:
  all 30 authored `admin`/`stem`/`fill`/`label`/`key` values came through the
  34-country rebuild unchanged.
- **NEW — the country-outline folder is not the catalog.** 51 outline stems, 34
  catalog countries. Eleven of the difference are US states and six are
  countries with art and no entry. Deriving "which countries should the globe
  carry" from the art put six tappable dead ends one commit from landing;
  `GlobeIndexTests.everyCountryResolves` would have caught them and
  `globe_tex.py`'s catalog assert now catches them a step earlier. **When the
  question is whether the app knows about a country, the answer is in
  `regions.ts` and nowhere else.**
- **Cyprus is five polygons in Natural Earth** — `Cyprus`, `Northern Cyprus`,
  `Cyprus No Mans Area`, `Dhekelia`, `Akrotiri`. **The globe paints only
  `Cyprus`, on purpose**: every Cypriot wine region is south of the line. A tap
  on the north of the island answers "land". That is a decision, and it is
  written down here so it does not get re-discovered as a bug.
- **NEW — `globe_tex.py` used to destroy `globe-meta.json`.** Fixed 13 Sep. That
  file is installed *verbatim* and decoded by `GlobeIndex.Meta.Entry`, which
  needs `idx`, `admin`, `label`, `mapped`, all non-optional, and
  `install_globe.py` needs `fill`. The generator emitted three of the seven, so
  running it stripped four fields that had been hand-added to the shipped file:
  `KeyError('fill')` at install, and past that a nil `GlobeIndex` and a sphere
  that goes back to untappable. No test catches it, because the file is data.
  The generator now emits the whole contract and asserts it.
- **NEW — the globe's raster and meta must ship as a pair.** `idx` is a position
  in an alphabetical list, so adding one country renumbers most of them, and an
  old raster pairs *cleanly* with a new meta — every country answers as its
  alphabetical neighbour. `globe_tex.py` stamps `index_sha256` into the meta and
  `install_globe.py` refuses a mismatch. Do not defeat it.
- **NEW — `install_globe.py`'s brighten collapses the palette on screen.**
  Reported, not fixed: `v = min(1.0, v * 2.05)` clips, so every fill above
  v≈0.49 lands on the same value. Measured on the 30 authored fills,
  portugal/united-kingdom go from ΔE 25.5 in the manifest to **2.6** as shipped;
  slovenia/usa 18.7 → 4.5; chile/georgia 15.3 → 4.9. A non-clipping lift
  (`v + (1-v)*0.40`) roughly triples the worst pair and costs visible brightness;
  the real fix is re-authoring about six of the thirty. **Any new colour must be
  chosen post-brighten** — `palette.extend(..., transform=palette.brighten)`.
  The four added on 13 Sep clear ΔE 30.9 against all 33 others as shipped.
- **NEW — `region_check.py <c>` used to destroy the region index.** Fixed 13 Sep;
  see §5.4. The general shape is the one to remember: *a gate that writes an
  artefact can corrupt the artefact and still print PASS.*
- **NEW — never hand-cut an admin-1 extract.** France's was metropolitan-only, 96
  units where the source gives 101, and regenerating it would have reframed the
  map from the Channel to Réunion with no assert firing. Exclusions go in the
  config. `verify_extracts.py` now catches it.
- **NEW — a painted area with no catalog entry is invisible until someone taps
  it.** Nothing in the build fails. That is how 25 accumulated. §5.4 adds the
  gate that would have caught it.

---

## 9. Sequence

Sommbot's ruling (`data-review/EXAM-ANCHORING-AND-SUBJECT-EXPANSION.md`) ranks
closing the content gap **above every new subject and every new country**, on the
grounds that a painted stem beats a free-text pointer. Ruling 2 agrees with it
from the other direction. So:

1. ~~**Regenerate the globe.**~~ Done — 34 countries, 13 Sep.
2. ~~**Build China.**~~ Done — 4 regions, PASS.
3. ~~**Build Austria.**~~ Done — 3 of 4; Wachau waits on §3.3.
4. **Install Austria and China.** `install_art.py` has been run for both;
   the layers are in `Sources/VinodexUI/Resources/Maps/{austria,china}/`. The
   coupled commit is the terminal's: `RegionMap.mapped`, `globe-meta.json` and
   the installed art together, with `mappedAgreesWithRegionMaps` green before it
   leaves.
5. **Stage the 25 catalog entries** (§6), with sommbot's seven corrections. This
   is a six-step sequence, not deploybot-only and not parallelisable — the
   terminal's correction to revision 2, which said it could run in parallel.
6. **Read the nine US rows** and settle §4.1. This needs a ruling, not work, and
   it is the same ruling as the eleven US state stems missing from the globe (§2).
   Separately: **six countries have outline art and no catalog entry** — bosnia,
   czechia, israel, serbia, slovakia, ukraine. They are sommbot's to write, and
   they cannot go on the globe until they exist. Same ordering as the 25.
7. **Land the second index plane** (§3.3), Austria first.
8. **Build Greece.** Peripheries, at least one split, and do not omit Dytiki
   Ellada — Patras is in it.
9. **Scope the source work** for Germany, South Africa, and the USA if its rows
   are AVAs. One country first, end to end, before committing to the rest.
10. **Leave the 3-region countries** until their catalogs grow.

Painting Greece before staging the 25 adds six more good regions to a map set
that already has twenty-five dead ends.

---

## 10. What not to touch

- `entries/countries/*.png` and their `mapPositions` — the existing
  country-outline system, which coexists with this one.
- `shared/data/regions.ts` — read-only from here. Pins are authored separately,
  and the §6 entries are the deploybot's to write, not this session's.
- `entries.json` and the generated data layer.
- The three gates. If one starts walking these files, move the files.
- `vinodex-web` — never commit or push it; hand any web-side prompt to the
  maintainer's web session.

---

## 11. Done means

For each country added:

- `region_map.py <c>` renders without warnings, and reports the region count, the
  admin-1 units claimed, the canvas size, and a computed palette with its worst
  adjacent ΔE.
- `verify_extracts.py` still reports **N of N extracts reproduce from source**,
  with the new country in `verify_extracts.ADMIN`.
- `region_check.py <c>` reports **PASS — all N pins resolved to a wine region**,
  and names the pin file the region index came from.
- `coverage_check.py <c>` reports **0 dead**. Every painted stem has at least one
  catalog id behind it; if a stem cannot get an entry, it should not be a stem.
- `install_art.py <c>` lands the layers in
  `Sources/VinodexUI/Resources/Maps/<c>/`.
- The country's `mapped` count in `globe-meta.json` is updated, and
  `GlobeIndexTests.mappedAgreesWithRegionMaps` still passes — it asserts that the
  countries the globe says are mapped are exactly the ones `RegionMap.mapped`
  lists, so a map installed without updating the meta fails there.
- A screenshot of the country's region tier on the simulator, looked at. The
  globe screen takes `-vinodexScreenshot globe@<lon>,<lat>:double`.
- **Where the map is an approximation, the approximation is written down** — in
  the config block, next to the units it approximates. France's §3 in
  `france-map-plan.md` is the model: state it plainly, because someone who knows
  the region will notice.

---

## 12. Standing debts

Small enough to forget, expensive enough to matter. Cleared only when the line
can be deleted.

| Owed | By | Note |
|---|---|---|
| Install Austria + China | terminal | `install_art.py` run for both; the coupled commit with `RegionMap.mapped` and `globe-meta.json` is theirs; §9.4 |
| Six `countries.ts` + `regions.ts` entries | sommbot | bosnia, czechia, israel, serbia, slovakia, ukraine — outline art exists, no catalog rows; they cannot go on the globe until they do (§2) |
| `GlobeIndex.catalogName` — Serbia / Bosnia display names | terminal | beside the USA one; only matters when the six land (§2) |
| `brighten` — re-author ~6 of the 30 country fills, or accept the collapse | Harrison | §8; measured, not fixed |
| `--strict` on `coverage_check.py` in CI | terminal | once the 25 are staged |
| Python gates in CI at all | terminal | `region_check`, `verify_extracts`, `coverage_check` are green and unwatched |
| Cava is listed as a sub-appellation of Penedès | sommbot | it is a DO in its own right, not under Penedès; affects §3.2's Spain rows |
| Austria's catalog classifications | sommbot | `Niederösterreich DAC` and its siblings do not exist — they are Weinbaugebiete. The painted map is right; the four `regions.ts` rows are not |
| Nothing in the 13 Sep drop has been seen on a device | — | pixel comparisons and cell counts only |
