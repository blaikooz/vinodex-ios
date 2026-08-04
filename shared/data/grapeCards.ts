import type { GrapeCard, RarityTier } from '../types.ts';
import { GRAPES as LEGACY_GRAPES } from './grapes.ts';

const toRarityTier = (old?: string): RarityTier => {
  switch (old) {
    case 'COMMON': return 'common';
    case 'UNCOMMON': return 'uncommon';
    case 'RARE': return 'rare';
    case 'NOBLE': return 'noble';
    case 'GODFORSAKEN': return 'godforsaken';
    default: return 'uncommon';
  }
};

/**
 * Descriptive level -> a 0-5 stat bar (0.7.4, sommbot's audit).
 *
 * **Tests run longest-match-first, and that is load-bearing**, because every
 * test is a substring test: `'Medium-High'.includes('high')` is true, so a bare
 * `high` placed above `medium-high` swallows it. Two things were wrong here.
 *
 * The consequential one: **`"None"` matched nothing and fell through to the
 * default of 3**, so all 60 white grapes carrying `tannin: "None"` drew a
 * half-full tannin bar -- the one value the bar exists to distinguish, rendered
 * as the middle of the scale. It is now 0, an empty bar, which is the truth.
 *
 * The lesser one: `medium-high` sat below `high` and was dead code, and
 * `Medium-Low`/`Low-Medium` fell into `medium`. Both are corrected here for the
 * function's sake; neither moves a rendered value, because the two call sites
 * round and `Math.round(3.5) === 4` and `Math.round(2.5) === 3` are what those
 * inputs already produced. Only the `none` line changes what anybody sees.
 *
 * `bodyFromText` below had the same defect shape and was deliberately left
 * alone in that batch. It is fixed in 0.7.5 (E) -- see its own note.
 */
const levelFromText = (text?: string) => {
  if (!text) return 3;
  const t = text.toLowerCase();
  if (t.includes('none')) return 0;
  if (t.includes('very high')) return 5;
  if (t.includes('medium-high') || t.includes('high-medium')) return 3.5;
  if (t.includes('medium-full') || t.includes('full-medium')) return 4;
  if (t.includes('medium-low') || t.includes('low-medium')) return 2.5;
  if (t.includes('high')) return 4;
  if (t.includes('medium')) return 3;
  if (t.includes('low')) return 2;
  return 3;
};

/**
 * Body text -> a 0-5 stat bar (0.7.5, E).
 *
 * **The same longest-match-first rule as `levelFromText` above, and this one
 * cost a rendered value.** `full` sat at the top and every test is a substring
 * test, so `'Medium-Full'.includes('full')` was true and the `medium-full`
 * line below it had never once executed: **the 16 grapes authored
 * `body: "Medium-Full"` drew a 5/5 bar**, identical to the 34 authored
 * `"Full"`. Chardonnay and Merlot read as full-bodied as Cabernet Sauvignon
 * and Syrah, which is the one distinction a body bar exists to draw. They are
 * 4/5 now.
 *
 * `light-medium` was dead in the same way -- `'Light-Medium'.includes('medium')`
 * -- and is corrected here for the function's sake rather than for anything
 * visible: the 22 grapes carrying it round to 3 either way, because the call
 * site rounds and `Math.round(2.5) === 3` is what `medium` already returned.
 *
 * So one input moves and one does not, and both branches are now reachable,
 * which is what stops the next reader from having to re-derive this.
 */
const bodyFromText = (text?: string) => {
  if (!text) return 3;
  const t = text.toLowerCase();
  if (t.includes('medium-full') || t.includes('full-medium')) return 4;
  if (t.includes('light-medium') || t.includes('medium-light')) return 2.5;
  if (t.includes('full')) return 5;
  if (t.includes('medium')) return 3;
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
