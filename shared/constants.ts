import type {
  EntryCategory,
  FlavorEntry,
  GrapeBodyClass,
  GrapeEntry,
  RarityLabel,
  TastingNote,
  TastingNoteIcon,
  WineEntry,
} from './types.ts';
import { GRAPES as LEGACY_GRAPES } from './data/grapes.ts';
import { REGIONS } from './data/regions.ts';
import { STYLES } from './data/styles.ts';
import { GRAPE_CARDS } from './data/grapeCards.ts';
import { CONTINENTS } from './data/continents.ts';
import { COUNTRIES } from './data/countries.ts';
import {
  FLAVOR_CLASS_COLORS,
  categorizeFlavor,
  categorizeFlavorSubclass,
  type FlavorClass,
} from './services/entryUtils.ts';

// Re-export individual collections
export { GRAPES as GRAPES_LEGACY } from './data/grapes.ts';
export { REGIONS } from './data/regions.ts';
export { STYLES } from './data/styles.ts';
export { GRAPE_CARDS } from './data/grapeCards.ts';
export { CONTINENTS } from './data/continents.ts';
export { COUNTRIES } from './data/countries.ts';

const canonicalizeGrapeName = (value: string) =>
  /^syrah\s*\/\s*shiraz$/i.test(value.trim()) ? 'Syrah' : value;

const normalizeText = (value?: string) => (value || '').trim().toLowerCase();

const getGrapeBodyClass = (...values: Array<string | undefined>): GrapeBodyClass => {
  for (const value of values) {
    const text = normalizeText(value)
      .replace(/-bodied/g, '')
      .replace(/body/g, '')
      .replace(/red|white|rose|ros\u00e9|orange|sparkling|aromatic|sweet/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    if (!text) continue;
    if (text.includes('medium full') || text.includes('full medium')) return 'Medium-Full';
    if (text.includes('light medium') || text.includes('medium light')) return 'Light-Medium';
    if (text.includes('full')) return 'Full';
    if (text.includes('medium')) return 'Medium';
    if (text.includes('light')) return 'Light';
  }

  return 'Medium';
};

interface LegacyGrapeMeta {
  color: string;
  icon?: string;
  tastingProfile?: TastingNote[];
  wineType?: string;
}

const legacyColorMap: Record<string, LegacyGrapeMeta> =
  LEGACY_GRAPES.reduce((acc, g) => {
    acc[g.id] = { color: g.color, icon: g.icon, tastingProfile: g.tastingProfile, wineType: g.wineType };
    return acc;
  }, {} as Record<string, LegacyGrapeMeta>);

const GRAPE_ENTRIES: GrapeEntry[] = GRAPE_CARDS.map((card) => {
  const legacy = legacyColorMap[card.id];
  const bodyClass = getGrapeBodyClass(legacy?.wineType, card.style, LEGACY_GRAPES.find((grape) => grape.id === card.id)?.details.body);
  const rarityMap: Record<string, RarityLabel> = {
    common: 'COMMON',
    uncommon: 'UNCOMMON',
    rare: 'RARE',
    epic: 'RARE',
    noble: 'NOBLE',
  };
  return {
    id: card.id,
    name: canonicalizeGrapeName(card.name),
    description: card.info,
    category: 'GRAPES',
    tags: card.tastingProfile,
    color: legacy?.color || '#722F37',
    icon: legacy?.icon || 'grape',
    wineType: card.style,
    grapeType: card.type,
    grapeStyle: card.style,
    grapeBodyClass: bodyClass,
    grapeCharacteristics: card.characteristics,
    grapeAlternateNames: card.alternateNames.map(canonicalizeGrapeName),
    grapeNotableRegions: card.notableRegions,
    grapeCountryOfOrigin: card.countryOfOrigin,
    grapeRarityTier: card.rarityTier,
    tastingProfile: legacy?.tastingProfile,
    grapeCard: card,
    rarity: rarityMap[card.rarityTier] || 'UNCOMMON',
    details: {
      origin: card.countryOfOrigin,
      synonyms: card.alternateNames.map(canonicalizeGrapeName),
      keyRegions: card.notableRegions,
      body: bodyClass,
    }
  };
});

const TASTING_NOTE_ICON_KEYS: TastingNoteIcon[] = [
  'circle',
  'triangle',
  'leaf',
  'cloud',
  'sun',
  'mountain',
  'sparkles',
  'flame',
  'droplet',
  'shield',
  'flower',
  'fruit',
  'herb',
  'spice',
  'mineral',
  'oak',
  'smoke',
  'stone',
  'tropical',
  'flag',
  'honey',
  'nut',
  'default',
];

const sanitizeTastingNoteIcon = (icon?: string): TastingNoteIcon =>
  icon && TASTING_NOTE_ICON_KEYS.includes(icon as TastingNoteIcon)
    ? (icon as TastingNoteIcon)
    : 'default';

const formatSubclassLabel = (subclass: string) => subclass.split('_').map(part => part.charAt(0) + part.slice(1).toLowerCase()).join(' ');

/// Opening phrase per flavour class, so the 56 generated blurbs stop reading as
/// one sentence with the nouns swapped. Every flavour also names the grapes it
/// was derived from, which is the part that actually differs entry to entry.
const FLAVOR_CLASS_PHRASE: Record<string, string> = {
  SWEET: 'a ripe, sweet-leaning',
  UMAMI: 'a savoury, umami-leaning',
  BITTER: 'a firm, bitter-edged',
  SOUR: 'a tart, acid-lifted',
  SALTY: 'a saline, mineral',
};

/// "A", "A and B", "A, B and C" — flavours derive from at most three grapes.
const formatNameList = (names: string[]): string => {
  if (names.length <= 1) return names[0] ?? '';
  return `${names.slice(0, -1).join(', ')} and ${names[names.length - 1]}`;
};

const buildFlavorDescription = (
  note: string,
  cls: string,
  subclassLabel: string,
  grapes: string[],
): string => {
  const phrase = FLAVOR_CLASS_PHRASE[cls] ?? `a ${cls.toLowerCase()}-leaning`;
  const kind = subclassLabel.toLowerCase();
  // Drop the subclass when it would repeat something already said: the note
  // itself ("Herbs is ... herb note") or the class ("saline, mineral salty
  // note", where SALTY is both the class and the subclass).
  const redundant = !kind
    || kind === note.toLowerCase()
    || kind === cls.toLowerCase()
    || phrase.includes(kind);
  const body = redundant
    ? `${note} is ${phrase} note`
    : `${note} is ${phrase} ${kind} note`;
  const named = grapes.slice(0, 3);
  return named.length
    ? `${body}, carried here by ${formatNameList(named)}.`
    : `${body}.`;
};

const buildFlavorEntries = (grapeEntries: GrapeEntry[]): FlavorEntry[] => {
  const flavorMap = new Map<string, { note: string; icon: string; color?: string; grapes: string[]; cls: FlavorClass; subclass: string }>();

  grapeEntries.forEach((entry) => {
    (entry.tastingProfile || []).forEach((flavor) => {
      const key = flavor.note.trim().toLowerCase();
      if (!key) return;
      const subclass = categorizeFlavorSubclass(flavor.note);
      const cls = categorizeFlavor(flavor.note, subclass);
      if (!flavorMap.has(key)) {
        flavorMap.set(key, { note: flavor.note, icon: flavor.icon || FLAVOR_CLASS_COLORS[cls].icon, color: flavor.color, grapes: [], cls, subclass });
      }
      flavorMap.get(key)!.grapes.push(entry.name);
    });
  });

  const flavorEntries: FlavorEntry[] = [];
  const flavorValues = Array.from(flavorMap.values());

  flavorMap.forEach((flavor, idx) => {
    const clsColors = FLAVOR_CLASS_COLORS[flavor.cls];
    const subclass = flavor.subclass || categorizeFlavorSubclass(flavor.note);
    const subclassLabel = formatSubclassLabel(subclass);
    const related = flavorValues
      .filter(f => f.cls === flavor.cls && f.note.toLowerCase() !== flavor.note.toLowerCase())
      .slice(0, 3)
      .map((f) => ({
        note: f.note,
        icon: 'default' as const,
        color: clsColors.border,
      }));

    flavorEntries.push({
      id: `FLAVOR-${idx + 1}`,
      name: flavor.note,
      description: buildFlavorDescription(flavor.note, flavor.cls, subclassLabel, flavor.grapes),
      category: 'FLAVORS',
      tags: [flavor.cls, subclass],
      color: clsColors.color,
      icon: flavor.icon,
      tastingProfile: [
        { note: flavor.note, icon: sanitizeTastingNoteIcon(flavor.icon), color: flavor.color || clsColors.border },
        ...related,
      ],
      details: {
        classification: flavor.cls,
        subclass,
        notableGrapes: flavor.grapes.slice(0, 8),
      },
    });
  });

  return flavorEntries;
};

const CATEGORY_CALLBACKS: Partial<Record<EntryCategory, { icon: string; tile: string }>> = {
  GRAPES: { icon: 'grape', tile: 'grape' },
  REGIONS: { icon: 'region', tile: 'region' },
  STYLES: { icon: 'style', tile: 'style' },
  FLAVORS: { icon: 'flavor', tile: 'flavor' },
  CONTINENTS: { icon: 'globe', tile: 'globe' },
  COUNTRY_GATE: { icon: 'flag', tile: 'globe' },
};

function applyCategoryCallbacks<T extends WineEntry>(entry: T): T {
  const callbacks = CATEGORY_CALLBACKS[entry.category];
  if (!callbacks) return entry;
  return {
    ...entry,
    iconCallback: entry.iconCallback ?? callbacks.icon,
    tileCallback: entry.tileCallback ?? callbacks.tile,
  };
}

// Canonicalize an entry's grape-name fields without losing variant typing.
// Uses `'in'` checks because notableGrapes/synonyms exist on different variants.
function canonicalizeEntry<T extends WineEntry>(entry: T): T {
  const next = { ...entry, name: canonicalizeGrapeName(entry.name) };
  const details = next.details as { notableGrapes?: string[]; synonyms?: string[] };
  const updated: { notableGrapes?: string[]; synonyms?: string[] } = {};

  if ('notableGrapes' in next.details && details.notableGrapes) {
    updated.notableGrapes = details.notableGrapes.map(canonicalizeGrapeName);
  }
  if ('synonyms' in next.details && details.synonyms) {
    updated.synonyms = details.synonyms.map(canonicalizeGrapeName);
  }

  return {
    ...next,
    details: { ...next.details, ...updated },
  } as T;
}

/**
 * Optional narrowing applied when assembling the entry set. Used by the native
 * port's generator to emit a slim starter dataset; the web app passes nothing
 * and gets the full database.
 *
 * Selection is applied to the *source* collections, so FLAVORS are derived only
 * from the selected grapes rather than being filtered afterwards.
 */
export interface EntrySelection {
  grapes?: readonly string[];
  regions?: readonly string[];
  styles?: readonly string[];
  includeContinents?: boolean;
  includeCountries?: boolean;
}

const selectById = <T extends { id: string }>(all: readonly T[], ids?: readonly string[]): T[] =>
  ids ? all.filter((entry) => ids.includes(entry.id)) : [...all];

export function buildWineEntries(selection?: EntrySelection): WineEntry[] {
  const grapes = selectById(GRAPE_ENTRIES, selection?.grapes);
  const regions = selectById(REGIONS, selection?.regions);
  const styles = selectById(STYLES, selection?.styles);

  return [
    ...grapes,
    ...regions,
    ...styles,
    ...buildFlavorEntries(grapes),
    ...(selection?.includeContinents === false ? [] : CONTINENTS),
    ...(selection?.includeCountries === false ? [] : COUNTRIES),
  ].map((entry) => applyCategoryCallbacks(canonicalizeEntry(entry)));
}

// Combined wine entries for the app
export const WINE_ENTRIES: WineEntry[] = buildWineEntries();

// Re-export shared helpers so existing consumers keep importing from `./constants`.
export { FLAVOR_CLASS_COLORS, categorizeFlavor, categorizeFlavorSubclass };
