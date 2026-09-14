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
    # --- the second index plane -------------------------------------------
    # A child is a catalog region that lives INSIDE a painted one and that no
    # admin-1 unit isolates. It gets a byte in <country>-index2.png, which the
    # hit test reads before plane 1. See horizon-md/index2-agreed.md.
    #
    # `source` is a commune-level file, because that is the level these exist
    # at; `fetch_communes.py` builds it from IGN/INSEE under Licence Ouverte.
    # `units` names whole communes, and the approximation each list makes is
    # stated here, next to the list that makes it.
    children={
     # R099. The AOC is ~3,200 ha over five communes: all of Châteauneuf-du-Pape
     # and PARTS of Bédarrides, Courthézon, Orange and Sorgues. Taking the one
     # whole commune UNDER-covers it by roughly half.
     #
     # That is the right direction to be wrong. A tap in the commune answers
     # Châteauneuf; a tap in the spill answers Rhône, which is true, just less
     # specific. Taking all five would over-cover and paint Côtes du Rhône
     # vineyards in Orange and Sorgues as Châteauneuf-du-Pape — a wrong answer
     # rather than a quiet one, and nothing downstream could detect it.
     'chateauneuf': dict(parent='rhone', source='fr-communes.json',
                         units=['Châteauneuf-du-Pape']),
     # R011. Unlike Châteauneuf this one is exact: the AOC is five WHOLE
     # communes, so the composed polygon is the appellation rather than an
     # approximation of it. Barsac may label as either Barsac or Sauternes.
     #
     # The five-commune list is the standard definition and it is NOT from a
     # register I could reach — sommbot should confirm it before this ships.
     'sauternes': dict(parent='bordeaux', source='fr-communes.json',
                       units=['Sauternes', 'Bommes', 'Fargues', 'Preignac',
                              'Barsac']),
    },
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
    # The two Canary provinces are back in and painted — R063 is a catalog
    # region and was one of the four rows the coverage gate called UNPINNED.
    # Ceuta and Melilla stay out: no catalog entry, and they sit inside
    # Morocco's coastline where a stray painted speck reads as an error.
    exclude=['Ceuta', 'Melilla'],
    # The Canaries are already inside the shipped canvas — they rendered as
    # index 0 before, because `exclude` dropped them BEFORE projection rather
    # than because they were off the frame. So the frame must be pinned to what
    # it already is, or Spain reframes around 28N/-18 and every existing index
    # byte moves. Both pins together hold canvas, projection and subject_rect.
    frame_window=(-10.0, 35.0, 5.0, 44.5),
    x_factor=0.75673244,
    regions={
     'rioja'        : ['La Rioja', 'Álava'],
     'navarra'      : ['Navarra'],
     'basque'       : ['Bizkaia', 'Gipuzkoa'],
     'riberadelduero': ['Burgos', 'Soria'],
     # R034 and R113 split, 14 Sep. Rueda is the Duero terraces in
     # Valladolid and Segovia; Toro is Zamora. `rueda` keeps the merged
     # area's slot so it inherits its index byte and nothing after it
     # renumbers; `toro` is appended below.
     'rueda'        : ['Valladolid', 'Segovia'],
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
     # R063. Stem is the catalog name folded flat, per
     # RegionMapTests.displayNamesNameTheArea.
     'canaryislands': ['Las Palmas', 'Santa Cruz de Tenerife'],
     'toro'         : ['Zamora'],       # R113
    },
)

PORTUGAL = dict(
    # log=600, not 160. The frame now spans 22 degrees — Lisbon to Flores — so
    # at the usual 160 the mainland is 21 cells across and Dao renders at 21 px,
    # a quarter of the smallest region on any shipped map. Ten mainland regions
    # must not lose their resolution to gain two islands. This is the one canvas
    # in the batch that is allowed to move, so it moves properly.
    admin1='pt-districts.json', subject='Portugal', log=600, margin=170,
    splits=[('douro', 'dao', 41.00)],
    # Madeira and the Azores are painted regions now (R081, R121). Unlike the
    # Canaries they were genuinely OFF the canvas — Madeira by a tenth of a
    # degree, the Azores by fifteen — so this is the one map in the batch whose
    # canvas and projection legitimately move. Everything else about it is held:
    # the seven existing regions come back as the same shapes, and...
    exclude=[],
    # ...the opening view stays on the mainland rather than following the
    # islands out into the Atlantic. See region_map.py.
    subject_rect='mainland',
    min_island=2,   # Porto Santo and the smaller Azorean islands are a few cells
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
     # Appended: new stems go last so existing region ids do not renumber.
     'madeira'      : ['Madeira'],      # R081
     'azores'       : ['Azores'],       # R121
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
     'waikatobayofplenty'  : ['Waikato', 'Bay of Plenty'],
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
    # The one region on the second index plane before 1.0. Unblocked by finding
    # the statute, not by lowering the bar: Weingesetz 2009 § 21 Abs. 3 Z 1 lit.
    # k names the eight Gemeinden, and the DAC-Verordnung (BGBl. II Nr. 200/2020
    # idF 191/2023) defers to that same Weinbaugebiet rather than redrawing it.
    # So this IS the DAC boundary, not a shape that resembles one.
    # `fetch_gemeinden.py` carries the citation, the CC BY 4.0 attribution, and
    # the reason the units are joined on Gemeindekennziffer and not on name.
    children={
     'wachau': {'parent': 'niederosterreich', 'source': 'at-gemeinden.json',
                'units': ['Aggsbach', 'Bergern im Dunkelsteinerwald', 'Dürnstein',
                          'Mautern an der Donau', 'Mühldorf', 'Rossatz-Arnsdorf',
                          'Spitz', 'Weißenkirchen in der Wachau']},
    },
)
# Pinned like Israel's and Ukraine's: Austria shipped these three at 0.9.56 and
# an unpinned palette is recomputed from scratch on every render.
AUSTRIA['fills'] = {
     'burgenland'      : (139, 67, 173),   # #8B43AD, as installed
     'niederosterreich': (130, 72, 43),    # #82482B, as installed
     'styria'          : (101, 173, 67),   # #65AD43, as installed
}

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
     'rueda': (74, 136, 181),   # was 'ruedatoro'; Toro's fill is computed
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
     'waikatobayofplenty': (43, 94, 130),
     'gisborne': (181, 151, 74),
     'hawkesbay': (181, 74, 93),
     'wairarapa': (130, 106, 43),
     'nelson': (181, 109, 74),
     'marlborough': (102, 43, 130),
     'canterbury': (71, 130, 43),
     'centralotago': (130, 43, 59),
}

# =============================================================================
# Wave 2, 13 Sep 2026 — a region map for every wine country in the catalog.
#
# Each block below was validated before it was written: every unit name is
# checked to exist in the extract, and every catalog region has a pin authored
# from the town its appellations name, so `region_check.py` proves the mapping
# against the shipped raster rather than against this table.
#
# Two standing approximations apply widely here and are not repeated per block:
#
#   * A painted area covers the WHOLE admin unit. Nashik is painted as all of
#     Maharashtra and Niagara as all of Ontario. That is the same licence
#     Bordeaux already takes over the Gironde, and it is what makes a two-region
#     country legible at all.
#   * Where several catalog regions share one unit, `splits` cuts it on a
#     parallel or a meridian and the cuts chain. Germany takes two and South
#     Africa three. A cut is reproducible and survives a re-render, which an
#     authored exception list would not — but it is a straight line through
#     country that has no straight lines in it, and everything it misplaces is
#     unassigned ground rather than another catalog region.
# =============================================================================

GREECE = dict(
    # log=220, not 160: at 160 a cell is ~7 km and Santorini (76 km2) is dropped
    # as an islet, so its own pin lands in the sea. An archipelago needs the
    # resolution its islands are made of.
    admin1='gr-peripheries.json', subject='Greece', log=220, margin=170,
    min_island=4,   # Santorini is ~6 cells here; the default 20 deletes it
    splits=[],
    regions={
     'southaegean'  : ['Notio Aigaio'],
     'peloponnese': ['Peloponnisos', 'Dytiki Ellada'],
     'naoussa'    : ['Kentriki Makedonia'],
     'amyndeon'   : ['Dytiki Makedonia'],
     'attica'     : ['Attiki'],
     # Appended, not inserted. Region ids are assigned in this dict's order, so
     # putting a new stem in the middle renumbers every region after it and
     # invalidates the shipped index raster.
     'crete'      : ['Kriti'],          # R201, authored 14 Sep
    },
)

GEORGIA = dict(
    admin1='ge-regions.json', subject='Georgia', log=160, margin=170,
    splits=[],
    regions={
     'kakheti': ['Kakheti'],
     'kartli' : ['Shida Kartli', 'Kvemo Kartli'],
     'imereti': ['Imereti'],
    },
)

CROATIA = dict(
    admin1='hr-counties.json', subject='Croatia', log=160, margin=170,
    # Hvar, Brač, Korčula and Pelješac are the Dalmatian wine islands and the
    # 20-cell speck floor was deleting them — they showed as sea with the
    # backdrop's shelf underneath. They are in Splitsko-Dalmatinska and
    # Dubrovacko-Neretvanska, both already claimed by `dalmatia`, so they need
    # no new region: they simply have to survive to be painted.
    min_island=2,
    splits=[],
    regions={
     'dalmatia': ['Zadarska', 'Šibensko-Kninska', 'Splitsko-Dalmatinska', 'Dubrovacko-Neretvanska'],
     'istria'  : ['Istarska'],
     'slavonia': ['Osjecko-Baranjska', 'Vukovarsko-Srijemska', 'Brodsko-Posavska', 'Viroviticko-Podravska'],
    },
)

HUNGARY = dict(
    admin1='hu-counties.json', subject='Hungary', log=160, margin=170,
    splits=[],
    regions={
     'tokaj'  : ['Borsod-Abaúj-Zemplén'],
     'villany': ['Baranya'],
     'eger'   : ['Heves', 'Eger'],
    },
)

ROMANIA = dict(
    admin1='ro-counties.json', subject='Romania', log=160, margin=170,
    splits=[],
    regions={
     'dealumare': ['Prahova', 'Buzau'],
     'tarnave'  : ['Alba', 'Mures', 'Sibiu'],
     'cotnari'  : ['Iasi'],
    },
)

BULGARIA = dict(
    admin1='bg-provinces.json', subject='Bulgaria', log=160, margin=170,
    splits=[],
    regions={
     'thracian': ['Plovdiv', 'Pazardzhik', 'Stara Zagora', 'Haskovo'],
     'struma'  : ['Blagoevgrad'],
    },
)

MOLDOVA = dict(
    admin1='md-districts.json', subject='Moldova', log=160, margin=170,
    splits=[],
    regions={
     'codru'     : ['Străşeni', 'Ialoveni', 'Călărași', 'Nisporeni', 'Hîncesti', 'Criuleni', 'Anenii Noi', 'Orhei', 'Chişinău'],
     'stefanvoda': ['Ștefan Vodă'],
    },
)

# CRIMEA IS PAINTED AS UKRAINE. Deliberate override of Natural Earth, ruled by
# the maintainer; the mechanism is `extract_admin1.ANNEX` and the reasoning is
# recorded there. NE 1:10m files both Crimean units under Russia in admin-1 and
# puts the peninsula inside Russia's admin-0 polygon, so the source would have
# drawn it as foreign land inside a country whose own outline art includes it.
#
# The cost, stated because it is not free: the canvas is sized on the subject,
# so the peninsula grew Ukraine's canvas from 502x440 to 502x451 and every index
# byte moved. Ukraine has to be re-rendered AND re-installed together; a new
# index raster against an old manifest resolves taps to the wrong regions.
# Nothing in `entries/countries/` moves -- that art already drew Crimea, and
# those files are not ours to touch.
UKRAINE = dict(
    admin1='ua-oblasts.json', subject='Ukraine', log=160, margin=170,
    splits=[],
    regions={
     'bessarabia' : ['Odessa'],
     'zakarpattia': ['Transcarpathia'],
    },
)
# Pinned for the same reason as Israel's: Ukraine shipped these two fills at
# 0.9.57, and `palette.assign` with no authored dict recomputes from scratch
# every render. It happens to return the same two colours today; that is luck,
# not a guarantee, and the next region added to Ukraine would restyle both.
UKRAINE['fills'] = {
     'bessarabia' : (139, 192, 114),   # #8BC072, as installed
     'zakarpattia': (43, 130, 104),    # #2B8268, as installed
}

SERBIA = dict(
    admin1='rs-districts.json', subject='Republic of Serbia', log=160, margin=170,
    splits=[],
    regions={
     'fruskagora': ['Južno-Backi', 'Sremski'],
     'sumadija'  : ['Šumadijski'],
    },
)

SLOVAKIA = dict(
    admin1='sk-regions.json', subject='Slovakia', log=160, margin=170,
    splits=[],
    regions={
     'malokarpatska'  : ['Bratislavský', 'Trnavský'],
     'slovensky-tokaj': ['Košický'],
    },
)

SLOVENIA = dict(
    admin1='si-municipalities.json', subject='Slovenia', log=160, margin=170,
    splits=[],
    regions={
     'goriskabrda': ['Brda', 'Nova Goriška'],
     'vipava'     : ['Vipava', 'Ajdovščina'],
    },
)

# Natural Earth files the Israeli-administered Golan under ISRAEL, not Syria --
# checked, not assumed. Probes at Katzrin, Ein Zivan, Odem, Mt Bental and the
# Hermon ski station all return admin='Israel', name='HaZafon' in admin-1 and
# ADMIN='Israel' in admin-0. Syria's two nearby units, 'Quneitra' (35.82-35.99E)
# and 'UNDOF' (35.76-35.92E, the separation zone), share ZERO cells with
# HaZafon: HaZafon's eastern edge IS the Alpha line. So there is no
# cross-country override here. Crimea is the override case; this is not.
#
# The real problem is the opposite one: HaZafon is Galilee AND the Golan in a
# single unit, 4,639 km2 with one ring and no holes, so `golan` has no admin
# unit to be cut from -- it has to come out of a split. Three of its four edges
# are free from the source (the Alpha line east, the Hermon finger north, the
# Yarmouk south -- the polygon's east edge steps 35.575 -> 35.667 between lat
# 32.65 and 32.70, which is the Golan appearing). Only the WEST edge is cut,
# and it runs the Jordan and the eastern shore of the Sea of Galilee, which
# sit between 35.625E and 35.652E over the whole span from the Yarmouk to the
# escarpment. A meridian at 35.635E is within 0.017 degrees of that line at
# every latitude; Israel renders at 40.34 px/deg with x_factor 0.847, so
# 0.017 deg is 0.5 px. A traced river and this meridian are the same picture on
# this canvas -- which is exactly why the Wachau argument does NOT transfer
# there: for Wachau every edge would be invented and the error is unbounded.
# Area check: the cut yields ~1,190 km2 against the ~1,200 km2 usually given
# for the Israeli-administered Golan.
ISRAEL = dict(
    admin1='il-districts.json', subject='Israel', log=160, margin=170,
    # On 'lon' the FIRST stem keeps the east, exactly as Germany's
    # ('rheinhessen', 'mosel', 7.4, 'lon') hands Mosel the western side. So the
    # unit hangs on `golan` and `uppergalilee` is the one that gains -- writing
    # it the intuitive way round put 505 px in the Golan and 195 in Galilee,
    # which is the whole of HaZafon inside out.
    splits=[['golan', 'uppergalilee', 35.635, 'lon']],
    regions={
     'judeanhills' : ['Jerusalem'],
     'uppergalilee': [],
     # APPENDED, never inserted: region ids are the dict order, and Greece's
     # ids shifted under a mid-dict insert earlier this campaign.
     'golan'       : ['HaZafon'],
    },
)
# --- palette frozen at 0.9.57 -------------------------------------------------
# Israel shipped two regions at 0.9.57 and is now gaining a third. Without this
# dict `palette.assign` recomputes all three from scratch, and the first run of
# the Golan split duly moved judeanhills from #8BC072 to #2B8268 and
# uppergalilee from #2B8268 to #65AD43 -- two colours restyled on a map that is
# already installed and already screenshotted, to add one region. `assign`
# extends a PARTIAL authored palette, so pinning the two shipped fills leaves
# `golan` as the only key `palette.extend` has to place.
#
# This is not an Israel problem. Every wave-2 country carries it: the moment one
# of them gains a region, its shipped fills move unless they are pinned first.
ISRAEL['fills'] = {
     'judeanhills' : (139, 192, 114),   # #8BC072, as installed
     'uppergalilee': (43, 130, 104),    # #2B8268, as installed
}


LEBANON = dict(
    admin1='lb-governorates.json', subject='Lebanon', log=160, margin=170,
    splits=[],
    regions={
     'bekaa'  : ['Beqaa'],
     'batroun': ['North Lebanon'],
    },
)

CYPRUS = dict(
    admin1='cy-districts.json', subject='Cyprus', log=160, margin=170,
    splits=[],
    regions={
     'commandaria': ['Limassol'],
     'pitsilia'   : ['Nicosia'],
    },
)

TURKEY = dict(
    admin1='tr-provinces.json', subject='Turkey', log=160, margin=170,
    splits=[],
    regions={
     # Cappadocia as a wine area is the whole tuff plateau, not one province.
     'cappadocia': ['Nevsehir', 'Aksaray', 'Nigde', 'Kayseri'],
     'elazig'    : ['Elazig'],
    },
)

ARMENIA = dict(
    admin1='am-provinces.json', subject='Armenia', log=160, margin=170,
    splits=[],
    regions={
     'vayotsdzor': ['Vayots Dzor'],
     'aragatsotn': ['Aragatsotn'],
    },
)

SWITZERLAND = dict(
    admin1='ch-cantons.json', subject='Switzerland', log=160, margin=170,
    splits=[],
    regions={
     'valais': ['Valais'],
     'lavaux': ['Vaud'],
    },
)

UNITEDKINGDOM = dict(
    admin1='uk-counties.json', subject='United Kingdom', log=160, margin=170,
    # Every English wine region is in the south-east, so a frame on the whole
    # island puts Kent at 0.7% of the subject. Frame on the regions; the north
    # still draws, it just bleeds off the margin.
    focus='regions',
    splits=[],
    regions={
     'sussex': ['East Sussex', 'West Sussex'],
     'kent'  : ['Kent'],
    },
)

JAPAN = dict(
    # Two prefectures on a 3,000 km archipelago: at log=160 Yamanashi was 27
    # cells and invisible. A finer canvas AND a frame on the regions, which puts
    # Honshu between Yamanashi and Yamagata across the map; Hokkaido and Kyushu
    # still draw and bleed off the margin.
    admin1='jp-prefectures.json', subject='Japan', log=260, margin=120,
    focus='regions',
    splits=[],
    regions={
     'yamanashi': ['Yamanashi'],
     'yamagata' : ['Yamagata'],
     # Natural Earth spells it with the macron: 'Hokkaidō', not 'Hokkaido'.
     # Fourth name of this class after Republic of Serbia, Bosnia and
     # Herzegovina, and admin-0 Czechia vs admin-1 Czech Republic.
     'hokkaido' : ['Hokkaidō'],         # R208, 14 Sep
    },
)

INDIA = dict(
    admin1='in-states.json', subject='India', log=160, margin=170,
    splits=[],
    regions={
     'nashik'    : ['Maharashtra'],
     'nandihills': ['Karnataka'],
    },
)

CANADA = dict(
    admin1='ca-provinces.json', subject='Canada', log=160, margin=170,
    splits=[],
    regions={
     'ontario' : ['Ontario'],
     'britishcolumbia': ['British Columbia'],
    },
)

MEXICO = dict(
    admin1='mx-states.json', subject='Mexico', log=160, margin=170,
    splits=[],
    regions={
     'guadalupe': ['Baja California'],
     'parras'   : ['Coahuila'],
    },
)

URUGUAY = dict(
    admin1='uy-departments.json', subject='Uruguay', log=160, margin=170,
    splits=[],
    regions={
     'canelones': ['Canelones'],
     'maldonado': ['Maldonado'],
    },
)

MOROCCO = dict(
    admin1='ma-regions.json', subject='Morocco', log=160, margin=170,
    splits=[],
    regions={
     'guerrouane': ['Meknès - Tafilalet'],
     # Grand Casablanca alone is 17 cells. Zenata sits on the coastal plain
     # east of Casablanca, which is Chaouia-Ouardigha.
     'zenata'    : ['Grand Casablanca', 'Chaouia - Ouardigha'],
    },
)

AUSTRALIA = dict(
    admin1='au-states.json', subject='Australia', log=160, margin=170,
    exclude=['Lord Howe Island', 'Macquarie Island', 'Jervis Bay Territory'],
    splits=[],
    regions={
     'southaustralia'      : ['South Australia'],
     'westernaustralia': ['Western Australia'],
     'newsouthwales' : ['New South Wales'],
     'tasmania'     : ['Tasmania'],     # R200, authored 14 Sep
    },
)

USA = dict(
    admin1='us-states.json', subject='United States of America', log=160, margin=170,
    # Alaska and Hawaii are back in, on the maintainer's order of 14 Sep. They
    # carry no catalog wine region, so they paint as country ground (255) rather
    # than as a region. `focus='regions'` is what makes that free: the frame is
    # sized on the four painted states, so putting two more states into FEAT
    # cannot move the canvas.
    exclude=[],
    focus='regions',
    # Pinned to the value the lower-48 map shipped with. Re-including Alaska and
    # Hawaii changes the mean-of-rings latitude — the Aleutians alone are dozens
    # of rings at 52N — which would move x_factor, the projection, the canvas and
    # therefore every index byte of California, Oregon, Washington and New York.
    # The islands are meant to appear ON the shipped map, not to redraw it.
    x_factor=0.78826908,
    # Maui is ~1,900 km2 and a USA cell is ~28 km, so the whole of Hawaii is a
    # handful of cells — under the 20-cell speck floor, which would delete the
    # islands the order exists to restore. Same override Greece needs for
    # Santorini.
    min_island=2,
    splits=[],
    regions={
     'california': ['California'],
     'oregon'    : ['Oregon'],
     'washington': ['Washington'],
     'newyork'   : ['New York'],
    },
)

BRAZIL = dict(
    admin1='br-states.json', subject='Brazil', log=160, margin=170,
    focus='regions',
    splits=[('serragaucha', 'campanha', -30.0)],
    regions={
     'serragaucha': ['Rio Grande do Sul'],
     'campanha'   : [],
    },
)

CZECHIA = dict(
    admin1='cz-regions.json', subject='Czech Republic', log=160, margin=170,
    splits=[('mikulovska', 'znojemska', 16.35, 'lon')],
    regions={
     'mikulovska': ['Jihomoravský'],
     'znojemska' : [],
    },
)

GERMANY = dict(
    admin1='de-states.json', subject='Germany', log=160, margin=170,
    splits=[('rheinhessen', 'mosel', 7.4, 'lon'), ('rheinhessen', 'pfalz', 49.65)],
    regions={
     'mosel'      : [],
     'rheingau'   : ['Hessen'],
     'franconia'  : ['Bayern'],
     'rheinhessen': ['Rheinland-Pfalz'],
     'pfalz'      : [],
    },
)

# SOUTH AFRICA IS ONE AREA: the Western Cape, named for itself.
#
# It shipped at 0.9.57 as four areas cut out of the province with three chained
# latitude lines, and on the device it read as horizontal stripes across the
# Cape. The projection was never wrong — Cape Town landed in `stellenbosch`,
# Robertson in `paarl` — but the boundary was invented, and an invented boundary
# that looks authoritative is the failure this pipeline is built to avoid.
#
# Option 1 was real Wine of Origin district polygons, the way Weingesetz § 21
# unblocked the Wachau. It is not available, and the reason is specific rather
# than a shrug:
#
#   - The WO districts ARE gazetted, under the Liquor Products Act scheme
#     administered by SAWIS and the Wine and Spirit Board. But the published
#     instrument (WOSA's "Production areas defined in terms of the Wine of
#     Origin scheme", Feb 2026) is a REGISTER OF NAMES — producers against
#     district names and approval dates. It carries no boundary description, no
#     co-ordinates and no map. The Wachau worked because § 21 Abs. 3 Z 1 lit. k
#     names eight Gemeinden I already had geometry for; there is no equivalent
#     sentence here.
#   - SAWIS publishes district maps as images, not as data.
#   - The one open mirror that carries wine-region polygons
#     (github.com/dlau/wineregions) states it is "a mirror of sources found on
#     the internet" with no provenance and no licence, and has no South Africa
#     file in any case. A polygon whose origin cannot be named is not citable.
#   - Municipal boundaries are open and tempting and WRONG. WO Paarl is not
#     Drakenstein LM (which also contains Wellington, a separate WO district
#     since 2012), and WO Stellenbosch runs past Stellenbosch LM toward the
#     Eerste River mouth. Substituting them would replace a boundary that looks
#     invented with one that looks official and is still not the gazetted area.
#
# So: option 2, the maintainer's own ruling for British Columbia and South
# Australia. One painted area, the province, honestly named. Stellenbosch,
# Paarl & Franschhoek, Swartland and Walker Bay pin to it and share it, and the
# province page lists them inside it — exactly as Okanagan Valley shares
# `britishcolumbia` and Barossa shares `southaustralia`. Sommbot writes the
# Western Cape entry; until then the four districts keep this area alive.
SOUTHAFRICA = dict(
    admin1='za-provinces.json', subject='South Africa', log=160, margin=170,
    # Framed on the country now, not on the Cape. `focus='regions'` and the
    # 16-26E / -35.5 to -30 crop are both gone: the crop cut the eastern half
    # off and the silhouette did not read as South Africa, which was half the
    # device complaint.
    #
    # The window stays, widened to the mainland, and it is here for ONE reason:
    # Natural Earth files the Prince Edward Islands — Marion Island, 37.7E
    # 46.9S, 1,800 km into the Southern Ocean — as polygons 1 and 2 of the
    # WESTERN CAPE feature. A unit-level `exclude` cannot reach inside a
    # MultiPolygon. Unfiltered they take the frame from 16.5-32.9E / -34.8 to
    # -22.1 out to 16.5-38.0E / -47.0 to -22.1 — roughly double, with the
    # country in one corner. `frame_window` filters by ring centroid and Spain
    # already uses it without `focus` for the Canaries; this is the same use.
    frame_window=(15.0, -36.0, 34.0, -21.0),
    splits=[],
    regions={
     'westerncape': ['Western Cape'],
    },
)
# Not pinned: the four stems this replaces are gone, so there is no installed
# fill to preserve. `westerncape` is a new key and `palette.assign` places it.

COUNTRIES.update({
    'greece': GREECE,
    'georgia': GEORGIA,
    'croatia': CROATIA,
    'hungary': HUNGARY,
    'romania': ROMANIA,
    'bulgaria': BULGARIA,
    'moldova': MOLDOVA,
    'ukraine': UKRAINE,
    'serbia': SERBIA,
    'slovakia': SLOVAKIA,
    'slovenia': SLOVENIA,
    'israel': ISRAEL,
    'lebanon': LEBANON,
    'cyprus': CYPRUS,
    'turkey': TURKEY,
    'armenia': ARMENIA,
    'switzerland': SWITZERLAND,
    'unitedkingdom': UNITEDKINGDOM,
    'japan': JAPAN,
    'india': INDIA,
    'canada': CANADA,
    'mexico': MEXICO,
    'uruguay': URUGUAY,
    'morocco': MOROCCO,
    'australia': AUSTRALIA,
    'usa': USA,
    'brazil': BRAZIL,
    'czechia': CZECHIA,
    'germany': GERMANY,
    'southafrica': SOUTHAFRICA,
})
