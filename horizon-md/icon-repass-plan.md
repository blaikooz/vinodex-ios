# The Major Icon Repass — campaign plan

Date: 2026-09-07. Planning document only — nothing in the repo changes until phases execute.
Input: `whiteground-audit.md` (same directory), read against the live pipeline
(`scripts/art_common.py`, `scripts/import-*-art.py`, scratchpad `slice-sheets.py`,
`scripts/generate-ios-data.ts`).

---

## 1. Executive summary

**What's wrong.** 310 of 583 committed art sources ship on a white ground, so
`art_common.strip_background` takes its fallback path: a border flood-fill that clears only
pixels with every channel >= 240. Anti-aliased edge pixels — white ground blended into the
near-black cel outline — land in the 200–239 band, fail the test, and survive as a 1px opaque
near-white fringe hugging the whole silhouette. On the app's dark CRT ground that fringe reads
as a white halo, plus stair-stepped ragged outlines and stray white specks in enclosed gaps
(between the orchard-fruit apples, inside handles) that the border flood can never reach. The
audit measured it: 89/106 FlavorArt files above the 0.10 white-edge threshold (mean 0.164),
every one of the 22 subclass icons at 0.25+, grape bunches to 0.263. The magenta-keyed sets all
measure **0.000** — the pipeline is fine; the ground is the problem.

**What a repass buys.** Regenerating a tile on the magenta key `#EE03E1` routes it through
chroma-key path 1 (exact clear, no heuristics), and the campaign slicer's fringe-snap already
repaints near-key AA blends to pure key before import. Keyed tiles come out with a clean dark
outline against transparency — proven at 0.000 across ~273 existing keyed sources and the
0.9.47 grape sheets.

**Scope, as this plan cuts it** (vs the audit's raw 215-core count):

| Bucket | tiles | approach |
|---|---|---|
| P1 FlavorArt | 94 | **regenerate** — 9 sheets (hero-size portraits; halo + enclosed specks + ragged edges) |
| P2 ClassArt | 64 | **regenerate** — 5 sheets (worst measured set; specks between elements) |
| P3 GrapeArt legacy bunches | 28 | **retire / programmatic** — 0 sheets (near-dead fallbacks since 0.9.47, see §3.4) |
| P4 StyleArt | 29 | **decision-gated** — 3 sheets held behind the de-halo review (mildest set, genuine white rims) |
| Optional VINOBOT faces | 6 | 1 optional sheet (defuses the sub-gate magenta trap) |
| entries/countries | 4 | **drop from campaign** — outputs measure 0.000; outlines are re-inked from authored rings anyway |

**Bottom line: 14 core sheets / 158 tiles regenerated; up to 18 sheets / 193 tiles with the
gated + optional work. Plus two small code passes (a de-halo erode and a keyed-fringe snap in
`art_common.py`) and one code-only grape retirement.** Core maintainer art time ≈ 7.5–8 h
spread one sheet a day over ~3 weeks; ≈ 10 h if styles and VINOBOT run too.

---

## 2. The assembly line (unchanged) and the three small slicer/code edits

Per sheet, the loop is the 0.9.47 one:

1. **🟥 Maintainer**: generate ONE image from the pasted prompt — flat magenta `#EE03E1`
   ground, no containers, generous spacing; retry weak tiles; drop the PNG in `art/inbox/`
   (~15–40 min including retries).
2. **🟦 Claude**: add the sheet's `PLAN` entry to `slice-sheets.py` (exact source filenames,
   spaces and artist typos preserved), run it — tile detection, fringe-snap, NEAREST downscale
   to set-native height — writing into `art/icons/entries/<set>/`.
3. **🟦 Claude**: run the set's importer (`import-flavor-art.py` / `import-class-art.py` /
   `import-style-art.py`), `icons:verify`, contact-sheet check on a dark ground, sim
   spot-check. **No `generate-ios-data.ts` edits for any flavor/class/style sheet** — every
   regenerated tile reuses its existing source filename, so `FLAVOR_ART`, the `art:` ids and
   `STYLE_ART` stay untouched.

Small edits needed once, before the first class sheet (🟦):

- **`slice-sheets.py` TARGET_H rows** — currently only grapes 162 / flavors 216 / styles 332.
  Add: `entries/subclasses` 176, `entries/soil` 176, `entries/classes` 176,
  `entries/climate` 176, `entries/color` 162, `entries/styleclasses` 176, `entries/body` 170,
  `entries/continents` 315 (and `chrome/vino` 296 if V1 runs). Values match each set's native
  sprite heights (sampled: class-family sets ~150–200, continents ~315, vino ~296).
- **Per-tile destination in `PLAN`** — sheets C4/C5 mix sets with different dest dirs (and, in
  C5, different target heights). Extend the tile list entries from `name` to `(destrel, name)`.
  It is a scratchpad script; ~10 lines.
- **`art_common.py`** — the two programmatic passes of §5, which ship on Day 1 regardless of
  the campaign.

### The house style (the preamble)

Studied from magenta-era masters: `entries/flavors/bellpeppers.png`,
`entries/grapes/pinotnoir.png`, `entries/styles/cava.png`. The look: chunky 16-bit cel pixel
art; every subject bound by a bold near-black outline (~2px at drawn scale); flat saturated
fills with two or three hard cel-shade tones per surface (a dark shade side, a mid, a lit
side); small hard-edged pure-white specular highlights as dots and short dashes — never soft
glows; no anti-aliasing, no gradients, no drop shadows, no ground line; subject fills its tile.

**HOUSE PREAMBLE — paste verbatim at the top of every sheet prompt, then the sheet's grid line
and numbered subjects:**

> One single image: a pixel-art sprite sheet. Retro 16-bit handheld cel style: every subject
> drawn with a bold near-black outline, flat saturated colour fills with two or three hard
> cel-shading tones per surface, and small hard-edged white specular highlights (dots and short
> dashes — never soft glows). No anti-aliasing, no gradients, no drop shadows, no text, and no
> boxes, frames, plates or containers around any subject. The entire background is one flat
> solid magenta, hex #EE03E1, and nothing else. Arrange the subjects in a neat grid with
> generous magenta spacing between every subject — at least half a subject-width — and keep
> every subject fully separate (no touching, no overlapping, no small parts drifting off on
> their own). All subjects at the same scale.

(The spacing/separation clause is what keeps the slicer's connected-component pass at the
expected tile count; a floating spark or crumb 3+ blocks from its subject becomes a phantom
tile or a merged crop.)

---

## 3. Sheet-by-sheet campaign plan

Tile lists are the exact source filenames the importers resolve today (spaces and the artist's
spellings preserved — `mediterrean.png`, `saltysublcass.png`, `rosecolor.png`,
`blackberry jam.png`); the slicer writes crops under these same names, so zero table edits.

### 3.1 FlavorArt — 9 sheets, 94 tiles (P1)

Importer: `scripts/import-flavor-art.py`. Slice target: **216 px** tile height
(`entries/flavors`), roughly square subjects. Wiring per sheet: PLAN entry → slice →
`import-flavor-art.py` → verify. No table edits.

---

**Sheet F1 — "Citrus & orchard" — 12 tiles, 4 cols x 3 rows**
Tiles: `lemon.png`, `lemoncurd.png`, `lemonzest.png`, `lime.png`, `yuzu.png`,
`grapefruit.png`, `orange.png`, `green apple.png`, `red apple.png`, `pear.png`,
`quince.png`, `banana.png`

Prompt (after the preamble): *Grid: 4 columns by 3 rows, 12 subjects, each roughly square.
Subjects, numbered left to right, top to bottom:*
1. A whole bright-yellow lemon with a small green leaf.
2. A small glass jar of pale-yellow lemon curd with a spoon resting in it — clearly a jar, distinct from the whole lemon.
3. A curl of lemon peel zest, spiral ribbon of yellow rind with white pith on the inner face.
4. A whole green lime with one wedge cut showing pale pulp segments.
5. A knobbly yellow-green yuzu citrus fruit with bumpy rind and a leaf.
6. A pink grapefruit half, cut face showing pink segments, next to the whole fruit.
7. A whole orange with dimpled rind and a green leaf.
8. A shiny green apple with a stem and leaf.
9. A shiny red apple with a stem and leaf — same pose as the green apple, different fruit colour.
10. A yellow-green pear with a brown stem.
11. A golden-yellow quince, lumpy pear-like fruit with a downy sheen.
12. A yellow banana, slightly curved, with brown tip.

---

**Sheet F2 — "Stone fruit & tropical" — 12 tiles, 4 cols x 3 rows**
Tiles: `apricot.png`, `peach.png`, `white peach.png`, `plum.png`, `blackplum.png`,
`mango.png`, `pineapple.png`, `lychee.png`, `fig.png`, `driedfig.png`, `pomegranate.png`,
`gooseberry.png`

Prompt: *Grid: 4 columns by 3 rows, 12 subjects, each roughly square:*
1. A round orange apricot with a cleft and a leaf.
2. A blushing orange-and-red peach with fuzzy sheen and a leaf.
3. A pale cream-and-pink white peach — clearly paler than the orange peach.
4. A purple-red plum with a dusty bloom.
5. A deep blue-black plum, darker than the purple one.
6. A ripe mango, green-to-red-orange skin, with one cut cheek showing orange flesh.
7. A pineapple with spiky green crown and cross-hatched golden body.
8. A red rough-skinned lychee, one peeled showing translucent white flesh.
9. A fresh purple fig, one cut in half showing pink-red seedy interior.
10. A wrinkled brown dried fig, flattened, clearly dried — distinct from the fresh fig.
11. A red pomegranate with one wedge broken open showing ruby seeds.
12. A cluster of three pale-green striped gooseberries with papery tails.

---

**Sheet F3 — "Berries & preserves" — 10 tiles, 5 cols x 2 rows**
Tiles: `blackberry.png`, `blackberry jam.png`, `blackcurrant.png`, `blueberry.png`,
`jammyberry.png`, `raspberry.png`, `sour cherry.png`, `strawberry.png`,
`strawberrycandy.png`, `tomato.png`

Prompt: *Grid: 5 columns by 2 rows, 10 subjects, each roughly square:*
1. A cluster of plump black blackberries with drupelet bumps and a leaf.
2. A glass jam jar full of dark blackberry jam, jar clearly drawn, a berry beside it.
3. A sprig of small glossy blackcurrants hanging from a stem with a leaf.
4. Three round blue blueberries with pale bloom and star-shaped calyx dimples.
5. A spoonful of glossy dripping mixed-berry jam, thick and syrupy — no jar, distinct from the blackberry jam jar.
6. A red raspberry, hollow-capped, with drupelet bumps and a small leaf.
7. Two bright sour cherries on a joined stem, lighter scarlet red, with one leaf.
8. A red strawberry with seeds and green cap.
9. A wrapped strawberry hard candy, twist wrapper ends, cartoon candy — clearly a sweet, not a fruit.
10. A ripe red tomato with green star calyx.

---

**Sheet F4 — "Floral" — 9 tiles, 3 cols x 3 rows**
Tiles: `redrose.png`, `rosepetal.png`, `violet.png`, `lilac.png`, `jasmine.png`,
`honeysuckle.png`, `chamomile.png`, `orange-blossom.png`, `whiteblossom.png`

Prompt: *Grid: 3 columns by 3 rows, 9 subjects, each roughly square:*
1. A single red rose bloom on a short stem with one leaf.
2. Three loose pink-red rose petals, scattered, soft curl to each.
3. A purple violet flower with five petals and a yellow centre, on a stem.
4. A cone-shaped cluster of small purple lilac florets with a leaf.
5. A white jasmine flower, five slender petals, with dark green pointed leaves.
6. A honeysuckle bloom, cream-and-yellow trumpet flowers with long curved stamens.
7. A chamomile flower, white daisy petals around a domed yellow centre.
8. An orange-blossom sprig: small white waxy flowers with a tiny green orange fruit behind.
9. A white blossom branch, several simple five-petal white flowers on a twig — distinct from the jasmine: rounder petals, pink-tinged centres.

---

**Sheet F5 — "Herbal & green" — 12 tiles, 4 cols x 3 rows**
Tiles: `mint.png`, `sage.png`, `dill.png`, `fennel.png`, `grass.png`, `alpineherbs.png`,
`driedherbs.png`, `tealeaf.png`, `tobaccoleaf.png`, `tomatoleaf.png`, `greenpea.png`,
`greenbellpepper.png`

Prompt: *Grid: 4 columns by 3 rows, 12 subjects, each roughly square:*
1. A sprig of fresh mint, bright green serrated leaves in opposite pairs.
2. A sprig of sage, soft grey-green oval leaves.
3. A feathery frond of dill, fine wispy dark-green threads.
4. A fennel bulb, pale white-green layered bulb with green stalks and feathery tops.
5. A tuft of green grass blades growing from a small clump of earth.
6. A small bundle of alpine wildflower herbs: thin stems, tiny white and blue flowers, tied with twine.
7. A hanging bundle of dried herbs, dusty olive-brown, tied and upside-down — clearly dried, distinct from the fresh bundles.
8. Two fresh tea leaves with a bud, glossy dark green, pointed.
9. A large tobacco leaf, broad, brown-amber, with prominent veins.
10. A tomato-vine leaflet sprig, jagged green leaflets on a fuzzy stem with a tiny green tomato.
11. An open green pea pod showing a row of round peas.
12. A green bell pepper, glossy, with stem — a single pepper.

---

**Sheet F6 — "Spice, nut & sweet spice" — 12 tiles, 4 cols x 3 rows**
Tiles: `cinnamon.png`, `clove.png`, `nutmeg.png`, `ginger.png`, `vanilla.png`,
`licorice.png`, `peppercorn.png`, `greenpeppercorn.png`, `whitepepper.png`, `almond.png`,
`hazelnut.png`, `marzipan.png`

Prompt: *Grid: 4 columns by 3 rows, 12 subjects, each roughly square:*
1. Two rolled cinnamon quills, crossed, warm brown with curled ends.
2. Three dried clove buds, dark brown nail-shaped with round heads.
3. A whole nutmeg seed beside a half showing the marbled cut face.
4. A knobby fresh ginger root, tan skin, one cut end showing pale yellow flesh.
5. Two dark-brown vanilla pods, slightly bent, with a small white flower.
6. Coiled black licorice rope with a few cut black pastille pieces.
7. A small pile of black peppercorns, matte black wrinkled spheres.
8. A sprig of green peppercorns still on the stem, like a tiny grape cluster — clearly green and on a strand.
9. A small pile of pale cream white peppercorns, smoother and paler than the black pile.
10. Three almonds, tan teardrop nuts, one showing the pitted shell texture.
11. Two hazelnuts, round glossy brown nuts, one in its frilled husk.
12. A block of pale almond-cream marzipan with two cut cubes, dusted look.

---

**Sheet F7 — "Pastry, dairy & roast" — 9 tiles, 3 cols x 3 rows**
Tiles: `brioche.png`, `butter.png`, `honey.png`, `beeswax.png`, `chocolate.png`,
`chocolate2.png`, `cocoa.png`, `coffee.png`, `cedar.png`

Prompt: *Grid: 3 columns by 3 rows, 9 subjects, each roughly square:*
1. A golden fluted brioche bun with a topknot, glossy egg-wash sheen.
2. A pat of yellow butter on a small square of paper, one corner curl.
3. A honey dipper dripping golden honey over a puddle, hexagon comb piece behind.
4. A lump of amber-yellow beeswax beside a small hexagonal honeycomb wedge — waxy and matte, clearly not the glossy honey.
5. A dark chocolate bar, near-black squares, one broken corner. **(this file is the DARK bar — the catalog maps 'dark chocolate' to `chocolate` and 'chocolate' to `chocolate2`; keep the darkness distinction exact)**
6. A milk chocolate bar, warm brown squares, one broken corner — clearly lighter than the dark bar.
7. A pile of red-brown cocoa powder with two cocoa beans in front.
8. A white cup of black coffee, side view, steam wisps, three roasted beans beside it.
9. A stack of two cedar wood planks with visible warm-red grain and a few shavings.

---

**Sheet F8 — "Mineral & marine" — 9 tiles, 3 cols x 3 rows**
Tiles: `chalk.png`, `mineral.png`, `stone.png`, `graphite.png`, `petrol.png`, `saline.png`,
`seasalt.png`, `seaspray.png`, `seabreeze.png`

Prompt: *Grid: 3 columns by 3 rows, 9 subjects, each roughly square.* **The white parts here
are subject, not ground — draw them inside outlines as usual; the magenta must never touch a
white fill directly except through the dark outline:**
1. Two white chalk sticks, one leaning on the other, with white dust crumbs at their base (crumbs close to the sticks).
2. A grey-blue mineral crystal cluster, faceted shards with pale highlights.
3. A smooth rounded grey river stone with a lighter band.
4. A graphite pencil-lead stick and a shard of dark silvery graphite with metallic sheen.
5. A rainbow-sheen petrol drop on a small dark slick, iridescent blues and purples.
6. A laboratory-style glass of clear brine with salt crystals dissolving at the bottom.
7. A small heap of coarse white sea-salt crystals with a tiny wooden scoop.
8. A curling ocean wave crest throwing white spray droplets (droplets tight to the wave).
9. A stylised gust of sea breeze: two curled wind swooshes over a small wave, a seagull silhouette above.

---

**Sheet F9 — "Earth & savory" — 9 tiles, 3 cols x 3 rows**
Tiles: `earth.png`, `game.png`, `leather.png`, `lanolin.png`, `olive.png`, `smoke.png`,
`smokyspice.png`, `tar.png`, `volcanicash.png`

Prompt: *Grid: 3 columns by 3 rows, 9 subjects, each roughly square:*
1. A rich brown mound of turned earth with a small green sprout.
2. A stag's head in profile with antlers, warm brown, noble game emblem.
3. A folded piece of tan leather with visible stitching and a strap end.
4. A ball of cream wool yarn with a soft waxy sheen — lanolin, wool-fat.
5. A sprig of two green olives and one dark olive with silvery-green leaves.
6. A rising curl of grey smoke from a small dark ember.
7. A smoking dark-red dried chilli over a few charred spice seeds — smoke plus spice in one, distinct from the plain smoke curl.
8. A dripping black tar blob on a brush handle, thick and glossy.
9. A grey volcano cone puffing a cloud of dark ash flecks (flecks tight to the plume).

---

### 3.2 ClassArt — 5 sheets, 64 tiles (P2)

Importer: `scripts/import-class-art.py` (stems come from the generator's `art:` ids, resolved
through `SOURCE_FOR` — filenames below are that table's, typos included, so no edits). Slice
targets: **176 px** for all small sets (color 162, body 170), **315 px** for continents. These
render small (dex rows, chips) — favour bold silhouettes, minimal interior detail.

---

**Sheet C1 — "Flavor subclasses A" — 11 tiles, 4 cols x 3 rows**
Dest `entries/subclasses`: `baking.png`, `berry.png`, `bread.png`, `briny.png`,
`citrus.png`, `darkfruit.png`, `earth.png`, `floral.png`, `game.png`, `herbal.png`, `nut.png`

Prompt: *Grid: 4 columns by 3 rows, 11 subjects (last row has 3), each roughly square, bold
and simple — these render at chip size:*
1. Baking spices: a cinnamon quill crossed over a star anise.
2. A cluster of three mixed berries (one red, two blue-black) with a leaf.
3. A rustic bread loaf with scored top.
4. Briny: an open oyster shell with a pearl-bright wet highlight.
5. A lemon wedge and a lime wedge side by side.
6. Dark fruit: a black plum with two blackberries in front.
7. A mound of brown earth with a sprout.
8. A single five-petal pink flower head.
9. A stag head in profile with antlers.
10. A sprig of green herb leaves.
11. A hazelnut and an almond side by side.

---

**Sheet C2 — "Flavor subclasses B" — 11 tiles, 4 cols x 3 rows**
Dest `entries/subclasses`: `orchardfruit.png`, `redfruit.png`, `saltysublcass.png`,
`savory.png`, `smoky.png`, `spice.png`, `stonefruit.png`, `tropical.png`, `vegetal.png`,
`wax.png`, `wood.png`

Prompt: *Grid: 4 columns by 3 rows, 11 subjects (last row has 3), each roughly square, bold
and simple:*
1. Orchard fruit: a red apple and a green pear leaning together — draw the pair tight so no white gap opens between them.
2. Red fruit: two cherries on a joined stem with a strawberry.
3. A salt shaker with a few grains falling.
4. Savory: a brown mushroom with a sprig of thyme.
5. A curl of grey smoke rising from an ember.
6. A red chilli crossed with a cinnamon quill.
7. Stone fruit: a peach with a cherry in front.
8. Tropical: a pineapple with a mango leaning on it.
9. Vegetal: a green bell pepper with a pea pod in front.
10. A dripping yellow wax candle stub, unlit.
11. A stack of two wooden planks with visible grain.

---

**Sheet C3 — "Soils" — 16 tiles, 4 cols x 4 rows**
Dest `entries/soil`: `alluvial.png`, `basalt.png`, `chalk.png`, `clay.png`,
`default soil.png`, `granite.png`, `gravel.png`, `laterite.png`, `limestone.png`,
`loam.png`, `loess.png`, `sand.png`, `schist.png`, `shale.png`, `slate.png`, `volcanic.png`

Prompt: *Grid: 4 columns by 4 rows, 16 subjects, each roughly square — every subject is a
small ground/rock emblem, kept visually distinct by colour and texture:*
1. Alluvial: a winding blue river ribbon depositing pale silt banks.
2. Basalt: a cluster of dark grey-green hexagonal basalt columns.
3. Chalk: a white cliff-edge block with soft crumb texture (white inside a dark outline).
4. Clay: a smooth terracotta-orange mound with two crack lines.
5. Default soil: a plain brown earth mound, simplest of the set.
6. Granite: a speckled light-grey boulder, salt-and-pepper flecks.
7. Gravel: a scatter pile of small grey pebbles — drawn as one tight heap, no strays.
8. Laterite: a rust-red crumbly block with pitted holes.
9. Limestone: a pale cream layered rock block.
10. Loam: a dark crumbly soil mound with a worm poking out.
11. Loess: a wind-blown tan silt dune with streak lines.
12. Sand: a small golden sand dune with ripple lines.
13. Schist: a silvery-grey rock with diagonal glittering foliation bands.
14. Shale: a stack of thin flaky dark grey-blue rock layers.
15. Slate: a smooth blue-grey split slab, cleaner and flatter than the shale stack.
16. Volcanic: a small grey volcano cone with a red lava trickle.

---

**Sheet C4 — "Taxonomy: classes, colours, style classes, body" — 15 tiles, 5 cols x 3 rows** 🟪
Mixed destinations (needs the per-tile-dest slicer edit):
`entries/classes`: `bitter.png`, `saltyclass.png`, `sour.png`, `sweet.png`, `umami.png` ·
`entries/color`: `dual.png`, `orange.png`, `red.png`, `rosecolor.png`, `white.png` ·
`entries/styleclasses`: `blend.png`, `method.png`, `origin.png`, `type.png` ·
`entries/body`: `light.png`

Prompt: *Grid: 5 columns by 3 rows, 15 subjects, each roughly square, bold and simple:*
1. Bitter: a dark coffee bean with a puckered zigzag mouth-line emblem beneath.
2. Salty: a heap of white salt crystals on a tiny dish.
3. Sour: a lemon wedge with pucker lines radiating off it.
4. Sweet: a honey drop with a small sugar cube.
5. Umami: a brown mushroom with a steam wisp.
6. Dual colour: a wine glass split down the middle, left half red wine, right half white wine.
7. Orange wine colour: a single tall drop of amber-orange liquid.
8. Red wine colour: a single tall drop of deep ruby liquid — same drop shape as the orange one.
9. Rosé colour: a single tall drop of pink liquid — same drop shape.
10. White wine colour: a single tall drop of pale straw liquid — same drop shape; pale gold fill, not pure white, inside the dark outline.
11. Blend: two overlapping wine drops merging, two colours meeting.
12. Method: a hand crank-corkscrew tool.
13. Origin: a small map pin over a wine-region hill with vine rows.
14. Type: a simple wine bottle silhouette with a plain label.
15. Body light: a feather floating above a wine glass.

---

**Sheet C5 — "Climate & continents" — 11 tiles, 2 rows** 🟪
Mixed destinations and mixed target heights (per-tile dest edit; climates 176, continents 315):
`entries/climate`: `continental.png`, `cool.png`, `maritime.png`, `mediterrean.png`,
`warm.png` · `entries/continents`: `africa.png`, `asia.png`, `europe.png`,
`northamerica.png`, `oceania.png`, `southamerica.png`

Prompt: *Grid: two rows. Top row: 5 small square subjects. Bottom row: 6 larger square
subjects, each drawn about twice the size of the top-row ones:*
1. Continental climate: a sun half and a snowflake half split by a jagged line.
2. Cool climate: a pale blue snowflake over a small thermometer reading low.
3. Maritime climate: a wave with a small cloud above it.
4. Mediterranean climate: a sun over an olive branch.
5. Warm climate: a bold sun with thick rays over heat-shimmer lines.
6. The continent of Africa as a chunky pixel landmass globe emblem, warm sand-and-green fills, on a small blue ocean disc.
7. The continent of Asia, same globe-emblem treatment.
8. The continent of Europe, same treatment.
9. North America, same treatment.
10. Oceania (Australia with New Zealand beside it), same treatment.
11. South America, same treatment.

---

### 3.3 StyleArt — 3 sheets, 29 tiles (P4 — DECISION-GATED)

**Held behind the Day-1 de-halo review** (§5): the audit found StyleArt mildest — much of its
white-edge score is genuine white glass rims — and a guarded de-halo may make regeneration
unnecessary here. If the contact sheet after the programmatic pass still shows halos (the
`rose.png` copita's pale left-of-bowl fringe is the tell), run these three sheets.

Importer: `scripts/import-style-art.py`. Slice target: **332 px** tile height — **tall**
subjects (bottle-and-glass proportions, ~2:1 height:width). Wiring: same loop; ONE extra edit —
if `sweetwhite.png` is regenerated on key, remove `"sweetwhite"` from that importer's
`MASTERS` set (today it is copied verbatim as a hand-recoloured master; a keyed regen should
go through the normal strip path).

---

**Sheet S1 — "Still wines" — 10 tiles, 5 cols x 2 rows**
Tiles: `fullbodyred.png`, `mediumbodyred.png`, `lightbodyred.png`, `chillablered.png`,
`fullbodywhite.png`, `mediumbodywhite.png`, `lightbodywhite.png`, `aromaticwhite.png`,
`sweetwhite.png`, `rose.png`

Prompt: *Grid: 5 columns by 2 rows, 10 subjects, each TALL (about twice as high as wide) —
wine bottles with a glass beside them. Bottle shape and glass fill distinguish each:*
1. Full-body red: a broad-shouldered dark bottle with a large glass of deep opaque ruby wine.
2. Medium-body red: same pairing, slightly slimmer bottle, clearly-red translucent wine.
3. Light-body red: slim bottle, glass of pale translucent garnet wine.
4. Chillable red: slim bottle in a droplet-beaded chill sleeve, glass of bright cherry-red wine with an ice-cold sparkle.
5. Full-body white: broad bottle, glass of rich golden wine.
6. Medium-body white: slimmer green bottle, glass of straw-yellow wine.
7. Light-body white: slim pale bottle, glass of very pale near-clear wine.
8. Aromatic white: slim tall flute-necked bottle with a small flower beside the glass of pale wine, scent wisps rising.
9. Sweet white: a small half-bottle with a glass of honey-gold wine and a honey drop.
10. Rosé: a clear bottle of pink wine with a wide-bowl copita glass of pale pink wine.

---

**Sheet S2 — "Sparkling, amber & natural" — 10 tiles, 5 cols x 2 rows**
Tiles: `champagne.png`, `prosecco.png`, `petnat.png`, `sparklingwine.png`,
`sparklingred.png`, `orangewine.png`, `qvevriamber.png`, `naturalwine.png`,
`crubeaujolas.png`, `noblegrape.png`

Prompt: *Grid: 5 columns by 2 rows, 10 subjects, each TALL (about twice as high as wide):*
1. Champagne: a dark bottle with gold foil and wire cage, flute glass of pale gold bubbles (bubbles inside the glass only).
2. Prosecco: a lighter green bottle, simpler foil, flute of lively pale bubbles.
3. Pét-nat: a bottle with a crown cap and hand-drawn-style label, cloudy hazy fizz in a tumbler.
4. Sparkling wine: a classic sparkling bottle popping its cork with a small burst, glass of bubbles beside.
5. Sparkling red: dark bottle, flute of fizzing ruby-red wine.
6. Orange wine: a bottle with a glass of hazy amber-orange wine.
7. Qvevri amber: a clay qvevri vessel (egg-shaped, buried-rim) beside a glass of amber wine.
8. Natural wine: a bottle with a plain paper label and a leaf, glass of cloudy unfiltered wine with sediment flecks.
9. Cru Beaujolais: a Burgundy-shaped bottle with a small hill-and-vine crest label, glass of vivid violet-red wine.
10. Noble grapes: a single regal grape bunch wearing a tiny gold crown.

---

**Sheet S3 — "Fortified, sweet & flagship blends" — 9 tiles, 3 cols x 3 rows**
Tiles: `port.png`, `sherry.png`, `fortifiedwine.png`, `dessertwine.png`, `icewine.png`,
`lateharvest.png`, `botrytiswine.png`, `bordeauxblend.png`, `supertuscan.png`

Prompt: *Grid: 3 columns by 3 rows, 9 subjects, each TALL (about twice as high as wide):*
1. Port: a squat dark bottle with a white painted stripe, small tulip glass of inky ruby port.
2. Sherry: a slim dark bottle with a small copita of amber sherry.
3. Fortified wine: a stout bottle with a barrel-stamp label beside a small glass of dark amber wine.
4. Dessert wine: a small elegant half-bottle with a tiny glass of thick golden wine and a sugar swirl.
5. Ice wine: a tall slim bottle frosted with ice crystals, tiny glass of golden wine, a snowflake.
6. Late harvest: a bottle beside a shrivelled-ripe golden grape bunch still on the vine.
7. Botrytis wine: a bottle beside a grape bunch dusted with noble-rot grey fuzz, glass of deep gold wine.
8. Bordeaux blend: a claret bottle with a château-tower crest label, glass of dark garnet wine.
9. Super Tuscan: a bold modern bottle with a minimalist label and a cypress-tree motif, glass of dark red wine.

---

### 3.4 GrapeArt legacy bunches — RETIRE, don't repass (P3 → code-only)

**Checked against the live resolution path before deciding**, as briefed:

- `EntryVisual.swift:107-108` resolves `grapePortraitStem(forGrapeID:)` **first**, falling to
  `grapeArtStem(forKey: GrapeArt.key(for:))` only when the portrait table misses.
- `buildGrapePortraits` (generate-ios-data.ts) is **total over the catalog**: named portrait →
  GODFORSAKEN gnarl → `GRAPE_CLUSTERS` archetype → a default `cone-large/small` archetype for
  any grape no table names. Every grape id gets a stem; the colour-grid fallback is reachable
  only via data drift (an id absent from the generated table), i.e. effectively never in a
  shipping build. `import-grape-art.py` already says it in its own comments: the golds "are
  dead fallbacks since every grape gained a portrait in 0.9.47".
- Within the grid itself, `buildGrapeArt` maps every combo onto the `-rare` stems only. Of the
  28 white-ground legacy sources: **16 are orphans** whose bundled outputs nothing references
  (`green-common`, all `-common`/`-noble` variants of green/red/red-amber/red-pink), **1** is
  the already-skipped duplicate `redlight.png`, and **11** back the near-dead fallback grid
  (`green/red/gold-{light,medium,full}-rare`, `red-amber-medium-rare`, `red-pink-rare`).

**Recommendation: spend zero art tiles here.**

1. 🟦 Delete the 16 orphan sources and their bundled `GrapeArt` outputs; trim their
   `SOURCE_TO_STEM` rows (plus the `redlight.png: None` row once its file goes). Pure
   dead-weight removal — nothing can resolve them.
2. 🟦 Keep the 11 fallback stems as the typed safety net; the Day-1 de-halo pass (§5) cleans
   the 8 that go through `strip_background`. The 3 `gold-*-rare` files are `MASTERS`
   (copied verbatim, bypassing the strip) — either a one-off scrub with the same erode, or
   leave them: the path is unreachable without a build-breaking data bug anyway.
3. Not recommended: repointing `buildGrapeArt` at the keyed archetype sprites to retire all
   28. It works, but it's redesigning the visuals of an unreachable path — against the
   log-don't-fix house rule.

If any grape sheet is ever generated again for other reasons: **every bunch keeps the
autumn-yellow leaf** — it is the sentinel the importer re-hues to teal (hue 0.47) for the
runtime rarity re-ink; a green or red leaf on a new drawing is an automatic redo.

### 3.5 Optional Sheet V1 — "VINOBOT faces" — 6 tiles, 3 cols x 2 rows

Tiles (dest `art/icons/chrome/vino`): `neutral.png`, `smiling.png`, `goodjob.png`,
`raiseaglass.png`, `surprised.png`, `thinking.png`. Importer: `scripts/import-vino-art.py`.
Slice target 296 px, tall-portrait aspect. Outputs are clean today — this sheet exists purely
to defuse the latent magenta trap (§6) and put the set on the keyed path. Run last, or never.

Prompt: *Grid: 3 columns by 2 rows, 6 subjects, each a tall bust portrait of the SAME
character: a friendly retro robot sommelier — rounded cream-white head, dark visor band with
two glowing eyes, a small bow tie, a folded white cloth over one arm. Only the expression and
pose change:*
1. Neutral: eyes level, calm straight mouth-light.
2. Smiling: eyes curved happy, warm smile-light.
3. Good job: winking, one thumbs-up.
4. Raise a glass: holding up a small wine glass in a toast.
5. Surprised: wide round eyes, small "!" spark beside the head.
6. Thinking: eyes up-and-aside, one hand at chin, a small gear or "?" above.

Wiring note: today's sources ship pre-cut with real alpha and (per the audit) 0.3–0.5%
embedded magenta. A keyed regen goes through path 1 like all chrome — and removes the trap.

### 3.6 Dropped from the campaign

`entries/countries` (armenia, bulgaria, cyprus, moldova): their `outline-*` outputs measure
0.000 — flat fills re-inked by the importer from authored rings; a repass buys nothing. Flags,
logo, attic, reference: per the audit, no tiles.

---

## 4. Ordering, cadence, and maintainer minutes

One phase a day (established cadence). 🟥 art (maintainer generates; Claude's slice+import is
routine) · 🟦 code only · 🟪 mixed (sheet + a code edit landing with it). Maintainer minutes
are generation time incl. retries, calibrated to the 0.9.47 campaign's 15–40 min/sheet.

| Day | Phase | Label | Maintainer est. |
|---|---|---|---|
| 1 | **Code: de-halo erode + keyed fringe-snap in `art_common.py`**, re-import all sets, contact-sheet review → decide StyleArt gate | 🟦 | ~10 min review |
| 2 | **Code: GrapeArt retirement** (16 orphans + table trim) | 🟦 | 0 |
| 3 | F1 Citrus & orchard (12) | 🟥 | 35–40 |
| 4 | F2 Stone & tropical (12) | 🟥 | 35–40 |
| 5 | F3 Berries (10) | 🟥 | 30 |
| 6 | F4 Floral (9) | 🟥 | 25–30 |
| 7 | F5 Herbal & green (12) | 🟥 | 35–40 |
| 8 | F6 Spice & nut (12) | 🟥 | 35–40 |
| 9 | F7 Pastry & roast (9) | 🟥 | 25–30 |
| 10 | F8 Mineral & marine (9) — interior-white care | 🟥 | 30 |
| 11 | F9 Earth & savory (9) | 🟥 | 25–30 |
| 12 | C1 Subclasses A (11) — lands with the TARGET_H slicer rows | 🟪 | 30 |
| 13 | C2 Subclasses B (11) | 🟥 | 30 |
| 14 | C3 Soils (16) | 🟥 | 40 |
| 15 | C4 Taxonomy mixed (15) — lands with the per-tile-dest slicer edit | 🟪 | 35–40 |
| 16 | C5 Climate & continents (11, two scales) | 🟪 | 35 |
| 17–19 | S1–S3 Styles (29) — **only if the Day-1 gate says so** | 🟥 | 30–35 each |
| 20 | V1 VINOBOT faces (6) — optional | 🟥 | 20–25 |

**Totals: core (F1–F9 + C1–C5, 14 sheets, 158 tiles) ≈ 7.5–8 h of maintainer art time.
With gated styles + optional VINOBOT (18 sheets, 193 tiles) ≈ 9.5–10 h.** Claude-side
slice/import/verify per sheet is not maintainer time.

---

## 5. The cheaper alternative: a programmatic de-halo pass — honest analysis

**The change** (in `art_common.strip_background`, path 2, after the flood-fill): one erosion
iteration over opaque pixels that are (a) near-white (`min(r,g,b) >= 230`) and (b) 4-adjacent
to transparency — with a **fringe guard**: clear only pixels whose near-white connected
component is thin (every pixel of the component within 1px of transparency). A halo is a 1px
string hugging the silhouette; a chalk stick or glass bowl is a blob with interior, and the
guard leaves blobs alone. ~25 lines, applies to every white-ground set on the next
`npm run icons`, zero art time.

**What it fixes** — most of the measured halo: the near-white AA fringe that is the bulk of
every score in the audit (FlavorArt mean 0.164, subclass 0.25+, grape rings 0.26). This is
why it ships Day 1 regardless: the whole app improves immediately, and every set that later
regenerates was still better in the meantime. It is also the only fix the retired-in-place
grape fallbacks and any other never-regenerated stragglers will ever get.

**What only regeneration fixes:**
- **Off-white contamination below the floor** — AA pixels in the 200–229 band (blends deep
  into the outline) fail the near-white test; the outline stays dirtied and stair-stepped.
- **Enclosed white specks** — the dots between the orchard-fruit apples and along the vegetal
  outlines are border-disconnected, so neither the flood nor an edge erode reaches them; the
  0.5.6 lesson stands that any heuristic smart enough to eat them also shreds petals.
- **Ragged silhouettes** — erosion removes a pixel, it cannot redraw the clean cel edge a
  keyed export has.
- **Style drift already present** — nothing programmatic makes a 2024-era drawing match the
  magenta-era masters.

**Casualty class**: genuine 1px white *linework* touching the silhouette edge — glass-rim
highlights on StyleArt, sparkle crosses — is thin by construction and the guard cannot tell it
from halo. Interior whites (chalk sticks, mineral facets, White Blossom petals) are safe: in
this art style white subject sits inside the dark cel outline, so it is never edge-adjacent.

**Recommended split:**
- **Regenerate**: FlavorArt (hero-size portraits; specks + ragged edges + worst traffic) and
  ClassArt (worst measured set, specks between elements). De-halo is the interim, not the fix.
- **Programmatic only**: GrapeArt legacy fallbacks (retired/near-dead — erode is more than the
  path deserves) and, pending the Day-1 review, StyleArt (mildest set, most legitimate white;
  if the guarded erode nicks the rims, opt StyleArt out of the pass and run S1–S3 instead).

**The audit's side finding — magenta AA fringe on KEYED sets — as one code change**: in
`strip_background` path 1, after clearing key pixels, run the same single-iteration edge pass
clearing opaque pixels adjacent to transparency that match the key-blend test the campaign
slicer already uses (`r > 120 and b > 120 and g < min(r,b) * 0.35`). That is exactly the
fringe-snap `slice-sheets.py` performs on new crops, moved to import time so the ~273 existing
keyed chrome sources (glyph-cog's `(174,6,172)` edge and friends) clean up on the next
re-import with no art touched. No shipped palette colour sits in that band (the slicer test
has run over every campaign sheet without an incident), and the VINOBOT faces never enter
path 1. Ships together with the de-halo as the Day-1 🟦 phase.

---

## 6. Risks

1. **Style drift vs icons users know.** 158+ icons redrawn from prompts will not be
   pixel-descendants of the originals — and FlavorArt is the hero surface. Mitigations: the
   house preamble is written from the actual magenta-era masters, not from taste; subject
   lines describe the existing icon's composition where it is distinctive (the
   chocolate/chocolate2 dark-vs-milk mapping is load-bearing — the catalog swaps them);
   per-tile retry before import (weak tiles redone, never "close enough"); contact-sheet
   review on the dark ground before each import; git keeps every old source for rollback.
   Accept that within-sheet consistency will beat cross-sheet consistency — grouping by theme
   means related icons regenerate together, which is where consistency matters most.
2. **The VINOBOT latent trap.** The six face sources measure 0.3–0.5% magenta — *under* the
   1% gate — while `import-vino-art.py`'s own docstring believes they carry "no magenta at
   all". Today they take the (harmless, for them) flood path. Any future touch that nudges
   past 1% — a tighter crop shrinking the canvas, an edit adding magenta-ish pixels — silently
   flips them to the key path, which would punch holes wherever those in-art magenta-passing
   pixels sit. Defusal options: optional sheet V1 (clean keyed re-export), or the
   log-don't-fix version — an importer assertion that errors when `0 < magenta < 1%` so the
   trap can never spring silently. The assertion is cheap enough to ride along with Day 1.
3. **Interior-white subjects vs a naive de-halo.** Chalk's sticks, mineral's facets, sea
   salt's crystals, every specular highlight — a guardless erode eats their edges. The
   thin-component guard in §5 is a requirement, not polish; StyleArt's 1px rim linework is
   the known residual and the reason for the Day-1 gate. The F8 prompt also carries an
   explicit "white inside outlines" clause so the *new* art keeps white un-adjacent to ground.
4. **Slicer count mismatches.** Detached sparkle dots, spray droplets and crumbs become
   phantom components or merge across the 3-block gap join. The preamble's separation clause
   plus per-subject "tight to the subject" wording in the risky tiles (seaspray, volcanicash,
   chalk crumbs, gravel) is the defence; the slicer's hard `expected != found` exit means a
   miscount fails loudly, never mis-names a tile.
5. **The grape leaf contract** — dormant, since no grape sheets run; recorded anyway: any
   future bunch generation must keep the autumn-yellow leaf (the sentinel the importer re-hues
   to teal, hue 0.47) or the runtime rarity re-ink silently stops for that sprite.
6. **Mixed-destination sheets (C4/C5)** depend on the small slicer edits; land those the same
   day as their sheet (🟪), and the slicer's loud-exit behaviour covers the rest.
7. **Bundle stability guarantees hold**: importers write through `save_stable`/
   `quantize_stable`, so re-imports only rewrite files whose decoded pixels changed —
   `git status` after each phase stays the honest record of what moved.
