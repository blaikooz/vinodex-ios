"""Fill assignment: a unique colour per region, placed so neighbours look apart.

Two requirements pull in different directions.

  1. The runtime identifies a region by reading the pixel under the tap, so every
     region's fill must be EXACTLY unique. No sharing, however far apart two
     regions sit.
  2. A person has to tell adjacent regions apart at a glance. With 21 regions on
     one country that is the binding constraint, and hand-picking 21 hues that
     all hold up next to each other is exactly the job that produced two
     indistinguishable reds in the France pilot.

So the colours are generated, not authored, and the assignment is computed from
the adjacency of the rendered masks: build a pool of well-separated colours, then
permute it until the least-separated pair of TOUCHING regions is as far apart as
it can get. Regions that never touch are free to be similar, which is what makes
21 possible at all.

`assign(masks, authored)` returns {stem: (r, g, b)}. If `authored` is given it is
returned as-is — France's palette was hand-tuned and reviewed, and there is no
reason to churn it.
"""
import colorsys
import numpy as np

# Seven hues at roughly even spacing, each in three value/chroma bands. Muted on
# purpose: these sit on stone and sea, next to a near-black coastline.
HUES = [0.97, 0.055, 0.12, 0.28, 0.45, 0.57, 0.78]
# Four bands, not three: three gave a hard ceiling of 21, which Italy hits
# exactly today and which the sub-appellation work would blow through the first
# time a country splits a region in two.
BANDS = [(0.34, 0.50), (0.47, 0.44), (0.60, 0.38), (0.72, 0.32)]


def pool(n):
    out = []
    for li, (l, s) in enumerate(BANDS):
        for h in HUES:
            r, g, b = colorsys.hls_to_rgb(h, l, s)
            out.append((int(round(r * 255)), int(round(g * 255)), int(round(b * 255))))
    assert len(set(out)) == len(out), 'pool has duplicates'
    assert len(out) >= n, 'pool of %d cannot cover %d regions' % (len(out), n)
    return out


def _lab(rgb):
    """sRGB -> CIELab, so distance means something to an eye."""
    c = np.array(rgb, float) / 255
    c = np.where(c > .04045, ((c + .055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[.4124, .3576, .1805], [.2126, .7152, .0722], [.0193, .1192, .9505]])
    xyz = m @ c / np.array([.95047, 1.0, 1.08883])
    f = np.where(xyz > .008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])


def adjacency(masks):
    """Which regions touch which, read off the rendered masks.

    scipy is imported here rather than at module scope on purpose:
    `install_globe.py` needs `brighten` and nothing else, runs on machines that
    have numpy and PIL but not scipy, and a top-level import turned a working
    installer into a ModuleNotFoundError. A module should cost what the caller
    uses.
    """
    from scipy import ndimage
    stems = list(masks)
    idx = {s: i for i, s in enumerate(stems)}
    grown = {s: ndimage.binary_dilation(m, iterations=2) for s, m in masks.items()}
    pairs = set()
    for i, a in enumerate(stems):
        for b in stems[i + 1:]:
            if (grown[a] & masks[b]).any():
                pairs.add((idx[a], idx[b]))
    return stems, sorted(pairs)


def _hex(rgb):
    return '#%02X%02X%02X' % tuple(rgb)


def _unhex(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def candidates(step_h=24, bands=None):
    """A dense grid of muted colours to draw from when the pool is too small.

    `pool()` gives 28, which is enough for one country's regions and not enough
    to place more countries on a globe that already holds thirty authored fills
    nobody wants moved.
    """
    out = []
    for l, s in (bands or BANDS):
        for i in range(step_h):
            r, g, b = colorsys.hls_to_rgb(i / step_h, l, s)
            out.append((int(round(r * 255)), int(round(g * 255)), int(round(b * 255))))
    return sorted(set(out))


def brighten(rgb):
    """What `install_globe.py` does to a country fill before it reaches glass.

    Lives here, not there, because the colours have to be CHOSEN in this space.
    Measured in the authored space the country fills clear ΔE 15; measured after
    this function they do not, because `v * 2.05` clips at 1.0 and every fill
    above v≈0.49 lands on the same value. Two colours a spreadsheet calls far
    apart arrive on the sphere as one. (The thirty authored fills already suffer
    from this: portugal and united-kingdom are ΔE 25.5 apart in the manifest and
    2.6 on glass. Not fixed here — fixing it restyles the globe.)

    Lifted in HSV rather than blended toward white: blending raises value and
    drops saturation together, which is how the first pass came out pastel, and
    thirty washed colours are harder to tell apart than thirty muted ones.
    """
    h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    v = min(1.0, v * 2.05)
    s = min(1.0, s * 1.18)
    return tuple(int(round(c * 255)) for c in colorsys.hsv_to_rgb(h, s, v))


def extend(adjacency_pairs, fixed, new, seed=11, transform=None):
    """Colour `new` keys without moving any colour in `fixed`.

    `fixed` is {key: '#RRGGBB'} that must not change — thirty authored country
    fills, in the case this was written for. `adjacency_pairs` is a set of
    frozenset({key, key}): the pairs that must look unlike each other. Returns
    {key: '#RRGGBB'} for `new`.

    Greedy farthest-point against each key's already-coloured conflicts, then a
    hill-climb over the new keys only.

    **The caller chooses the conflict graph and it is not always adjacency.** A
    flat map shows one country, so only touching regions have to be told apart.
    A globe shows a hemisphere, and two weaker rules were tried there and
    measured before the complete graph: adjacency put Slovakia and Turkey at
    ΔE 6.6, and a 40-degree centroid window put China and Turkey at 4.0. Any
    proximity threshold has an outside, and on a sphere the outside is visible.
    """
    # `transform` is what happens to a colour between here and the screen. Pass
    # it or the numbers printed below are about a file, not about a picture.
    t = transform or (lambda c: c)
    cand = [c for c in candidates() if _hex(c) not in set(fixed.values())]
    labs = {c: _lab(t(c)) for c in cand}
    flab = {k: _lab(t(_unhex(v))) for k, v in fixed.items()}
    nbr = {k: set() for k in list(fixed) + list(new)}
    for pair in adjacency_pairs:
        a, b = tuple(pair)
        if a in nbr and b in nbr:
            nbr[a].add(b)
            nbr[b].add(a)

    chosen = {}

    def lab_of(k):
        return flab[k] if k in flab else labs[chosen[k]]

    def score(k, c):
        near = [n for n in nbr[k] if n in flab or n in chosen]
        if not near:
            return 1e9
        return min(float(np.linalg.norm(labs[c] - lab_of(n))) for n in near)

    # Most-constrained first: a key with five coloured neighbours has the least
    # room, so it picks before a key with one.
    order = sorted(new, key=lambda k: -len(nbr[k]))
    for k in order:
        free = [c for c in cand if c not in chosen.values()]
        chosen[k] = max(free, key=lambda c: score(k, c))

    rng = np.random.default_rng(seed)
    worst = lambda: min((score(k, chosen[k]) for k in new), default=1e9)
    best = worst()
    for _ in range(400):
        k = new[int(rng.integers(len(new)))]
        c = cand[int(rng.integers(len(cand)))]
        if c in chosen.values():
            continue
        old, chosen[k] = chosen[k], c
        s = worst()
        if s > best:
            best = s
        else:
            chosen[k] = old
    print('palette.extend: %d new keys, worst adjacent ΔE = %.1f' % (len(new), best))
    return {k: _hex(v) for k, v in chosen.items()}


def assign(masks, authored=None, seed=7):
    if authored:
        return {s: tuple(authored[s]) for s in masks}
    stems, pairs = adjacency(masks)
    cols = pool(len(stems))
    labs = np.array([_lab(c) for c in cols])
    n, m = len(stems), len(cols)

    def worst(order):
        """The least-separated touching pair under this assignment."""
        return min(np.linalg.norm(labs[order[a]] - labs[order[b]]) for a, b in pairs) \
            if pairs else 1e9

    # `order` picks WHICH colours, not just their arrangement. Taking the first
    # n of the pool is what made Austria's three regions come out as three
    # browns: with n < pool the first n are all one band. A country with three
    # regions should get three colours from opposite corners of the pool.
    rng = np.random.default_rng(seed)
    best, best_score = None, -1
    for _ in range(24):                       # restarts, then hill-climb each
        order = rng.permutation(m)[:n]
        score = worst(order)
        improved = True
        while improved:
            improved = False
            for i in range(n):                # swap two stems' colours
                for j in range(i + 1, n):
                    order[i], order[j] = order[j], order[i]
                    s2 = worst(order)
                    if s2 > score:
                        score, improved = s2, True
                    else:
                        order[i], order[j] = order[j], order[i]
            for i in range(n):                # or bring in an unused colour
                for c in range(m):
                    if c in order:
                        continue
                    old, order[i] = order[i], c
                    s2 = worst(order)
                    if s2 > score:
                        score, improved = s2, True
                    else:
                        order[i] = old
        if score > best_score:
            best, best_score = order.copy(), score
    print('palette: %d regions, %d touching pairs, worst adjacent ΔE = %.1f'
          % (n, len(pairs), best_score))
    return {s: cols[best[i]] for i, s in enumerate(stems)}
