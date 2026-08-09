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
//   - grape lineage refs                       -> a GRAPE *id*, or a name the
//                                                 catalog deliberately does not
//                                                 carry (0.7.5, E)
//   - exam entryRefs / entryIcon image keys    -> an entry *id* (0.7.5, D)

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

// The authored Wine Exam bank (0.7.5, D). Read from the generated JSON for the
// same reason `entries.json` is: it is what the app actually resolves against.
const exam = JSON.parse(
  readFileSync(resolve(HERE, '..', 'Sources', 'VinodexCore', 'Resources', 'exam.json'), 'utf8'),
);

const missing = { grapes: new Map(), regions: new Map(), styles: new Map(), countries: new Map(), flavors: new Map(), lineage: new Map(), exam: new Map() };
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

// **The lineage arm (0.7.5, E), and it is the one arm that does not go through
// the name index.** Every other check here resolves a *name* the way the app's
// resolver does, because that is how the rest of the catalog cross-references.
// `lineage` deliberately does not: an in-catalog link is an `id`, because the
// grape-name index is exactly where name resolution breaks down — "Espadeiro"
// answers to five VIVC prime names, "Nerello" to seven — and a pedigree wired by
// name would silently marry a Galician vine to a Portuguese one. See
// `LineageRef` in shared/types.ts.
//
// So there are two kinds of ref and each gets its own rule:
//
//   `{ id }`   must name a grape in this build. A typo'd id is a broken edge
//              and there is no fuzzy match that could rescue it.
//   `{ name }` is an ancestor the catalog does not carry, on purpose — Gouais
//              Blanc is the mother of a third of France's varieties and will
//              never be a collectible entry. It is *not* checked against the
//              grape list, because a hit would mean the ref was wrong, not
//              right: that is the case below.
//
// The failures, all of them schema violations rather than missing content:
// a ref with both keys or neither (the type says exactly one), an id that
// resolves to nothing, and a name that matches a catalog grape's own *primary*
// name — which is an edge that should have been written as an id and would
// otherwise draw a terminal node for a grape you can tap.
//
// A name matching a *synonym* is not a failure and is counted separately.
// That case is real and authored: `Mammolo` is a synonym of G168 Sciaccarellu
// because VIVC folds the two into one record, and Verdicchio's pedigree names
// the Tuscan variety rather than the Corsican entry. Ruling on which is a
// factual question for data-review/FINDINGS.md, not for this gate.
const grapeIDs = new Set(grapes.map((g) => g.id));
const grapePrimaryNames = new Map(grapes.map((g) => [norm(g.name), g.id]));
const grapeSynonyms = new Map();
for (const g of grapes) {
  for (const s of g.grapeAlternateNames ?? []) grapeSynonyms.set(norm(s), g.name);
}

/** Every ref on one lineage block, flattened. `mutationOf` is a single ref. */
const lineageRefs = (l) => [
  ...(l.parents ?? []),
  ...(l.mutationOf ? [l.mutationOf] : []),
  ...(l.related ?? []),
];

const externalAncestors = new Map();
const synonymAncestors = new Map();
let lineageEdges = 0;
let authoredLineages = 0;
// Refs, not distinct names: 36 ancestors are pointed at 47 times, and both
// numbers say something different about the backlog.
let externalRefs = 0;

for (const g of grapes) {
  const lineage = g.lineage;
  if (!lineage) continue;
  authoredLineages += 1;
  for (const ref of lineageRefs(lineage)) {
    lineageEdges += 1;
    if (ref.id && ref.name) {
      record(missing.lineage, `${ref.id} / ${ref.name}`, `grape ${g.name} (ref carries both id and name)`);
    } else if (ref.id) {
      if (!grapeIDs.has(ref.id)) record(missing.lineage, ref.id, `grape ${g.name} (no such grape id)`);
    } else if (ref.name) {
      externalRefs += 1;
      const key = norm(ref.name);
      externalAncestors.set(key, ref.name);
      if (grapePrimaryNames.has(key)) {
        record(
          missing.lineage,
          ref.name,
          `grape ${g.name} (named ancestor IS ${grapePrimaryNames.get(key)} — write it as an id)`,
        );
      } else if (grapeSynonyms.has(key)) {
        synonymAncestors.set(key, `${ref.name} = a synonym of ${grapeSynonyms.get(key)}`);
      }
    } else {
      record(missing.lineage, '(empty ref)', `grape ${g.name} (ref carries neither id nor name)`);
    }
  }
}

// **The exam arm (0.7.5, D)**, and like the lineage arm it deliberately does
// *not* go through the name index. An `entryRefs` element is an entry id by
// contract — sommbot's own note gives the reason the lineage refs give, that the
// grape-name index over-lumps (Espadeiro answers to five VIVC prime names,
// Nerello to seven) — so a name here is a mis-authored ref, not a resolvable
// one, and resolving it would be wiring in exactly the ambiguity the id rule
// exists to prevent.
//
// Three failure modes, all schema violations rather than missing content:
//
//   - an id that names nothing in this build (a typo, or a ref to an entry a
//     later data batch removed);
//   - a ref that is a *name* — caught by testing it against the name index
//     precisely so it can be reported as "write this as an id" rather than
//     accepted;
//   - an `imageIdentification` question whose `entryIcon` key is not an entry
//     id, which would draw a blank tile on a question that is nothing but a
//     picture.
//
// `countryOutline` image keys and `aromaIdentification` `noteKeys` are **not**
// checked here: they are keys of `icons.json` tables that only
// `generate-ios-data.ts` defines, so `assertExam` checks them at the point the
// tables exist. The split is by ownership — a table defined in the generator is
// checked in the generator, a reference into the catalog is checked here.
const entryIDs = new Set(entries.map((e) => e.id));
const entryNames = new Map(entries.map((e) => [norm(e.name), e.id]));
const examRefCounts = new Map();
let examRefs = 0;
let examAnchored = 0;

/** Every catalog-id reference one question carries. */
const examEntryRefs = (q) => [
  ...(q.entryRefs ?? []).map((id) => ({ id, field: 'entryRefs' })),
  ...(q.format === 'imageIdentification' && q.image?.kind === 'entryIcon'
    ? [{ id: q.image.key, field: 'image.key' }]
    : []),
];

for (const q of exam.questions ?? []) {
  const refs = examEntryRefs(q);
  if (refs.length > 0) examAnchored += 1;
  for (const { id, field } of refs) {
    examRefs += 1;
    if (entryIDs.has(id)) {
      examRefCounts.set(id, (examRefCounts.get(id) ?? 0) + 1);
    } else if (entryNames.has(norm(id))) {
      record(
        missing.exam,
        id,
        `${q.id} ${field} (that is the NAME of ${entryNames.get(norm(id))} — write it as an id)`,
      );
    } else {
      record(missing.exam, id, `${q.id} ${field} (no such entry id)`);
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

// **Printed, not asserted.** An off-catalog ancestor is correct data — the
// pedigree of a variety does not stop at the edge of what this app sells — but
// it is also the backlog: each one is a grape that appears in the tree as a
// terminal node nobody can tap, and the ten grapes hanging off Gouais Blanc are
// the argument for it earning an entry. Silence here would read as "no external
// ancestors", which was never true and is the exact failure the dead
// COUNTRY_GATE arm above taught. Candidates go in data-review/CANDIDATES.md.
console.log(
  `\nlineage: ${lineageEdges} refs on ${authoredLineages} grapes — ` +
    `${lineageEdges - externalRefs} resolved in-catalog by id, ` +
    `${externalRefs} to ${externalAncestors.size} distinct off-catalog ancestors`,
);
if (synonymAncestors.size > 0) {
  console.log(
    `  ${synonymAncestors.size} off-catalog ancestor name${synonymAncestors.size === 1 ? '' : 's'} ` +
      `also answer${synonymAncestors.size === 1 ? 's' : ''} to a catalog synonym (authored, not a fault):`,
  );
  for (const note of synonymAncestors.values()) console.log(`    - ${note}`);
}

// **Printed, not asserted**, on the lineage arm's precedent. How much of the
// catalog the bank actually anchors to is editorial reach rather than
// correctness — a question about malolactic fermentation has nothing to point
// at and should not be made to — but an unmeasured number is one that quietly
// goes to zero, which is what the dead COUNTRY_GATE arm above taught.
console.log(
  `\nexam: ${(exam.questions ?? []).length} questions, ${examAnchored} anchored — ` +
    `${examRefs} refs to ${examRefCounts.size} distinct entries ` +
    `(${((examRefCounts.size / entries.length) * 100).toFixed(0)}% of the catalog)`,
);

console.log(
  `\n${total === 0 ? 'zero dangling' : `${total} dangling names`} — ` +
    `${grapes.length} grapes, ${regions.length} regions, ${styles.length} styles, ` +
    `${flavors.length} flavors, ${countries.length} countries`,
);
process.exit(total === 0 ? 0 : 1);
