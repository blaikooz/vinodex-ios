# For the iOS session — what web did on 14–15 Sep, and six things for you

Written from the web terminal, the reciprocal of
`web-catchup-2026-09-14.md`. Your data is unchanged by any of this: web does
not edit `shared/` except where noted in §1, and it never commits or pushes
`vinodex-ios` beyond this file.

Web is at **v0.6.72**, production trails at 0.6.62 (manual promote).

---

## 1. One change we made to the hub, and why

**`Mavrodaphne` was a white grape.** Not a typo in its record — a derivation:
`grapeCards.ts` reads red/white by looking for the word "red" in `wineType`,
and Mavrodaphne's is `"Fortified Wine"`, so the Peloponnese's dark laurel was
typed white with tannin 4, against its own description.

Blast radius measured before touching anything: exactly four records have a
`wineType` the rule cannot read, and the other three (Sercial, Boal, Malvasia
de São Jorge) are genuinely white, so the rule had been right by luck.

Fixed in the hub, following the file's own "authored wins over the prose"
pattern: an optional `berryColor?: 'red' | 'white'` on `LegacyGrapeRecord`
which the derivation prefers, and `berryColor: "red"` on G191 alone. You
confirmed this reached the device on regeneration.

---

## 2. Five findings for your side

**(a) The QUIET node answers with the wrong line.** `VinoScene.swift` composes
`silenced ? "Voice restored" : "Quiet mode on"`, but `ProfVinoScreen.swift`
toggles the store and *then* re-composes — so the flag it composes under is
the post-tap one. On the device today, tapping SPEAK LESS silences him and he
answers "Voice restored." `VinoSceneTests.quietDoorIsHonest` pins the pre-tap
reading, so the graph passes its own suite and the fault lives in the seam
between graph and screen. Web states the post-tap truth instead.

**(b) `VinoTake`'s thresholds are written for a 0..1 scale.** `spread < 0.15`
and `body <= 0.45`, against characteristic bars that are 0–5 integers in
`entries.json` (Cabernet is `tannin: 4, body: 5`). So the balanced branch
fires only on an exact three-way tie and the light-body branch cannot fire at
all. Web ported it faithfully rather than "fixing" it, so the same entry gets
the same line on both devices — if you rescale, say so and web follows in the
same pass. (Note `VinoTake` is dead code your side since 0.9.53 retired its
render site; web keeps it unrendered for the same reason.)

**(c) Natural Earth is uncredited.** `art/inbox/region-maps/geosrc.py` records
the region maps as Natural Earth 1:10m, and `NOTICE.md` / `ATTRIBUTION.md`
name R74n, LWIN, the fonts and three icon sets but never Natural Earth. Public
domain, so nothing is breached and attribution is waived — but a repo this
careful going silent on the source of 39 maps reads as an oversight rather
than a decision. Web added it to its own new `NOTICE.md` and CREDITS screen
when it took the globe rasters.

**(d) 146 names on the state gates lead nowhere.** Your doc told us
`find-missing-refs.ts` skipped `classification: 'STATE'`; lifting it found
that 132 of the AVAs and 14 of the grapes those fifty gates name have no
catalogue entry — Muscadine, Norton, Frontenac, Seyval Blanc, Traminette and
Vignoles among the grapes, which are not obscure. Web now hides the dead rows
and reports the gap without failing the build. **These are sommbot's to
author, not ours**, and they would benefit both apps.

**(e) Lemnos, Halkidiki and Tokat** are still named by Limnio and Narince with
no region entry behind them. Reported 9 Sep, still open, still tolerated by a
self-clearing list web-side.

---

## 3. What web built from your work, in case the shape is useful

- **The globe hit test, ported** (0.9.55). Web reads `globe-index.png` and
  `globe-meta.json` exactly as you do; `globe-wine.png` replaced its
  photographic texture and the screen got *lighter* (72 KB against 217 KB)
  while gaining a hit test it never had. Your comment that colour matching
  "works in a browser and is fragile on iOS" is why the index plane ported
  cleanly — thank you for writing it down. The v-flip you lost a commit to is
  real in Three.js too (its `uv.y` runs the other way); it is one subtraction,
  and web pins the convention against six real countries plus a case that
  fails if the flip is ever dropped.
- **The painted region maps were NOT ported.** 3.4 MB is affordable; what is
  not is re-deriving the camera and zoom-fence choreography you iterated on
  across four releases with a device in hand. Web took the 131 KB globe layer
  only, and will decide the rest on evidence.
- **VINOBOT's scene graph, INSIDE IT, the tier card, the moon copy, the 120 s
  screensaver, read-aloud + NARRATOR, firmware families, in-place facets** all
  ported. One deliberate refusal: iOS 0.8.7 C1's filter→chip exchange, because
  `EntryFilter.chipOption` proves the swap set-equal on your side and web's
  nine `FilterMode`s have no such proof.
- **`extraState`** ported; web's backup had the identical hole and was
  dropping 26 keys.

---

## 4. Two standing rules, from our side

- Web does not commit or push `vinodex-ios`, except this file.
- `sync-shared.sh`'s web art leg now also carries **ClassArt, FlavorArt and
  StyleArt** (they had been hand-copied once and gone ~100 files stale).
  `GrapeArt` is deliberately still excluded: your stems gained a body rung and
  an `arch-cone` family, and web still resolves the older spellings, so a
  mirroring sync would delete five sprites web references and add 112 it
  cannot name. That is a port of the resolution logic, not a copy, and it is
  logged rather than half-done. Both tables (`.sh` and `.ps1`) were updated
  together.
