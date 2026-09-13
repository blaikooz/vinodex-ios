#!/usr/bin/env python3
"""
verify_extracts.py — every committed admin-1 extract is reproducible from source.

    python3 verify_extracts.py

Each country config names an `admin1` file. Those files are cuts of
`ne-admin1.json`, and nothing was checking that they still are. This regenerates
each one from source and compares bytes.

Why it exists: `fr-departements.json` held 96 units where a fresh extract gives
101. Natural Earth files Guadeloupe, Guyane française, La Réunion, Martinique and
Mayotte under admin='France', and the committed file had been cut down by hand at
some point before `extract_admin1.py` existed. Geometry on all 96 shared units was
byte-identical, so nothing looked wrong — but the next person to regenerate the
file would have framed the France map on a bounding box spanning the Channel to
Réunion, and no assert in the pipeline fires on that. The map just comes out as a
speck in an ocean.

The fix was not to keep the hand-cut file. It was to put the five names in
France's `exclude` — where the pipeline can see the decision — regenerate the
extract in full, and confirm all 146 rendered outputs stayed byte-identical.
This script is what stops the hand-cut version coming back.

A FAIL here is not necessarily a bug in the extract. It means the committed file
and the source disagree, and you have to say which one is right:

  - extra units in the source     -> name them in the config's `exclude`
  - a different Natural Earth release -> re-verify every render before accepting
  - a hand-edit                   -> move the intent into the config
"""
import json
import sys

from countries import COUNTRIES
from extract_admin1 import emit, units_for

# admin1 filename -> the Natural Earth admin name it is cut from. Kept here
# rather than in countries.py because it is a property of the source, not of the
# wine geography, and countries.py is meant to stay a table anyone can read.
ADMIN = {
    'fr-departements.json': 'France',
    'it-provinces.json':    'Italy',
    'es-provinces.json':    'Spain',
    'pt-districts.json':    'Portugal',
    'ar-provinces.json':    'Argentina',
    'cl-regions.json':      'Chile',
    'nz-councils.json':     'New Zealand',
    'at-states.json':       'Austria',
    'cn-provinces.json':    'China',
}


def main():
    bad = 0
    seen = set()
    for name, cfg in COUNTRIES.items():
        fn = cfg['admin1']
        if fn in seen:
            continue
        seen.add(fn)
        if fn not in ADMIN:
            print('%-22s SKIP  no source admin recorded in verify_extracts.ADMIN' % fn)
            bad += 1
            continue
        fresh = json.dumps(emit(units_for(ADMIN[fn])),
                           ensure_ascii=False, separators=(',', ':')).encode()
        with open(fn, 'rb') as fh:
            have = fh.read()
        if fresh == have:
            n = len(json.loads(have)['features'])
            drop = len(set(cfg.get('exclude', ())))
            print('%-22s ok    %3d units, %d excluded by config' % (fn, n, drop))
            continue
        bad += 1
        a = {f['properties']['name'] for f in json.loads(fresh)['features']}
        b = {f['properties']['name'] for f in json.loads(have)['features']}
        print('%-22s FAIL  source %d units, committed %d' % (fn, len(a), len(b)))
        if a - b:
            print('%-22s       only in source:    %s' % ('', ', '.join(sorted(a - b))))
        if b - a:
            print('%-22s       only in committed: %s' % ('', ', '.join(sorted(b - a))))
        if a == b:
            print('%-22s       same units, different bytes — geometry or property '
                  'shape moved' % '')
    print('\n%d of %d extracts reproduce from source' % (len(seen) - bad, len(seen)))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
