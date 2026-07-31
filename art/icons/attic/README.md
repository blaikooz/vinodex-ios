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

## Everything else

Earlier unreferenced pieces (`grape-*`, `greenpear`, `oakbarrel`, plus
`gsmblend` and `freshchillablered`, which lost their entries when GSM Blend
moved to a class glyph and the chillable-red stems were untangled).
