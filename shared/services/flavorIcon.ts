/**
 * Pure flavor-name -> Iconify id lookup, extracted from `FlavorIcon.jsx`.
 *
 * This has no React/JSX dependency, so it can be imported by non-component
 * consumers — notably `native/scripts/generate.ts`, which runs under a plain
 * Node/ts-node script and can't load `.jsx` files. `FlavorIcon.jsx` re-exports
 * everything from here so existing imports of it keep working unchanged.
 */

/**
 * Glyph per flavour *class* — the five top-level tastes.
 *
 * Keyed and named to match `FLAVOR_CLASS_COLORS` in `entryUtils.ts`, whose
 * `icon` field carries these same lucide names; spelled as Iconify ids here
 * because that is what the iOS rasteriser consumes. Deliberately abstract marks
 * rather than foods, so a class icon can never collide with one of its own
 * subclasses' icons below.
 */
export const FLAVOR_CLASS_ICON_MAP: Record<string, string> = {
  sweet: 'lucide:sparkles',
  sour: 'lucide:citrus',
  salty: 'lucide:droplet',
  bitter: 'lucide:triangle',
  umami: 'lucide:leaf',
};

export const FLAVOR_ICON_MAP: Record<string, string> = {
  'orchard fruit': 'game-icons:shiny-apple',
  'stone fruit': 'game-icons:peach',
  'tropical': 'game-icons:banana-bunch',
  'red fruit': 'game-icons:cherry',
  'berry': 'game-icons:elderberry',
  'dark fruit': 'game-icons:blackcurrant',
  'citrus': 'game-icons:cut-lemon',
  'herbal': 'game-icons:herbs-bundle',
  'vegetal': 'game-icons:bok-choy',
  'nut': 'game-icons:almond',
  'baking': 'game-icons:cookie',
  'bread': 'game-icons:sliced-bread',
  'wax': 'game-icons:honeycomb',
  'earth': 'game-icons:mushrooms',
  'smoky': 'game-icons:burn',
  'spice': 'game-icons:hot-spices',
  'savory': 'game-icons:charcuterie',
  'briny': 'game-icons:mussel',
  'salty': 'game-icons:salt-shaker',
  'floral': 'game-icons:lotus-flower',
  'game': 'game-icons:deer',
  // WOOD was the one subclass in `SUBCLASS_TO_CLASS` with no entry here, so it
  // fell through to the question-mark fallback wherever a subclass glyph was
  // asked for. Oak, not a tree: in wine, wood means the barrel.
  'wood': 'game-icons:oak-leaf',
};

export const FLAVOR_NAME_ICON_MAP: Record<string, string> = {
  // Orchard
  'apple': 'game-icons:shiny-apple',
  'red apple': 'game-icons:shiny-apple',
  'green apple': 'game-icons:apple-core',
  'pear': 'game-icons:pear',
  // Stone
  'peach': 'game-icons:peach',
  'white peach': 'game-icons:peach',
  // Tropical
  'banana': 'game-icons:banana',
  'pineapple': 'game-icons:pineapple',
  // Red fruit
  'cherry': 'game-icons:cherry',
  'red cherry': 'game-icons:cherry',
  'black cherry': 'game-icons:cherry',
  'sour cherry': 'game-icons:cherry',
  // Dark fruit
  'plum': 'game-icons:plum',
  'black plum': 'game-icons:plum',
  // Berry
  'strawberry': 'game-icons:strawberry',
  'strawberry candy': 'game-icons:jelly-beans',
  'raspberry': 'game-icons:raspberry',
  'blackcurrant': 'game-icons:blackcurrant',
  'blackberry jam': 'game-icons:mason-jar',
  'jammy berry': 'game-icons:jelly',
  // Citrus
  'lemon': 'game-icons:cut-lemon',
  'lemon zest': 'game-icons:cut-lemon',
  'lemon curd': 'game-icons:cut-lemon',
  'orange': 'game-icons:orange-slice',
  // Floral
  'rose': 'game-icons:rose',
  'rose petal': 'game-icons:rose',
  // Herbal
  'tea leaf': 'game-icons:teapot-leaves',
  'herbal tea': 'game-icons:teapot',
  'grass': 'game-icons:high-grass',
  // Vegetal
  'bell pepper': 'game-icons:bell-pepper',
  'green pepper': 'game-icons:bell-pepper',
  'tomato': 'game-icons:tomato',
  'tomato leaf': 'game-icons:tomato',
  'olive': 'game-icons:olive',
  // Spice
  'clove': 'game-icons:clover',
  // Baking
  'vanilla': 'game-icons:vanilla-flower',
  'chocolate': 'game-icons:chocolate-bar',
  'dark chocolate': 'game-icons:chocolate-bar',
  'cocoa': 'game-icons:chocolate-bar',
  'coffee': 'game-icons:coffee-beans',
  'espresso': 'game-icons:coffee-cup',
  'butter': 'game-icons:butter',
  // Nut
  'almond': 'game-icons:almond',
  // Wax / honey
  'honey': 'game-icons:honey-jar',
  'beeswax': 'game-icons:beehive',
  // Wood
  'oak': 'game-icons:oak-leaf',
  'cedar': 'game-icons:pine-tree',
  // Earth / mineral
  'mushroom': 'game-icons:mushroom',
  'truffle': 'game-icons:mushroom-gills',
  'mineral': 'game-icons:rock',
  'stone': 'game-icons:stone-pile',
  'graphite': 'game-icons:gold-bar',
  'petrol': 'game-icons:gas-pump',
  // Smoky
  'smoke': 'game-icons:smoking-pipe',
  'volcanic ash': 'game-icons:volcano',
  // Savory / game
  'leather': 'game-icons:leather-vest',
  'game': 'game-icons:deer',
};

const FALLBACK_ICON = 'mdi:help-circle-outline';

const normalizeKey = (value?: string): string =>
  typeof value === 'string'
    ? value.toLowerCase().replace(/_/g, ' ').trim()
    : '';

export const resolveFlavorIcon = (name?: string, subclass?: string): string => {
  const nameKey = normalizeKey(name);
  if (nameKey && FLAVOR_NAME_ICON_MAP[nameKey]) return FLAVOR_NAME_ICON_MAP[nameKey];
  const subKey = normalizeKey(subclass);
  if (subKey && FLAVOR_ICON_MAP[subKey]) return FLAVOR_ICON_MAP[subKey];
  return FALLBACK_ICON;
};

/**
 * Glyph for a flavour subclass alone, ignoring any note's name.
 *
 * `resolveFlavorIcon` prefers the per-note map, which is right for an *entry* —
 * "Blackberry jam" should be a jam jar, not the generic berry. It is the wrong
 * answer when the thing being labelled is the subclass itself: the flavour
 * scan's CLASS and SUBCLASS tiles both showed the glyph of whichever entry you
 * had opened, so a subclass wore a different icon on every page and the two
 * tiles were always identical to each other.
 */
export const resolveFlavorSubclassIcon = (subclass?: string): string =>
  FLAVOR_ICON_MAP[normalizeKey(subclass)] ?? FALLBACK_ICON;

/** Glyph for a flavour class (SWEET / SOUR / SALTY / BITTER / UMAMI). */
export const resolveFlavorClassIcon = (cls?: string): string =>
  FLAVOR_CLASS_ICON_MAP[normalizeKey(cls)] ?? FALLBACK_ICON;
