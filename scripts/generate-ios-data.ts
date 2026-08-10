/**
 * Generates the iOS app's bundled data from the shared data + colour tables.
 *
 * Emits eight files into the VinodexCore resource directory:
 *   entries.json   — the WineEntry set for the current selection
 *   tiers.json     — which entry ids the free tier unlocks
 *   palette.json   — the full colour tables, materialised by probing the
 *                    shared lookup functions over their key domains
 *   icons.json     — the icon manifest rasterize-icons.sh consumes
 *   countries.json — authored INFO prose for the country pages, which are
 *                    assembled from region fields and so have no entry of
 *                    their own to carry a description
 *   schema.json    — the SCHEMA_VERSION stamp, asserted at load on the Swift
 *                    side (0.6.3, item 1 — AUDIT M3)
 *   firmware.json  — the authored version and the per-release changelog the
 *                    boot POST and the FIRMWARE HISTORY panel read (0.7.3, F3)
 *   exam.json      — the authored Wine Exam question bank plus its closed
 *                    vocabularies (0.7.5, D)
 *
 * All eight are committed so a Swift build never needs Node. Scaling the starter
 * to the full database is a matter of setting STARTER_SELECTION to `undefined`.
 *
 * Everything this reads lives under `shared/`, a sibling of `scripts/` in this
 * repo. That used to be true of two repos at once — this script was published
 * into a mirror whose Swift package sat at the root rather than under `ios/`,
 * so it probed for `ios/Package.swift` to decide where to write. This repo is
 * now the only home, so the paths below are direct.
 */
import {
  resolveFlavorIcon,
  resolveFlavorClassIcon,
  resolveFlavorSubclassIcon,
} from '../shared/services/flavorIcon.ts';
import { existsSync, readFileSync, writeFileSync, mkdirSync, renameSync, rmSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { buildWineEntries, type EntrySelection } from '../shared/constants.ts';
import type { WineEntry } from '../shared/types.ts';
import { CONTINENTS } from '../shared/data/continents.ts';
import { COUNTRIES } from '../shared/data/countries.ts';
import { CLIMATE_CLASS_MAP } from '../shared/data/climateClasses.ts';
import {
  EXAM_QUESTIONS,
  EXAM_TIERS,
  EXAM_CATEGORIES,
  EXAM_FORMATS,
  EXAM_CATEGORY_LABELS,
  EXAM_TIER_LABELS,
  EXAM_AUTHORED_TIER_COUNTS,
  EXAM_MIN_CELL_COUNT,
  type ExamQuestion,
} from '../shared/data/exam.ts';
import { FIRMWARE_RELEASES, FIRMWARE_VERSION } from '../shared/data/firmware.ts';
import { getFlagGradient } from '../shared/data/flagGradients.ts';
import { GRAPE_CARDS } from '../shared/data/grapeCards.ts';
import { REGIONS } from '../shared/data/regions.ts';
import { STYLES } from '../shared/data/styles.ts';
import { STYLE_TONE_PALETTE } from '../shared/stylePalette.ts';
import {
  FLAVOR_SUBCLASS_KEYWORDS,
  FLAVOR_CLASS_COLORS,
  getStyleClassType,
  getColorType,
} from '../shared/services/entryUtils.ts';
import {
  getRegionClassificationIconColor,
  getFlavorSubclassIconColor,
} from '../shared/services/colorUtils.ts';
import {
  getCountryChipColors,
  getClassificationChipColors,
  getWineTypeChipColors,
  getRarityChipColors,
  getColorTypeChipColors,
  getStyleClassChipColors,
  getFlavorClassChipColors,
  getFlavorSubclassChipColors,
  SYSTEM_CHIP_COLOR,
  CLIMATE_CHIP_COLOR,
  BLUE_CHIP_COLOR,
  APPELLATION_CHIP_COLORS,
  type ChipColorStyle,
} from '../shared/services/chipColors.ts';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..');

// The Swift package is this repo. SwiftPM resolves target resources relative to
// the target's source directory, hence the Sources/... suffix.
const OUT_DIR = resolve(REPO_ROOT, 'Sources', 'VinodexCore', 'Resources');

if (!existsSync(resolve(REPO_ROOT, 'Package.swift'))) {
  throw new Error(`no Package.swift at ${REPO_ROOT} — run this from the repo root`);
}

// ---------------------------------------------------------------------------
// Starter selection. Chosen for UI-state coverage, not familiarity — see the
// plan. Set to `undefined` to emit the full database.
//
// Grapes are the only independently hand-picked list. Regions and styles are
// *derived* from the selected grapes' real cross-links — each REGION/STYLE
// entry's `details.notableGrapes` — rather than an independently hand-picked
// parallel list that can silently drift out of sync with the grape selection.
// Flavors are already derived this way upstream, in `buildFlavorEntries`.
// ---------------------------------------------------------------------------

const STARTER_GRAPES = [
  // Original 10 (Phase 1 starter, kept as-is): Cab Sauv, Pinot Noir,
  // Chardonnay, Riesling, Sangiovese, Montepulciano, Assyrtiko,
  // Touriga Nacional, Albariño, Pinotage.
  'G001', 'G002', 'G003', 'G007', 'G009', 'G051', 'G035', 'G038', 'G027', 'G050',
  // Phase 2 expansion (+15): the rest of the noble six (Merlot, Syrah,
  // Sauvignon Blanc, Nebbiolo), classic Old World reds/whites (Grenache,
  // Tempranillo, Malbec, Zinfandel, Gewürztraminer), and broader country
  // coverage — Argentina (Torrontés), Hungary (Furmint), Georgia (Saperavi),
  // Japan (Koshu), Greece (Xinomavro), Italy (Primitivo).
  'G004', 'G005', 'G006', 'G008', 'G010', 'G011', 'G012', 'G017', 'G024',
  'G026', 'G040', 'G043', 'G046', 'G063', 'G078',
  // Phase 3 expansion (+10), chosen to stress the layout rather than to round
  // out the canon: the two longest names in the set (Cabernet Gernischt, Melon
  // de Bourgogne, both 18 chars), umlauts (Grüner Veltliner, Müller-Thurgau,
  // Blaufränkisch), an apostrophe (Nero d'Avola), a hyphen, and RARE tiers so
  // the rarity crown is not only ever seen on NOBLE.
  'G042', 'G062', 'G077', 'G028', 'G044',
  'G070', 'G076', 'G037', 'G022', 'G080',
];

const selectedGrapeNames = new Set(
  GRAPE_CARDS.filter((card) => STARTER_GRAPES.includes(card.id)).map((card) => card.name),
);

/** Every REGION/STYLE that lists at least one of the selected grapes as notable. */
const linkedIds = <T extends { id: string; details: { notableGrapes?: string[] } }>(
  all: readonly T[],
): string[] =>
  all
    .filter((entry) => entry.details.notableGrapes?.some((name) => selectedGrapeNames.has(name)))
    .map((entry) => entry.id);

/// The full database now ships. `STARTER_GRAPES` is kept because the free-tier
/// rule below is expressed against real grape properties rather than a
/// hand-listed selection, and because reverting to a curated subset is a
/// one-line change if the full set turns out to be unwieldy.
const STARTER_SELECTION: EntrySelection | undefined = undefined;

/// Retained as the ready-made argument for STARTER_SELECTION above. Exported
/// only so `noUnusedLocals` doesn't delete the one thing that makes reverting
/// to a curated subset a one-line change.
export const CURATED_SELECTION: EntrySelection = {
  grapes: STARTER_GRAPES,
  regions: linkedIds(REGIONS),
  styles: linkedIds(STYLES),
  // Continents power the native continent info screen (globe marker ->
  // INFO + COUNTRIES). Countries remain out of scope — full COUNTRY_GATE
  // screens (states, appellation systems) aren't ported; a continent's
  // country rows link straight to that country's regions instead.
  includeContinents: true,
  includeCountries: false,
};

// ---------------------------------------------------------------------------
// Palette materialisation
//
// The web app's colour lookups are functions with private maps and keyword
// matching, not exported tables. Rather than duplicate them, probe each
// function across its key domain and record what it returns — whatever the
// function says is by definition correct.
// ---------------------------------------------------------------------------

const uniq = (values: readonly string[]) => [...new Set(values)].filter(Boolean).sort();

const probe = <K extends string>(
  keys: readonly K[],
  lookup: (key: K) => ChipColorStyle,
): Record<string, ChipColorStyle> =>
  Object.fromEntries(keys.map((key) => [key, lookup(key)]));

/** Every string that reaches a colour lookup anywhere in the full database. */
function collectKeyDomain(all: readonly WineEntry[]) {
  const origins: string[] = [];
  const classifications: string[] = [];
  const wineTypes: string[] = [];

  for (const entry of all) {
    // The details union has no index signature, and CountryGateDetails in
    // particular does not overlap structurally — go via unknown rather than
    // widening every member of the union.
    const details = entry.details as unknown as Record<string, unknown>;
    if (typeof details.origin === 'string') origins.push(details.origin);
    if (typeof details.classification === 'string') classifications.push(details.classification);
    if (entry.category === 'GRAPES') {
      wineTypes.push(entry.wineType ?? '', entry.grapeStyle ?? '');
    }
    // Appellation systems ride in tags on country gates.
    for (const tag of entry.tags) classifications.push(tag);
  }

  return {
    origins: uniq(origins),
    classifications: uniq(classifications),
    wineTypes: uniq(wineTypes),
  };
}

function buildPalette(full: readonly WineEntry[]) {
  const domain = collectKeyDomain(full);

  const rarities = ['COMMON', 'UNCOMMON', 'RARE', 'NOBLE', 'GODFORSAKEN'] as const;
  // **`ROSE`, not `ROSÉ` (0.8.0, K).** This probe list is not a display
  // vocabulary — the strings in it become the *keys* of the emitted table, and
  // every consumer looks up with `StyleColorType`'s rawValue, which is the
  // unaccented `ROSE` on both sides (`entryUtils.ts`'s `StyleColorType` union
  // and `EntryDisplay.StyleColorType` agree). `getColorTypeChipColors` answers
  // to either spelling, which is exactly what hid this: the generator asked with
  // the accent, got the right colours, and wrote them under a key nothing in the
  // app ever asks for. Every rosé style therefore missed the table and fell
  // through to `Palette.resolve`'s neutral stone — the chip said ROSE and was
  // grey, which reads as a styling choice rather than as a miss.
  //
  // This is the identical fault 0.6.9's I1 found on the grape colour chip (wrong
  // table *and* wrong case, 146 grapes grey), and the identical tell. The
  // lesson, written down this time: **a probe key is an identifier, and the only
  // safe source for one is the rawValue the reader uses.**
  const colorTypes = ['RED', 'WHITE', 'ROSE', 'ORANGE', 'DUAL'] as const;
  const styleClasses = ['STYLE', 'METHOD', 'ORIGIN', 'TYPE', 'BLEND'] as const;
  const flavorClasses = ['SWEET', 'SOUR', 'SALTY', 'BITTER', 'UMAMI'] as const;
  const flavorSubclasses = FLAVOR_SUBCLASS_KEYWORDS.map((k) => k.id);

  return {
    countryChips: probe(domain.origins, getCountryChipColors),
    classificationChips: probe(domain.classifications, getClassificationChipColors),
    wineTypeChips: probe(domain.wineTypes, getWineTypeChipColors),
    rarityChips: probe(rarities, getRarityChipColors),
    colorTypeChips: probe(colorTypes, getColorTypeChipColors),
    styleClassChips: probe(styleClasses, getStyleClassChipColors),
    flavorClassChips: probe(flavorClasses, getFlavorClassChipColors),
    flavorSubclassChips: probe(flavorSubclasses, getFlavorSubclassChipColors),
    namedChips: {
      SYSTEM: SYSTEM_CHIP_COLOR,
      CLIMATE: CLIMATE_CHIP_COLOR,
      BLUE: BLUE_CHIP_COLOR,
    },
    appellationChips: APPELLATION_CHIP_COLORS,
    styleTones: STYLE_TONE_PALETTE,
    climates: CLIMATE_CLASS_MAP,
    flavorClassMeta: FLAVOR_CLASS_COLORS,
    // Icon tints (colorUtils) — used by the region soil/classification sections
    // and the flavour subclass glyphs in EntryDetail.
    regionClassificationIconColors: Object.fromEntries(
      domain.classifications.map((key) => [key, getRegionClassificationIconColor(key)]),
    ),
    flavorSubclassIconColors: Object.fromEntries(
      flavorSubclasses.map((key) => [key, getFlavorSubclassIconColor(key)]),
    ),
    flagGradients: Object.fromEntries(
      domain.origins.map((origin) => [origin, getFlagGradient(origin)]),
    ),
    continentColors: Object.fromEntries(
      CONTINENTS.map((continent) => [continent.id.replace('CONT_', ''), continent.color]),
    ),
    /** continent -> countries. `keyRegions` holds country names despite the name. */
    continentCountries: Object.fromEntries(
      CONTINENTS.map((continent) => [
        continent.id.replace('CONT_', ''),
        continent.details.keyRegions,
      ]),
    ),
    /**
     * style id -> `StyleColorType`, as the *shared* `getColorType` answers it.
     *
     * **Not a lookup table — a pin (0.8.1, B).** Nothing reads this at runtime:
     * `EntryDisplay.colorType` re-derives, because `WineEntry.tileChips` has no
     * database in scope and the label scanner asks about names that are not in
     * the catalog. A port is the right shape here, and a port is also what
     * silently lost `STYLE_NAME_COLOR_OVERRIDES` for sixteen of thirty-three
     * styles. So the two ends are written down side by side and
     * `CoverageTests.styleColorTypesMatchShared` fails the moment they disagree
     * — in either direction, including a new override added here that the
     * Swift table never hears about.
     */
    styleColorTypes: Object.fromEntries(
      full
        .filter((entry) => entry.category === 'STYLES')
        .map((entry) => [entry.id, getColorType(entry.name)]),
    ),
  };
}

// ---------------------------------------------------------------------------
// Icon manifest
//
// Which icons the app actually needs is a function of the selected data, so it
// is derived here rather than hand-maintained. Everything is expressed as an
// Iconify id — flavours use `game-icons:*` via the web app's own resolver,
// while other categories use the lucide keys their entries carry, mapped onto
// Iconify's lucide set so a single fetch pipeline covers both.
// ---------------------------------------------------------------------------

const LUCIDE_ICONIFY: Record<string, string> = {
  castle: 'lucide:castle',
  circle: 'lucide:circle',
  citrus: 'lucide:citrus',
  cloud: 'lucide:cloud',
  droplet: 'lucide:droplet',
  flame: 'lucide:flame',
  flower: 'lucide:flower-2',
  fruit: 'lucide:apple',
  globe: 'lucide:globe',
  grape: 'lucide:grape',
  heart: 'lucide:heart',
  herb: 'lucide:sprout',
  honey: 'lucide:sparkles',
  leaf: 'lucide:leaf',
  mineral: 'lucide:gem',
  mountain: 'lucide:mountain',
  nut: 'lucide:triangle',
  oak: 'lucide:trees',
  shield: 'lucide:shield',
  smoke: 'lucide:wind',
  sparkles: 'lucide:sparkles',
  spice: 'lucide:flame',
  stone: 'lucide:mountain',
  sun: 'lucide:sun',
  triangle: 'lucide:triangle',
  tropical: 'lucide:citrus',
  zap: 'lucide:zap',
  default: 'lucide:grape',
  flag: 'lucide:flag',
};

const FALLBACK_ICON = 'mdi:help-circle-outline';

// Full-colour pixel-art portraits for flavours, keyed by normalised flavour
// name. Values are PNG stems under Sources/VinodexUI/Resources/FlavorArt —
// the art itself is imported from art/icons/entries/flavors by a one-off pass (see
// v0.5.1), not rasterised here; this table only keeps the wiring stable
// across regenerations. Names with no convincing art are deliberately absent
// and keep their tinted glyph.
const FLAVOR_ART: Record<string, string> = {
  'almond': 'almond',
  'alpine herbs': 'alpineherbs',
  'apricot': 'apricot',
  'banana': 'banana',
  'beeswax': 'beeswax',
  'bell pepper': 'greenbellpepper',
  'black cherry': 'blackcherry',
  'black fruit': 'blackberry',
  'black pepper': 'peppercorn',
  'black plum': 'blackplum',
  'blackberry': 'blackberry',
  // Own portrait since 0.5.7 — shared blackberry.png before.
  'blackberry jam': 'blackberry-jam',
  'blackcurrant': 'blackcurrant',
  'blueberry': 'blueberry',
  'cedar': 'cedar',
  'brioche': 'brioche',
  'butter': 'butter',
  'chalk': 'chalk',
  'chamomile': 'chamomile',
  'cherry': 'cherry',
  // The two bars shipped swapped in 0.5.1: chocolate.png *is* the dark bar.
  'chocolate': 'chocolate2',
  'cinnamon': 'cinnamon',
  'clove': 'clove',
  'cocoa': 'cocoa',
  'dark chocolate': 'chocolate',
  'dill': 'dill',
  'dried fig': 'driedfig',
  'dried herbs': 'driedherbs',
  'earth': 'earth',
  'espresso': 'coffee',
  'fennel': 'fennel',
  'fig': 'fig',
  'floral': 'whiteblossom',
  'fresh herbs': 'mint',
  'game': 'game',
  'ginger': 'ginger',
  'gooseberry': 'gooseberry',
  'grapefruit': 'grapefruit',
  'graphite': 'graphite',
  'grass': 'grass',
  'green apple': 'green-apple',
  'green pea': 'greenpea',
  'green pepper': 'greenbellpepper',
  'green peppercorn': 'greenpeppercorn',
  'hazelnut': 'hazelnut',
  'herb': 'driedherbs',
  'herbal tea': 'tealeaf',
  'herbs': 'driedherbs',
  'honey': 'honey',
  'honeysuckle': 'honeysuckle',
  // First art for this note (0.5.7) — it was the one flavour with none.
  'jammy berry': 'jammyberry',
  'jasmine': 'jasmine',
  'lanolin': 'lanolin',
  'leather': 'leather',
  'lemon': 'lemon',
  'lemon curd': 'lemoncurd',
  // Own portrait since 0.5.8 — borrowed lemon.png before.
  'lemon zest': 'lemonzest',
  'licorice': 'licorice',
  'lilac': 'lilac',
  'lime': 'lime',
  'lychee': 'lychee',
  'mango': 'mango',
  'marzipan': 'marzipan',
  'mineral': 'mineral',
  'nutmeg': 'nutmeg',
  'olive': 'olive',
  'orange blossom': 'orange-blossom',
  'peach': 'peach',
  'pear': 'pear',
  'pepper': 'peppercorn',
  'petrol': 'petrol',
  'pineapple': 'pineapple',
  'plum': 'plum',
  'pomegranate': 'pomegranate',
  'quince': 'quince',
  'raspberry': 'raspberry',
  'red apple': 'red-apple',
  'red cherry': 'cherry',
  'rose': 'redrose',
  'rose petal': 'rosepetal',
  'sage': 'sage',
  'saline': 'saline',
  'sea breeze': 'seabreeze',
  'sea salt': 'seasalt',
  'sea spray': 'seaspray',
  'smoke': 'smoke',
  // Own portrait since 0.5.7 — shared smoke.png before.
  'smoky spice': 'smokyspice',
  'sour cherry': 'sour-cherry',
  'spice': 'peppercorn',
  'stone': 'stone',
  'strawberry': 'strawberry',
  // Own portrait since 0.5.7 — shared strawberry.png before.
  'strawberry candy': 'strawberrycandy',
  'tangerine': 'orange',
  'tar': 'tar',
  'tea leaf': 'tealeaf',
  'tobacco': 'tobaccoleaf',
  'tomato': 'tomato',
  'tomato leaf': 'tomatoleaf',
  'vanilla': 'vanilla',
  'violet': 'violet',
  'volcanic ash': 'volcanicash',
  'white blossom': 'whiteblossom',
  'white flower': 'whiteblossom',
  'white peach': 'white-peach',
  'white pepper': 'whitepepper',
  'yuzu citrus': 'yuzu',
};

// Fixed icon sets used by the detail screen's three-tile header, transcribed
// from EntryDetail.tsx and climateDisplay.tsx.
//
// `art:` ids (v0.5.7, B1) name drawn pixel art rather than Iconify glyphs:
// `art:<stem>` loads `<stem>.png` from Resources/ClassArt, imported from
// art/icons/entries/{classes,subclasses,color,body,climate,soil,countries} by
// scripts/import-class-art.py. The Swift side
// branches on the prefix in `DexIcon`; these ids never reach the Iconify
// rasteriser (`unique` excludes them below).
//
// Light-Medium and Medium-Full keep their tinted glyphs — the drawn set
// covers only the three anchor weights so far.
const BODY_ICONS: Record<string, string> = {
  Light: 'art:body-light',
  'Light-Medium': 'game-icons:weight-scale',
  Medium: 'art:body-medium',
  'Medium-Full': 'game-icons:weight-lifting-up',
  Full: 'art:body-full',
};

const CLIMATE_ICONS: Record<string, string> = {
  maritime: 'art:climate-maritime',
  continental: 'art:climate-continental',
  cool: 'art:climate-cool',
  warm: 'art:climate-warm',
  mediterranean: 'art:climate-mediterranean',
};

const COLOR_ICONS: Record<string, string> = {
  RED: 'art:color-red',
  WHITE: 'art:color-white',
  ROSE: 'art:color-rose',
  ORANGE: 'art:color-orange',
  DUAL: 'art:color-dual',
};

/// Drawn glyphs for the flavour taxonomy (v0.5.7, B1) — used ahead of the
/// web app's Iconify resolvers in `buildIconManifest`, which stay as the
/// fallback so a future class/subclass still renders something while its art
/// is pending (and trips the duplicate-glyph assertion, which is the signal
/// to draw it).
const FLAVOR_CLASS_ART: Record<string, string> = {
  SWEET: 'art:class-sweet',
  SOUR: 'art:class-sour',
  BITTER: 'art:class-bitter',
  UMAMI: 'art:class-umami',
  SALTY: 'art:class-salty',
};

const FLAVOR_SUBCLASS_ART: Record<string, string> = {
  BERRY: 'art:subclass-berry',
  CITRUS: 'art:subclass-citrus',
  TROPICAL: 'art:subclass-tropical',
  ORCHARD_FRUIT: 'art:subclass-orchard-fruit',
  STONE_FRUIT: 'art:subclass-stone-fruit',
  RED_FRUIT: 'art:subclass-red-fruit',
  DARK_FRUIT: 'art:subclass-dark-fruit',
  HERBAL: 'art:subclass-herbal',
  VEGETAL: 'art:subclass-vegetal',
  NUT: 'art:subclass-nut',
  BAKING: 'art:subclass-baking',
  BREAD: 'art:subclass-bread',
  WAX: 'art:subclass-wax',
  EARTH: 'art:subclass-earth',
  SMOKY: 'art:subclass-smoky',
  SPICE: 'art:subclass-spice',
  SAVORY: 'art:subclass-savory',
  BRINY: 'art:subclass-briny',
  SALTY: 'art:subclass-salty',
  FLORAL: 'art:subclass-floral',
  GAME: 'art:subclass-game',
  WOOD: 'art:subclass-wood',
};

// Per-category visual tables, transcribed from entryIconVisuals.tsx. The rules
// that consume them live in Swift (EntryVisual.swift); only the lookups are
// generated, so the tables cannot drift from the web app while the rules stay
// readable and tweakable natively.

/// Style entries take their glyph from their classification, not their icon key.
///
/// The web app also carries a `STYLE_ICON_MAP` keyed on the entry's own icon
/// key, but it is unreachable: `getStyleIconShape` tries the class icon first,
/// and every style resolves to one of TYPE/BLEND/ORIGIN/METHOD, all of which
/// have one. It is also mostly invalid — 15 of its 24 names (`game-icons:leaf`,
/// `:droplet`, `:zap`, `:question-mark`, …) do not exist in the icon set. Not
/// ported. `STYLE` is included here so all five classes resolve to something
/// real even though no current entry reaches it.
const STYLE_CLASS_ICONS: Record<string, string> = {
  TYPE: 'art:styleclass-type',
  BLEND: 'art:styleclass-blend',
  ORIGIN: 'art:styleclass-origin',
  METHOD: 'art:styleclass-method',
  // Unreachable (see above) and unillustrated — the glyph survives so the
  // table stays total.
  STYLE: 'game-icons:wine-glass',
};

/// The drawn country/state outlines (v0.5.7, B3), keyed by normalised place
/// name — the region rows' glyph, replacing both the borrowed key-grape glyph
/// and the 0.5.6 masked-flag treatment. Covers every place in `FLAG_PATHS`,
/// states included; `buildIconManifest` filters it to the places actually
/// present, same as the flags.
const COUNTRY_SHAPE_ICONS: Record<string, string> = {
  france: 'art:outline-france',
  germany: 'art:outline-germany',
  italy: 'art:outline-italy',
  greece: 'art:outline-greece',
  portugal: 'art:outline-portugal',
  spain: 'art:outline-spain',
  hungary: 'art:outline-hungary',
  austria: 'art:outline-austria',
  croatia: 'art:outline-croatia',
  california: 'art:outline-california',
  oregon: 'art:outline-oregon',
  washington: 'art:outline-washington',
  'new york': 'art:outline-new-york',
  georgia: 'art:outline-georgia',
  switzerland: 'art:outline-switzerland',
  romania: 'art:outline-romania',
  'south africa': 'art:outline-south-africa',
  morocco: 'art:outline-morocco',
  usa: 'art:outline-usa',
  canada: 'art:outline-canada',
  argentina: 'art:outline-argentina',
  chile: 'art:outline-chile',
  uruguay: 'art:outline-uruguay',
  'new zealand': 'art:outline-new-zealand',
  australia: 'art:outline-australia',
  japan: 'art:outline-japan',
  china: 'art:outline-china',
  india: 'art:outline-india',
  // 0.7.9 (E). Both had regions and no outline since they were added — R117
  // Serra Gaucha and R118 Campanha Gaucha for Brazil, R098 Valle de Guadalupe
  // for Mexico — so three region pages drew nothing where the dotted map goes.
  brazil: 'art:outline-brazil',
  mexico: 'art:outline-mexico',
  // 0.8.4 (F1). The hand-drawn drop covers sixteen places beyond the thirty,
  // and these three are the ones the catalog already names: all three are
  // `keyRegions` on their continent, and Slovenia is an entry origin outright
  // (Blaufrankisch moved there in 0.7.9). They were the standing backlog
  // `CoverageTests.regionsHaveOutlineArt` records as *latent* — a flag and a
  // blurb but no shape — and they are latent no longer. Bulgaria is the fourth
  // and stays latent: nobody has drawn it.
  //
  // None of the three has a region, so no coverage gate demanded them. That is
  // the argument for adding them rather than against it: a place is reachable
  // through its continent's key-region list long before it has a region page,
  // and until now those three reached it and drew nothing.
  slovenia: 'art:outline-slovenia',
  lebanon: 'art:outline-lebanon',
  'united kingdom': 'art:outline-united-kingdom',
};

/// Icon-well background per style classification.
const STYLE_CLASS_BG: Record<string, string> = {
  METHOD: '#312e81',
  ORIGIN: '#7c2d12',
  TYPE: '#0f172a',
  STYLE: '#064e3b',
  BLEND: '#1d1b47',
};

/// Glyph tint per wine colour family.
const STYLE_COLOR_TYPE_COLORS: Record<string, string> = {
  RED: '#dc2626',
  WHITE: '#ffffff',
  ROSE: '#ec4899',
  ORANGE: '#f97316',
  DUAL: '#3b82f6',
};

/// Soil chips on the region screen. Keyword-matched (`soilDisplay.tsx`), so the
/// matching rule lives in Swift and only the table is generated.
// Soil keyword -> glyph. Every soil term that appears in the data needs a
// keyword here; anything unmatched renders as the default mountain, which reads
// as a bug rather than a fallback. `alluvial`, `shale`, `loess`, `laterite`,
// `basalt` and `loam` were all landing on the default until they were added.
//
// KEY ORDER IS SIGNIFICANT. Matching is first-substring-wins, so more specific
// terms must precede the ones they contain, and `clay` must precede `loam` so
// "clay loam" reads as clay. The order is exported as `soilKeywords` and the
// Swift side iterates that, rather than keeping its own copy in sync.
const SOIL_ICONS: Record<string, { icon: string; color: string }> = {
  volcanic: { icon: 'art:soil-volcanic', color: '#FF4500' },
  basalt: { icon: 'art:soil-basalt', color: '#2F4F4F' },
  clay: { icon: 'art:soil-clay', color: '#B5651D' },
  loam: { icon: 'art:soil-loam', color: '#8B5A2B' },
  sand: { icon: 'art:soil-sand', color: '#F4A460' },
  limestone: { icon: 'art:soil-limestone', color: '#E0E0E0' },
  chalk: { icon: 'art:soil-chalk', color: '#EDEDED' },
  slate: { icon: 'art:soil-slate', color: '#708090' },
  shale: { icon: 'art:soil-shale', color: '#6B7B8C' },
  schist: { icon: 'art:soil-schist', color: '#5F7A8A' },
  granite: { icon: 'art:soil-granite', color: '#A9A9A9' },
  gravel: { icon: 'art:soil-gravel', color: '#696969' },
  alluvial: { icon: 'art:soil-alluvial', color: '#6CA0DC' },
  loess: { icon: 'art:soil-loess', color: '#C2B280' },
  laterite: { icon: 'art:soil-laterite', color: '#A0522D' },
  default: { icon: 'art:soil-default', color: '#8B4513' },
};

/// Match order for `SOIL_ICONS`, minus the fallback. Exported so the Swift
/// matcher does not carry a second, drifting copy of the keyword list.
const SOIL_KEYWORDS = Object.keys(SOIL_ICONS).filter((k) => k !== 'default');

/// Regions without an explicit `soilType` fall back to a climate-keyed triplet.
const CLIMATE_SOIL_FALLBACK: Record<string, string[]> = {
  maritime: ['Alluvial', 'Clay', 'Sand'],
  continental: ['Limestone', 'Loess', 'Gravel'],
  cool: ['Limestone', 'Slate', 'Alluvial'],
  warm: ['Alluvial', 'Sand', 'Clay'],
  mediterranean: ['Limestone', 'Clay', 'Gravel'],
};

const DEFAULT_SOILS = ['Alluvial', 'Clay', 'Limestone'];

/// Pixel flags live in `shared/pixelflags/<Continent>/<slug>/<slug>.png` — the
/// cross-repo master (HGapps\shared, mirrored here by sync-shared.ps1),
/// because the web app consumes the same set. The values below are relative to
/// that root and are shared with the web consumer, so they do not change when
/// the root moves.
///
/// R74n's pack is non-commercial without permission (auditS H2), so a
/// first-party standby set exists at `art/flags/<slug>.png` (drawn by
/// `scripts/generate-flag-art.py`, named by the `flagSlug()` values below).
/// Development builds still ship the R74n pack — permission for the paid
/// release has been requested from R74n (2026-08-06); if it is refused,
/// `rasterize-icons.sh` flips its flag source to the standby set.
///
/// Originally just the countries that appeared as a grape/region `origin` in
/// the starter selection. Now also covers every country the continent info
/// screen lists (`data/continents.ts`' `keyRegions`), even where no grape or
/// region in the curated selection happens to originate there — the
/// continent screen shows every country in its list, not just the linked
/// ones, and `FlagImage` only falls back to a plain swatch when a country is
/// missing here entirely.
const FLAG_PATHS: Record<string, string> = {
  France: 'Europe/france/france.png',
  Germany: 'Europe/germany/germany.png',
  Italy: 'Europe/italy/italy.png',
  Greece: 'Europe/greece/greece.png',
  Portugal: 'Europe/portugal/portugal.png',
  Spain: 'Europe/spain/spain.png',
  Hungary: 'Europe/hungary/hungary.png',
  Austria: 'Europe/austria/austria.png',
  Croatia: 'Europe/croatia/croatia.png',
  // US states, for the country screen's STATES section. Keyed by state name
  // alongside the countries because `FlagSwatch` looks up one flat table — a
  // state and a country never collide in this data.
  California: 'North America/united_states/california/california.png',
  Oregon: 'North America/united_states/oregon/oregon.png',
  Washington: 'North America/united_states/washington/washington.png',
  'New York': 'North America/united_states/new_york/new_york.png',
  Georgia: 'Europe/georgia_country/georgia_country_flag.png',
  Switzerland: 'Europe/switzerland/switzerland.png',
  Romania: 'Europe/romania/romania.png',
  // The coming-soon gates (0.6.4, batch 2): flags ship because the continent
  // rosters list them; no COUNTRY_SHAPE_ICONS on purpose — no outline art
  // exists and the shape map degrades gracefully without an entry.
  'United Kingdom': 'Europe/united_kingdom/united_kingdom.png',
  Slovenia: 'Europe/slovenia/slovenia.png',
  Bulgaria: 'Europe/bulgaria/bulgaria.png',
  Lebanon: 'Asia/lebanon/lebanon.png',
  'South Africa': 'Africa/south_africa/south_africa.png',
  Morocco: 'Africa/morocco/morocco.png',
  USA: 'North America/united_states/united_states.png',
  Canada: 'North America/canada/canada.png',
  Mexico: 'North America/mexico/mexico.png',
  Argentina: 'South America/argentina/argentina.png',
  // Brazil (0.7.3c). The pixel flag has been sitting in shared/pixelflags since
  // the flag drop; this line is all that was missing.
  Brazil: 'South America/brazil/brazil.png',
  Chile: 'South America/chile/chile.png',
  Uruguay: 'South America/uruguay/uruguay.png',
  'New Zealand': 'Oceania/new_zealand/new_zealand.png',
  Australia: 'Oceania/australia/australia.png',
  Japan: 'Asia/japan/japan.png',
  China: 'Asia/china/china.png',
  India: 'Asia/india/india.png',
};

// Full-colour pixel-art portraits for styles (0.5.6), keyed by normalised
// style name. Values are PNG stems under Sources/VinodexUI/Resources/StyleArt,
// imported from art/icons/entries/styles by scripts/import-style-art.py. All 32
// shipped styles are covered; `crubeaujolas` preserves the artist's spelling.
// The three 0.6 styles carry portraits derived from their nearest siblings
// (recolour passes over fullbodywhite/mediumbodyred/dessertwine) — distinct
// stems on purpose, so the artist can redraw them without touching the map.
const STYLE_ART: Record<string, string> = {
  'aromatic white': 'aromaticwhite',
  'bordeaux blend': 'bordeauxblend',
  'botrytis wine': 'botrytiswine',
  'champagne': 'champagne',
  // 0.7.9 (G). S033 and S034 arrived with sommbot's P1/P2 batch and
  // `CoverageTests.styleArtWiring` requires a portrait for every style but GSM
  // Blend. Both masters are **recolours of shipped siblings** rather than drawn
  // art -- madeira from port.png (ruby -> amber-brown, same fortified flask),
  // cava from prosecco.png (gold -> pale straw, same flute). Placeholders in
  // the house style; flagged in PLAN.md for an artist pass. They keep their
  // white backgrounds, so neither needs to join import-style-art.py's MASTERS.
  'cava': 'cava',
  'madeira': 'madeira',
  'cremant': 'cremant',
  'cru beaujolais': 'crubeaujolas',
  'dessert wine': 'dessertwine',
  'fortified wine': 'fortifiedwine',
  // The 0.6.5 newpass masters untangled the chillable/light-body knot: each
  // style finally owns a stem spelled like itself. Before this, 'light-body
  // red' wore the stem `chillablered` and 'chillable red' wore
  // `freshchillablered` — an artefact of the 0.6.x rename that made every
  // art drop a puzzle. `freshchillablered` is orphaned and pruned.
  'chillable red': 'chillablered',
  'full-body red': 'fullbodyred',
  'full-body white': 'fullbodywhite',
  // GSM Blend deliberately has NO portrait (0.6.4, D1). The 0.6.2 swap to the
  // BLEND class glyph landed in `byEntry` but was invisible: `EntryIconWell`
  // draws `artName` over `iconID`, so the portrait covered the glyph
  // everywhere. Dropping the portrait is what makes the swap actually render.
  'ice wine': 'icewine',
  'late harvest': 'lateharvest',
  // See the chillable-red note above: its own stem since 0.6.5.
  'light-body red': 'lightbodyred',
  'light-body white': 'lightbodywhite',
  'medium-body red': 'mediumbodyred',
  'medium-body white': 'mediumbodywhite',
  'sweet white': 'sweetwhite',
  'natural wine': 'naturalwine',
  'noble grapes': 'noblegrape',
  'orange wine': 'orangewine',
  'petillant naturel': 'petnat',
  'port': 'port',
  'prosecco': 'prosecco',
  'qvevri amber': 'qvevriamber',
  'rose': 'rose',
  'sherry': 'sherry',
  'sparkling red': 'sparklingred',
  'sparkling wine': 'sparklingwine',
  'super tuscan': 'supertuscan',
};

/**
 * Grape bunch sprites (0.5.4): one bunch recoloured across colour x depth x
 * blend, leaf coloured by rarity — see `GrapeArt` on the Swift side, which
 * derives the keys. The sprite set covers the combos that occur in practice;
 * this fills the full 2x3x3x3 grid with the nearest available sprite so every
 * derivable key resolves. Stems are PNGs under Resources/GrapeArt, written by
 * scripts/import-grape-art.py.
 */
function buildGrapeArt(): Record<string, string> {
  // Keys are `<color>-<depth>-<blend>` — no leaf since 0.6.2 (A2): the leaf
  // is recoloured per rarity in code (`GrapeSpriteLoader`), so every key
  // resolves to ONE base sprite. The `-rare` files are the bases on purpose:
  // their leaf is the one part drawn in yellow, which is what makes it
  // separable from green berries at recolour time.
  const stemFor = (color: string, depth: string, blend: string): string => {
    if (blend === 'none') return `${color}-${depth}-rare`;
    const blendColor = color === 'gold' ? 'green' : color;
    // The blends ship at one depth each; depth falls back to what exists.
    if (blendColor === 'green' && blend === 'amber') return 'green-amber-rare';
    if (blendColor === 'red' && blend === 'amber') return 'red-amber-medium-rare';
    if (blendColor === 'red' && blend === 'pink') return 'red-pink-rare';
    // Green pink: the light rare is the cleaner of the two sources.
    return depth === 'light' ? 'green-pink-light-rare' : 'green-pink-rare';
  };

  const out: Record<string, string> = {};
  for (const color of ['green', 'red', 'gold']) {
    for (const depth of ['light', 'medium', 'full']) {
      for (const blend of ['none', 'pink', 'amber']) {
        out[`${color}-${depth}-${blend}`] = stemFor(color, depth, blend);
      }
    }
  }
  return out;
}

/// Drawn per-continent globes (v0.5.8, B1) — art/icons/entries/continents via
/// import-class-art.py. Each continent finally gets its own face; the three
/// shared Iconify globes they replaced left Africa and Europe identical.
const CONTINENT_ICONS: Record<string, string> = {
  CONT_AFRICA: 'art:globe-africa',
  CONT_EUROPE: 'art:globe-europe',
  CONT_ASIA: 'art:globe-asia',
  CONT_OCEANIA: 'art:globe-oceania',
  CONT_NORTH_AMERICA: 'art:globe-north-america',
  CONT_SOUTH_AMERICA: 'art:globe-south-america',
};

/**
 * Authored country blurbs for `CountryScreen`'s INFO block, keyed by country
 * name and by state name alike.
 *
 * COUNTRY_GATE is still not a shipped *category* — `EntryCategory` on the Swift
 * side cannot decode it, and a country page is assembled from region fields
 * rather than an entry. But the one thing that assembly genuinely could not
 * produce was prose: the screen was reduced to counting its own regions
 * ("France holds 12 regions in this database"), which is a readout, not
 * information. The descriptions are authored in `countries.ts`, so the web
 * country gate and the native country page say the same thing.
 *
 * Only places the app can actually navigate to are emitted, so the resource
 * does not carry fifty US states that no screen will ever ask for.
 */
function buildCountryInfo(entries: readonly WineEntry[]) {
  const reachable = new Set<string>();
  for (const entry of entries) {
    const details = entry.details as unknown as Record<string, unknown>;
    if (typeof details.origin === 'string') reachable.add(details.origin);
    if (typeof details.state === 'string') reachable.add(details.state);
    if (entry.category === 'CONTINENTS') {
      for (const country of entry.details.keyRegions) reachable.add(country);
    }
  }

  const info: Record<string, { description: string; appellationSystem?: string[] }> = {};
  for (const country of COUNTRIES) {
    if (!reachable.has(country.name)) continue;
    if (!country.description) continue;
    // The country's appellation system (0.6, A2) rides in the entry's tags
    // alongside the COUNTRY marker — strip the marker, ship the system.
    const system = (country.tags ?? []).filter((t) => t !== 'COUNTRY');
    info[country.name] = {
      description: country.description,
      ...(system.length > 0 ? { appellationSystem: system } : {}),
    };
  }
  return info;
}

function buildIconManifest(entries: readonly WineEntry[]) {
  const byEntry: Record<string, string> = {};

  // Glyphs for the flavour taxonomy itself, keyed by the class/subclass values
  // actually present. Emitted per-dataset rather than as a fixed table so a new
  // subclass with no icon shows up in `assertCoverage` instead of shipping a
  // question mark on the flavour scan's SUBCLASS tile.
  const flavorClassIcons: Record<string, string> = {};
  const flavorSubclassIcons: Record<string, string> = {};
  for (const entry of entries) {
    if (entry.category !== 'FLAVORS') continue;
    const { classification, subclass } = entry.details;
    // Drawn art first (0.5.7); the web app's Iconify resolvers remain the
    // fallback for anything not yet illustrated.
    flavorClassIcons[classification] =
      FLAVOR_CLASS_ART[classification] ?? resolveFlavorClassIcon(classification);
    flavorSubclassIcons[subclass] =
      FLAVOR_SUBCLASS_ART[subclass] ?? resolveFlavorSubclassIcon(subclass);
  }

  for (const entry of entries) {
    if (entry.category === 'FLAVORS') {
      byEntry[entry.id] = resolveFlavorIcon(entry.name, entry.details.subclass) as string;
    } else if (CONTINENT_ICONS[entry.id]) {
      byEntry[entry.id] = CONTINENT_ICONS[entry.id]!;
    } else if (entry.id === 'S020') {
      // GSM Blend wears the BLEND class glyph (0.6.2, E1) — its authored
      // lucide circle said nothing a blend tile needed saying.
      byEntry[entry.id] = 'art:styleclass-blend';
    } else {
      byEntry[entry.id] = LUCIDE_ICONIFY[entry.icon ?? 'default'] ?? LUCIDE_ICONIFY.default!;
    }
  }

  // Only ship flags for countries that actually appear in the selection —
  // either as a grape/region/style origin, or listed by a continent's
  // COUNTRIES section (`keyRegions`, despite the name).
  const origins = new Set([
    ...entries
      .map((e) => (e.details as { origin?: string }).origin)
      .filter((o): o is string => typeof o === 'string'),
    ...entries
      .filter((e) => e.category === 'CONTINENTS')
      .flatMap((e) => (e.details as { keyRegions?: string[] }).keyRegions ?? []),
    // States too: the country screen's STATES section flies a state flag, and
    // `FlagSwatch` reads the same flat table for both.
    ...entries
      .map((e) => (e.details as { state?: string }).state)
      .filter((s): s is string => typeof s === 'string'),
  ]);
  const flags = Object.fromEntries(
    Object.entries(FLAG_PATHS).filter(([country]) => origins.has(country)),
  );

  // The bundled filename each flag lands under, decided here and only here
  // (AUDIT **L25**). The rule used to be written twice and shared by nobody:
  // `tr '[:upper:] ' '[:lower:]-'` in rasterize-icons.sh, which names the file
  // it copies, and `country.lowercased().replacingOccurrences(of: " ", …)` in
  // `IconManifest.flagSlug(for:)`, which names the file the app asks for. They
  // agree on all 29 current keys — every one is ASCII differing only by spaces
  // — and would part company on the first accented or punctuated country name,
  // producing a flag that is copied in and then never found. Both sides read
  // this table now, so there is nothing left to diverge.
  const flagSlugs = Object.fromEntries(
    Object.keys(flags).map((country) => [country, flagSlug(country)]),
  );

  // Only ship country shapes for countries actually present.
  const shapeIcons = Object.fromEntries(
    Object.entries(COUNTRY_SHAPE_ICONS).filter(([country]) =>
      [...origins].some((o) => o.toLowerCase() === country),
    ),
  );

  // `unique` is the Iconify rasterisation list (rasterize-icons.sh fetches
  // every id in it) — `art:` ids are bundled pixel art imported by
  // scripts/import-class-art.py and must not reach the fetcher.
  const unique = [
    ...new Set(
      [
        ...Object.values(byEntry),
        ...Object.values(BODY_ICONS),
        ...Object.values(CLIMATE_ICONS),
        ...Object.values(COLOR_ICONS),
        ...Object.values(STYLE_CLASS_ICONS),
        ...Object.values(flavorClassIcons),
        ...Object.values(flavorSubclassIcons),
        ...Object.values(shapeIcons),
        ...Object.values(SOIL_ICONS).map((v) => v.icon),
        'game-icons:fluffy-cloud', // climate fallback
        // The GODFORSAKEN rarity emblem (0.6.4, D3) — the entry screen's
        // rarity readout wears a skull instead of the 0.6.2 flame. Referenced
        // by id from Swift (EntryDetailScreen), listed here so the rasteriser
        // ships it.
        'game-icons:death-skull',
        FALLBACK_ICON,
      ].filter((id) => !id.startsWith('art:')),
    ),
  ].sort();

  return {
    byEntry,
    unique,
    fallback: FALLBACK_ICON,
    bodyIcons: BODY_ICONS,
    climateIcons: CLIMATE_ICONS,
    colorIcons: COLOR_ICONS,
    styleClassIcons: STYLE_CLASS_ICONS,
    flavorClassIcons,
    flavorSubclassIcons,
    flavorArt: FLAVOR_ART,
    grapeArt: buildGrapeArt(),
    styleArt: STYLE_ART,
    countryShapeIcons: shapeIcons,
    styleClassBg: STYLE_CLASS_BG,
    styleColorTypeColors: STYLE_COLOR_TYPE_COLORS,
    soilIcons: SOIL_ICONS,
    soilKeywords: SOIL_KEYWORDS,
    climateSoilFallback: CLIMATE_SOIL_FALLBACK,
    defaultSoils: DEFAULT_SOILS,
    flags,
    flagSlugs,
  };
}

/// The one country -> bundled-flag-filename rule (AUDIT **L25**).
///
/// Deliberately wider than the two implementations it replaces: they lowercased
/// and turned spaces into hyphens, which is all the current keys need, and
/// nothing at all for `Côte d'Ivoire` or `Bosnia & Herzegovina`. Diacritics are
/// folded and every other run of non-alphanumerics collapses to one hyphen, so
/// the answer is always a safe filename. On today's 29 keys the output is
/// byte-identical to what both old rules produced — no flag is renamed by this.
function flagSlug(country: string): string {
  return country
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

// ---------------------------------------------------------------------------
// Coverage assertions — these are the guardrails the plan calls for. A data
// swap that silently drops a UI state should fail the build, not ship.
// ---------------------------------------------------------------------------

class CoverageError extends Error {}

function assertCoverage(entries: readonly WineEntry[], palette: ReturnType<typeof buildPalette>) {
  const failures: string[] = [];
  const check = (label: string, ok: boolean, detail = '') => {
    if (!ok) failures.push(`${label}${detail ? ` — ${detail}` : ''}`);
  };

  const grapes = entries.filter((e) => e.category === 'GRAPES');
  const regions = entries.filter((e) => e.category === 'REGIONS');
  const styles = entries.filter((e) => e.category === 'STYLES');
  const flavors = entries.filter((e) => e.category === 'FLAVORS');

  // Rarity tiers
  const tiers = new Set(grapes.map((g) => (g.category === 'GRAPES' ? g.rarity : undefined)));
  for (const tier of ['COMMON', 'UNCOMMON', 'RARE', 'NOBLE', 'GODFORSAKEN']) {
    check(`rarity tier ${tier} missing`, tiers.has(tier as never));
  }

  // Climates
  const climates = new Set(
    regions.map((r) => (r.category === 'REGIONS' ? r.climate : undefined)).filter(Boolean),
  );
  for (const climate of ['maritime', 'continental', 'cool', 'warm', 'mediterranean']) {
    check(`climate ${climate} missing`, climates.has(climate as never));
  }

  // Style classifications, via the same inference the UI uses.
  //
  // Only four of the five StyleClassType values are reachable from the current
  // database: TYPE, METHOD, ORIGIN, BLEND. Plain 'STYLE' is the fallback branch
  // and no entry reaches it — `classification: "STYLE"` in the data is *not* an
  // override (only ORIGIN/METHOD/TYPE/BLEND are), so those names fall through to
  // keyword matching, and TYPE_KEYWORDS contains 'red'/'white'/'aromatic'/
  // 'full-body', which catches all of them. Asserting on 'STYLE' would be
  // unsatisfiable.
  const styleClasses = new Set(
    styles.map((s) =>
      getStyleClassType(s.name, s.category === 'STYLES' ? s.details.classification : undefined),
    ),
  );
  for (const cls of ['TYPE', 'METHOD', 'ORIGIN', 'BLEND']) {
    check(`style class ${cls} missing`, styleClasses.has(cls as never));
  }

  // Every globe marker must resolve to at least one region — resolved through
  // continents.ts rather than assumed. This is the assertion that catches a
  // pick like Kakheti, whose country is filed under Europe rather than Asia.
  const regionOrigins = regions.map((r) =>
    'origin' in r.details ? String(r.details.origin ?? '').toLowerCase() : '',
  );
  for (const [continent, countries] of Object.entries(palette.continentCountries)) {
    const hit = (countries as string[]).some((country) =>
      regionOrigins.includes(country.toLowerCase()),
    );
    check(`continent ${continent} has no region`, hit, `countries: ${(countries as string[]).join(', ')}`);
  }

  // Flavours must be derived from the grapes that ship, not selected or
  // filtered independently of them. `buildFlavorEntries` emits exactly one
  // FLAVORS entry per distinct tasting note (trimmed, lowercased) across its
  // input grapes, so the two counts must agree: shipped flavours above the
  // note count mean flavour derivation ran over grapes that were then
  // deselected; below it, that flavours were filtered on their own. Holds
  // under any selection — the 40-75 band it replaces was gated on a curated
  // STARTER_SELECTION and died with it (audit B10).
  const grapeNotes = new Set(
    grapes.flatMap((g) =>
      ((g as { tastingProfile?: { note: string }[] }).tastingProfile ?? []).map((f) =>
        f.note.trim().toLowerCase(),
      ),
    ),
  );
  grapeNotes.delete('');
  check(
    `flavor count ${flavors.length} != ${grapeNotes.size} distinct grape tasting notes`,
    flavors.length === grapeNotes.size,
    'flavours must derive from the shipped grape set, nothing more or less',
  );

  // Every flavour class and subclass must own a glyph, and no two may share
  // one: the scan's CLASS and SUBCLASS tiles sit side by side, so a duplicate
  // reads as a rendering bug and the fallback reads as a missing asset.
  //
  // Levels are qualified by kind rather than by name: SALTY is both a class and
  // a subclass, and they are two levels that each need a glyph of their own.
  const flavorGlyphs = new Map<string, string>();
  for (const flavor of flavors) {
    if (flavor.category !== 'FLAVORS') continue;
    // Resolved the same way `buildIconManifest` resolves them — art first,
    // Iconify fallback — so this asserts on what actually ships.
    for (const [kind, value, icon] of [
      [
        'class',
        flavor.details.classification,
        FLAVOR_CLASS_ART[flavor.details.classification]
          ?? resolveFlavorClassIcon(flavor.details.classification),
      ],
      [
        'subclass',
        flavor.details.subclass,
        FLAVOR_SUBCLASS_ART[flavor.details.subclass]
          ?? resolveFlavorSubclassIcon(flavor.details.subclass),
      ],
    ] as const) {
      const level = `${kind} ${value}`;
      check(`flavor ${level} has no glyph`, icon !== FALLBACK_ICON);
      const owner = flavorGlyphs.get(icon);
      check(`flavor ${level} reuses ${icon}`, owner === undefined || owner === level, owner);
      flavorGlyphs.set(icon, level);
    }
  }

  // Every country a region names as its origin must have an authored INFO
  // blurb, or that country's page falls back to counting its own regions.
  const countryInfo = buildCountryInfo(entries);
  for (const origin of new Set(
    regions.map((r) => ('origin' in r.details ? String(r.details.origin ?? '') : '')).filter(Boolean),
  )) {
    check(`country ${origin} has no INFO blurb`, countryInfo[origin] !== undefined);
  }

  check('no grapes emitted', grapes.length > 0);
  check('no regions emitted', regions.length > 0);
  check('no styles emitted', styles.length > 0);

  if (failures.length > 0) {
    throw new CoverageError(`coverage assertions failed:\n  - ${failures.join('\n  - ')}`);
  }

  return { grapes, regions, styles, flavors, styleClasses, climates, tiers };
}

// ---------------------------------------------------------------------------

// AUDIT M4 / L18 — fields the Swift app never decodes, stripped from the shipped
// JSON to shrink the launch-time parse. The matching Swift properties were
// deleted alongside this (EntryCommon.icon/iconCallback/tileCallback and
// Palette.appellationChips/continentColors), so these keys are now unknown to
// every Codable type; grapeCard/grapeRarityTier/flagGradients/flavorClassMeta
// never had a Swift property at all.
const STRIP_ENTRY_FIELDS = ['grapeCard', 'grapeRarityTier', 'icon', 'iconCallback', 'tileCallback'];
const STRIP_PALETTE_FIELDS = ['flagGradients', 'flavorClassMeta', 'appellationChips', 'continentColors'];

// AUDIT L19 — ship minified JSON (the app decodes it identically) to drop ~⅓ of
// the on-disk/bundle size that 2-space pretty-printing added. Pass --pretty (or
// PRETTY=1) to emit readable JSON when eyeballing a data change.
const PRETTY = process.argv.includes('--pretty') || process.env.PRETTY === '1';
const serialize = (value: unknown): string =>
  (PRETTY ? JSON.stringify(value, null, 2) : JSON.stringify(value)) + '\n';

function omitKeys<T>(value: T, keys: string[]): T {
  if (Array.isArray(value)) return value.map((v) => omitKeys(v, keys)) as unknown as T;
  if (value && typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      if (!keys.includes(k)) out[k] = v;
    }
    return out as T;
  }
  return value;
}

// AUDIT M3 — generator-side decode smoke test. The Swift Codable structs used to
// decode all-or-nothing (entries are element-wise since 0.6.3), so a TS rename
// that drops a required key shipped as a whole-app decode failure with no earlier
// signal. This re-reads what was just written and asserts the shape the Swift
// structs require (non-optional keys only), failing the generate step — and
// therefore CI — before the drift ever reaches a device. The matching
// schemaVersion-asserted-at-load is `WineDatabase.expectedSchemaVersion`
// (0.6.3, item 1); bump BOTH constants together when the emitted shape changes
// incompatibly.
const SCHEMA_VERSION = 1;
const ENTRY_CATEGORIES = new Set(['GRAPES', 'REGIONS', 'STYLES', 'FLAVORS', 'CONTINENTS']);
const PALETTE_REQUIRED = [
  'countryChips', 'classificationChips', 'wineTypeChips', 'rarityChips', 'colorTypeChips',
  'styleClassChips', 'flavorClassChips', 'flavorSubclassChips', 'namedChips',
  'styleTones', 'climates', 'regionClassificationIconColors', 'flavorSubclassIconColors',
  'continentCountries', 'styleColorTypes',
];
const ICONS_REQUIRED = [
  'byEntry', 'unique', 'fallback', 'bodyIcons', 'climateIcons', 'colorIcons', 'styleClassIcons',
  'countryShapeIcons', 'styleClassBg', 'styleColorTypeColors', 'soilIcons', 'climateSoilFallback',
  'defaultSoils', 'flags',
];
// Optional on the Swift side — an older manifest still decodes without them —
// which is exactly why they need asserting *here*. Rename one in this file and
// nothing fails: `IconManifest.flavorArt` and friends just decode to `nil` and
// every affected entry silently drops back to a tinted glyph. Required at
// generation time, optional at decode time: forward compatibility for old data,
// no silent degradation for new. (AUDIT M3)
const ICONS_REQUIRED_NONEMPTY = [
  'flavorClassIcons', 'flavorSubclassIcons', 'flavorArt', 'grapeArt', 'styleArt', 'soilKeywords',
  // AUDIT **L25**. Both the rasteriser and the app now take the flag filename
  // from here rather than deriving it, so an empty or missing table is not a
  // degraded build — it is no flags at all on one side and wrong names on the
  // other.
  'flagSlugs',
];

// The non-optional properties of each Swift `*Entry` struct, by category. A key
// missing here is a key whose disappearance the self-check would not catch, so
// this list is the contract — keep it in step with `Sources/VinodexCore/WineEntry.swift`.
//
// `string`/`number` are checked by `typeof`; `array` and `object` by shape.
// Anything the Swift side declares optional (`String?`, `decodeIfPresent`) is
// deliberately absent: those are allowed to go missing.
type FieldKind = 'string' | 'number' | 'array' | 'object';
const ENTRY_COMMON_REQUIRED: Record<string, FieldKind> = {
  id: 'string', name: 'string', description: 'string', color: 'string', tags: 'array',
};
const ENTRY_REQUIRED: Record<string, Record<string, FieldKind>> = {
  GRAPES: {
    grapeType: 'string', grapeStyle: 'string', grapeBodyClass: 'string',
    grapeCharacteristics: 'object', grapeCountryOfOrigin: 'string', rarity: 'string',
    details: 'object',
  },
  REGIONS: { details: 'object' },
  STYLES: { details: 'object' },
  FLAVORS: { details: 'object' },
  CONTINENTS: { details: 'object' },
};
const DETAILS_REQUIRED: Record<string, Record<string, FieldKind>> = {
  GRAPES: { origin: 'string', synonyms: 'array', keyRegions: 'array', body: 'string' },
  REGIONS: { origin: 'string', notableGrapes: 'array', classification: 'string' },
  STYLES: {
    origin: 'string', keyRegions: 'array', notableGrapes: 'array', classification: 'string',
  },
  FLAVORS: { classification: 'string', subclass: 'string', notableGrapes: 'array' },
  CONTINENTS: { keyRegions: 'array' },
};
// `GrapeCharacteristics` — every bar is a non-optional `Double`.
const GRAPE_CHARACTERISTICS_REQUIRED: Record<string, FieldKind> = {
  tannin: 'number', acid: 'number', colorIntensity: 'number', aromatics: 'number', body: 'number',
};
// `TastingNote` — optional as a whole, but every element of a present array
// must carry all three, or the array's decode throws and takes the entry with it.
const TASTING_NOTE_REQUIRED: Record<string, FieldKind> = {
  note: 'string', icon: 'string', color: 'string',
};
// Enum-backed fields: Swift decodes these into `RawRepresentable` enums, so an
// unlisted value is a decode failure, not a fallback.
const ENTRY_ENUMS: Record<string, Set<string>> = {
  grapeType: new Set(['red', 'white']),
  rarity: new Set(['COMMON', 'UNCOMMON', 'RARE', 'NOBLE', 'GODFORSAKEN']),
  climate: new Set(['maritime', 'continental', 'cool', 'warm', 'mediterranean']),
};

function validateOutputs(dir: string, suffix = ''): void {
  const problems: string[] = [];
  const read = (name: string): unknown => JSON.parse(readFileSync(resolve(dir, name + suffix), 'utf8'));
  const has = (obj: unknown, key: string): boolean =>
    !!obj && typeof obj === 'object' && key in (obj as Record<string, unknown>);

  // Every non-optional key of the matching Swift struct, not a spot-check of
  // four (AUDIT M3). Anything absent from the tables above is optional on the
  // Swift side and is allowed to go missing.
  const checkFields = (
    where: string,
    rec: Record<string, unknown>,
    required: Record<string, FieldKind>,
  ): void => {
    for (const [key, kind] of Object.entries(required)) {
      const value = rec[key];
      const ok =
        kind === 'array'
          ? Array.isArray(value)
          : kind === 'object'
            ? !!value && typeof value === 'object' && !Array.isArray(value)
            : typeof value === kind;
      if (!ok) problems.push(`${where}.${key} missing or not ${kind}`);
    }
    // Enums are checked wherever they appear, required or not: Swift decodes
    // them into a `RawRepresentable`, so an unlisted value throws rather than
    // falling back.
    for (const [key, allowed] of Object.entries(ENTRY_ENUMS)) {
      const value = rec[key];
      if (value !== undefined && value !== null && !allowed.has(String(value))) {
        problems.push(`${where}.${key} not a known value: ${String(value)}`);
      }
    }
  };

  const entries = read('entries.json');
  if (!Array.isArray(entries) || entries.length === 0) {
    problems.push('entries.json is not a non-empty array');
  } else {
    entries.forEach((e, i) => {
      const rec = e as Record<string, unknown>;
      const category = rec.category;
      if (typeof category !== 'string' || !ENTRY_CATEGORIES.has(category)) {
        problems.push(`entries[${i}].category invalid: ${String(category)}`);
        return;
      }
      // Named by id once it is known to be a string — `entries[214]` sends the
      // reader counting through a 375-element file.
      const where = typeof rec.id === 'string' ? `entries[${rec.id}]` : `entries[${i}]`;

      // A category with no contract is itself the defect: someone added a
      // `WineEntry` variant and left the self-check behind, so every field of
      // every entry in it would go unchecked. Say so rather than skip it.
      const required = ENTRY_REQUIRED[category];
      const detailsRequired = DETAILS_REQUIRED[category];
      if (!required || !detailsRequired) {
        problems.push(`${where}: no schema contract for category ${category}`);
        return;
      }

      checkFields(where, rec, ENTRY_COMMON_REQUIRED);
      checkFields(where, rec, required);

      const details = rec.details;
      if (details && typeof details === 'object' && !Array.isArray(details)) {
        checkFields(`${where}.details`, details as Record<string, unknown>, detailsRequired);
      }

      const chars = rec.grapeCharacteristics;
      if (chars && typeof chars === 'object') {
        checkFields(
          `${where}.grapeCharacteristics`,
          chars as Record<string, unknown>,
          GRAPE_CHARACTERISTICS_REQUIRED,
        );
      }

      // Optional as a whole; strict once present. One note missing its `icon`
      // fails the array's decode, which fails the entry.
      const profile = rec.tastingProfile;
      if (Array.isArray(profile)) {
        profile.forEach((note, n) => {
          if (!note || typeof note !== 'object') {
            problems.push(`${where}.tastingProfile[${n}] is not an object`);
            return;
          }
          checkFields(
            `${where}.tastingProfile[${n}]`,
            note as Record<string, unknown>,
            TASTING_NOTE_REQUIRED,
          );
        });
      } else if (profile !== undefined && profile !== null) {
        problems.push(`${where}.tastingProfile is not an array`);
      }
    });
  }

  const palette = read('palette.json');
  for (const key of PALETTE_REQUIRED) {
    if (!has(palette, key)) problems.push(`palette.json missing required key: ${key}`);
  }

  const icons = read('icons.json');
  for (const key of ICONS_REQUIRED) {
    if (!has(icons, key)) problems.push(`icons.json missing required key: ${key}`);
  }
  // Optional at decode time, required here — see `ICONS_REQUIRED_NONEMPTY`.
  // Emptiness is the check that matters: a renamed *source* table would leave
  // the key present and the object empty, which decodes cleanly and drops
  // every entry back to a tinted glyph without a word of complaint.
  for (const key of ICONS_REQUIRED_NONEMPTY) {
    const value = (icons as Record<string, unknown> | null)?.[key];
    const count = Array.isArray(value)
      ? value.length
      : value && typeof value === 'object'
        ? Object.keys(value).length
        : -1;
    if (count < 0) problems.push(`icons.json missing required table: ${key}`);
    else if (count === 0) problems.push(`icons.json table is empty: ${key}`);
  }

  const tiers = read('tiers.json');
  // Emptiness matters as much as presence: `{"free":[]}` decodes cleanly on
  // device and unlocks every entry through the fail-open `freeIDs.isEmpty`
  // short-circuit in WineDatabase (auditS L6).
  const free = (tiers as { free?: unknown } | null)?.free;
  if (!Array.isArray(free) || free.length === 0) {
    problems.push('tiers.json missing or empty free[]');
  } else if (Array.isArray(entries)) {
    // A free id that names no entry is silent drift — `isFree` returns false
    // for an id nobody looks up, quietly shrinking the free tier (auditS L17).
    const ids = new Set(entries.map((e) => (e as { id?: unknown }).id));
    for (const id of free) {
      if (!ids.has(id)) problems.push(`tiers.json free id has no entry: ${String(id)}`);
    }
  }

  const countries = read('countries.json');
  if (!countries || typeof countries !== 'object') {
    problems.push('countries.json is not an object');
  }

  const schema = read('schema.json');
  if (!has(schema, 'schemaVersion') || (schema as { schemaVersion?: unknown }).schemaVersion !== SCHEMA_VERSION) {
    problems.push(`schema.json missing/wrong schemaVersion (expected ${SCHEMA_VERSION})`);
  }

  const firmware = read('firmware.json');
  if (!has(firmware, 'version') || !has(firmware, 'releases')) {
    problems.push('firmware.json missing version/releases');
  }

  // `ExamCatalog`'s non-optional keys. `assertExam` has already validated the
  // bank's *contents*; this checks the envelope actually reached disk, which is
  // the half a rename in this file would break silently.
  const exam = read('exam.json');
  for (const key of ['questions', 'tiers', 'categories', 'formats', 'categoryLabels', 'tierLabels', 'minCellCount']) {
    if (!has(exam, key)) problems.push(`exam.json missing ${key}`);
  }
  const questions = (exam as { questions?: unknown }).questions;
  if (!Array.isArray(questions) || questions.length === 0) {
    problems.push('exam.json questions is not a non-empty array');
  } else {
    // Every key `ExamQuestion.init(from:)` decodes unconditionally. The payload
    // keys are per-format and are checked by `assertExam`.
    for (const q of questions as Record<string, unknown>[]) {
      for (const key of ['id', 'tier', 'category', 'format', 'prompt', 'explanation']) {
        if (typeof q[key] !== 'string') problems.push(`exam.json ${String(q.id)}.${key} missing or not string`);
      }
    }
  }

  if (problems.length > 0) {
    throw new Error(
      `schema self-check failed — the Swift structs would not decode:\n  - ${problems.join('\n  - ')}`,
    );
  }
}

/**
 * The firmware changelog's own gate (0.7.3, F3).
 *
 * `firmware.json` is the only generated file whose contents nothing else in the
 * pipeline can check: an entry with a dangling grape reference trips
 * `find-missing-refs.mjs`, a missing palette key trips the self-check, but a
 * changelog is prose and prose validates against nothing. So the rules it *does*
 * have are asserted here, loudly, at generation time:
 *
 * - **Three dot-separated integers.** The scheme since iOS 0.4.3, and the shape
 *   `CFBundleShortVersionString` accepts. `AppVersionTests.versionShape` pins the
 *   same rule on the Swift side; this stops a bad number ever reaching it.
 * - **Newest first, strictly descending, no duplicates.** `FIRMWARE_VERSION` is
 *   `releases[0].version`, so an out-of-order list would silently ship the wrong
 *   number as the current one — the single failure this whole file exists to
 *   prevent.
 * - **ASCII throughout**, and `headline` uppercase and short. The panel's
 *   headings are Press Start 2P, which has a partial Latin-1 range; a curly
 *   apostrophe pasted out of a spec would render as a blank box on the device's
 *   most-read panel and nothing would say so.
 * - **Every release has notes.** A version with an empty body is a row that
 *   opens onto nothing.
 */
function assertFirmware(): void {
  const problems: string[] = [];
  const seen = new Set<string>();
  /** -1 / 0 / +1, comparing three-integer versions component by component. */
  const compare = (a: string, b: string): number => {
    const x = a.split('.').map(Number);
    const y = b.split('.').map(Number);
    for (let k = 0; k < Math.max(x.length, y.length); k += 1) {
      const d = (x[k] ?? 0) - (y[k] ?? 0);
      if (d !== 0) return Math.sign(d);
    }
    return 0;
  };

  const isAscii = (s: string) => [...s].every((c) => c.charCodeAt(0) >= 0x20 && c.charCodeAt(0) <= 0x7e);

  if (FIRMWARE_RELEASES.length === 0) problems.push('FIRMWARE_RELEASES is empty');

  FIRMWARE_RELEASES.forEach((release, i) => {
    const where = `FIRMWARE_RELEASES[${i}] (${release.version})`;
    const parts = release.version.split('.');
    if (parts.length !== 3 || parts.some((p) => p === '' || !/^\d+$/.test(p))) {
      problems.push(`${where}: version is not three dot-separated integers`);
    }
    if (seen.has(release.version)) problems.push(`${where}: duplicate version`);
    seen.add(release.version);

    if (!/^\d{4}-\d{2}-\d{2}$/.test(release.date)) {
      problems.push(`${where}: date is not ISO YYYY-MM-DD`);
    }
    if (release.headline !== release.headline.toUpperCase()) {
      problems.push(`${where}: headline must be uppercase`);
    }
    if (release.headline.length === 0 || release.headline.length > 24) {
      problems.push(`${where}: headline is ${release.headline.length} chars; the panel fits 24`);
    }
    if (!isAscii(release.headline)) problems.push(`${where}: headline is not printable ASCII`);
    if (release.notes.length === 0) problems.push(`${where}: no notes`);
    release.notes.forEach((note, n) => {
      if (note.trim().length === 0) problems.push(`${where}.notes[${n}]: empty`);
      if (!isAscii(note)) problems.push(`${where}.notes[${n}]: not printable ASCII — ${note}`);
    });

    // Bound once rather than indexed twice. `noUncheckedIndexedAccess` types
    // every element access as possibly-undefined, and `i > 0` does not narrow
    // an index expression — so the two reads below were the only two type
    // errors in this repo (0.7.5, D). Behaviour is unchanged: the guard was
    // already `i > 0`, and `previous` cannot be undefined when it holds.
    const previous = i > 0 ? FIRMWARE_RELEASES[i - 1] : undefined;
    if (previous && compare(previous.version, release.version) <= 0) {
      problems.push(
        `${where}: the list is newest-first, but ${previous.version} does not sort above it`,
      );
    }
  });

  if (FIRMWARE_VERSION !== FIRMWARE_RELEASES[0]?.version) {
    problems.push(`FIRMWARE_VERSION (${FIRMWARE_VERSION}) is not the head of the list`);
  }

  if (problems.length > 0) {
    throw new Error(`firmware changelog failed its own rules:\n  - ${problems.join('\n  - ')}`);
  }
}

/**
 * Country/state outline art must exist for every place a shipped region names
 * (0.7.5, D).
 *
 * **This is the gate that was missing.** `COUNTRY_SHAPE_ICONS` is a hand-kept
 * table and nothing checked it against the catalog, so a country could be added
 * — regions, prose, flag gradient, chip colour, pack membership — and simply
 * have no outline. `EntryVisual.regionVisual` degrades quietly to a climate
 * glyph, and `CountryOutlineMap` has no `else` at all: its `if let` fails and
 * the country page draws *nothing* where the dotted map belongs. Brazil (0.7.3c)
 * and Mexico both shipped that way, and both were found by reading rather than
 * by any gate. It is the third silent-missing-asset bug in three batches, after
 * `icon: "fruit"` (0.7.4) and the two logo layers (0.7.5, A5).
 *
 * **`OUTLINE_BACKLOG` is gone (0.7.9, E), which is what it was for.** It named
 * Brazil and Mexico, said they were a drawing job rather than a data one, and
 * carried the instruction "the list is meant to shrink to `[]`; when it does,
 * delete it and the `known`/`missing` split with it". Both outlines are drawn,
 * so the list, the split and the "known gap" concept are all deleted here: a
 * region naming a place with no outline is now simply a build failure, with no
 * spelling of the problem that lets it through.
 *
 * The two new silhouettes are rasterised from authored lon/lat rings rather
 * than drawn by hand, which the deleted note above warned would be "visibly not
 * of that set" — see the 0.7.9 entry in PLAN.md. They wear the set's treatment
 * (flat fill, one-cell black cel outline, specular mark) and are worth an
 * artist's eye, but a country page that draws nothing is the worse defect and
 * it is the one this batch was asked to fix.
 */
function assertOutlineCoverage(entries: readonly WineEntry[]): string[] {
  const label = (s: string) => s.toLowerCase().trim();
  const missing = new Map<string, string[]>();

  for (const entry of entries) {
    if (entry.category !== 'REGIONS') continue;
    const details = entry.details as { origin?: string; state?: string };
    const state = details.state ? label(details.state) : undefined;
    // State first, exactly as `EntryVisual.regionVisual` resolves it: a
    // Willamette row reads as Oregon, not as the whole USA.
    if (state && COUNTRY_SHAPE_ICONS[state]) continue;
    const place = label(details.origin || entry.name);
    if (COUNTRY_SHAPE_ICONS[place]) continue;
    const held = missing.get(place) ?? [];
    held.push(`${entry.id} ${entry.name}`);
    missing.set(place, held);
  }

  const unexpected = [...missing.keys()].sort();
  if (unexpected.length > 0) {
    throw new CoverageError(
      'regions name places with no outline art:\n'
        + unexpected.map((p) => `  - ${p}: ${(missing.get(p) ?? []).join(', ')}`).join('\n')
        + '\nDraw the outline into art/icons/entries/countries/ and wire it through '
        + 'COUNTRY_SHAPE_ICONS and scripts/import-class-art.py.',
    );
  }

  return unexpected;
}

/** Where the app's art actually lives. `assertAssetsExist` is its only reader. */
const UI_RESOURCES = resolve(REPO_ROOT, 'Sources', 'VinodexUI', 'Resources');

/**
 * The drawn-art search path, in order — mirrors `PixelArtLoader.subdirectories`
 * in Sources/VinodexUI/EntryVisual.swift. First hit wins there and here.
 */
const ART_DIRS = ['FlavorArt', 'GrapeArt', 'StyleArt', 'ClassArt', 'StampArt', 'StickerArt', 'ButtonArt'] as const;

/**
 * Every asset id this generator emits must resolve to a file the app can load
 * (0.7.5, A028).
 *
 * **The fourth silent-missing-asset bug is why this exists, and it was already in
 * the tree when the gate was written.** `icons.json` has named a Brazil flag
 * since 0.7.3c and nothing ever copied `brazil.png` into `Resources/Flags`, so
 * `FlagLoader` returned nil and every Brazilian row flew a blank swatch. Same
 * shape as `icon: "fruit"` (0.7.4 — an Iconify id that had never been
 * rasterised), the screensaver layers (0.7.5, A5) and the Brazil/Mexico outlines
 * (0.7.5, D): an id that resolves in *data* and to nothing on disk.
 *
 * The class is invisible to everything else the project runs. `IconLoader.image`
 * and `PixelArtLoader.image` both end in `return nil` with no diagnostic, over
 * 207 rasterised glyphs and five art directories; `swift test` cannot see the
 * art at all because it belongs to `VinodexUI`, which no Linux gate compiles;
 * and the clean `xtool dev build` cannot see it either, because a missing *file*
 * is not a compile error. On the phone it is a red `questionmark.square.dashed`
 * at best and empty space at worst.
 *
 * **Why here rather than in `verify-art.py`.** `icons:verify` re-runs the
 * importers into a temp tree with `ART_OUT` and diffs pixels: it answers "did the
 * committed art change", and it has no catalog, so it cannot know which ids are
 * *requested*. This function is the other half — it holds the manifest it just
 * built and checks it against the bundle. It is also the half that runs in CI:
 * the `data` job runs `npm run generate` on every push, while `icons:verify`
 * needs Pillow and is run by hand.
 *
 * **It runs after the writes, deliberately.** `rasterize-icons.sh` reads the
 * `unique` list out of `icons.json`, so a gate that threw before `writeFileSync`
 * would make a new icon id unbootstrappable — generate would refuse to emit the
 * manifest the rasteriser needs in order to produce the file generate is
 * demanding. With the write first, adding an icon is: generate (fails, naming the
 * id) → `npm run icons` → generate (passes).
 *
 * **No backlog list, on purpose.** `OUTLINE_BACKLOG` earns its existence because
 * drawing an outline to match the other 28 is a job that can be honestly
 * outstanding. Nothing checked here is: every id below is satisfied by `npm run
 * icons`, one command and no drawing. An allowlist with nothing in it is rot
 * waiting to happen. If a genuine stopgap is ever needed, copy `OUTLINE_BACKLOG`
 * whole — including the staleness check that fails when an entry stops being
 * missing.
 *
 * Returns how many ids were checked, for the summary.
 */
function assertAssetsExist(icons: ReturnType<typeof buildIconManifest>): number {
  const missing: string[] = [];
  let checked = 0;

  const want = (ok: boolean, what: string, where: string) => {
    checked += 1;
    if (!ok) missing.push(`${what} — expected ${where}`);
  };

  // Rasterised glyphs. `IconLoader.load(slug:)` walks @3x → @2x → the bare name
  // and takes the first that opens, so any one of the three is a working icon;
  // requiring all three would fail the icons that shipped before the variants
  // existed. `unique` is the complete Iconify surface by construction — every
  // non-`art:` id in every table is folded into it in `buildIconManifest`.
  for (const id of icons.unique) {
    const slug = id.replace(':', '--');
    const ok = ['@3x', '@2x', ''].some((variant) =>
      existsSync(resolve(UI_RESOURCES, 'Icons', `${slug}${variant}.png`)),
    );
    want(ok, id, `Sources/VinodexUI/Resources/Icons/${slug}.png`);
  }

  // Drawn art reached by `art:` id. Collected by walking the whole manifest
  // rather than by listing the tables that carry them: `byEntry`, `bodyIcons`,
  // `climateIcons`, `colorIcons`, `styleClassIcons`, `flavorClassIcons`,
  // `flavorSubclassIcons`, `countryShapeIcons` and `soilIcons` all do today, in
  // three different value shapes, and a hand-kept list of them is precisely the
  // thing that went stale in `COUNTRY_SHAPE_ICONS`. A walk covers the next table
  // for free.
  const artIDs = new Map<string, string>();
  const walk = (node: unknown, path: string): void => {
    if (typeof node === 'string') {
      if (node.startsWith('art:') && !artIDs.has(node)) artIDs.set(node, path);
    } else if (Array.isArray(node)) {
      node.forEach((child, i) => walk(child, `${path}[${i}]`));
    } else if (node && typeof node === 'object') {
      for (const [key, child] of Object.entries(node)) walk(child, `${path}.${key}`);
    }
  };
  walk(icons, 'icons');

  const artFile = (stem: string) =>
    ART_DIRS.some((dir) => existsSync(resolve(UI_RESOURCES, dir, `${stem}.png`)));

  for (const [id, path] of [...artIDs].sort()) {
    want(artFile(id.slice(4)), `${id} (${path})`, `${id.slice(4)}.png in one of ${ART_DIRS.join(', ')}`);
  }

  // The three portrait tables ship bare stems rather than `art:` ids — the well
  // loads them through the same `PixelArtLoader`, so they resolve the same way,
  // but the walk above cannot tell one from a caption. Named explicitly.
  for (const table of ['flavorArt', 'grapeArt', 'styleArt'] as const) {
    for (const stem of [...new Set(Object.values(icons[table]))].sort()) {
      want(artFile(stem), `${table}: ${stem}`, `${stem}.png in one of ${ART_DIRS.join(', ')}`);
    }
  }

  // Flags. `WineDatabase.flagSlug` lowercases and hyphenates; `rasterize-icons.sh`
  // derives the same slug with `tr` when it copies out of shared/pixelflags. The
  // *bundle* is what is checked, not the master — a present master that was never
  // copied is exactly the Brazil failure.
  for (const country of Object.keys(icons.flags).sort()) {
    const slug = country.toLowerCase().replace(/ /g, '-');
    want(
      existsSync(resolve(UI_RESOURCES, 'Flags', `${slug}.png`)),
      `flag: ${country}`,
      `Sources/VinodexUI/Resources/Flags/${slug}.png`,
    );
  }

  if (missing.length > 0) {
    throw new CoverageError(
      `${missing.length} of ${checked} emitted asset ids resolve to no file:\n`
        + missing.map((m) => `  - ${m}`).join('\n')
        + '\n\nicons.json has already been written, so the usual fix is:\n'
        + '  npm run icons      # rasterises glyphs, copies flags, runs the art importers\n'
        + '  npm run generate   # re-runs this gate\n'
        + 'A drawn-art id additionally needs its master under art/icons/ and a row in\n'
        + 'the importer that ships it (scripts/import-*-art.py).',
    );
  }

  return checked;
}

/**
 * The question bank's own gate (0.7.5, D).
 *
 * Written for the same reason `assertFirmware` was: `exam.json` is authored
 * prose in a shape nothing else in the pipeline can check. `find-missing-refs`
 * walks the *catalog* references (`entryRefs`, and the `entryIcon` image keys,
 * which are entry ids); this walks everything the generator itself owns — the
 * closed vocabularies, the per-format payload invariants, and the two asset
 * tables (`FLAVOR_ART`, `COUNTRY_SHAPE_ICONS`) that only exist in this file.
 *
 * The split is by ownership: a table defined here is checked here, a reference
 * into the catalog is checked against the catalog.
 *
 * ASCII is asserted on every *shipped* string. The question card is Press Start
 * 2P over VT323, both of which have partial Latin-1 coverage — a curly
 * apostrophe or an accented place name pasted from a source would render as a
 * blank box, exactly the failure `assertFirmware` exists to prevent one panel
 * over. The bank is already clean; this keeps it that way.
 */
/**
 * The two things about flavours that nothing else can see.
 *
 * **Ids.** Flavours are the only category whose ids are derived rather than
 * authored, and until 0.8.9 they were derived wrong — `FLAVOR-${idx + 1}`
 * inside a `Map.forEach`, where the second callback argument is the key, not
 * an index. Every id shipped as `FLAVOR-blackcurrant1` and 37 of 106 carried a
 * space. Nothing caught it because nothing reads a flavour id except
 * `Bookmarks`, on a user's disk, where an id it cannot resolve is *silently
 * dropped*. The shape is asserted here so the derivation cannot rot back: ids
 * are `FLAVOR-` plus a slug of the note, and they are unique. Uniqueness is
 * the load-bearing half — two notes slugging to one id would silently merge
 * two entries into one, and the count would still read 106 upstream.
 *
 * **`FLAVOR_ART` keys.** The table is keyed on the normalised *note name*, so
 * renaming a note in `grapes.ts` orphans its art with no error anywhere: the
 * entry simply falls back to a tinted glyph and looks deliberate. The exam
 * bank's `noteKey` arm already throws on a stale key (see `assertExam`), but
 * that only covers the 75 notes the exam happens to reference. This covers all
 * of them, which converts the whole rename class from silent to loud — and the
 * flavour rework's Batch C renames and retirements are exactly that class.
 */
function assertFlavorIds(entries: readonly WineEntry[]): void {
  const problems: string[] = [];
  const flavors = entries.filter((e) => e.category === 'FLAVORS');

  const seen = new Map<string, string>();
  for (const f of flavors) {
    if (!/^FLAVOR-[A-Z0-9]+(-[A-Z0-9]+)*$/.test(f.id)) {
      problems.push(`"${f.name}": id "${f.id}" is not FLAVOR- plus an uppercase slug`);
    }
    const prior = seen.get(f.id);
    if (prior !== undefined) {
      problems.push(`id "${f.id}" is shared by "${prior}" and "${f.name}" — two notes slug to one id`);
    } else {
      seen.set(f.id, f.name);
    }
  }

  // Both directions would be wrong to assert: a note with no art is the
  // documented default (see FLAVOR_ART's own comment — "names with no
  // convincing art are deliberately absent"). A *key* with no note is the
  // error, because it can only mean the note was renamed or retired out from
  // under it.
  const liveNotes = new Set(flavors.map((f) => f.name.trim().toLowerCase()));
  for (const key of Object.keys(FLAVOR_ART)) {
    if (!liveNotes.has(key)) {
      problems.push(`FLAVOR_ART key "${key}" names no live flavour — renamed or retired, and its art is orphaned`);
    }
  }

  if (problems.length) {
    throw new Error(`Flavour ids/art:\n  ${problems.join('\n  ')}`);
  }
}

function assertExam(): void {
  const problems: string[] = [];
  const tiers = new Set<string>(EXAM_TIERS);
  const categories = new Set<string>(EXAM_CATEGORIES);
  const formats = new Set<string>(EXAM_FORMATS);
  const seen = new Set<string>();
  const cells = new Map<string, number>();
  const perTier = new Map<string, number>();

  const isAscii = (s: string) => [...s].every((c) => c.charCodeAt(0) >= 0x20 && c.charCodeAt(0) <= 0x7e);
  const text = (where: string, field: string, value: string): void => {
    if (value.trim().length === 0) problems.push(`${where}: ${field} is empty`);
    if (!isAscii(value)) problems.push(`${where}: ${field} is not printable ASCII — ${value}`);
  };
  const list = (where: string, field: string, values: readonly string[], min: number): void => {
    if (values.length < min) problems.push(`${where}: ${field} has ${values.length}, needs >= ${min}`);
    values.forEach((v, i) => text(where, `${field}[${i}]`, v));
    if (new Set(values.map((v) => v.toLowerCase())).size !== values.length) {
      problems.push(`${where}: ${field} repeats an entry`);
    }
  };

  for (const q of EXAM_QUESTIONS as readonly ExamQuestion[]) {
    const where = `EXAM_QUESTIONS ${q.id}`;
    if (!/^EXQ-[A-Z]{3}-\d{3}$/.test(q.id)) problems.push(`${where}: id is not EXQ-XXX-nnn`);
    if (seen.has(q.id)) problems.push(`${where}: duplicate id`);
    seen.add(q.id);
    if (!tiers.has(q.tier)) problems.push(`${where}: unknown tier ${q.tier}`);
    if (!categories.has(q.category)) problems.push(`${where}: unknown category ${q.category}`);
    if (!formats.has(q.format)) problems.push(`${where}: unknown format ${q.format}`);
    text(where, 'prompt', q.prompt);
    text(where, 'explanation', q.explanation);
    if (q.source !== undefined) text(where, 'source', q.source);
    if (q.entryRefs !== undefined && q.entryRefs.length === 0) {
      problems.push(`${where}: entryRefs is present but empty — omit it instead`);
    }

    cells.set(`${q.tier}|${q.category}`, (cells.get(`${q.tier}|${q.category}`) ?? 0) + 1);
    perTier.set(q.tier, (perTier.get(q.tier) ?? 0) + 1);

    switch (q.format) {
      case 'multipleChoice':
      case 'imageIdentification':
      case 'aromaIdentification': {
        list(where, 'options', q.options, 2);
        if (q.answerIndex < 0 || q.answerIndex >= q.options.length) {
          problems.push(`${where}: answerIndex ${q.answerIndex} is outside options`);
        }
        if (q.format === 'aromaIdentification') {
          if (q.noteKeys.length === 0) problems.push(`${where}: no noteKeys`);
          for (const key of q.noteKeys) {
            if (!(key in FLAVOR_ART)) problems.push(`${where}: noteKey "${key}" is not a flavorArt key`);
          }
        }
        if (q.format === 'imageIdentification' && q.image.kind === 'countryOutline') {
          if (!(q.image.key in COUNTRY_SHAPE_ICONS)) {
            problems.push(`${where}: image key "${q.image.key}" is not a countryShapeIcons key`);
          }
        }
        break;
      }
      case 'trueFalse':
        if (typeof q.answer !== 'boolean') problems.push(`${where}: answer is not a boolean`);
        break;
      case 'selectAll': {
        list(where, 'options', q.options, 3);
        const picks = new Set(q.answerIndices);
        if (picks.size !== q.answerIndices.length) problems.push(`${where}: answerIndices repeats`);
        // Both degenerate cases are the same defect: a "select all that apply"
        // with nothing or everything correct teaches the candidate nothing and
        // is unscoreable against partial credit.
        if (picks.size === 0) problems.push(`${where}: answerIndices is empty`);
        if (picks.size === q.options.length) problems.push(`${where}: every option is correct`);
        for (const i of q.answerIndices) {
          if (i < 0 || i >= q.options.length) problems.push(`${where}: answerIndex ${i} is outside options`);
        }
        break;
      }
      case 'matching': {
        if (q.pairs.length < 2) problems.push(`${where}: matching needs >= 2 pairs`);
        list(where, 'pairs.left', q.pairs.map((p) => p.left), 2);
        // The right column is what gets shuffled, so a repeat there is not a
        // cosmetic duplicate — it makes two different lefts indistinguishably
        // correct and the score a lie.
        list(where, 'pairs.right', q.pairs.map((p) => p.right), 2);
        break;
      }
      case 'ordering': {
        list(where, 'items', q.items, 3);
        text(where, 'axis.from', q.axis.from);
        text(where, 'axis.to', q.axis.to);
        break;
      }
      default:
        problems.push(`${where}: unhandled format`);
    }
  }

  for (const tier of EXAM_TIERS) {
    const authored = EXAM_AUTHORED_TIER_COUNTS[tier];
    const actual = perTier.get(tier) ?? 0;
    if (authored !== actual) {
      problems.push(`EXAM_AUTHORED_TIER_COUNTS.${tier} says ${authored}, the bank holds ${actual}`);
    }
    for (const category of EXAM_CATEGORIES) {
      const count = cells.get(`${tier}|${category}`) ?? 0;
      // The floor, not the total, is what bounds balanced generation (D4): an
      // exam cannot draw more distinct questions from a category than its
      // thinnest cell holds without repeating, and `ExamPaper` refuses to
      // repeat.
      if (count < EXAM_MIN_CELL_COUNT) {
        problems.push(`cell ${tier}/${category} holds ${count}, below EXAM_MIN_CELL_COUNT (${EXAM_MIN_CELL_COUNT})`);
      }
    }
  }

  for (const category of EXAM_CATEGORIES) text(`EXAM_CATEGORY_LABELS.${category}`, 'label', EXAM_CATEGORY_LABELS[category]);
  for (const tier of EXAM_TIERS) text(`EXAM_TIER_LABELS.${tier}`, 'label', EXAM_TIER_LABELS[tier]);

  if (problems.length > 0) {
    throw new Error(`the exam bank failed its own rules:\n  - ${problems.join('\n  - ')}`);
  }
}

function main() {
  const full = buildWineEntries();
  // COUNTRY_GATE entries are the web app's country drill-down nodes (country ->
  // states -> regions). The native port has no country screen — `DexRoute` has
  // no case for it and `EntryCategory` cannot decode it — so shipping them
  // failed the *entire* entries.json decode on one bad category, taking the
  // whole database down with it. Excluded until that screen exists.
  //
  // With no selection active, `full` is reused rather than rebuilt — this used
  // to be the second of three identical 405-entry builds per run (audit B11;
  // the third was `WINE_ENTRIES` evaluating at import of shared/constants,
  // now removed).
  const entries = (STARTER_SELECTION ? buildWineEntries(STARTER_SELECTION) : full)
    .filter((entry) => entry.category !== 'COUNTRY_GATE');
  const palette = buildPalette(full);

  const summary = assertCoverage(entries, palette);
  const icons = buildIconManifest(entries);
  assertFirmware();
  assertFlavorIds(entries);
  assertExam();
  const outlineBacklog = assertOutlineCoverage(entries);

  mkdirSync(OUT_DIR, { recursive: true });

  // Which entries the free tier unlocks: every NOBLE grape, plus the COMMON
  // grapes of the four countries a newcomer is most likely to be holding a
  // bottle from. Expressed against grape properties rather than a hand-listed
  // set, so it stays correct as the database grows.
  //
  // Regions, styles and flavours follow from *their* cross-links, so the free
  // tier stays internally consistent — you never meet a region whose key grape
  // is locked. Continents are always free: the globe is navigation, and locking
  // it would strand the user on the map screen.
  const FREE_COMMON_ORIGINS = new Set(['France', 'Italy', 'USA', 'Spain']);
  const freeGrapeIDs = new Set(
    entries
      .filter((entry) => {
        if (entry.category !== 'GRAPES') return false;
        const rarity = (entry as { rarity?: string }).rarity;
        if (rarity === 'NOBLE') return true;
        const origin = (entry.details as { origin?: string }).origin ?? '';
        return rarity === 'COMMON' && FREE_COMMON_ORIGINS.has(origin);
      })
      .map((entry) => entry.id),
  );
  const freeGrapeNames = new Set(
    entries.filter((entry) => freeGrapeIDs.has(entry.id)).map((entry) => entry.name),
  );
  const isFree = (entry: WineEntry): boolean => {
    if (entry.category === 'CONTINENTS') return true;
    if (entry.category === 'GRAPES') return freeGrapeIDs.has(entry.id);
    const linked = (entry.details as { notableGrapes?: string[] }).notableGrapes ?? [];
    return linked.some((name) => freeGrapeNames.has(name));
  };
  const tiers = { free: entries.filter(isFree).map((entry) => entry.id) };

  const countries = buildCountryInfo(entries);

  const leanEntries = omitKeys(entries, STRIP_ENTRY_FIELDS);
  const leanPalette = omitKeys(palette, STRIP_PALETTE_FIELDS);

  // Write temps, self-check them, then rename into place (audit B9). Every
  // temp is written and validated before the first rename, so a crash or a
  // failed self-check anywhere in the sequence leaves the previous consistent
  // set on disk rather than a mixed one that decodes fine and renders wrong.
  // schema.json still lands last — the signal M45's loadNotices check keys on
  // for an interrupted first-ever generation — by design now rather than by
  // write order.
  const outputs: Array<[string, string]> = [
    ['entries.json', serialize(leanEntries)],
    ['tiers.json', serialize(tiers)],
    ['palette.json', serialize(leanPalette)],
    ['icons.json', serialize(icons)],
    ['countries.json', serialize(countries)],
    ['schema.json', serialize({ schemaVersion: SCHEMA_VERSION })],
    // The authored version travels *with* the changelog rather than being
    // derived again on the Swift side: `FIRMWARE_VERSION` is already the head
    // of the list, and shipping it as its own key means `AppVersion` never has
    // to reason about ordering to answer "what is this build".
    ['firmware.json', serialize({ version: FIRMWARE_VERSION, releases: FIRMWARE_RELEASES })],
    // The bank and its closed vocabularies travel together, for the reason the
    // firmware version travels with its changelog: `ExamCatalog` should never
    // have to restate a label or a tier order that `shared/` already decides.
    // `minCellCount` is the one number `ExamPaper` reasons about — it bounds
    // how many distinct questions a balanced paper can draw per category — so
    // it ships as data rather than as a Swift literal that could drift.
    //
    // Both of these arrived on the upstream side writing straight to disk;
    // folded into the temp-then-rename set on integration so the two newest
    // resources get the same all-or-nothing guarantee as the other six (audit
    // B9). `validateOutputs` already checks both envelopes.
    ['exam.json', serialize({
      questions: EXAM_QUESTIONS,
      tiers: EXAM_TIERS,
      categories: EXAM_CATEGORIES,
      formats: EXAM_FORMATS,
      categoryLabels: EXAM_CATEGORY_LABELS,
      tierLabels: EXAM_TIER_LABELS,
      authoredTierCounts: EXAM_AUTHORED_TIER_COUNTS,
      minCellCount: EXAM_MIN_CELL_COUNT,
    })],
  ];
  const tempOf = (name: string) => resolve(OUT_DIR, `${name}.tmp`);
  try {
    for (const [name, payload] of outputs) writeFileSync(tempOf(name), payload);
    // AUDIT M3 — fail loudly here (and in CI) if the emitted JSON would not
    // decode. Runs against the temps, so a failure keeps the previous set.
    validateOutputs(OUT_DIR, '.tmp');
    for (const [name] of outputs) renameSync(tempOf(name), resolve(OUT_DIR, name));
  } finally {
    // Resources/ ships into the bundle via `.copy`, so a failed run must not
    // leave stray *.json.tmp behind to ride along.
    for (const [name] of outputs) rmSync(tempOf(name), { force: true });
  }

  // 0.7.5 (A028) — and after the writes, for the bootstrap reason spelled out on
  // the function. Decodable JSON that names a file nobody shipped is still a
  // blank space on the phone.
  const assetsChecked = assertAssetsExist(icons);

  const hexes = new Set(JSON.stringify(palette).match(/#[0-9a-fA-F]{6}/g) ?? []);

  console.log('entries.json');
  console.log(`  grapes   ${summary.grapes.length}`);
  console.log(`  regions  ${summary.regions.length}`);
  console.log(`  styles   ${summary.styles.length}`);
  console.log(`  flavors  ${summary.flavors.length}  (derived)`);
  console.log(`  total    ${entries.length}   (full database would be ${full.length})`);
  console.log('palette.json');
  console.log(`  unique hex values ${hexes.size}`);
  console.log('tiers.json');
  console.log(`  free tier      ${tiers.free.length} of ${entries.length}`);
  console.log('countries.json');
  console.log(`  country blurbs ${Object.keys(countries).length}`);
  console.log('firmware.json');
  console.log(`  version        ${FIRMWARE_VERSION}`);
  console.log(`  releases       ${FIRMWARE_RELEASES.length}`);
  console.log('exam.json');
  console.log(`  questions      ${EXAM_QUESTIONS.length}`);
  console.log(
    `  by tier        ${EXAM_TIERS.map((t) => `${t} ${EXAM_AUTHORED_TIER_COUNTS[t]}`).join(' · ')}`,
  );
  console.log(`  min cell       ${EXAM_MIN_CELL_COUNT} (bounds a balanced paper's per-category draw)`);
  console.log('icons.json');
  console.log(`  distinct icons ${icons.unique.length}`);
  console.log(`  assets on disk ${assetsChecked} ids checked, all resolve`);
  // Printed rather than silent, on the lesson 0.7.4's dead COUNTRY_GATE arm
  // taught: an absence nothing mentions reads as "none". Unreachable since
  // 0.7.9 (E) — `assertOutlineCoverage` throws instead of returning names —
  // and kept as the one line that would say so if that ever changes back.
  if (outlineBacklog.length > 0) {
    console.log(`  no outline art: ${outlineBacklog.join(', ')}`);
  }
  const missing = Object.entries(icons.byEntry)
    .filter(([, id]) => id === icons.fallback)
    .map(([entryId]) => entryId);
  if (missing.length > 0) {
    console.log(`  unresolved (using fallback): ${missing.length} — ${missing.join(', ')}`);
  }
  console.log('coverage');
  console.log(`  rarity tiers  ${[...summary.tiers].join(', ')}`);
  console.log(`  climates      ${[...summary.climates].join(', ')}`);
  console.log(`  style classes ${[...summary.styleClasses].join(', ')}`);
  console.log('  all 6 continents resolve to >=1 region');
}

main();
