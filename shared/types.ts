
export type EntryCategory = 'GRAPES' | 'REGIONS' | 'STYLES' | 'FLAVORS' | 'MASTER_SEARCH' | 'WORLD_SEARCH' | 'COUNTRY_GATE' | 'CONTINENTS' | 'RETRO_GLOBE';

export type DataCategory = 'GRAPES' | 'REGIONS' | 'STYLES' | 'FLAVORS' | 'CONTINENTS' | 'COUNTRY_GATE';

export type RarityTier = 'common' | 'uncommon' | 'rare' | 'epic' | 'noble' | 'godforsaken';

export type RarityLabel = 'COMMON' | 'UNCOMMON' | 'RARE' | 'NOBLE' | 'GODFORSAKEN';

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
  /**
   * Authored genetics, carried through from `LegacyGrapeRecord` (0.7.5, E).
   *
   * **Top level, not inside `details`, and that is the whole reason this line
   * exists.** The iOS generator's `STRIP_ENTRY_FIELDS` drops `grapeCard` on the
   * way out, so anything reached only through the card never lands in
   * `entries.json`; `details` is built field by field in `constants.ts` rather
   * than spread, so a field nobody names there is dropped just as silently.
   * This sits beside the other `grape*` projections, which is the shape that
   * already travels.
   *
   * Optional because 40% of the catalog has a relationship and 60% does not —
   * see `GrapeLineage`, and `GrapeLineageIndex` on the Swift side for what the
   * missing 60% is shown instead of an empty tree.
   */
  lineage?: GrapeLineage;
}

export interface RegionDetails {
  origin: string;
  state?: string;
  notableGrapes: string[];
  classification: string;
  appellations?: string[];
  soilType?: string;
  synonyms?: string[];
  /// Where this region actually sits on its outline art (0.6.x), as fractions
  /// of the PNG canvas — x from the left, y from the top. The art in question
  /// is the one the region's icon resolves to (state outline first for US
  /// regions, country otherwise). Approximate: renderers snap the point to
  /// the nearest land pixel. Omit it and placement falls back to the seeded
  /// hash walk, which guarantees land but knows no geography.
  mapPosition?: { x: number; y: number };
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

/**
 * One end of a lineage edge (0.7.5 E, sommbot).
 *
 * `id` when the other variety is a catalog entry, `name` when it is not —
 * exactly one of the two, never both.
 *
 * **In-catalog links are by id, not by name, and that is deliberate.** Every
 * other cross-reference in this file resolves through the app's name normaliser,
 * and the grape-name index is precisely where that breaks: "Espadeiro" answers
 * to five VIVC prime names, "Nerello" to seven, "Colorino" to three. A pedigree
 * graph resolved by name would quietly wire a Galician vine to a Portuguese one.
 * Ids are also stable by house rule — renames touch `name` only.
 *
 * Off-catalog ancestors are *named* rather than dropped. Gouais Blanc is the
 * mother of a third of France's varieties and will never be a collectible
 * entry; refusing to name it would throw away most of the tree. A renderer
 * draws these as flat, untappable nodes; `data-review/CANDIDATES.md` is where
 * one goes if it earns a slot of its own.
 */
export interface LineageRef {
  /** Catalog grape id, e.g. `"G008"`. Mutually exclusive with `name`. */
  id?: string;
  /** Display name of a variety the catalog does not carry. */
  name?: string;
  /** Seed vs pollen parent, set only where the cross direction is established. */
  role?: 'mother' | 'father';
  /** The relationship is real, but its direction or the identity is disputed. */
  contested?: boolean;
}

/**
 * A grape's marker-confirmed relatives (0.7.5 E, sommbot).
 *
 * **Only the child-facing direction is stored.** `offspring`, `mutations` and
 * `siblings` are all derived by one reverse pass over the grape list — offspring
 * of X is every grape whose `parents` contains X; half-siblings are the grapes
 * that share a parent key (`id ?? normalised name`, which is why off-catalog
 * ancestors must be spelled the same way everywhere). Storing both directions
 * would mean two places to be wrong and a list that silently rots every time a
 * grape is added; deriving costs one pass over 171 records at load.
 *
 * Nothing goes in here that is not marker-confirmed. Where markers establish the
 * relationship but not its *direction*, the ref carries `contested` and `note`
 * explains it, rather than the entry asserting or omitting it.
 */
export interface GrapeLineage {
  /** At most two. An unidentified second parent is absent, never a placeholder. */
  parents?: LineageRef[];
  /** A somatic mutation of that variety — same genotype, different skin. */
  mutationOf?: LineageRef;
  /**
   * A first-degree relative whose direction is unresolved, or a confirmed
   * half-sibling whose shared parent the catalog cannot name.
   */
  related?: LineageRef[];
  /** One sentence for the tree's footnote wherever the above is contested. */
  note?: string;
  /**
   * Research was done and no parent pair is established (0.8.2, sommbot).
   *
   * **This is an authored claim, not the absence of one.** The overwhelming
   * majority of the catalog carries no `lineage` at all, and that silence means
   * only "nobody has written this one down yet". `parentageUnknown` means
   * something stronger and rarer: the question was *asked* of a source that
   * would know — a VIVC passport whose pedigree field is empty, or a study that
   * looked for the parents and reported none — and the answer is that the
   * parentage is genuinely unestablished. Assyrtiko is not Nebbiolo-with-a-gap;
   * it is a variety whose parents nobody has found.
   *
   * The two states render differently and must never be collapsed:
   * `GrapeLineageIndex` turns this flag into `LineageNode.Target.unrecorded`,
   * a drawn tile reading "Parentage unrecorded", where an unauthored grape gets
   * no tree at all. `GrapeLineageTests.unknownParentageIsDistinctFromUnauthored`
   * exists to keep them apart, so do not set this as a way of saying "I could
   * not find it" — that verdict is spelled by leaving `lineage` off entirely.
   *
   * Legal beside `parents`: a grape can have one established parent and a
   * second that is genuinely unrecorded, which is what draws a named tile and
   * an unrecorded one side by side (`GrapeLineageScreen` adds the tile when
   * `parentageUnknown` and fewer than two ancestors are authored).
   *
   * Not counted as an edge: `GrapeLineage.isEmpty` and `GrapeRelatives.isEmpty`
   * both ignore it, because an annotation about absent knowledge is not a
   * relationship. That is what routes the two cases to different UI — a grape
   * with no edges draws the flat PARENTAGE UNRECORDED statement on the entry
   * screen, while a grape that has edges (even only derived ones, like an
   * offspring list) still opens the tree and carries the unrecorded tile
   * inside it.
   */
  parentageUnknown?: boolean;
}

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
  /**
   * Authored genetics. Absent on most entries — a sparse correct tree beats a
   * dense speculative one, and 0.7.5 E ships only what markers confirm.
   *
   * Not yet carried onto `GrapeEntry`: `constants.ts` builds that shape field by
   * field rather than spreading, so a pass-through there (and a `lineage` on
   * `GrapeEntry`, and `WineEntry.swift`) is what makes this reach the app.
   * `STRIP_ENTRY_FIELDS` in the iOS generator is a blacklist, so nothing needs
   * to change there.
   */
  lineage?: GrapeLineage;

  /**
   * Authored stat-bar values, overriding the text derivation (0.9.x).
   *
   * `grapeCards.ts` derives all five bars from prose. Two of them never
   * carried any information: `colorIntensity` was `type === 'red' ? 4 : 2`
   * with zero exceptions, so three teinturiers read like Pinot Noir, and
   * `aromatics` was `min(notes, 3) + 2`, which scored 5 on 174 of 177 grapes
   * and really measured whether three tasting notes had been authored.
   *
   * Both are now authored per variety, which is why this is a field rather
   * than a better formula: a second derivation would be a subtler version of
   * the same defect.
   *
   * `Partial` on purpose. Anything absent falls back to the text derivation,
   * so the three prose-backed bars keep working untouched and can be moved
   * over later, one at a time, without a flag day. **The merge in
   * `grapeCards.ts` uses `??`, not `||`** - 0 is a legal authored value and
   * `||` would silently discard it.
   */
  characteristics?: Partial<GrapeCharacteristics>;
}

/**
 * One shipped release, as the device itself describes it (iOS 0.7.3, F3).
 *
 * This is the *user-facing* changelog — what the FIRMWARE HISTORY panel prints
 * and what the boot POST reads its version number off. It is deliberately not
 * the engineering record: `AppVersion.swift` still carries the long "why does
 * this build have this number" notes, because those answer a question no player
 * asks. Anything here is written to be read on a 320pt LCD in a fixed-width
 * font.
 *
 * ASCII only, and `headline` uppercase and short: the panel's headings are set
 * in Press Start 2P, which has a partial Latin-1 range, and a missing glyph is
 * a worse outcome than a missing accent. The generator gates all of that.
 */
export interface FirmwareRelease {
  /** Three dot-separated integers — the scheme since iOS 0.4.3. */
  version: string;
  /** ISO `YYYY-MM-DD`, the day the batch landed. */
  date: string;
  /** ASCII, uppercase, <= 24 characters. The panel's per-release heading. */
  headline: string;
  /** One line each, in the order they should be read. ASCII, sentence case. */
  notes: string[];
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
