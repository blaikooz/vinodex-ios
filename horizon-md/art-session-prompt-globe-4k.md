# Paste this into the art session — a sharper globe

> Device feedback, 14 Sep: *"any way to increase resolution of the countries
> so they dont look blurry when selected?"* Tapping a country zooms the globe
> to fill the glass with it, and at that magnification the 2048×1024 texture
> shows its texels — Italy owns about 68 of them. The app now magnifies with
> nearest-neighbour so they read as crisp pixels rather than smeared ones,
> which is the register the device draws in, but the underlying answer is
> more texels.
>
> ## Ask
>
> `globe_tex.py` renders at `W, H = 2048, 1024` (line 85). Render the
> **texture** at **4096×2048** — `globe-wine.png` and the intermediate it is
> colourised from. The country list, fills and everything else unchanged.
>
> Two things to decide on your side, and say which:
>
> 1. **The index raster.** `globe-index.png` is the hit-test data the app reads
>    on a tap. It can stay at 2048×1024 — a tap does not need 4K precision, and
>    `GlobeIndex` reads it into memory — or go to 4096 with it (8 MB of bytes
>    on the device, fine either way). If both come from one render, emit the
>    texture at 4096 and downsample the index with nearest, *never* linear: an
>    index byte that gets averaged is a country that does not exist.
> 2. **Size.** A 4096×2048 RGB PNG of flat fills compresses well — expect
>    under 300 KB. If it comes out over a megabyte something is not flat.
>
> Do not go to 8192: 128 MB of texture memory on the sphere is not worth it,
> and the region maps already give every country a close-up that is drawn
> from its own art.
>
> ## Contract
>
> Coupled drop as always: texture and meta together; the index raster's
> bytes unchanged if you keep it at 2048, or pixel-verified against the old
> one at 2× if you regenerate it. I re-shoot the globe and three selected
> countries on landing.
