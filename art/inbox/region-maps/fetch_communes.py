#!/usr/bin/env python3
"""
fetch_communes.py — pull the French communes a child region needs.

    python3 fetch_communes.py 84 Châteauneuf-du-Pape
    python3 fetch_communes.py 33 Sauternes Bommes Fargues Preignac Barsac
    python3 fetch_communes.py 84 --list          # every commune in the département

Writes/updates `fr-communes.json`: only the communes actually named by a
`children` entry in `countries.py`, in the same shape as the admin-1 extracts
(`{name, region, geometry}`), so `region_map.py` reads them the same way.

WHY A SEPARATE SOURCE. Natural Earth admin-1 stops at the département, and the
second index plane exists precisely for regions no admin-1 unit isolates.
Châteauneuf-du-Pape is one commune inside the Vaucluse; Sauternes is five inside
the Gironde. Neither is expressible above this level.

SOURCE AND LICENCE. github.com/gregoiredavid/france-geojson, built from IGN
(AdminExpress) and INSEE and published under the Licence Ouverte / Open Licence
(Etalab). That is a real register with a citable licence, which is what ruling 3
of the expansion plan asks for. Only the named communes are committed, so the
repo carries kilobytes rather than the 100 MB national file.

WHAT THIS DOES NOT GIVE YOU. A commune is not an appellation. Sauternes AOC is
five whole communes and composing it is exact; Châteauneuf-du-Pape AOC spills
into parts of Bédarrides, Courthézon, Orange and Sorgues, so the commune alone
UNDER-covers it. Under-covering is the right way to be wrong here: a tap inside
answers Châteauneuf, a tap in the spill answers Rhône, and Rhône is true. Taking
all five communes would over-cover and paint Côtes du Rhône vineyards as
Châteauneuf, which is a lie rather than a silence. Every such choice goes in the
`children` block next to the units that make it.
"""
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'fr-communes.json')
URL = ('https://raw.githubusercontent.com/gregoiredavid/france-geojson/master/'
       'departements/%s/communes-%s.geojson')
DEPT = {'84': '84-vaucluse', '33': '33-gironde', '21': '21-cote-d-or',
        '89': '89-yonne', '81': '81-tarn', '46': '46-lot',
        '64': '64-pyrenees-atlantiques'}


def fetch(code):
    slug = DEPT.get(code)
    if not slug:
        sys.exit('no slug for département %r — add it to DEPT (the repo names '
                 'them like "84-vaucluse")' % code)
    with urllib.request.urlopen(URL % (slug, slug), timeout=60) as r:
        return json.load(r)['features']


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if not args:
        sys.exit(__doc__)
    code, wanted = args[0], args[1:]
    feats = fetch(code)
    print('%s: %d communes from %s' % (code, len(feats), DEPT[code]))

    if '--list' in sys.argv:
        for f in sorted(feats, key=lambda f: f['properties']['nom']):
            print('   %-38s %s' % (f['properties']['nom'], f['properties']['code']))
        return

    if not wanted:
        sys.exit('name the communes to keep, or pass --list')
    by = {f['properties']['nom']: f for f in feats}
    missing = [w for w in wanted if w not in by]
    if missing:
        import difflib
        for m in missing:
            print('  %r not found. Did you mean: %s'
                  % (m, ', '.join(difflib.get_close_matches(m, by, 3)) or '?'))
        sys.exit('names must match the source exactly — run --list')

    have = {}
    if os.path.exists(OUT):
        have = {f['properties']['name']: f
                for f in json.load(open(OUT))['features']}
    for w in wanted:
        have[w] = {'type': 'Feature',
                   'properties': {'name': w, 'region': None,
                                  'insee': by[w]['properties']['code'],
                                  'dept': code},
                   'geometry': by[w]['geometry']}
    out = {'type': 'FeatureCollection',
           'source': 'IGN AdminExpress / INSEE via gregoiredavid/france-geojson, '
                     'Licence Ouverte (Etalab)',
           'features': [have[k] for k in sorted(have)]}
    with open(OUT, 'w', encoding='utf-8') as fh:
        json.dump(out, fh, ensure_ascii=False, separators=(',', ':'))
    print('wrote fr-communes.json — %d communes, %d KB'
          % (len(out['features']), os.path.getsize(OUT) // 1024))
    for f in out['features']:
        print('   %-30s %s' % (f['properties']['name'], f['properties']['insee']))


if __name__ == '__main__':
    main()
