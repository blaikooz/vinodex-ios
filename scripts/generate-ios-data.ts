/**
 * Generates the iOS app's bundled data from the shared data + colour tables.
 *
 * Emits five files into the VinodexCore resource directory:
 *   entries.json   — the WineEntry set for the current selection
 *   tiers.json     — which entry ids the free tier unlocks
 *   palette.json   — the full colour tables, materialised by probing the
 *                    shared lookup functions over their key domains
 *   icons.json     — the icon manifest rasterize-icons.sh consumes
 *   countries.json — authored INFO prose for the country pages, which are
 *                    assembled from region fields and so have no entry of
 *                    their own to carry a description
 *
 * All five are committed so a Swift build never needs Node. Scaling the starter
 * to the full database is a matter of setting STARTER_SELECTION to `undefined`.
 *
 * Everything this reads lives under `shared/`, which is a sibling of `scripts/`
 * in both the monorepo and the published `vinodex-swift` mirror — so the import
 * specifiers below are identical in both and the script runs in either repo.
 * Only the output path differs; see OUT_DIR.
 */
import {
  resolveFlavorIcon,
  resolveFlavorClassIcon,
  resolveFlavorSubclassIcon,
} from '../shared/services/flavorIcon.ts';
import { existsSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { buildWineEntries, type EntrySelection } from '../shared/constants.ts';
import type { WineEntry } from '../shared/types.ts';
import { CONTINENTS } from '../shared/data/continents.ts';
import { COUNTRIES } from '../shared/data/countries.ts';
import { CLIMATE_CLASS_MAP } from '../shared/data/climateClasses.ts';
import { getFlagGradient } from '../shared/data/flagGradients.ts';
import { GRAPE_CARDS } from '../shared/data/grapeCards.ts';
import { REGIONS } from '../shared/data/regions.ts';
import { STYLES } from '../shared/data/styles.ts';
import { STYLE_TONE_PALETTE } from '../shared/stylePalette.ts';
import {
  FLAVOR_SUBCLASS_KEYWORDS,
  FLAVOR_CLASS_COLORS,
  getStyleClassType,
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

// The Swift package sits under `ios/` in the monorepo but at the root of the
// published `vinodex-swift` mirror. Probe rather than hard-code, so one script
// serves both. SwiftPM resolves target resources relative to the target's
// source directory, hence the Sources/... suffix either way.
const SWIFT_ROOT = existsSync(resolve(REPO_ROOT, 'ios', 'Package.swift'))
  ? resolve(REPO_ROOT, 'ios')
  : REPO_ROOT;
const OUT_DIR = resolve(SWIFT_ROOT, 'Sources', 'VinodexCore', 'Resources');

if (!existsSync(resolve(SWIFT_ROOT, 'Package.swift'))) {
  throw new Error(
    `no Package.swift under ${SWIFT_ROOT} — run this from the monorepo root or from a vinodex-swift checkout`,
  );
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

  const rarities = ['COMMON', 'UNCOMMON', 'RARE', 'NOBLE'] as const;
  const colorTypes = ['RED', 'WHITE', 'ROSÉ', 'ORANGE', 'DUAL'] as const;
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

// Fixed icon sets used by the detail screen's three-tile header, transcribed
// from EntryDetail.tsx and climateDisplay.tsx.
// NOTE: two names referenced by the web app do not exist in the game-icons set,
// so Iconify renders nothing for them there — `scales-tipped` (Light-Medium
// body) and `cloud` (climate fallback). Substituted with real icons here.
const BODY_ICONS: Record<string, string> = {
  Light: 'game-icons:feather',
  'Light-Medium': 'game-icons:weight-scale',
  Medium: 'game-icons:scales',
  'Medium-Full': 'game-icons:weight-lifting-up',
  Full: 'game-icons:weight',
};

const CLIMATE_ICONS: Record<string, string> = {
  maritime: 'game-icons:big-wave',
  continental: 'game-icons:mountains',
  cool: 'game-icons:snowflake-2',
  warm: 'game-icons:sun',
  mediterranean: 'game-icons:olive',
};

const COLOR_ICONS: Record<string, string> = {
  RED: 'game-icons:wine-bottle',
  WHITE: 'game-icons:wine-glass',
  ROSE: 'game-icons:rose',
  ORANGE: 'game-icons:sun',
  DUAL: 'game-icons:two-shadows',
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
  TYPE: 'game-icons:holy-grail',
  BLEND: 'game-icons:pouring-chalice',
  ORIGIN: 'game-icons:atlas',
  METHOD: 'game-icons:cellar-barrels',
  STYLE: 'game-icons:wine-glass',
};

/// Countries whose outline exists as a glyph, used to mask the flag into the
/// country's shape rather than showing a plain rectangle.
const COUNTRY_SHAPE_ICONS: Record<string, string> = {
  france: 'game-icons:france',
  australia: 'game-icons:australia',
  hungary: 'game-icons:hungary',
  italy: 'game-icons:italia',
  japan: 'game-icons:japan',
  portugal: 'game-icons:portugal',
  'south africa': 'game-icons:south-africa',
  spain: 'game-icons:spain',
  switzerland: 'game-icons:switzerland',
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
  volcanic: { icon: 'game-icons:volcano', color: '#FF4500' },
  basalt: { icon: 'game-icons:stone-pile', color: '#2F4F4F' },
  clay: { icon: 'lucide:droplet', color: '#B5651D' },
  loam: { icon: 'game-icons:plow', color: '#8B5A2B' },
  sand: { icon: 'game-icons:salt-shaker', color: '#F4A460' },
  limestone: { icon: 'game-icons:mountains', color: '#E0E0E0' },
  chalk: { icon: 'lucide:triangle', color: '#EDEDED' },
  slate: { icon: 'game-icons:rock', color: '#708090' },
  shale: { icon: 'game-icons:flat-platform', color: '#6B7B8C' },
  schist: { icon: 'lucide:mountain', color: '#5F7A8A' },
  granite: { icon: 'game-icons:crystal-cluster', color: '#A9A9A9' },
  gravel: { icon: 'lucide:circle', color: '#696969' },
  alluvial: { icon: 'game-icons:river', color: '#6CA0DC' },
  loess: { icon: 'game-icons:dust-cloud', color: '#C2B280' },
  laterite: { icon: 'game-icons:ore', color: '#A0522D' },
  default: { icon: 'lucide:mountain', color: '#8B4513' },
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

/// Pixel flags live in `pixelflags/<Continent>/<slug>/<slug>.png`.
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
  'South Africa': 'Africa/south_africa/south_africa.png',
  Morocco: 'Africa/morocco/morocco.png',
  USA: 'North America/united_states/united_states.png',
  Canada: 'North America/canada/canada.png',
  Argentina: 'South America/argentina/argentina.png',
  Chile: 'South America/chile/chile.png',
  Uruguay: 'South America/uruguay/uruguay.png',
  'New Zealand': 'Oceania/new_zealand/new_zealand.png',
  Australia: 'Oceania/australia/australia.png',
  Japan: 'Asia/japan/japan.png',
  China: 'Asia/china/china.png',
  India: 'Asia/india/india.png',
};

/// Continents all carried `icon: 'globe'`, so all six resolved to the same
/// `lucide:globe` — a generic mark that told you nothing and made the globe
/// search look like six copies of one row. Outline glyphs where game-icons has
/// the landmass; a recognisable stand-in where it does not.
const CONTINENT_ICONS: Record<string, string> = {
  CONT_AFRICA: 'game-icons:africa',
  CONT_SOUTH_AMERICA: 'game-icons:south-america',
  CONT_OCEANIA: 'game-icons:australia',
  CONT_NORTH_AMERICA: 'game-icons:earth-america',
  CONT_EUROPE: 'game-icons:coliseum',
  CONT_ASIA: 'game-icons:pagoda',
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

  const info: Record<string, { description: string }> = {};
  for (const country of COUNTRIES) {
    if (!reachable.has(country.name)) continue;
    if (!country.description) continue;
    info[country.name] = { description: country.description };
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
    flavorClassIcons[classification] = resolveFlavorClassIcon(classification);
    flavorSubclassIcons[subclass] = resolveFlavorSubclassIcon(subclass);
  }

  for (const entry of entries) {
    if (entry.category === 'FLAVORS') {
      byEntry[entry.id] = resolveFlavorIcon(entry.name, entry.details.subclass) as string;
    } else if (CONTINENT_ICONS[entry.id]) {
      byEntry[entry.id] = CONTINENT_ICONS[entry.id]!;
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

  // Only ship country shapes for countries actually present.
  const shapeIcons = Object.fromEntries(
    Object.entries(COUNTRY_SHAPE_ICONS).filter(([country]) =>
      [...origins].some((o) => o.toLowerCase() === country),
    ),
  );

  const unique = [
    ...new Set([
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
      FALLBACK_ICON,
    ]),
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
    countryShapeIcons: shapeIcons,
    styleClassBg: STYLE_CLASS_BG,
    styleColorTypeColors: STYLE_COLOR_TYPE_COLORS,
    soilIcons: SOIL_ICONS,
    soilKeywords: SOIL_KEYWORDS,
    climateSoilFallback: CLIMATE_SOIL_FALLBACK,
    defaultSoils: DEFAULT_SOILS,
    flags,
  };
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
  for (const tier of ['COMMON', 'UNCOMMON', 'RARE', 'NOBLE']) {
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

  // Flavours must be derived from the selected grapes, not filtered afterwards.
  // 25 grapes x up to 3 notes = 75 instances collapsing to ~45-65 once shared
  // notes (e.g. "cherry") merge across grapes. A count near the full
  // database's total would mean the selection was applied after
  // buildFlavorEntries instead of before.
  if (STARTER_SELECTION) {
    check(
      `flavor count ${flavors.length} outside expected 40-75`,
      flavors.length >= 40 && flavors.length <= 75,
      'selection may have been applied after flavour derivation',
    );
  }

  // Every flavour class and subclass must own a glyph, and no two may share
  // one: the scan's CLASS and SUBCLASS tiles sit side by side, so a duplicate
  // reads as a rendering bug and the fallback reads as a missing asset.
  //
  // Levels are qualified by kind rather than by name: SALTY is both a class and
  // a subclass, and they are two levels that each need a glyph of their own.
  const flavorGlyphs = new Map<string, string>();
  for (const flavor of flavors) {
    if (flavor.category !== 'FLAVORS') continue;
    for (const [kind, value, icon] of [
      ['class', flavor.details.classification, resolveFlavorClassIcon(flavor.details.classification)],
      ['subclass', flavor.details.subclass, resolveFlavorSubclassIcon(flavor.details.subclass)],
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

function main() {
  const full = buildWineEntries();
  // COUNTRY_GATE entries are the web app's country drill-down nodes (country ->
  // states -> regions). The native port has no country screen — `DexRoute` has
  // no case for it and `EntryCategory` cannot decode it — so shipping them
  // failed the *entire* entries.json decode on one bad category, taking the
  // whole database down with it. Excluded until that screen exists.
  const entries = buildWineEntries(STARTER_SELECTION)
    .filter((entry) => entry.category !== 'COUNTRY_GATE');
  const palette = buildPalette(full);

  const summary = assertCoverage(entries, palette);
  const icons = buildIconManifest(entries);

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

  writeFileSync(resolve(OUT_DIR, 'entries.json'), JSON.stringify(entries, null, 2) + '\n');
  writeFileSync(resolve(OUT_DIR, 'tiers.json'), JSON.stringify(tiers, null, 2) + '\n');
  writeFileSync(resolve(OUT_DIR, 'palette.json'), JSON.stringify(palette, null, 2) + '\n');
  writeFileSync(resolve(OUT_DIR, 'icons.json'), JSON.stringify(icons, null, 2) + '\n');
  writeFileSync(resolve(OUT_DIR, 'countries.json'), JSON.stringify(countries, null, 2) + '\n');

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
  console.log('icons.json');
  console.log(`  distinct icons ${icons.unique.length}`);
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
