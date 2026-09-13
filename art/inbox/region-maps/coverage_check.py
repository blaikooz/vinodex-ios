#!/usr/bin/env python3
"""
coverage_check.py — one painted area per catalog region, measured.

    python3 coverage_check.py                # every country with a rendered map
    python3 coverage_check.py italy spain    # just these
    python3 coverage_check.py --strict       # exit 1 if any area is dead

Ruling 2 of the expansion plan says the map should be a direct visual index of
the encyclopedia: one painted area, one catalog region. Nothing enforced it, and
nothing could tell you how far off it was without a person counting. That is how
twenty-five dead areas accumulated — a painted area with no entry behind it
fails no build, renders correctly, and is invisible until somebody taps it and
gets "NO CATALOG ENTRY HERE YET".

Reads `out/<c>/<c>-region-index.json`, which `region_check.py` generates from the
catalog pins, so this asks the same question the app asks and needs no access to
`shared/`. Two failure directions, opposite causes:

  DEAD    a painted stem with no catalog id     -> write the entry, or drop the area
  SHARED  one stem answering for several ids    -> split the area, or a second
                                                   index plane where no admin
                                                   unit isolates the child

Not fatal by default. Every number it prints today is a known debt with a plan
attached, and a gate that is red on arrival gets switched off. Run it with
--strict in CI once the debt is paid, so the twenty-six-th cannot appear.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')


def countries(argv):
    named = [a for a in argv if not a.startswith('-')]
    if named:
        return named
    return sorted(d for d in os.listdir(OUT)
                  if os.path.isdir(os.path.join(OUT, d))
                  and os.path.exists(os.path.join(OUT, d, '%s-region-index.json' % d)))


def main():
    strict = '--strict' in sys.argv
    dead_total = shared_total = areas_total = 0
    dead_rows, shared_rows = [], []

    for c in countries(sys.argv[1:]):
        p = os.path.join(OUT, c, '%s-region-index.json' % c)
        if not os.path.exists(p):
            print('%-12s no region index — run region_check.py %s' % (c, c))
            continue
        by_stem = json.load(open(p))['byStem']
        dead = sorted(s for s, ids in by_stem.items() if not ids)
        shared = sorted((s, ids) for s, ids in by_stem.items() if len(ids) > 1)
        areas_total += len(by_stem)
        dead_total += len(dead)
        shared_total += sum(len(i) - 1 for _, i in shared)
        print('%-12s %2d areas   %2d dead   %2d areas answering for %d ids'
              % (c, len(by_stem), len(dead), len(shared),
                 sum(len(i) for _, i in shared)))
        for s in dead:
            dead_rows.append((c, s))
        for s, ids in shared:
            shared_rows.append((c, s, ids))

    if dead_rows:
        print('\nDEAD — painted, no catalog entry behind it:')
        for c, s in dead_rows:
            print('   %-12s %s' % (c, s))
    if shared_rows:
        print('\nSHARED — one area answering for several catalog rows:')
        for c, s, ids in shared_rows:
            print('   %-12s %-16s %s' % (c, s, ', '.join(ids)))

    print('\n%d painted areas: %d dead, %d catalog rows without an area of their own'
          % (areas_total, dead_total, shared_total))
    if strict and (dead_total or shared_total):
        print('--strict: failing.')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
