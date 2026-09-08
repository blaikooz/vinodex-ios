# White-ground legacy icon audit — Vinodex iOS

Date: 2026-09-07. Read-only audit of committed art sources and bundled outputs.
Repo: /Users/hsmini/Developer/HGapps/vinodex-ios

## Method

- **Classification**: every committed source under `art/icons/**`, `art/flags/`, `art/originals/`
  (583 files) run through the exact `strip_background` path test from `scripts/art_common.py`:
  a pixel is magenta when `a>0 and r>=200 and b>=200 and g<=80`; the file is **magenta-ground**
  when magenta pixels `> (w*h)//100` (>=1%), else **white-ground** (border flood-fill fallback).
- **Halo metric** on bundled outputs (`Sources/VinodexUI/Resources/**`): for every opaque pixel
  (a>=128) with a transparent 4-neighbour, count it near-white when `min(r,g,b)>=230`.
  `white` = white-edge fraction. Baseline: magenta-keyed sets score ~0.000; a clean cut of this
  dark-cel-outline art style has essentially no white on the silhouette edge, so anything
  above ~0.10 is halo (or genuine white subject touching the edge — checked visually).
- **Visual inspection**: contact sheets composited on a dark ground (matching the CRT UI) plus
  4x nearest-neighbour zoom crops, viewed for each set (sheets saved alongside this file:
  `sheet_flavor.png`, `sheet_style.png`, `sheet_class.png`, `sheet_grape.png`, `sheet_vino.png`,
  `sheet_keyed.png`, `sheet_logo.png`, `sheet_zoom.png`).

## Classification counts

**Total 583 sources — 273 magenta-ground, 310 white-ground.**

| Source set | files | magenta | white | bundled output |
|---|---|---|---|---|
| art/icons/chrome/buttons | 43 | 43 | 0 | ButtonArt |
| art/icons/chrome/marquee | 39 | 39 | 0 | MarqueeArt |
| art/icons/chrome/glyphs | 22 | 22 | 0 | GlyphArt |
| art/icons/chrome/stickers | 21 | 20 | 0* | StickerArt |
| art/icons/chrome/cartridges | 17 | 17 | 0 | CartridgeArt |
| art/icons/chrome/stamps | 11 | 10 | 0* | StampArt |
| art/icons/chrome/footer | 4 | 4 | 0 | FooterArt |
| art/icons/chrome/vino | 6 | 0 | **6** | VinoArt (VINOBOT faces) |
| art/icons/chrome/logo | 1 | 0 | **1** | Logo (dvd icon source) |
| art/originals | 15 | 15 | 0 | (feeds ButtonArt masters) |
| art/icons/entries/flavors | 106 | 12 | **94** | FlavorArt |
| art/icons/entries/grapes | 64 | 36 | **28** | GrapeArt |
| art/icons/entries/styles | 32 | 3 | **29** | StyleArt |
| art/icons/entries/subclasses | 22 | 0 | **22** | ClassArt (subclass-*) |
| art/icons/entries/soil | 16 | 0 | **16** | ClassArt (soil-*) |
| art/icons/entries/continents | 6 | 0 | **6** | ClassArt (globe-*) |
| art/icons/entries/classes | 5 | 0 | **5** | ClassArt (class-*) |
| art/icons/entries/climate | 5 | 0 | **5** | ClassArt (climate-*) |
| art/icons/entries/color | 5 | 0 | **5** | ClassArt (color-*) |
| art/icons/entries/styleclasses | 4 | 0 | **4** | ClassArt (styleclass-*) |
| art/icons/entries/countries | 50 | 46 | **4** | ClassArt (outline-*) |
| art/icons/entries/body | 3 | 2 | **1** | ClassArt (body-light) |
| art/flags | 35 | 0 | **35** | Flags (opaque rects — n/a) |
| art/icons/attic | 41 | 4 | 37 | not shipped |
| art/icons/reference | 12 | 0 | 12 | not shipped |

\* a couple of sticker/stamp files fell just at the boundary; all shipped chrome outputs behave as keyed.

Note on chrome/vino: the six face sources carry 0.3–0.5% magenta — **below** the 1% gate, so
they went through the white flood-fill path, but their outputs are clean (see below).

## Ranked repass list (worst first)

Priority weighs both measured/observed defect severity and surface traffic. FlavorArt renders
as the hero portrait on entry pages (`EntryVisual.swift`), ClassArt as dex row/chip icons
(`DexIcon.swift`), GrapeArt via `GrapeSpriteLoader` in the grape dex, StyleArt on style pages.

### P1 — FlavorArt (entries/flavors) — 94 white-ground tiles
- Metric: 89/106 bundled files above 0.10 white-edge; set mean 0.164, worst ~0.27.
- Viewed: `redrose.png` (white specks and 1px stair-step halo hugging the whole outline —
  confirmed at 4x zoom), `lemon.png` (pale halo along left/bottom rind), `tealeaf.png` and
  `mint.png` (light fringe following leaf edges), `petrol.png`, `mineral.png`, `orange.png`.
- `chalk.png` and `mineral.png`'s interior whites survived (the flood-fill only clears
  border-connected white), so the defect is halo/fringe, not dropped subject-white.
- Contrast: the 12 magenta-keyed flavors (`bellpeppers`, `blackfruit`, `floralbouquet`, …)
  measure 0.000 — the pipeline is fine; the ground is the problem.
- Surface: hero-size entry portraits, highest-traffic art in the app.

### P2 — ClassArt (classes/subclasses/color/climate/soil/styleclasses/body/continents) — 64 tiles
- Metric: 62/103 bundled files above 0.10; worst: `color-white.png` 0.339,
  `subclass-orchard-fruit.png` 0.321, `styleclass-origin.png` 0.301,
  `subclass-vegetal.png` 0.295, `class-umami.png` 0.291, `class-sour.png` 0.288,
  `body-medium.png` 0.242, `body-light.png` 0.217, `soil-volcanic.png` 0.241.
- Viewed: apples cluster (`subclass-orchard-fruit`) with white specks between fruit and along
  edges; `subclass-vegetal` with strong white dots on every outline; olive branch
  (`climate-mediterranean`) with specks around leaves; volcano (`soil-volcanic`) and mushroom
  with edge specks; droplet (`color-white`) with visible halo staircase at 4x.
- Every subclass-* file (22) scores 0.25+ — the whole subfolder is affected.
- Surface: dex rows and category chips — high traffic, but rendered smaller than FlavorArt.
- Exception inside ClassArt: `outline-*` country fills all measure 0.000 (see fine-as-is).

### P3 — GrapeArt (entries/grapes, the 28 white-ground bunch sprites) — 28 tiles
- Metric: 27/105 bundled files above 0.10 (exactly the white-ground sources); worst:
  `red-medium-common.png` 0.263, `red-amber-medium-common.png` 0.252,
  `red-medium-noble.png` 0.235, `red-medium-rare.png` 0.233, `red-pink-common.png` 0.232,
  `green-full-rare.png` 0.232.
- Viewed: every white-ground bunch shows a conspicuous ring of white pixels clinging to the
  silhouette — the most visually obvious halo in the audit (see `sheet_grape.png`,
  bottom-left of `sheet_zoom.png`).
- The 36 magenta-keyed grape sources (arch-cone-* etc.) measure 0.000.
- Surface: grape dex sprites — high traffic, small render size makes the 1px ring pop.

### P4 — StyleArt (entries/styles) — 29 tiles
- Metric: 23/32 above 0.10; worst: `lightbodyred.png` 0.272, `mediumbodyred.png` 0.265,
  `lightbodywhite.png` 0.232, `fortifiedwine.png` 0.228, `rose.png` 0.219.
- Viewed: glasses read mostly clean at UI scale because their rims/stems are genuinely white;
  at 4x the `rose.png` copita shows a faint pale halo left of the bowl. Part of the metric
  score here is legitimate white subject touching the edge — the mildest of the four sets.
- The 3 magenta-keyed styles (`cava`, `cremant`, `madeira`) measure 0.000; `sweetwhite`
  is white-ground yet clean.
- Surface: style pages, medium traffic.

### Optional / low priority
- **entries/countries** — 4 white-ground sources (`armenia`, `bulgaria`, `cyprus`, `moldova`);
  their `outline-*` outputs measure 0.000 white-edge (flat single-colour fills, nothing for
  the flood-fill to chew). Repass only for pipeline consistency: 4 tiles.
- **chrome/vino** — 6 white-ground sources but bundled VINOBOT faces are clean (0.000
  white-edge, no magenta fringe; visually inspected all six in `sheet_vino.png`). Repass only
  for pipeline consistency, but note they sit below the 1% magenta gate while *containing*
  magenta — a re-export would remove a latent trap if the art is ever touched: 6 tiles.

## Fine as-is (white-ground, no repass needed)

- **art/flags (35)** — outputs are fully opaque rectangles (edge px = 0); no keying involved.
- **VinoArt / VINOBOT faces (6)** — clean silhouettes, hero surface unaffected (optional above).
- **ClassArt outline-* countries** — all 0.000, including the 4 white-ground sources.
- **Logo (chrome/logo, 1)** — `vinodex-mark-face/shade` measure 1.000 white-edge because the
  V mark IS white; by design.
- **art/icons/attic (37 white)** and **art/icons/reference (12)** — not imported into the
  bundle; exclude from any campaign.

## Side finding (out of scope, worth logging): magenta fringe on KEYED sets

The chroma-key path clears only pixels passing `_is_magenta` (r,b>=200, g<=80). Anti-aliased
blends of magenta ground with the dark cel outline fall below those thresholds and survive as
opaque magenta-tinted edge pixels. Measured magenta-edge fractions of 0.3–0.8 across
StickerArt, StampArt, CartridgeArt, ButtonArt, GlyphArt; sampled edge colours on
`GlyphArt/glyph-cog.png` include (174,6,172) and (201,8,201) — pure key-blend pink. Visible at
4x on `glyph-cog`, `ButtonArt/moondial.png` sparkles, `ButtonArt/settings.png` sliders
(`sheet_keyed.png`). On the dark UI ground a dark-pink 1px fringe reads far better than a
white one, which is why the maintainer perceives keyed sets as fine — but if a future repass
regenerates masters anyway, exporting with hard (non-anti-aliased) edges against the key, or
loosening the key thresholds/adding a fringe pass, would clean this too. Log, don't fix.

## Regeneration campaign sizing (magenta-sheet tiles per set)

| Set | tiles | priority |
|---|---|---|
| entries/flavors | 94 | P1 |
| entries/subclasses | 22 | P2 |
| entries/soil | 16 | P2 |
| entries/continents | 6 | P2 |
| entries/classes | 5 | P2 |
| entries/climate | 5 | P2 |
| entries/color | 5 | P2 |
| entries/styleclasses | 4 | P2 |
| entries/body | 1 | P2 |
| entries/grapes | 28 | P3 |
| entries/styles | 29 | P4 |
| **Core repass total** | **215** | |
| entries/countries (consistency only) | 4 | opt |
| chrome/vino (consistency only) | 6 | opt |
| **Total incl. optional** | **225** | |

Flags (35), logo (1), attic (37) and reference (12) white-ground files need no tiles.

## Appendix — full white-ground list, grouped by set

### art/flags/ (35 files)
argentina.png, australia.png, austria.png, brazil.png, bulgaria.png, california.png, canada.png, chile.png,
china.png, croatia.png, france.png, georgia.png, germany.png, greece.png, hungary.png, india.png, italy.png,
japan.png, lebanon.png, mexico.png, morocco.png, new-york.png, new-zealand.png, oregon.png, portugal.png,
romania.png, slovenia.png, south-africa.png, spain.png, switzerland.png, united-kingdom.png, uruguay.png,
usa.png, various.png, washington.png

### art/icons/attic/ (37 files — not shipped)
freshchillablered.png, grape-dark.png, grape-green.png, grape-mutant.png, grape-purple.png, grape-red.png,
grape-yellow.png, greenpear.png, gsmblend.png, legacy-2new-chillablered.png, legacy-2new-dessertwine.png,
legacy-2new-fortifiedwine.png, legacy-2new-fullbodyred.png, legacy-2new-fullbodywhite.png,
legacy-2new-lightbodywhite.png, legacy-2new-mediumbodyred.png, legacy-2new-orangewine.png,
legacy-blackcherry.png, legacy-cherry.png, legacy-classes-baking.png, legacy-classes-berry.png,
legacy-classes-blend.png, legacy-classes-bread.png, legacy-classes-darkfruit.png, legacy-classes-earth.png,
legacy-classes-full.png, legacy-classes-game.png, legacy-classes-herbal.png, legacy-classes-medium.png,
legacy-classes-orchardfruit.png, legacy-classes-redfruit.png, legacy-classes-savory.png,
legacy-classes-spice.png, legacy-classes-stonefruit.png, legacy-classes-vegetal.png, legacy-classes-wax.png,
oakbarrel.png

### art/icons/chrome/logo/ (1 file)
vinodex-dvd-icon.png

### art/icons/chrome/vino/ (6 files)
goodjob.png, neutral.png, raiseaglass.png, smiling.png, surprised.png, thinking.png

### art/icons/entries/body/ (1 file)
light.png

### art/icons/entries/classes/ (5 files)
bitter.png, saltyclass.png, sour.png, sweet.png, umami.png

### art/icons/entries/climate/ (5 files)
continental.png, cool.png, maritime.png, mediterrean.png, warm.png

### art/icons/entries/color/ (5 files)
dual.png, orange.png, red.png, rosecolor.png, white.png

### art/icons/entries/continents/ (6 files)
africa.png, asia.png, europe.png, northamerica.png, oceania.png, southamerica.png

### art/icons/entries/countries/ (4 files)
armenia.png, bulgaria.png, cyprus.png, moldova.png

### art/icons/entries/flavors/ (94 files)
almond.png, alpineherbs.png, apricot.png, banana.png, beeswax.png, blackberry jam.png, blackberry.png,
blackcurrant.png, blackplum.png, blueberry.png, brioche.png, butter.png, cedar.png, chalk.png, chamomile.png,
chocolate.png, chocolate2.png, cinnamon.png, clove.png, cocoa.png, coffee.png, dill.png, driedfig.png,
driedherbs.png, earth.png, fennel.png, fig.png, game.png, ginger.png, gooseberry.png, grapefruit.png,
graphite.png, grass.png, green apple.png, greenbellpepper.png, greenpea.png, greenpeppercorn.png,
hazelnut.png, honey.png, honeysuckle.png, jammyberry.png, jasmine.png, lanolin.png, leather.png, lemon.png,
lemoncurd.png, lemonzest.png, licorice.png, lilac.png, lime.png, lychee.png, mango.png, marzipan.png,
mineral.png, mint.png, nutmeg.png, olive.png, orange-blossom.png, orange.png, peach.png, pear.png,
peppercorn.png, petrol.png, pineapple.png, plum.png, pomegranate.png, quince.png, raspberry.png,
red apple.png, redrose.png, rosepetal.png, sage.png, saline.png, seabreeze.png, seasalt.png, seaspray.png,
smoke.png, smokyspice.png, sour cherry.png, stone.png, strawberry.png, strawberrycandy.png, tar.png,
tealeaf.png, tobaccoleaf.png, tomato.png, tomatoleaf.png, vanilla.png, violet.png, volcanicash.png,
white peach.png, whiteblossom.png, whitepepper.png, yuzu.png

### art/icons/entries/grapes/ (28 files)
goldfullrare.png, goldlightrare.png, goldmediumrare.png, greencommon.png, greenfullcommon.png,
greenfullnoble.png, greenfullrare.png, greenlightnoble.png, greenlightrare.png, greenmediumcommon.png,
greenmediumnoble.png, greenmediumrare.png, redambermediumcommon.png, redambermediumnoble.png,
redambermediumrare.png, redfullcommon.png, redfullnoble.png, redfullrare.png, redlight.png,
redlightcommon.png, redlightnoble.png, redlightrare.png, redmediumcommon.png, redmediumnoble.png,
redmediumrare.png, redpinkcommon.png, redpinknoble.png, redpinkrare.png

### art/icons/entries/soil/ (16 files)
alluvial.png, basalt.png, chalk.png, clay.png, default soil.png, granite.png, gravel.png, laterite.png,
limestone.png, loam.png, loess.png, sand.png, schist.png, shale.png, slate.png, volcanic.png

### art/icons/entries/styleclasses/ (4 files)
blend.png, method.png, origin.png, type.png

### art/icons/entries/styles/ (29 files)
aromaticwhite.png, bordeauxblend.png, botrytiswine.png, champagne.png, chillablered.png, crubeaujolas.png,
dessertwine.png, fortifiedwine.png, fullbodyred.png, fullbodywhite.png, icewine.png, lateharvest.png,
lightbodyred.png, lightbodywhite.png, mediumbodyred.png, mediumbodywhite.png, naturalwine.png, noblegrape.png,
orangewine.png, petnat.png, port.png, prosecco.png, qvevriamber.png, rose.png, sherry.png, sparklingred.png,
sparklingwine.png, supertuscan.png, sweetwhite.png

### art/icons/entries/subclasses/ (22 files — every subclass source is white-ground)
baking.png, berry.png, bread.png, briny.png, citrus.png, darkfruit.png, earth.png, floral.png, game.png,
herbal.png, nut.png, orchardfruit.png, redfruit.png, saltysublcass.png, savory.png, smoky.png, spice.png,
stonefruit.png, tropical.png, vegetal.png, wax.png, wood.png

### art/icons/reference/ (12 files — not shipped)
(reference folder, not imported)
