# Art session — working agreement (rev 2, 14 Sep 2026)

**Hand this whole file to the art session at the start of a batch.** It is the
operating manual for the half of Vinodex's art pipeline that does not live in
the terminal, and for how the two halves meet.

Rev 1 was written from a session that generated 20 sprite sheets and built the
region-map renderer as a prototype. This revision is written from the map
campaign that followed: seven countries with painted maps to thirty-nine, 85
painted areas to 178, 25 dead areas to zero. Everything below was paid for once,
and the sections that survived rev 1 unchanged are the ones that kept being
right.

> **Rev 1's own §6 says a doc goes stale in days.** That applies to this one.
> Date it, re-measure before quoting it, and when it contradicts the repo, the
> repo wins.

---

## 1. There are two Claudes and they are peers

**You** have a browser, the image-generation loop, a Python sandbox, and the
Mac mini's filesystem through the device bridge.

**The terminal** has the repo, the build, the test suite, the simulator, the
gates, and a much better view of the Swift side than you will ever have.

Neither of you can see the other's context. **You share a folder, not a
conversation.** Everything that passes between you passes through the repo — art
into `art/inbox/`, docs into `horizon-md/` — and that is the whole protocol.

> **The terminal is not downstream of you. It is a peer that will find what you
> got wrong.**

It did, repeatedly, and every catch was a number that was already in this
session's own tool output, unchecked:

- The globe shipped as 40 countries. It should have been 34. Six of the ten
  countries added had no catalog entry, and `GlobeIndexTests.everyCountryResolves`
  fails on exactly those six. See §3.
- Three island pins never reached the region index, because on a two-file country
  the index is built from the `-catalog` file alone. See §7.

Write handoffs that expect to be corrected. State what you measured and what you
assumed, **separately**, so the other side knows which half to check.

---

## 2. The one rule about art

**Does this pixel have to answer a question?**

- **Yes** — a tap on it must resolve to a region, an entry, a thing. Then it is
  *rendered or authored*, never generated, and there is a byte behind it in an
  index raster saying what it is. Diffusion art cannot do this: it is
  antialiased, so there are no exact flat fills to derive an index from.
- **No** — it is decoration. Generate it.

**Authored art can carry an index.** Hand-drawn is not the same as generated:
draw flat exact fills and the index falls out of the art. That is how the
country outlines already work. So "custom map" is available at any tier;
"generated map" is not.

**Procedural beats generative wherever there is data behind the picture.** The
region maps are Python over Natural Earth polygons: reproducible, diffable,
gateable, and a colour change is a re-run rather than a re-draw.

**Measure before you draw.** Two items on this campaign's queue were closed
without generating anything, because measuring showed there was nothing to
generate: the icon repass was already complete, and the grape portraits are
procedural. Ten minutes of counting beats an afternoon of the browser.

---

## 3. The art is not the catalog

The single most expensive lesson of the campaign, and the one most likely to
recur, because the wrong answer is always so close to hand.

`art/icons/entries/countries/*.png` has 51 country outlines. The globe's country
list was derived from the set difference between those stems and the countries
already on the globe. That derivation is wrong. **Outlines exist for countries
with no entry.** Six of the ten it produced — bosnia, czechia, israel, serbia,
slovakia, ukraine — were in neither `regions.ts` nor `countries.ts`. Landing them
would have made six countries tappable that open nothing, which is the exact
failure the USA shipped for all of 0.9.55.

> **When the question is "does the app know about this country", the answer is in
> `shared/data/regions.ts` and nowhere else.**

`catalog.py` is the read-only view of that file, and `globe_tex.py` now asserts
its country list against it and names both set differences in the failure. The
catalog leads; the map follows. If an entry is missing, the fix is sommbot
writing it, not the map quietly covering for it.

`shared/data/regions.ts` is **read-only from the art side** and stays that way.

---

## 4. Namespaces, and the traps in each

Five namespaces, constantly confused. Say which one you mean, every time.

| | example | lives in |
|---|---|---|
| art stem | `riberadelduero` | `countries.py`, file names |
| catalog id | `R032` | `regions.ts`, pins |
| catalog name | `Priorat` | `regions.ts`, display rows |
| admin-1 unit | `Tarragona` | the Natural Earth extract |
| NE admin-0 | `Republic of Serbia` | `ne.json` |

Never let a stem become an id. `region_check.py` once fell back to the pin *name*
when a pin had no id, replacing `R001 -> bordeaux` with `Medoc -> bordeaux` in
the region index — and printed PASS.

**Natural Earth's two layers disagree with each other on names.** Four found so
far: `Czechia` (admin-0) vs `Czech Republic` (admin-1); `Republic of Serbia`;
`Bosnia and Herzegovina`; `Hokkaidō`, which has a macron. Each one fails a join
silently-ish. A display-name row in `GlobeIndex.catalogName` and a `LABELS` entry
are two different fixes and both are usually needed: one fixes where the tap
GOES, the other what it SAYS.

**A rename and its display row ship together, the same day.** A stem renamed
without its row is a region that resolves and then shows a slug.

**A painted area is named after itself, and the app now checks.**
`RegionMapTests.displayNamesNameTheArea` folds the stem and the display name
flat (case, diacritics, punctuation) and requires one to contain the other; the
display name is the catalog's name. So a new stem is the catalog name folded
flat — `canaryislands`, `waikatobayofplenty`, `britishcolumbia` — never an
abbreviation and never the appellation inside the area. Seven stems failed this
in one day (`okanagan` was all of British Columbia; `waikatobop` abbreviated
its own name) and every one was a tap that lied about what was under it. The
matching rule on the entry side, `RegionMap.primaryEntry`, treats a name that
merely *contains* the display name as the area's own entry ("South West
France" for `southwest`), so a longer catalog name is fine; a different one is
not. *(Added by the terminal on review.)*

---

## 5. The index raster is the contract

One byte per **logical** cell — canvas-sized, never `export_scale`.
`0` = outside, `255` = inside-unassigned, `1..N` = a region id. Hit-test against
this, never against pixel colour.

Colour matching was tried first and is fragile on iOS for reasons none of which
are visible from here: no ICC profiles, asset-catalog re-encoding, interpolation
blending borders. The palette is a presentation choice; the raster is the answer.

**The second index plane.** `<country>-index2.png`, optional, same dimensions and
logical scale, `0` = no child, `1..M` = child. The runtime reads plane 2 first.
It exists for regions no admin-1 unit isolates: Sauternes is five communes inside
the Gironde, Châteauneuf is one inside the Vaucluse, the Wachau is eight
Gemeinden inside Niederösterreich. Four invariants are asserted at render time —
containment ≥ 98 %, same shape as plane 1, its own namespace, non-empty.

**FLOOR, not round.** The rasteriser fills cell *i* from canvas coordinate
`[i, i+1)`, so the cell containing a point is `floor(x), floor(y)`. Rounding
picks the nearest cell *centre* and lands one cell over for anything past the
halfway line. Invisible on a 464-cell region; decisive on a 5-cell child. Two
Sauternes probes 2.5 km apart resolved differently and that was the whole cause.

**The canvas is sized on the subject, so territory changes move every byte.**
Painting Crimea as Ukraine grew Ukraine's canvas from 502×440 to 502×451 and
moved the whole index. A country that gains or loses territory must be
re-rendered **and re-installed together**; a new raster against an old manifest
resolves taps to the wrong regions. `x_factor` in the config pins the longitude
correction for exactly the case where the canvas must *not* move.

---

## 6. Check what the source does before you cut it

Natural Earth is the source and it is not neutral about contested ground. The
campaign hit two cases and **predicted both wrong**:

- **Crimea.** NE files both admin-1 units, `Crimea` and `Sevastopol`, under
  Russia, and puts the peninsula inside Russia's admin-0 polygon. Ukraine's own
  outline art has always drawn it, so the source made the encyclopedia disagree
  with itself. Ruled: painted as Ukraine, via `extract_admin1.ANNEX`, recorded
  as a deliberate override in three places so nobody "fixes" it back.
- **The Golan Heights.** Everyone — this session and the terminal — assumed NE
  would file it under Syria and that it would need the same override. It does
  not. NE files the Israeli-administered Golan under **Israel**, inside HaZafon,
  and its two nearby Syrian units (`Quneitra`, `UNDOF`) share zero cells with it.
  The real problem was the opposite one: HaZafon is Galilee *and* the Golan in a
  single unit, so the region needed a `splits` cut, not an override.

> **Probe the layer. Both layers. Print what came back.** Five probe points and
> a containment test cost two minutes and changed the design of the work.

---

## 7. Gates, and how gates lie

Every gate in this pipeline was written after something got through. Each of
these is a *class* of failure, not an anecdote.

- **A gate that writes an artefact can corrupt that artefact and still print
  PASS.** `region_check.py` generates the region index it is checking. Its
  documented invocation destroyed the index and reported success.
- **A gate is blind to what it does not read.** `coverage_check.py` found DEAD
  (painted, no entry) and SHARED (one area, many entries) and was structurally
  incapable of finding UNPINNED, because the index it reads is built *from* the
  pins: a catalog row nobody pinned never enters the file, so it can be neither
  dead nor shared. Every gate needs the question "what can this not see?"
- **The gate reads the shipped artefact, not the source it came from.** Pointing
  the check at the rendered PNG is what caught Tavel landing in Provence, which
  the geometry-level check could not see.
- **The transport re-encodes your artefact.** `device_commit_files` re-encodes
  PNGs, so a file-byte hash fails on a file that is pixel-identical. Hash
  **decoded pixels plus shape**, never file bytes. (An earlier claim that the
  byte differences were "two different PILs" was wrong and had to be retracted.)
- **A two-file country builds its index from the `-catalog` file alone.** Three
  island pins sat in the dense file with ids the catalog file did not carry, and
  reached nothing. There is now an orphan-pin guard that fails loudly and names
  them.
- **A silent MISMATCH drops a row.** France's two child pins carried
  `expect: bordeaux` from before the second plane existed; resolving to
  `sauternes` marked them mismatched, which dropped both ids from the index and
  made both children read as DEAD — while `region_check` still printed PASS,
  because the mismatch was in the second file whose failures were discarded.
- **A shipped fill that moves is a restyle nobody asked for.** `palette.assign`
  with no authored dict recomputes every colour from scratch, and the pool has
  been widened twice. Adding the Golan moved two of Israel's *existing* fills.
  `region_map.py` now warns when a rendered fill differs from the manifest
  already on disk, and `countries.py` pins installed palettes in a `fills` dict;
  `assign` extends a partial one.

**Every wave-2 country still carries the unpinned version of that last bug.**
Three are pinned (Israel, Ukraine, Austria) because this campaign touched them.
The rest will move the first time they gain a region. The warning will say so.

---

## 8. Order-independence

Two sources can agree on a picture and disagree on an answer.

- **Arbitrate contested cells by coverage, not by draw order.** Sub-pixel
  supersample and `argmax`. Draw order is why the globe and the flat maps
  resolved Madrid differently.
- **Sort your inputs.** Shuffling the backdrop's source moved 22,400 cells with
  an identical country set. Coverage arbitration got that to 650 — all exact ties
  — and sorting the feature list by ADMIN got it to 0. A tie has to break the
  same way every run.
- **The filter can be right and the input wrong.** Every backdrop drew the same
  108 Europe-only countries for three drops. The filter always said "everything
  but the subject"; `world.json` was a Europe-centred extract cut for the France
  pilot, so twelve non-European maps rendered as silhouettes floating in ocean
  with a dead-straight 49th parallel. Nobody looked, because the European maps
  were correct.

---

## 9. Approximation: the bar, and how to clear it

**Every approximation is written down next to the config line that makes it.** A
painted area covers the whole admin unit — all of the Gironde is "Bordeaux",
pine forest included. That is allowed, and it is stated, because someone who
knows the region will notice.

> **A wrong boundary is worse than an absent one, because nothing can detect it.**

That rule blocked the Wachau for most of the campaign: Natural Earth has no
Austrian admin-2, and nothing reachable said which Gemeinden are the Wachau.

The way it was cleared is the pattern to copy: **find the statute, not a
shape that looks right.** Weingesetz 2009 § 21 Abs. 3 Z 1 lit. k names the eight
Gemeinden of the Weinbaugebiet Wachau, and the DAC-Verordnung (BGBl. II Nr.
200/2020 idF 191/2023) defers to that same area rather than redrawing it. So the
boundary in the repo *is* the DAC boundary. Two things had to be true and both
were checked:

1. **A citable delimitation**, quoted in `fetch_gemeinden.py` next to the units.
2. **Geometry whose generalisation is below one cell.** Austria renders at one
   cell per 3.57 km; the Wachau is 6.9 × 4.8 cells and covers 29. The mirror's
   retained detail is orders of magnitude finer. Where the primary register is
   unreachable — `data.statistik.gv.at` is refused by the egress proxy on both
   machines — say so in the file, name the mirror, and state the measurement that
   makes the substitution safe.

**Under-cover rather than over-cover.** Châteauneuf-du-Pape AOC spills into parts
of four neighbouring communes; the one commune under-covers it. A tap in the
spill answers Rhône, and Rhône is true. Taking all five communes would paint
Côtes du Rhône vineyards as Châteauneuf, which is a lie rather than a silence.

**Licences travel with the geometry.** Natural Earth is public domain and needs
nothing. The French communes are Licence Ouverte (Etalab); the Austrian
Gemeinden are CC BY 4.0 and require attribution — *Datenquelle: Statistik Austria
— data.statistik.gv.at* — which is carried in the emitted file's `source` field,
not only in a comment.

---

## 10. Pins are the human bottleneck

A pin is a lon/lat with a catalog id, and it is the only thing that proves a
painted area answers the entry it claims. Roughly 14 % can be derived
mechanically (pole of inaccessibility over the mask); the rest are a person
naming a place inside the region — Katzrin for the Golan, Dürnstein for the
Wachau, Yoichi for Hokkaidō.

- **`mapPosition` is not geography.** It is a fraction of a stylised outline
  authored for dot placement. Decoding it as lon/lat drifts a median 61 km and
  put Alsace in Champagne.
- **Pins are a test fixture and must never be imported into `shared/`.**
- **Pick a pin with clearance, not just a famous name.** Walla Walla sits 0.07°
  from the Oregon line. `region_check` prints the clearance; read it.

---

## 11. The image-generation loop

Unchanged from rev 1, and still true. You drive Gemini in the browser on the
mini, the PNG lands in `~/Downloads`, you process it in your sandbox and commit
the finished sheet to `art/inbox/`.

- **Gemini drops the first typed message after a navigate.** Send a sacrificial
  keystroke in the same batch as the navigate, then type the real prompt next,
  and screenshot to confirm before submitting.
- **Downloads land as `.com.brave.Browser.*` temp files and get swept in
  seconds.** Copy immediately; `ls -t` will hand you a stale file.
- **Checksum every row against the previous one before composing.** A sheet
  shipped twice from a duplicated row, and once from an unrelated stale image,
  because `ls -t` looked plausible.
- **Ask for rows of N and compose the grid locally.** Asking for a grid gives the
  wrong tile count and inconsistent scale.
- **Spread lookalikes across generation rows.** Six similar reds generated
  together converge.
- **Anything comparative must be generated in ONE image.** No exceptions.
- **The key arrives dirty.** Gemini returns JPEG, so `#EE03E1` comes back as a
  spread of near-magenta plus ringing. Flood-fill from the corners at threshold
  ~70, then snap near-magenta globally. Generated work goes down
  `art_common.strip_background`; **rendered work never does**, because a cleanup
  pass that shifts one pixel of a flat fill makes that pixel unresolvable.
- **Ask for large flat-colour art on the key, not for "pixel art".** Generate
  large, downscale hard with nearest-neighbour, snap the edges.

---

## 12. Measure, do not assert

The habit this manual exists to enforce. Two failure shapes, both cheap to avoid:

> **A number you did not query is a guess wearing a number's clothes.** The globe
> was 40 instead of 34 because a count was derived rather than queried. It takes
> thirty seconds and the doc outlives the session.

> **A comparison you performed by hand is not a comparison.** This session
> compared 47 checksums between its sandbox and the repo by re-typing one side
> into a script, concluded a file matched, and worked from a stale copy of it for
> three steps. Write both sides to files and diff them mechanically. The sandbox
> is a **copy**; the repo is the state.

Other retractions worth remembering: a key-repair "bug" was diagnosed, fixed and
*confirmed* on five sheets — rendering before/after crops proved the fix was the
bug. `PLAN.md` was cited three times for a region count; it is a frozen
per-release batch log, not current state.

---

## 13. Handoff discipline

- **Ship the inputs, not just the script.** `globe_tex.py` was committed reading
  a file that existed only in a sandbox. `geosrc.py` exists so that cannot
  happen again.
- **Separate what you measured from what you assumed.** Put the queries and their
  results in the doc so the other side can re-run rather than re-derive.
- **Renaming a manifest field breaks both layers silently.** `france_rect` →
  `subject_rect` was a non-optional decode and produced "MAP NOT INSTALLED" on
  every country at once. Rename in the same batch as the consumer, or not at all.
- **Coupled things land in one commit.** Index raster and manifest. Globe texture
  and `globe-meta.json`. A rename and its display row.
- **Ask for a review before a batch, not after.** Two reviews on the expansion
  plan found nine things between them, three of which would have shipped wrong
  art.

**Standing prohibitions, from the maintainer:**

- Do not touch `art/icons/entries/countries/*.png` or their `mapPositions`.
- `shared/data/regions.ts` is read-only from the art side.
- Never add exclusions to `outlines:check`, `icons:verify` or
  `find-missing-refs` — move the files instead.
- Never commit or push `vinodex-web`.
- Maps do not go through the sheet slicer. The backdrop is never chroma-keyed.
  Rendered art never goes through `strip_background`.

---

## 14. What "done" means

**For a generated batch:** every sheet composed locally from rows, key exact or
repaired, checksums verified against the previous row; committed to
`art/inbox/<batch>/` with a tile-order manifest; approximations and known-wrong
tiles named in the handoff.

**For a map batch, all of these, with the numbers in the handoff:**

- `region_check.py` PASSes every country.
- `coverage_check.py` reports **0 dead** and **0 unpinned**; any SHARED row is
  named with the plan for it.
- `verify_extracts.py` reproduces every admin-1 extract from source.
- `halo_check.py` clean on the bundled files.
- No fill-drift warning, or the drift is pinned.
- Every override and approximation recorded next to the line that causes it.

At the close of this campaign: **178 painted areas, 0 dead, 0 unpinned, 37
shared, 39/39 on every gate.**

---

## 15. The division, stated plainly

| | You | The terminal |
|---|---|---|
| Image generation, browser | ✓ | — |
| Procedural rendering | ✓ | ✓ (it's Python) |
| Boundary data, index rasters | ✓ | — |
| Slicing, import, install | — | ✓ |
| Swift, tests, gates | — | ✓ |
| Simulator verification | — | ✓ |
| Catalog content | — | sommbot |
| Deciding what is true | both, by measuring | |

The last row is the one that matters. Neither side is the authority; the repo is.
When you and the terminal disagree, the answer is a query, not a discussion.
