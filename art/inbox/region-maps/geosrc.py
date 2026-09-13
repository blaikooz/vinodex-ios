"""Opening the Natural Earth sources, wherever they happen to be on disk.

Two files sit behind everything in this folder, both Natural Earth 1:10m, both
public domain:

    ne.json[.gz]         admin-0, 258 countries — the world backdrop and the globe
    ne-admin1.json[.gz]  admin-1, 4596 units    — every country's regions

They are committed gzipped because uncompressed they are 13 MB and 39 MB and the
repo does not need either number. Only the properties the pipeline reads are
kept; **no coordinate is rounded**, because the six frozen countries must
re-render byte-identical and a moved vertex can flip a boundary cell.

`load(name)` takes the bare name and finds either spelling, so a working copy
can keep the plain file and the repo can ship the gz.

This module exists because of a mistake worth not repeating: `globe_tex.py` was
committed reading `ne.json`, which lived only in a sandbox. It could not run in
the repo, and three sections of a plan depended on it. If a script reads a file,
that file goes in the drop.
"""
import gzip
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))

HINT = ("It is Natural Earth 1:10m, public domain. Fetch %s as GeoJSON from\n"
        "naturalearthdata.com, keep only the properties listed in geosrc.py, and\n"
        "save it beside this script — plain or gzipped, either is found.")
WHICH = {'ne.json': 'ne_10m_admin_0_countries',
         'ne-admin1.json': 'ne_10m_admin_1_states_provinces'}


def path(name):
    """The spelling that exists, gz preferred; None if neither does."""
    for p in (os.path.join(HERE, name + '.gz'), os.path.join(HERE, name)):
        if os.path.exists(p):
            return p
    return None


def load(name):
    p = path(name)
    if p is None:
        raise SystemExit('missing %s (or %s.gz).\n%s'
                         % (name, name, HINT % WHICH.get(name, name)))
    if p.endswith('.gz'):
        with gzip.open(p, 'rt', encoding='utf-8') as fh:
            return json.load(fh)
    with open(p, encoding='utf-8') as fh:
        return json.load(fh)
