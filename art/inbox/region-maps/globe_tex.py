#!/usr/bin/env python3
"""Builds the textures the globe prototype samples.

Two kinds, both plain equirectangular so the globe's own projection is the only
projection involved:

  globe-index.png        world, one byte per cell: 0 sea, 1 land, 2+ wine country
  rgn-<country>.png      that country's wine regions, one byte per cell, cropped
                         to its bounding box

Land masses too small to survive the trip are dropped here rather than at draw
time. A speck that covers a fraction of a screen pixel does not render smaller —
it flickers on and off as the sphere turns, because point sampling either hits it
or misses it. Removing it from the source is the only fix that costs nothing per
frame.
"""
import json, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
from countries import COUNTRIES

WINE = {
 'Argentina':'argentina','Australia':'australia','Austria':'austria','Brazil':'brazil',
 'Bulgaria':'bulgaria','Canada':'canada','Chile':'chile','China':'china','Croatia':'croatia',
 'France':'france','Georgia':'georgia','Germany':'germany','Greece':'greece','Hungary':'hungary',
 'India':'india','Italy':'italy','Japan':'japan','Lebanon':'lebanon','Mexico':'mexico',
 'Morocco':'morocco','New Zealand':'new-zealand','Portugal':'portugal','Romania':'romania',
 'Slovenia':'slovenia','South Africa':'south-africa','Spain':'spain','Switzerland':'switzerland',
 'United Kingdom':'united-kingdom','United States of America':'usa','Uruguay':'uruguay',
}
MIN_CELLS = 9          # world cells; ~19.5 km a side at the equator
W, H = 2048, 1024


def rings_of(feat):
    g = feat['geometry']
    return [g['coordinates']] if g['type'] == 'Polygon' else g['coordinates']


def paint(dr, polys, value, lon0, lat1, sx, sy):
    for poly in polys:
        for i, ring in enumerate(poly):
            a = np.array(ring, float)
            xy = [((lo - lon0) * sx, (lat1 - la) * sy) for lo, la in a]
            if len(xy) > 2:
                dr.polygon(xy, fill=(value if i == 0 else 0))


def despeck(a, min_cells=MIN_CELLS):
    """Drop connected components below min_cells, per class, keeping each class's
    largest piece whatever its size — a small country must not vanish."""
    out = a.copy()
    for v in np.unique(a):
        if v == 0:
            continue
        lab, n = ndimage.label(a == v)
        if n < 2:
            continue
        sizes = np.bincount(lab.ravel()); sizes[0] = 0
        keep = set(np.nonzero(sizes >= min_cells)[0]) | {int(sizes.argmax())}
        drop = ~np.isin(lab, list(keep)) & (lab > 0)
        out[drop] = 0
    return out


# --- world -------------------------------------------------------------------
D = json.load(open(os.path.join(HERE, 'ne.json')))['features']
im = Image.new('L', (W, H), 0)
dr = ImageDraw.Draw(im)
for f in D:
    paint(dr, rings_of(f), 1, -180, 90, W/360, H/180)
order = sorted(WINE)
for i, adm in enumerate(order, start=2):
    for f in D:
        if f['properties'].get('ADMIN') == adm:
            paint(dr, rings_of(f), i, -180, 90, W/360, H/180)
a = np.array(im)
before = (a > 0).sum()
a = despeck(a)
print('world: dropped %d specks (%.2f%% of land)'
      % (before - (a > 0).sum(), 100 * (before - (a > 0).sum()) / before))
gone = [adm for i, adm in enumerate(order, 2) if not (a == i).any()]
assert not gone, gone
Image.fromarray(a).save(os.path.join(HERE, 'globe-index.png'), optimize=True)

meta = {'countries': [{'idx': i, 'admin': adm, 'stem': WINE[adm]}
                      for i, adm in enumerate(order, 2)]}

# --- per-country region textures --------------------------------------------
LONG = 300                       # cells on the country's long axis
regions = {}
for name, cfg in COUNTRIES.items():
    feats = json.load(open(os.path.join(HERE, cfg['admin1'])))['features']
    drop = set(cfg.get('exclude', ()))
    feats = [f for f in feats if f['properties']['name'] not in drop]
    by_name = {f['properties']['name']: f for f in feats}
    by_region = {}
    for f in feats:
        by_region.setdefault(f['properties'].get('region'), []).append(f['properties']['name'])

    def units(spec):
        return list(by_region[spec['region']]) if isinstance(spec, dict) else list(spec)

    REG = {s: units(v) for s, v in cfg['regions'].items()}
    stems = list(REG)

    # crop the texture the way the flat map frames itself, so a long thin country
    # is not mostly empty cells
    if cfg.get('frame_window'):
        lon0, lat0, lon1, lat1 = cfg['frame_window']
    else:
        src = feats if cfg.get('focus') != 'regions' else \
            [by_name[u] for u in sorted({u for us in REG.values() for u in us})]
        pts = np.vstack([np.array(r, float) for f in src for p in rings_of(f) for r in p])
        lon0, lat0 = pts[:,0].min(), pts[:,1].min()
        lon1, lat1 = pts[:,0].max(), pts[:,1].max()
    pad = 0.06 * max(lon1-lon0, lat1-lat0)
    lon0 -= pad; lon1 += pad; lat0 -= pad; lat1 += pad
    sx = sy = (LONG - 1) / max(lon1-lon0, lat1-lat0)
    w = int(round((lon1-lon0) * sx)) + 1
    h = int(round((lat1-lat0) * sy)) + 1

    # Contested cells go to whichever region covers more of them, the same rule
    # the flat maps use. First-come-first-served looks equivalent and is not: it
    # hands every shared border to whichever region the config happens to list
    # earlier, which put Madrid — a province wholly enclosed by La Mancha — into
    # La Mancha. Supersampling also stops coastal cells falling through the
    # cracks between a polygon edge and the cell grid.
    SS = 4
    cov = np.zeros((len(stems), h, w), np.int16)
    for i, stem in enumerate(stems):
        if not REG[stem]:
            continue                       # split-only region, filled below
        m = Image.new('L', (w * SS, h * SS), 0)
        paint(ImageDraw.Draw(m), [p for u in REG[stem] for p in rings_of(by_name[u])],
              255, lon0, lat1, sx * SS, sy * SS)
        cov[i] = (np.array(m) > 0).reshape(h, SS, w, SS).sum(axis=(1, 3))
    grid = np.where(cov.max(axis=0) > 0, cov.argmax(axis=0) + 1, 0).astype(np.uint8)

    for spec in cfg['splits']:
        keeps, gains, val = spec[0], spec[1], spec[2]
        axis = spec[3] if len(spec) > 3 else 'lat'
        ki, gi = stems.index(keeps)+1, stems.index(gains)+1
        other = np.zeros((h, w), bool)
        if axis == 'lat':
            cut = int(round((lat1 - val) * sy)); other[max(cut,0):, :] = True
        else:
            cut = int(round((val - lon0) * sx)); other[:, :max(cut,0)] = True
        grid[(grid == ki) & other] = gi

    grid = despeck(grid, 4)
    man = json.load(open(os.path.join(HERE, 'out', name, '%s-manifest.json' % name)))
    Image.fromarray(grid).save(os.path.join(HERE, 'rgn-%s.png' % name), optimize=True)
    regions[name] = {
        'bounds': [round(lon0,4), round(lat0,4), round(lon1,4), round(lat1,4)],
        'size': [w, h],
        'stems': stems,
        'fills': [man['regions'][s]['fill'] for s in stems],
        'labels': [s for s in stems],
    }
    print('%-11s %3dx%-3d  %d regions' % (name, w, h, len(stems)))

meta['regions'] = regions
json.dump(meta, open(os.path.join(HERE, 'globe-meta.json'), 'w'), indent=1)
print('wrote globe-index.png, %d region textures, globe-meta.json' % len(regions))
