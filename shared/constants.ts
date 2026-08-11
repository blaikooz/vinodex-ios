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
// Not a wine collection, but the same rule applies: anything the apps read as
// data is reachable from here (iOS 0.7.3, F3).
export { FIRMWARE_RELEASES, FIRMWARE_VERSION } from './data/firmware.ts';

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
  // The whole legacy record, hoisted (0.7.5, E). `bodyClass` below already did
  // this find inline and `lineage` needs the same record, so the second reader
  // is the one that makes it worth naming rather than scanning 171 records
  // twice per card.
  const record = LEGACY_GRAPES.find((grape) => grape.id === card.id);
  // The authored pedigree (0.7.5, E). `GRAPE_CARDS` does not carry it -- a card
  // is the stat-bar projection -- so it comes off the legacy record. Passed
  // through by name because this object is built field by field; see
  // `GrapeEntry.lineage` for why it is top level rather than in `details`.
  const lineage = record?.lineage;
  const bodyClass = getGrapeBodyClass(legacy?.wineType, card.style, record?.details.body);
  const rarityMap: Record<string, RarityLabel> = {
    common: 'COMMON',
    uncommon: 'UNCOMMON',
    rare: 'RARE',
    epic: 'RARE',
    noble: 'NOBLE',
    godforsaken: 'GODFORSAKEN',
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
    // Omitted entirely when absent rather than written as `undefined`: the
    // generator's JSON pass would drop it either way, but `vinodex-web`
    // typechecks this under `exactOptionalPropertyTypes`-adjacent strictness and
    // an explicit `undefined` reads as "authored blank" rather than "no data".
    ...(lineage ? { lineage } : {}),
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

/// One line per flavour class, about the class itself (iOS 0.8.94, E1).
///
/// The third pass at this copy, each moving the same direction. 0.5.7's G1
/// stopped the blurbs describing the *database* ("carried here by Barbera…");
/// E1 stops them describing the *drinking* — "promises fruit before the sip"
/// and "makes the mouth water" framed every flavour through the glass, on
/// entries whose subject is the flavour. What is left is the family in its
/// own terms, one short line each.
const FLAVOR_CLASS_ABOUT: Record<string, string> = {
  SWEET: 'Sweet flavors read as ripeness and sugar: fruit, honey and confection.',
  UMAMI: 'Umami flavors are the savoury register: earth, leather, broth and pantry.',
  BITTER: 'Bitter flavors are grip and edge: pith, char and green herbs.',
  SOUR: 'Sour flavors are acidity and lift: citrus, orchard fruit and anything tart.',
  SALTY: 'Salty flavors are the mineral register: brine, stone and sea air.',
};

const buildFlavorDescription = (
  note: string,
  cls: string,
  subclassLabel: string,
): string => {
  const kind = subclassLabel.toLowerCase();
  const clsWord = cls.toLowerCase();
  // Drop the subclass when it would repeat something already said: the note
  // itself ("Herbs is ... herb note") or the class ("a salty salty note",
  // where SALTY is both the class and the subclass).
  const redundant = !kind
    || kind === note.toLowerCase()
    || kind === clsWord;
  const lead = redundant ? clsWord : kind;
  const article = /^[aeiou]/.test(lead) ? 'an' : 'a';
  const body = redundant
    ? `${note} is ${article} ${clsWord} note`
    : `${note} is ${article} ${kind} note in the ${clsWord} family`;
  const about = FLAVOR_CLASS_ABOUT[cls];
  return about ? `${body}. ${about}` : `${body}.`;
};

/**
 * A flavour's id, derived from its own name rather than from its position.
 *
 * This is the fix for a defect that shipped from the beginning until 0.8.9.
 * The id read `FLAVOR-${idx + 1}` inside a `Map.forEach`, whose callback is
 * `(value, key, map)` — so `idx` was never an index. It was the lowercased
 * note, and every id went out as the note with a stray `1` welded on:
 * `FLAVOR-blackcurrant1`, 37 of the 106 carrying a space.
 *
 * The obvious repair — `FLAVOR-1` … `FLAVOR-106` — is the wrong one, and it
 * is worth writing down why. The other four categories *author* their ids
 * (`G001`, `R001`, `S001`) in their data files, so those ids never move.
 * Flavours have no data file: the set is derived from the union of every
 * grape's tasting notes, in grape-file order. A positional id over a derived
 * set renumbers whenever a note is added to an early grape or retired from
 * the set — so it would break saved entries on ordinary catalog growth, which
 * is a worse failure than the one being fixed. A slug moves only when the
 * note is renamed, which is a deliberate act.
 */
const flavorSlug = (note: string): string =>
  note.trim().toUpperCase().replace(/[^A-Z0-9]+/g, '-').replace(/^-+|-+$/g, '');

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

  // Second argument named for what it is. It was called `idx` and read as one,
  // which is the whole of the id defect above.
  flavorMap.forEach((flavor, _noteKey) => {
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
      id: `FLAVOR-${flavorSlug(flavor.note)}`,
      name: flavor.note,
      description: buildFlavorDescription(flavor.note, flavor.cls, subclassLabel),
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
