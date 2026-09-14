#!/usr/bin/env python3
"""
region_check.py — the gate. Reads the SHIPPED base map PNG, not the geometry it
came from, and asserts every catalog coordinate resolves to a wine region.

    python3 region_check.py italy                    # runs against pins-italy.json
    python3 region_check.py france my-pins.json      # the real regions.ts rows

Input JSON: a list of {"id":..., "name":..., "lon":..., "lat":...}.

`id` is the CATALOG id (R032), and it is not cosmetic: it keys
`<name>-region-index.json`, which is the artefact the app reads to turn a
catalog row into a painted region. A pin file without ids can check the map but
cannot write that index — see WHICH PINS below.

WHICH PINS
  The seven older countries carry two pin files. `pins-<c>.json` is dense and
  name-only: more coverage, better at catching a mis-painted département.
  `pins-<c>-catalog.json` is the real regions.ts rows, with ids. Austria and
  China have one file that is both.

  The check runs against whatever you name, defaulting to `pins-<c>.json`. The
  region index is written from whichever pins carry ids, which is a different
  file for those seven — and the reason this is spelled out is that it did not
  used to be. `by_id[i or n]` fell back to the pin NAME, so the documented
  invocation `python3 region_check.py france` silently replaced an id-keyed
  index with a name-keyed one. Nothing failed; the file just stopped being able
  to answer the question it exists for.

Exit 0 if every pin lands on a coloured region. Exit 1 otherwise, listing which
pins failed and how. This is deliberately the same discipline as
`outlines:check` after 0.8.4 — read the file the app opens, so the check cannot
go on being green about art that is no longer shipped.

The three failure kinds it distinguishes:
  OFF-MAP      the coordinate is outside the canvas entirely
  ON-STONE     inside France but in an unassigned département (nearest region
               reported, since that is what the runtime hit test will return)
  MISMATCH     resolved, but to a region other than `expect`, when a pin
               carries an `expect` field
"""
import json, math, os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
args = [a for a in sys.argv[1:] if not a.startswith('-')]
NAME = args[0] if args and not args[0].endswith('.json') else 'france'
OUT = os.path.join(HERE, 'out', NAME)

man = json.load(open(os.path.join(OUT, '%s-manifest.json' % NAME)))
CW, CH = man['base']['canvas']

# The gate reads the INDEX raster, because that is what the app hit-tests. The
# art is checked against it separately, below, so the two cannot drift.
idx = np.array(Image.open(os.path.join(OUT, '%s-index.png' % NAME)))
assert idx.shape == (CH, CW), 'manifest canvas disagrees with the index raster'

# The second index plane, when the country has one. Read BEFORE the base plane,
# which is the order the app uses: non-zero wins, otherwise fall back. Reading it
# here is what proves containment end to end — R099 has to come back
# `chateauneuf` from the shipped rasters, not from the geometry it was cut from.
IDX2, KIDS = None, {}
_p2 = os.path.join(OUT, '%s-index2.png' % NAME)
if os.path.exists(_p2):
    IDX2 = np.array(Image.open(_p2))
    assert IDX2.shape == idx.shape, 'the two index planes disagree on the grid'
    KIDS = {c['id']: n for n, c in (man.get('children') or {}).items()}
    assert KIDS, '%s-index2.png exists but the manifest declares no children' % NAME
    for n, c in man['children'].items():
        inside = ((IDX2 == c['id']) & (idx == man['regions'][c['parent']]['id'])).sum()
        assert inside == (IDX2 == c['id']).sum(), \
            '%s leaks outside %s in the shipped rasters' % (n, c['parent'])
    print('plane 2: %d children, all inside their parents' % len(KIDS))

art = np.array(Image.open(os.path.join(OUT, '%s-regions.png' % NAME)).convert('RGB'))
SC = man['base']['export_scale']
art = art[::SC, ::SC]
for n, r in man['regions'].items():
    px = np.unique(art[idx == r['id']].reshape(-1, 3), axis=0)
    assert len(px) == 1 and '#%02X%02X%02X' % tuple(px[0]) == r['fill'], \
        'art and index disagree on ' + n
img = art

pr = man['projection']
K, O, S = pr['x_factor'], pr['origin'], pr['scale']
BY_ID = {r['id']: n for n, r in man['regions'].items()}
assert len(BY_ID) == len(man['regions']), 'two regions share an id'
BY_RGB = {tuple(int(r['fill'][i:i + 2], 16) for i in (1, 3, 5)): n
          for n, r in man['regions'].items()}
STONE = tuple(int(man['base']['unassigned'][i:i + 2], 16) for i in (1, 3, 5))
INK = tuple(int(man['base']['outline'][i:i + 2], 16) for i in (1, 3, 5))

COORDS = {n: np.argwhere(idx == i) for i, n in BY_ID.items()}   # (y, x)


def to_canvas(lon, lat):
    return (lon * K - O[0]) * S + 2, (-lat - O[1]) * S + 2


def nearest(x, y):
    best = (1e18, None)
    for n, ys in COORDS.items():
        d = ((ys[:, 1] - x) ** 2 + (ys[:, 0] - y) ** 2).min()
        if d < best[0]:
            best = (d, n)
    return best[1], math.sqrt(best[0])


def resolve(pins):
    """Where each pin lands on the shipped index raster."""
    fails, rows = [], []
    for p in pins:
        x, y = to_canvas(p['lon'], p['lat'])
        # FLOOR, not round. The rasteriser fills cell i from canvas coordinate
        # [i, i+1), so the cell containing a point is floor(coord); rounding
        # picks the nearest cell CENTRE and lands one cell over for anything in
        # the upper half of a cell. Invisible on a 464-cell region and decisive
        # on a 5-cell child: two Sauternes probes 2.5 km apart disagreed, one
        # answering `sauternes` and the other `bordeaux`, purely from this.
        xi, yi = int(x), int(y)
        got, note = None, ''
        if not (0 <= xi < CW and 0 <= yi < CH):
            note = 'OFF-MAP'
        else:
            kid = int(IDX2[yi, xi]) if IDX2 is not None else 0
            v = int(idx[yi, xi])
            got = KIDS.get(kid) or BY_ID.get(v)
            if got is None:
                n, d = nearest(x, y)
                kind = 'ON-STONE' if v == 255 else 'OUTSIDE'
                note = '%s -> nearest %s (%.1fpx)' % (kind, n, d)
                got = n
        if note:
            fails.append((p, note))
        elif p.get('expect') and p['expect'] != got:
            note = 'MISMATCH expected %s' % p['expect']
            fails.append((p, note))
        rows.append((p.get('id', ''), p['name'], got or '-', note))
    return fails, rows


named = next((a for a in args if a.endswith('.json')), None)
src = named or os.path.join(HERE, 'pins-%s.json' % NAME)
pins = json.load(open(src))
print('checking %d pins from %s\n' % (len(pins), os.path.basename(src)))

fails, rows = resolve(pins)

w1 = max(len(r[0]) for r in rows) or 1
w2 = max(len(r[1]) for r in rows)
for i, n, g, note in rows:
    print('%-*s  %-*s  %-11s %s' % (w1, i, w2, n, g, note))

# --- the region index, from pins that carry catalog ids ----------------------
cat = os.path.join(HERE, 'pins-%s-catalog.json' % NAME)
if all(p.get('id') for p in pins):
    idx_src, idx_rows = src, rows
elif not named and os.path.exists(cat):
    idx_src = cat
    _f, idx_rows = resolve(json.load(open(cat)))
    print('\nregion index from %s (%d pins)' % (os.path.basename(cat), len(idx_rows)))
else:
    idx_src, idx_rows = None, None
    print('\n%s-region-index.json NOT written: these pins carry no catalog ids,\n'
          'and overwriting an id-keyed index with a name-keyed one is worse than\n'
          'leaving it alone. Run with the catalog pins to rebuild it.' % NAME)

# A pin in the dense file whose id is NOT in the catalog file is a pin that
# passes this check and links to nothing.
#
# This is the trap the catalog-preference branch above created, and it caught me
# with my own code: R063 Canary Islands, R081 Madeira and R121 Azores went into
# the dense files, resolved correctly, reported PASS — and never reached the
# region index, because on a two-file country the index is built from the
# catalog file alone. The Canaries tile read NO CATALOG ENTRY HERE YET on a
# region that had just been painted for it.
#
# The gate has to fail on that. A pin that resolves but does not link is worse
# than one that does not resolve, because the first kind reports success.
if idx_src and named is None and idx_src != src:
    dense_ids = {p['id'] for p in pins if p.get('id')}
    cat_ids = {r[0] for r in idx_rows if r[0]}
    orphan = sorted(dense_ids - cat_ids)
    if orphan:
        print('\nFAIL — %d pin%s in %s carr%s an id the catalog file does not:'
              % (len(orphan), '' if len(orphan) == 1 else 's',
                 os.path.basename(src), 'ies' if len(orphan) == 1 else 'y'))
        for i in orphan:
            n = next((p['name'] for p in pins if p.get('id') == i), '?')
            print('  %-6s %s' % (i, n))
        print('\nThese resolve on the map and reach NOTHING: %s is built from %s,\n'
              'so the app will show NO CATALOG ENTRY HERE YET on a painted region.\n'
              'Put the row in the catalog file, not only in the dense one.'
              % ('%s-region-index.json' % NAME, os.path.basename(idx_src)))
        sys.exit(1)

if idx_rows is not None:
    by_id, by_stem = {}, {s: [] for s in man['regions']}
    by_stem.update({s: [] for s in (man.get('children') or {})})
    for (i, n, g, note) in idx_rows:
        if not note and g in by_stem:
            by_id[i] = g
            by_stem[g].append(i)
    assert all(by_id), 'a pin reached the index without a catalog id'
    json.dump({'byId': by_id, 'byStem': by_stem},
              open(os.path.join(OUT, '%s-region-index.json' % NAME), 'w'),
              ensure_ascii=False, indent=1)
    print('\nwrote %s-region-index.json (%d ids mapped from %s)'
          % (NAME, len(by_id), os.path.basename(idx_src)))

if fails:
    print('FAIL — %d of %d pins did not resolve cleanly:' % (len(fails), len(pins)))
    for p, note in fails:
        print('  %-24s %s' % (p['name'], note))
    print('\nFix by adding the département to the right region in france_map.py, or '
          'by adding a SPLITS entry in countries.py. Do not add an exception list.')
    sys.exit(1)
print('PASS — all %d pins resolved to a wine region.' % len(pins))
