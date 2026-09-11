#!/usr/bin/env python3
"""
france_check.py — the gate. Reads the SHIPPED base map PNG, not the geometry it
came from, and asserts every catalog coordinate resolves to a wine region.

    python3 france_check.py                    # runs against pins-sample.json
    python3 france_check.py my-pins.json       # runs against the real regions.ts rows

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
OUT = os.path.join(HERE, 'out')

man = json.load(open(os.path.join(OUT, 'france-manifest.json')))
img = np.array(Image.open(os.path.join(OUT, 'france-regions.png')).convert('RGB'))
SC = man['base']['export_scale']
img = img[::SC, ::SC]                                   # back to logical pixels
CW, CH = man['base']['canvas']
assert img.shape[:2] == (CH, CW), 'manifest canvas disagrees with the PNG'

pr = man['projection']
K, O, S = pr['x_factor'], pr['origin'], pr['scale']
BY_RGB = {tuple(int(r['fill'][i:i + 2], 16) for i in (1, 3, 5)): n
          for n, r in man['regions'].items()}
STONE = tuple(int(man['base']['unassigned'][i:i + 2], 16) for i in (1, 3, 5))
INK = tuple(int(man['base']['outline'][i:i + 2], 16) for i in (1, 3, 5))

# region masks, read off the shipped art
masks = {n: np.all(img == np.array(c, np.uint8), axis=2) for c, n in BY_RGB.items()}
COORDS = {n: np.argwhere(m) for n, m in masks.items()}    # (y, x)


def to_canvas(lon, lat):
    return (lon * K - O[0]) * S + 2, (-lat - O[1]) * S + 2


def nearest(x, y):
    best = (1e18, None)
    for n, ys in COORDS.items():
        d = ((ys[:, 1] - x) ** 2 + (ys[:, 0] - y) ** 2).min()
        if d < best[0]:
            best = (d, n)
    return best[1], math.sqrt(best[0])


src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'pins-sample.json')
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
        px = tuple(img[yi, xi])
        got = BY_RGB.get(px)
        if got is None:
            n, d = nearest(x, y)
            kind = 'ON-STONE' if px == STONE else ('ON-OUTLINE' if px == INK else 'ON-KEY')
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
          open(os.path.join(OUT, 'france-region-index.json'), 'w'),
          ensure_ascii=False, indent=1)
print('\nwrote out/france-region-index.json (%d ids mapped)' % len(by_id))

if fails:
    print('FAIL — %d of %d pins did not resolve cleanly:' % (len(fails), len(pins)))
    for p, note in fails:
        print('  %-24s %s' % (p['name'], note))
    print('\nFix by adding the département to the right region in france_map.py, or '
          'by adding a SPLITS entry. Do not add an exception list.')
    sys.exit(1)
print('PASS — all %d pins resolved to a wine region.' % len(pins))
