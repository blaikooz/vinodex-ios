#!/usr/bin/env python3
"""Emit pins.json: the catalog's 20 France regions as lon/lat, for france_check.py.

Step 3 of HANDOFF.md, with one correction to its premise.

THE HANDOFF SAYS to derive lon/lat by decoding each region's `mapPosition`.
That was tried first and it does not hold up. `mapPosition` is authored as a
fraction of a *hand-drawn, stylised* France outline, for the sole purpose of
dropping a 7px dot somewhere convincing — `OutlineDotPlacer` even snaps it to
the nearest opaque pixel, so an approximate value is not merely tolerated, it
is designed for. Read back as geography the fractions drift: decoding all 20
put Alsace at 6.03E (it is 7.36E) which resolved it to CHAMPAGNE, and put
Jurançon in Spain. Sixteen of twenty survived; the four that did not were not
config problems the handoff's table could fix, because the input was wrong
rather than the grouping.

So the coordinates below are authored from the actual towns, the way
`pins-sample.json` was. Each is the seat of the region it names and sits in a
département `france_map.py` assigns to the expected stem.

The decode is kept anyway, as a printed cross-check: the gap between the
authored point and the decoded one measures how far each shipping dot sits
from its own region, which is a finding about `regions.ts` rather than about
this map. Nothing here writes to regions.ts — it is read-only for this test.

Also worth recording: the catalog holds 20 France regions, not the 19
PLAN.md's 0.8.3 entry estimated.
"""
import json, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUTLINE = os.path.join(REPO, "Sources/VinodexUI/Resources/ClassArt/outline-france.png")
ENTRIES = os.path.join(REPO, "Sources/VinodexCore/Resources/entries.json")

from PIL import Image
import numpy as np

# The seat of each region, and the département it must land in for the stem
# on the right to be the answer. Sources are the appellation towns themselves.
AUTHORED = {
    "R001": (-0.578, 44.838, "Bordeaux (Gironde)",                 "bordeaux"),
    "R002": (4.840, 47.022, "Beaune (Côte-d'Or)",                  "burgundy"),
    "R003": (3.960, 49.043, "Épernay (Marne)",                     "champagne"),
    "R004": (4.808, 44.138, "Orange (Vaucluse)",                   "rhone"),
    "R005": (0.690, 47.394, "Tours (Indre-et-Loire)",              "loire"),
    "R006": (7.358, 48.079, "Colmar (Haut-Rhin)",                  "alsace"),
    "R007": (5.448, 43.529, "Aix-en-Provence (Bouches-du-Rhône)",  "provence"),
    # North of the 45.62N SPLITS cut, which is what separates the Beaujolais
    # half of the Rhône département from Côte-Rôtie in its south.
    "R008": (4.719, 45.989, "Villefranche-sur-Saône (Rhône)",      "beaujolais"),
    "R009": (3.216, 43.344, "Béziers (Hérault)",                   "languedoc"),
    "R010": (3.799, 47.814, "Chablis (Yonne)",                     "burgundy"),
    "R011": (-0.319, 44.539, "Sauternes (Gironde)",                "bordeaux"),
    "R012": (5.775, 46.904, "Arbois (Jura)",                       "jura"),
    "R079": (1.898, 43.901, "Gaillac (Tarn)",                      "southwest"),
    "R099": (4.832, 44.056, "Châteauneuf-du-Pape (Vaucluse)",      "rhone"),
    "R105": (8.738, 41.927, "Ajaccio (Corse-du-Sud)",              "corsica"),
    "R106": (5.917, 45.564, "Chambéry (Savoie)",                   "savoie"),
    "R107": (2.895, 42.698, "Perpignan (Pyrénées-Orientales)",     "roussillon"),
    "R108": (1.441, 44.448, "Cahors (Lot)",                        "southwest"),
    "R122": (0.482, 44.851, "Bergerac (Dordogne)",                 "southwest"),
    "R155": (-0.383, 43.290, "Jurançon (Pyrénées-Atlantiques)",    "southwest"),
}

man = json.load(open(os.path.join(HERE, "out/france-manifest.json")))
pr = man["projection"]
K, O, S = pr["x_factor"], pr["origin"], pr["scale"]


def to_canvas(lon, lat):
    return (lon * K - O[0]) * S + 2, (-lat - O[1]) * S + 2


def from_canvas(cx, cy):
    return ((cx - 2) / S + O[0]) / K, -((cy - 2) / S + O[1])


im = Image.open(OUTLINE).convert("RGBA")
ys, xs = np.nonzero(np.array(im)[:, :, 3] > 8)
sil = (xs.min(), xs.max(), ys.min(), ys.max())
W, H = im.size

geo = json.load(open(os.path.join(HERE, "fr-departements.json")))
feats = geo["features"] if isinstance(geo, dict) else geo


def coords_of(g):
    if g["type"] == "Polygon":
        for ring in g["coordinates"]:
            yield from ring
    else:
        for poly in g["coordinates"]:
            for ring in poly:
                yield from ring


pts = [to_canvas(lo, la) for f in feats for lo, la in coords_of(f["geometry"])]
CX0, CX1 = min(p[0] for p in pts), max(p[0] for p in pts)
CY0, CY1 = min(p[1] for p in pts), max(p[1] for p in pts)


def decode(mp):
    """What `mapPosition` claims, read back as geography."""
    px, py = mp["x"] * W, mp["y"] * H
    fx = (px - sil[0]) / (sil[1] - sil[0])
    fy = (py - sil[2]) / (sil[3] - sil[2])
    return from_canvas(CX0 + fx * (CX1 - CX0), CY0 + fy * (CY1 - CY0))


def km(a, b):
    dlon = (a[0] - b[0]) * math.cos(math.radians((a[1] + b[1]) / 2)) * 111.32
    return math.hypot(dlon, (a[1] - b[1]) * 110.57)


entries = {e["id"]: e for e in json.load(open(ENTRIES))}
pins, drift = [], []
print(f"{'id':6} {'name':22} {'authored seat':34} {'drift of the shipping dot'}")
for rid, (lon, lat, seat, stem) in sorted(AUTHORED.items()):
    e = entries.get(rid)
    name = e["name"] if e else "?"
    pins.append({"id": rid, "name": name, "lon": lon, "lat": lat})
    mp = (e or {}).get("details", {}).get("mapPosition")
    note = ""
    if mp:
        d = km(decode(mp), (lon, lat))
        drift.append((d, name))
        note = f"{d:6.0f} km"
    print(f"{rid:6} {name[:22]:22} {seat:34} {note}")

with open(os.path.join(HERE, "pins.json"), "w") as fh:
    json.dump(pins, fh, indent=1, ensure_ascii=False)

drift.sort(reverse=True)
print(f"\nwrote pins.json ({len(pins)} regions)")
print(f"shipping-dot drift: median {sorted(d for d, _ in drift)[len(drift)//2]:.0f} km, "
      f"worst {drift[0][0]:.0f} km ({drift[0][1]})")
print("worst five:", ", ".join(f"{n} {d:.0f}km" for d, n in drift[:5]))
