// === Normalization ===

const DIACRITIC_RANGE = /[̀-ͯ]/g;

const normalizeLabel = (value: string) =>
  value
    .toLowerCase()
    .normalize('NFD')
    .replace(DIACRITIC_RANGE, '');

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

