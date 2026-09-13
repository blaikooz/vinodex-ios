# Art session — working agreement

**Hand this whole file to the browser/art session at the start of a batch.**
It is the operating manual for the half of Vinodex's art pipeline that does not
live in the terminal, and for how the two halves meet.

Written from a session that generated 20 sprite sheets, built the region-map
renderer and the globe prototype, and got several things wrong in ways worth
recording. Everything below was paid for once.

---

## 1. There are two Claudes and they are peers

**You** have a browser, the image-generation loop, a Python sandbox, and the
Mac mini's filesystem through the device bridge.

**The terminal** has the repo, the build, the test suite, the simulator, the
gates, and a much better view of the Swift side than you will ever have.

Neither of you can see the other's context. **You share a folder, not a
conversation.** Everything that passes between you passes through
`~/Developer/HGapps/vinodex-ios` — art into `art/inbox/`, docs into
`horizon-md/`, and that is the whole protocol.

The important part, and the thing this session learned the hard way:

> **The terminal is not downstream of you. It is a peer that will find what you
> got wrong.**

Mid-session I found `make_pins.py` in a folder I thought was mine, with a
docstring that began *"THE HANDOFF SAYS to derive lon/lat from each region's
`mapPosition`. That does not survive contact."* It was right. `mapPosition` is a
fraction of a stylised outline authored for dot placement; decoding it as
geography drifts a median 61 km and had put Alsace in Champagne. My handoff had
confidently instructed it to do exactly that.

Write handoffs that expect to be corrected. State what you measured and what you
assumed, separately, so the other side knows which half to check.

---

## 2. The one rule about art

**Does this pixel have to answer a question?**

- **Yes** — a tap on it must resolve to a region, an entry, a thing. Then it is
  *rendered or authored*, never generated, and there is a byte behind it in an
  index raster saying what it is. Diffusion art cannot do this: it is
  antialiased, so there are no exact flat fills to derive an index from.
- **No** — it is decoration. Generate it.

That single question sorts the whole pipeline. Maps, region fills, anything
hit-tested: rendered from boundary data or authored as flat exact fills.
Flavour icons, chrome, markers, cartridges, tiles: generated.

**Authored art can carry an index.** This is the part people miss. Hand-drawn is
not the same as generated — draw flat exact fills and the index falls out of the
art automatically. That is how the country outlines already work: 0.8.4 made the
hand-drawn coastlines the master and pointed `outlines:check` at them. So
"custom map" is available at any tier; "generated map" is not.

**Procedural beats generative wherever there is data behind the picture.** The
region maps are Python over Natural Earth polygons. They are reproducible,
diffable, gateable, and a colour change is a re-run rather than a re-draw. Reach
for Gemini when the thing you want has no data behind it.

---

## 3. The image-generation loop

You drive Gemini in the browser on the mini, the PNG lands in `~/Downloads`, you
process it in your sandbox and commit the finished sheet to `art/inbox/`. The
terminal slices, imports and verifies on the simulator.

Six traps, all of which cost real time:

- **Gemini drops the first typed message after a navigate.** Send a sacrificial
  keystroke in the same batch as the navigate, then type the real prompt in the
  next call, and screenshot to confirm the text is in the box before submitting.
- **Downloads land as `.com.brave.Browser.*` temp files and get swept within
  seconds.** Copy immediately. `ls -t` will hand you a stale file if the download
  has not landed yet.
- **Checksum every row against the previous one before composing.** This session
  built and shipped a sheet from a duplicated row twice, and once from a
  completely unrelated stale image, because `ls -t` looked plausible.
- **Ask for rows of N, compose the grid locally.** Asking the model for a grid
  gives you the wrong tile count and inconsistent scale. Rows of three, extracted
  by bounding box, assembled in Python.
- **Spread lookalikes across generation rows.** Six similar reds generated
  together converge. Split them across rows and restore the canonical order at
  compose time.
- **Anything comparative must be generated in ONE image.** "Paler than the
  first", "the same pose", a graded set — if it spans two generations the
  comparison is not real. This is the paired-set contract and it has no
  exceptions.

**The key arrives dirty.** Gemini returns JPEG, so `#EE03E1` comes back as a
spread of near-magenta plus ringing. Flood-fill from the four corners at
threshold ~70, then snap near-magenta globally. Generated work goes down
`strip_background` (which gained de-halo and fringe-snap in 0.9.55 for exactly
this); **rendered work must never go down that path**, because a cleanup pass
that shifts one pixel of a flat fill makes that pixel unresolvable.

**Ask for large flat-colour art on the key, not for "pixel art".** Diffusion
models do not respect a pixel grid and "pixel art" gets you fake-pixel texture at
the wrong scale. Generate large, downscale hard with nearest-neighbour, snap the
edges.

---

## 4. The rendered-art loop

`region_map.py <country>` renders, `region_check.py <country>` gates, and the
only hand-written thing is `countries.py` — which admin-1 units make up which
wine region. `extract_admin1.py` makes a new country's geometry file.

Three properties worth defending:

- **The index raster is the contract, not the colour.** One byte per logical
  cell. The palette is a presentation choice that can change without re-slicing
  anything, which is why fills repeat across countries harmlessly.
- **Every approximation is written down next to the config line that makes it.**
  A painted area covers the whole admin unit — all of the Gironde is "Bordeaux",
  pine forest included. That is allowed and it is stated, because someone who
  knows the region will notice.
- **The gate reads the shipped artefact, not the source it came from.** This is
  not pedantry: pointing the check at the rendered PNG is what caught Tavel
  landing in Provence, which the geometry-level check could not see.

---

## 5. Measure, do not assert

The single most expensive habit to break. Every claim this session made without
measuring turned out wrong at least once.

- I diagnosed a key-repair "bug", wrote a fix, and *confirmed* it on five
  delivered sheets. Rendering before/after crops proved the pixels were enclosed
  background pockets that should key transparent. **The fix was the bug.** I had
  to retract it publicly.
- I wrote "France has 19 catalog regions" three times from `PLAN.md`. It has 20.
  `PLAN.md` is a frozen per-release batch log, not current state — cite
  `shared/data/regions.ts`.
- I wrote "Germany's Anbaugebiete map cleanly onto admin-1". Four of the five sit
  inside one state. A review caught it before it cost a session a day.
- I proposed a two-cut fix for that and a review caught *that* too: the cuts
  bisect the Nahe and paint the Ahr as "Mosel".

Two structural lessons behind the anecdotes:

> **Two pipelines that agree on a picture can still disagree on an answer.** The
> globe's region rasters and the flat maps looked identical and resolved Madrid
> differently, because one arbitrated contested cells by coverage and the other
> by config order. Cross-check them at every pin, not by eye.

> **A number you did not query is a guess wearing a number's clothes.** Before
> quoting a count in a doc, run the query. It takes thirty seconds and the doc
> outlives the session.

---

## 6. Handoff discipline

- **Ship the inputs, not just the script.** I committed `globe_tex.py` without
  `ne.json`, which existed only in my sandbox. It cannot run in the repo. Three
  sections of a plan depended on it. If a script reads a file, that file goes in
  the drop or the script says where to get it.
- **Separate what you measured from what you assumed.** Put the queries and their
  results in the doc so the other side can re-run rather than re-derive.
- **Name the namespaces.** There are art *stems* (`riberadelduero`), catalog
  *ids* (`R032`), catalog *names* (`Priorat`), and admin-1 *unit names*
  (`Tarragona`). Four namespaces, constantly confused. Say which one you mean
  every time, and never let a stem become an id.
- **Renaming a manifest field breaks both layers silently.** `france_rect` →
  `subject_rect` was a non-optional decode and produced "MAP NOT INSTALLED" on
  every country at once. Rename fields in the same batch as the consumer, or not
  at all.
- **A doc goes stale in days.** Three of the four documents in this project
  contradicted the repo within a week of being written. Date them, version them,
  and re-measure before quoting one.
- **Ask for a review before a batch, not after.** Two reviews on the expansion
  plan found nine things between them, three of which would have shipped wrong
  art. They cost an hour and saved several.

---

## 7. What "done" means for an art batch

- Every sheet composed locally from rows, key exact or repaired, checksums
  verified against the previous row.
- Committed to `art/inbox/<batch>/` with a tile-order manifest — what each tile
  is, in reading order, and where it should land.
- Approximations, omissions and known-wrong tiles named in the handoff, not left
  for the terminal to discover on the simulator.
- Anything hit-tested has an index raster and a gate that reads the shipped file.
- The terminal has what it needs to slice without asking a question, and knows
  which of your claims you measured.

---

## 8. The division, stated plainly

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
