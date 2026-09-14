# Paste this into the art session

> There is a defect in the backdrop generator. I found it on 13 Sep chasing a
> striping bug on Canada, and it is one line in `region_map.py` that costs
> twelve of the thirty-nine maps their neighbours.
>
> The write-up is at **`horizon-md/backdrop-countries-are-europe-only.md`** in
> `vinodex-ios`. Read that first — it has the evidence, the twelve affected
> maps, why there is no Swift-side repair, and the one-line manifest check that
> will tell you a re-render worked without opening a PNG.
>
> The short version: `backdrop.countries` is the **same 108-name list in all
> thirty-nine manifests**. Europe, North Africa, the Middle East, plus
> Greenland, Russia and Kazakhstan — exactly what a Europe-centred bounding box
> catches at its edges. Not one country in the Americas appears on any map. So
> Canada, the USA, Mexico, Brazil, Argentina, Chile, Uruguay, China, India,
> Japan, Australia and New Zealand all render their neighbours as open sea. The
> USA is a silhouette floating in ocean with a dead-straight 49th parallel
> along its top, because Canada is not in the list and the border is where the
> land stops.
>
> What I think the fix is: whatever builds that list should take the
> **subject's own canvas extent** instead of a constant, then re-render the
> twelve. I have not touched `region_map.py` and I am not going to — it is
> yours.
>
> Two things it is **not**:
>
> - **Do not re-render to a different canvas height.** Canada's canvas runs to
>   128.2°N because every country gets the same 502 cells and the rest is
>   padding. That padding was folding over the pole on the globe's mesh and
>   z-fighting with itself, which is what the striping actually was — but I
>   fixed that on my side (`RegionMap.canvasBounds` clamps to ±90, pinned by
>   `RegionMapTests.canvasBoundsAreReal`). The padding is harmless now, and
>   changing the canvas height would churn every index raster for nothing.
> - **Do not touch the index rasters or the manifests' projections.** This is a
>   backdrop-only re-render. The five contracts from AUDIT §3 all still hold,
>   and if a re-render moves `base.canvas`, `projection`, or any
>   `regions[].index`, something has gone wrong — stop and say so.
>
> Priority is yours to judge against Greece, which the 13 Sep queue note has as
> the next new country. This is twelve corrected maps versus one new one; I
> would take the twelve, but I am not the one holding the queue.
>
> When it lands, tell me and I will re-run the globe screenshots for the
> affected countries.
