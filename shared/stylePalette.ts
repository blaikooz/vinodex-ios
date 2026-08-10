export type StyleColorKey =
  | 'full-bodied red'
  | 'bright red'
  | 'light-bodied red'
  | 'dark red'
  | 'medium-bodied red'
  | 'rosé'
  | 'pink'
  | 'light-bodied white'
  | 'aromatic white'
  | 'high-acid white'
  | 'full-bodied white'
  | 'sweet white'
  | 'medium-bodied white';

export interface StyleColorPair {
  primary: string;
  secondary: string;
}

const BASE_STYLE_COLORS: Record<StyleColorKey, StyleColorPair> = {
  'full-bodied red': { primary: '#2b0a0e', secondary: '#5a0f18' },
  'bright red': { primary: '#5b0f1f', secondary: '#dc143c' },
  'light-bodied red': { primary: '#4f1f28', secondary: '#8b3f4c' },
  'dark red': { primary: '#3f1024', secondary: '#70193d' },
  'medium-bodied red': { primary: '#5e2b30', secondary: '#e96b6b' },
  rosé: { primary: '#5b2c36', secondary: '#f6b6c0' },
  pink: { primary: '#5b2c36', secondary: '#f6b6c0' },
  'light-bodied white': { primary: '#334155', secondary: '#ffffff' },
  'aromatic white': { primary: '#3f2e1a', secondary: '#daa520' },
  'high-acid white': { primary: '#1f2937', secondary: '#e5e7eb' },
  'full-bodied white': { primary: '#3b2315', secondary: '#f4a261' },
  'sweet white': { primary: '#3a2412', secondary: '#b5651d' },
  'medium-bodied white': { primary: '#2f261b', secondary: '#d6bfa3' },
};

// Reverse the tones so former secondary becomes primary and vice versa
export const STYLE_TONE_PALETTE: Record<StyleColorKey, StyleColorPair> = Object.fromEntries(
  Object.entries(BASE_STYLE_COLORS).map(([key, val]) => [
    key,
    { primary: val.secondary, secondary: val.primary },
  ])
) as Record<StyleColorKey, StyleColorPair>;
