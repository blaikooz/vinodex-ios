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
from scipy import ndimage

# Seven hues at roughly even spacing, each in three value/chroma bands. Muted on
# purpose: these sit on stone and sea, next to a near-black coastline.
HUES = [0.97, 0.055, 0.12, 0.28, 0.45, 0.57, 0.78]
BANDS = [(0.34, 0.50), (0.50, 0.42), (0.66, 0.34)]   # (lightness, saturation)


def pool(n):
    out = []
    for li, (l, s) in enumerate(BANDS):
        for h in HUES:
            r, g, b = colorsys.hls_to_rgb(h, l, s)
            out.append((int(round(r * 255)), int(round(g * 255)), int(round(b * 255))))
    assert len(set(out)) == len(out), 'pool has duplicates'
    assert len(out) >= n, 'pool of %d cannot cover %d regions' % (len(out), n)
    return out[:n] if len(out) == n else out


def _lab(rgb):
    """sRGB -> CIELab, so distance means something to an eye."""
    c = np.array(rgb, float) / 255
    c = np.where(c > .04045, ((c + .055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[.4124, .3576, .1805], [.2126, .7152, .0722], [.0193, .1192, .9505]])
    xyz = m @ c / np.array([.95047, 1.0, 1.08883])
    f = np.where(xyz > .008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])


def adjacency(masks):
    """Which regions touch which, read off the rendered masks."""
    stems = list(masks)
    idx = {s: i for i, s in enumerate(stems)}
    grown = {s: ndimage.binary_dilation(m, iterations=2) for s, m in masks.items()}
    pairs = set()
    for i, a in enumerate(stems):
        for b in stems[i + 1:]:
            if (grown[a] & masks[b]).any():
                pairs.add((idx[a], idx[b]))
    return stems, sorted(pairs)


def assign(masks, authored=None, seed=7):
    if authored:
        return {s: tuple(authored[s]) for s in masks}
    stems, pairs = adjacency(masks)
    cols = pool(len(stems))
    labs = np.array([_lab(c) for c in cols])
    n = len(stems)

    def worst(order):
        """The least-separated touching pair under this assignment."""
        return min(np.linalg.norm(labs[order[a]] - labs[order[b]]) for a, b in pairs) \
            if pairs else 1e9

    rng = np.random.default_rng(seed)
    best, best_score = None, -1
    for _ in range(24):                       # restarts, then hill-climb each
        order = rng.permutation(n)
        score = worst(order)
        improved = True
        while improved:
            improved = False
            for i in range(n):
                for j in range(i + 1, n):
                    order[i], order[j] = order[j], order[i]
                    s2 = worst(order)
                    if s2 > score:
                        score, improved = s2, True
                    else:
                        order[i], order[j] = order[j], order[i]
        if score > best_score:
            best, best_score = order.copy(), score
    print('palette: %d regions, %d touching pairs, worst adjacent ΔE = %.1f'
          % (n, len(pairs), best_score))
    return {s: cols[best[i]] for i, s in enumerate(stems)}
