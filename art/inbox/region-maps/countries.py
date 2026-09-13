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
    # The committed fr-departements.json is metropolitan-only: 96 units. A fresh
    # extract_admin1.py run gives 101, because Natural Earth files the five
    # overseas départements under admin='France'. Without this list a regenerated
    # extract silently reframes the map from the Channel to Réunion and every
    # subject_rect in the manifest goes wrong at once — no assert fires, the map
    # just comes out as a speck. Named here so the config is correct against the
    # source, not only against the file that happens to be committed.
    exclude=['Guadeloupe', 'Guyane française', 'La Réunion', 'Martinique', 'Mayotte'],
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


# Austria is the closest admin-1 fit on the board after Italy: Burgenland,
# Niederösterreich and Steiermark are simultaneously Bundesländer AND
# Weinbaugebiete with the same boundaries — not an approximation at all.
#
# WACHAU IS NOT HERE, and its absence is the point. R040 Wachau DAC sits inside
# Niederösterreich, which is itself R062. Under the parent-stays-whole ruling it
# is an overlay on a second plane, not a carve-out of its parent, and that plane
# does not exist yet. Painting it with a `splits` line would hand the whole
# western half of Niederösterreich to a 1,350-hectare DAC.
#
# Wien is also both a Bundesland and a Weinbaugebiet, with its own Wiener
# Gemischter Satz DAC. It has no catalog row; staged in the expansion doc.
AUSTRIA = dict(
    admin1='at-states.json', subject='Austria', log=160, margin=170, splits=[],
    regions={
     'burgenland'      : ['Burgenland'],
     'niederosterreich': ['Niederösterreich'],
     'styria'          : ['Steiermark'],
    },
)

# China's four catalog rows sit on four provinces, which is why it needs no
# split and no new source. Two are exact, two are whole-unit approximations and
# the second one is a stretch:
#
#   Shandong  exact — Yantai and Penglai are Shandong prefectures
#   Hebei     exact — Huailai and Changli. Beijing and Tianjin are separate
#             admin-1 units, so painted Hebei has two holes in it
#   Ningxia   approximate — the GI is literally "Ningxia Helan Mountain East
#             Foothill", a ~60 km strip at the mountain's foot near Yinchuan.
#             Southern Ningxia is loess, not vines
#   Yunnan    STRETCHED — Shangri-La is Deqin and Cizhong in Diqing prefecture,
#             a handful of villages at 2,200-2,600 m in the far north-west.
#             Painting all 394,000 km² of Yunnan means a tap on Honghe, where
#             the province's actual volume viticulture is and which is 700 km
#             south-east at a different altitude entirely, answers Shangri-La.
#             Admin-2 (Diqing) is the honest fix if that data ever lands.
CHINA = dict(
    admin1='cn-provinces.json', subject='China', log=160, margin=170, splits=[],
    regions={
     'ningxia'  : ['Ningxia'],
     'shangrila': ['Yunnan'],
     'shandong' : ['Shandong'],
     'hebei'    : ['Hebei'],
    },
)

COUNTRIES.update(austria=AUSTRIA, china=CHINA)


# --- palettes frozen at 0.9.56 ------------------------------------------------
# `palette.py` was widened after these seven shipped: a fourth value band, and an
# assignment that picks WHICH colours rather than always taking the first n of
# the pool. Every country improved — Italy's worst adjacent pair went 46.4 to
# 51.0, Austria's three regions went 24.1 (three browns) to 71.8.
#
# The seven installed at 0.9.56 keep the colours they shipped with, because
# changing them means re-rendering and re-installing art that is already on
# screen and already screenshotted. Delete a dict below and that country picks
# up the better pool on its next render. France was always authored.

ITALY['fills'] = {
     'piedmont': (147, 74, 181),
     'valledaosta': (43, 130, 104),
     'liguria': (198, 181, 139),
     'lombardy': (71, 130, 43),
     'altoadige': (130, 43, 59),
     'trentino': (179, 139, 198),
     'veneto': (139, 198, 180),
     'friuli': (198, 139, 149),
     'emiliaromagna': (181, 74, 93),
     'tuscany': (108, 181, 74),
     'umbria': (130, 106, 43),
     'marche': (139, 173, 198),
     'lazio': (102, 43, 130),
     'abruzzo': (130, 72, 43),
     'molise': (158, 198, 139),
     'campania': (181, 109, 74),
     'puglia': (74, 136, 181),
     'basilicata': (74, 181, 149),
     'calabria': (43, 94, 130),
     'sicily': (198, 158, 139),
     'sardinia': (181, 151, 74),
}

SPAIN['fills'] = {
     'rioja': (147, 74, 181),
     'navarra': (43, 94, 130),
     'basque': (181, 109, 74),
     'riberadelduero': (108, 181, 74),
     'ruedatoro': (74, 136, 181),
     'bierzo': (198, 158, 139),
     'galicia': (71, 130, 43),
     'catalonia': (74, 181, 149),
     'aragon': (130, 106, 43),
     'lamancha': (102, 43, 130),
     'madrid': (130, 72, 43),
     'levante': (181, 74, 93),
     'jerez': (130, 43, 59),
     'andalucia': (181, 151, 74),
     'extremadura': (43, 130, 104),
     'baleares': (198, 139, 149),
}

PORTUGAL['fills'] = {
     'vinhoverde': (130, 72, 43),
     'douro': (71, 130, 43),
     'dao': (181, 109, 74),
     'bairrada': (43, 94, 130),
     'beirainterior': (102, 43, 130),
     'lisboa': (130, 43, 59),
     'tejo': (43, 130, 104),
     'setubal': (181, 151, 74),
     'alentejo': (181, 74, 93),
     'algarve': (130, 106, 43),
}

ARGENTINA['fills'] = {
     'mendoza': (43, 130, 104),
     'sanjuan': (130, 72, 43),
     'salta': (130, 106, 43),
     'catamarca': (43, 94, 130),
     'patagonia': (130, 43, 59),
     'cordoba': (71, 130, 43),
}

CHILE['fills'] = {
     'coquimbo': (130, 106, 43),
     'aconcagua': (43, 94, 130),
     'maipo': (181, 74, 93),
     'rapel': (71, 130, 43),
     'maule': (130, 43, 59),
     'itata': (43, 130, 104),
     'biobio': (102, 43, 130),
     'malleco': (130, 72, 43),
}

NEWZEALAND['fills'] = {
     'northland': (43, 130, 104),
     'auckland': (130, 72, 43),
     'waikatobop': (43, 94, 130),
     'gisborne': (181, 151, 74),
     'hawkesbay': (181, 74, 93),
     'wairarapa': (130, 106, 43),
     'nelson': (181, 109, 74),
     'marlborough': (102, 43, 130),
     'canterbury': (71, 130, 43),
     'centralotago': (130, 43, 59),
}
