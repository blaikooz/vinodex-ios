#!/usr/bin/env python3
"""
halo_check.py — how much white halo is still on the shipped art.

    python3 halo_check.py                    # every bundled set
    python3 halo_check.py StyleArt FlavorArt # just these
    python3 halo_check.py --files StyleArt   # per-file, worst first

The metric is `whiteground-audit.md`'s, unchanged so the numbers stay
comparable: for every opaque pixel (a >= 128) with a transparent 4-neighbour,
count it near-white when min(r, g, b) >= 230. The fraction of edge pixels that
are near-white is the score.

Baseline: a magenta-keyed set scores ~0.000, because this art style has a
near-black cel outline and there is nothing white on a clean silhouette edge.
Above ~0.10 is halo — a white ground that survived `strip_background`'s
border-flood fallback as a one-pixel fringe, invisible on white and obvious on
the app's dark CRT ground.

The audit measured this once, by hand, on 2026-09-07, and the campaign plan was
written from that snapshot. The snapshot is now a week old and three releases
back. This exists so the next person asks the repo instead of the document —
same reason `coverage_check.py` exists.

A high score is not automatically halo: a genuinely white subject that touches
its own silhouette (a white wine in a glass, a chalk soil) scores high and is
correct. Use --files and look at the names before regenerating anything.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
RES = os.path.join(REPO, 'Sources')

NEAR_WHITE = 230
OPAQUE = 128
HALO = 0.10


def score(path):
    """Fraction of silhouette-edge pixels that are near-white, and the count."""
    im = Image.open(path).convert('RGBA')
    a = np.array(im)
    op = a[:, :, 3] >= OPAQUE
    if not op.any():
        return None, 0
    # A 4-neighbour is transparent -> this opaque pixel is on the silhouette.
    pad = np.pad(op, 1, constant_values=False)
    edge = op & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    n = int(edge.sum())
    if not n:
        return None, 0
    white = (a[:, :, :3].min(axis=2) >= NEAR_WHITE) & edge
    return int(white.sum()) / n, n


def sets():
    """Bundled art sets: any Resources dir holding PNGs, keyed by its name."""
    out = {}
    for root, _dirs, files in os.walk(RES):
        pngs = [f for f in files if f.lower().endswith('.png')]
        if pngs and os.sep + 'Resources' + os.sep in root + os.sep:
            out.setdefault(os.path.basename(root), []).extend(
                os.path.join(root, f) for f in sorted(pngs))
    return out


def main():
    argv = sys.argv[1:]
    per_file = '--files' in argv
    named = [a for a in argv if not a.startswith('-')]
    found = sets()
    if not found:
        sys.exit('no bundled PNGs under %s — run this from inside the repo.' % RES)
    rows = []
    for name in sorted(found):
        if named and name not in named:
            continue
        scored = [(score(p)[0], os.path.basename(p)) for p in found[name]]
        scored = [(s, f) for s, f in scored if s is not None]
        if not scored:
            continue
        vals = [s for s, _ in scored]
        over = [(s, f) for s, f in scored if s > HALO]
        rows.append((name, len(scored), len(over),
                     sum(vals) / len(vals), max(vals), sorted(over, reverse=True)))

    print('%-18s %5s %7s %7s %7s' % ('set', 'files', 'over.10', 'mean', 'worst'))
    for name, n, o, mean, worst, _ in sorted(rows, key=lambda r: -r[3]):
        flag = '  <-- halo' if mean > HALO else ''
        print('%-18s %5d %7d %7.3f %7.3f%s' % (name, n, o, mean, worst, flag))

    if per_file:
        for name, _n, _o, _m, _w, over in rows:
            if not over:
                continue
            print('\n%s — %d over %.2f, worst first:' % (name, len(over), HALO))
            for s, f in over:
                print('   %.3f  %s' % (s, f))

    total = sum(r[1] for r in rows)
    bad = sum(r[2] for r in rows)
    print('\n%d bundled files, %d over %.2f' % (total, bad, HALO))


if __name__ == '__main__':
    main()
