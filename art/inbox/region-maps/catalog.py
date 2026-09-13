"""Read-only view of the catalog, for gates on this side of the fence.

`shared/data/regions.ts` is read-only from the art side and stays that way. This
reads it; it never writes it, and nothing here may be imported into `shared/`.

It exists because of a mistake worth not repeating. Deciding which countries the
globe should carry, I used the country-outline art as the proxy — the filenames
in `art/icons/entries/countries/`. Outlines exist for countries the catalog does
not carry, so that set is 51 where the catalog's is 34, and the ten I derived as
"missing from the globe" included six that have no catalog entry at all. Landing
them would have made six countries tappable that open nothing, which is the bug
`GlobeIndexTests.everyCountryResolves` was written for after the USA shipped an
empty country page for all of 0.9.55.

The art is not the catalog. When the question is "does the app know about this
country", the answer is in `regions.ts` and nowhere else.

    from catalog import origins, regions
    origins()          # {'argentina', 'armenia', ..., 'usa'}  — stems
    regions()          # [(id, name, stem), ...] — every catalog region row

Parsing TypeScript with a regular expression is not something to be proud of,
and the alternative is a claim in a document instead of a query. The assert on
the count is there so a shape change in `regions.ts` fails loudly rather than
returning a plausible short list.
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
REGIONS_TS = os.path.join(REPO, 'shared', 'data', 'regions.ts')

MIN_ORIGINS = 25          # a floor, not the count; 39 on 13 Sep 2026
MIN_ROWS = 120            # a floor, not the count; 157 on 13 Sep 2026


def slug(origin):
    """Catalog origin -> art stem. 'New Zealand' -> 'new-zealand', 'USA' -> 'usa'.

    No exception table, deliberately: every one of the 34 slugs straight, and a
    table here would be a place for a wrong answer to hide.
    """
    return origin.strip().lower().replace(' ', '-')


def _read(path=None):
    p = path or REGIONS_TS
    if not os.path.exists(p):
        raise SystemExit(
            'cannot read %s.\nThis gate reads the catalog directly; run it from '
            'inside the repo.' % p)
    with open(p, encoding='utf-8') as fh:
        return fh.read()


def regions(path=None):
    """Every catalog region row, as (id, name, country stem).

    Each row is one line of the form `{ id: "R001", name: "Bordeaux", ...`, with
    `origin` somewhere in the same object. Matched per row rather than by
    scraping the whole file, so a row missing an origin fails the assert below
    instead of silently pairing with its neighbour's.
    """
    s = _read(path)
    out = []
    for m in re.finditer(r'^\s*\{ id: "(R\d+)", name: "([^"]+)"', s, re.M):
        seg = s[m.start():m.start() + 2500]
        o = re.search(r'origin: "([^"]+)"', seg)
        if o:
            out.append((m.group(1), m.group(2), slug(o.group(1))))
    assert len(out) >= MIN_ROWS, (
        'only %d region rows parsed out of regions.ts — the file\'s shape has '
        'probably changed and this regex is now lying. Fix it before trusting '
        'any gate that calls this.' % len(out))
    return out


def origins(path=None):
    """Every country the catalog has at least one region for, as art stems."""
    found = set(re.findall(r'origin: "([^"]+)"', _read(path)))
    assert len(found) >= MIN_ORIGINS, (
        'only %d origins parsed out of regions.ts — the file\'s shape has '
        'probably changed and this regex is now lying. Fix it before trusting '
        'any gate that calls this.' % len(found))
    return {slug(o) for o in found}
