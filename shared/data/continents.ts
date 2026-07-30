import type { ContinentEntry } from '../types';

const CONTINENTS_BASE: ContinentEntry[] = [
  {
    id: "CONT_NORTH_AMERICA",
    name: "North America",
    description: "The birthplace of New World wine, North America combines Old World traditions with innovative winemaking. From California's sun-drenched valleys to Canada's cool-climate vineyards, the continent produces a diverse range of styles that have revolutionized global wine production.",
    category: "CONTINENTS",
    // v0.5.4: each continent gets its own hue family. The six wells used to
    // run wine reds and roses, and once the glyphs became three shared
    // region-globes (0.5.3) the colour was the only thing telling a pair
    // apart. North America: lake blue.
    color: "#1D4E89",
    icon: "globe",
    tags: ["Continent"],
    details: {
      keyRegions: ["USA", "Canada"]
    }
  },
  {
    id: "CONT_EUROPE",
    name: "Europe",
    description: "The cradle of viticulture, Europe has shaped wine culture for millennia. From France's prestigious appellations to Italy's ancient vineyards, Europe's diverse climates and terroirs produce wines of unparalleled complexity and tradition.",
    category: "CONTINENTS",
    // Europe keeps the wine red — it earned it.
    color: "#8E2439",
    icon: "globe",
    tags: ["Continent"],
    details: {
      keyRegions: ["France", "Italy", "Spain", "Germany", "Portugal", "Hungary", "Austria", "Greece", "Georgia", "Switzerland", "Romania"]
    }
  },
  {
    id: "CONT_ASIA",
    name: "Asia",
    description: "An emerging wine frontier blending ancient traditions with modern innovation. From China's high-altitude vineyards to Japan's delicate whites, Asia's diverse landscapes are producing increasingly sophisticated wines that reflect both heritage and contemporary winemaking.",
    category: "CONTINENTS",
    // Asia: gold (unchanged in spirit from the old #C9A227).
    color: "#C9A227",
    icon: "globe",
    tags: ["Continent"],
    details: {
      keyRegions: ["China", "Japan", "India"]
    }
  },
  {
    id: "CONT_SOUTH_AMERICA",
    name: "South America",
    description: "A continent of extremes, from Andean foothills to coastal plains, producing bold, expressive wines. Argentina's Malbec and Chile's Cabernet Sauvignon have become global benchmarks for value and quality in the New World.",
    category: "CONTINENTS",
    // South America: Andean green.
    color: "#2E8B57",
    icon: "globe",
    tags: ["Continent"],
    details: {
      keyRegions: ["Argentina", "Chile", "Uruguay"]
    }
  },
  {
    id: "CONT_AFRICA",
    name: "Africa",
    description: "Africa's wine heritage spans from ancient Egyptian traditions to modern innovations. South Africa's Cape region produces world-class wines that blend Old World elegance with New World vibrancy, while other regions are rapidly developing their vinicultural potential.",
    category: "CONTINENTS",
    // Africa: ochre.
    color: "#C4762B",
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
    // Oceania: reef teal.
    color: "#2AA5A0",
    icon: "globe",
    tags: ["Continent"],
    details: {
      keyRegions: ["Australia", "New Zealand"]
    }
  }
];

export const CONTINENTS: ContinentEntry[] = CONTINENTS_BASE;