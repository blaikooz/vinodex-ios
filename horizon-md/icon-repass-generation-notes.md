# Icon repass — generation notes & handoff

Companion to `icon-repass-plan.md`. Written by the browser session that generated the
sheets, for the terminal session that slices and imports them.

Everything below describes **what is actually in the PNGs**, not what the plan asked for.
Where the two differ, this file wins.

---

## 1. Status

| Block | Sheets | Tiles | State |
|---|---|---|---|
| FlavorArt (P1) | F1–F9 | 94 | **sliced + imported** in 0.9.52 |
| ClassArt (P2) | C1–C5 | 64 | **sliced + imported** in 0.9.52 |
| StyleArt (P4) | S1–S3 | 29 | **in `art/inbox/`, not yet sliced** |

`art/inbox/` currently holds three files:

```
sheet-s1-still.png          4714 x 3001   5 cols x 2 rows   10 tiles
sheet-s2-sparkling.png      5070 x 3150   5 cols x 2 rows   10 tiles
sheet-s3-fortified.png      2840 x 4106   3 cols x 3 rows    9 tiles
```

Slice target for all three: **332 px tile height**, dest `entries/styles`,
importer `scripts/import-style-art.py`.

---

## 2. ONE required table edit

`import-style-art.py` keeps `sweetwhite` in its `MASTERS` set, where files are copied
verbatim and bypass `strip_background`. The new `sweetwhite` tile is keyed like every
other tile and **must** go through the normal strip path.

**Remove `"sweetwhite"` from that importer's `MASTERS` set before importing S1.**

This is the only table or code edit the whole campaign needs. Every other filename below
already matches what the importers resolve today, typos preserved
(`mediterrean.png`, `saltysublcass.png`, `rosecolor.png`, `blackberry jam.png`).

---

## 3. Tile order

Reading order is left-to-right, top-to-bottom, matching the plan's numbering exactly.
No re-mapping needed anywhere.

### S1 — `sheet-s1-still.png` — 5 x 2

```
fullbodyred      mediumbodyred    lightbodyred     chillablered     fullbodywhite
mediumbodywhite  lightbodywhite   aromaticwhite    sweetwhite       rose
```

### S2 — `sheet-s2-sparkling.png` — 5 x 2

```
champagne        prosecco         petnat           sparklingwine    sparklingred
orangewine       qvevriamber      naturalwine      crubeaujolas     noblegrape
```

### S3 — `sheet-s3-fortified.png` — 3 x 3

```
port             sherry           fortifiedwine
dessertwine      icewine          lateharvest
botrytiswine     bordeauxblend    supertuscan
```

<details>
<summary>Already-imported sheets, for the record</summary>

```
F1 sheet-f1-citrus       lemon, lemoncurd, lemonzest, lime / yuzu, grapefruit, orange,
                         green apple / red apple, pear, quince, banana
F2 sheet-f2-stonefruit   apricot, peach, white peach, plum / blackplum, mango, pineapple,
                         lychee / fig, driedfig, pomegranate, gooseberry
F3 sheet-f3-berries      blackberry, blackberry jam, blackcurrant, blueberry, jammyberry /
                         raspberry, sour cherry, strawberry, strawberrycandy, tomato
F4 sheet-f4-floral       redrose, rosepetal, violet / lilac, jasmine, honeysuckle /
                         chamomile, orange-blossom, whiteblossom
F5 sheet-f5-herbal       mint, sage, dill, fennel / grass, alpineherbs, driedherbs,
                         tealeaf / tobaccoleaf, tomatoleaf, greenpea, greenbellpepper
F6 sheet-f6-spice        cinnamon, clove, nutmeg, ginger / vanilla, licorice, peppercorn,
                         greenpeppercorn / whitepepper, almond, hazelnut, marzipan
F7 sheet-f7-pastry       brioche, butter, honey / beeswax, chocolate, chocolate2 /
                         cocoa, coffee, cedar
F8 sheet-f8-mineral      chalk, mineral, stone / graphite, petrol, saline /
                         seasalt, seaspray, seabreeze
F9 sheet-f9-earth        earth, game, leather / lanolin, olive, smoke /
                         smokyspice, tar, volcanicash
C1 sheet-c1-subclassesA  baking, berry, bread, briny / citrus, darkfruit, earth, floral /
                         game, herbal, nut
C2 sheet-c2-subclassesB  orchardfruit, redfruit, saltysublcass, savory / smoky, spice,
                         stonefruit, tropical / vegetal, wax, wood
C3 sheet-c3-soils        alluvial, basalt, chalk, clay / default soil, granite, gravel,
                         laterite / limestone, loam, loess, sand / schist, shale, slate,
                         volcanic
C4 sheet-c4-taxonomy     bitter, saltyclass, sour, sweet, umami / dual, orange, red,
                         rosecolor, white / blend, method, origin, type, light
C5 sheet-c5-climate...   top row: continental, cool, maritime, mediterrean, warm
                         bottom row: africa, asia, europe, northamerica, oceania,
                         southamerica
```

</details>

---

## 4. Slicing the S-sheets: the one thing that differs

F- and C-sheets held one compact subject per tile. **Every S-tile is a bottle *and* a
glass** — two disconnected shapes that belong to the same tile.

A connected-component or naive column-gap pass will split them and return 20 tiles from
S1 instead of 10. The projection slicer needs a horizontal gap threshold large enough to
bridge bottle-to-glass but smaller than the gap between neighbouring pairs.

Measured on these three sheets, that window is comfortable:

| Sheet | bottle→glass gap | pair→pair gap | threshold used at compose time |
|---|---|---|---|
| S1 | ~30–45 px | ~200+ px | 40 |
| S2 | ~40–55 px | ~190+ px | 40–60 |
| S3 | ~35–50 px | ~180+ px | 40–50 |

**Anything in 60–150 px will separate the ten pairs correctly on all three sheets.**
If the slicer returns 20/20/18 tiles, that threshold is the knob.

Two tiles have a deliberate third element tucked against the pair — S1 `sweetwhite`
(honey drop right of the glass) and S1 `aromaticwhite` (flower at the glass foot). Both
sit inside the pair's own gap window and come along with the tile. They are not strays.

---

## 5. Contracts honoured in the artwork

- **Key** is flat `#EE03E1` on every sheet. Exact-magenta coverage runs 68–83%.
- **Nothing is framed.** No panels, cards, rounded rectangles, borders or ground lines.
- **No text anywhere.** S2's first pass wrote "Pet-nat" on a label and was regenerated
  with an explicit zero-characters clause. Labels that need to say something say it with
  a picture instead: `fortifiedwine` a barrel, `bordeauxblend` a château tower,
  `supertuscan` a cypress, `crubeaujolas` a hill-and-vine crest.
- **Graded sets were generated as single images**, so the steps are real rather than
  three independent guesses:
  - S1 `fullbodyred` / `mediumbodyred` / `lightbodyred` — one image
  - S1 `fullbodywhite` / `mediumbodywhite` / `lightbodywhite` — one image
  - C4 `orange` / `red` / `rosecolor` / `white` — one image, one silhouette, four fills
  - F1 `green apple` / `red apple` — one image, identical pose
  - F2 `peach` / `white peach` and `plum` / `blackplum` — one image each
- **`white.png` is pale straw gold, not white**, per the plan's note.
- **Lookalikes were split across separate generations** so they could not converge:
  black / white / green peppercorn; smoke / smokyspice / volcanicash; shale / slate;
  chalk / seasalt; jasmine / orange-blossom / whiteblossom; champagne / prosecco /
  sparklingwine.

### Leaf colour — decide before importing S2/S3

Three StyleArt tiles contain a grape bunch: S2 `noblegrape`, S3 `lateharvest`,
S3 `botrytiswine`. All three were drawn with an **autumn-yellow leaf**, following the
house rule at the end of the plan's §3.4.

That rule exists because `import-grape-art.py` re-hues the yellow leaf to teal (hue 0.47)
as the rarity sentinel. **`import-style-art.py` does not do that**, so on this path the
yellow is purely cosmetic — it reads as autumnal, which suits `lateharvest` and
`botrytiswine` and is arguably neutral on `noblegrape`.

Nothing breaks either way. If you'd rather they were green, they're a hand-tint, not a
regeneration.

---

## 6. Known cosmetic notes

- **C1's bottom five tiles** (`earth`, `floral`, `game`, `herbal`, `nut`) are drawn
  smaller than the rest of that sheet, because they came from a five-across generation
  row. The slicer normalises each tile to 176 px so this should not survive import —
  worth one glance at the contact sheet to confirm.
- **Scale varies within several F-sheets** (F1's lemon is small, its yuzu is large).
  Same reasoning: per-tile height normalisation absorbs it.
- **F5 `fennel`** has very fine feathery fronds. They should survive a 216 px slice;
  below that they thin out.

---

## 7. A false alarm, so nobody re-opens it

While composing S1 the key-repair pass flagged ~94k pixels per row as "near-magenta
inside the artwork", which looked like deep ruby wine being punched transparent. An
audit of the already-imported rows appeared to confirm it on five of them.

**It was a false positive.** Those pixels are *enclosed background pockets* — the empty
upper half of a wine glass above the wine line, the triangle of space between two cherry
stems. Keying them to transparent is correct and is what makes a glass read as glass. A
"fix" that preserved them filled the glasses with magenta blobs.

The existing repair behaviour is right. **Nothing in 0.9.52 needs re-slicing**, and the
high in-sprite-magenta counts in the generation logs are expected, not a defect.

---

## 8. Out of scope, unchanged

GrapeArt legacy bunches remain a **retire, don't repass** per plan §3.4 — 16 orphan
sources to delete, 11 fallback stems to keep as the typed safety net, zero art tiles
spent. No sheets were generated for them.
