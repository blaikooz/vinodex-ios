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


SPAIN = dict(
    admin1='es-provinces.json', subject='Spain', log=160, margin=170, splits=[],
    exclude=['Las Palmas', 'Santa Cruz de Tenerife', 'Ceuta', 'Melilla'],
    regions={
     'rioja'        : ['La Rioja', 'Álava'],
     'navarra'      : ['Navarra'],
     'basque'       : ['Bizkaia', 'Gipuzkoa'],
     'riberadelduero': ['Burgos', 'Soria'],
     'ruedatoro'    : ['Valladolid', 'Zamora', 'Segovia'],
     'bierzo'       : ['León'],
     'galicia'      : ['La Coruña', 'Lugo', 'Orense', 'Pontevedra'],
     'catalonia'    : ['Barcelona', 'Tarragona', 'Lérida', 'Gerona'],
     'aragon'       : ['Huesca', 'Teruel', 'Zaragoza'],
     'lamancha'     : ['Albacete', 'Ciudad Real', 'Cuenca', 'Guadalajara', 'Toledo'],
     'madrid'       : ['Madrid'],
     'levante'      : ['Alicante', 'Castellón', 'Valencia', 'Murcia'],
     'jerez'        : ['Cádiz', 'Sevilla', 'Huelva'],
     'andalucia'    : ['Córdoba', 'Málaga', 'Granada', 'Jaén', 'Almería'],
     'extremadura'  : ['Badajoz', 'Cáceres'],
     'baleares'     : ['Baleares'],
    },
)

PORTUGAL = dict(
    admin1='pt-districts.json', subject='Portugal', log=160, margin=170,
    splits=[('douro', 'dao', 41.00)],
    exclude=['Azores', 'Madeira'],
    regions={
     'vinhoverde'   : ['Viana do Castelo', 'Braga', 'Porto'],
     # Viseu district holds the Douro's south bank AND the Dão. Cut at 41.00 N:
     # north of it is Douro, south is Dão. `dao` therefore starts with no units
     # of its own and is entirely the product of that split.
     'douro'        : ['Vila Real', 'Bragança', 'Viseu'],
     'dao'          : [],
     'bairrada'     : ['Aveiro', 'Coimbra'],
     'beirainterior': ['Castelo Branco', 'Guarda'],
     'lisboa'       : ['Lisboa', 'Leiria'],
     'tejo'         : ['Santarém'],
     'setubal'      : ['Setúbal'],
     'alentejo'     : ['Évora', 'Beja', 'Portalegre'],
     'algarve'      : ['Faro'],
    },
)

ARGENTINA = dict(
    admin1='ar-provinces.json', subject='Argentina', log=160, margin=170, splits=[],
    exclude=['Tierra del Fuego'],   # the province carries an Antarctic claim
    focus='regions',
    regions={
     'mendoza'   : ['Mendoza'],
     'sanjuan'   : ['San Juan'],
     'salta'     : ['Salta', 'Jujuy'],
     'catamarca' : ['Catamarca', 'La Rioja'],
     'patagonia' : ['Río Negro', 'Neuquén', 'Chubut'],
     'cordoba'   : ['Córdoba'],
    },
)

CHILE = dict(
    admin1='cl-regions.json', subject='Chile', log=160, margin=170,
    exclude=[], focus='regions',
    # Valparaíso Region includes Easter Island; frame on the mainland wine belt.
    frame_window=(-76, -40, -69, -28),
    # Natural Earth's Metropolitana polygon reaches to 71.46 W at Casablanca's
    # latitude — about 25 km further west than the real regional boundary, which
    # put Casablanca in Maipo. Cut on the meridian: Maipo keeps the east side.
    splits=[('maipo', 'aconcagua', -71.25, 'lon')],
    regions={
     'coquimbo'  : ['Coquimbo'],
     'aconcagua' : ['Valparaíso'],
     'maipo'     : ['Región Metropolitana de Santiago'],
     'rapel'     : ["Libertador General Bernardo O'Higgins"],
     'maule'     : ['Maule'],
     'itata'     : ['Ñuble'],
     'biobio'    : ['Bío-Bío'],
     'malleco'   : ['La Araucanía'],
    },
)

NEWZEALAND = dict(
    admin1='nz-councils.json', subject='New Zealand', log=160, margin=170, splits=[],
    exclude=['Antipodes Islands', 'Auckland Islands', 'Campbell Islands',
             'Chatham Islands Territory', 'Kermadec Islands', 'The Snares',
             'Three Kings Islands', 'Tokelau'],
    regions={
     'northland'   : ['Northland'],
     'auckland'    : ['Auckland'],
     'waikatobop'  : ['Waikato', 'Bay of Plenty'],
     'gisborne'    : ['Gisborne District'],
     'hawkesbay'   : ["Hawke's Bay"],
     'wairarapa'   : ['Wellington'],
     'nelson'      : ['Nelson City', 'Tasman District'],
     'marlborough' : ['Marlborough District'],
     'canterbury'  : ['Canterbury'],
     'centralotago': ['Otago'],
    },
)

COUNTRIES.update(spain=SPAIN, portugal=PORTUGAL, argentina=ARGENTINA,
                 chile=CHILE, newzealand=NEWZEALAND)
