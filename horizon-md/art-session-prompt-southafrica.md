# Paste this into the art session — South Africa reads as stripes

> Device feedback, 14 Sep: **"south africa region map is way off."** I measured
> before writing this, and the projection is fine — Cape Town lands in
> `stellenbosch`, Robertson in `paarl`, the manifest formula and the raster
> agree. What is off is the *art*: the regions were cut with straight
> latitude/longitude lines (the "chained axis cuts" that brought South Africa
> off the blocked list), so on the sphere Stellenbosch and Paarl are horizontal
> bands across the Western Cape, and the frame (`frame_window=(16,-35.5,26,-30)`)
> crops the eastern half of the country so the shape does not read as South
> Africa.
>
> The same class of problem as Germany (Mosel, Rheinhessen, Pfalz all inside
> Rheinland-Pfalz): admin-1 does not carry the wine geography, and axis cuts
> are a boundary nobody can check — your own rule, *a wrong boundary is worse
> than an absent one*.
>
> ## What I would do, in order of preference
>
> 1. **Real district polygons.** South Africa's Wine of Origin districts and
>    wards are gazetted (the Liquor Products Act scheme, administered by SAWIS
>    / the Wine and Spirit Board), and WOSA publishes district maps. If a
>    citable boundary source is reachable — the way Weingesetz §21 unblocked
>    the Wachau — this is the right fix: Stellenbosch, Paarl, Swartland,
>    Constantia and the rest as their own shapes.
> 2. **Fall back to the province ruling.** If no source is reachable, paint the
>    **Western Cape** as one area (units `['Western Cape']`), named for itself,
>    and let the districts sit inside it as shared rows — exactly what the
>    maintainer ruled for British Columbia and South Australia. Sommbot authors
>    a Western Cape entry; the province page lists the districts INSIDE IT.
>    Honest, and it reads as the map it is.
> 3. **Either way, frame on the country.** Drop the tight window so South
>    Africa's outline is South Africa's — the Cape regions are large enough at
>    the country frame, and the current crop is half the complaint.
>
> Do not keep the axis cuts. Say which of 1 or 2 you took and why, and the
> usual contract check applies: it is a South Africa-only re-render, canvas
> allowed to move, index raster and manifest landing together.
