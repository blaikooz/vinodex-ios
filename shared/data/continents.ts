import type { ContinentEntry } from '../types';

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
    color: "#9B2335",
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
    color: "#73343A",
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
    color: "#C48B8B",
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
    color: "#D4A5A5",
    icon: "globe",
    tags: ["Continent"],
    details: {
      keyRegions: ["Australia", "New Zealand"]
    }
  }
];

export const CONTINENTS: ContinentEntry[] = CONTINENTS_BASE;