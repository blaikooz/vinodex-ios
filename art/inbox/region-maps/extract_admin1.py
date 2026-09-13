#!/usr/bin/env python3
"""
extract_admin1.py — cut a country's admin-1 units out of Natural Earth.

    python3 extract_admin1.py Austria at-states.json
    python3 extract_admin1.py "New Zealand" nz-councils.json --list

Every country config in `countries.py` names an `admin1` file. This is the tool
that makes one, and it was missing: the drop shipped seven extracts with no way
to produce an eighth, so adding a country meant reverse-engineering the shape.

Output is the shape `region_map.py` expects — nothing more:

    {"type": "FeatureCollection", "features": [
       {"type": "Feature",
        "properties": {"name": "Burgenland", "region": null},
        "geometry": {...}} ]}

`region` is Natural Earth's own grouping column where it has one. Italy's
provinces carry it, which is why Italy's config can say {'region': 'Toscana'}
instead of naming ten provinces; France's départements do not.

--list prints the unit names and exits, which is the first thing you want when
writing a config: the names in the file are the only names the config may use,
and they are not always the names you expect (Natural Earth spells Haut-Rhin
"Haute-Rhin", and gives Greece 13 peripheries plus Mount Athos rather than the
regional units a wine atlas would name).
"""
import json, os, sys

import geosrc

HERE = os.path.dirname(os.path.abspath(__file__))


def units_for(admin):
    """Every admin-1 unit Natural Earth files under this country, in file order."""
    feats = geosrc.load('ne-admin1.json')['features']
    out = [f for f in feats if f['properties'].get('admin') == admin]
    if not out:
        have = sorted({f['properties'].get('admin') for f in feats} - {None})
        near = [n for n in have if n.lower().startswith(admin[:3].lower())]
        sys.exit('no admin-1 units for %r.\nDid you mean one of: %s'
                 % (admin, ', '.join(near) or '?'))
    return out


def emit(feats):
    """The shape region_map.py expects — name, region, geometry, nothing else."""
    return {'type': 'FeatureCollection', 'features': [
        {'type': 'Feature',
         'properties': {'name': f['properties']['name'],
                        'region': f['properties'].get('region')},
         'geometry': f['geometry']} for f in feats]}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) < 1:
        sys.exit(__doc__)
    admin = args[0]
    feats = units_for(admin)

    types = sorted({f['properties'].get('type_en') or '?' for f in feats})
    regions = sorted({f['properties'].get('region') for f in feats} - {None})
    print('%s: %d units, type_en %s, region column %s'
          % (admin, len(feats), types,
             '%d values' % len(regions) if regions else 'absent'))

    if '--list' in sys.argv:
        for f in sorted(feats, key=lambda f: f['properties']['name']):
            p = f['properties']
            print('   %-34s %-22s %s' % (p['name'], p.get('type_en', ''),
                                         p.get('region') or ''))
        return

    if len(args) < 2:
        sys.exit('give an output filename, or pass --list')
    path = os.path.join(HERE, args[1])
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(emit(feats), fh, ensure_ascii=False, separators=(',', ':'))
    print('wrote %s  (%d KB)' % (args[1], os.path.getsize(path) // 1024))
    print('names are the only strings countries.py may use — run --list to see them')
    print('every unit is in the file; the ones the country should not be framed by\n'
          'go in the config\'s `exclude`, not in a hand-edit of this file. France\n'
          'shipped metropolitan-only once and a re-extract would have reframed the\n'
          'map from the Channel to Réunion with no assert to catch it.')


if __name__ == '__main__':
    main()
