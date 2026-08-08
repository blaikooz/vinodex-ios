# Dataset provenance

The Vinodex wine dataset — every description and data record in
`shared/data/` (`grapes.ts`, `regions.ts`, `styles.ts`, `countries.ts`,
`grapeCards.ts`, `continents.ts`, `climateClasses.ts`, `flagGradients.ts`),
compiled into `Sources/VinodexCore/Resources/entries.json` — was written
first-party by the project owners. As of 2026-08-05 the catalog is 405
entries: 146 GRAPES, 116 REGIONS, 106 FLAVORS, 31 STYLES, 6 CONTINENTS.
Owner declaration of authorship recorded 2026-08-05.

## Independence from the Sotheby's text

No text in this dataset derives from `sothebys-wine-encyclopedia-2005.raw.txt`,
a 4.5 MB copy of a copyrighted wine encyclopedia committed to the upstream
monorepo (`blaikooz/vinodex`). That file was never mirrored into this
repository and is not a source for any entry here. This note also serves as
the standing record — previously in KNOWN-ISSUES.md — that the file exists in
the upstream repository's history and is scheduled to be purged from it;
deleting the record does not delete the exposure, so this paragraph should
outlive the purge as its documentation.
