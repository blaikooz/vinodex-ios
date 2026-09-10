#!/usr/bin/env python3
"""Emit catalog pins for region_check.py.  python3 make_pins.py france|italy

Step 3 of HANDOFF.md, with the same correction to its premise that the France
pass established and that holds for Italy too.

THE HANDOFF SAYS to derive lon/lat from each region's `mapPosition`. That does
not survive contact. `mapPosition` is authored as a fraction of a hand-drawn,
stylised country outline, purely to drop a 7px dot somewhere convincing —
`OutlineDotPlacer` even snaps it to the nearest opaque pixel, so an approximate
value is not merely tolerated, it is designed for. Read back as geography the
French fractions drifted a median of 61km and put Alsace in Champagne and
Jurançon in Spain.

So the coordinates below are authored from the towns themselves. Each is the
seat of the appellation it names and sits in an admin-1 unit that
`countries.py` assigns to the stem on the right.

Nothing here writes to regions.ts — it is read-only for this test.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ENTRIES = os.path.join(REPO, "Sources/VinodexCore/Resources/entries.json")

# id: (lon, lat, seat, expected stem)
FRANCE = {
    "R001": (-0.578, 44.838, "Bordeaux (Gironde)",                 "bordeaux"),
    "R002": (4.840, 47.022, "Beaune (Côte-d'Or)",                  "burgundy"),
    "R003": (3.960, 49.043, "Épernay (Marne)",                     "champagne"),
    "R004": (4.808, 44.138, "Orange (Vaucluse)",                   "rhone"),
    "R005": (0.690, 47.394, "Tours (Indre-et-Loire)",              "loire"),
    "R006": (7.358, 48.079, "Colmar (Haut-Rhin)",                  "alsace"),
    "R007": (5.448, 43.529, "Aix-en-Provence (Bouches-du-Rhône)",  "provence"),
    # North of the 45.62N split, which is what separates the Beaujolais half
    # of the Rhône département from Côte-Rôtie in its south.
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

# Italy's catalog mixes whole regions with single appellations — Valpolicella
# is a corner of Veneto, Etna a shoulder of Sicily, Collio a strip of Friuli.
# Those three get the coordinates of the appellation, not of the region, which
# is the point: the map should place them where they actually are.
ITALY = {
    "R021": (11.331, 43.318, "Siena (Toscana)",                    "tuscany"),
    "R022": (8.035, 44.700, "Alba (Piemonte)",                     "piedmont"),
    "R023": (10.993, 45.438, "Verona (Veneto)",                    "veneto"),
    "R024": (12.437, 37.803, "Marsala (Sicilia)",                  "sicily"),
    "R025": (14.790, 40.914, "Avellino (Campania)",                "campania"),
    "R026": (13.236, 46.063, "Udine (Friuli)",                     "friuli"),
    "R027": (11.354, 46.499, "Bolzano (Alto Adige)",               "altoadige"),
    "R028": (14.167, 42.351, "Chieti (Abruzzo)",                   "abruzzo"),
    "R029": (17.633, 40.401, "Manduria (Puglia)",                  "puglia"),
    "R064": (13.244, 43.524, "Jesi (Marche)",                      "marche"),
    "R069": (9.113, 39.216, "Cagliari (Sardegna)",                 "sardinia"),
    "R070": (11.121, 46.067, "Trento (Trentino)",                  "trentino"),
    "R071": (10.867, 45.533, "Negrar, Valpolicella (Verona)",      "veneto"),
    "R072": (11.343, 44.494, "Bologna (Emilia-Romagna)",           "emiliaromagna"),
    "R073": (15.004, 37.752, "Etna, Catania (Sicilia)",            "sicily"),
    "R074": (13.499, 45.952, "Gorizia, Collio (Friuli)",           "friuli"),
    "R100": (12.646, 42.889, "Montefalco (Umbria)",                "umbria"),
    "R109": (10.048, 45.568, "Franciacorta (Lombardia)",           "lombardy"),
    "R110": (12.680, 41.809, "Frascati (Lazio)",                   "lazio"),
    "R111": (17.070, 39.383, "Cirò (Calabria)",                    "calabria"),
    "R112": (15.677, 40.923, "Rionero in Vulture (Basilicata)",    "basilicata"),
}

TABLES = {"france": FRANCE, "italy": ITALY}
name = (sys.argv[1] if len(sys.argv) > 1 else "france").lower()
if name not in TABLES:
    sys.exit("usage: make_pins.py france|italy")
table = TABLES[name]

entries = {e["id"]: e for e in json.load(open(ENTRIES))}
country = {"france": "France", "italy": "Italy"}[name]
catalog = {
    e["id"] for e in entries.values()
    if e.get("category") == "REGIONS" and e.get("details", {}).get("origin") == country
}

missing = sorted(catalog - set(table))
if missing:
    print("!! catalog regions with no authored pin: %s" % ", ".join(missing))
extra = sorted(set(table) - catalog)
if extra:
    print("!! pins for ids the catalog does not hold: %s" % ", ".join(extra))

pins = []
print(f"{'id':6} {'name':26} {'seat':34} {'stem'}")
for rid, (lon, lat, seat, stem) in sorted(table.items()):
    nm = entries.get(rid, {}).get("name", "?")
    # `expect` turns region_check's MISMATCH class on: without it the gate can
    # only say a pin landed somewhere, not that it landed somewhere right.
    pins.append({"id": rid, "name": nm, "lon": lon, "lat": lat, "expect": stem})
    print(f"{rid:6} {nm[:26]:26} {seat:34} {stem}")

out = os.path.join(HERE, "pins-%s-catalog.json" % name)
with open(out, "w") as fh:
    json.dump(pins, fh, indent=1, ensure_ascii=False)
print(f"\nwrote {os.path.basename(out)} ({len(pins)} regions)")
