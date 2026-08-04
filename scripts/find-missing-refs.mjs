#!/usr/bin/env node
// Cross-reference audit over the shipped data (0.6 A1 acceptance gate).
//
// Reads the generated entries.json rather than the shared/ sources, so it
// checks exactly what the app resolves against — with one deliberate
// exception, the country gates, which never reach entries.json at all and are
// read from shared/ instead (see the COUNTRY_GATE note below). Matching
// mirrors the app's resolver (TextNormalize.label): lowercase, diacritics
// folded, punctuation collapsed; an entry answers to its name and its synonyms.
//
// Exit 0 with "zero dangling" only when every cross-reference resolves:
//   - grape/style/continent/country keyRegions -> a REGION (or, for
//     continents, a country with at least one region)
//   - region/style/country notableGrapes       -> a GRAPE ("Various" excluded)
//   - grape wineType                           -> a STYLE
//   - grape tastingProfile notes               -> a FLAVOR

import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const entries = JSON.parse(
  readFileSync(resolve(HERE, '..', 'Sources', 'VinodexCore', 'Resources', 'entries.json'), 'utf8'),
);
// The authored country blurbs. A continent may list a country with *zero*
// regions on purpose — the coming-soon gates (0.6.4, batch 2) — and the mark
// of "planned, not typo'd" is an authored blurb in countries.json: a
// misspelled roster name has no blurb, a deliberate gate always does. The
// continent check below accepts either a region origin or a blurb.
const countryBlurbs = JSON.parse(
  readFileSync(resolve(HERE, '..', 'Sources', 'VinodexCore', 'Resources', 'countries.json'), 'utf8'),
);

const norm = (s) =>
  String(s ?? '')
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

const byCategory = (cat) => entries.filter((e) => e.category === cat);

const index = (list) => {
  const keys = new Set();
  for (const e of list) {
    keys.add(norm(e.name));
    for (const syn of e.details?.synonyms ?? []) keys.add(norm(syn));
    for (const syn of e.grapeAlternateNames ?? []) keys.add(norm(syn));
  }
  return keys;
};

const grapes = byCategory('GRAPES');
const regions = byCategory('REGIONS');
const styles = byCategory('STYLES');
const flavors = byCategory('FLAVORS');
const continents = byCategory('CONTINENTS');
// **The country gates are read from `shared/`, not from `entries.json`.**
//
// This arm used to be `byCategory('COUNTRY_GATE')`, and the generator
// deliberately drops that category on the way out (`generate-ios-data.ts`) —
// so the list was always empty, the loop at the bottom of this file had never
// executed once, and the summary line reported an honest, useless "0
// countries". Thirty gates' worth of `keyRegions` and `notableGrapes` went
// unchecked from the day the gate was written until 0.7.4, when sommbot
// noticed and hand-verified them.
//
// `countries.ts` is object literals under an erased `import type`, so the
// array literal is valid JS exactly as it sits on disk.
//
// STATE gates stay excluded: their references are authored free text by
// design, and whether that is right is an open question in
// data-review/FINDINGS.md rather than something this gate should rule on.
const countriesSource = readFileSync(
  resolve(HERE, '..', 'shared', 'data', 'countries.ts'),
  'utf8',
);
const countriesStart = countriesSource.indexOf('[', countriesSource.search(/=\s*\[/));
const countries = Function(
  `return ${countriesSource.slice(countriesStart, countriesSource.lastIndexOf(']') + 1)}`,
)().filter((e) => e.details?.classification !== 'STATE');

const grapeKeys = index(grapes);
const regionKeys = index(regions);
const styleKeys = index(styles);
const flavorKeys = index(flavors);
const regionOrigins = new Set(regions.map((r) => norm(r.details?.origin)));
// See the countries.json load above: a blurbed, region-less country is a
// deliberate coming-soon gate, not a dangling reference.
const blurbedCountries = new Set(Object.keys(countryBlurbs).map(norm));

const missing = { grapes: new Map(), regions: new Map(), styles: new Map(), countries: new Map(), flavors: new Map() };
const record = (bucket, name, from) => {
  const key = norm(name);
  if (!bucket.has(key)) bucket.set(key, { name, from: [] });
  bucket.get(key).from.push(from);
};

const SKIP_GRAPES = new Set(['various']);

for (const g of grapes) {
  for (const r of g.details?.keyRegions ?? []) {
    if (!regionKeys.has(norm(r))) record(missing.regions, r, `grape ${g.name}`);
  }
  for (const t of [g.wineType, g.grapeStyle].filter(Boolean)) {
    if (!styleKeys.has(norm(t))) record(missing.styles, t, `grape ${g.name}`);
  }
  for (const n of g.tastingProfile ?? []) {
    if (!flavorKeys.has(norm(n.note))) record(missing.flavors, n.note, `grape ${g.name}`);
  }
}

for (const r of regions) {
  for (const g of r.details?.notableGrapes ?? []) {
    if (SKIP_GRAPES.has(norm(g))) continue;
    if (!grapeKeys.has(norm(g))) record(missing.grapes, g, `region ${r.name}`);
  }
}

for (const st of styles) {
  for (const r of st.details?.keyRegions ?? []) {
    if (!regionKeys.has(norm(r))) record(missing.regions, r, `style ${st.name}`);
  }
  for (const g of st.details?.notableGrapes ?? []) {
    if (SKIP_GRAPES.has(norm(g))) continue;
    if (!grapeKeys.has(norm(g))) record(missing.grapes, g, `style ${st.name}`);
  }
}

for (const c of continents) {
  for (const country of c.details?.keyRegions ?? []) {
    if (!regionOrigins.has(norm(country)) && !blurbedCountries.has(norm(country))) {
      record(missing.countries, country, `continent ${c.name} (no region originates there, no authored blurb)`);
    }
  }
}

for (const c of countries) {
  for (const r of c.details?.keyRegions ?? []) {
    if (!regionKeys.has(norm(r))) record(missing.regions, r, `country ${c.name}`);
  }
  for (const g of c.details?.notableGrapes ?? []) {
    if (SKIP_GRAPES.has(norm(g))) continue;
    if (!grapeKeys.has(norm(g))) record(missing.grapes, g, `country ${c.name}`);
  }
}

let total = 0;
for (const [kind, bucket] of Object.entries(missing)) {
  if (bucket.size === 0) continue;
  console.log(`\nMissing ${kind} (${bucket.size}):`);
  for (const { name, from } of bucket.values()) {
    total += 1;
    console.log(`  - ${name}  <- ${from.join(', ')}`);
  }
}

console.log(
  `\n${total === 0 ? 'zero dangling' : `${total} dangling names`} — ` +
    `${grapes.length} grapes, ${regions.length} regions, ${styles.length} styles, ` +
    `${flavors.length} flavors, ${countries.length} countries`,
);
process.exit(total === 0 ? 0 : 1);
