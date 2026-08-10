#!/usr/bin/env python3
"""Draws the 33 bundled pixel flags as first-party art -> art/flags/<slug>.png.

A STANDBY set as of 2026-08-06: development builds still ship the R74n
PixelFlags copies (non-commercial use, credited in NOTICE.md) while the
owner's emailed permission request to R74n is pending. If permission is
refused, pointing the rasterize-icons.sh flag block at art/flags/<slug>.png
is the whole swap — slugs and canvas already match.

Written 2026-08-05 so the shipped set can drop the R74n copies before any
paid release:
R74n's license (licenses/LICENSE-r74n.txt) forbids commercial use without
explicit permission, and its §4 claims derivatives — so these are NOT traced
or adapted from R74n's pixels. Every flag below is drawn in code from the
underlying flag design itself: band ratios and emblem placement follow the
official construction sheets, colors follow the officially published values
(flag designs are government insignia, which carry no copyright; the pixel
rendition here is original). R74n's files were not opened during this work —
only their PNG metadata (32x18 canvas, RGBA, full-bleed) was inspected so the
recreations drop into the same pipeline.

Canvas contract, shared with the previous set so every consumer keeps working:
32x18, RGBA-8, hard pixel edges (alpha 0 or 255 only), full-bleed — except
Switzerland, whose flag is officially square and is drawn 18x18 centered on a
transparent canvas (columns 7-24), as before.

Flags are stretched to the shared 16:9 canvas regardless of each flag's legal
aspect ratio, like every other pixel-flag treatment in the app.

Requires Pillow, same as the sibling import-*-art.py importers.
Usage: python3 scripts/generate-flag-art.py [outdir]   (default: art/flags)
"""

import math
import os
import sys

from PIL import Image

W, H = 32, 18


# --------------------------------------------------------------------------
# drawing helpers — all coordinates are pixel-grid; "continuous" helpers
# (disc/ring/poly/star) sample pixel centers at (x+0.5, y+0.5)
# --------------------------------------------------------------------------

def canvas():
    return Image.new('RGBA', (W, H), (0, 0, 0, 0))


def rgb(hexstr):
    hexstr = hexstr.lstrip('#')
    return (int(hexstr[0:2], 16), int(hexstr[2:4], 16), int(hexstr[4:6], 16), 255)


def P(img, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((int(x), int(y)), c)


def rect(img, x0, y0, x1, y1, c):
    """Inclusive corners."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            P(img, x, y, c)


def hbands(img, bands):
    """[(row_count, color)] top to bottom."""
    y = 0
    for rows, c in bands:
        rect(img, 0, y, W - 1, y + rows - 1, c)
        y += rows
    assert y == H, f'hbands sum {y} != {H}'


def vbands(img, bands):
    """[(col_count, color)] hoist to fly."""
    x = 0
    for cols, c in bands:
        rect(img, x, 0, x + cols - 1, H - 1, c)
        x += cols
    assert x == W, f'vbands sum {x} != {W}'


def disc(img, cx, cy, r, c):
    for y in range(H):
        for x in range(W):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                P(img, x, y, c)


def ring(img, cx, cy, r_out, r_in, c):
    for y in range(H):
        for x in range(W):
            d2 = (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2
            if r_in * r_in < d2 <= r_out * r_out:
                P(img, x, y, c)


def _in_poly(px, py, pts):
    inside = False
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        if (y0 > py) != (y1 > py):
            xt = x0 + (py - y0) * (x1 - x0) / (y1 - y0)
            if px < xt:
                inside = not inside
    return inside


def poly(img, pts, c):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    for y in range(max(0, int(min(ys) - 1)), min(H, int(max(ys) + 2))):
        for x in range(max(0, int(min(xs) - 1)), min(W, int(max(xs) + 2))):
            if _in_poly(x + 0.5, y + 0.5, pts):
                P(img, x, y, c)


def star5(img, cx, cy, r, c, rot_deg=0.0, inner=0.42):
    """Rasterized five-point star, tip-up at rot 0."""
    pts = []
    for i in range(10):
        ang = math.radians(rot_deg + i * 36.0)
        rad = r if i % 2 == 0 else r * inner
        pts.append((cx + rad * math.sin(ang), cy - rad * math.cos(ang)))
    poly(img, pts, c)


def line(img, x0, y0, x1, y1, c):
    """Bresenham, 1px."""
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        P(img, x0, y0, c)
        if x0 == x1 and y0 == y1:
            return
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def pmap(img, x0, y0, rows, key):
    """Paint a pixel map of single-char rows; '.' is skip."""
    width = len(rows[0])
    for dy, row in enumerate(rows):
        assert len(row) == width, f'ragged pmap row {dy}: {row!r}'
        for dx, ch in enumerate(row):
            if ch != '.':
                P(img, x0 + dx, y0 + dy, key[ch])


# A 5x5 five-point star and a 5x5 seven-point burst (Commonwealth Star), the
# two smallest sizes that still read as stars on this canvas.
STAR5 = [
    '..X..',
    '.XXX.',
    'XXXXX',
    '.XXX.',
    'X...X',
]
STAR7 = [
    '..X..',
    'XXXXX',
    '.XXX.',
    'XXXXX',
    '..X..',
]


def union_jack(img, x0, y0, w, h, blue, white, red,
               cross_w, cross_r, sal_w, sal_r):
    """Union Flag in the given region.

    cross_w/cross_r: half-widths of the white and red St George cross.
    sal_w/sal_r: half-widths of the white and red saltires. The red saltire is
    offset within the white per the official counterchange — white uppermost
    in the hoist half of each diagonal.
    """
    rect(img, x0, y0, x0 + w - 1, y0 + h - 1, blue)
    cx, cy = x0 + w / 2.0, y0 + h / 2.0
    hyp = math.hypot(w, h)
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            px, py = x + 0.5, y + 0.5
            # signed perpendicular distances to the two diagonals
            # (positive = below the line)
            d1 = ((py - y0) * w - (px - x0) * h) / hyp          # TL -> BR
            d2 = ((py - (y0 + h)) * w + (px - x0) * h) / hyp    # BL -> TR
            if min(abs(d1), abs(d2)) <= sal_w:
                P(img, x, y, white)
            hoist = px < cx
            for d in (d1, d2):
                if abs(d) <= sal_w:
                    if (hoist and 0 < d <= 2 * sal_r) or (not hoist and -2 * sal_r <= d < 0):
                        P(img, x, y, red)
    # St George cross over the saltires
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            px, py = x + 0.5, y + 0.5
            if abs(px - cx) <= cross_w or abs(py - cy) <= cross_w:
                P(img, x, y, white)
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            px, py = x + 0.5, y + 0.5
            if abs(px - cx) <= cross_r or abs(py - cy) <= cross_r:
                P(img, x, y, red)


# --------------------------------------------------------------------------
# the 33 flags, alphabetical by slug
# --------------------------------------------------------------------------

def argentina():
    # Celeste-white-celeste triband; Sun of May filling the white band.
    img = canvas()
    celeste, gold = rgb('74ACDF'), rgb('F6B40E')
    hbands(img, [(6, celeste), (6, rgb('FFFFFF')), (6, celeste)])
    disc(img, 16, 9, 2.05, gold)
    for x, y in [(15, 6), (16, 6), (15, 11), (16, 11),      # N and S rays
                 (13, 8), (13, 9), (18, 8), (18, 9),        # W and E rays
                 (13, 6), (18, 6), (13, 11), (18, 11)]:     # diagonal rays
        P(img, x, y, gold)
    return img


def australia():
    # Blue ensign: Union canton, Commonwealth Star below it, Southern Cross
    # in the fly (star positions per the official construction, scaled).
    img = canvas()
    blue, white, red = rgb('012169'), rgb('FFFFFF'), rgb('E4002B')
    rect(img, 0, 0, W - 1, H - 1, blue)
    union_jack(img, 0, 0, 16, 9, blue, white, red,
               cross_w=2.0, cross_r=1.0, sal_w=1.25, sal_r=0.7)
    star = {'X': white}
    pmap(img, 6, 11, STAR7, star)      # Commonwealth Star, hoist lower half
    pmap(img, 22, 0, STAR5, star)      # Gamma Crucis (top)
    pmap(img, 22, 12, STAR5, star)     # Alpha Crucis (bottom)
    pmap(img, 18, 5, STAR5, star)      # Beta Crucis (left)
    pmap(img, 26, 3, STAR5, star)      # Delta Crucis (right)
    P(img, 26, 10, white)              # Epsilon Crucis (small)
    return img


def austria():
    # Red-white-red triband.
    img = canvas()
    red = rgb('EF3340')
    hbands(img, [(6, red), (6, rgb('FFFFFF')), (6, red)])
    return img


def bulgaria():
    # White-green-red triband.
    img = canvas()
    hbands(img, [(6, rgb('FFFFFF')), (6, rgb('00966E')), (6, rgb('D62612'))])
    return img


def california():
    # Bear Flag: white field, red hoist star, grizzly walking toward the
    # hoist on a grass plot, red stripe along the bottom. The lettering is
    # below pixel scale and is left out.
    img = canvas()
    white, red = rgb('FFFFFF'), rgb('B71234')
    rect(img, 0, 0, W - 1, H - 1, white)
    rect(img, 0, 16, W - 1, 17, red)
    pmap(img, 2, 1, STAR5, {'X': red})
    pmap(img, 8, 7, [
        '..D.............',
        '.BBB..BBBBBBB...',
        'BDBBBBBBBBBBBB..',
        '.BBBBBBBBBBBBBB.',
        '..BBBBBBBBBBBB..',
        '..BB..BB...BB...',
        'GGDDGGDDGGGDDGGG',
    ], {'B': rgb('BD8A5E'), 'D': rgb('584528'), 'G': rgb('2A6132')})
    return img


def canada():
    # 1:2:1 red-white-red pale with the maple leaf on the center square.
    img = canvas()
    red = rgb('FF0000')
    vbands(img, [(8, red), (16, rgb('FFFFFF')), (8, red)])
    pmap(img, 10, 3, [
        '.....XX.....',
        '.X...XX...X.',
        '.XX..XX..XX.',
        '.XXX.XX.XXX.',
        '..XXXXXXXX..',
        'XXXXXXXXXXXX',
        '.XXXXXXXXXX.',
        '....XXXX....',
        '.....XX.....',
        '.....XX.....',
        '.....XX.....',
    ], {'X': red})
    return img


def chile():
    # White over red; blue canton with white star on the upper hoist.
    img = canvas()
    rect(img, 0, 0, W - 1, 8, rgb('FFFFFF'))
    rect(img, 0, 9, W - 1, 17, rgb('DA291C'))
    rect(img, 0, 0, 9, 8, rgb('0033A0'))
    pmap(img, 2, 2, STAR5, {'X': rgb('FFFFFF')})
    return img


def china():
    # Red field; large gold star with four small stars arcing to its right,
    # positions per the official 30x20-unit construction grid.
    img = canvas()
    gold = rgb('FFFF00')
    rect(img, 0, 0, W - 1, H - 1, rgb('EE1C25'))
    star5(img, 5.8, 4.5, 3.4, gold)
    for x, y in [(10, 1), (12, 3), (12, 6), (10, 8)]:
        rect(img, x, y, x + 1, y + 1, gold)
    return img


def croatia():
    # Red-white-blue triband; the chequy shield straddles the red/white
    # boundary. 2px checks, red first, bottom row tapered.
    img = canvas()
    red, white = rgb('FF0000'), rgb('FFFFFF')
    hbands(img, [(6, red), (6, white), (6, rgb('171796'))])
    for y in range(4, 13):
        for x in range(12, 20):
            if y == 12 and (x < 13 or x > 18):
                continue
            c = red if ((x - 12) // 2 + (y - 4) // 2) % 2 == 0 else white
            P(img, x, y, c)
    return img


def france():
    # Blue-white-red vertical tricolor.
    img = canvas()
    vbands(img, [(11, rgb('0055A4')), (10, rgb('FFFFFF')), (11, rgb('EF4135'))])
    return img


def georgia():
    # Five Cross Flag: white field, red St George cross, a Bolnur-Katskhuri
    # cross centered in each quadrant.
    img = canvas()
    white, red = rgb('FFFFFF'), rgb('E8112D')
    rect(img, 0, 0, W - 1, H - 1, white)
    rect(img, 14, 0, 17, H - 1, red)
    rect(img, 0, 7, W - 1, 10, red)
    bolnur = ['.XX.', 'XXXX', '.XX.']
    for x0, y0 in [(5, 2), (23, 2), (5, 13), (23, 13)]:
        pmap(img, x0, y0, bolnur, {'X': red})
    return img


def germany():
    # Black-red-gold triband.
    img = canvas()
    hbands(img, [(6, rgb('000000')), (6, rgb('DD0000')), (6, rgb('FFCC00'))])
    return img


def greece():
    # Nine stripes, blue outermost (2px each on 18 rows); blue canton over
    # the first five stripes with a white cross one stripe wide.
    img = canvas()
    blue, white = rgb('0D5EAF'), rgb('FFFFFF')
    for i in range(9):
        rect(img, 0, i * 2, W - 1, i * 2 + 1, blue if i % 2 == 0 else white)
    rect(img, 0, 0, 9, 9, blue)
    rect(img, 4, 0, 5, 9, white)
    rect(img, 0, 4, 9, 5, white)
    return img


def hungary():
    # Red-white-green triband.
    img = canvas()
    hbands(img, [(6, rgb('CD2A3E')), (6, rgb('FFFFFF')), (6, rgb('436F4D'))])
    return img


def india():
    # Saffron-white-green with the navy chakra filling the white band.
    # 24 spokes don't exist at 6px; the ring alone carries it.
    img = canvas()
    hbands(img, [(6, rgb('FF9933')), (6, rgb('FFFFFF')), (6, rgb('138808'))])
    ring(img, 16, 9, 2.95, 1.55, rgb('000080'))
    return img


def italy():
    # Green-white-red vertical tricolor.
    img = canvas()
    vbands(img, [(11, rgb('009246')), (10, rgb('FFFFFF')), (11, rgb('CE2B37'))])
    return img


def japan():
    # White field, crimson sun disc (3/5 of the height, per spec).
    img = canvas()
    rect(img, 0, 0, W - 1, H - 1, rgb('FFFFFF'))
    disc(img, 16, 9, 5.3, rgb('BC002D'))
    return img


def lebanon():
    # 1:2:1-ish red-white-red with the green cedar touching both stripes.
    img = canvas()
    red = rgb('ED1C24')
    hbands(img, [(4, red), (10, rgb('FFFFFF')), (4, red)])
    pmap(img, 8, 4, [
        '.......XX.......',
        '.....XXXXXX.....',
        '....XXXXXXXX....',
        '..XXXXXXXXXXXX..',
        '....XXXXXXXX....',
        'XXXXXXXXXXXXXXXX',
        '....XXXXXXXX....',
        '.......XX.......',
        '.......XX.......',
        '.....XXXXXX.....',
    ], {'X': rgb('00A651')})
    return img


def mexico():
    # Green-white-red tricolor; eagle-on-cactus abstracted to silhouette
    # (brown eagle facing the hoist, gold beak, nopal, stone base).
    img = canvas()
    vbands(img, [(11, rgb('006341')), (10, rgb('FFFFFF')), (11, rgb('CE1126'))])
    pmap(img, 11, 5, [
        '...EE.....',
        '..YKEE....',
        '...EEEE...',
        '...EEEEE..',
        '....EEEE..',
        '....E.E...',
        '..CCCCCC..',
        '....CC....',
        '...SSSS...',
    ], {'E': rgb('6B4A2B'), 'K': rgb('3D2B1F'), 'Y': rgb('C8A040'),
        'C': rgb('4E8C3A'), 'S': rgb('C7B37F')})
    return img


def morocco():
    # Red field with the green interlaced pentagram (drawn as chords).
    img = canvas()
    rect(img, 0, 0, W - 1, H - 1, rgb('C1272D'))
    pts = []
    for i in range(5):
        ang = math.radians(i * 72.0)
        pts.append((round(16 + 5.4 * math.sin(ang) - 0.5),
                    round(9.4 - 5.4 * math.cos(ang) - 0.5)))
    green = rgb('006233')
    for a, b in [(0, 2), (2, 4), (4, 1), (1, 3), (3, 0)]:
        line(img, pts[a][0], pts[a][1], pts[b][0], pts[b][1], green)
    return img


def new_york():
    # Blue field, arms abstracted: Liberty (blue gown) and Justice (gold)
    # flanking the sun-over-river shield, eagle above, motto ribbon below.
    img = canvas()
    rect(img, 0, 0, W - 1, H - 1, rgb('002D72'))
    pmap(img, 9, 3, [
        '......GG......',
        '.....GGGG.....',
        '.F...WWWW...F.',
        'LL...WGGW...GG',
        'LL...WWWW...GG',
        'LL...WLLW...GG',
        'LL...WWWW...GG',
        '.L....WW....G.',
        '..WWWWWWWWWW..',
    ], {'G': rgb('FFC72C'), 'W': rgb('FFFFFF'), 'L': rgb('9BCBEB'),
        'F': rgb('E8B88A')})
    return img


def new_zealand():
    # Blue ensign: Union canton; Southern Cross as four red stars with
    # white borders (no Epsilon, per the official flag).
    img = canvas()
    blue, white, red = rgb('012169'), rgb('FFFFFF'), rgb('C8102E')
    rect(img, 0, 0, W - 1, H - 1, blue)
    union_jack(img, 0, 0, 16, 9, blue, white, red,
               cross_w=2.0, cross_r=1.0, sal_w=1.25, sal_r=0.7)
    star = [
        '..W..',
        '.WRW.',
        'WRRRW',
        '.WRW.',
        '..W..',
    ]
    key = {'W': white, 'R': red}
    pmap(img, 22, 1, star, key)    # Gamma (top)
    pmap(img, 22, 12, star, key)   # Alpha (bottom)
    pmap(img, 18, 6, star, key)    # Beta (left)
    pmap(img, 26, 4, star, key)    # Delta (right)
    return img


def oregon():
    # Navy field, obverse rendered gold-on-navy: eagle over the escutcheon,
    # "1859" reduced to tick marks below.
    img = canvas()
    rect(img, 0, 0, W - 1, H - 1, rgb('002A86'))
    pmap(img, 8, 3, [
        '......GGGG......',
        '.......GG.......',
        '...GGGGGGGGGG...',
        '...G........G...',
        '...G...GG...G...',
        '...G........G...',
        '....G.GGGG.G....',
        '.....G....G.....',
        '......G..G......',
        '.......GG.......',
        '................',
        '....G.G..G.G....',
    ], {'G': rgb('FFC400')})
    return img


def portugal():
    # Green hoist band (2/5), red fly; armillary sphere ringed in gold on
    # the boundary, white shield with the quinas reduced to a blue mark.
    img = canvas()
    vbands(img, [(13, rgb('046A38')), (19, rgb('DA291C'))])
    ring(img, 13, 9, 4.5, 3.4, rgb('FFE900'))
    shield_red = rgb('DA291C')
    rect(img, 10, 5, 15, 11, shield_red)
    rect(img, 11, 12, 14, 12, shield_red)
    rect(img, 11, 6, 14, 11, rgb('FFFFFF'))
    rect(img, 12, 8, 13, 9, rgb('003399'))
    return img


def romania():
    # Blue-yellow-red vertical tricolor.
    img = canvas()
    vbands(img, [(11, rgb('002B7F')), (10, rgb('FCD116')), (11, rgb('CE1126'))])
    return img


def slovenia():
    # White-blue-red triband; arms on the white/blue boundary toward the
    # hoist: red-edged blue shield, gold stars, white Triglav over waves.
    img = canvas()
    blue = rgb('0033A0')
    hbands(img, [(6, rgb('FFFFFF')), (6, blue), (6, rgb('D8232A'))])
    pmap(img, 6, 3, [
        '.RRRRR.',
        'RBYBYBR',
        'RBBYBBR',
        'RBBBBBR',
        'RBBWBBR',
        'RBWWWBR',
        'RWWWWWR',
        'RBWBWBR',
        '.RRRRR.',
    ], {'R': rgb('D8232A'), 'B': blue, 'Y': rgb('FFDD00'), 'W': rgb('FFFFFF')})
    return img


def south_africa():
    # The pall: red over blue, white-edged green Y converging on a
    # gold-edged black hoist triangle.
    img = canvas()
    rect(img, 0, 0, W - 1, 8, rgb('E03C31'))
    rect(img, 0, 9, W - 1, 17, rgb('001489'))
    poly(img, [(0, 0), (14, 4), (32, 4), (32, 14), (14, 14), (0, 18)],
         rgb('FFFFFF'))
    poly(img, [(0, 2.0), (15, 6), (32, 6), (32, 12), (15, 12), (0, 16.0)],
         rgb('007749'))
    poly(img, [(0, 4.0), (10.5, 9), (0, 14.0)], rgb('FFB81C'))
    poly(img, [(0, 5.5), (8.5, 9), (0, 12.5)], rgb('000000'))
    return img


def spain():
    # Red-yellow-red (1:2:1); simplified arms toward the hoist — crowned
    # quartered shield between the Pillars of Hercules.
    img = canvas()
    hbands(img, [(4, rgb('AA151B')), (10, rgb('F1BF00')), (4, rgb('AA151B'))])
    pmap(img, 5, 4, [
        'Y..YYYY..Y',
        'P.RRRWWW.P',
        'P.RYRWRW.P',
        'P.RRRWWW.P',
        'P.WWWRRR.P',
        'P.WRWRYR.P',
        'P.WWWRRR.P',
        'P..RRRR..P',
        'P...RR...P',
    ], {'R': rgb('CE1126'), 'W': rgb('FFFFFF'), 'Y': rgb('FFD24D'),
        'P': rgb('C9C9C9')})
    return img


def switzerland():
    # Officially square: 18x18 red centered on the transparent canvas,
    # white couped cross with the spec's 7:6 arm proportions.
    img = canvas()
    rect(img, 7, 0, 24, 17, rgb('DA291C'))
    white = rgb('FFFFFF')
    rect(img, 14, 3, 17, 14, white)
    rect(img, 10, 7, 21, 10, white)
    return img


def united_kingdom():
    # Union Flag at full canvas, counterchanged saltires and all.
    img = canvas()
    union_jack(img, 0, 0, W, H, rgb('012169'), rgb('FFFFFF'), rgb('C8102E'),
               cross_w=3.0, cross_r=2.0, sal_w=1.9, sal_r=0.78)
    return img


def uruguay():
    # Nine stripes white-first; white canton with the Sun of May (gold,
    # brown-detailed face per the official sun).
    img = canvas()
    white, blue = rgb('FFFFFF'), rgb('0038A8')
    for i in range(9):
        rect(img, 0, i * 2, W - 1, i * 2 + 1, white if i % 2 == 0 else blue)
    rect(img, 0, 0, 10, 9, white)
    pmap(img, 1, 0, [
        '....G....',
        '.G..G..G.',
        '...GGG...',
        '..GGGGG..',
        'GGGKGKGGG',
        '..GGGGG..',
        '...GGG...',
        '.G..G..G.',
        '....G....',
    ], {'G': rgb('F6B40E'), 'K': rgb('7B3F00')})
    return img


def usa():
    # Thirteen stripes on 18 rows (accumulated rounding, red outermost);
    # canton over seven stripes, star field reduced to a staggered grid.
    img = canvas()
    red, white, blue = rgb('B31942'), rgb('FFFFFF'), rgb('0A3161')
    bounds = [round(i * H / 13) for i in range(14)]
    for i in range(13):
        rect(img, 0, bounds[i], W - 1, bounds[i + 1] - 1,
             red if i % 2 == 0 else white)
    rect(img, 0, 0, 12, 9, blue)
    for y, xs in [(1, (1, 4, 7, 10)), (3, (2, 5, 8, 11)),
                  (5, (1, 4, 7, 10)), (7, (2, 5, 8, 11))]:
        for x in xs:
            P(img, x, y, white)
    return img


def washington():
    # Green field; seal abstracted — gold ring, cream ground, the
    # Washington portrait facing the hoist.
    img = canvas()
    rect(img, 0, 0, W - 1, H - 1, rgb('00843D'))
    disc(img, 16, 9, 3.5, rgb('F2E3C4'))
    ring(img, 16, 9, 4.55, 3.5, rgb('FFC72C'))
    pmap(img, 13, 6, [
        '.WWWW..',
        '.FFFW..',
        '.FFFW..',
        'FFFFW..',
        '.FFW...',
        '.KWKKK.',
        'KKKKKK.',
    ], {'W': rgb('FFFFFF'), 'F': rgb('E8B88A'), 'K': rgb('2B2B2B')})
    return img


FLAGS = {
    'argentina': argentina,
    'australia': australia,
    'austria': austria,
    'bulgaria': bulgaria,
    'california': california,
    'canada': canada,
    'chile': chile,
    'china': china,
    'croatia': croatia,
    'france': france,
    'georgia': georgia,
    'germany': germany,
    'greece': greece,
    'hungary': hungary,
    'india': india,
    'italy': italy,
    'japan': japan,
    'lebanon': lebanon,
    'mexico': mexico,
    'morocco': morocco,
    'new-york': new_york,
    'new-zealand': new_zealand,
    'oregon': oregon,
    'portugal': portugal,
    'romania': romania,
    'slovenia': slovenia,
    'south-africa': south_africa,
    'spain': spain,
    'switzerland': switzerland,
    'united-kingdom': united_kingdom,
    'uruguay': uruguay,
    'usa': usa,
    'washington': washington,
}


def validate(slug, img):
    assert img.size == (W, H), f'{slug}: size {img.size}'
    seen = set()
    for y in range(H):
        for x in range(W):
            r, g, b, a = img.getpixel((x, y))
            assert a in (0, 255), f'{slug}: soft alpha {a} at {x},{y}'
            if a == 0:
                # only Switzerland may have transparency, outside its square
                assert slug == 'switzerland' and not (7 <= x <= 24), \
                    f'{slug}: unexpected transparent pixel at {x},{y}'
            else:
                seen.add((r, g, b))
    assert len(seen) <= 12, f'{slug}: palette too large ({len(seen)})'


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    outdir = sys.argv[1] if len(sys.argv) > 1 else \
        os.path.join(here, '..', 'art', 'flags')
    os.makedirs(outdir, exist_ok=True)
    for slug, fn in sorted(FLAGS.items()):
        img = fn()
        validate(slug, img)
        img.save(os.path.join(outdir, f'{slug}.png'), optimize=True)
    print(f'drew {len(FLAGS)} flags -> {outdir}')


if __name__ == '__main__':
    main()
