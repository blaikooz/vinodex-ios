"""Per-country configuration for region_map.py.

A region is built from admin-1 units, named one of two ways:

    ['Gironde', 'Dordogne']          explicit unit names (the `name` field)
    {'region': 'Toscana'}            every unit whose `region` field matches

The second form only works where the source data carries a `region` column —
Italy's provinces do, France's départements do not. Mixing them is fine and is
how Trentino and Alto Adige are carved out of one administrative region.

Fills are NOT authored here. Every region gets a unique colour so the runtime can
identify it by pixel, and the assignment is computed by `palette.py` from the
adjacency of the rendered masks, so that no two regions that touch each other end
up looking alike. See §6.1 of the plan.
"""

FRANCE = dict(
    admin1='fr-departements.json',
    subject='France',                 # excluded from the world backdrop
    log=160, margin=170,
    # The Rhône département holds Beaujolais in its north and the head of the
    # Northern Rhône (Ampuis, Côte-Rôtie) in its south. Cut it where Beaujolais
    # stops. Reproducible; survives a re-render.
    splits=[('beaujolais', 'rhone', 45.62)],
    # France's palette was hand-tuned and reviewed; keep it rather than churn it.
    fills={
     'bordeaux': (142, 47, 69),   'southwest': (201, 162, 76),
     'loire': (110, 148, 100),    'burgundy': (166, 99, 31),
     'beaujolais': (208, 87, 122),'champagne': (228, 208, 138),
     'alsace': (62, 140, 138),    'jura': (138, 123, 176),
     'savoie': (127, 168, 201),   'rhone': (168, 65, 44),
     'provence': (217, 143, 122), 'languedoc': (140, 143, 62),
     'roussillon': (95, 91, 140), 'corsica': (78, 122, 74),
    },
    regions={
     'bordeaux'  : ['Gironde'],
     'southwest' : ['Dordogne', 'Lot', 'Lot-et-Garonne', 'Tarn', 'Tarn-et-Garonne',
                    'Gers', 'Landes', 'Pyrénées-Atlantiques', 'Hautes-Pyrénées',
                    'Aveyron', 'Ariège', 'Haute-Garonne'],
     'loire'     : ['Loire-Atlantique', 'Maine-et-Loire', 'Indre-et-Loire',
                    'Loir-et-Cher', 'Loiret', 'Cher', 'Nièvre', 'Indre'],
     'burgundy'  : ["Côte-d'Or", 'Saône-et-Loire', 'Yonne'],
     'beaujolais': ['Rhône'],
     'champagne' : ['Marne', 'Aube', 'Aisne', 'Haute-Marne'],
     'alsace'    : ['Bas-Rhin', 'Haute-Rhin'],
     'jura'      : ['Jura'],
     'savoie'    : ['Savoie', 'Haute-Savoie'],
     'rhone'     : ['Ardèche', 'Drôme', 'Vaucluse', 'Gard'],
     'provence'  : ['Var', 'Bouches-du-Rhône', 'Alpes-de-Haute-Provence',
                    'Alpes-Maritimes'],
     'languedoc' : ['Hérault', 'Aude'],
     'roussillon': ['Pyrénées-Orientales'],
     'corsica'   : ['Corse-du-Sud', 'Haute-Corse'],
    },
)

# Italy needs no approximation. Its wine regions ARE its administrative regions,
# so all 110 provinces are claimed and there is no unassigned ground at all —
# a cleaner fit than France, where 49 départements stay neutral.
#
# The one departure from the 20 administrative regions is the one the wine world
# insists on: Trentino-Alto Adige is two DOC territories, not one, so Trento and
# Bozen are carved apart by province. That takes the count to 21, which is what
# PLAN.md says the catalog holds for Italy.
ITALY = dict(
    admin1='it-provinces.json',
    subject='Italy',
    log=160, margin=170,
    splits=[],
    regions={
     'piedmont'      : {'region': 'Piemonte'},
     'valledaosta'   : {'region': "Valle d'Aosta"},
     'liguria'       : {'region': 'Liguria'},
     'lombardy'      : {'region': 'Lombardia'},
     'altoadige'     : ['Bozen'],
     'trentino'      : ['Trento'],
     'veneto'        : {'region': 'Veneto'},
     'friuli'        : {'region': 'Friuli-Venezia Giulia'},
     'emiliaromagna' : {'region': 'Emilia-Romagna'},
     'tuscany'       : {'region': 'Toscana'},
     'umbria'        : {'region': 'Umbria'},
     'marche'        : {'region': 'Marche'},
     'lazio'         : {'region': 'Lazio'},
     'abruzzo'       : {'region': 'Abruzzo'},
     'molise'        : {'region': 'Molise'},
     'campania'      : {'region': 'Campania'},
     'puglia'        : {'region': 'Apulia'},
     'basilicata'    : {'region': 'Basilicata'},
     'calabria'      : {'region': 'Calabria'},
     'sicily'        : {'region': 'Sicily'},
     'sardinia'      : {'region': 'Sardegna'},
    },
)

COUNTRIES = {'france': FRANCE, 'italy': ITALY}
