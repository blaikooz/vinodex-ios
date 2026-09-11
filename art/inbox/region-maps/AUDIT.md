# Pre-handoff audit — wine region maps and Globe Scan

Written before this goes to the Swift side. Everything below is a check that was
**run**, not a claim. Five things broke during the audit and are fixed; two are
open and need a decision from you or from the implementer.

**Revision 2** — §1.4 and §1.5 were open in revision 1 and are now closed: the
app hit-tests an index raster instead of a pixel colour, which removes the whole
class of failure and takes the cross-country palette collision with it.

Audited: `art/inbox/region-maps/` at 114 PNGs / 0.90 MB, seven countries,
85 regions, 30 wine countries on the globe.

---

## 1. What the audit found

### 1.1 FIXED — Madrid was in La Mancha on the globe, not on the flat map

The two pipelines disagreed on 3 of 149 pins. The globe's region rasters painted
regions **first-come-first-served** — visually identical to the flat maps until
you notice it hands every shared border to whichever region the config happens to
list earlier. Madrid is a province wholly enclosed by La Mancha, so it lost.

Now both pipelines use the same rule: a contested cell goes to whichever region
covers more of it. **147 of 149** after the fix.

The lesson generalises: *two pipelines that agree on a picture can still disagree
on an answer.* The cross-check that caught it is in §2 and should stay in CI.

### 1.2 FIXED — two harbour towns resolved to nothing

Alicante and Málaga sit one cell seaward of the rasterised coast, so a tap there
found sea. The flat maps already had the answer — resolve a tap to the *nearest*
region, not only the one under the finger — and the globe now does the same, out
to 3 cells. **149 of 149.** Drawing is untouched: the coast still looks like the
coast; only the tap is forgiving.

### 1.3 FIXED — detail maps ignored every split

Region detail maps were re-rasterised from their unit lists rather than cut from
the masks the base map painted, which meant they silently dropped both splits.
France's Beaujolais and Rhône detail maps were wrong from the day they were made.
Now cut from the masks, so base map and detail map cannot diverge.

### 1.4 FIXED — fills repeat across countries, and no longer matter

85 region fills, **35 distinct**. 50 are reused between countries.

That is by design: the palette is computed per country, and two regions that
never appear on screen together are free to share a colour. Under the old
colour-matching contract it was a trap — a single global dictionary built from
all seven manifests would have collapsed 85 regions into 35 and mis-resolved
roughly every other tap, silently.

**§1.5 removes the trap rather than documenting it.** Regions are identified by
id now, and ids are per-country by construction. The palette is free to repeat
because nothing resolves by colour any more.

Verified clean within each country: no duplicate fill inside any of the seven,
and no region fill collides with any reserved colour (chroma key `#EE03E1`,
unassigned stone `#CEC6BA`, outline ink `#1A1420`, sea `#38506B`, shelf
`#4E6985`, foreign land `#8C8778`).

### 1.5 FIXED — colour-matching was the wrong contract for iOS

The flat maps ask the app to identify a region by reading a pixel and matching
its RGB exactly. That works in a browser. On iOS it is fragile in three separate
ways, none of which will announce itself:

- **Colour management.** The PNGs carry **no ICC profile** (checked: every one).
  An untagged PNG is assumed sRGB by most of the stack, but if anything in the
  chain treats it as Display P3, or renders through a P3 context, every channel
  shifts by a few counts and exact matching fails everywhere at once.
- **Asset catalogs re-encode.** Xcode may recompress or repack PNGs. Lossless
  today; not a guarantee you want a hit test resting on.
- **Any interpolation is fatal.** The moment the image is drawn scaled with
  smoothing, border pixels become blends of two regions and match nothing.

**Done: the maps no longer ask anyone to match a colour.** Every country now
ships `<country>-index.png` — one byte per logical cell, on exactly the canvas
the manifest describes:

```
0     outside the country (sea, a neighbour, or the coastline ink)
255   inside the country, unassigned ground
1..N  a region — regions[<stem>].id in the manifest
```

14 KB for all seven. The hit test reads an integer no colour pipeline can
perturb, and the palette drops to being a presentation choice that can change
without re-slicing anything.

Two gates keep the two representations honest. `region_map.py` asserts the index
agrees with the masks it painted; `region_check.py` now resolves every pin
**through the index** and separately asserts that every pixel of the shipped art
under a given id carries exactly that region's published fill. Art and index
cannot drift apart without a build failing.

One thing to know: the coastline ink is drawn one pixel *outside* the country, so
it indexes as 0. A tap exactly on the coast resolves through the nearest-region
rule, same as §1.2.

### 1.6 OPEN — nothing here has been seen on a device

Every number in this drop comes from Python and a desktop browser. Not yet
verified on a simulator or a phone: memory footprint of seven index rasters held
resident, decode time at launch, the 44pt tap arithmetic against a real
`.aspectRatio(.fit)` frame, and how the pixel art holds up at 3× on a Retina
panel. The globe prototype has never run anywhere but Chromium.

### 1.7 OPEN — no accessibility pass

The maps carry no labels, no VoiceOver story, and no non-colour way to tell
regions apart. In Amber and Terminal screen modes the region hues collapse to one
hue by design, which makes colour useless as a discriminator for everyone, not
just colour-blind users. A region name in the HUD is the minimum; that is a
design decision, not a bug to fix silently.

---

## 2. Checks that pass, and should stay passing

Run all of them before any change ships. The first is the gate that already
exists; the second is the one this audit added and CI does not have yet.

| Check | How | Result |
|---|---|---|
| Every sample pin resolves to the right region | `region_check.py <country>` | **149/149** across 7 countries |
| Every real catalog row resolves | `region_check.py france pins-france-catalog.json` | **France 20/20, Italy 21/21** |
| Globe rasters agree with the flat maps | cross-check both at every pin | **149/149** |
| Painted canvas matches the published palette | assertion inside `region_map.py` | passes for all 7 |
| Index raster agrees with the painted masks | assertion inside `region_map.py` | passes for all 7 |
| Shipped art agrees with the index, per region | assertion inside `region_check.py` | passes for all 7 |
| No admin-1 unit claimed by two regions | assertion inside `region_map.py` | passes for all 7 |
| Markers never collide at 8 logical px | printed on every render | 0 collisions, all 7 |
| All 30 wine countries survive despeckling | assertion in `globe_tex.py` | passes |
| Region ids fit one byte | max id 31 of 255 | passes |

**France is 20 catalog regions, not the 19 PLAN.md records.** Worth correcting
in PLAN.md.

---

## 3. What the Swift side must honour

Five contracts. Break any one and the failure is quiet.

1. **Hit-test `<country>-index.png`, never a pixel colour.** §1.5. The index is
   at logical scale, not `export_scale` — one byte per canvas cell.
2. **Never re-derive geometry in the app.** The manifest's projection block is
   the single source of truth for lon/lat → canvas; if Swift recomputes it with
   its own constants the two will drift and nothing will say so.
3. **Compute nothing that the manifest already computed.** Button positions are
   poles of inaccessibility, emitted as canvas fractions. 0.8.4 lost 6 of 121
   authored dots to exactly this.
4. **Resolve a tap to the nearest region, not the one under the finger.** §1.2,
   and §6.2 of the handoff for why 44pt buttons cannot fit.
5. **Keep these files away from `outlines:check` and `icons:verify`.** If a gate
   starts walking them, move the files rather than adding an exclusion.

---

## 4. Provenance and licensing

All geometry is **Natural Earth 1:10m**, admin-0 and admin-1, which is in the
**public domain** — no attribution required, though the project credits it
anyway. Nothing here is derived from a licensed dataset, a map service, or a
scraped source, and no network call is made at build time or at run time.

The appellation coordinates in `pins-*.json` are authored from the towns each
appellation is named for. They are a **test fixture**, not catalog data, and must
not be imported.

---

## 5. Recommendation

**Ship the flat maps as a test. Do not ship the globe yet.**

The flat maps are finished work with a gate around them, and the risk that was
worth worrying about — §1.5 — is closed rather than documented. The globe is a
strong prototype with a real interaction model — the index
raster, the mip chain, the second tier — but it has never run outside a desktop
browser, and per-pixel un-projection at 60fps on a phone is exactly the kind of
thing that is fine until it is not. Get it on a simulator behind a flag before
anyone decides it replaces globe scan.

What remains open is §1.6 (nothing has run on a device) and §1.7 (no
accessibility pass). Neither blocks the test; both should be answered before
anything ships to players.
