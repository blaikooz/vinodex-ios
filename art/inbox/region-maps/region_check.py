#!/usr/bin/env python3
"""
region_check.py — the gate. Reads the SHIPPED base map PNG, not the geometry it
came from, and asserts every catalog coordinate resolves to a wine region.

    python3 region_check.py italy                    # runs against pins-italy.json
    python3 region_check.py france my-pins.json      # the real regions.ts rows

Input JSON: a list of {"id":..., "name":..., "lon":..., "lat":...}.
`id` is optional and only used in the report.

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


src = next((a for a in args if a.endswith('.json')),
           os.path.join(HERE, 'pins-%s.json' % NAME))
pins = json.load(open(src))
print('checking %d pins from %s\n' % (len(pins), os.path.basename(src)))

fails, rows = [], []
for p in pins:
    x, y = to_canvas(p['lon'], p['lat'])
    xi, yi = int(round(x)), int(round(y))
    got, note = None, ''
    if not (0 <= xi < CW and 0 <= yi < CH):
        note = 'OFF-MAP'
    else:
        v = int(idx[yi, xi])
        got = BY_ID.get(v)
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

w1 = max(len(r[0]) for r in rows) or 1
w2 = max(len(r[1]) for r in rows)
for i, n, g, note in rows:
    print('%-*s  %-*s  %-11s %s' % (w1, i, w2, n, g, note))

by_id, by_stem = {}, {s: [] for s in man['regions']}
for (i, n, g, note) in rows:
    if not note and g in by_stem:
        by_id[i or n] = g
        by_stem[g].append(i or n)
json.dump({'byId': by_id, 'byStem': by_stem},
          open(os.path.join(OUT, '%s-region-index.json' % NAME), 'w'),
          ensure_ascii=False, indent=1)
print('\nwrote %s-region-index.json (%d ids mapped)' % (NAME, len(by_id)))

if fails:
    print('FAIL — %d of %d pins did not resolve cleanly:' % (len(fails), len(pins)))
    for p, note in fails:
        print('  %-24s %s' % (p['name'], note))
    print('\nFix by adding the département to the right region in france_map.py, or '
          'by adding a SPLITS entry in countries.py. Do not add an exception list.')
    sys.exit(1)
print('PASS — all %d pins resolved to a wine region.' % len(pins))
