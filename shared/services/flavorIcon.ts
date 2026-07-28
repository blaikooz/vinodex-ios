/**
 * Pure flavor-name -> Iconify id lookup, extracted from `FlavorIcon.jsx`.
 *
 * This has no React/JSX dependency, so it can be imported by non-component
 * consumers — notably `native/scripts/generate.ts`, which runs under a plain
 * Node/ts-node script and can't load `.jsx` files. `FlavorIcon.jsx` re-exports
 * everything from here so existing imports of it keep working unchanged.
 */

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
