import type { ContinentEntry } from '../types.ts';

const CONTINENTS_BASE: ContinentEntry[] = [
  {
    id: "CONT_NORTH_AMERICA",
    name: "North America",
    description: "The birthplace of New World wine, North America combines Old World traditions with innovative winemaking. From California's sun-drenched valleys to Canada's cool-climate vineyards, the continent produces a diverse range of styles that have revolutionized global wine production.",
    category: "CONTINENTS",
    color: "#722F37",
    icon: "globe",
    tags: ["Continent"],
    details: {
      keyRegions: ["USA", "Canada", "Mexico"]
    }
  },
  {
    id: "CONT_EUROPE",
    name: "Europe",
    description: "The cradle of viticulture, Europe has shaped wine culture for millennia. From France's prestigious appellations to Italy's ancient vineyards, Europe's diverse climates and terroirs produce wines of unparalleled complexity and tradition.",
    category: "CONTINENTS",
    // Cobalt, not the #9B2335 claret it wore until iOS 0.8.0 (I).
    //
    // **The check the ask asked for, done first: red carries no other meaning on
    // the globe.** A continent's `color` is one value serving two things — the
    // marker plate on `RetroGlobeScreen` and the icon well behind the drawn globe
    // in `EntryVisual.continentVisual` — and nothing else on that screen reads
    // it. Selection is drawn as scale and stroke weight, locking is
    // `AccessStore`, and the six continents are simply six colours. So this is
    // one row in a table, exactly as the ask suspected.
    //
    // It also closes the complaint 0.7.1's A3 left open. That pass moved South
    // America off #73343A because it "sat one to five points per channel from
    // North America's #722F37", and signed off with "no two continents sit closer
    // than North America and Europe already did" — which named this pair as the
    // remaining offence and left it standing. Claret against dark claret at
    // marker size was two thirds of the Old World reading as one blob. Cobalt is
    // the furthest thing on the wheel from the five colours already in the set,
    // and it is the colour Europe wears in the one other place anybody has drawn
    // these six together: the Olympic rings, which is also what `vinodex-web`'s
    // `OLYMPIC_CONTINENT_COLORS` already uses for `CONT_EUROPE`.
    color: "#2B5FA5",
    icon: "globe",
    tags: ["Continent"],
    details: {
      keyRegions: ["France", "Italy", "Spain", "Germany", "Portugal", "Hungary", "Austria", "Greece", "Georgia", "Switzerland", "Romania", "Croatia", "United Kingdom", "Slovenia", "Bulgaria"]
    }
  },
  {
    id: "CONT_ASIA",
    name: "Asia",
    description: "An emerging wine frontier blending ancient traditions with modern innovation. From China's high-altitude vineyards to Japan's delicate whites, Asia's diverse landscapes are producing increasingly sophisticated wines that reflect both heritage and contemporary winemaking.",
    category: "CONTINENTS",
    color: "#C9A227",
    icon: "globe",
    tags: ["Continent"],
    details: {
      keyRegions: ["China", "Japan", "India", "Lebanon"]
    }
  },
  {
    id: "CONT_SOUTH_AMERICA",
    name: "South America",
    description: "A continent of extremes, from Andean foothills to coastal plains, producing bold, expressive wines. Argentina's Malbec and Chile's Cabernet Sauvignon have become global benchmarks for value and quality in the New World.",
    category: "CONTINENTS",
    // Malbec violet, not the merlot #73343A it wore until iOS 0.7.1 (A3).
    // A continent's `color` is its globe marker and its icon well both — one
    // value, so the two can never disagree — and #73343A sat one to five
    // points per channel from North America's #722F37. At marker size, drawn
    // at 0.2–0.45 opacity over the globe, the two continents were the same
    // dot. Violet is the only hue more than 100° from anything else in the
    // set (three dark reds, two pinks and Asia's gold), and it is the colour
    // of the grape this continent is known for.
    color: "#6E3B7A",
    icon: "globe",
    tags: ["Continent"],
    details: {
      keyRegions: ["Argentina", "Brazil", "Chile", "Uruguay"]
    }
  },
  {
    id: "CONT_AFRICA",
    name: "Africa",
    description: "Africa's wine heritage spans from ancient Egyptian traditions to modern innovations. South Africa's Cape region produces world-class wines that blend Old World elegance with New World vibrancy, while other regions are rapidly developing their vinicultural potential.",
    category: "CONTINENTS",
    // Ochre, not the #C48B8B it wore until iOS 0.7.2 (A1) — the same fix South
    // America got in 0.7.1 (A3), applied to the pair that was left.
    //
    // #C48B8B and Oceania's #D4A5A5 both had G == B exactly, so both sat at hue
    // 0° with near-identical saturation; the only thing telling them apart was
    // lightness, and at marker size over a lit globe at 0.2–0.45 opacity they
    // were two shades of one dusty pink. Sixteen points of red and twenty-six
    // of green and blue is not a colour difference anyone can name.
    //
    // Ochre rather than another red because the reds are full: North America,
    // Europe and the two old pinks were four of the six markers inside a 351°–0°
    // band. This sits at ~25°, which is the widest gap available without
    // reaching for a blue — and a blue marker on a globe reads as ocean, which
    // is the one thing a continent must not look like. Sun-baked earth is also
    // the right register for the continent whose wine story starts in Egypt.
    color: "#B95E19",
    icon: "globe",
    tags: ["Continent"],
    details: {
      keyRegions: ["South Africa", "Morocco"]
    }
  },
  {
    id: "CONT_OCEANIA",
    name: "Oceania",
    description: "The southernmost wine regions of the world, where maritime climates and diverse terroirs create distinctive wines. Australia's bold Shiraz and New Zealand's aromatic Sauvignon Blanc have redefined international wine styles.",
    category: "CONTINENTS",
    // Eucalypt green, not the #D4A5A5 it wore until iOS 0.7.2 (A1) — see the
    // note on Africa above for why the pink pair had to be broken up.
    //
    // Green is the only wide hue left once Africa takes the ochre, and it is
    // the one this continent can actually claim: eucalyptus — mint, menthol,
    // the smell of the bush — is the textbook descriptor for Coonawarra
    // Cabernet and Australian Shiraz, and the app already puts tasting notes on
    // screen. It is also the far side of the wheel from every other marker: its
    // nearest neighbour is now South America's violet, and no two continents
    // sit closer than North America and Europe already did.
    //
    // **That last clause is out of date and the fix is on Europe** (0.8.0, I):
    // Europe is cobalt now, so the closest pair in the set is no longer two
    // claret plates a few points apart, and the sentence above is kept only as
    // the record of what was still wrong when it was written.
    color: "#3E8E63",
    icon: "globe",
    tags: ["Continent"],
    details: {
      keyRegions: ["Australia", "New Zealand"]
    }
  }
];

export const CONTINENTS: ContinentEntry[] = CONTINENTS_BASE;