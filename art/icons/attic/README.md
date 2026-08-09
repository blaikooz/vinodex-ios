# attic — drawn but unreferenced, kept so nothing is lost

Nothing here is read by the pipeline. `art_common.resolve_source_dir` only
looks in the named use-folders (`flavors/`, `styles/`, `subclasses/`, …), so a
file parked here ships nowhere — it is kept because deleting art is not
reversible in any way that matters.

## `legacy-*` (0.6.5, batch 4 phase 2)

The 27 files prefixed `legacy-` came from `shared/newicons/`, the pre-H12 art
master, when that tree was retired. Every other file there (271 of them) was
byte-identical to something already under `art/icons/`, so it was dropped
safely; these 27 shared a **name** with a live asset but not its **bytes**,
which makes them earlier or alternate takes rather than duplicates. The name
records where each came from — `legacy-classes-berry.png` was
`shared/newicons/classes/berry.png`.

Two worth knowing about:

- `legacy-cherry.png` (101,737 B) is the original of `art/icons/flavors/cherry.png`
  (58,954 B). The live one is the reworked master; this is what it replaced.
- The `legacy-2new-*` set is the pre-0.6.5 style portraits, superseded by the
  `newpass` drop that landed in `art/icons/styles/`.

## `alt-marquee-*` (0.8.9a, A2)

Two files from the v9.0 drop that redraw marquee glyphs already on disk:
`alt-marquee-labelscanner.png` is the bottle the panel shows for LABEL SCAN,
`alt-marquee-flavorscan.png` the cherry pair it shows for FLAVORS. Both are the
right register (no cel outline, magenta key) and both are *larger* than the set
they would join — roughly 320px against the 110-160px the 0.8.4 drop was drawn
at — and both carry scan-reticle corner brackets that no other one of the
thirty-four has.

So adopting them was a look decision, not a wiring one, and it was declined
this pass: the marquee draws these silhouetted at one size, so a finer dot pitch
on two glyphs out of thirty-four reads as an inconsistency rather than as
detail. Parked instead of dropped because it is one `git mv` each to reverse,
and because the same drop's `soilscan` and `stamps` — genuinely new names —
carry the brackets too and did ship.

## Everything else

Earlier unreferenced pieces (`grape-*`, `greenpear`, `oakbarrel`, plus
`gsmblend` and `freshchillablered`, which lost their entries when GSM Blend
moved to a class glyph and the chillable-red stems were untangled).
