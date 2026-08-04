/**
 * Chip colour tables. Deliberately free of any framework import: this file is
 * read both by the web app and by the native generator running under plain
 * ts-node, where `react` is not a dependency.
 */

export interface ChipColorStyle {
  bg: string;
  border: string;
  text: string;
}

export const getCountryChipColors = (country?: string): ChipColorStyle => {
  const map: Record<string, ChipColorStyle> = {
    france:        { bg: '#0f172a', border: '#1d4ed8', text: '#dbeafe' },
    italy:         { bg: '#052e16', border: '#16a34a', text: '#bbf7d0' },
    spain:         { bg: '#450a0a', border: '#dc2626', text: '#fecdd3' },
    usa:           { bg: '#1e1b4b', border: '#4338ca', text: '#c7d2fe' },
    germany:       { bg: '#422006', border: '#d97706', text: '#fde68a' },
    portugal:      { bg: '#064e3b', border: '#10b981', text: '#d1fae5' },
    australia:     { bg: '#7c2d12', border: '#f97316', text: '#ffedd5' },
    'new zealand': { bg: '#0f172a', border: '#14b8a6', text: '#99f6e4' },
    argentina:     { bg: '#0c4a6e', border: '#38bdf8', text: '#e0f2fe' },
    chile:         { bg: '#7f1d1d', border: '#f97316', text: '#fee2e2' },
    'south africa':{ bg: '#312e81', border: '#a21caf', text: '#e0e7ff' },
    austria:       { bg: '#831843', border: '#f472b6', text: '#ffe4e6' },
    greece:        { bg: '#0e7490', border: '#22d3ee', text: '#e0f2fe' },
    hungary:       { bg: '#365314', border: '#84cc16', text: '#f7fee7' },
    canada:        { bg: '#7f1d1d', border: '#ef4444', text: '#fee2e2' },
    china:         { bg: '#854d0e', border: '#f59e0b', text: '#fffbeb' },
    japan:         { bg: '#9f1239', border: '#f472b6', text: '#fff1f2' },
    india:         { bg: '#713f12', border: '#f59e0b', text: '#fef3c7' },
    georgia:       { bg: '#422006', border: '#f59e0b', text: '#fef3c7' },
    uruguay:       { bg: '#312e81', border: '#8b5cf6', text: '#ede9fe' },
    croatia:       { bg: '#1e293b', border: '#3b82f6', text: '#e0f2fe' },
    // Batch 2 (0.6.4): the four countries that had been falling through to
    // the grey fallback despite appearing in continent rosters...
    mexico:        { bg: '#14532d', border: '#22c55e', text: '#dcfce7' },
    // Brazil (0.7.3c), added with the country so its rows chip in colour
    // from the first build rather than falling through to the grey.
    brazil:        { bg: '#083d21', border: '#facc15', text: '#fef9c3' },
    morocco:       { bg: '#7f1d1d', border: '#16a34a', text: '#fee2e2' },
    romania:       { bg: '#1e3a8a', border: '#facc15', text: '#fef9c3' },
    switzerland:   { bg: '#7f1d1d', border: '#f8fafc', text: '#fee2e2' },
    // ...and the coming-soon gates, so their rows chip in colour from day one.
    'united kingdom': { bg: '#1e293b', border: '#dc2626', text: '#dbeafe' },
    slovenia:      { bg: '#0f172a', border: '#0ea5e9', text: '#e0f2fe' },
    bulgaria:      { bg: '#14532d', border: '#dc2626', text: '#dcfce7' },
    lebanon:       { bg: '#450a0a', border: '#16a34a', text: '#fecdd3' },
  };
  const key = (country || '').toLowerCase();
  return map[key] || { bg: '#0b0f19', border: '#374151', text: '#e5e7eb' };
};

export const getClassificationChipColors = (classification?: string): ChipColorStyle => {
  const map: Record<string, ChipColorStyle> = {
    aoc:          { bg: '#3f1d2e', border: '#f43f5e', text: '#ffe4e6' },
    docg:         { bg: '#422006', border: '#f59e0b', text: '#fef3c7' },
    doc:          { bg: '#451a03', border: '#ea580c', text: '#ffedd5' },
    doca:         { bg: '#713f12', border: '#fcd34d', text: '#fef3c7' },
    ava:          { bg: '#1e1b4b', border: '#6366f1', text: '#e0e7ff' },
    gi:           { bg: '#064e3b', border: '#22c55e', text: '#d1fae5' },
    pdo:          { bg: '#312e81', border: '#a855f7', text: '#ede9fe' },
    pgi:          { bg: '#0f172a', border: '#14b8a6', text: '#ccfbf1' },
    igp:          { bg: '#1a2e05', border: '#84cc16', text: '#ecfccb' },
    wo:           { bg: '#1a1a2e', border: '#f97316', text: '#ffedd5' },
    vqa:          { bg: '#7f1d1d', border: '#ef4444', text: '#fee2e2' },
    dac:          { bg: '#831843', border: '#f472b6', text: '#ffe4e6' },
    do:           { bg: '#450a0a', border: '#dc2626', text: '#fecdd3' },
  };
  const key = (classification || '').toLowerCase().replace(/[^a-z]/g, '');
  return map[key] || { bg: '#1f2937', border: '#4b5563', text: '#e5e7eb' };
};

export const getWineTypeChipColors = (wineType?: string): ChipColorStyle => {
  const t = (wineType || '').toLowerCase();

  // Type chips shade with body (0.6.x): reds run light -> dark red and whites
  // light -> dark green, so the chip alone carries the weight axis. Sweet and
  // aromatic keep colours of their own — they are about the nose, not weight.
  if (t.includes('red') || t.includes('bold')) {
    if (t.includes('light')) return { bg: '#8a3242', border: '#e0525f', text: '#ffd6da' };
    if (t.includes('full'))  return { bg: '#450a0a', border: '#991b1b', text: '#f87171' };
    return { bg: '#701a1a', border: '#c02626', text: '#fca5a5' };
  }
  if (t.includes('sweet'))    return { bg: '#9a3412', border: '#ea580c', text: '#fed7aa' };
  if (t.includes('aromatic')) return { bg: '#274a1e', border: '#65a30d', text: '#d9f99d' };
  if (t.includes('white')) {
    if (t.includes('light')) return { bg: '#3e661a', border: '#a3e635', text: '#f0fdf4' };
    if (t.includes('full'))  return { bg: '#0f2a15', border: '#166534', text: '#86efac' };
    return { bg: '#1f4416', border: '#4d7c0f', text: '#bef264' };
  }
  if (t.includes('rosé') || t.includes('rose')) return { bg: '#9d174d', border: '#db2777', text: '#fbcfe8' };
  if (t.includes('sparkling'))                  return { bg: '#a16207', border: '#eab308', text: '#fef9c3' };
  if (t.includes('orange'))                     return { bg: '#7c2d12', border: '#ea580c', text: '#fed7aa' };
  return { bg: '#57534e', border: '#78716c', text: '#e7e5e4' };
};

export const getRarityChipColors = (rarity?: string): ChipColorStyle => {
  switch (rarity) {
    case 'COMMON':   return { bg: '#3f3f46', border: '#52525b', text: '#e4e4e7' };
    case 'UNCOMMON': return { bg: '#064e3b', border: '#16a34a', text: '#d1fae5' };
    case 'RARE':     return { bg: '#111827', border: '#2563eb', text: '#dbeafe' };
    case 'NOBLE':    return { bg: '#3b0764', border: '#9333ea', text: '#f3e8ff' };
    // Above NOBLE (0.6.2): cursed gold on near-black.
    case 'GODFORSAKEN': return { bg: '#292010', border: '#ca8a04', text: '#fde047' };
    default:         return { bg: '#3f3f46', border: '#52525b', text: '#e4e4e7' };
  }
};

export const getColorTypeChipColors = (type?: string): ChipColorStyle => {
  switch (type) {
    case 'RED':    return { bg: '#3b0f0f', border: '#8b0000', text: '#fecdd3' };
    case 'WHITE':  return { bg: '#3b2f00', border: '#b8860b', text: '#fef3c7' };
    case 'ROSÉ':
    case 'ROSE':   return { bg: '#4a0e2a', border: '#db2777', text: '#fbcfe8' };
    case 'ORANGE': return { bg: '#451a03', border: '#ea580c', text: '#ffedd5' };
    case 'DUAL':   return { bg: '#2d0a1e', border: '#be185d', text: '#fce7f3' };
    default:       return { bg: '#1c1917', border: '#57534e', text: '#e7e5e4' };
  }
};

export const getStyleClassChipColors = (type?: string): ChipColorStyle => {
  switch (type) {
    case 'STYLE':  return { bg: '#0a0f0a', border: '#16a34a', text: '#bbf7d0' };
    case 'METHOD': return { bg: '#1e1b4b', border: '#7c3aed', text: '#ede9fe' };
    case 'ORIGIN': return { bg: '#422006', border: '#d97706', text: '#fde68a' };
    case 'TYPE':   return { bg: '#0f172a', border: '#0891b2', text: '#cffafe' };
    case 'BLEND':  return { bg: '#2e1065', border: '#f97316', text: '#ffedd5' };
    default:       return { bg: '#0a0f0a', border: '#16a34a', text: '#bbf7d0' };
  }
};

export const getFlavorClassChipColors = (cls?: string): ChipColorStyle => {
  switch ((cls || '').toUpperCase()) {
    case 'SWEET':  return { bg: '#451a03', border: '#d97706', text: '#fde68a' };
    case 'SOUR':   return { bg: '#1a2e05', border: '#65a30d', text: '#d9f99d' };
    case 'SALTY':  return { bg: '#0c2340', border: '#0284c7', text: '#bae6fd' };
    case 'BITTER': return { bg: '#2e1065', border: '#7c3aed', text: '#ede9fe' };
    case 'UMAMI':  return { bg: '#022c22', border: '#0d9488', text: '#ccfbf1' };
    default:       return { bg: '#1c1917', border: '#57534e', text: '#e7e5e4' };
  }
};

export const getFlavorSubclassChipColors = (sub?: string): ChipColorStyle => {
  switch ((sub || '').toUpperCase()) {
    case 'CITRUS':        return { bg: '#431407', border: '#ea580c', text: '#ffedd5' };
    case 'ORCHARD_FRUIT': return { bg: '#1a2e05', border: '#65a30d', text: '#d9f99d' };
    case 'STONE_FRUIT':   return { bg: '#451a03', border: '#f97316', text: '#ffedd5' };
    case 'TROPICAL':      return { bg: '#422006', border: '#d97706', text: '#fef3c7' };
    case 'RED_FRUIT':     return { bg: '#450a0a', border: '#dc2626', text: '#fecdd3' };
    case 'DARK_FRUIT':    return { bg: '#2e1065', border: '#7c3aed', text: '#ede9fe' };
    case 'BERRY':         return { bg: '#4c0519', border: '#e11d48', text: '#fecdd3' };
    case 'HERBAL':        return { bg: '#022c22', border: '#0d9488', text: '#ccfbf1' };
    case 'VEGETAL':       return { bg: '#052e16', border: '#16a34a', text: '#bbf7d0' };
    case 'SPICE':         return { bg: '#451a03', border: '#d97706', text: '#fde68a' };
    case 'BAKING':        return { bg: '#3b1f0a', border: '#b45309', text: '#fde68a' };
    case 'FLORAL':        return { bg: '#4a0e2a', border: '#db2777', text: '#fbcfe8' };
    case 'EARTH':         return { bg: '#1c1917', border: '#78716c', text: '#e7e5e4' };
    case 'WOOD':          return { bg: '#292524', border: '#92400e', text: '#fde68a' };
    case 'MARINE':        return { bg: '#0c2340', border: '#0284c7', text: '#bae6fd' };
    case 'WAX':           return { bg: '#422006', border: '#b45309', text: '#fef3c7' };
    case 'NUT':           return { bg: '#3b2f00', border: '#a16207', text: '#fef9c3' };
    default:              return { bg: '#1c1917', border: '#57534e', text: '#e7e5e4' };
  }
};

export const SYSTEM_CHIP_COLOR: ChipColorStyle = {
  bg: 'rgba(127,29,29,0.7)',
  border: '#ef4444',
  text: '#fca5a5',
};

export const CLIMATE_CHIP_COLOR: ChipColorStyle = {
  bg: 'rgba(20,83,45,0.7)',
  border: '#22c55e',
  text: '#86efac',
};

export const BLUE_CHIP_COLOR: ChipColorStyle = {
  bg: 'rgba(30,58,138,0.7)',
  border: '#3b82f6',
  text: '#93c5fd',
};

export const APPELLATION_CHIP_COLORS: ChipColorStyle[] = [
  SYSTEM_CHIP_COLOR,
  CLIMATE_CHIP_COLOR,
  BLUE_CHIP_COLOR,
];

export const extractTagAbbrev = (tag: string): string =>
  (tag.split(/[\s(]/)[0] ?? '').toUpperCase();
