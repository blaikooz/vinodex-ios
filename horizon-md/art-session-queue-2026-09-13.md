# To the art session — onboarding needs nothing from you

Short note, because the honest answer to "can the art session take some of
this" is **no, and you should not stop what you are doing.**

The maintainer asked me to spec the onboarding rework and to hand you whatever
part of it was yours. Having specced it
(`horizon-md/onboarding-rework-plan.md`), there is no art in it. It is copy,
sequencing and one-shot state: a louder BIOS prompt, four orientation cards
that show live screens behind them, the existing six-step coachmark moved to
the opt-in slot, and an eleven-card walkthrough retired. Where the orientation
cards want a visual they want the app's *own* screens, and where they want a
glyph the existing MarqueeArt and ClassArt sets already carry one. Generating
art for it would be inventing a need.

So this is a queue note instead.

---

## What landed since your drop

**Your 13 Sep drop is merged.** Austria and China are installed and rendering;
the globe is at 34, then 39 after sommbot's batch. `ne.json.gz`,
`geosrc.py`, `verify_extracts.py` and `coverage_check.py` all came with it.

**Sommbot authored five of the six countries you could not reach** — Czechia,
Slovakia, Israel, Ukraine and Serbia — and **declined Bosnia**, partly on the
slug argument you would recognise: an honest origin of "Bosnia and Herzegovina"
does not match the master drawn as `bosnia.png`, and naming it to fit the art
would write the geography error into the data. Blatina and Žilavka are staged
as P1 grapes instead.

**Two Serbia spellings, not one.** `GlobeIndex.catalogName` now maps
`Republic of Serbia → Serbia` so the tap arrives in the right place, and I
added a `LABELS` row in `globe_tex.py` so the tile *says* the right thing. The
first alone left a country tile reading REPUBLIC OF SERBIA above a page headed
Serbia — worth knowing that the two corrections are separate.

**Your transport finding held up on my side.** Nine `rgn-*.png` came through my
re-render byte-different and pixel-identical; I compared them cell for cell and
reverted rather than committing them. The rule you wrote is the right one.

---

## The queue, recomputed against the catalog

The rule from the expansion plan still holds: a region map earns its place when
the country has enough catalog regions to make a multi-colour map mean
something. Below about four it says nothing the outline did not.

| Country | Catalog regions | Status |
|---|---:|---|
| USA | 9 | **Needs a ruling, not work** — see below |
| Greece | 6 | **Next.** Fourteen peripheries; revision 2 notes it needs one split |
| Germany | 5 | **Out.** Three of its five regions — Mosel, Rheinhessen, Pfalz — are all inside Rheinland-Pfalz. No admin-1 split separates them; it needs Landkreise or real Anbaugebiete polygons |
| South Africa | 4 | After Greece |
| The five new countries | 2 each | **Not yet.** A two-colour map is not a map |

**Greece is the only clean next job.**

---

## Two things that outrank another country

**1. The 25 dead painted areas.** `coverage_check.py` still reports 92 areas,
25 dead, 15 shared. That is catalog work rather than art — it is sommbot's, and
it is queued — but it is the reason not to paint Greece first. Twenty-five
areas already say NO CATALOG ENTRY HERE YET on art that was paid for and is on
screen; Greece would add six more good regions to that set.

**2. The second index plane.** `horizon-md/index2-agreed.md` is agreed between
us and unbuilt. Six regions need it — Wachau, Sauternes, Etna, Valpolicella,
Collio and Châteauneuf-du-Pape. Austria is already shipping 3 painted areas
against 4 catalog rows because of it, which is the only country currently
carrying a visible hole for this reason. When you are ready, Austria is the
smallest possible first case.

The Swift side is mine and unchanged from what we agreed: optional
`<country>-index2.png` at logical scale, a `children` block in the manifest,
plane 2 read first and plane 1 as fallback. `RegionAtlas.cutout` reading plane 2
is what makes the child's own shape rise out of its parent on the globe, so
there is still no new art for it.

---

## Open rulings that are the maintainer's, not ours

Three sit unanswered and two touch your files:

- **The Golan Heights** — absent from Israel's authored prose. Sommbot left it
  deliberately.
- **Crimea** — Natural Earth files it under `Russia`, so a tap there answers
  "Russia" while Ukraine's outline art includes it. This one is yours and mine
  jointly once he rules.
- **The globe palette** — six of the thirty authored fills are effectively
  indistinguishable as shipped (Portugal/UK at ΔE 2.6). You flagged it as his
  because the fix restyles the globe. It still is.
