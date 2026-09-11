#!/usr/bin/env python3
"""
france_map.py — renders the Vinodex France region map from département geometry.

Self-contained: needs only fr-departements.json (beside this file), numpy, scipy
and Pillow. No network.

    python3 france_map.py            # base map + 14 detail maps + manifest
    python3 france_map.py --base     # base map + manifest only

Outputs, into ./out/ :
    france-regions.png      the base map, 5x nearest-neighbour
    map-<stem>.png          one detail map per region, 5x
    france-manifest.json    computed button fractions + palette + groupings

Everything positional in the manifest is COMPUTED. Nothing here is authored by
hand except REGIONS below, which is the whole point: a re-render can change the
canvas size and the manifest stays correct.

See horizon-md/france-map-plan.md for why each of these decisions is what it is.
"""
import json, math, sys, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
OUT  = os.path.join(HERE, 'out')

MAG   = (238, 3, 225)     # chroma key, matches every other sheet in art/inbox
INK   = (26, 20, 32)      # #1A1420  France's coastline: the strongest line drawn
STONE = (206, 198, 186)   # #CEC6BA  unassigned France
SEA         = (56, 80, 107)    # #38506B
SHALLOW     = (78, 105, 133)   # #4E6985  shelf band hugging every coast
FOREIGN     = (140, 135, 120)  # #8C8778  neighbouring countries, dimmer than STONE
FOREIGN_INK = (26, 20, 32)     # #1A1420  same black as France, one line per frontier

# --- the only authored table in this file ----------------------------------
# wine region art stem -> (départements it is built from, fill)
# These stems are ART NAMES. They are deliberately not ids in regions.ts and
# never need to be — see §5.1 of the plan.
REGIONS = {
 'bordeaux'  : (['Gironde'],                                              (142, 47, 69)),
 'southwest' : (['Dordogne', 'Lot', 'Lot-et-Garonne', 'Tarn', 'Tarn-et-Garonne',
                 'Gers', 'Landes', 'Pyrénées-Atlantiques', 'Hautes-Pyrénées',
                 'Aveyron', 'Ariège', 'Haute-Garonne'],                   (201, 162, 76)),
 'loire'     : (['Loire-Atlantique', 'Maine-et-Loire', 'Indre-et-Loire',
                 'Loir-et-Cher', 'Loiret', 'Cher', 'Nièvre', 'Indre'],    (110, 148, 100)),
 'burgundy'  : (["Côte-d'Or", 'Saône-et-Loire', 'Yonne'],                 (166, 99, 31)),
 'beaujolais': (['Rhône'],                                                (208, 87, 122)),
 'champagne' : (['Marne', 'Aube', 'Aisne', 'Haute-Marne'],                (228, 208, 138)),
 'alsace'    : (['Bas-Rhin', 'Haute-Rhin'],                               (62, 140, 138)),
 'jura'      : (['Jura'],                                                 (138, 123, 176)),
 'savoie'    : (['Savoie', 'Haute-Savoie'],                               (127, 168, 201)),
 'rhone'     : (['Ardèche', 'Drôme', 'Vaucluse', 'Gard'],                 (168, 65, 44)),
 'provence'  : (['Var', 'Bouches-du-Rhône', 'Alpes-de-Haute-Provence',
                 'Alpes-Maritimes'],                                      (217, 143, 122)),
 'languedoc' : (['Hérault', 'Aude'],                                      (140, 143, 62)),
 'roussillon': (['Pyrénées-Orientales'],                                  (95, 91, 140)),
 'corsica'   : (['Corse-du-Sud', 'Haute-Corse'],                          (78, 122, 74)),
}

# The Rhône département holds Beaujolais in its north and the head of the
# Northern Rhône (Ampuis, Côte-Rôtie) in its south. Cut it where Beaujolais
# stops. Reproducible; survives a re-render. §3 of the plan.
SPLITS = [('beaujolais', 'rhone', 45.62)]     # (north stem, south stem, lat)

LOG    = 160   # logical pixels on FRANCE's long axis (not the canvas — see MARGIN)
MARGIN = int(os.environ.get('MARGIN', 170))  # logical px of world on every side
SHELF  = 3     # shelf band width; the coastline eats the innermost pixel
MIN_ISLAND = 20  # land masses smaller than this are specks, not islands
SCALE = 5      # export multiplier, nearest-neighbour
SS    = 6      # rasteriser supersample; max-pooled down, so thin capes survive

# ---------------------------------------------------------------------------
FR = {f['properties']['name']: f
      for f in json.load(open(os.path.join(HERE, 'fr-departements.json')))['features']}

missing = sorted({d for deps, _ in REGIONS.values() for d in deps} - set(FR))
assert not missing, 'no such département: %s' % missing
claimed = [d for deps, _ in REGIONS.values() for d in deps]
assert len(claimed) == len(set(claimed)), 'a département is claimed by two regions'


def rings(names):
    out = []
    for n in names:
        g = FR[n]['geometry']
        polys = [g['coordinates']] if g['type'] == 'Polygon' else g['coordinates']
        for p in polys:
            out.append([np.array(r, float) for r in p])
    return out


def project(polys, k):
    """Equirectangular with a cos(mean latitude) correction on x."""
    return [[np.stack([r[:, 0] * k, -r[:, 1]], axis=1) for r in poly] for poly in polys]


def _supersample(ringsets, mn, S, W, H):
    im = Image.new('L', (W * SS, H * SS), 0)
    dr = ImageDraw.Draw(im)
    for poly in ringsets:
        for i, r in enumerate(poly):
            q = (r - mn) * S * SS + SS
            dr.polygon([tuple(v) for v in q], fill=(255 if i == 0 else 0))
    return (np.array(im) > 0).reshape(H, SS, W, SS)


def raster(ringsets, mn, S, W, H):
    """Presence: max-pooled, so a one-subpixel cape still shows up."""
    return _supersample(ringsets, mn, S, W, H).max(axis=(1, 3))


def coverage(ringsets, mn, S, W, H):
    """How much of each logical pixel the shape covers, 0..SS*SS.

    Regions are rasterised independently, so max-pooling alone makes neighbours
    overlap by a pixel along every shared border and the last one written wins —
    which put Tavel (Gard) in Provence. Contested pixels go to whichever region
    actually covers more of them instead. See §3 of the plan.
    """
    return _supersample(ringsets, mn, S, W, H).sum(axis=(1, 3))


def despeckle(m, min_hole=4):
    """Enclosed gaps smaller than min_hole are sub-pixel noise, not lakes."""
    holes = ndimage.binary_fill_holes(m) & ~m
    lab, n = ndimage.label(holes)
    for i in range(1, n + 1):
        c = (lab == i)
        if c.sum() < min_hole:
            m |= c
    return m


CROSS = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], bool)


def border(mask):
    """One-pixel outer border, 4-connected.

    8-connected dilation looks like the obvious choice and is wrong: at every
    diagonal staircase it paints both the pixel above and the pixel beside, so
    the line comes out two and three pixels thick along any coast that isn't
    axis-aligned. The cross kernel gives a line that is exactly one pixel thick
    everywhere and still visually continuous, because the result is itself
    8-connected.
    """
    return ndimage.binary_dilation(mask, CROSS) & ~mask


def outline(mask, canvas, colour=INK):
    canvas[border(mask)] = colour


def drop_islets(m, min_px=MIN_ISLAND):
    """Remove land masses too small to draw as anything but a speck.

    A 2-pixel island still gets a full border, so it renders as a dot of ink with
    a dot of land inside it — noise along a coast that is otherwise one clean
    line. Île de Ré, Oléron and Noirmoutier go; Corsica (205 px) and the
    Balearics stay.
    """
    lab, n = ndimage.label(m)
    if not n:
        return m
    keep = np.bincount(lab.ravel())
    keep[0] = 0
    return np.isin(lab, np.nonzero(keep >= min_px)[0])


def pole(m):
    """Pole of inaccessibility: interior point furthest from any edge.

    NOT the arithmetic centroid, which lands outside concave shapes — Gironde's
    estuary is exactly that notch.
    """
    dt = ndimage.distance_transform_edt(np.pad(m, 1))[1:-1, 1:-1]
    y, x = np.unravel_index(dt.argmax(), dt.shape)
    return int(x), int(y), float(dt.max())


# --- projection, sized on France, then widened by MARGIN --------------------
allr = rings(list(FR))
K = math.cos(math.radians(np.vstack([p[0] for p in allr])[:, 1].mean()))
P = project(allr, K)
allp = np.vstack([r for poly in P for r in poly])
FMN, FMX = allp.min(axis=0), allp.max(axis=0)
span = FMX - FMN
S = (LOG - 2) / span.max()
FW = int(round(span[0] * S)) + 2          # France's own footprint, for the rect below
FH = int(round(span[1] * S)) + 2

# The canvas is France's box plus a margin of sea and neighbours on every side.
# The projection ORIGIN moves; the scale does not, so France is drawn at exactly
# the size it would have been without a backdrop and every downstream number
# stays comparable to the pre-backdrop run.
MN = FMN - MARGIN / S
W = FW + 2 * MARGIN
H = FH + 2 * MARGIN

canvas = np.full((H + 2, W + 2, 3), SEA, np.uint8)

# --- exterior: neighbouring countries ---------------------------------------
NB = json.load(open(os.path.join(HERE, 'neighbours.json')))['features']
nb_rings = []
for f in NB:
    for poly in f['geometry']['coordinates']:
        nb_rings.append([np.array(r, float) for r in poly])
foreign = np.zeros((H + 2, W + 2), bool)
foreign[1:-1, 1:-1] = despeckle(raster(project(nb_rings, K), MN, S, W, H))
foreign = drop_islets(foreign)

# France's own silhouette, needed here only so the shelf hugs its coast too
fr_land = np.zeros((H + 2, W + 2), bool)
fr_land[1:-1, 1:-1] = despeckle(raster(P, MN, S, W, H))
fr_land = drop_islets(fr_land)

# continental shelf: a lighter band of sea hugging every coast, the way a
# printed atlas shades shallow water. Two pixels, so it reads at this size.
shelf = ndimage.binary_dilation(foreign | fr_land, iterations=SHELF) & ~(foreign | fr_land)
canvas[shelf] = SHALLOW
canvas[foreign] = FOREIGN

# --- one line per frontier --------------------------------------------------
# Outlining each country separately draws its border into its neighbour's
# territory, so every shared frontier came out as TWO parallel lines — one laid
# down by each side. Label the countries instead and derive the borders from
# where the labels change, which can only ever produce one line.
lab = np.zeros((H + 2, W + 2), np.int16)
for i, f in enumerate(NB, start=1):
    rr = [[np.array(r, float) for r in poly] for poly in f['geometry']['coordinates']]
    m = np.zeros((H + 2, W + 2), bool)
    m[1:-1, 1:-1] = raster(project(rr, K), MN, S, W, H)
    lab[m & foreign & (lab == 0)] = i
lab[fr_land] = -1                     # France is its own label, never a neighbour's

# The interactive layer paints France's coastline one pixel outside France, so
# anything the backdrop draws there would sit alongside it as a second line.
fr_edge = border(fr_land)

# Coastline: derived from the union, so it is drawn once in the sea.
coast = border(foreign) & ~fr_land & ~fr_edge

# Internal frontiers: a pixel is a border if the label to its right or below
# differs. Two conditions, both load-bearing:
#   - directional, because checking all four neighbours marks the pixel on BOTH
#     sides of every frontier, which is the doubling again;
#   - both sides must be foreign LAND, because otherwise a coastal pixel counts
#     as a frontier with the sea and gets inked on the land side while `coast`
#     inks the sea side — a two-pixel coastline on every south- and east-facing
#     shore.
internal = np.zeros_like(foreign)
internal[:, :-1] |= (lab[:, :-1] != lab[:, 1:]) & foreign[:, :-1] & foreign[:, 1:]
internal[:-1, :] |= (lab[:-1, :] != lab[1:, :]) & foreign[:-1, :] & foreign[1:, :]
internal &= ~fr_edge

# Land that runs off the canvas is cut by the window, not bounded by a coast.
# Drawing a border along that cut turns the edge of the map into a black frame,
# so the outer ring is left alone and the land simply runs off.
rim = np.zeros_like(foreign)
rim[:2, :] = rim[-2:, :] = True
rim[:, :2] = rim[:, -2:] = True

canvas[(coast | internal) & ~rim] = FOREIGN_INK

# France's own footprint is filled with STONE rather than left as sea: the
# interactive layer covers it exactly, so this is only ever visible as a seam if
# the two layers are a pixel out of register — and a stone seam is invisible
# where a sea-blue one would not be.
canvas[fr_land] = STONE

# the rasteriser leaves a one-pixel pad on every side; replicate into it so the
# backdrop bleeds to the true edge instead of showing a frame of open sea
canvas[0] = canvas[1]; canvas[-1] = canvas[-2]
canvas[:, 0] = canvas[:, 1]; canvas[:, -1] = canvas[:, -2]
backdrop = canvas.copy()

# --- France on top ----------------------------------------------------------
land = fr_land          # the same silhouette the backdrop was cut around,
canvas[land] = STONE    # so the two layers register by construction

stems = list(REGIONS)
cov = np.stack([coverage(project(rings(REGIONS[s][0]), K), MN, S, W, H) for s in stems])
win = cov.argmax(axis=0)                 # ties go to the earlier stem, deterministically
any_ = cov.max(axis=0) > 0
masks = {}
for i, stem in enumerate(stems):
    q = np.zeros((H + 2, W + 2), bool)
    q[1:-1, 1:-1] = any_ & (win == i)
    masks[stem] = q & land

for north, south, lat in SPLITS:
    ycut = int(round((-lat - MN[1]) * S)) + 2
    below = np.zeros((H + 2, W + 2), bool)
    below[ycut:, :] = True
    moved = masks[north] & below
    masks[north] &= ~moved
    masks[south] |= moved
    print('split %s/%s at %.2fN: %d px -> %s' % (north, south, lat, moved.sum(), south))

for stem in REGIONS:
    canvas[masks[stem]] = REGIONS[stem][1]
outline(land, canvas)
CH, CW = canvas.shape[:2]

# France's own box within the canvas, as fractions. The app should scale the
# pair so THIS rect fills the intended width and let the backdrop bleed off the
# screen edges — that keeps every tap target the size §5.2 measured.
FRECT = [round((MARGIN + 1) / CW, 4), round((MARGIN + 1) / CH, 4),
         round(FW / CW, 4), round(FH / CH, 4)]

os.makedirs(OUT, exist_ok=True)


def save(arr, name):
    Image.fromarray(arr).resize((arr.shape[1] * SCALE, arr.shape[0] * SCALE),
                                Image.NEAREST).save(os.path.join(OUT, name))


# the interactive layer: France only, everything else the chroma key
inter = np.full_like(canvas, MAG)
inter[land] = canvas[land]
outline(land, inter)
save(inter, 'france-regions.png')      # hit-tested; key means "not France"
save(backdrop, 'france-backdrop.png')  # sea + neighbours, drawn underneath
save(canvas, 'france-map-preview.png')  # the two composited, for eyeballing

# --- computed button positions + collision proof ---------------------------
btn = {n: pole(m) for n, m in masks.items()}


def collisions(d):
    ks, hits = list(btn), []
    for i in range(len(ks)):
        for j in range(i + 1, len(ks)):
            (x1, y1, _), (x2, y2, _) = btn[ks[i]], btn[ks[j]]
            r = math.hypot(x1 - x2, y1 - y2)
            if r < d:
                hits.append([ks[i], ks[j], round(r, 1)])
    return sorted(hits, key=lambda t: t[2])


print('base canvas %dx%d logical, exported %dx%d' % (CW, CH, CW * SCALE, CH * SCALE))
print('%-11s %5s %5s %7s %7s' % ('region', 'bx', 'by', 'clear', 'px'))
for n, (x, y, r) in sorted(btn.items(), key=lambda t: -t[1][2]):
    print('%-11s %5d %5d %7.1f %7d' % (n, x, y, r, masks[n].sum()))
for d in (12, 10, 8):
    print('marker d=%2d -> %d collisions %s' % (d, len(collisions(d)), collisions(d)))

# --- detail maps -----------------------------------------------------------
DETAIL_LOG = 60      # logical px long axis; 5x -> ~300px, matches §6.2
detail_meta = {}
if '--base' not in sys.argv:
    for stem, (deps, col) in REGIONS.items():
        rr = project(rings(deps), K)
        pts = np.vstack([r for poly in rr for r in poly])
        mn, mx = pts.min(axis=0), pts.max(axis=0)
        sp = mx - mn
        s = (DETAIL_LOG - 2) / sp.max()
        w = int(round(sp[0] * s)) + 2
        h = int(round(sp[1] * s)) + 2
        m = despeckle(raster(rr, mn, s, w, h))
        c = np.full((h + 2, w + 2, 3), MAG, np.uint8)
        q = np.zeros((h + 2, w + 2), bool)
        q[1:-1, 1:-1] = m
        c[q] = col
        outline(q, c)
        Image.fromarray(c).resize(((w + 2) * SCALE, (h + 2) * SCALE), Image.NEAREST) \
             .save(os.path.join(OUT, 'map-%s.png' % stem))
        detail_meta[stem] = {
            'canvas': [w + 2, h + 2],
            'bounds_projected': [list(np.round(mn, 6)), list(np.round(mx, 6))],
            'scale': round(float(s), 6),
        }
    print('%d detail maps written' % len(detail_meta))

# --- manifest --------------------------------------------------------------
manifest = {
  'generator': 'france_map.py',
  'projection': {'kind': 'equirectangular', 'x_factor': round(K, 8),
                 'origin': [round(float(MN[0]), 6), round(float(MN[1]), 6)],
                 'scale': round(float(S), 6),
                 'note': 'canvas_x = (lon*x_factor - origin[0])*scale + 2 ; '
                         'canvas_y = (-lat - origin[1])*scale + 2'},
  'base': {'canvas': [CW, CH], 'export_scale': SCALE,
           'unassigned': '#%02X%02X%02X' % STONE, 'outline': '#%02X%02X%02X' % INK,
           'key': '#%02X%02X%02X' % MAG,
           'layers': {'interactive': 'france-regions.png',
                      'backdrop': 'france-backdrop.png'},
           'france_rect': FRECT,
           'france_rect_note': 'x,y,w,h as fractions of the canvas. Scale the two '
                               'layers together so this rect fills the intended '
                               'width; the backdrop bleeds off the screen edges.'},
  'backdrop': {'margin_px': MARGIN, 'sea': '#%02X%02X%02X' % SEA,
               'foreign': '#%02X%02X%02X' % FOREIGN,
               'foreign_outline': '#%02X%02X%02X' % FOREIGN_INK,
               'shallow': '#%02X%02X%02X' % SHALLOW, 'shelf_px': SHELF,
               'countries': sorted(f['properties']['name'] for f in NB)},
  'marker_clearance': {str(d): collisions(d) for d in (12, 10, 8)},
  'splits': [{'north': a, 'south': b, 'lat': c} for a, b, c in SPLITS],
  'regions': {
     n: {'button': [round(x / CW, 4), round(y / CH, 4)],
         'clearance_px': round(r, 1),
         'area_px': int(masks[n].sum()),
         'fill': '#%02X%02X%02X' % REGIONS[n][1],
         'departements': REGIONS[n][0],
         'detail': detail_meta.get(n)}
     for n, (x, y, r) in btn.items()},
}
json.dump(manifest, open(os.path.join(OUT, 'france-manifest.json'), 'w'),
          ensure_ascii=False, indent=1)
print('wrote out/france-manifest.json')

# expose for france_check.py
__all__ = ['masks', 'land', 'K', 'MN', 'S', 'CW', 'CH', 'REGIONS', 'btn']
