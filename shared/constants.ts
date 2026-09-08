import type {
  EntryCategory,
  FlavorEntry,
  GrapeBodyClass,
  GrapeEntry,
  RarityLabel,
  TastingNote,
  TastingNoteIcon,
  WineEntry,
} from './types.ts';
import { GRAPES as LEGACY_GRAPES } from './data/grapes.ts';
import { REGIONS } from './data/regions.ts';
import { STYLES } from './data/styles.ts';
import { GRAPE_CARDS } from './data/grapeCards.ts';
import { CONTINENTS } from './data/continents.ts';
import { COUNTRIES } from './data/countries.ts';
import {
  FLAVOR_CLASS_COLORS,
  categorizeFlavor,
  categorizeFlavorSubclass,
  type FlavorClass,
} from './services/entryUtils.ts';

// Re-export individual collections
export { GRAPES as GRAPES_LEGACY } from './data/grapes.ts';
export { REGIONS } from './data/regions.ts';
export { STYLES } from './data/styles.ts';
export { GRAPE_CARDS } from './data/grapeCards.ts';
export { CONTINENTS } from './data/continents.ts';
export { COUNTRIES } from './data/countries.ts';
// Not a wine collection, but the same rule applies: anything the apps read as
// data is reachable from here (iOS 0.7.3, F3).
export { FIRMWARE_RELEASES, FIRMWARE_VERSION } from './data/firmware.ts';

const canonicalizeGrapeName = (value: string) =>
  /^syrah\s*\/\s*shiraz$/i.test(value.trim()) ? 'Syrah' : value;

const normalizeText = (value?: string) => (value || '').trim().toLowerCase();

const getGrapeBodyClass = (...values: Array<string | undefined>): GrapeBodyClass => {
  for (const value of values) {
    const text = normalizeText(value)
      .replace(/-bodied/g, '')
      .replace(/body/g, '')
      .replace(/red|white|rose|ros\u00e9|orange|sparkling|aromatic|sweet/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    if (!text) continue;
    if (text.includes('medium full') || text.includes('full medium')) return 'Medium-Full';
    if (text.includes('light medium') || text.includes('medium light')) return 'Light-Medium';
    if (text.includes('full')) return 'Full';
    if (text.includes('medium')) return 'Medium';
    if (text.includes('light')) return 'Light';
  }

  return 'Medium';
};

interface LegacyGrapeMeta {
  color: string;
  icon?: string;
  tastingProfile?: TastingNote[];
  wineType?: string;
}

const legacyColorMap: Record<string, LegacyGrapeMeta> =
  LEGACY_GRAPES.reduce((acc, g) => {
    acc[g.id] = { color: g.color, icon: g.icon, tastingProfile: g.tastingProfile, wineType: g.wineType };
    return acc;
  }, {} as Record<string, LegacyGrapeMeta>);

const GRAPE_ENTRIES: GrapeEntry[] = GRAPE_CARDS.map((card) => {
  const legacy = legacyColorMap[card.id];
  // The whole legacy record, hoisted (0.7.5, E). `bodyClass` below already did
  // this find inline and `lineage` needs the same record, so the second reader
  // is the one that makes it worth naming rather than scanning 171 records
  // twice per card.
  const record = LEGACY_GRAPES.find((grape) => grape.id === card.id);
  // The authored pedigree (0.7.5, E). `GRAPE_CARDS` does not carry it -- a card
  // is the stat-bar projection -- so it comes off the legacy record. Passed
  // through by name because this object is built field by field; see
  // `GrapeEntry.lineage` for why it is top level rather than in `details`.
  const lineage = record?.lineage;
  const bodyClass = getGrapeBodyClass(legacy?.wineType, card.style, record?.details.body);
  const rarityMap: Record<string, RarityLabel> = {
    common: 'COMMON',
    uncommon: 'UNCOMMON',
    rare: 'RARE',
    epic: 'RARE',
    noble: 'NOBLE',
    godforsaken: 'GODFORSAKEN',
  };
  return {
    id: card.id,
    name: canonicalizeGrapeName(card.name),
    description: card.info,
    category: 'GRAPES',
    tags: card.tastingProfile,
    color: legacy?.color || '#722F37',
    icon: legacy?.icon || 'grape',
    wineType: card.style,
    grapeType: card.type,
    grapeStyle: card.style,
    grapeBodyClass: bodyClass,
    grapeCharacteristics: card.characteristics,
    grapeAlternateNames: card.alternateNames.map(canonicalizeGrapeName),
    grapeNotableRegions: card.notableRegions,
    grapeCountryOfOrigin: card.countryOfOrigin,
    grapeRarityTier: card.rarityTier,
    tastingProfile: legacy?.tastingProfile,
    grapeCard: card,
    rarity: rarityMap[card.rarityTier] || 'UNCOMMON',
    // Omitted entirely when absent rather than written as `undefined`: the
    // generator's JSON pass would drop it either way, but `vinodex-web`
    // typechecks this under `exactOptionalPropertyTypes`-adjacent strictness and
    // an explicit `undefined` reads as "authored blank" rather than "no data".
    ...(lineage ? { lineage } : {}),
    details: {
      origin: card.countryOfOrigin,
      synonyms: card.alternateNames.map(canonicalizeGrapeName),
      keyRegions: card.notableRegions,
      body: bodyClass,
    }
  };
});

const TASTING_NOTE_ICON_KEYS: TastingNoteIcon[] = [
  'circle',
  'triangle',
  'leaf',
  'cloud',
  'sun',
  'mountain',
  'sparkles',
  'flame',
  'droplet',
  'shield',
  'flower',
  'fruit',
  'herb',
  'spice',
  'mineral',
  'oak',
  'smoke',
  'stone',
  'tropical',
  'flag',
  'honey',
  'nut',
  'default',
];

const sanitizeTastingNoteIcon = (icon?: string): TastingNoteIcon =>
  icon && TASTING_NOTE_ICON_KEYS.includes(icon as TastingNoteIcon)
    ? (icon as TastingNoteIcon)
    : 'default';

/// One authored blurb per flavour, keyed by the note's name (0.9.53, sommbot).
///
/// The fourth pass at this copy, and the first that is written rather than
/// assembled. G1 (0.5.7) stopped the blurbs describing the *database*
/// ("carried here by Barbera…"); E1 (0.8.94) stopped them describing the
/// *drinking*. Both left a template underneath: every entry was "<note> is a
/// <kind> note in the <class> family" plus one line about the class — 106
/// sentences with the nouns swapped. These are 106 authored entries in the
/// encyclopedic register: what the flavour is, how it arises in wine, and one
/// catalog grape that carries it, always drawn from that flavour's own
/// notableGrapes. The table is validated against the derived flavour set in
/// `buildFlavorEntries` — the bargain GRAPE_CLUSTERS strikes with the grape
/// catalog — so a note without a row, or a row without a note, fails the
/// generate run loudly instead of shipping a fallback sentence.
///
/// Entry INFO reads these aloud via speech synthesis, so the sentences are
/// written to be spoken: no parentheticals, no slashes, no dash asides.
const FLAVOR_DESCRIPTIONS: Record<string, string> = {
  'Blackcurrant': "Blackcurrant, also called cassis, is the small tart black berry of the currant bush, darker and more pungent than blackberry. In wine it is a varietal marker of ripe Cabernet Sauvignon, where it forms the core of the fruit above the grape's firm tannin.",
  'Cedar': "Cedar is the dry, sweetly resinous scent of cedarwood, familiar from pencil boxes and cigar humidors. It develops where a structured red ages in oak barrels and deepens with time in bottle, and it is a classic companion to Cabernet Sauvignon's blackcurrant fruit.",
  'Spice': "Spice is a broad sweet-spice impression, cinnamon, clove and pepper blurred together rather than any one jar. It can come from the grape itself or from the toasted inside of an oak barrel, and it threads through reds as different as Ruché and Nero d'Avola.",
  'Cherry': "Cherry is the bright note of fresh sweet cherries, the signature fruit of many mid-weight reds. It is produced by the grape rather than the barrel, and Pinot Noir and Sangiovese both build their profiles around it.",
  'Earth': "Earth is the smell of turned soil or a forest floor after rain. It emerges as a red wine matures and its fresh fruit recedes into savoury territory, and it is prized in aged Pinot Noir as well as in rustic reds like Baga and Carignan.",
  'Floral': "Floral is a general flower-garden lift rather than any one identifiable bloom. It comes from aromatic compounds in the skins of delicate, thin-skinned varieties, and it gives Pinot Noir its perfumed top note.",
  'Red Apple': "Red apple is the mellow, faintly sweet scent of a ripe dessert apple. It marks white grapes picked at full ripeness in moderate climates, once sharper green-apple acidity has softened, and it is typical of unoaked Chardonnay.",
  'Butter': "Butter is the rich, creamy scent of melted butter. It comes from diacetyl, a compound produced during malolactic fermentation when a wine's sharp malic acid is converted to softer lactic acid, and it is a hallmark of barrel-aged Chardonnay.",
  'Vanilla': "Vanilla is the sweet baking scent of vanilla pod. In wine it comes almost entirely from vanillin in oak barrels, with new oak giving the strongest dose, and oaked Chardonnay wears it most openly.",
  'Plum': "Plum is the fleshy dark fruit note of ripe plums, rounder and softer than blackberry. It signals full ripeness in warmer-climate reds, and it is the core fruit of Merlot and Malbec.",
  'Chocolate': "Chocolate is a sweet, rounded cocoa richness in the finish of a red wine. It develops where very ripe dark fruit meets toasty oak, and plush styles of Merlot show it clearly.",
  'Herbs': "Herbs is the mixed green scent of a kitchen herb bundle, thyme, bay and their kin. It comes from aromatic compounds that grapes share with herb plants, often amplified by cooler sites, and it seasons Mediterranean whites like Vermentino.",
  'Blackberry': "Blackberry is the deep, sweet-tart note of ripe bramble fruit. It is the leading fruit of thick-skinned dark grapes grown in warmth, and Syrah and Tannat both open with it.",
  'Pepper': "Pepper is the pungent bite of freshly cracked peppercorns. It is caused by rotundone, a compound in grape skins that rises in cooler seasons, and it is the defining spice of cool-climate Syrah.",
  'Smoke': "Smoke is the char and woodsmoke edge some reds carry. It can come from heavily toasted barrels or read as part of the grape's own character, and Pinotage and Aglianico are both known for it.",
  'Lime': "Lime is the sharp, zesty citrus note at the acid end of the white wine spectrum. It marks high-acid grapes from cool climates, where citrus flavors stay green rather than turning golden, and dry Riesling is its clearest carrier.",
  'Gooseberry': "Gooseberry is the tart, faintly musky green berry long used to describe Sauvignon Blanc. The note comes from thiols released during fermentation, and New Zealand styles of the grape show it at full volume.",
  'Grass': "Grass is the fresh green smell of a just-mown lawn. It comes from green-leaf compounds, including methoxypyrazines, that are highest in grapes from cool sites picked early, and it is a varietal signature of Sauvignon Blanc.",
  'Peach': "Peach is the juicy stone fruit note of ripe yellow peaches. It appears in whites from moderately warm sites, sitting between citrus and tropical fruit on the ripeness ladder, and ripe Riesling and Marsanne both reach it.",
  'Petrol': "Petrol is the kerosene-like scent that aged Riesling famously develops. It comes from TDN, a compound formed slowly in bottle from precursors in the grape, faster with sun-exposed fruit, and a measured dose is considered a mark of maturity rather than a fault.",
  'Rose': "Rose is the unmistakable perfume of fresh roses. It is driven by terpenes in aromatic grape skins, and it crowns Nebbiolo and Gewürztraminer alike.",
  'Tar': "Tar is the dark, resinous scent of warm asphalt. It is one half of Nebbiolo's traditional pairing of tar and roses, emerging alongside firm tannin as Barolo-style wines age.",
  'Tomato': "Tomato is the savoury, faintly sweet scent of ripe or stewed tomatoes. It belongs to the umami side of red wine, where fruit shades into sauce-like savouriness, and mature Sangiovese is its best-known home.",
  'Espresso': "Espresso is the dark roasted coffee note in the bass register of a red wine. It comes from heavily toasted oak barrels working on ripe dark fruit, and oak-aged Sangiovese often finishes on it.",
  'Strawberry': "Strawberry is the light, sweet note of ripe strawberries. It typifies pale, delicate reds and rosés from thin-skinned grapes, and Grenache and Cinsault both lead with it.",
  'Raspberry': "Raspberry is the perfumed, sweet-tart note of fresh raspberries, sitting between strawberry and cherry in the red fruit spectrum. It comes from the grape's own aroma compounds rather than from winemaking, and it is a core marker of Cabernet Franc and Grenache.",
  'Fig': "Fig is the dense, honeyed note of fresh ripe figs. It appears in reds from hot climates where the fruit verges on raisining, and warm-region Tempranillo can show it.",
  'Tobacco': "Tobacco is the sweet leafy scent of a cigar box or cured pipe leaf. It develops as tannic reds age in barrel and bottle, their fruit drying toward leaf and spice, and mature Rioja-style Tempranillo is a textbook example.",
  'Dill': "Dill is the distinct pickle-herb scent of dill fronds. In wine it is a fingerprint of American oak barrels, and traditional Rioja raised Tempranillo in exactly those, which is why the grape and the herb are linked.",
  'Blueberry': "Blueberry is the plush, sweet dark berry note of ripe blueberries. It marks deeply colored reds picked very ripe under strong sun, and high-altitude Argentine styles of Malbec are famous for it.",
  'Cocoa': "Cocoa is the dry, dusty cocoa-powder note that coats a red wine's tannin. It arises where ripe tannin meets toasted oak and reads drier than chocolate, and Carmenère and Malbec both show it.",
  'Bell Pepper': "Bell pepper is the green capsicum scent found in some reds. It comes from methoxypyrazines, compounds that sunlight degrades as grapes ripen, so shaded or early-picked fruit keeps more of them. Cabernet Franc carries a trace even at ripeness, where it reads as varietal character rather than a flaw.",
  'Graphite': "Graphite is the cool scent of pencil lead, a mineral edge in structured reds. Tasters associate it with tannic wines grown on stony soils rather than with any single compound, and Cabernet Franc and Mencía are frequent carriers.",
  'Quince': "Quince is the tart, perfumed orchard fruit note of quince paste, denser than apple or pear. It marks high-acid whites picked ripe, and it is a signature of Chenin Blanc, sharp in youth and honeyed with age.",
  'Honey': "Honey is the sweet floral richness of liquid honey. It develops in white wines through bottle age, late picking or noble rot, and mature Chenin Blanc and Tokaji-style Furmint are steeped in it.",
  'Chamomile': "Chamomile is the gentle, apple-tinged scent of chamomile flowers, a dried flower note rather than a fresh one. It suits subtle, quietly aromatic whites, and Savatiano and Chenin Blanc both carry it.",
  'Tangerine': "Tangerine is the sweet, fragrant citrus of mandarin peel, softer than orange. It shows in aromatic whites picked ripe, when citrus turns from sharp to juicy, and Viognier wears it alongside its stone fruit.",
  'Honeysuckle': "Honeysuckle is the heady nectar scent of honeysuckle blossom. It comes from terpenes in aromatic white grapes, and it is one of Viognier's defining perfumes.",
  'Mango': "Mango is the lush tropical note of fully ripe mango flesh. It appears when white grapes ripen well past the citrus stage in warm sites, and late-picked Viognier and Petit Manseng both reach it.",
  'Pomegranate': "Pomegranate is the tangy, lightly bitter red fruit note of pomegranate seeds. It suits pale, high-acid reds whose fruit stays crunchy rather than jammy, and Gamay and Areni both show it well.",
  'Banana': "Banana is the candied banana scent of isoamyl acetate, an ester created by fermentation. It is strongest in wines made by carbonic maceration, and Beaujolais-style Gamay made the note famous.",
  'Jammy Berry': "Jammy berry is cooked, sugared berry fruit rather than fresh, berries reduced to preserves. It comes from very ripe, sun-soaked grapes that arrive at harvest with low acidity, and warm-climate Zinfandel is its archetype.",
  'Cinnamon': "Cinnamon is the warm bark spice of ground cinnamon. In wine it usually comes from oak aging layered over ripe red fruit, and spiced reds like Zinfandel and Primitivo show it plainly.",
  'Lemon Curd': "Lemon curd is citrus made rich, lemon folded into butter and sugar. The note appears when a high-acid white gains breadth from lees contact or bottle maturity, and aged Semillon is its classic home.",
  'Beeswax': "Beeswax is the soft, waxy polish note of candle wax or honeycomb, sweetness of scent without sugar. It develops in quietly aromatic whites as they age, and Semillon and Grenache Blanc both take on this texture-like perfume.",
  'Lanolin': "Lanolin is the soft scent of wool grease, clean fleece rather than farmyard. It is the traditional descriptor for dry Semillon, whose neutral youth turns waxy and lanolin-scented on its way to honeyed maturity.",
  'Black Fruit': "Black fruit is a composite of dark berries and plums, fruit read as a mass rather than as any single berry. It signals thick-skinned grapes at full ripeness, and Mourvèdre and Touriga Nacional both build their cores from it.",
  'Game': "Game is the savoury, meaty scent of hung game or cured meat. It develops in structured reds with age, and Mourvèdre is the catalog's most gamey grape, showing the note even in relative youth.",
  'Sour Cherry': "Sour cherry is the tart note of morello cherries, brighter and sharper than sweet cherry. It marks high-acid reds in the Italian mould, and Barbera and Xinomavro are both built on it.",
  'Licorice': "Licorice is the dark anise-root sweetness of black licorice. It arrives with very ripe dark fruit in southern Italian and Iberian reds, and Primitivo and Negroamaro both carry it.",
  'Lemon': "Lemon is the fresh citrus note at the heart of most crisp white wines. It reflects the high natural acidity of grapes from cool to moderate sites, and Assyrtiko and Fiano both center on it.",
  'Mineral': "Mineral is a catch-all for stony, non-fruit freshness, closer to wet rock than to any fruit or flower. Tasters link it to high acidity and restrained aromatics rather than to literal minerals drawn from the soil, and Assyrtiko from volcanic Santorini is a benchmark.",
  'Violet': "Violet is the dark floral perfume of violet petals, sweeter and deeper than rose. It comes from ionone compounds in certain black grape skins, and it lifts the aromatics of Petit Verdot and Touriga Nacional.",
  'Lilac': "Lilac is the light spring blossom scent of lilac flowers, airier than violet. It is a subtle skin-derived floral note, and Petit Verdot can show it above its dense dark fruit.",
  'Sage': "Sage is the dusty, savoury herb note of dried sage leaves. It belongs to the garrigue family of scrubland herbs that mark wines from dry, sunny hillsides, and Petit Verdot and Nascetta both carry it.",
  'Green Pepper': "Green pepper is the fresh capsicum bite of an unripe pepper, sharper than the rounded bell pepper note. It comes from methoxypyrazines that persist when fruit stops short of full ripeness, and Carmenère keeps a streak of it even in warm climates.",
  'Lychee': "Lychee is the perfumed, rosewater-tinged tropical note of lychee fruit. It comes from rose oxide, the same compound behind Gewürztraminer's rose scent, and that grape is the note's defining carrier.",
  'Lemon Zest': "Lemon zest is the oily, aromatic side of lemon peel rather than its juice. It shows in brisk coastal and hillside whites, and Picpoul and Verdicchio both finish on its bitter-fresh snap.",
  'Orange Blossom': "Orange blossom is the sweet neroli perfume of citrus flowers. It comes from terpenes concentrated in the Muscat family and its relatives, and Moscato carries the note in its purest form.",
  'Pear': "Pear is the soft orchard fruit note of ripe pears, gentler and rounder than apple. It typifies mild-mannered whites fermented cool in stainless steel, and Glera brings it to every glass of Prosecco-style sparkling wine.",
  'Ginger': "Ginger is the warm, faintly hot spice of fresh ginger root. It appears in aromatic whites that carry a phenolic edge, and Gewürztraminer's own name points to this spiced register.",
  'Apricot': "Apricot is the dense, honeyed stone fruit note of ripe apricots. It marks aromatic whites picked late or concentrated by noble rot, and Albariño and Vidal both reach it in ripe years.",
  'Sea Salt': "Sea salt is a clean saline impression on the finish, tasted as much as smelled. It shows in whites grown within reach of the ocean, and coastal Albariño and Sherry-country Palomino both close on it.",
  'Grapefruit': "Grapefruit is the bittersweet citrus note of fresh grapefruit flesh and pith. It is driven by thiols released from aromatic white grapes during fermentation, and Albariño and Verdejo both pour it freely.",
  'Green Pea': "Green pea is the sweet vegetal scent of freshly podded peas. It is a gentle green note in the methoxypyrazine family, found in cool-climate whites, and young Grüner Veltliner sometimes shows it beside its pepper.",
  'White Pepper': "White pepper is the sharper, earthier cousin of black pepper spice. Like black pepper it traces to rotundone in the grape skins, and it is the signature bite of Grüner Veltliner and cool-site Blaufränkisch.",
  'Almond': "Almond is the clean bitter-almond note in the finish of many Italian-style whites. It comes from the grape and from time on fine lees rather than from oak, and Vermentino and Verdicchio traditionally close on it.",
  'Fennel': "Fennel is the fresh anise-and-green scent of fennel bulb and fronds. It gives Mediterranean whites a savoury herbal lift, and Clairette and Xarel·lo both carry it.",
  'Herbal Tea': "Herbal tea is the dried infusion scent of tisanes, chamomile, verbena and their kin steeped rather than fresh. It appears in skin-contact and gently oxidative whites, and Rkatsiteli made in the Georgian amber style is full of it.",
  'Marzipan': "Marzipan is sweet almond paste, richer and more sugared than the plain almond note. It develops in full-bodied whites given time on the lees, and Marsanne is its classic carrier.",
  'Green Apple': "Green apple is the crisp, tart orchard note of an unripe apple, malic acid made fruit. It marks whites from cool sites or early picking, and Pinot Blanc and Aligoté both open on it.",
  'Hazelnut': "Hazelnut is the toasted nut note that white wines earn from lees aging, old oak or gentle oxidation. It is prized in mature Savagnin from the Jura and in Fiano, where it deepens the mid-palate.",
  'Saline': "Saline is a briny freshness that makes a wine taste faintly of the sea itself. It clings to whites from island and seaside vineyards where salt air reaches the vines, and Assyrtiko and Picpoul are leading examples.",
  'Leather': "Leather is the scent of worked hide, saddle rather than shoe polish. It develops in tannic reds as they age and their fruit turns savoury, and mature Aglianico and Tannat both show it richly.",
  'Black Cherry': "Black cherry is the deep, sweet note of dark cherries, riper and denser than red cherry. It marks warm-climate reds of real color and concentration, and Nero d'Avola and Plavac Mali both carry it at the core.",
  'Herb': "Herb is a single clean green accent rather than a full herbal bouquet. It reflects aromatic skin compounds kept fresh by moderate ripeness, and Touriga Nacional threads it through its dark fruit.",
  'Black Plum': "Black plum is the dark-skinned plum note, deeper and less sweet than red plum. It is the mark of inky, thick-skinned grapes, and Saperavi and Alicante Bouschet, both dyer grapes with colored flesh, are steeped in it.",
  'Green Peppercorn': "Green peppercorn is the fresh, brined bite of unripe peppercorns, greener and juicier than cracked black pepper. It sits between the capsicum and pepper-spice families of green notes, and Cabernet Gernischt is known for it.",
  'Tea Leaf': "Tea leaf is the dry, gently tannic scent of loose black tea. It appears in reds whose tannins read leafy rather than woody, and Cabernet Gernischt carries it as a varietal note.",
  'Yuzu Citrus': "Yuzu citrus is the fragrant Japanese citrus note, part grapefruit and part mandarin with a floral edge. It describes the delicate citrus register of Koshu, Japan's own white grape, whose gentle acidity keeps the note airy rather than sharp.",
  'Jasmine': "Jasmine is the sweet white-flower perfume of jasmine blossom, headier than orchard bloom. It comes from terpenes in aromatic white grapes, and Malagousia and Koshu both show it.",
  'Strawberry Candy': "Strawberry candy is the confected strawberry note of sweet-shop candies rather than fresh fruit. It comes from fermentation esters in soft, low-tannin reds, and Muscat Bailey A, the Japanese hybrid, is famous for it.",
  'Rose Petal': "Rose petal is a softer, drier take on rose, loose petals rather than full perfume. It marks pale, delicate reds and rosés, and Moschofilero and Cinsault both wear it lightly.",
  'Smoky Spice': "Smoky spice is spice with an ember behind it, clove and pepper laid over char. It comes from toasted barrels meeting naturally spicy dark fruit, and Saperavi takes it on in oak.",
  'White Flower': "White flower is the light blossom scent of small white flowers, acacia and orchard bloom in one impression. It marks unoaked aromatic whites picked for freshness, and Kisi and Ribolla Gialla both open with it.",
  'Dark Chocolate': "Dark chocolate is the bitter-edged cocoa note, deeper and less sweet than milk chocolate. It arises where dense ripe tannin meets dark-roast oak, and Pinotage and Petite Sirah both pour it thickly.",
  'Dried Herbs': "Dried herbs is the brittle scent of the herb jar, oregano and thyme past their fresh green stage. It marks reds from hot, dry Mediterranean climates, and Montepulciano and Carignan both finish on it.",
  'Red Cherry': "Red cherry is the crisp, mid-weight cherry note between sour cherry and black cherry. It defines elegant reds from limestone and volcanic slopes alike, and Nerello Mascalese and Agiorgitiko both center on it.",
  'Dried Fig': "Dried fig is the concentrated, raisined sweetness of figs dried in the sun. It comes from late-picked or deliberately dried grapes, and Pedro Ximénez, the Sherry grape traditionally sun-dried on mats, is its purest expression.",
  'Brioche': "Brioche is the warm scent of buttery yeast bread. It comes from autolysis, yeast cells slowly breaking down during long lees aging in traditional-method sparkling wine, and Pinot Meunier and Xarel·lo both meet it in Champagne and Cava styles.",
  'Black Pepper': "Black pepper is the direct spice of cracked black peppercorns, warmer and darker than white pepper. It traces to rotundone in the grape skins, and Petite Sirah and Mondeuse both grind it over their dark fruit.",
  'Alpine Herbs': "Alpine herbs is the cool scent of mountain meadow plants, gentian and wild thyme in thin air. It marks high-altitude wines with bright acidity, and Savoie's Jacquère and the alpine red Teroldego both carry it.",
  'Chalk': "Chalk is the dry, dusty scent of chalk or limestone dust. It describes taut, low-fruit whites from calcareous soils, and Aligoté and Chasselas both leave it on the finish.",
  'Sea Spray': "Sea spray is the fresh iodine-and-salt scent of breaking waves, airier than salt on the palate. It marks whites grown within reach of ocean weather, and Melon de Bourgogne from the Atlantic end of the Loire is a classic carrier.",
  'Tomato Leaf': "Tomato leaf is the sharp green scent of tomato vines, more herbal and pungent than the fruit itself. It is a savoury vegetal marker of high-acid reds, and Xinomavro is the catalog's defining example.",
  'Olive': "Olive is the briny, savoury note of black or green olives. It appears in structured reds where fruit shades into umami, and Xinomavro, often compared with Nebbiolo, carries it from a young age.",
  'Clove': "Clove is the warm, faintly numbing spice of whole cloves. It comes largely from eugenol drawn out of toasted oak barrels, and oak-aged Agiorgitiko and Sagrantino both show it.",
  'White Peach': "White peach is the delicate cousin of yellow peach, sweeter scented and lower in acid. It suits gently aromatic whites picked for finesse, and Glera and Roditis both lead with it.",
  'Sea Breeze': "Sea breeze is a light marine freshness, salt air rather than salt taste. It lifts coastal Mediterranean whites, and Sicily's Grillo and Verdicchio from near the Adriatic both carry it.",
  'Nutmeg': "Nutmeg is the soft, woody baking spice of freshly grated nutmeg. In wine it is usually a gentle oak note, though in Müller-Thurgau a light nutmeg tone is part of the grape's own muscat-tinged aroma.",
  'White Blossom': "White blossom is the airy scent of orchard trees in flower, fainter and fresher than jasmine. It marks light, early-drinking whites, and Arneis and Garganega both open on it.",
  'Fresh Herbs': "Fresh herbs is the just-cut green scent of living herbs, brighter than the dried jar. It comes from grapes picked with their aromatics intact in cooler sites, and Silvaner and Mencía both show it.",
  'Stone': "Stone is the blunt scent of dry rocks in the sun, heavier than chalk and less saline than the sea notes. It describes austere, quietly aromatic wines from rocky sites, and Silvaner and Babić both carry it.",
  'Pineapple': "Pineapple is the bright tropical note of ripe pineapple flesh. It comes from fruity fermentation esters in fully ripe white grapes, and Verdelho and Vidal both reach it in warm years.",
  'Volcanic Ash': "Volcanic ash is a fine mineral smokiness, ash and warm stone rather than woodsmoke. Tasters find it in wines from volcanic slopes, and Etna's Nerello Mascalese and Carricante are its reference points.",
  'Blackberry Jam': "Blackberry jam is bramble fruit cooked down to preserves, sweeter and heavier than the fresh berry. It comes from very ripe grapes grown in hot climates, sometimes partly dried on the vine, and Primitivo is its natural home.",
};

/**
 * A flavour's id, derived from its own name rather than from its position.
 *
 * This is the fix for a defect that shipped from the beginning until 0.8.9.
 * The id read `FLAVOR-${idx + 1}` inside a `Map.forEach`, whose callback is
 * `(value, key, map)` — so `idx` was never an index. It was the lowercased
 * note, and every id went out as the note with a stray `1` welded on:
 * `FLAVOR-blackcurrant1`, 37 of the 106 carrying a space.
 *
 * The obvious repair — `FLAVOR-1` … `FLAVOR-106` — is the wrong one, and it
 * is worth writing down why. The other four categories *author* their ids
 * (`G001`, `R001`, `S001`) in their data files, so those ids never move.
 * Flavours have no data file: the set is derived from the union of every
 * grape's tasting notes, in grape-file order. A positional id over a derived
 * set renumbers whenever a note is added to an early grape or retired from
 * the set — so it would break saved entries on ordinary catalog growth, which
 * is a worse failure than the one being fixed. A slug moves only when the
 * note is renamed, which is a deliberate act.
 */
const flavorSlug = (note: string): string =>
  note.trim().toUpperCase().replace(/[^A-Z0-9]+/g, '-').replace(/^-+|-+$/g, '');

const buildFlavorEntries = (grapeEntries: GrapeEntry[]): FlavorEntry[] => {
  const flavorMap = new Map<string, { note: string; icon: string; color?: string; grapes: string[]; cls: FlavorClass; subclass: string }>();

  grapeEntries.forEach((entry) => {
    (entry.tastingProfile || []).forEach((flavor) => {
      const key = flavor.note.trim().toLowerCase();
      if (!key) return;
      const subclass = categorizeFlavorSubclass(flavor.note);
      const cls = categorizeFlavor(flavor.note, subclass);
      if (!flavorMap.has(key)) {
        flavorMap.set(key, { note: flavor.note, icon: flavor.icon || FLAVOR_CLASS_COLORS[cls].icon, color: flavor.color, grapes: [], cls, subclass });
      }
      flavorMap.get(key)!.grapes.push(entry.name);
    });
  });

  // Authored copy meets the derived set here, at build time. A tasting note
  // added to any grape needs a FLAVOR_DESCRIPTIONS row before it can ship,
  // and a row whose note has left the catalog is flagged as dead — the same
  // loud-drift contract the grape art tables enforce in generate-ios-data.
  const authoredProblems: string[] = [];
  const derivedNotes = new Set(Array.from(flavorMap.values(), (f) => f.note));
  for (const note of derivedNotes) {
    if (!FLAVOR_DESCRIPTIONS[note]) authoredProblems.push(`"${note}" has no authored description`);
  }
  for (const key of Object.keys(FLAVOR_DESCRIPTIONS)) {
    if (!derivedNotes.has(key)) authoredProblems.push(`"${key}" describes no note in the catalog`);
  }
  if (authoredProblems.length > 0) {
    throw new Error(`FLAVOR_DESCRIPTIONS disagrees with the derived flavour set: ${authoredProblems.join('; ')}`);
  }

  const flavorEntries: FlavorEntry[] = [];
  const flavorValues = Array.from(flavorMap.values());

  // Second argument named for what it is. It was called `idx` and read as one,
  // which is the whole of the id defect above.
  flavorMap.forEach((flavor, _noteKey) => {
    const clsColors = FLAVOR_CLASS_COLORS[flavor.cls];
    // Present by the validation above; the check narrows the indexed access
    // for the compiler and keeps the failure loud if the two ever part ways.
    const description = FLAVOR_DESCRIPTIONS[flavor.note];
    if (!description) {
      throw new Error(`"${flavor.note}" lost its authored description between validation and build`);
    }
    const subclass = flavor.subclass || categorizeFlavorSubclass(flavor.note);
    const related = flavorValues
      .filter(f => f.cls === flavor.cls && f.note.toLowerCase() !== flavor.note.toLowerCase())
      .slice(0, 3)
      .map((f) => ({
        note: f.note,
        icon: 'default' as const,
        color: clsColors.border,
      }));

    flavorEntries.push({
      id: `FLAVOR-${flavorSlug(flavor.note)}`,
      name: flavor.note,
      description,
      category: 'FLAVORS',
      tags: [flavor.cls, subclass],
      color: clsColors.color,
      icon: flavor.icon,
      tastingProfile: [
        { note: flavor.note, icon: sanitizeTastingNoteIcon(flavor.icon), color: flavor.color || clsColors.border },
        ...related,
      ],
      details: {
        classification: flavor.cls,
        subclass,
        notableGrapes: flavor.grapes.slice(0, 8),
      },
    });
  });

  return flavorEntries;
};

const CATEGORY_CALLBACKS: Partial<Record<EntryCategory, { icon: string; tile: string }>> = {
  GRAPES: { icon: 'grape', tile: 'grape' },
  REGIONS: { icon: 'region', tile: 'region' },
  STYLES: { icon: 'style', tile: 'style' },
  FLAVORS: { icon: 'flavor', tile: 'flavor' },
  CONTINENTS: { icon: 'globe', tile: 'globe' },
  COUNTRY_GATE: { icon: 'flag', tile: 'globe' },
};

function applyCategoryCallbacks<T extends WineEntry>(entry: T): T {
  const callbacks = CATEGORY_CALLBACKS[entry.category];
  if (!callbacks) return entry;
  return {
    ...entry,
    iconCallback: entry.iconCallback ?? callbacks.icon,
    tileCallback: entry.tileCallback ?? callbacks.tile,
  };
}

// Canonicalize an entry's grape-name fields without losing variant typing.
// Uses `'in'` checks because notableGrapes/synonyms exist on different variants.
function canonicalizeEntry<T extends WineEntry>(entry: T): T {
  const next = { ...entry, name: canonicalizeGrapeName(entry.name) };
  const details = next.details as { notableGrapes?: string[]; synonyms?: string[] };
  const updated: { notableGrapes?: string[]; synonyms?: string[] } = {};

  if ('notableGrapes' in next.details && details.notableGrapes) {
    updated.notableGrapes = details.notableGrapes.map(canonicalizeGrapeName);
  }
  if ('synonyms' in next.details && details.synonyms) {
    updated.synonyms = details.synonyms.map(canonicalizeGrapeName);
  }

  return {
    ...next,
    details: { ...next.details, ...updated },
  } as T;
}

/**
 * Optional narrowing applied when assembling the entry set. Used by the native
 * port's generator to emit a slim starter dataset; the web app passes nothing
 * and gets the full database.
 *
 * Selection is applied to the *source* collections, so FLAVORS are derived only
 * from the selected grapes rather than being filtered afterwards.
 */
export interface EntrySelection {
  grapes?: readonly string[];
  regions?: readonly string[];
  styles?: readonly string[];
  includeContinents?: boolean;
  includeCountries?: boolean;
}

const selectById = <T extends { id: string }>(all: readonly T[], ids?: readonly string[]): T[] =>
  ids ? all.filter((entry) => ids.includes(entry.id)) : [...all];

export function buildWineEntries(selection?: EntrySelection): WineEntry[] {
  const grapes = selectById(GRAPE_ENTRIES, selection?.grapes);
  const regions = selectById(REGIONS, selection?.regions);
  const styles = selectById(STYLES, selection?.styles);

  return [
    ...grapes,
    ...regions,
    ...styles,
    ...buildFlavorEntries(grapes),
    ...(selection?.includeContinents === false ? [] : CONTINENTS),
    ...(selection?.includeCountries === false ? [] : COUNTRIES),
  ].map((entry) => applyCategoryCallbacks(canonicalizeEntry(entry)));
}
