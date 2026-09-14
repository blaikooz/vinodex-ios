# Paste this into the art session — round two, after the maintainer's rulings

> The maintainer ruled on everything in the islands brief
> (`horizon-md/art-session-prompt-islands.md`) and on the batch that came out
> of it. This supersedes the open questions there; the per-map instructions
> in it still stand unless changed below.
>
> ## Rulings that touch your files
>
> **Portugal opens on the mainland.** `subject_rect` stays on the mainland when
> the canvas grows west for Madeira and the Azores; the fence lets a pan reach
> the islands. Implement it however survives the next island — a per-country
> override is fine, a "largest landmass cluster" rule is better. Say which.
>
> **Alaska and Hawaii are country ground, unpainted (255).** No region for
> either. Hawaii will need a `min_island` override or it despeckles.
>
> **Hokkaido is in.** Sommbot is authoring the entry now. Reframe Japan to reach
> it — that undoes the Yamanashi tightening unless you use a second window, and
> you will know better than me whether `frame_window` can carry two. Yamanashi
> at 27 cells was the reason for the tight frame; if Hokkaido forces the
> country frame back, say what Yamanashi ends up at and the maintainer can
> rule again. Stem `hokkaido`, unit `Hokkaido`.
>
> **Rueda & Toro splits.** Cut the merged Spanish area into `rueda` and `toro`.
> The catalog already has both (`R034`, `R113`); no entry work. This is an
> index-raster change on Spain, alongside the Canaries — do both in one Spain
> render so the contract is checked once.
>
> **All three weak areas stay painted** — Waikato & Bay of Plenty, Molise,
> Córdoba. Entries are authored and honest about their size.
>
> ## Seven stem renames — no byte changes, just the key
>
> The app now holds every painted area to naming itself: stem folded must be
> contained in the display name folded, or vice versa, and the display name is
> the catalog's name. Seven stems fail that once the new entries land, all for
> the same reason — the area is an admin-1 unit named after the one
> appellation inside it. The maintainer chose province entries (sommbot is
> authoring them), so the stems become the province:
>
> | Map | Old stem | New stem | The area is |
> |---|---|---|---|
> | canada | `okanagan` | `britishcolumbia` | British Columbia |
> | canada | `niagara` | `ontario` | Ontario |
> | australia | `barossa` | `southaustralia` | South Australia |
> | australia | `margaretriver` | `westernaustralia` | Western Australia |
> | australia | `huntervalley` | `newsouthwales` | New South Wales |
> | greece | `santorini` | `southaegean` (sommbot will confirm the catalog's spelling) | Notio Aigaio |
> | newzealand | `waikatobop` | `waikatobayofplenty` | Waikato & Bay of Plenty |
>
> A rename is the `regions` key in `countries.py` and therefore in the
> manifest, `region-index.json` and the `map-<stem>.png` detail file name. The
> index byte does not change. I will change the display-name rows on my side
> the same day; tell me the stems you settle on before you render so the two
> land together.
>
> ## Pins are coming from sommbot, not from you
>
> Sommbot is authoring the seat coordinates for its 34 new regions (and the
> provinces, Hokkaido and six more) directly into `make_pins.py`, and running
> `make_pins.py` / `region_check.py` per country. You do not need to author
> pins for this batch. Where a pin fails to land after your renames, that is
> the stem mismatch above, not a geometry problem.
>
> ## Order I would take, if it is yours to choose
>
> 1. Spain — Canaries in, Rueda/Toro split, frame pinned. One render, one
>    contract check.
> 2. USA — Alaska and Hawaii back, `min_island` for Hawaii.
> 3. Croatia — `min_island` so Dalmatia's islands survive.
> 4. Renames — the seven stems, no re-render needed beyond re-emitting
>    manifests and detail file names.
> 5. Portugal — the canvas change, with the mainland `subject_rect`.
> 6. Japan — Hokkaido reframe.
> 7. Australia and Greece — `tasmania`, `crete` once the entries have pins.
>
> Same verification on my side as the backdrop drop: pixel hash of every
> index raster masked to the existing region bytes, plus manifest fields.
