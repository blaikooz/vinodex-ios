export const isLightColor = (hex: string): boolean => {
  const clean = hex.replace('#', '');
  if (clean.length !== 6) return false;
  const r = parseInt(clean.substring(0, 2), 16);
  const g = parseInt(clean.substring(2, 4), 16);
  const b = parseInt(clean.substring(4, 6), 16);
  return (0.299 * r + 0.587 * g + 0.114 * b) > 160;
};

export const darkenHex = (hex: string, amount = 0.35): string => {
  const clean = hex.replace('#', '');
  if (clean.length !== 6) return hex;
  const toChannel = (start: number) => {
    const channel = parseInt(clean.substring(start, start + 2), 16);
    const darkened = Math.max(0, Math.min(255, Math.round(channel * (1 - amount))));
    return darkened.toString(16).padStart(2, '0');
  };
  return `#${toChannel(0)}${toChannel(2)}${toChannel(4)}`;
};

const REGION_CLASSIFICATION_ICON_COLORS: Record<string, string> = {
  aoc: '#f43f5e',
  docg: '#f59e0b',
  doc: '#ea580c',
  doca: '#fcd34d',
  ava: '#6366f1',
  gi: '#22c55e',
  pdo: '#a855f7',
  pgi: '#14b8a6',
  igp: '#84cc16',
};

export const getRegionClassificationIconColor = (classification?: string): string => {
  const key = classification ? classification.toLowerCase() : '';
  return REGION_CLASSIFICATION_ICON_COLORS[key] || '#e5e7eb';
};

const FLAVOR_SUBCLASS_ICON_COLORS: Record<string, string> = {
  CITRUS: '#f97316',
  ORCHARD_FRUIT: '#84cc16',
  STONE_FRUIT: '#fb923c',
  TROPICAL: '#eab308',
  RED_FRUIT: '#ef4444',
  DARK_FRUIT: '#8b5cf6',
  BERRY: '#e11d48',
  HERBAL: '#34d399',
  VEGETAL: '#22c55e',
  SPICE: '#d97706',
  BAKING: '#c08457',
  FLORAL: '#ec4899',
  EARTH: '#78716c',
  WOOD: '#8b5a2b',
  MARINE: '#0ea5e9',
  WAX: '#f59e0b',
  NUT: '#eab308',
};

export const getFlavorSubclassIconColor = (sub?: string): string => {
  const key = (sub || '').toUpperCase();
  return FLAVOR_SUBCLASS_ICON_COLORS[key] || '#e5e7eb';
};
