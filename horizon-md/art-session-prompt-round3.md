# Paste this into the art session — round three: the maintainer's rulings on your close-out

> Thank you for the close-out. All four parked decisions are ruled, and the
> manual rewrite is approved. In the order I'd take them:
>
> ## 1. Rewrite `horizon-md/art-session-prompt.md` — approved
>
> Yes. Write it from what this campaign taught; I'll review it against the
> app-side contracts (index raster is data, floor not round, the five drop
> contracts, the two-file pins trap) before it's committed. The old §6 line
> about docs going stale in days is the honest frame — keep it.
>
> ## 2. Wachau goes on the second plane — and only Wachau, before 1.0
>
> The maintainer's list is one item. Austria gets `austria-index2.png` with
> Wachau as a child of `niederosterreich`, a `children` block in the manifest,
> and `map-wachau.png`, exactly as France carries Sauternes and Châteauneuf.
> The catalog entry exists and has been the one unpinned id all day; pin it
> to the child stem `wachau`. Your own ruling stands — *a wrong boundary is
> worse than an absent one* — so if the Wachau polygon you can source isn't
> the DAC boundary, say so and stop rather than approximate. The other 36
> shared areas wait for 1.1.
>
> ## 3. Re-author six globe fills
>
> The proper fix, as you said: six of the thirty authored country colours
> re-chosen so they survive the app's brighten step with a real ΔE between
> every neighbouring pair on glass. You have the measurement; you pick the
> six. Nothing changes in Swift. `globe-meta.json` and the rebuilt texture
> come through as a coupled drop and I'll re-shoot the globe.
>
> ## 4. Crimea is painted as Ukraine
>
> Ruled: override Natural Earth for those polygons. On the globe raster, the
> Crimean peninsula carries Ukraine's byte; on Ukraine's region-map backdrop
> and subject mask it is Ukraine, not foreign land. Ukraine's outline art
> under `entries/countries/` already includes it, so nothing there moves —
> and per the standing rule I don't touch those files anyway. Record it in
> the drop as a deliberate override so nobody later "fixes" it back to the
> source.
>
> ## 5. A Golan Heights region, painted under Israel
>
> Ruled, with eyes open: a painted area and an entry, filed under Israel.
> The entry exists — `R215`, prose states the territory's status in one
> clause — and its pin is in `make_pins.py` under a new `ISRAEL` table,
> seat Katzrin, expected stem `golan`. Sommbot checked the source layer so
> you don't have to: **`il-districts.json` carries no Golan unit at all** —
> the plateau sits inside HaZafon, which is already `uppergalilee`. So this
> is not the Crimea case (reassigning a polygon that exists); it is a
> **geometry split**, the Beaujolais 45.62°N pattern — cut HaZafon along
> the Jordan/Hula line so the plateau east of it becomes `golan`. Say what
> line you cut on and record it as a deliberate override in the drop.
>
> ## Stems, so display names land the same day
>
> `wachau` (child), `golan`. I'll add the rows when you confirm.
>
> ## What is not in this round
>
> Nothing else. The queue after this is empty until the maintainer opens
> 1.1, and the 36 remaining shared areas are the first thing in it.
