import type { GrapeCard, RarityTier } from '../types.ts';
import { GRAPES as LEGACY_GRAPES } from './grapes.ts';

const toRarityTier = (old?: string): RarityTier => {
  switch (old) {
    case 'COMMON': return 'common';
    case 'UNCOMMON': return 'uncommon';
    case 'RARE': return 'rare';
    case 'NOBLE': return 'noble';
    default: return 'uncommon';
  }
};

const levelFromText = (text?: string) => {
  if (!text) return 3;
  const t = text.toLowerCase();
  if (t.includes('very high')) return 5;
  if (t.includes('high')) return 4;
  if (t.includes('medium-high') || t.includes('high-medium')) return 3.5;
  if (t.includes('medium-full') || t.includes('full-medium')) return 4;
  if (t.includes('medium')) return 3;
  if (t.includes('low')) return 2;
  return 3;
};

const bodyFromText = (text?: string) => {
  if (!text) return 3;
  const t = text.toLowerCase();
  if (t.includes('full')) return 5;
  if (t.includes('medium-full')) return 4;
  if (t.includes('medium')) return 3;
  if (t.includes('light-medium')) return 2.5;
  if (t.includes('light')) return 2;
  return 3;
};

const slugify = (str: string) => str.toLowerCase().replace(/\s+/g, '-');

export const GRAPE_CARDS: GrapeCard[] = LEGACY_GRAPES.map((legacy) => {
  const type = (legacy.wineType || '').toLowerCase().includes('red') ? 'red' : 'white';
  const styleName = legacy.wineType || legacy.details.body || 'Unknown Style';
  const tastingProfile = (legacy.tastingProfile || []).slice(0, 3).map(t => t.note);
  const rarityTier = toRarityTier(legacy.rarity);
  const styleId = rarityTier === 'noble' ? 'noble-grapes' : slugify(styleName);
  return {
    id: legacy.id,
    name: legacy.name,
    type,
    style: styleName,
    styleId,
    countryOfOrigin: legacy.details.origin || 'Unknown',
    alternateNames: legacy.details.synonyms || [],
    rarityTier,
    characteristics: {
      tannin: Math.round(levelFromText(legacy.details.tannin)),
      acid: Math.round(levelFromText(legacy.details.acidity)),
      colorIntensity: type === 'red' ? 4 : 2,
      aromatics: Math.round((tastingProfile.length || 1) + 2),
      body: Math.round(bodyFromText(legacy.details.body)),
    },
    tastingProfile,
    notableRegions: legacy.details.keyRegions || [],
    info: legacy.description,
  };
});
