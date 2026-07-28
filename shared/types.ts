
export type EntryCategory = 'GRAPES' | 'REGIONS' | 'STYLES' | 'FLAVORS' | 'MASTER_SEARCH' | 'WORLD_SEARCH' | 'COUNTRY_GATE' | 'CONTINENTS' | 'RETRO_GLOBE';

export type DataCategory = 'GRAPES' | 'REGIONS' | 'STYLES' | 'FLAVORS' | 'CONTINENTS' | 'COUNTRY_GATE';

export type RarityTier = 'common' | 'uncommon' | 'rare' | 'epic' | 'noble';

export type RarityLabel = 'COMMON' | 'UNCOMMON' | 'RARE' | 'NOBLE';

export type ClimateClass = 'maritime' | 'continental' | 'cool' | 'warm' | 'mediterranean';

export type GrapeBodyClass = 'Light' | 'Light-Medium' | 'Medium' | 'Medium-Full' | 'Full';

export interface GrapeCharacteristics {
  tannin: number;        // 0–5
  acid: number;          // 0–5
  colorIntensity: number;// 0–5
  aromatics: number;     // 0–5
  body: number;          // 0–5
}

export interface RegionAffinity {
  region: string;
  bonus: string; // e.g. "+2 Structure"
}

export interface GrapeCard {
  id: string;
  name: string;
  type: 'red' | 'white';
  style: string; // e.g., "full-bodied red"
  countryOfOrigin: string;
  alternateNames: string[];
  rarityTier: RarityTier;
  evolutionLine?: string[];
  signatureMove?: string;
  discoveryYear?: number;
  regionAffinity?: RegionAffinity[];
  characteristics: GrapeCharacteristics;
  tastingProfile: string[];
  notableRegions: string[];
  info: string;
  // cross-links
  styleId?: string;
}

export interface WineStyle {
  id: string;
  name: string;
  type: 'red' | 'white';
  description: string;
  tastingProfile?: TastingNote[];
  notableGrapes?: string[];
  keyRegions?: string[];
}

export type TastingNoteIcon =
  | 'circle' | 'triangle' | 'leaf' | 'cloud' | 'sun' | 'mountain'
  | 'sparkles' | 'flame' | 'droplet' | 'shield' | 'flower' | 'fruit'
  | 'herb' | 'spice' | 'mineral' | 'oak' | 'smoke' | 'stone'
  | 'tropical' | 'flag' | 'honey' | 'nut' | 'default';

export interface TastingNote {
  note: string;
  icon: TastingNoteIcon;
  color: string;
}

// === Discriminated union variants for WineEntry ===

interface BaseEntry {
  id: string;
  name: string;
  description: string;
  color: string;
  tags: string[];
  icon?: string;
  tileCallback?: string;
  iconCallback?: string;
}

export interface GrapeDetails {
  origin: string;
  synonyms: string[];
  keyRegions: string[];
  body: GrapeBodyClass | string;
  acidity?: string;
  tannin?: string;
  classification?: string;
}

export interface GrapeEntry extends BaseEntry {
  category: 'GRAPES';
  tastingProfile?: TastingNote[];
  wineType?: string;
  grapeType: 'red' | 'white';
  grapeStyle: string;
  grapeBodyClass: GrapeBodyClass;
  grapeCharacteristics: GrapeCharacteristics;
  grapeAlternateNames: string[];
  grapeNotableRegions: string[];
  grapeCountryOfOrigin: string;
  grapeRarityTier: RarityTier;
  grapeCard: GrapeCard;
  rarity: RarityLabel;
  details: GrapeDetails;
}

export interface RegionDetails {
  origin: string;
  state?: string;
  notableGrapes: string[];
  classification: string;
  appellations?: string[];
  soilType?: string;
  synonyms?: string[];
}

export interface RegionEntry extends BaseEntry {
  category: 'REGIONS';
  climate?: ClimateClass;
  climateDescription?: string;
  details: RegionDetails;
}

export interface StyleDetails {
  origin: string;
  body?: string;
  tannin?: string;
  acidity?: string;
  keyRegions: string[];
  notableGrapes: string[];
  classification: string;
}

export interface StyleEntry extends BaseEntry {
  category: 'STYLES';
  rarity?: RarityLabel;
  tastingProfile?: TastingNote[];
  details: StyleDetails;
}

export interface FlavorDetails {
  classification: string;
  subclass: string;
  notableGrapes: string[];
}

export interface FlavorEntry extends BaseEntry {
  category: 'FLAVORS';
  tastingProfile: TastingNote[];
  details: FlavorDetails;
}

export interface ContinentDetails {
  keyRegions: string[];
}

export interface ContinentEntry extends BaseEntry {
  category: 'CONTINENTS';
  details: ContinentDetails;
}

export interface CountryGateDetails {
  origin: string;
  classification?: 'COUNTRY' | 'STATE';
  keyRegions?: string[];
  notableGrapes?: string[];
  appellations?: string[];
}

export interface CountryGateEntry extends BaseEntry {
  category: 'COUNTRY_GATE';
  details: CountryGateDetails;
}

export type WineEntry =
  | GrapeEntry
  | RegionEntry
  | StyleEntry
  | FlavorEntry
  | ContinentEntry
  | CountryGateEntry;

// === Type guards ===

export const isGrapeEntry = (e: WineEntry): e is GrapeEntry => e.category === 'GRAPES';
export const isRegionEntry = (e: WineEntry): e is RegionEntry => e.category === 'REGIONS';
export const isStyleEntry = (e: WineEntry): e is StyleEntry => e.category === 'STYLES';
export const isFlavorEntry = (e: WineEntry): e is FlavorEntry => e.category === 'FLAVORS';
export const isContinentEntry = (e: WineEntry): e is ContinentEntry => e.category === 'CONTINENTS';
export const isCountryGateEntry = (e: WineEntry): e is CountryGateEntry => e.category === 'COUNTRY_GATE';

// Raw legacy grape source — not part of the WineEntry union.
// Consumed by grapeCards.ts and constants.ts to derive the canonical GrapeEntry shape.
export interface LegacyGrapeRecord {
  id: string;
  name: string;
  description: string;
  category: 'GRAPES';
  rarity?: RarityLabel;
  color: string;
  icon: string;
  wineType: string;
  tastingProfile: TastingNote[];
  tags: string[];
  details: {
    origin: string;
    body: string;
    acidity?: string;
    tannin?: string;
    keyRegions?: string[];
    synonyms?: string[];
    classification?: string;
  };
}

export interface Pairing {
  code: string;
  name: string;
  category: string;
  compatibility: string;
  intensity: string;
  reasoning: string;
  color: string;
  servingTemp: string;
  examples: string[];
}
