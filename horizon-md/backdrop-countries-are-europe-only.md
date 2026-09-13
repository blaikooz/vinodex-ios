# To the art session — every backdrop draws the same 108 countries

Found on 13 Sep while chasing a striping bug on Canada. It is one line in
`region_map.py`, and it costs twelve of the thirty-nine maps their neighbours.

## What the manifests say

Every `<country>-manifest.json` carries a `backdrop.countries` list — the
foreign land the backdrop paints around the subject. I unioned all thirty-nine
of those lists:

```
union across all 39 maps: 108 names
```

One hundred and eight. Each map's own list is the same 108 minus itself, plus
itself where it is not the subject. It is not a per-map neighbourhood; it is
one fixed list reused thirty-nine times.

And the list is Europe-shaped. Sorted, it runs Akrotiri → Yemen: Europe, North
Africa, the Middle East, plus **Greenland**, **Russia** and **Kazakhstan** —
exactly what a Europe-centred bounding box catches at its edges.

```
any Americas present anywhere: []          # not one, on any map
any Asia/Oceania present anywhere: ['Kazakhstan']
```

## What that looks like on the device

Twelve maps have no neighbour the generator is able to draw:

`argentina · australia · brazil · canada · chile · china · india · japan ·
mexico · newzealand · uruguay · usa`

On those, everything outside the subject is `backdrop.sea`. The USA map is a
silhouette floating in open ocean with a **dead-straight 49th parallel** along
its top, because Canada is not in the list and the border is where the land
stops. Canada has the mirror image of the same edge, and its only foreign
landmass anywhere on the canvas is Greenland — which is how a striping artifact
over Greenland came to be the *only* neighbour visible on that map, and why it
was so conspicuous.

Meanwhile Lebanon, Italy and every other European map draw their neighbours
correctly, which is why this went unnoticed through three drops.

## Why it is yours and not mine

The app reads the backdrop as an opaque picture — contract 4 of the drop audit,
compute nothing the manifest computed. There is no Swift-side repair: if the
art paints the USA as sea, the USA is sea. The fix is whatever produces that
`countries` list in `region_map.py` taking the *subject's own* canvas extent
instead of a constant, and re-rendering the twelve.

Nothing else needs to change. The list is already in each manifest, so the
count will tell you it worked without opening a single PNG:

```python
len(json.load(open(f'{k}-manifest.json'))['backdrop']['countries'])
```

Today that returns 107 or 108 for all thirty-nine. Afterwards Canada's should
be small and should contain `United States of America`, and Japan's should
contain `South Korea`.

## Two things this does not change

**The pole clamp is mine and is already done.** Canada's canvas runs to
128.2°N — thirty-eight degrees past the pole, empty blue padding from the
502-cell canvas height. The globe's mesh folded it over the pole onto the near
hemisphere and z-fought, which is what the striping actually was. `RegionMap.canvasBounds`
now clamps to ±90 and `RegionMapTests.canvasBoundsAreReal` holds it there. **You
do not need to trim the canvases** — the padding is harmless once it is clamped,
and re-rendering to a different height would churn every index raster.

**Greece is still the next country**, per the queue note of the same date. This
is a re-render of existing maps, not new art, so it does not displace it — but
it does outrank Greece if you would rather ship twelve corrected maps than one
new one.
