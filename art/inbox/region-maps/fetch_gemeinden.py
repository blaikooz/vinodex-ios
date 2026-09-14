#!/usr/bin/env python3
"""
fetch_gemeinden.py — pull the Austrian Gemeinden a child region needs.

    python3 fetch_gemeinden.py wachau
    python3 fetch_gemeinden.py --list 313      # every Gemeinde in Bezirk 313

Writes/updates `at-gemeinden.json` in the same shape as the admin-1 extracts
(`{name, region, geometry}`) plus the Gemeindekennziffer, so `region_map.py`
reads it exactly as it reads `fr-communes.json` for Sauternes.

WHY A SEPARATE SOURCE. Natural Earth admin-1 stops at the Bundesland: Austria is
nine units and Niederösterreich is one of them. There is no admin-2 layer, so
the Wachau — 8 Gemeinden inside Niederösterreich — is not expressible above this
level. That is what the second index plane is for.

THE BOUNDARY IS THE LEGAL ONE, not an approximation. This was blocked for most
of the campaign on exactly that point: nothing reachable said WHICH Gemeinden
are the Wachau, and a wrong boundary is worse than an absent one because nothing
can detect it. It is unblocked now because the delimitation is in statute.

  Weingesetz 2009, § 21 Abs. 3 Z 1 lit. k defines the Weinbaugebiet Wachau as
  "die Gemeinden Aggsbach, Bergern im Dunkelsteinerwald, Dürnstein, Mautern an
  der Donau, Mühldorf, Rossatz-Arnsdorf, Spitz und Weißenkirchen in der Wachau".

  The DAC-Verordnung "Wachau" (BGBl. II Nr. 200/2020, as amended by BGBl. II Nr.
  191/2023) does NOT redraw that area — it defers to the Weinbaugebiet and only
  adds the 22 Ortsnamen permitted on a label. So the DAC boundary and the
  Weinbaugebiet boundary are the same boundary, and this is it.

SOURCE AND LICENCE. github.com/ginseng666/GeoJSON-TopoJSON-Austria, the 2021
municipality file, CC BY 4.0 (Flooh Perlot), derived from Statistik Austria's
`OGDEXT_GEM_1`, itself CC BY 4.0. Attribution is required — unlike Natural
Earth, which is public domain — so it is recorded in the emitted file's
`source` field, which travels with the geometry.

  Datenquelle: Statistik Austria - data.statistik.gv.at

WHY THE DERIVATIVE AND NOT THE REGISTER. `data.statistik.gv.at` is the primary
source and its WFS is the grundstücksgenau original. It is not reachable from
either machine this session can run code on — the egress proxy refuses
`www.statistik.gv.at:443` in both the cloud container and the desktop VM. So the
committed geometry is the least-simplified public mirror, and the question that
matters is whether the generalisation is visible on the raster it feeds:

  Austria renders at 30.70 px/deg with x_factor 0.675, so one index cell is
  3.57 km. The eight Gemeinden span 6.9 x 4.8 cells and cover ~15 of them. The
  mirror's coarsest retained detail is two orders of magnitude below one cell.
  Sauternes shipped at 5 cells and Châteauneuf at 4; 15 is the largest child on
  the second plane.

If the register ever becomes reachable, re-run against it and the raster should
not move. If it does move, the mirror was wrong and this note is where to start.

MATCH BY GEMEINDEKENNZIFFER, NOT BY NAME. Austria has homonyms across
Bundesländer and one of them is in this very list: a name-match on the eight
statutory names returns NINE features, because Mühldorf is also a Gemeinde in
Kärnten (iso 20624, Bezirk Spittal an der Drau). It sits 160 km southwest, and
taking it would have stretched the child's bounding box from the Danube to
Carinthia with no assert in the pipeline to catch it — the same shape of failure
as France's five overseas départements. The eight Wachau Gemeinden are all in
Bezirk 313 (Krems-Land) and the iso codes below are the join key. The names are
carried into the extract only so `countries.py` can stay readable.
"""
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'at-gemeinden.json')

# The 2021 municipality file. "95" is the LEAST simplified of the three the
# mirror publishes, which is the opposite of what the number looks like: 95 is
# 214,945 vertices nationally, 99.5 is 34,552 and 99.9 is 16,499. On the 99.9
# file Spitz is a heptagon. Do not "upgrade" this to a higher number.
URL = ('https://raw.githubusercontent.com/ginseng666/GeoJSON-TopoJSON-Austria/'
       'master/2021/simplified-95/gemeinden_95_geo.json')

SOURCE = ('Statistik Austria - data.statistik.gv.at (OGDEXT_GEM_1, 2021) via '
          'ginseng666/GeoJSON-TopoJSON-Austria, CC BY 4.0')

# Gemeindekennziffer -> name, straight out of Weingesetz 2009 § 21 Abs. 3 Z 1 k.
# Adding a child means adding a block here with its own citation, not editing
# this one.
CHILDREN = {
    'wachau': {
        'law': 'Weingesetz 2009 § 21 Abs. 3 Z 1 lit. k (Weinbaugebiet Wachau); '
               'DAC-Verordnung Wachau, BGBl. II Nr. 200/2020 idF 191/2023',
        'units': {
            '31301': 'Aggsbach',
            '31303': 'Bergern im Dunkelsteinerwald',
            '31304': 'Dürnstein',
            '31327': 'Mautern an der Donau',
            '31330': 'Mühldorf',
            '31338': 'Rossatz-Arnsdorf',
            '31344': 'Spitz',
            '31351': 'Weißenkirchen in der Wachau',
        },
    },
}


def fetch():
    with urllib.request.urlopen(URL, timeout=180) as r:
        return json.load(r)['features']


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    feats = fetch()
    print('%d Gemeinden in the 2021 file' % len(feats))

    if '--list' in sys.argv:
        pre = args[0] if args else ''
        for f in sorted(feats, key=lambda f: f['properties']['iso']):
            p = f['properties']
            if p['iso'].startswith(pre):
                print('   %-8s %s' % (p['iso'], p['name']))
        return

    if not args:
        sys.exit('name a child: %s' % ', '.join(sorted(CHILDREN)))
    child = args[0]
    if child not in CHILDREN:
        sys.exit('no such child %r — known: %s' % (child, ', '.join(sorted(CHILDREN))))
    want = CHILDREN[child]['units']

    by = {f['properties']['iso']: f for f in feats}
    missing = [k for k in want if k not in by]
    assert not missing, 'Gemeindekennziffer not in the 2021 file: %s' % missing
    wrong = [(k, by[k]['properties']['name']) for k, n in want.items()
             if by[k]['properties']['name'] != n]
    assert not wrong, (
        'the source names these differently than the statute does: %s\n'
        'A Gemeinde may have been merged or renamed since January 2021. Do NOT '
        'relax this assert — check the current Weingesetz text first.' % wrong)

    have = {}
    if os.path.exists(OUT):
        have = {f['properties']['iso']: f
                for f in json.load(open(OUT))['features']}
    for k, n in want.items():
        have[k] = {'type': 'Feature',
                   'properties': {'name': n, 'region': None, 'iso': k,
                                  'child': child},
                   'geometry': by[k]['geometry']}
    out = {'type': 'FeatureCollection', 'source': SOURCE,
           'features': [have[k] for k in sorted(have)]}
    with open(OUT, 'w', encoding='utf-8') as fh:
        json.dump(out, fh, ensure_ascii=False, separators=(',', ':'))
    print('wrote at-gemeinden.json — %d Gemeinden, %d KB'
          % (len(out['features']), os.path.getsize(OUT) // 1024))
    print('   %s' % CHILDREN[child]['law'])
    for f in out['features']:
        print('   %-8s %s' % (f['properties']['iso'], f['properties']['name']))


if __name__ == '__main__':
    main()
