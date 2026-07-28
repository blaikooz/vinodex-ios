import type { DataCategory, EntryCategory, WineEntry } from '../types';

// === Normalization ===

const DIACRITIC_RANGE = /[̀-ͯ]/g;

export const normalizeKey = (value: string) =>
  value
    .toLowerCase()
    .normalize('NFD')
    .replace(DIACRITIC_RANGE, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

export const normalizeEntryKey = normalizeKey;
export const normalizeFlavorKey = normalizeKey;

export const normalizeLabel = (value: string) =>
  value
    .toLowerCase()
    .normalize('NFD')
    .replace(DIACRITIC_RANGE, '');

export const isVariousOrigin = (origin?: string) =>
  (origin || '').trim().toLowerCase() === 'various';

// === Flavor categorization ===

export type FlavorClass = 'SWEET' | 'SOUR' | 'SALTY' | 'BITTER' | 'UMAMI';

export const FLAVOR_SUBCLASS_KEYWORDS: { id: string; keywords: string[] }[] = [
  { id: 'CITRUS', keywords: ['lemon', 'lime', 'grapefruit', 'citrus', 'orange', 'tangerine', 'yuzu'] },
  { id: 'BERRY', keywords: ['berry', 'berries', 'mixed berry', 'jammy', 'strawberry', 'raspberry', 'blueberry', 'blackberry', 'cranberry', 'currant', 'blackcurrant', 'redcurrant', 'cassis', 'boysenberry', 'mulberry', 'black fruit', 'blue fruit'] },
  { id: 'TROPICAL', keywords: ['pineapple', 'mango', 'papaya', 'banana', 'lychee', 'passion fruit', 'guava'] },
  { id: 'ORCHARD_FRUIT', keywords: ['apple', 'pear', 'quince', 'gooseberry'] },
  { id: 'STONE_FRUIT', keywords: ['peach', 'apricot', 'nectarine'] },
  { id: 'RED_FRUIT', keywords: ['cherry', 'pomegranate', 'red fruit'] },
  { id: 'DARK_FRUIT', keywords: ['plum', 'fig', 'date', 'prune', 'raisin', 'dark fruit'] },
  { id: 'HERBAL', keywords: ['herb', 'herbal', 'mint', 'eucalyptus', 'tea', 'sage', 'fennel', 'dill', 'basil', 'thyme', 'oregano', 'grass'] },
  { id: 'VEGETAL', keywords: ['bell pepper', 'peppercorn', 'tomato', 'green pepper', 'jalapeño', 'jalapeno', 'green pea', 'pea', 'olive', 'asparagus', 'artichoke', 'celery'] },
  { id: 'GAME', keywords: ['game', 'gamy', 'gamey', 'venison'] },
  { id: 'SAVORY', keywords: ['leather', 'savory', 'savoury', 'charcuterie', 'cured', 'salami', 'jerky', 'meat', 'umami'] },
  { id: 'SPICE', keywords: ['pepper', 'spice', 'cinnamon', 'clove', 'ginger', 'anise', 'licorice', 'liquorice', 'tobacco', 'nutmeg', 'cardamom'] },
  { id: 'BREAD', keywords: ['brioche', 'bread', 'baguette', 'biscuit', 'toast', 'yeast', 'dough', 'pastry'] },
  { id: 'BAKING', keywords: ['vanilla', 'cocoa', 'chocolate', 'caramel', 'coffee', 'espresso', 'butter', 'cookie', 'cake'] },
  { id: 'FLORAL', keywords: ['rose', 'violet', 'jasmine', 'blossom', 'honeysuckle', 'lilac', 'flower', 'floral', 'chamomile', 'lavender', 'elderflower'] },
  { id: 'EARTH', keywords: ['earth', 'earthy', 'mushroom', 'forest', 'soil', 'truffle', 'graphite', 'mineral', 'chalk', 'tar', 'petrol', 'stone', 'flint'] },
  { id: 'SMOKY', keywords: ['smoke', 'smoky', 'smoked', 'ash', 'burnt'] },
  { id: 'WOOD', keywords: ['oak', 'cedar', 'wood', 'woodsy', 'sandalwood', 'sawdust', 'barrel'] },
  { id: 'SALTY', keywords: ['saline', 'sea salt', 'salt', 'salty'] },
  { id: 'BRINY', keywords: ['briny', 'brine', 'sea breeze', 'sea spray', 'sea', 'ocean', 'oyster'] },
  { id: 'WAX', keywords: ['honey', 'beeswax', 'lanolin', 'wax'] },
  { id: 'NUT', keywords: ['almond', 'hazelnut', 'walnut', 'marzipan', 'nut'] },
];

export const FLAVOR_CLASS_COLORS: Record<FlavorClass, { color: string; icon: string; border: string; text: string }> = {
  SWEET: { color: '#f59e0b', icon: 'sparkles', border: '#b45309', text: '#fffbeb' },
  SOUR: { color: '#22c55e', icon: 'citrus', border: '#15803d', text: '#ecfdf3' },
  SALTY: { color: '#38bdf8', icon: 'droplet', border: '#0ea5e9', text: '#e0f2fe' },
  BITTER: { color: '#8b5cf6', icon: 'triangle', border: '#6d28d9', text: '#f3e8ff' },
  UMAMI: { color: '#14b8a6', icon: 'leaf', border: '#0d9488', text: '#e0f2f1' },
};

const SUBCLASS_TO_CLASS: Record<string, FlavorClass> = {
  CITRUS: 'SOUR',
  ORCHARD_FRUIT: 'SWEET',
  STONE_FRUIT: 'SWEET',
  TROPICAL: 'SWEET',
  RED_FRUIT: 'SWEET',
  DARK_FRUIT: 'SWEET',
  BERRY: 'SWEET',
  MARINE: 'SALTY',
  SALTY: 'SALTY',
  BRINY: 'SALTY',
  SPICE: 'BITTER',
  BAKING: 'SWEET',
  BREAD: 'SWEET',
  VEGETAL: 'UMAMI',
  HERBAL: 'UMAMI',
  EARTH: 'UMAMI',
  SMOKY: 'BITTER',
  WOOD: 'UMAMI',
  WAX: 'UMAMI',
  NUT: 'UMAMI',
  FLORAL: 'UMAMI',
  GAME: 'UMAMI',
  SAVORY: 'UMAMI',
};

export const categorizeFlavor = (note: string, subclassHint?: string): FlavorClass => {
  const subclass = (subclassHint || categorizeFlavorSubclass(note)).toUpperCase();
  return SUBCLASS_TO_CLASS[subclass] || 'UMAMI';
};

export const categorizeFlavorSubclass = (note: string): string => {
  const lower = note.toLowerCase();
  const match = FLAVOR_SUBCLASS_KEYWORDS.find(({ keywords }) => keywords.some(k => lower.includes(k)));
  return match ? match.id : 'FLAVOR';
};

// === Style categorization ===

export type StyleClassType = 'ORIGIN' | 'METHOD' | 'TYPE' | 'BLEND' | 'STYLE';

const ORIGIN_KEYWORDS = ['champagne', 'port', 'sherry', 'prosecco', 'cremant', 'cru beaujolais', 'super tuscan'];
const METHOD_KEYWORDS = ['sparkling', 'fortified', 'dessert', 'late harvest', 'ice wine', 'botrytis', 'petillant', 'natural wine', 'orange wine'];
const TYPE_KEYWORDS = ['full-body', 'full body', 'full-bodied', 'full bodied', 'light-body', 'light body', 'light-bodied', 'light bodied', 'medium-body', 'medium body', 'medium-bodied', 'medium bodied', 'aromatic', 'white', 'red', 'rose', 'sweet white', 'sparkling wine'];

export const getStyleClassType = (name: string, classification?: string): StyleClassType => {
  const normalized = normalizeLabel(name);
  const classOverride = classification?.toUpperCase();

  if (classOverride === 'ORIGIN' || classOverride === 'METHOD' || classOverride === 'TYPE' || classOverride === 'BLEND') {
    return classOverride as StyleClassType;
  }

  if (ORIGIN_KEYWORDS.some(k => normalized.includes(k))) return 'ORIGIN';
  if (TYPE_KEYWORDS.some(k => normalized.includes(k))) return 'TYPE';
  if (METHOD_KEYWORDS.some(k => normalized.includes(k))) return 'METHOD';
  return 'STYLE';
};

export type StyleColorType = 'RED' | 'WHITE' | 'ROSE' | 'ORANGE' | 'DUAL';

const STYLE_NAME_COLOR_OVERRIDES: Record<string, StyleColorType> = {
  'prosecco': 'WHITE',
  'champagne': 'WHITE',
  'cremant': 'WHITE',
  'cava': 'WHITE',
  'sparkling wine': 'WHITE',
  'sherry': 'WHITE',
  'port': 'RED',
  'gsm blend': 'RED',
  'bordeaux blend': 'RED',
  'super tuscan': 'RED',
  'cru beaujolais': 'RED',
  'dessert wine': 'WHITE',
  'late harvest': 'WHITE',
  'ice wine': 'WHITE',
  'botrytis wine': 'WHITE',
  'qvevri amber': 'ORANGE',
};

export const getColorType = (name: string): StyleColorType => {
  const n = normalizeLabel(name);
  const override = STYLE_NAME_COLOR_OVERRIDES[n.trim()];
  if (override) return override;
  if (/\borange\b/.test(n)) return 'ORANGE';
  if (/\brose\b/.test(n)) return 'ROSE';
  if (/\bred\b/.test(n)) return 'RED';
  if (/\bwhite\b/.test(n)) return 'WHITE';
  return 'DUAL';
};

export const getStyleColorType = getColorType;

// === Entry lookup ===

export const matchesEntryKey = (entry: WineEntry, cleanName: string) => {
  if (normalizeKey(entry.name) === cleanName) return true;
  const synonyms = (entry.details as { synonyms?: string[] }).synonyms;
  if (synonyms?.some((s) => normalizeKey(s) === cleanName)) return true;
  return false;
};

export function findEntryByName(entries: WineEntry[], name: string): WineEntry | undefined;
export function findEntryByName<C extends DataCategory>(
  entries: WineEntry[],
  name: string,
  category: C,
): Extract<WineEntry, { category: C }> | undefined;
export function findEntryByName(
  entries: WineEntry[],
  name: string,
  category?: EntryCategory,
): WineEntry | undefined {
  const clean = normalizeKey(name);
  return entries.find((entry) => {
    if (category && entry.category !== category) return false;
    return matchesEntryKey(entry, clean);
  });
}

export const findRelatedEntry = (
  entries: WineEntry[],
  name: string,
  preferredCategory?: EntryCategory,
): WineEntry | undefined => {
  const cleanName = normalizeKey(name);

  const exactInPreferred = preferredCategory
    ? entries.find((entry) => entry.category === preferredCategory && matchesEntryKey(entry, cleanName))
    : undefined;
  if (exactInPreferred) return exactInPreferred;

  const exactAny = entries.find((entry) => matchesEntryKey(entry, cleanName));
  if (exactAny) return exactAny;

  const fallbackPool = preferredCategory
    ? [
        ...entries.filter((entry) => entry.category === preferredCategory),
        ...entries.filter((entry) => entry.category !== preferredCategory),
      ]
    : entries;

  const cleanTokens = cleanName.split(' ').filter(Boolean);
  return fallbackPool.find((entry) => {
    const entryKey = normalizeKey(entry.name);
    if (!entryKey) return false;

    const entryTokens = entryKey.split(' ').filter(Boolean);
    if (cleanTokens.length > 1 && entryTokens.length === 1) return false;
    return entryKey.includes(cleanName) || cleanName.includes(entryKey);
  });
};

export const findExactFlavorEntry = (entries: WineEntry[], name: string) =>
  findEntryByName(entries, name, 'FLAVORS');

export const findExactGrapeEntry = (entries: WineEntry[], name: string) =>
  findEntryByName(entries, name, 'GRAPES');
