# Paste this into the art session — outlying islands

> Maintainer order, 14 Sep: **Alaska and Hawaii on the USA map, outlying
> territories generally, and every outlying island that is a real wine region
> painted as one** — Canaries, Madeira, Balearics, Azores named; Tasmania and
> Crete are the same case.
>
> I measured every wine island against the shipped maps before writing this,
> so the table below is what the rasters actually say, and each row traces to a
> line in `countries.py`. Nothing here is a guess about the code — the
> mechanism is your `exclude` list, which drops named admin-1 units *before*
> projection, plus the 20-cell `MIN_ISLAND` speck filter.
>
> | Island | Map | On canvas? | Index at its centre | Why | Catalog entry |
> |---|---|---|---|---|---|
> | Alaska | usa | yes | 0 (not the country) | `countries.py:666` `exclude=['Alaska', 'Hawaii']` | none — paint as country ground (255) |
> | Hawaii | usa | yes | 0 | same line | none — 255 |
> | Puerto Rico | usa | yes | 0 | not an admin-1 unit of the USA in NE; separate feature | none — leave unless trivially includable |
> | Canary Islands | spain | yes | 0 | `countries.py:140` excludes `Las Palmas`, `Santa Cruz de Tenerife` | **`R063` Canary Islands** — paint as a region |
> | Mallorca | spain | yes | painted `baleares` | already right | `R120` |
> | Madeira | portugal | **no — misses the left edge by 0.1°** (canvas runs to −16.8, Madeira is −16.9) | — | `countries.py:164` `exclude=['Azores', 'Madeira']` | **`R081` Madeira** |
> | Azores | portugal | **no — 8–15° off the left edge** | — | same line | **`R121` Azores** (and `G151` Arinto dos Açores points at it) |
> | Tasmania | australia | yes | 255 (country, unpainted) | no region claims `Tasmania` | **being authored now** by sommbot |
> | Crete | greece | yes | 255 | no region claims `Kriti` | **being authored now** by sommbot |
> | Hvar / Dalmatian islands | croatia | yes | 0, backdrop reads *shelf* | no exclude — **despeckled**: `MIN_ISLAND = 20`, no `min_island` override (Greece has one at `:417` for exactly this reason) | `R093` Dalmatia — the islands belong inside the existing `dalmatia` area |
> | Hokkaido | japan | **no** | — | your `focus='regions'` reframe for Yamanashi | none in catalog — **flag only**, not this batch |
> | Corsica, Sicily, Sardinia, Santorini, Waiheke | — | yes | painted | already right | — |
>
> ## What to do, per map
>
> **USA** — take Alaska and Hawaii out of `exclude`. `focus='regions'` is
> already set, so the frame is sized on the four painted states and putting the
> two back into `FEAT` should not move the canvas; my probe says both already
> land on it. Two things to check: (1) that the canvas, projection and
> `subject_rect` come back byte-identical — if `focus='regions'` really frames
> on the regions, they will; (2) **Hawaii will probably despeckle.** Maui is
> ~1,900 km², which at the USA's ~3.5 cells/degree is a few cells — under the
> 20-cell filter. It needs a `min_island` override the way Greece has. Both
> land as 255 (country ground, unpainted): there is no Alaska or Hawaii region
> in the catalog and the maintainer has not asked for one.
>
> **Spain** — take the two Canary provinces out of `exclude` and add a region
> `canaryislands: ['Las Palmas', 'Santa Cruz de Tenerife']`. They are *already
> on the canvas* (Tenerife is inside it now, as index 0), so the frame need not
> change — but Spain has no `focus`, so the frame is sized on the whole country,
> and the whole country will now include 28°N/−18°. Pin it: a `frame_window`
> equal to the current frame keeps `MN`, `W`, `H` and therefore every existing
> index byte where it is. That is the contract: the seven existing Spanish
> regions' index bytes must come back identical.
>
> **Portugal** — this one moves the canvas, and there is no way round it. Madeira
> is a tenth of a degree off the left edge; the Azores are fifteen. Take both out
> of `exclude`, add `madeira: ['Madeira']` and `azores: ['Azores']`, and let the
> canvas grow west. Mainland Portugal will occupy roughly a third of the width.
> **On the globe that is fine, on one condition**: `subject_rect` must stay on
> the mainland. The app frames the initial view on `subject_rect` and fences the
> camera to the whole canvas, so a mainland `subject_rect` means the map opens
> on Portugal as it does today and a pan west reaches the islands. If
> `subject_rect` is computed from the country's full extent it will open on
> the Atlantic. You know whether that needs a per-country override or a
> "largest landmass cluster" rule in the generator; either is fine by me, and
> the second is the one that also survives the next island. Say which you did.
>
> **Croatia** — a `min_island` override so Hvar, Brač, Korčula and Pelješac
> survive, and confirm they rasterise into `dalmatia` (they are in
> `Splitsko-Dalmatinska` and `Dubrovacko-Neretvanska`, both already in that
> area's units). No canvas change.
>
> **Australia and Greece** — wait for sommbot's entries to land (Tasmania,
> Crete), then `tasmania: ['Tasmania']` and `crete: ['Kriti']`. No canvas
> change on either; both are inside the frame already.
>
> **Japan / Hokkaido** — not this batch. There is no Hokkaido entry, and
> reaching it undoes your Yamanashi reframe. Noted for the maintainer.
>
> ## Stem naming — a rule the app now enforces
>
> `RegionMapTests.displayNamesNameTheArea` holds every painted area to naming
> *itself*: the stem, folded, must be contained in the display name, folded, or
> vice versa. The display name is the catalog's name. So a new stem should be
> the catalog name folded flat: **`canaryislands`** (not `canarias`), `madeira`,
> `azores`, `tasmania`, `crete`. Give me the stems and I add the display-name
> rows on my side before your drop lands, so nothing shows as a bare upper-cased
> stem for a build.
>
> ## The contracts, restated for this batch
>
> Spain, USA, Croatia, Australia, Greece: **canvas, projection, `subject_rect`
> and every existing region's index byte unchanged**. I will diff all of them
> the way I did the backdrop drop — pixel hash of each `-index.png` masked to
> the existing region bytes, since new bytes will legitimately appear where
> islands were 0 or 255.
>
> Portugal: canvas and projection *will* change; `subject_rect` must not
> follow the islands; the seven existing regions must come back as the same
> shapes in the new projection, which `verify_extracts` should be able to say.
>
> ## One thing I found that is not yours — for the maintainer
>
> Several maps are painted at admin-1 and named after the one appellation the
> catalog holds inside them, which is the California/Napa problem the
> maintainer just ruled on, one level up:
>
> | Map | Stem | Display name | What the area actually is |
> |---|---|---|---|
> | canada | okanagan | OKANAGAN VALLEY | all of **British Columbia** |
> | canada | niagara | NIAGARA PENINSULA | all of **Ontario** |
> | australia | barossa | BAROSSA VALLEY | all of **South Australia** |
> | australia | margaretriver | MARGARET RIVER | all of **Western Australia** |
> | australia | huntervalley | HUNTER VALLEY | all of **New South Wales** |
> | greece | santorini | SANTORINI | all of **Notio Aigaio** (the South Aegean) |
>
> Tapping the whole of British Columbia and being told it is the Okanagan is
> the same defect as Oregon reading WILLAMETTE VALLEY was. Whether the fix is
> province pages like the US states, province region entries, or finer art, is
> the maintainer's call and I have put it to him. Don't act on it.
