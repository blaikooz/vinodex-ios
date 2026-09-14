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


# Deliberate overrides of Natural Earth's admin column, ruled by the maintainer.
# `{subject: [(natural earth's admin, unit name), ...]}` — units Natural Earth
# files under one country that this atlas files under another.
#
# There is exactly one entry and it is not a bug in the source: NE 1:10m files
# both Crimean units under Russia in admin-1 AND puts the peninsula inside
# Russia's admin-0 polygon (probed at Simferopol, Sevastopol, Massandra, Kerch
# and Yevpatoria — all five answer 'Russia' in both layers). Ukraine's own
# country-outline art under `entries/countries/` already draws Crimea, so
# without this the encyclopedia disagreed with itself: the outline included the
# peninsula and the map did not.
#
# The bar for adding a row here is a maintainer ruling recorded in horizon-md,
# not a judgement made in this file. The Golan Heights is NOT such a case and
# must not be added: Natural Earth already files the Israeli-administered Golan
# under Israel, inside HaZafon, so it needs a split in `countries.py` and no
# override at all. Check what the source does before assuming it needs one.
ANNEX = {
    'Ukraine': [('Russia', 'Crimea'), ('Russia', 'Sevastopol')],
}


def units_for(admin):
    """Every admin-1 unit Natural Earth files under this country, in file order.

    Plus any unit `ANNEX` reassigns to it, appended after the source's own so
    the file stays a pure function of (source, ANNEX) and `verify_extracts.py`
    can still reproduce it byte for byte.
    """
    feats = geosrc.load('ne-admin1.json')['features']
    out = [f for f in feats if f['properties'].get('admin') == admin]
    for donor, unit in ANNEX.get(admin, ()):
        got = [f for f in feats
               if f['properties'].get('admin') == donor
               and f['properties'].get('name') == unit]
        assert len(got) == 1, \
            'ANNEX %s <- %s/%s matched %d units' % (admin, donor, unit, len(got))
        out += got
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
