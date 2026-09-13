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
import hashlib, json, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
import geosrc
from countries import COUNTRIES

# Natural Earth's ADMIN spelling -> the country's stem. The stems are not
# invented here: they are the filenames in art/icons/entries/countries, which is
# the namespace the rest of the app already uses. Checked against that folder,
# not guessed — NE spells Serbia "Republic of Serbia" and would have failed the
# assert below, and Bosnia is "Bosnia and Herzegovina".
WINE = {
 'Argentina':'argentina','Australia':'australia','Austria':'austria','Brazil':'brazil',
 'Bulgaria':'bulgaria','Canada':'canada','Chile':'chile','China':'china','Croatia':'croatia',
 'France':'france','Georgia':'georgia','Germany':'germany','Greece':'greece','Hungary':'hungary',
 'India':'india','Italy':'italy','Japan':'japan','Lebanon':'lebanon','Mexico':'mexico',
 'Morocco':'morocco','New Zealand':'new-zealand','Portugal':'portugal','Romania':'romania',
 'Slovenia':'slovenia','South Africa':'south-africa','Spain':'spain','Switzerland':'switzerland',
 'United Kingdom':'united-kingdom','United States of America':'usa','Uruguay':'uruguay',
 # Added once ne.json reached the repo. These four are the whole gap: they carry
 # catalog regions and could not be tapped because the globe could not be built.
 'Armenia':'armenia','Cyprus':'cyprus','Moldova':'moldova','Turkey':'turkey',
 #
 # NOT ADDED, and the reason is the assert below. A first pass here carried ten,
 # derived from the set difference between art/icons/entries/countries/*.png (51
 # stems) and this table. That derivation is wrong: **the art is not the
 # catalog.** Outlines exist for countries with no entry, and six of the ten —
 # bosnia, czechia, israel, serbia, slovakia, ukraine — appear in neither
 # regions.ts nor countries.ts. Landing them would have made six countries
 # tappable that open nothing, which is what GlobeIndexTests.everyCountryResolves
 # was written for after the USA shipped an empty country page for all of 0.9.55.
 # The catalog leads and the map follows; they land when sommbot writes them.
 #
 # Their Natural Earth spellings, checked, so nobody re-derives them and nobody
 # guesses: Serbia is 'Republic of Serbia' and Bosnia is 'Bosnia and
 # Herzegovina'. Both would fail the ADMIN join silently-ish. The matching
 # display-name correction belongs beside the USA one in GlobeIndex.catalogName.
 #
 # The eleven remaining country-outline stems are US states (arizona, california,
 # idaho, michigan, missouri, new-mexico, new-york, oregon, texas, virginia,
 # washington). Admin-0 has no state boundaries, so on the globe they are all
 # 'usa'; separating them needs the admin-1 plane, not another entry here.
 #
 # Known approximation: NE files 'Northern Cyprus' as its own admin-0 feature, so
 # the north of the island paints as plain land, not as Cyprus. Left alone —
 # every Cypriot wine region is south of the line — but a tap up there answers
 # "land", and that is a decision, not an oversight.
}
MIN_CELLS = 9          # world cells; ~19.5 km a side at the equator
W, H = 2048, 1024

# The globe carries exactly the countries the catalog has regions for. Not the
# ones with outline art — that set is 51 and includes six countries with no
# entry, plus eleven US states admin-0 cannot separate. A country on the globe
# with nothing behind it is a tappable dead end, and the Swift side has a test
# for it; this is the same assert one step earlier, where it costs a re-run
# instead of a round trip.
try:
    import catalog
    _want = catalog.origins()
    _have = set(WINE.values())
    assert _have == _want, (
        'globe country list disagrees with shared/data/regions.ts.\n'
        '  on the globe, not in the catalog: %s\n'
        '  in the catalog, not on the globe: %s\n'
        'The catalog leads. Add the entry first, then the country.'
        % (sorted(_have - _want) or 'none', sorted(_want - _have) or 'none'))
    print('catalog: %d countries, and WINE matches' % len(_want))
except SystemExit as e:                       # not inside the repo — say so, run on
    print('catalog check skipped: %s' % e)


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
D = geosrc.load('ne.json')['features']
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

# --- the country table -------------------------------------------------------
# globe-meta.json is installed VERBATIM by install_globe.py and decoded by
# GlobeIndex.Meta.Entry, which requires idx, admin, label and mapped — all
# non-optional — while install_globe.py requires fill. This script used to emit
# only idx/admin/stem, so running it destroyed four fields that had been added
# to the shipped file by hand: install would have raised KeyError('fill') and,
# past that, the globe would have decoded to nil and gone back to untappable.
# No test catches it, because the file is data.
#
# So the generator now emits the whole contract, and carries forward anything it
# does not compute from the file already on disk. Authored fills are authored;
# nothing here overwrites one.
#   idx    class in the raster
#   admin  Natural Earth's spelling — the join key back to the geometry
#   stem   the app's slug: art/icons/entries/countries/<stem>.png
#   key    the flat-map directory (COUNTRIES key) when there is one, else stem.
#          These differ exactly once: stem 'new-zealand', key 'newzealand'.
#   label  display text, admin uppercased, with the overrides below
#   mapped how many regions the flat map has; 0 means "no drill-down"
#   fill   the country's colour on the globe
LABELS = {'United States of America': 'UNITED STATES'}

prior = {}
_p = os.path.join(HERE, 'globe-meta.json')
if os.path.exists(_p):
    prior = {c['stem']: c for c in json.load(open(_p)).get('countries', [])}

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

# --- fill in the rest of the country table -----------------------------------
KEY = {}                                   # stem -> flat-map directory
for name in regions:
    for adm, stem in WINE.items():
        if stem.replace('-', '') == name:
            KEY[stem] = name

for c in meta['countries']:
    stem, old = c['stem'], prior.get(c['stem'], {})
    c['key'] = KEY.get(stem, stem)
    c['label'] = old.get('label') or LABELS.get(c['admin'], c['admin'].upper())
    c['mapped'] = len(regions[c['key']]['stems']) if c['key'] in regions else 0
    if 'fill' in old:
        c['fill'] = old['fill']            # authored; never regenerated

# Anything still without a fill is new to the globe. Colour it against its
# NEIGHBOURS, read off the raster that was just painted — the new arrivals are a
# central-European cluster and handing them colours off the top of a list is how
# you get two countries nobody can tell apart.
missing = [c for c in meta['countries'] if 'fill' not in c]
if missing:
    import palette
    # Every pair, not the touching ones. The flat maps optimise adjacency because
    # a flat map shows one country and only neighbours have to be told apart. A
    # globe does not work that way, and two weaker rules were tried and measured
    # before this one:
    #   adjacency         -> Slovakia and Turkey at ΔE 6.6. They do not touch.
    #   within 40 degrees -> China and Turkey at ΔE 4.0. Their centroids are 45
    #                        degrees apart and they are still in the same eyeful.
    # Any proximity threshold has an outside, and the outside is visible. The 30
    # authored fills already hold a floor of ΔE 10.1, so a complete graph is not
    # even expensive here — it just has to clear the floor that exists.
    stems = [c['stem'] for c in meta['countries']]
    touch = {frozenset((p, q)) for i, p in enumerate(stems) for q in stems[i + 1:]}
    # Measured AFTER install_globe.py's brighten, which is the colour that
    # reaches the sphere. Measured before it, the first ten fills scored ΔE 15.5
    # and shipped at 1.7: `v * 2.05` clips at 1.0, so every fill above v≈0.49
    # arrives at the same value and the separation is spent on nothing.
    got = palette.extend(
        touch,
        {c['stem']: c['fill'] for c in meta['countries'] if 'fill' in c},
        [c['stem'] for c in missing],
        transform=palette.brighten)
    for c in missing:
        c['fill'] = got[c['stem']]
    print('new country fills: ' + ', '.join('%s %s' % (c['stem'], c['fill'])
                                            for c in missing))

ORDER = ('idx', 'admin', 'stem', 'fill', 'label', 'mapped', 'key')
meta['countries'] = [{k: c[k] for k in ORDER} for c in meta['countries']]

# The contract, asserted here rather than discovered on a simulator.
for c in meta['countries']:
    for k in ORDER:
        assert c.get(k) not in (None, ''), (c['stem'], k)
    assert c['fill'].startswith('#') and len(c['fill']) == 7, c
assert len({c['fill'] for c in meta['countries']}) == len(meta['countries']), \
    'two countries share a fill'

# The raster's fingerprint, so the pair cannot be shipped mismatched.
#
# `idx` is the position in sorted(WINE). Adding one country renumbers most of
# them, and a globe-index.png from before the change decodes cleanly against a
# globe-meta.json from after it — every country simply answers as its
# alphabetical neighbour. Nothing crashes, no test fails on a shape, and the bug
# reads as "the hit test is off" rather than "two files disagree". Cheap to make
# impossible; expensive to find.
#
# **Over the DECODED PIXELS, not the file bytes.** The first version hashed the
# file and was defeated within the hour: the delivery path between machines
# re-encodes PNGs, so the same raster arrived as 39,973 bytes instead of 34,203,
# with a different hash each time, while every pixel was identical. A byte hash
# of an image is a hash of one encoder's output, not of the data — it fails on a
# re-save that changed nothing, and would pass on a hand-edited raster re-encoded
# the same way. The pixels are the contract, so hash those.
#
# (Same cause as the seven frozen rgn-*.png differing in bytes from a local
# render while matching cell for cell. That was written off as "two PILs"; it
# was this.)
_px = np.array(Image.open(os.path.join(HERE, 'globe-index.png')))
meta['index_pixels'] = {'sha256': hashlib.sha256(_px.tobytes()).hexdigest(),
                        'shape': list(_px.shape)}

json.dump(meta, open(os.path.join(HERE, 'globe-meta.json'), 'w'), indent=1)
print('wrote globe-index.png, %d region textures, globe-meta.json (%d countries)'
      % (len(regions), len(meta['countries'])))
