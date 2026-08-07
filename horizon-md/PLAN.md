# HGapps plan — open issues, cleanup, and next batches

**Authored by Horizon.**

*2026-07-30, written at iOS v0.6.2 (tagged, on main). This is the working
plan that consolidates the open ends of AUDIT.md, KNOWN-ISSUES.md,
V1-ROADMAP.md and the archived shipping/port reviews. Run batches with the
`dexbot` agent (`.claude/agents/dexbot.md`); it knows the pipeline and gates.*

> **Moved 0.6.5 (batch 4 phase 3).** This file lived at `HGapps\PLAN.md` — one
> level above the repo, where only one collaborator could see it. It now sits
> in `horizon-md/`, so both collaborators do; the AUDIT/auditS/arch trio it
> draws on moved alongside it and then on into `godot-md/`. The
> workspace paths it describes (`HGapps\…`) still refer to the folder **above**
> this repo. Note that several items below are already done — the pixelflags
> decision, the root-doc archive, the `README-layout.md` rewrite and this very
> move all landed in batch 4.

## Where things stand

> **Updated 2026-08-04, at iOS v0.7.3.** The line below is the 0.6.2 baseline
> this file was written at and is kept for context; the current state is the
> batch log immediately after it.

- **iOS**: v0.6.2 on `main`, tagged. 375 entries (128 grapes · 104 regions ·
  31 styles · 106 flavors · 25 countries), five rarity tiers, tools suite,
  15 skins, geographic region dots, passport stamps. All 196 tests green,
  clean xtool build, deployed.
- **Web**: still at the ScreenState-port baseline. `shared/` mirror synced to
  the 0.6.2 data but the web app has had no feature work since the split.
  This is now the widest gap in the product.
- **Docs**: AUDIT.md (52 open items) and KNOWN-ISSUES.md (runbook) live in
  vinodex-ios and are current. SHIPPING-REVIEW.md and PORT-TO-WEB.md (now in HGapps\archive\) are
  archived (banners point here). V1-ROADMAP.md carries a 2026-07-30 baseline
  correction. The 0.6 missing-data tracker (Downloads) is fully landed.

### Batch log since 0.6.2

Each row is one dexbot batch: the spec it ran from, what it changed, and the
gate result. Kept here rather than only in `AppVersion.swift`'s release notes
because that file answers "what is this build" and this one answers "what has
been happening", which is the question a planning doc is for.

| Version | Spec | Headline | Catalog | Gates |
|---|---|---|---|---|
| 0.6.3–0.6.9 | assorted | Chassis work: button band, top-bar chrome, per-mode globe, recessed button bundles, two skins, back swipe removed, still marquee. See `AppVersion.swift`. | 405 from 0.6.4 | green |
| 0.7.0 | `vinodex-0.7.0` | Sectioned pickers on both axes, WALDGLAS + HALLOWEEN skins, three chip facets, per-skin back plate, stamp drag rebuilt, tools shelf re-cut, marquee glyph table audited. | 405, untouched | 250 tests, clean build |
| 0.7.1 | `vinodex-0.7.1.md` | UI/UX fixes, the new marquee, polish — see below. | 405; South America's marker colour changed, no entry moved | 282 tests, clean build, deployed |
| 0.7.2 | `vinodex-label-reader` | **LABEL SCAN.** Camera → Apple Vision OCR on-device → match against the catalog. Matching/scoring/inference in Core (Linux-gated); Vision, camera and pickers in UI behind `LabelRecognitionProvider`. `xtool.yml` gained `infoPath` for the usage strings. | 405, untouched | 320 tests, clean build, **not deployed** |
| 0.7.2 | `vinodex-0.7.2` | **Consolidation + nine fixes.** All batch branches merged onto `testing`; stamps made draggable at last (A2); the marquee becomes a control surface — lamps are TOOLS/CUSTOMIZE, pins in the corners, PINS on open, MENU glyph, rotating toasts; Africa and Oceania get their own marker colours. | 405, untouched; two continent colours changed | 326 tests, clean build, deployed |
| 0.7.3 | `vinodex-0.7.3a` | **Device experience + the 0.7.3 Foundation.** F1 one entitlement store behind a protocol; F2 one idle timer where there were two clocks; F3 version + changelog moved into `shared/`. Then A1 boot POST, A2 demo mode, A3 firmware history, A4 cheat console, A5 bouncing-V screensaver. | 405, untouched; `firmware.json` is a new generated file | 384 tests, clean build, deployed and eyeballed |
| 0.7.3 | `vinodex-0.7.3b` | **DEVICE WORKSHOP (premium).** The six part axes that did not exist, then the builder over all eight. `DeviceAxis`/`DeviceBuild`/`CustomDeviceStore` in Core; `PartColor`, `GrilleShape` and `ChassisLook` in UI. Gated on F1's `Entitlement.workshop`; GARAGISTE unlocks it. | 405, untouched | 404 tests, clean build, deployed and eyeballed |
| 0.7.3 | `vinodex-0.7.3c` | **EXPANSION PACKS.** Twelve collectible cartridges on a PACKS shelf — three atlas, six device, three display — owned through F1's `Entitlement.expansion`, which finally covers something. Packs **collect rather than gate**. Brazil added to the catalog so the New World pack has a Brazil to name. | **405 → 407** (+2 Brazilian regions); countries 25 → 26 | 425 tests, clean build, **not deployed** |
| 0.7.4 | `vinodex-0.7.4-grapes.md` | **GRAPE OVERHAUL.** `sommbot` authored the data (+25 grapes, +6 regions, corrections to Marselan, Cabernet Gernischt, Sangiovese, Palomino, Tannat, Négrette, Fer Servadou, and the Chile/Croatia gates); `dexbot` took the code side. Two logic fixes sommbot found and left: `levelFromText` and the dead country-gate arm of `find-missing-refs.mjs`. | **407 → 438** (+25 grapes, +6 regions); flavours held at 106, countries 26 unchanged | tests green, clean build, **not deployed** |
| 0.7.5 | v0.7.5 spec, sections A + B | **THE SHOP.** ACCESS becomes SHOP and the expansion packs move into it out of CUSTOMIZE — **superseding 0.7.3c's placement**. The whole storefront is redrawn in 0.7.3c's cartridge tile and every cartridge opens to a splash. `PurchaseProviding` lands beside F1's `EntitlementStoring`; **no StoreKit, no payment path**. Plus six A-list fixes: bigger marquee lamps with darker glyphs, a squared orb, a monochrome-only refresh flash, PÉT-NAT → FIBERGLASS, the real wordmark in the screensaver, and a full-screen POST. | 438, untouched | 438 tests, clean build, **not deployed** |
| 0.7.5 | v0.7.5 spec, section D | **THE WINE EXAM.** `sommbot` authored the bank (`shared/data/exam.ts`, 407 questions, 16 subjects, 7 formats, an explanation on every one); `dexbot` built everything that consumes it — the `exam.json` emit and its gate, the Swift decode, the shuffling engine, balanced paper assembly, scoring, the statistics store, the seven answering UIs and the explanation reveal. Plus the two pre-existing TS errors and the missing-outline-art gate. | 438, untouched; `exam.json` is a new generated file | 484 tests, clean build, **not deployed** |
| 0.7.5 | v0.7.5 spec, section E | **INTERACTIVE GRAPE LINEAGE.** `sommbot` authored the pedigree off VIVC passports — 57 grapes carrying a lineage, 68 of 171 in a relationship after the reverse pass. `dexbot` took the pipeline (`constants.ts` pass-through, `WineEntry` Codable, a `find-missing-refs` arm), the reverse index that derives offspring / mutations / half-siblings, and the tree screen behind a new `Entitlement.lineage`. Plus the approved `bodyFromText` fix: 16 grapes stop drawing a full-body bar they never earned. | 438, untouched; `lineage` is a new optional field on grape entries | 452 tests, clean build, **not deployed** |
| 0.7.5 | `audit-review/FINDINGS.md` A026–A028 | **THE ASSET GATE.** Three silent-missing-asset bugs in three batches and only the third left a gate behind, so this one is the general case: `assertAssetsExist` in the generator checks that every emitted `icon` / `art:` / portrait-stem / flag id resolves to a file on disk — 337 ids a run. It found a **fourth on its first run**: `icons.json` has named a Brazil flag since 0.7.3c and `Flags/brazil.png` was never copied, so every Brazilian row flew a blank swatch. Plus the pipeline wiring — `import-logo-art.py` was in no roster at all (A026), `import-stamp-art.py` in the rasteriser but not the verifier (A027), and `ArtPipelineRosterTests` now holds the four rosters equal so a seventh importer cannot land in three of them. | 438, untouched; `Flags/brazil.png` added | 489 tests, clean build, `npm run icons` + `icons:verify` green, **not deployed**; no firmware bump — nothing user-visible changed |
| 0.7.7 | `vinodex-0.7.7-bios.md` (titled 0.7.6) | **THE BIOS SCREEN.** The startup POST rebuilt from a written description of a mockup, **superseding 0.7.3a A1 and 0.7.5 A6 wholesale**: full-screen and opaque over the chassis (reversing 0.7.3a's "inside the LCD", which was an argument about a *translucent* overlay), three zones inside a terminal frame with ticked side rails and corner brackets, scanlines and a vignette, the shipped pixel "V" in cream over a magenta drop shadow. Staged checks now resolve *into* the composition rather than cutting away, then it rests on `PRESS ANY BUTTON TO CONTINUE` — any touch advances, and so does a 3.5s timeout. The mockup's `v1.0.0` was disobeyed: that string is on `AppVersion.placeholders` and printing it would have hidden the failure it signals. Four glyphs, no new art asset — one reuse, three drawn in code. | 438, untouched; `firmware.ts` only | 504 tests, clean build, `npm run generate` + `find-missing-refs` + `npm run icons` + `icons:verify` green, **not deployed** (held at the user's request) |
| 0.7.8 | 0.7.8 spec, sections B–D | **THE GROWTH TRIO.** Scoped three times and built here, fully local. **B** one card renderer reused three ways — entry, profile, earned stamp — through `ImageRenderer` at a fixed 3× into the share sheet, framed by a purpose-built still that takes the chassis's *tokens* rather than rendering `DeviceChassis` (which exports a blank marquee and dim lamps off-screen). **C** the spoiler-free result string, `DailyResult` in Core, two tiles not three because the paper has no third state; C2's three preconditions confirmed against the code and one caveat found — the paper depends on the shipped catalog, so cross-version strings are not comparable, which is why it carries no puzzle number. **D** `NotificationPlan` in Core, a 7-day horizon of one-shots re-cut whenever the app can see whether today's paper is done; the toggle renders real `UNAuthorizationStatus`, not a stored bool. `QuizSession` gained `marks` with a hand-written decoder so a paper half-sat across the upgrade survives. | 438, untouched; `firmware.ts` only | 542 tests, clean build, `npm run generate` + `find-missing-refs` green, **not deployed** (held per the spec) |
| 0.8.0 | `vinodex-0.8.0.md`, sections A–L | **NEW MAPS, NEW MAKER.** All thirty country/state outlines regenerated from authored lon/lat rings, with the generator and its data now *in the repo* — once every outline is derived the script is the master art. Gated on **A0b**, its own commit: the six quantising importers routed through a pinned `quantize_stable` and through `save_stable`, so a re-run is byte-identical and a three-colour outline never meets a quantiser at all. Every one of the 121 authored `mapPosition` dots checked against the new art (**8 were already in the sea**, 7 re-authored, 1 — the Canary Islands, at fraction (-0.49, 2.07) of Iberia — named as genuinely off-map). Plus: BIOS by HORIZON/GODOT, centred and larger; the orb becomes a lamp in height *and* treatment; "paper" becomes "exam" in every player-facing string and no identifier; a rosé chip that had been resolving to grey since it shipped; four menu tiles that finally share a baseline; type-ahead in WHAT'S THAT…? restricted to entries the player has met. | 446, untouched; `regions.ts` mapPosition ×7, `continents.ts` Europe colour, `firmware.ts` | 582 tests, clean build, `npm run generate` + `find-missing-refs` + `icons:verify` green, **not deployed** |
| 0.8.3 | `vinodex-0.8.3.md`, sections A–H | **THE SHELVES BECOME CARTRIDGES, AND A PAYWALL COMES DOWN WITHOUT TAKING ANYTHING WITH IT.** **D** was the item that could fail and the spec's own reconnaissance was wrong about where it lived: the flavour wheel and the Italy/France/Spain packs are not `ExpansionPack`s at all — they are `Entitlement` rows in `SettingsPanel.shopUpgrades`, and the three countries were never chosen but *computed* by a `topCountries` helper taking the largest three by region count. So `ExpansionPacks.all.count` stays **12** and `FREE_COMMON_ORIGINS` never came into it. What did matter is that `country:France` is a string on disk: the cases are **retired, not deleted** (`Entitlement.isRetired`), so `init(id:)` still parses, `covers` still opens, and a 0.8.2 owner loses nothing — while `canPurchase` refuses them and `offer(for:)` collapses to `.pro`, because a paywall prompt naming a product no storefront lists *is* the orphaning the item warns about. The gate is `everyEntryHasABuyableOffer`, which asserts both halves over all 446 entries; the old test checked only coverage and would have passed through the failure. **C4** turned the other flagged risk into a measurement: the label well is at the **same fractional position on all seventeen** sprites, the three 2× files included — what varies is the **aspect ratio** (0.678–0.798), so a fraction-of-tile overlay would have drifted out of the well under `.aspectRatio(.fit)`, and the rect is computed off the fitted image instead. **B1** was art, not code: the cast shadow is painted into the sources as the magenta key at half value, so `strip_key_shadow` clears it in `import-footer-art.py` (27,885 pixels) — nothing in SwiftUI was drawing it. **A** and **H** are one mechanism with a parameter: `DexRoute.marqueeArt` feeds both, and `DexChromeGlyph.flatten` decides silhouette or drawing. **F** finished `ScreenMockup` by making it *be* the CUSTOMIZE card rather than a likeness — which is how the missing monochrome pass was found: AMBER and VINTAGE were previewing in the green they derive from. | 446 / 177 / 124 / 33 / 106 / 26, all untouched; `firmware.ts` only | **601 tests**, clean build, `generate` (no drift) + `find-missing-refs` (zero dangling) + `icons:verify` (312 identical) + `outlines:check` green; four `FooterArt` PNGs re-exported, **not deployed** |
| 0.8.4 | `vinodex-8.4.md` (titled 8.4; shipped as 0.8.4), sections A–F | **THE MENU BECOMES A DIAL, AND THE MAPS STOP BEING GENERATED.** **F** was the item that could go wrong and it went wrong in the direction the coordinator flagged: the user's 46 hand-drawn coastlines supersede 0.8.0's ring rasteriser as the *master*, which meant `npm run outlines` was one absent-minded run away from replacing them, and `outlines:check` — which re-rasterised the rings rather than reading the art — would have gone on reporting green about geography no longer shipped. Both fixed rather than worked around: `--check` now thresholds the alpha of `ClassArt/outline-*.png` at 127, which is `OutlineDotPlacer.interiorPoints`' own test, so the gate reads the file the app opens; and `--draw` requires an explicit `--out`, so nothing has a default write path into `art/icons/countries/`. **The rings are kept, not discarded** — 30 authored geographies and a one-command fallback for a country nobody has drawn — with `FILL` moved to `country-outline-fills.py`, because the masters are flat silhouettes now and the ink is applied at *import* by `ink_outline`, three colours out so the quantiser is never reached and `icons:verify`'s zero-pixel budget stays honest. Repointing the check at the real art immediately earned it: **6 of 121 authored `mapPosition` dots landed in the sea** on the new coastlines (all within 1–5px — the two sets are broadly compatible), re-authored in the master `shared/data/regions.ts` by id. Master stems are now the icon stem, retiring the three-spelling problem (`outline-washington` → `washingtonstate.png`) and with it `SOURCE_FOR`'s 30 outline rows; `outlineRingsMatchTheManifest` becomes `outlineMastersMatchTheManifest` + `everyMasterHasAFill`, both two-way, with the 13 drawn-ahead places a *named* backlog. **A** is an eighth importer and the first bare-word collision the loader's own note predicted: 19 of the 34 marquee stems are words `ButtonArt` already uses, so `marquee-` is load-bearing rather than tidy. It also caught a live one — `MarqueePin.artStem` read `DexRoute.minigames.marqueeArt`, so repointing that table silently moved a *chassis lamp* onto art drawn for a lit LCD; `pinsResolveToRoutes` failed, and now asserts the prefix pairing instead of equality. A2 reverses 0.8.3's A: the glyph is `ink` (`skin.marqueeShadow`), the same expression the letters beside it read, not black. **B** is a hand-built `Shape`: `Path.subtracting` gives the scoop in three lines and leaves two hard cusps per tile, so the path fillets the arc-to-edge transitions (external tangency, `d = √((scoop+f)² − (f+channel)²)`), built once for the top-leading quadrant and mirrored. Validated by porting the arithmetic to Python and rendering it before the build. **C** needed no `parent` switch — there is none, `goBack()` is `path.removeLast()`; the splash was `@State` on a frame the user had navigated past, so one pop skipped the shop. `openShopItem` becomes an input and the *same view* is dispatched from `.pack(id:)`, which is why the fix is four lines and not an extraction. **E1** found the drawn caps discarding a colour every skin had already chosen (`ChassisControl.glyph`); masked by measurement (r < 0.72, v < 0.60 — the incised line runs 0.19–0.47, the face sits at 0.96, the bevel at 0.70–0.78) rather than by a per-sprite stencil. **E2**'s bleed is two halves: the importer's key ceiling cut through the shadow's shoulder at 0.35 instead of the measured gap at 0.5, and the square sprites carried 301–630 opaque pixels outside a round cap — clipped in pixel space, because `.aspectRatio(.fit)` means a view-space circle is only the sprite's circle on the one cap that is square. **D** was two bugs: the grid was hidden *and* `lcd.screen` (#232323) is not `mode.ground` (#0c0a09), so the blank was lighter than the app on DARK/AMBER/TERMINAL. | 446 / 177 / 124 / 33 / 106 / 26, all untouched; `regions.ts` mapPosition ×6, `firmware.ts` | **605 tests**, clean build, `generate` (no drift) + `find-missing-refs` (zero dangling) + `icons:verify` (349 identical) + `outlines:check` (120/121 on land, 1 exemption) green; vinodex-web `typecheck` green, **not deployed** |
| 0.8.5 | `vinodex-8.5.md` (titled 8.5; shipped as 0.8.5), sections A–G | **THE THIRD PASS AT THE FOOTER CAPS FINDS THE FAULT, AND IT WAS NEVER A CLIP.** **E2** is the item that mattered and the spec's own diagnosis (“fill + shadow not clipped to the button shape”) described the symptom. Three measurements settled it. (1) `strip_key_shadow` was a **global** sweep, so it also matched the cap's own darkest shading and punched **3,276–3,706 transparent holes per cap** through an opaque moulded part, clustered in the lower half where the shadow's colour and the bevel's meet — which is the mottling, and where a run of them reached the rim it cut the cel outline into fragments. Border-flooding it takes the silhouette's radial sd from **4.18px to 1.33px** on a 123px disc (`home` is the residual at 5.04, its master is genuinely that wobbly). (2) 0.8.4's disc clip was fitted to the **image**, not the drawing: `min(w,h)/2 = 127` about the image centre, where the cap is r≈122 about a centroid **(5, 3.5)px away** — so it lay outside the art over most of the perimeter and shaved a 1px crescent off the far side. Now the centre is the alpha centroid and the radius the **10th percentile of 360 rays**, with a 1.5px feather, because the sprites have **strictly binary alpha — zero partial pixels in all four**. (3) The coordinator's second observation was its own bug and the larger one: 0.8.4's E1 glyph mask (`d < 0.72R && v < 0.60`) claimed a bimodal value gap that **does not exist** — every radius band carries 760–1,711 pixels below 0.50, and **61% of what it captured on BACK sat at 0.6–0.72R**, the lower-right bevel painted in the *glyph* ink. No pair of thresholds separates them; **shape** does, so dark pixels are grouped into connected regions and a region is the symbol iff it starts inside 0.50R and stays inside 0.78R (measured: symbols run 0.00–0.73, every other region begins at 0.61 and runs past 0.80). **B1** was one word off in the report: STYLE SCAN is `EntryFilter.type`'s `scanTitle`, not the styles listing's, and `DexRoute.marqueeArt` answered nil for **all nine** filters — four now resolve, five keep the SF Symbol, and `marqueeArtIsOnDisk` reaches filters for the first time. **F** needed two hand-written stem maps: both drops arrived named for the picture, and a verbatim copy would have put ten files in the bundle nothing asks for while leaving six badges on stand-ins — silently, since neither family is walked by `assertAssetsExist`. `vinhoverde.png` is **NOCTURNE**, not the shell whose rawValue is `VINHO VERDE`; that one is `boxwine.png`. `unauthoredArtDirectories` emptied itself exactly as designed. **C1** replaced a flat `scoop/8` with the **area centroid** of the drawn shape, integrated in 240 horizontal strips and validated against a 700² grid to 0.002pt — the right offset is (-4.4,-6.4) to (-7.1,-8.0) over the sizes laid out, not 8.38 on both axes, and it *shrinks* as C2 grows the tile. **A3** separated the effect from the duration the 0.7.1 argument had conflated them into. **D1** reverses 0.8.2's sketch-shell exemption. Trap logged: Swift reads `
| 0.8.6 | `vinodex-8.6.md` (titled 8.6; shipped as 0.8.6), sections A–D | **A STICKER, NOT A FRAME — AND THE COG'S GREY TEETH WERE NEVER THE CLIP.** **B1** is the item that mattered and the spec's diagnosis ("the clip wasn't applied to the gear/jog-wheel button") is wrong in both halves: the cog goes through the *same* `ChassisCapLoader.image` call as its three neighbours, with the same `cap.topHex` / `cap.glyphHex` pair, and the thing the photographs show is not a clip failure. Two measurements. (1) **The grey lower teeth are the mask.** 0.8.5's shape rule admits a dark region that starts inside 0.50R and stays inside 0.78R, and on `settings` the facets along the bottom of the dial are welded into **one 2,491-pixel region by the moulded shading they sit in**, running 0.300 → 0.735 — inside both bounds. That region is also what 0.8.5 measured and wrote down as "the cog's own ring, the widest symbol at 0.73": **the outer bound had been fitted to the bug**. Re-measured, the four symbols reach 0.002 / 0.038 / 0.043 / 0.107 and the nearest thing that is not one bottoms out at **0.297**, so `glyphInnerReach` goes 0.50 → **0.20**, between them rather than beside one. Why it reads as *unrecoloured source grey* rather than as the wrong colour is the tell nobody could have guessed from the code: the glyph ink is a near-white on most liveries, a near-white has no saturation to give, and the pass preserves value — so a pixel wrongly claimed by it comes out at its own value in grey. (2) **The gear is not a toothed silhouette**, which retires the coordinator's own hypothesis before it cost anything: its 360 rays run 124.5–130.5px, tighter than any of the other three, and only **2.7% of the drawing** lies outside the p10 radius — 1,376 of those 1,387 pixels being the cel outline at value ≤ 0.1. What the p10 clip *does* do is eat that outline unevenly: under 2px of it survives on **25 of 360 rays** around the cog and **none at all on 154 of 360** around the house, and an outline that survives on some rays and not others is a ragged dark rim. So the disc goes entirely: the cap is the **largest connected opaque component** and coverage ramps with each pixel's distance to the outside of it — shape-correct for a disc, for a gear, and for whatever a fifth cap is drawn as, with no constant to re-fit. What 0.8.4 introduced the disc to remove (301–630 strays per cap) is down to **159 pixels on `home` and one or two on the other three** since 0.8.5 border-flooded the shadow, and they are detached speckle, which is exactly what a largest-component rule takes. Both halves ported to Python and rendered over three liveries before the build. The four different cap colours in the photographs are `skin.buttonSet` working as designed (0.6.7, K2/K3) and were left alone. **C6 arrived with a name collision and the names were already spent**: `art/icons/stamps/stamp1.png` and `stamp2.png` came in the 0.8.4 drop and 0.8.5's F1 wired them as `BackPlateDecal.decalOne`/`.decalTwo` — drawn, imported, bundled and on the plate. Reusing them would have swapped two shipped decals for two undrawn badges, silently, since `import-stamp-art.py` copies by source stem. The decals keep the names, the badges take `stamp-all-grapes` / `stamp-all-styles`, and **the art is a genuine gap recorded two-way** in `ArtPipelineRosterTests.undrawnStampStems` — a stem on the list that has since been drawn fails the roster too, so it cannot rot. **A1 and C1/C4 are one observation applied twice**: both 0.8.5 drops draw their own container — every sticker file is a complete die-cut with a peeled corner, every stamp file a complete franked object with its own perforation — so both views split into an art path that renders the file and a fallback that keeps the code-drawn frame. The fallback is **scaled** into the smaller box rather than re-laid-out in it, because 0.7.0's E1 sized 88x104 for a two-line pixel-face title at its accessibility floor and re-flowing it at 72x66 would have crushed the title back to the ~7pt E1 spent an item fixing. **D1** was two bugs stacked: `bandPillLabel`'s own note has said since 0.8.5 that this legend must not grow with SETTINGS > TEXT SIZE, while the call site went through `DexFont.retro`, which scales — and `minimumScaleFactor(0.45)` then absorbed the overflow **per label**, which is why two lamps side by side wore two sizes. Now `retroFixed` (no scale step) plus one size fitted to the longest name in `MarqueePin.allCases`, off a **measured** advance ratio: Press Start 2P advances a full em and the `.monospaced` fallback about six tenths, so a constant would have been right for whichever face happened to be registered. Trap logged: **static stored properties are not allowed on a generic type**, and `DeviceChassis` is generic over its content — the lamp constants live in a file-private enum. Carried forward from 0.8.5's B1: GEOLOGY, RARITY, SYSTEM and CLIMATE scans still have no marquee art; nothing in this drop draws a rock, a star, a seal or a thermometer. | 446 / 177 / 124 / 33 / 106 / 26, all untouched; `firmware.ts` only | **608 tests**, clean build, `generate` (no drift) + `find-missing-refs` (zero dangling) + `icons:verify` (379 identical) + `outlines:check` (120/121 on land) green; vinodex-web `typecheck` green, **not deployed** |
| 0.8.7 | items pasted inline (no spec file), nine of them | **PICK IT UP AND MOVE IT — AND THE COLOUR UNDER THE HOUSE WAS THE SHADOW'S OWN OUTLINE.** **E1** is the item that mattered and 0.8.6's B1 is the release that caused it. That pass replaced the fitted disc with "the largest connected opaque component" and wrote down that the strays were "159 pixels on `home` and one or two on the other three, and they are detached speckle, which is exactly what a largest-component rule takes". Every word true and one measurement short: the 159 *are* detached and *are* taken, while `home`'s largest component itself carries **708 pixels past 1.05x its median radius** — 339 due south, 324 south-east, y=180..247 — where the other three carry **none**. A component rule cannot remove part of its own component, which is why the disc had been hiding this and why removing the disc revealed it. It is the **cast shadow's cel outline**: 0.8.3's B1 keys the shadow's fill out and 0.8.5's E2 made that border-connected, but neither reaches a black line, because `_is_key_shadow` needs chroma and the survivors measure (9,7,9), (8,7,9), (9,6,9) — value 8-9, `g/max(r,b)` 0.67-1.00, **neutral**. Relaxing the importer was tried and rendered: `SHADOW_VALUE_FLOOR` 16 -> 4 takes `back`'s silhouette from sd **1.33 to 5.59** and blows 502 fragments out of it, because down there the shadow's line and the *cap's* line are one colour. No threshold separates them; **what a cel line is for** does — it belongs to the thing it encloses, and this one encloses nothing. So the part is trimmed to what lies within `outlineReach` of the cap's largest **lit** region, geodesically, inside the alpha. Measured: the outline reaches **11, 12, 11** on `back`, `settings`, `user` and `12` on `home`, and `home` then carries **2,079 pixels at 13 and beyond**. At 12, `back` and `user` lose nothing, `settings` loses four pixels, `home` loses the arc. Ported to Python and rendered over two liveries before the build; the glyph mask re-measured on the reduced parts (symbols 0.019-0.596 / 0.038-0.597 / 0.043-0.578 / 0.107-0.624, nearest non-symbol still 0.297). **A1 is the user overruling 0.8.6's C6 and the reversal cost two rows and two enum cases** — `stamp1.png` / `stamp2.png` now feed `stamp-all-grapes` / `stamp-all-styles`, `BackPlateDecal` loses `decalOne` / `decalTwo`, and nothing renamed, because no end of this pipeline derives a stem from a filename. That is `STEM_FOR`'s entire purpose, tested rather than asserted. `undrawnStampStems` emptied itself by its own second rule, which is the half of a two-way backlog that exists to fire exactly once. The two decals had **no code-drawn fallback**, so they left the plate rather than becoming blank slots; nothing structural went with them, and no replacement art is proposed. **C1 does not reopen K2 rule 2 and the two are now asserted on the same routes.** Rule 2 forbids a filtered listing from borrowing its *parent category's* face; item 1 gives six of them a third identity of their own, FILTER SEARCH under `DexGlyph.search` and `marquee-mastersearch` — **art already on disk, so nothing needed drawing**, and 0.8.5 B1's four-name backlog (GEOLOGY, RARITY, SYSTEM, CLIMATE) is down to **one**, `soil`, which is the one filter kind nothing pushes as a route. Which filters convert is *derived* — a filter is a filter search exactly when it is expressible as a chip — and the two value-dependent arms were settled by measuring the catalog, not by reading code: `.type("red")` is the COLOUR chip exactly (96/96, 81/81) and `.type("Full-Body Red")` is **not** BODY (35 against 47, 20 against 67, 7 against 47, 40 against 63), so the grape *body* tile keeps STYLE SCAN; `.tasting` matches its chip on all five classes (SWEET 37/37, UMAMI 44/44, BITTER 13/13, SOUR 8/8, SALTY 4/4); `.origin` is left alone because it matches tags as well as origins and nothing routes to it. The chip is a **live control**, so `queryFilter` drops the constraint from `EntryQuery` once the chip carries it — applying both would have made turning SWEET off do nothing — and the banner goes with it. REGIONS gains a CLIMATE chip row, because the guard in `EncyclopediaListScreen.init` refuses to pre-select an option its facet does not offer and caught the gap. **A2 and A4 collide on purpose**: the artifact goes through the *same* `PlateDraggable` as the eight stamps rather than a second gesture chain, since that chain is four releases of findings (0.7.0 E2's feedback loop, 0.7.2 A2's six stamps sharing one hit region, 0.7.1 D3's unenterable hold, 0.7.2 A2's lost exclusive pair) and "as well" is an invitation to reproduce all four badly. Tap/drag arbitration is now by **movement, not duration** — a release under 8pt is a tap at any hold length — which is 0.6.7's own measurement of touch slop reused rather than a new constant, and it fixes the real defect: a press over 0.25s was claimed by the sequence, whose `onEnded` wrote the object's existing offset back over itself and buzzed, so whether one tap opened anything depended on how long your finger happened to rest. `StampLayoutStore` takes the artifact under a reserved id, a strict widening of a `[String: StampOffset]` — no decoder needed. **A3 is why the containers were visible**: `WornOverlay`'s two `.overlay`s fill the *frame*, which was harmless while both objects were code-drawn and filled theirs, and stopped being harmless in 0.8.6 when A1/C4 made them fitted art that letterboxes. It becomes a `View` wrapper rather than a `ViewModifier` for one reason — the fix needs the content **twice**, to draw and to stencil, and `Content` is a placeholder a modifier body may not reuse. **D1 is the 0.7.5 trap, avoided by construction**: folding the ladder into `seededKey` would have seeded nobody, because that flag is already true on every install since 0.7.1, and the first `announceTier` after updating would have celebrated a rank held for months. Its own flag, its own seed, plus `seedIfNeeded` on the entry page so a returning player who taps TRIED before opening the passport is covered too — `@autoclosure`, so the passport is never computed once both flags are set. Persists the **rank index**, not the rawValue, because `tiersAreNotStorage` pins rawValue == displayName precisely to keep renames free; `rankIndicesAreStable` is the new pin on what an index commits to instead. **B2**: the TASTINGS glyphs take `tint`, not 0.8.4 A2's `ink` — A2's argument is that a glyph and the title beside it are one legend in one material, which on the passport points at the row's own colour rather than at the text's. | 446 / 177 / 124 / 33 / 106 / 26, all untouched; `firmware.ts` only | **616 tests**, clean build, `generate` (no drift) + `find-missing-refs` (zero dangling) + `icons:verify` (379 identical) + `outlines:check` (120/121 on land) green; `StampArt` 10 files for 10 stems; vinodex-web `typecheck` green, **not deployed** |
| 0.8.8 | items pasted inline (no spec file), eight of them; item 4 (the flavour rework) was scoped to `sommbot` in parallel and is untouched here | **EVERY CLUE HAS A PRICE — AND THE BODY TILE WAS NEVER THE BODY CHIP.** **C1** is the item that mattered and it is the user overruling 0.8.7's C1 on this one arm. That release deliberately kept STYLE SCAN on a grape's TYPE tile, having measured that `.type(grapeStyle)` is *not* the BODY chip — 35 entries against 47, 20 against 67, 7 against 47, 40 against 63 — and the rule being applied was that a filter converts exactly when it is expressible as a chip. Every number is still true; the inference from them was too narrow. They measure the filter against the *nearest chip already drawn*, which is not the same claim as “no chip can express this”. Converting it naively would have lit a chip showing a different list, which is worse than the wrong title — so the vocabulary widened instead. Three measurements settled the shape. (1) The obvious compound, BODY ∧ COLOUR, **fails on eight of the ten values**: four of them (AROMATIC WHITE, SWEET WHITE, MADEIRA, SPARKLING RED, 14 grapes) name no body at all, and on four of the six that look like compounds the two sides disagree because `grapeBodyClass` and `grapeStyle` are separately authored — Full-Body White is 7 against 12, Light-Body White 43 against 47, Medium-Body White 18 against 22, Medium-Body Red 40 against 41. Gewürztraminer is Full, white, and AROMATIC WHITE. (2) A `.grapeStyle` facet comparing the field `.type` already compares is **identical on all ten** (43/43, 40/40, 35/35, 20/20, 18/18, 7/7, 7/7, 3/3, 3/3, 1/1), zero either way, because `wineType` and `grapeStyle` agree on all 177 grapes. (3) The same pass found the *style* COLOR tile broken three ways: it pushed `.list(category: .grapes, filter: .type(color.rawValue))`, so a RED style listed every red grape, a **ROSE or ORANGE style listed nothing** (no grape carries either word), and a DUAL style listed **all 177** via a `"dual"` special case added in 0.6.2 for that exact caller. New `EntryFilter.styleColor` sends it to styles, where its sibling CLASS tile has always gone; the special case retired with its caller. STYLE SCAN is now unreachable from `EntryFilter`. The invariant is pinned across the **whole set** rather than sampled (`chipsReproduceTheirFilters`, every cross-link the app can build): the lit chip reproduces the listing entry-for-entry *and* must not select the whole category — the second half is what `.type("Dual")` failed. **E1/E2/E3**: WHAT'S THAT…? had one cost (NEXT CLUE) and free unlimited guessing, so the dominant strategy was to spam names before spending a point, and nothing was recorded — `ScreenStateStore` is never written to disk and the route forgets its key. Now clues are priced by `Clue.Kind.weight` and bought individually, a named-wrong guess turns over the *cheapest* remaining clue (so being wrong costs the choice as well as the points) and running out loses the round; unrecognised typing is free, because a typo is not a wrong answer. The state moved out of four loose `@State` flags into `WhatsThat.Play`, which is why any of it is testable. `WhatsThatRecord` keeps played/solved/best/run behind a hand-written lenient decoder. **D1/D2**: six tools each introduce themselves once, keyed by id in one `UserDefaults` string — **deliberately no seed flag**, because the badge-burst failure mode cannot occur here (one card per navigation, and opening the shelf opens no tool), and a returning player is exactly who needs telling that WHAT'S THAT…? now charges; `markAllSeen` on the card is the escape hatch instead of guessing who has used what. The tour gained the passport, workshop and shop, its device is a fixed 300pt on every step (it was `maxHeight: .infinity`, so it grew and shrank between an 84-char body and a 175-char one), and two drifts fell out: the tools step named **master search**, which is not on that shelf, while omitting WHAT'S THAT…?, and the mocked settings grid still drew a **TUTORIAL tile removed in 0.7.6**. Both now derive from `ToolRoster` in Core. **G1**: the DATA tiles take their drawn faces in each row's own `tint` — the argument re-made rather than copied from 0.8.7 B2, and it lands on `lcd.accent` for TOTAL ENTRIES, which is the same rule reaching a different colour; driving the five real tables off `EntryCategory` fixed REGIONS and CONTINENTS having had their symbols **swapped** against the canonical table. `marquee-encyclopedia` claimed (renamed from the drop's `encylopedia`, on 0.8.3's rule that a typo in a filename is a typo and a typo in a table is a second spelling). **F1**: the stamp share card draws `BackPlateStampView` rather than `fallbackSymbol`. **H1**: SAVE THIS BUILD and SAVED BUILDS above SHELL. | 446 / 177 / 124 / 33 / 106 / 26, all untouched; `firmware.ts` only (edited in the **master** `HGapps\shared` and re-synced — it was first edited in the ios mirror by mistake and moved before the sync) | **630 tests**, clean build, `generate` (344 asset ids resolve) + `find-missing-refs` (zero dangling) + `icons:verify` (379 identical, art reproduces) + `outlines:check` (120/121 on land) + `marquee-art` (34 glyphs, rename reproduces byte-identical) green; vinodex-web `typecheck` green (its `shared/` is synced but **left uncommitted**), **not deployed** |
| — | consolidation pass, no spec: land 0.8.4–0.8.8 on `testing` and clear the flavour rework's one blocking precondition | **THE FLAVOUR IDS WERE NEVER INDICES, AND THE OBVIOUS REPAIR WAS THE WRONG ONE.** No version bump — this carries no feature and the next batch is to be 0.8.9. Four releases had accumulated as a chain of local batch branches with 0.8.8 **uncommitted**, so `v0.8.8-batch` held zero commits of its own and a merge would have landed 0.8.4–0.8.7 and silently dropped the fifth; committed first (`54658d0`, explicit `add -A` because only two PNG renames were staged), then `testing` fast-forwarded — verified as a strict ancestor with **zero divergence**, which is 0.7.8's precedent applied rather than assumed. The "six releases behind" figure carried in `dexbot.md` was **four**. **The Batch A item.** `constants.ts` derived flavour ids as `` `FLAVOR-${idx + 1}` `` inside a `Map.forEach`, whose callback is `(value, key, map)` — `idx` was never an index, it was the lowercased note, and every id shipped as `FLAVOR-blackcurrant1` with **37 of 106 carrying a space**. Nothing caught it because nothing reads a flavour id except `Bookmarks`, on a user's disk, where `saved(in:)` **silently drops** what it cannot resolve. **The intended repair — `FLAVOR-1`…`FLAVOR-106` — was rejected on measurement, not taste**: the other four categories *author* their ids (`G001`, `R001`, `S001`) in data files and those never move, while flavours have no data file at all — the set is derived from the union of every grape's tasting notes, in grape-file order — so a positional id renumbers whenever a note is added to an early grape or retired, which would break saved entries on ordinary catalog growth and is a *worse* failure than the one being fixed. Slugs move only on a rename, which is a deliberate act. Verified 106 notes → **106 distinct slugs, zero collisions**, all `[A-Z0-9-]`. All 106 ids change at once and **no alias table is carried**: pre-0.8.9 saved flavours are lost by ruling, not by accident. New `assertFlavorIds` covers three things nothing else could see — id shape, id **uniqueness** (the load-bearing half: two notes slugging to one id would silently merge two entries while the count still read 106), and **orphaned `FLAVOR_ART` keys**, which converts the whole rename class from silent to loud and is the precondition the flavour plan's Batch C renames need. Both halves negative-tested against injected faults (a renamed art key; a truncated slug forcing Blackcurrant/Blackberry and Honey/Honeysuckle to collide). **Two claims carried this session were wrong and are corrected here**: `flavorDisplay.ts`'s six missing subclass colours are real but the module has **zero importers**, so the "16 flavour entries draw grey on web" precondition is dead code and not a precondition; and MASTER SEARCH / FILTER SEARCH is **not** an inconsistency — `EntryFilter.swift:248-252` documents the distinction (one searches the whole catalog from nothing, the other opens already narrowed), so no rename was made though neither string is persisted and it would have been safe. **vinodex-web committed** (`a34a54e`), which surfaced two failing determinism goldens in `quiz.test.ts`; they are a refactor guard whose own note says to regenerate deliberately rather than paste a failure, so the pins were re-derived by running `quizQuestion` over the current catalog — the tell that it is the catalog and not the algorithm being that seed -13 now opens on `S033` and seed 777 deals `R124`, a style and a region that did not exist when the old pins were taken. | 446 / 177 / 124 / 33 / 106 / 26, all untouched; **all 106 flavour ids change** (`FLAVOR-blackcurrant1` → `FLAVOR-BLACKCURRANT`); `constants.ts` in the master `HGapps\shared` | **631 tests**, clean `xtool dev build` (0 errors) on the merged `testing` *and* after Batch A; `generate` (no drift, 344 asset ids resolve) + `find-missing-refs` (zero dangling) green; vinodex-web 363 tests + `typecheck` green and **committed**; **not pushed** — `testing` has no upstream, so it is `git push origin testing` |
` as one grapheme, so `split(separator: "
")` over a CRLF script returns the whole file as one line — the new roster parser read zero rows and looked like a missing table. | 446 / 177 / 124 / 33 / 106 / 26, all untouched; `firmware.ts` only | **608 tests**, clean build, `generate` (no drift) + `find-missing-refs` (zero dangling) + `icons:verify` (379 identical) + `outlines:check` (120/121 on land) green; 30 new bundle PNGs, 4 `FooterArt` re-exported, **not deployed** |
| 0.8.9a | `vinodex-9.0-icon-wiring.md` + `vinodex-9.0-implementation.md` (the user calls the feature v9.0; it is 0.8.9, in four sub-batches) | **THE DROP SORTS INTO THREE REGISTERS, AND THE PIXELS SAY WHICH.** Sub-batch A, the art foundation. **No firmware bump** — 0.8.9 lands as one changelog entry with the final sub-batch, so the entry describes the feature rather than four fragments. **A1** is the restructure the user asked for with latitude: `art/icons/` goes from a flat 22 directories to `entries/` (art *of* what the catalog names) + `chrome/` (the device's own furniture) + the two registers nothing reads. The split is the one the importers already argue for in prose — `import-marquee-art.py` spends three paragraphs on why a dot-matrix `grapescan` and a painted `grapes` are different registers of one subject — and the top level now states it. `artifacts` → `chrome/stickers` makes `PixelArtLoader`'s own comment true after two releases of naming a directory that did not exist. Eleven importers, four test paths, one npm script; **proved inert before a single new asset landed** (`icons:verify`, 379 identical), which is the only reason a 426-file move is a safe thing to do in the same batch as 32 wirings. **A2/A3 needed no judgement about the split, because the drop measures.** The 32 files fall into three groups by pixel statistics and the delivery's own `*icon`/`*glyph` naming tracks the boundary exactly: 20 carry a magenta key, a cel outline over 13–25% of the canvas and cream highlights at (247,222,182) — `chrome/buttons`' register; 5 carry **zero pixels below value 110**, which is `import-marquee-art.py`'s own measured signature for "no cel outline to protect"; 6 arrive already cut with alpha and no key at all. Two importers, six rosters each, and `glyph-` was load-bearing on arrival rather than tidy — `tools`, `firmware`, `seal` and `stamp` are words `ButtonArt`, `MarqueeArt` and `StampArt` already own, so three live drawings would have been shadowed by list order in a flat namespace. `UIGlyph` and `VinoExpression` give both sets a Core type so the directory, the type and the bundle are held equal from today rather than from whenever phase 2 arrives. **A5 closes the 0.8.5 backlog the way it was supposed to close**: B1 left four scans with no face, and 0.8.7/0.8.8's C1 retired three of the names by making those filters stop being scans — real fixes, and zero drawings. GEOLOGY needed a rock and now has one. The `artless` pin flips 1 → 0 and is **kept at zero**, so the next filter kind added without a face fails instead of joining a backlog that has a documented member and therefore looks healthy. **Three spec rows were wrong and the code was right**, which is why the reconnaissance ran first: `labelscannerglyph` and `flavorscanglyph` are marked ✅ for homes that have shipped art since 0.8.4 — they are redraws at twice the dot pitch with scan-reticle corners no other of the 34 carries, so they are parked in `attic/` one `git mv` from adoption; the daily-challenge fix was already half-done (the Tools tile has had the art since 0.8.1, the streak counters had not); and the ladder the five shields map onto has **four** rungs, not five, so `level5` is parked and a fifth rung is an *append* with the art already on disk. `profvino.png` is the contact sheet the six expressions were cut from — `reference/`, with the other source sheets. Eleven of twenty glyphs parked, each named two-way in `UIGlyph.unwired` with its reason; `battery` is the one that can never be wired, because `BiosBatteryGlyph` makes its fill a function of `UIDevice.batteryLevel` and a sprite would have to be eleven sprites. The gates earned their keep twice: a **fourth** test file read the moved tree (`CartridgeArtTests`, which builds its path a different way and survived the grep), and 0.8.7's `filterSearchIsOneDestination` pinned the borrowed magnifier A5 was replacing. | unchanged — no `shared/` edit, no generated-data drift; `firmware.ts` deliberately untouched | **633 tests** (631 + 2 new rosters), clean build, `generate` (no drift, 344 ids resolve) + `find-missing-refs` (zero dangling) + `icons:verify` (**408 identical**) + `outlines:check` (120/121) green; **not deployed** |
| 0.8.9b | `vinodex-9.0-implementation.md` **phase 1 only** (A/B/C) + three copy corrections from `sommbot` + the user's five-rung passport ladder, folded in mid-batch | **THE TRIED SHELF WAS ALREADY THERE, AND THE FIFTH RUNG WENT ON THE BOTTOM OF A LADDER THAT ONLY APPENDS.** Sub-batch B, discovery core. **No firmware bump** — 0.8.9 still lands as one entry with phase 3, and 0.8.9a's reasoning is unchanged. **A1 is the item the reconnaissance overturned.** The spec asks for a `DiscoveryStore` holding `triedGrapeIDs`, `triedStyleIDs` and a first-tried date each — and every one of those facts already ships: `Shelf.tried` since shelves landed, `triedEntryDays` since 0.7.1's D1, entry ids as the keys. A second store would have forked the truth at the worst possible place, because the tried count drives the rank ladder, six of eight badges, the activity graph and both completion stamps; a player with eighty entries marked would have opened a Discovery panel reading zero. So `DiscoveryStore` is a **façade** over `BookmarkStore` (which keeps being the one place membership changes, so a scanned tasting still clears the wishlist and gets dated), and the new type worth having is `DiscoveryIndex` — the *split*, which needs the database `BookmarkStore` deliberately does not hold. **A3 already existed** as the TRIED pill. **C2's badges were not unwired** either: `Passport.compute` did the grape/style split itself, and so did two other places, so the batch's real C2 is that the four completion conditions moved onto `DiscoveryIndex` **verbatim, guards included** — grapes folded by name, styles by id, both non-empty — and the counters, the panel and the badges now read one definition instead of three. **A2 asks before it writes, against the spec's letter.** The results screen heads its two lists POSSIBLE GRAPES and POSSIBLE STYLES and means it: `grapeIDs` is usually *inferred from the place*, so a Bordeaux label yields six grapes the bottle held some subset of, and a scan taken in a shop yields the same six. Silent marking would move the ladder, stamp the graph and count toward the two hardest badges on evidence the app itself calls possible, undoable only by visiting seven pages. One tap for six grapes and a style is still the fast path — the comparison is seven visits, not zero taps. **B: INSIGHT is the player-facing word and the type name, deliberately the same word**, because the same batch fixed `ToolIntro`'s "the written paper" — a string that drifted from the identifier beside it and survived 0.8.0's whole rename — and choosing a prettier synonym for the header would be starting that fault on purpose. Phase 2's copy is written against INSIGHT. Seven line kinds, each declaring the `InsightDepth` it unlocks at (1/5/15/40) so "the panel deepens" is a Linux-testable fact rather than a screenshot; the spec's fourth example, pairings weighted to history, **has no data to derive from** (`Exam.Subject.foodPairing` is a quiz category, not a field) and is not faked. **The ladder was the dangerous half.** The user's APPRENTICE/MASTER/GRANDMASTER/LEGENDARY/WINE MONK is a *prepend*, and 0.8.7's D1 persists `PassportTier`'s **declaration index**; a literal prepend shifts every stored index by one, so everyone stored at 0 decodes as APPRENTICE, is found to hold MASTER, and gets a second MASTER card. Of the three ways out — migrate every stored index, store something other than the index, or stop making declaration order carry two jobs — the third is the only one that writes nothing to a device: `apprentice` is **appended** at index 4, MASTER stays 0, and `PassportTier.ladder` sorts by threshold instead. Everything meaning "higher" now compares **thresholds**, including `announceTier`, because APPRENTICE has the highest index and the lowest rung and raw-integer comparison would have gone permanently silent after one tasting. `tiersAreNotStorage` still holds — the renames and the dropped `VINODEX ` prefix cost nothing, which is the promise it was written to guarantee — and `rankIndicesAreStable` was **rewritten rather than deleted**, now pinning the four frozen indices *and* that declaration order is not the ladder, plus a test that replays the literal 0.8.7 on-disk byte and expects silence. `level5` came off `UIGlyph.unwired` and the two-way gate flipped exactly as built to (its message read "level5 has a rung now — take it off the list"); the shields are ladder positions, so **four existing tiers change picture** — MASTER goes from shield I to II. Nothing else was adopted from `unwired`: none of the parked candidates depicts a derived readout, so INSIGHT takes an SF Symbol. One performance find: the panel rebuilds an index on every body evaluation and the entry screen re-evaluates **on scroll** (its anchor is state), so the catalog half folded ~180 names per scroll event — exactly what `byName` was extracted to stop — and is now `WineDatabase.discoveryCatalog`, one pass at load, with a two-way drift test. | unchanged — **no `shared/` edit, no generated-data drift**; the tried set is user state in `UserDefaults` and never reaches `entries.json`, which is what keeps the data-drift job green | **673 tests** (633 + 40 new: Discovery, Insight, the ladder rewrite), clean `xtool dev build` (0 errors, `Build complete!`); **not deployed** |
| 0.8.9c | `vinodex-9.0-implementation.md` **phase 2 only** (D/E) + `data-review/VINO-DIALOGUE.md` (`sommbot`'s reviewed line set, which supersedes the voice bible's drafts) | **HE HAS TO WAIT HIS TURN, AND THE NAME HE ALREADY HAD WAS ON DISK.** Sub-batch C, the presenter and the triggers. **No firmware bump** — 0.8.9 still lands as one entry with phase 3, third batch running, reasoning unchanged. **E3's open call went to Core, not `shared/`.** The spec offers a resource JSON or `shared/` → generated, and the closest precedent is neither: `ToolRoster` is authored, player-facing, first-run, one-shot copy with persisted ids, living in Core behind a test — which is what this is, and which `sommbot` already named as the structural precedent for `FirstTimeTriggers`. `shared/` is the catalog and is master-synced into `vinodex-web`, which **reads neither `exam.ts` nor `firmware.ts`**; those two are already authored-copy dead weight in the mirror, so a third would extend a wart rather than follow a pattern. The deciding argument is where the gate can run: every invariant here is a statement about strings *and* about the Swift vocabulary consuming them, so a generator assert would check half and still need a Swift test for the half that matters. `VinoDialogue.problems()` is one function, `assertFirmware`'s shape moved to where the consumers are. **The ASCII rule earned its keep on arrival**: the reviewed set carries four em dashes and two chirps holding a `U+25B9` arrow and another em dash, all of which render as blank boxes in VT323 over Press Start 2P — the exact failure `assertFirmware` exists to prevent one panel over. The chirp became its own field (`VinoChirp`) so the sentence never has to carry punctuation the font cannot draw. Scoped to Vino's copy and **not** widened to all shipped strings, because `ToolRoster` ships `WHAT'S THAT…?` with a real `U+2026` and widening would have changed a shipping title as a side effect of a dialogue batch. **Both proposed gates were worth building.** The retired-term denylist runs over `VinoDialogue` *and* `ToolRoster`, matching on word boundaries so `ACCESS` does not fire on "accessible" — it converts the drift that hid "the written paper" through 0.8.0's whole rename from a review finding into a build failure, and the next authored set is one `append` away from being covered. The gag ratio is `gag * 4 <= total` (4 of 17) **plus a floor**, because a well-meaning copy pass that deleted the character's one joke would have passed a cap. One correction on top of the reviewed set: `firstInsight` says **INSIGHT**, uppercase — `sommbot` wrote "Insight" while §B did not exist and flagged it to be re-checked, §B shipped the header as INSIGHT, and this set's own rule is to use the shipped string (it already writes TRIED, SHOP, GODFORSAKEN). **The name was the reconnaissance find.** §6.3 asks for a new persisted key treated as immutable; the app has stored `userDisplayName` for releases, editable on the USER screen, wiped by CLEAR SAVED DATA, and **already rendered onto share cards** — so the leaving-the-device flag §6.3 raises is pre-existing rather than introduced here. A second key would have been two names for one person and would have asked a player who had already answered; the literal moved to `VinoName.storageKey` and `UserProfile.displayNameKey` forwards to it, so a key `ACCESS` taught us cannot be renamed has one spelling. `explorer` stays the lowercase fallback and the sentence-initial ban that follows is **enforced three lines from where it is stated**, not remembered. **The first-run trap, third batch running, answered by shape rather than by a flag.** 0.8.8's `ToolIntroStore` shipped without a seed and was right to: one card per navigation, and opening the shelf opens no tool. Fifteen triggers across the app does not inherit that for free, but neither does it need the opposite — sorting them by *what can make them true* splits them cleanly. Twelve are navigation or action driven and keep 0.8.8's reasoning verbatim; three (`firstTried`, `firstInsight`, `firstStamp`) are computed from state an existing player already has on disk, which is `PassportProgress.seed`'s exact failure mode and gets its exact answer. Seeding the lot would have silently robbed every existing player of the entire character — the opposite failure and a much quieter one — so `seedLeavesNavigationTriggersAlone` pins that half too. The seeded flag is separate from the emptiness of the set for `PassportProgress`'s stated reason. **The ToolIntro collision is sequenced, and suspension is a set of reasons rather than a boolean** — which the code forced: `RootView` owns the BIOS, the tool card, the paywall and the data notice, but the stamp celebration and the rating prompt are raised *inside* `EntryDetailScreen`, which is precisely where `firstTried` and `firstStamp` fire, and `PassportScreen` raises the same prompts on the arrival that fires `firstPassport`. Two writers to one boolean is a race whose losing case is a bubble across the celebration it is congratulating. The line is **held, not dropped**, which is the half that would be invisible if it were wrong. **Two trigger conditions were nearly wrong for the same reason — the obvious predicate was the wrong one.** `firstInsight` keys on `panel.lines`, not `panel.isEmpty`, because `InsightPanel.isEmpty` is false in the *teaser* state too and the obvious version would have fired "INSIGHT unlocked" on the first grape a brand-new player opened, before anything was; `firstScan` fires on `.identified` only, because spending the once-ever bubble on an ambiguous shortlist would be both a lie and unrecoverable. **Deferral is a declared field, not a comment**: `firstLaunch` and `firstLaunchNamed` wait for phase 3, which owns the capture field a question needs, and `firstFlavorViewed` waits for the flavour rework's Batch C on `sommbot`'s own declaration — all three are still checked by every rule, still hold their keys, and `fireOnce` returns nil **without burning the key**, so switching one on is deleting a string. The route table lives on `FirstTimeTrigger`, not in `VinodexApp`, for `ToolRoster.intro(for:)`'s reason: that module is the one no test can see, so `routeTriggersAreReachable` walks it both ways and copy that is written and never raised is a failure rather than a thing nobody notices. One arrival can owe two lines (a Godforsaken grape opened first), which is why it returns a list and why there is a queue at all. **No `silenceAll`**, deliberately: seeding removes the returning-player problem `ToolIntroStore.markAllSeen` exists for, what remains is a hide-him preference belonging in SETTINGS > DEVICE beside the re-runnable tutorial (§G2, phase 3), and shipping a public method with a test and no call site is the "written, shipped, never raised" fault the rest of this batch builds gates against. | unchanged — **no `shared/` edit, no generated-data drift, no generator run**; the copy is Swift in Core and the seen set is user state in `UserDefaults`. `firmware.ts:336`'s British "customise" is **left alone**: it is inside 0.7.6's archived release note, and a changelog is a record — `Walkthrough.swift`'s live instance was already fixed in 0.8.9b | **703 tests** (673 + 30 new: the copy gates, the trigger vocabulary, the seed split, the queue), clean `xtool dev build`; **not deployed** |
| 0.8.9d | `vinodex-9.0-implementation.md` **phase 3 only** (F/G) | **THERE WAS ALREADY A TUTORIAL, AND IT HAD DRAWN THE LINE ITSELF.** Sub-batch D, onboarding, and **the batch that bumps the version**: 0.8.9 lands as one changelog entry covering all four, which is what a, b and c each held off for. **The design question first.** §G2 asks for a skippable, resumable, re-runnable-from-SETTINGS-`>`-DEVICE walkthrough — the same slot, the same entry point and roughly the same subject as the twelve-step tour 0.7.6's F1 moved there and 0.8.8's D2 rebuilt. Two tutorials in one menu would have passed every gate in the repo. **The line was already drawn, in `WalkthroughScreen`'s own note**, which rejected live spotlights because the tour "would have to drive the navigation stack ... and a user who tapped something mid-tour would end up somewhere the script did not expect". Every one of those objections is about a tour that *drives*; §G1's rule is that a coachmark advances only when the user acts, so this one follows and cannot desynchronise — `report(_:)` is the only way forward and it is called by the thing happening. So they are not two tutorials but the two halves that note split apart: the diagram teaches the *device* (furniture, controls that change meaning between screens, the shop, the workshop — none of it reachable without driving), the spotlight teaches the *loop* (six things done with a thumb, which is exactly the tour's steps `screen`, `entry` and `passport` performed instead of read). **One row, therefore**, and the hand-off is the tour's last step, which has always ended by telling you to go and press something. Cost stated rather than hidden, in 0.7.6 F1's manner: wanting only the live half means pressing NEXT to the end of a twelve-page tour. **§F1 and §G2 disagree, and it is settled rather than built twice.** They are the same walkthrough described by what it achieves and by how it looks; where §F1 opens LABEL SCAN and §G2 opens a category, the catalog wins on four counts — a fresh install meets an **iOS camera-permission dialog**, it needs a **bottle** (§F1 concedes this with its own sample fallback, and a fallback that fires for most first launches is the main path), **0.8.9b's A2 deliberately made scan results ask before marking**, and §G2 is the sequence the spec asks to be built. **Neither ask is routed around**: the tried step advances on `CoachmarkAction.markedTried`, the *write landing* rather than a screen, so a player who does have a bottle and confirms a scan mid-walkthrough advances the same step by the same rule — the confirm is one of two doors onto one action, not an obstacle in front of one of them, and it needs no branch in the sequence. The scanner keeps its billing as the star path by being what the closing line hands you. **No hardcoded sample entry**: step two lights the listing's first row, so the wine is one the player picked, and a pinned id would have been a data coupling `CoverageTests` had to hold. **The third teaching layer, sequenced.** Tool cards (0.8.8 D1), seventeen first-time bubbles (0.8.9c) and now a spotlight could meet on one screen. The bubbles are **held** through the suspension set — joined, not duplicated — and the set gained `isSuspended(otherThan:)` because the spotlight is the first writer that also has to *read* it: it holds the queue while it runs, and must itself stand down for the rating prompt its own spotlit TRIED tap raises inside `EntryDetailScreen`, or its input barrier would trap the player behind a modal it is covering. Tool cards are simply suppressed, which costs nothing because they are re-derived from the route rather than queued. On finish the queue is cleared: everything waiting was about a screen the walkthrough just narrated. **The dim is a hit-test barrier**, which is what answers `WalkthroughScreen`'s desynchronisation objection — only the cut-out passes touches, so the strict route arm (`.list(.grapes)` and nothing else) never sees an arrival it did not ask for. Four bands rather than one even-odd shape, because hit-testing a filled path does not honour the fill rule and a hole that swallowed its own taps would be unadvanceable; the *dim* is the even-odd path and does no hit testing. SKIP is always drawn and always live, so a target whose anchor never resolves degrades to a bubble with a way out. It is **the one overlay that covers the chassis** rather than living in the LCD, forced by the passport step pointing at the USER button; one target id (`passportButton`) is published by the chassis button and by `BookmarksScreen`'s PASSPORT row, one on screen at a time. **Resumable means more than not-completed.** Each step declares `isAnchor` — reachable from Home without having navigated — and a resumed run rewinds to the last anchor at or before the high-water mark, so quitting on the entry page returns to the menu step and quitting on the passport step returns exactly there. Skip keeps the mark and does not complete; a *completed* walkthrough re-runs from the top. **The first-run trap, fourth batch running** (0.8.7 D1, 0.8.8 D1/D2, 0.8.9c E1), and here the blast radius is a six-step spotlight over the whole screen on the launch after an update rather than a bubble: `seed(hasHistory:)` reads three signals (any tasting, anything saved, or a name typed on the USER screen), because a player can have used this app for a year without marking a wine. **No seeded flag**, deliberately the opposite of `FirstTimeTriggerStore` one sub-batch ago — that store needed one because "seeded to empty" and "never seeded" decode identically, whereas this seed only ever sets and only on a yes, so it is idempotent and running it every launch is free. **§F1's intro cost what Phase 2 predicted**: a text field plus two `fireOnce` calls. Both launch lines come off deferral; the keys are burnt when the card *finishes* rather than when it draws, so an app killed on the name field has not spent its introduction; SKIP and DONE both land on the greeting page, because `firstLaunchNamed` carries the division of labour every later line assumes; and a player who named themselves on the USER screen in 0.7.x never sees page one, which is the promise 0.8.9c made when it chose `userDisplayName` over minting a key. **`silenceAll` resolved as a preference, not a method.** 0.8.9c declined to ship it without a call site; the call site is a PROFESSOR VINO row beside TUTORIAL, and the case for it is the **returning** player, who meets fourteen deliberately-unseeded triggers over their next few sessions in an app they already know. It is a **filter, not a consumption** — silenced lines return nil without burning the key, exactly as deferred ones do — and it does not touch the tutorial's bubbles, which are content the player pressed a button to start; the row says so rather than half-working. `RetiredTerms` widened to the tour, which is the third authored set and the one with form (0.8.8's D2 found it naming a tool not on the shelf). | unchanged — 446 / 177 / 124 / 33 / 106 / 26. **`firmware.ts` only**: `CURRENT` → 0.8.9 with the whole-release entry, 0.8.8 displaced to the head of `PREVIOUS`; `npm run generate` moved `firmware.json` and nothing else, and `find-missing-refs` is zero dangling. `vinodex-web` typecheck green, its `shared/` committed | **726 tests** (703 + 23: the sequence and its order, advancement, skip/resume/anchor, the seed split, the silence filter, the suspension read, the tour hand-off), clean `xtool dev build`; **not deployed** |
| 0.8.2 | sommbot's data-pass handoff + five coordinator items | **THE LINEAGE DATA ARRIVES, AND THE TILES BUILT FOR IT MEET THEIR FIRST USERS.** Sommbot takes authored lineage from 61 grapes to **163** and sets `parentageUnknown` on **74**; iOS lands the pins and finds the handoff wrong in three places. **The category is not empty**: `derivedOnlyGrapesAreConnected` was told to retire because "zero grapes are connected only by derived edges", and there are **fourteen** — Nebbiolo among them. Its old assertion `lineage == nil` was a proxy for *authors no edge*, and 0.8.2 is the batch that pulled the two apart. Handoff also missed `siblingsGroupThroughExternalParents` (Gouais Blanc 10 → 13 children) and claimed `colorOverridesResolve` was red when only its **title** was. The 0.8.0 `.unrecorded` tile and 0.8.1's off-catalog box had never drawn for a real entry in three releases and now serve 32 and 69 respectively. Plus a live `related` de-dupe defect pinned before data could trip it. Coordinator: **four drawn footer caps** that are whole moulded buttons rather than glyphs, re-inked per skin by a `GrapeSpriteLoader`-shaped HSV pass; **17 drawn cartridges** on the shop shelf and three times larger on the splash; display packs previewed as **screens** rather than as a device with a tinted sliver; and a share sheet that finally has a header, via `LinkPresentation`. | 446 / 177 / 124 / 33 / 106 / 26, all untouched; `grapes.ts`, `styles.ts` (S033/S034 → ORIGIN), `entryUtils.ts` (`madeira` → WHITE), `types.ts`, `firmware.ts` — all sommbot's | **596 tests**, clean build, `generate` (no drift) + `find-missing-refs` (zero dangling) + `icons:verify` (312 identical) + `outlines:check` green, **not deployed** |
| 0.8.1 | `vinodex-0.8.1.md`, sections A–F, H–J (**G held**) | **PROSECCO IS NOT A ROSÉ.** A bug hunt that turned out to be a whole missing table: `EntryDisplay.colorType` is a port of `entryUtils.ts`'s `getColorType` and had never carried `STYLE_NAME_COLOR_OVERRIDES`, so **16 of 33 styles reported a different colour on the device than in the data** — 15 silently as DUAL, and Prosecco as ROSÉ because the port matched substrings and `"p*rose*cco"` contains one. Fixed as a port plus a cross-end pin (`palette.styleColorTypes`), then **D** spends it: COLOUR and COUNTRY join STYLE CLASS on the styles list. **F3** was expected to be the same shape and was not — the keys matched perfectly; `getFlavorSubclassChipColors` simply had no case for six ids and its `default` is byte-identical to the reader's fallback, so six chips were the neutral *written into the table under a valid key*. **J** wires 30 of 32 new button faces in behind a fitted square box, through an eighth importer registered in all four rosters and both search paths. Plus a lineage tree whose connectors now reach the boxes, a marquee glyph that dissolves with its word, and a toast that changes language every five seconds. | 446, untouched; `chipColors.ts`, `colorUtils.ts`, `entryUtils.ts` (`MARINE` retired), `firmware.ts` | 590 tests, clean build, `generate` + `find-missing-refs` (zero dangling) + `icons:verify` (291 identical) + `outlines:check` green, **not deployed** |
| 0.7.6 | v0.7.5 spec (lands as 0.7.6), sections A–F | **THE CONSOLIDATION.** The Decision: three ways to reach the same places become one — the two marquee lamps *are* the pins, always visible, each reassignable by holding it. `MarqueeDrawer` deleted, the corner pin buttons deleted, the panel is a display again. `QuickPinStore` reused, not forked: `MarqueePin`'s raw values are a superset of `SettingsSection`'s, so no pins are reset. The idle timer stops being two stages (screensaver 15→**30s**, the marquee greeting folded into it and firing on **any** screen, revertible by giving `IdleSchedule.toast` a number back); the screensaver gets a random start, kept as a phase so the closed form survives. Plus two new workshop axes (10 in all), the **W64** shell, a stadium orb, bigger shop splashes with previews of their contents, and the tutorial into SETTINGS > DEVICE. | 438, untouched | 501 tests, clean build, `npm run generate` + `find-missing-refs` + `npm run icons` green, **not deployed** |

**0.7.5, The Wine Exam** (v0.7.5 spec, section D). The second split batch:
`sommbot` authored the 407-question bank, `dexbot` built every consumer of it.

- **D1's naming collision resolved to *absorb*, and the code decided it rather
  than taste.** The question was whether the Wine Exam replaces, absorbs or sits
  beside the existing `TastingQuiz` ladder. Four pieces of shipped evidence, all
  found by reading before writing: `DexRoute.wsetQuiz.title` has been the string
  `"WINE EXAM"` since 0.5.9; that screen's picker is headed CHOOSE YOUR EXAM and
  its way out says BACK TO EXAMS; and `StampCatalog`'s SOMMELIER stamp — a
  *shipped, earned* back-plate stamp — describes itself as "The Wine Exam's top
  tier, unlocked". There was never a second feature to sit beside. D1 asks to
  expand the Wine Exam, so `.wsetQuiz` is the same door with a different room
  behind it.
- **Two tier vocabularies, one ladder, and the device's words win.** The bank is
  authored `beginner`/`intermediate`/`advanced`; the device's ladder is
  `QuizTier`'s NOVICE/ENTHUSIAST/SOMMELIER. `ExamTier.ladder` maps them 1:1 and
  in order (`examTierMatchesLadder` pins the bijection both ways). The device's
  words win for two reasons that are not preference: `QuizTier`'s raw values are
  **persisted** in `quizTierUnlocked`/`quizTiersCompleted`, so a user's SOMMELIER
  unlock is a string on somebody's disk; and they are printed on a stamp that has
  already shipped. The bank's words never reach the screen. Everything the old
  practice paper had — the ladder, the locks, the completion stars, the passport
  badge — carries over untouched, because none of it was ever about where the
  questions came from.
- **`TastingQuiz` was not retired, and the split is deliberate rather than
  leftover.** It keeps the **daily challenge**, and it should: an authored bank
  is finite (407 questions at five a day is under three months before repeats)
  and a daily that must be the same paper for everyone, every day, forever is
  exactly what a generator answers and a bank cannot. The generated paper also
  cannot contradict an entry. What *did* go is `TastingQuizScreen`'s `.practice`
  mode and the `QuizMode` enum with it — a two-case enum with one case left is a
  parameter every call site passes and none can vary.
- **The shuffle is the whole reason the engine exists, and it is falsifiable.**
  Authored option order *is* answer order, matching pairs are authored paired and
  ordering items authored in sequence — the only sane way to author them and
  completely unusable as a presentation. `ExamPrompt` is the presentation layer:
  a seeded permutation stored alongside the question, so grading is a lookup
  rather than a second guess at what the user saw. `shufflingMovesTheAnswer` is
  the falsifier — it measures the share of questions whose answer lands in slot 0
  across every single-answer question in the bank and fails at 100% (never
  shuffled) *and* at 0% (always moved off zero, which would make slot 0 never
  correct — a bigger tell than the one it fixes).
- **Ordering is the one format where the identity permutation is a bug.** A
  three-item ordering shuffles to its authored order one run in six, and an
  ordering question presented in the authored order is presented *already
  solved*. `ExamPrompt` swaps the first two when the permutation comes back as
  the identity, and `orderingIsNeverPreSolved` checks all 18 ordering questions
  against 200 seeds each rather than sampling — the identity is precisely the
  case a sampled test misses. Options are deliberately **not** corrected this
  way, for the reason above.
- **A paper that runs dry says so.** The brief's line — a generator that silently
  repeats when a cell runs dry is worse than one that says it cannot — is
  `ExamAssemblyFailure`, returned rather than papered over. `EXAM_MIN_CELL_COUNT`
  (6), not the 407 total, is the real bound: `balancedCapacity` is the thinnest
  cell times sixteen categories, and past it a paper leans on the fat categories
  rather than failing. Both behaviours are pinned —
  `fullLengthPaperIsDistinct` asserts an exactly-even split at the ceiling and
  `beyondCeilingStillDistinct` asserts no repeat when the *whole tier* is drawn.
- **Balance is a seed-rotated round robin, which buys three things at once.** Ten
  questions over sixteen categories means ten *different* subjects per paper
  rather than three about grapes; the rotation moves *which* ten with the seed,
  so consecutive papers examine different ground rather than the same ten
  subjects with different questions; and an exhausted category is skipped, never
  re-drawn, which is what makes "no question twice" structural rather than
  checked afterwards.
- **`ExamRun` stores the seed, not the paper.** `ExamPaper.assemble` is pure, so
  a run round-trips through `ScreenStateStore` as one integer and re-derives ten
  questions with their options, explanations and shuffles exactly. `QuizSession`'s
  arrangement, applied to a much larger payload — the alternative was a few
  kilobytes of question text re-encoded on every tap.
- **All-or-nothing on `selectAll`, and the reveal is where the nuance goes.**
  Partial credit was considered and rejected: `correct` is an integer out of
  `length` on a results card and against a pass mark, and a paper where one
  question is worth two thirds makes both numbers a lie. The reveal still marks
  each option individually, so nothing is hidden — the *score* just does not
  claim a precision it has no scale for.
- **Matching and ordering are tap-only, and 0.7.2's A2 is why.** They are the two
  formats a desktop would do with drag and drop. Adding a third drag gesture to a
  2.5-inch LCD that already arbitrates the stamp drag and the globe pan is how
  0.7.2 spent two batches on a control that never received a touch — and
  `VinodexUI` is invisible to the Linux tests, so nothing would have caught it.
  Matching is *arm a left row, tap its right*; ordering is *tap in order, tap
  again to unset*. Neither negotiates with anything.
- **D7 is the reveal, not a results-screen appendix.** Verdict, then the
  explanation, then the source where the claim needed one, then the question's
  `entryRefs` as the same `EntryTileView`s they are everywhere else — which
  **generalises the old quiz's best idea** rather than losing it. The generated
  quiz's reveal worked because every option was a real entry with a page behind
  it; an authored bank cannot promise that, but 316 of 407 questions carry
  catalog ids, so a question you got wrong still ends one tap from the page that
  would have told you. Capped at three tiles: a reveal is a moment, not a reading
  list.
- **D6 reuses three stores and forks none.** `QuizProgress` keeps the ladder
  (`ExamRecordStore.record` calls straight through to `recordPass`), `StreakStore`
  keeps the *calendar* streak, and the new store holds only what neither had: a
  bounded history of results. Every statistic is **derived** from it —
  accuracy, full marks, best-by-tier, per-category — rather than incremented
  beside it, because a counter and a list are two facts that can disagree and it
  is always the counter that is wrong. `passStreak` is deliberately not folded
  into `StreakStore`: that one counts *days* at one sitting per day, and you can
  sit four papers in an evening.
- **The pass streak saturates at 100 and the test says so rather than being
  written around it.** It is derived from a history bounded at `historyLimit`, so
  120 consecutive passes read as 100. The test was written expecting 120, failed,
  and the *finding* was kept: the alternative is a stored counter beside a stored
  list, which is the thing the store exists to avoid. Pinned at
  `historyLimit` with the reasoning, so the saturation is a decision.
- **The statistics screen's useful half is the weakest subject, and it has a
  sample floor.** One wrong answer in one FORTIFIED question is 0% and would sit
  atop a weakness list forever, ahead of a subject genuinely being failed half
  the time. `weakest(minimumAsked: 3)` is the floor, and
  `weakestNeedsASample` pins that removing it changes the answer.
- **`sommbot`'s handoff item 1 was half wrong, and checking it saved an edit.**
  It asked for `Package.swift` resource wiring alongside the `exam.json` emit.
  `VinodexCore` declares `.copy("Resources")` — the whole directory, not a file
  list — so a new `Resources/*.json` needs no Package.swift change at all. The
  emit was real and is done; the wiring never existed to do.
- **The exam arm of `find-missing-refs.mjs` is the lineage arm's shape and was
  proved the same way.** Like lineage it does **not** go through the name index,
  for the reason sommbot gives: `entryRefs` are ids because the grape-name index
  over-lumps, so a *name* here is a mis-authored ref rather than a resolvable one
  — and it is tested against the name index precisely so it can be reported as
  "write this as an id". Three failure modes, all verified against injected data
  (bad id, a name where an id belongs, a bad `entryIcon` image key), all three
  named correctly, exit 1. **774 refs to 205 distinct entries, 47% of the
  catalog, printed rather than asserted** — editorial reach is not correctness,
  but an unmeasured number is one that quietly goes to zero.
- **The split of who checks what is by ownership.** `find-missing-refs` walks
  references *into the catalog*; the generator's new `assertExam` walks
  everything the generator itself owns — the closed vocabularies, per-format
  payload invariants (empty and all-correct `selectAll` answers, a repeated
  matching *right* column, out-of-range indices), the tier counts against
  `EXAM_AUTHORED_TIER_COUNTS`, every cell against `EXAM_MIN_CELL_COUNT`, and the
  two asset tables (`FLAVOR_ART`, `COUNTRY_SHAPE_ICONS`) that exist nowhere else.
  ASCII on every shipped string, on `assertFirmware`'s precedent: the question
  card is Press Start 2P over VT323 and a pasted accented place name renders as a
  blank box.
- **The missing outline art is a real art job, and the gate is the deliverable.**
  Verified: `countryShapeIcons` has 28 keys against 34 flag gradients, and three
  live regions fall through — R117 Serra Gaúcha, R118 Campanha Gaúcha (Brazil)
  and R098 Valle de Guadalupe (Mexico). The brief's diagnosis was right about
  `CountryOutlineMap.swift:29` (its `if let` has **no `else`** — the country page
  draws nothing) and slightly off about `EntryVisual.swift:186`, which has a
  `?? db.icons.climateIcon(...)` fallback and degrades to a climate glyph rather
  than to nothing. **Drawing them was declined**: the 28 existing outlines are
  hand-drawn pixel art in `art/icons/countries/` at sizes from 50x185 to 232x140,
  and a silhouette synthesised by a script would be visibly not of that set. So
  **two gates instead**, in both places that can hold one: the generator's
  `assertOutlineCoverage` hard-fails on any place with regions and no outline
  unless it is named in `OUTLINE_BACKLOG` (and *also* fails if a backlog entry
  stops being missing, so the list cannot rot into an excuse), and
  `CoverageTests.regionsHaveOutlineArt` pins the set as **exactly** `["Brazil",
  "Mexico"]` — failing in both directions, the pleasant one being "somebody drew
  it, delete this line". This is the third silent-missing-asset bug in three
  batches, after `icon: "fruit"` (0.7.4) and the two logo layers (0.7.5, A5), and
  it is the first of the three to leave a gate behind.
- **The two pre-existing TS errors were `noUncheckedIndexedAccess` and are fixed
  at the cause.** `FIRMWARE_RELEASES[i - 1]` was read twice under an `i > 0`
  guard, which does not narrow an index expression. Bound once into a local,
  behaviour identical. `npx tsc -p tsconfig.json` is clean for the first time in
  the repo's history.
- **`exam.json` is the eighth generated file and it carries its own
  vocabularies.** Labels, tier order and `minCellCount` ship *with* the bank
  rather than being restated as Swift literals, on the same reasoning F3 used for
  the firmware version travelling with its changelog: a literal here would
  silently disagree with the bank the first time somebody added questions.
  `ExamCatalog` decodes element-wise like `WineDatabase`, so a malformed question
  costs one question — which makes it silent by construction, which is why
  `DiagnosticsReport` now prints the bank's count and its decode errors.
- The FIRMWARE headline moved from THE SHOP to **THE WINE EXAM**. The headline
  names the release on the panel, and a release whose largest item is a
  407-question exam was describing its second-largest feature.

**Parked from 0.7.5 (D):**

- **Brazil and Mexico still have no outline art**, and four more countries (UK,
  Slovenia, Bulgaria, Lebanon) have flag gradients and no outline — *latent*,
  because no region names them, so the new gate correctly says nothing about
  them. Both gates are set to fail the moment either changes. This is the art
  backlog's item, not a data one.
- **Not deployed** — stopped at the clean build by instruction, and this is the
  section with the most that only glass can settle. Worth an eye, in order: the
  **matching** card at four pairs (the right column is a hand-rolled flow layout,
  `DexFlowRow`, and "Grapes dried after picking" beside "Chardonnay" is the case
  it was written for); the **ordering** card at seven items, which is the longest
  authored and the one most likely to need scrolling mid-answer; the three
  **aroma glyphs** at 62pt on a real display; the **country outlines** at 128pt,
  which have never been drawn at that size before; and the reveal card when a
  question carries three entry tiles *and* a long explanation.
- **`selectAll` has no "how many" hint**, deliberately — the count is part of the
  question. Worth watching whether that reads as under-specified on device.
- **The `entryIcon` image kind is implemented and unexercised.** All 11
  `imageIdentification` questions authored are `countryOutline`; the `entryIcon`
  arm is covered by the refs gate's negative test but by no live data.
- **No new passport badge.** D6 asks for achievement unlocks and the exam already
  has one — SOMMELIER, which `Passport.compute` earns from
  `QuizProgress.highestUnlocked` and which now means the authored top paper. A
  seventh badge (full marks, say) is cheap — `Passport.Badge` plus a
  `BackPlateStamp`, 1:1 and pinned by `StampCatalogTests` — but `PassportProgress.seed`
  runs **once ever**, so a badge shipped to existing users fires one popup for
  something they already qualified for. Worth doing deliberately in its own
  sitting rather than as the tail of this one.

**0.7.5, Interactive Grape Lineage** (v0.7.5 spec, section E; `sommbot` ran D in
parallel and owns `shared/data/exam.ts`).

- **The tree is not offered on 103 of the 171 grapes, and that is the design
  rather than a gap in it.** Coverage is 40% and will stay short of 100% —
  Zinfandel's parents are genuinely unresolved and Rkatsiteli's marker line names
  a reconstructed genotype rather than a variety. The three options were an
  always-present section that opens an empty tree (three grapes in five, and the
  fastest way to teach somebody a button does nothing), a greyed NO LINEAGE DATA
  row (a paywall-shaped reminder of an absence on every second grape), and
  drawing nothing. `EntryDetailScreen.lineageSection` draws nothing, gated on
  `WineDatabase.lineage.hasLineage`, and the SHOP listing is where the feature is
  discoverable independently of which grape you happen to have open. The button
  that *is* drawn carries its own counts — "2 PARENTS · 6 OFFSPRING · 3
  MUTATIONS" — so a thin tree is honest about being thin before you open it.
- **Off-catalog ancestors are terminal, not broken.** Gouais Blanc is the mother
  of ten grapes here and will never be an entry; half the pedigree would go with
  it if named ancestors were dropped. `LineageTile` draws them on the *well* with
  a dashed border and no art — a different kind of thing, plainly not a door —
  rather than through `LinkedRow`'s greyed-out treatment, which in this app means
  "a cross-link that failed to resolve" and would say the data is broken. They
  still do one job in the graph: they are **sibling keys**, which is the only
  reason Chardonnay and Riesling know they are half-siblings at all.
- **Contested edges are drawn as contested from both ends.** The reverse pass
  carries `contested` through, so Palomino's offspring row for Listán Negro says
  what Listán Negro's parents row says — without that, the app declines to assert
  a direction from one side and quietly asserts it from the other. A dashed
  connector and a `?` badge mark it; the authored sentence lands in an ON THE
  RECORD footnote block, de-duplicated by the index. A question mark rather than
  a warning triangle: nothing here is wrong, two sources disagree.
- **`related` is reversed even though nothing in today's data reverses.** Both
  authored `related` refs are Sangiovese's and both are off-catalog. It is built
  anyway because "first-degree relative of undetermined direction" is symmetric
  by definition, and the day one names a catalog grape, that grape's tree would
  otherwise be missing an edge its partner draws. Exercised by a fixture
  (`relatedIsSymmetric`) rather than left as untested scaffolding.
- **The tree is a column, not a canvas.** The LCD is about 2.5 inches wide;
  pan-and-zoom on it would be a worse list. What a graph gives that a list cannot
  is *direction*, so ancestors sit above the subject with rails running down into
  it, descendants below with rails running out, and everything sideways is a
  labelled section underneath. Half-siblings are **grouped by the relative they
  came through** — Chardonnay's eleven are nine Gouais Blanc children and two
  Pinot Noir ones, and a flat list of eleven names says none of that. The rails
  are a single `Canvas` path in `lcd.accent`, so they come out as ink in VINTAGE
  and as phosphor in the four single-colour modes.
- **A new `Entitlement.lineage`, not a fold into `.pro`.** The shop can only sell
  what the entitlement set can name, and this behaves exactly as `.workshop`
  does: it gates a door, `covers(_:)` answers `false` because it is not a slice of
  the catalog, and `.pro` supersedes it. It sells through B2's
  `PurchaseProviding` / `AccessStore.purchase` like everything else — no second
  store — and continues to the tree on success (0.7.3's C1), which is the first
  time `EntryDetailScreen` has raised an `UpgradePrompt` of its own; every *entry*
  paywall is still handled a level up in `RootView.open(_:)`.
- **`bodyFromText` had `levelFromText`'s exact defect and it cost a rendered
  value.** `t.includes('full')` sat above the `medium-full` branch and every test
  in the function is a substring test, so `'Medium-Full'.includes('full')` was
  true and that branch had never once executed: **16 grapes authored
  `"Medium-Full"` drew the same 5/5 bar as the 34 authored `"Full"`**. Chardonnay
  and Merlot read as full-bodied as Cabernet Sauvignon. They are 4/5 now, on iOS
  and on web, which read the same `GRAPE_CARDS`. `light-medium` was dead the same
  way and is corrected for the function's sake only — those 22 grapes round to 3
  either way, because `Math.round(2.5) === 3` is what `medium` already returned.
  Nothing caught this because Cabernet Sauvignon is the only grape whose
  characteristics are pinned anywhere and it is genuinely `"Full"`;
  `CoverageTests.bodyBarsAreDistinct` now pins the whole distribution, because
  what broke was a *branch* and a branch is only observable across the set.
- **The lineage gate is the only arm of `find-missing-refs.mjs` that does not go
  through the name index**, deliberately: in-catalog links are ids, so a typo'd id
  is a hard failure and a *name* is never checked against the grape list — a hit
  would mean the ref was mis-authored, not resolved. Four failure modes are
  caught (bad id, both keys, neither key, and a name matching a catalog grape's
  primary name), all four verified against injected data. The off-catalog count
  is **printed rather than asserted**: 47 refs to 36 distinct ancestors is
  backlog, not breakage, and silence there would read as "none", which is the
  exact failure the dead COUNTRY_GATE arm taught in 0.7.4.

**Parked from 0.7.5 (E):**

- **`grapeBodyClass` still disagrees with the body bar on some grapes, and it is
  a different derivation.** `getGrapeBodyClass` in `constants.ts` reads
  `legacy.wineType` *first* — so Chardonnay, whose style label is "Full-Body
  White" and whose authored body is `"Medium-Full"`, resolves to the class `Full`
  while its bar now reads 4/5. The function's own ordering is correct (it tests
  `medium full` before `full`); what is arguable is that a *style label* outranks
  an authored body at all. Out of scope here — only `bodyFromText` was approved —
  and worth a ruling of its own, because fixing it moves the body **chip** on an
  unmeasured number of grapes.
- **`Mammolo` is both an authored off-catalog ancestor of Verdicchio and a
  synonym of G168 Sciaccarellu.** VIVC folds Sciaccarellu and Mammolo into one
  record; whether Verdicchio's parent is that entry is a factual question for
  `data-review/FINDINGS.md`. The gate prints it as an authored, non-fault
  collision rather than ruling on it, and the index does **not** resolve it —
  in-catalog links are ids, and a name that resolves through synonyms is exactly
  the wiring the id rule exists to prevent.
- **Not deployed** — stopped at the clean build by instruction. Worth an eye: the
  fan connectors at their widest (Pinot Noir, nine descendants, which wrap), the
  dashed external tiles against the well in the light modes, and the `?` badge at
  its 13pt size on a real display.

**0.7.5, The Shop** (v0.7.5 spec, sections A and B; C, D and E are separate and
were deliberately not speculated about).

- **B supersedes 0.7.3c's placement, and the reason 0.7.3c gave was never about
  the packs.** That batch put the shelf behind a door inside CUSTOMIZE because
  the settings grid is a fixed three-by-two sized to fill the LCD, so a seventh
  tile would have been an orphan on a fourth row — a constraint about the *grid*,
  which the packs then paid for. B1 dissolves it without touching the grid at
  all: packs are paid content and ACCESS was already the paid-content tile, so
  the shelf moves into a tile that exists. `SettingsSection.packs` retires with
  the door — it was minted only to buy a marquee title, a glyph, Back behaviour
  and `ChromeTests` coverage, all of which SHOP now provides — which takes the
  route count 32 → 31 and the marquee's chip row back to four, the number its own
  comment has claimed since 0.7.1 and which stopped being true when PACKS landed.
  CUSTOMIZE is a scrolling column of sections, so losing one shortens it and
  moves nothing.
- **"Bundles" was already gone, and the word that had to move was ACCESS.**
  B1 asks the packs to replace BUNDLES in the access area; 0.7.3c had already
  renamed that heading to EXPANSION PACKS, so the check was worth doing and the
  answer was "nothing to rename". ACCESS was the real one, and it is
  **persisted** — `QuickPinStore` writes `SettingsSection` raw values into
  `marqueeQuickPins` and its decoder silently drops what it does not recognise,
  so a rename unpins rather than failing. `displayName` per the house rule; the
  doc comment claiming "no `SettingsSection` is persisted anywhere" has been
  wrong since 0.7.2 (A7) and is corrected.
- **The shop's Decision #2 was not in the spec, so nothing was invented for it.**
  What was built is the shape F1 already argued for, one layer up:
  `PurchaseProviding` / `LocalPurchaseProvider` beside `EntitlementStoring` /
  `LocalEntitlementStore`, injected through `AccessStore(defaults:store:purchases:)`
  exactly as the store is. It is `async` because `Product.purchase()` is, and a
  synchronous seam would be unimplementable by the one adapter it exists for.
  The local provider grants immediately, which is precisely what the three
  `UpgradePrompt` call sites did inline before — **no StoreKit, no payment
  path, and no empty shell of one**. What an adapter must fill in is written out
  on `LocalPurchaseProvider`: a product-id table (`Entitlement.id` is *storage*
  and pinned by tests, so it cannot double as one), twenty-one products, a
  `Transaction.updates` listener that must land through `AccessStore` or the
  observable mirror goes stale, restore, and verification.
- **No RESTORE PURCHASES button.** `LocalPurchaseProvider.restore()` returns
  nothing, so the button would report success and change nothing — the exact
  fault `CheatCodes`' own note forbids. It arrives with the adapter.
- **B3 finished the grid consolidation for every surface but the two that carry
  art.** 0.7.3c took four bespoke grids to three plus `DexPickerTile` and said
  the rest was a sitting of its own. The shop's toggle rows are now cartridges,
  and `PackCartridge` takes a glyph rather than an `ExpansionPack` so one
  cartridge serves packs and plain upgrades alike. **`skinGrid` and `modeGrid`
  remain hand-written** — 50pt tiles carrying real art (a fake device, a fake
  LCD running the monochrome pass), which is not the same problem and was not
  this batch's ask.
- **The old ACCESS harness was a developer test rig, and B replaced it rather
  than dressing it up.** What is lost is revoking *one* entitlement without the
  rest; FREE TIER plus REVOKE ALL still reaches every combination, one more tap
  at a time.
- **A1's clearance is the footer's, not the island's, and that was worth
  checking.** The lamps that nearly touched the Dynamic Island are
  `islandStatusDot` and are untouched at 22.1pt (SMALL) / 15.2pt (LARGE). The
  marquee pills share a column with the panel that sums to `bandHeight` exactly,
  so 20 → 24 is 4pt straight out of `marqueeHeight` (109 → 105 SMALL, 127 → 123
  LARGE, floor 60/69) and nothing else in the chassis moves — the same trade
  0.7.2's A9 made, made again with the sum re-derived rather than assumed.
- **A2 does not go through `RecessedLamp`, and the spec's hunch was worth
  testing.** That modifier is generic over `InsettableShape`, but it draws parts
  *recessed* into the deck and the orb is the one part that stands **proud** —
  its own note says so. Routing the orb through it to get a rounded rectangle
  would invert the lighting on the only part meant to catch light. The shape is
  parameterised in `lcdOrb` instead. `islandTopInset`'s corner-arc note claimed
  the controls survive the 26pt cut "because they are circles"; re-derived, that
  is true of the trio and never was what saved the orb, whose box starts 68pt in.
- **A5 does not go through `IconLoader` either, and 0.7.4's parked finding is
  why.** `IconLoader` resolves Iconify slugs, and `rasterize-icons.sh` *deletes*
  any PNG in `Resources/Icons` absent from the generated manifest — an asset
  parked there survives until the next `npm run icons`. The mark ships in
  `Resources/Logo`, beside the wordmark, loaded the way `LogoMark` already loads.
  It is split on luminance into a face and a shade mask by
  `scripts/import-logo-art.py` and tinted in code, because the LCD's ink is the
  user's choice and the master's white-and-grey would be two fixed colours on a
  screen with twenty-one colourways. **The folder the master sits in is not a
  name this project uses**: no type, comment, shipped string or shipped file
  repeats it, which is the line 0.7.3a drew and this keeps.
- **`LogoLayerTests` is the gate 0.7.4 could only write down.** It reads the two
  PNGs off disk through `#filePath` — `VinodexUI` has no test target and linking
  it would make the test uncompilable on the host, which is the whole reason no
  such gate existed — and checks the PNG signature, the IHDR dimensions, that the
  two layers register, and that the mark is landscape. **Scoped to these two
  files on purpose**: auditing all 207 rasterised icons and the five drawn-art
  directories belongs in the generator or `verify-art.py`, next to the tables it
  would check, and is still open.
- **A6 moved no timing.** `BootSequence.duration` is still 1.9s and
  `BootSequenceTests.brief` is untouched: A6 is entirely type sizes, and a POST
  that filled the screen by running longer would be a worse POST. Both of 0.7.3a's
  rules survive — inside the LCD, skippable on a tap. The sizes are bounded by two
  faces with very different metrics (`VT323` advances ~0.4em, `PressStart2P` a
  full em), which is why the lines went 16 → 28 and the header only 11 → 15, and
  why all three gained a `lineLimit(1)` they did not need at the old sizes.
- **A3's gate is derived, not listed.** `lcd.monochromeTint != nil`, the same
  predicate `honorsFontInk` uses, so a fifth single-phosphor mode is covered the
  day it is added and a colour mode cannot opt in. The flash draws white *inside*
  the existing `grayscale`/`colorMultiply` pass, so it comes out in the mode's
  own phosphor. It keys off the chassis's marquee `title` — one string that
  changes on every navigation and is already threaded there — and Reduce Motion
  removes it outright, on the screensaver's reading rather than the POST's: the
  POST keeps its content because the content is information, and this has none.
- **A4 was checked before it was done.** `"PET NAT"` is the `chassisSkin`
  `@AppStorage` value, the FNV-1a seed for the back plate's procedural wear
  (`WornOverlay.seed`), and the stem `stickerStem` derives — all three of
  HALLOWINE's reasons, present on this skin too. Label only. The `petnat` hits in
  `icons.json` and `art/icons/styles/` are the wine style Pétillant Naturel and
  are unrelated.
- **A data batch that is not this one was sitting in the master `shared/`, and
  it was separated rather than absorbed.** `npm run generate` after the version
  bump moved `entries.json` as well as `firmware.json`: four grapes (G159
  Colorino, G162 Espadeiro, G166 Nerello Cappuccio, G169 St. Laurent) carrying
  identity rulings that postdate the 0.7.4 commit — descriptions, one synonym,
  one `keyRegions` entry. `vinodex-ios/shared/data/grapes.ts` was reverted to
  HEAD and regenerated, so this commit carries only `firmware.ts`. **Nothing is
  lost**: `HGapps\shared` is the master and still holds the work for whichever
  batch lands it. This is 0.7.4's own lesson applied on the first run rather than
  hunk by hunk afterwards.

**Parked from 0.7.5:**

- **Not deployed** — stopped at the clean build by instruction. Worth an eye:
  the refresh flash on VINTAGE/AMBER/TERMINAL/GRÜNERBOY (subtle by design, and
  the one item here that is a judgement call about *how much*), the squared orb
  against the shell it sits on, the POST at its new size on a real display, and
  the splash's fanned cartridge trio.
- **`skinGrid` and `modeGrid` are the last two hand-written pickers.** See above;
  they carry real art and are a sitting of their own, still.
- **The general icon-asset gate is still open.** `LogoLayerTests` covers two
  files. The 207 in `Resources/Icons` and the five drawn-art directories do not
  have one.
- **`vinodex-web` was left where 0.7.4 parked it.** `sync-shared.ps1` writes into
  that repo too, so the version bump landed `shared/data/firmware.ts` there as a
  new untracked file (web has never carried it) on top of the uncommitted
  `batch4-into-testing` tree. Nothing was reconciled and nothing was reverted —
  unwinding that tree would have risked the parked 0.7.4 work — but the release
  pass should know the file is there.
- **`bodyFromText`'s `medium-full` defect is untouched**, as instructed. It did
  not collide with anything here. (**Fixed in section E**, same version — see the
  0.7.5 lineage entry above for the measurement.)

**0.7.4, Grape Overhaul** (`vinodex-0.7.4-grapes.md`). The first batch split
across two agents: `sommbot` authored and landed the data in `shared/`, `dexbot`
took the pins, the two logic fixes and the gates. Findings and identity rulings
are in `data-review/FINDINGS.md`, which is the record for anything factual.

- **Two batches were layered uncommitted in one working tree, and they were
  separated rather than merged.** 0.7.3c was deployed but not yet eyeballed, and
  0.7.4's data sat on top of it in the same four `shared/data/*.ts` files. They
  are separable by content but not by path, so the split was done hunk by hunk —
  sommbot had labelled every line it added with the batch it belonged to, which
  is the only reason this was cheap. 0.7.3c was committed first, at its own
  catalog total of 407, with its `Resources/*.json` regenerated from the reduced
  `shared/` so the commit is internally consistent rather than carrying 0.7.4's
  data under 0.7.3c's pins. A `v0.7.4-wip-snapshot` branch holds the combined
  pre-split tree and can be deleted once both commits are confirmed on glass.
- **`levelFromText`'s default swallowed `"None"`, and 60 grapes paid for it.**
  Every test in that function is a substring test against a lowercased string,
  and `"None"` matched none of them, so all 60 whites carrying
  `details.tannin: "None"` fell through to the default of 3 and drew a
  half-full tannin bar — the one value the bar exists to communicate, rendered
  as the middle of the scale. Now 0. The ordering bugs sommbot flagged
  alongside it (`medium-high` dead below `high`; `Medium-Low`/`Low-Medium`
  falling into `medium`) are corrected in the same pass but **move nothing on
  screen**: both call sites round, and `Math.round(3.5) == 4` and
  `Math.round(2.5) == 3` are what those inputs already produced. Verified
  against the live catalog before and after — 60 tannin values moved, 0 acidity
  values moved, and Cabernet Sauvignon's pinned characteristics are untouched
  because it is a red reading "High".
- **`find-missing-refs.mjs` had a gate that had never once executed.** Its
  country arm read `COUNTRY_GATE` out of `entries.json`, a category the
  generator deliberately drops, so the array was always empty, the validation
  loop never ran, and the summary line reported "0 countries" — an honest
  number that read like a pass. It now parses `shared/data/countries.ts`
  directly and reports 30. Proved live with a negative test (a bogus grape
  injected into the Croatia gate is caught and named) rather than by trusting
  the zero.
- **Sommbot's "no Swift change needed for the six new regions" claim held, and
  was checked rather than assumed.** All six use classification strings
  `EntryDisplay.appellationName` already resolves (DO, DOC, AOC, AVA), all six
  origins are countries the catalog already had, and every soil string hits a
  covered keyword. The Azores deliberately take `DOC` over the formally correct
  EU `DOP` to avoid minting a classification string and a chip-colour probe.
- **One thing the data audit could not have caught: `icon: "fruit"`.** Two of
  the new grapes (G150 Alfrocheiro, G160 Corvinone) use an icon key that was
  present in the generator's `LUCIDE_ICONIFY` table but had never been used by
  any entry, so `lucide:apple` had never been rasterised and those two rows
  would have drawn nothing — `IconLoader.image` returns nil for a missing
  asset, and no test or build gate covers icon assets. The glyph was rasterised
  at all three scales. **`scripts/rasterize-icons.sh` was deliberately not
  used**: it prunes every PNG absent from the manifest it is handed, so a
  one-icon manifest would have deleted the other 200.

**Parked from 0.7.4:**

- **Not deployed** — stopped at the clean build by instruction. Worth an eye:
  the tannin bar on any white grape (should be empty, not half), and the apple
  glyph on Alfrocheiro and Corvinone, which is a real fruit glyph on two reds
  and may read oddly next to the grape glyph everything else uses.
- **`bodyFromText` has the same defect shape as `levelFromText` and was left
  alone on purpose.** `t.includes('full')` is tested first, so the
  `medium-full` branch below it is dead and **16 grapes reading
  `body: "Medium-Full"` render a full 5/5 body bar**, indistinguishable from
  the 34 that are actually `"Full"`. (`Light-Medium` likewise falls into
  `medium`, but rounds to the same 3 it already produced, so it is inert.)
  Unlike the tannin fix this is not a clear correction — 5/5 for "nearly full"
  is arguable — and it changes a rendered value on 16 entries, so it wants a
  decision rather than a quiet fix. Cabernet Sauvignon's pin is `"Full"` and
  would be unaffected either way.
- **`vinodex-web` was brought green rather than parked, because the sync had
  already broken it.** `sync-shared.ps1` writes into that repo too, so the
  moment 0.7.4's data landed its suite went red — leaving it there would have
  been leaving damage, not deferring work. Changes are uncommitted, on
  `batch4-into-testing`, for the release pass to pick up: coverage pins (GRAPES
  146 → 171, REGIONS 116 → 124, total 405 → 438, origins 25 → 26 — two batches
  of drift, since web never re-pinned 0.7.3c's Brazil), the quiz determinism
  goldens for both seeds, and one genuine parity bug below. `npm run typecheck`
  and all 363 tests pass.
- **Running web's suite found a 0.7.3c parity gap that iOS's own gates could
  not see.** `web/src/services/entryDisplay.ts` never got the two cases iOS
  added with the Brazilian regions: `IP` was missing outright, and Brazil's
  `DO` was not split off the Spanish one — so Campanha Gaúcha showed a bare
  abbreviation and **Serra Gaúcha printed its system in Spanish**, which no
  test was ever going to catch because a wrong-language expansion still reads
  like prose. Both mirrored from `EntryDisplay.swift`. The lesson is that
  0.7.3c's Swift-side appellation work needed a web pass and did not get one.
- **`FilterTests.filterPlusSearch` moved, and it is not a regression.** Free
  text search covers `entryDescription`, and R122 South West France is
  described as "the arc of country between Bordeaux and the Pyrenees", so the
  France-filtered search for "bordeaux" now returns two regions. Re-pinned with
  the reason recorded; if the intent is that search should *not* reach
  descriptions, that is a separate and much larger decision.

**0.7.3c, Expansion Packs** (`vinodex-0.7.3c.md`). Last of the three 0.7.3
sub-batches, and the one that fills in `Entitlement.expansion` — the case 0.7.3a
minted and left covering nothing.

> **Superseded in part by 0.7.5 (B).** The packs no longer live behind a door
> inside CUSTOMIZE and `SettingsSection.packs` no longer exists — the shelves are
> the shop's own body, IAP-backed. Everything below about *what a pack is* stands
> unchanged: they still collect rather than gate, ownership is still the union
> through `impliedBy`, the catalog is still Swift, and Brazil is still Brazil.
> What changed is where the shelf is and what the tile beside it is called. See
> the 0.7.5 entry above for why the grid constraint that put it in CUSTOMIZE
> stopped applying.

- **The decision: packs collect and organise, they do not gate — and the reason
  is the passport, not caution.** The spec left it open and named collect/organise
  as the lower-risk default. It is also the only one the code permits. `PassportTier`
  is absolute counts of *tried* entries and its own doc comment states the
  invariant — "a rank you had already earned must not be taken back by a data
  batch" — while `Passport.compute` resolves the tried shelf against the whole
  database and never consults `AccessStore`. A pack that withdrew twenty
  countries' entries until bought would drop the tried count, demote a rank
  already held, empty ALL NOBLE and REGION COMPLETE, and move every denominator
  on the screen. On a shipped app that is a regression, and it decided the item.
- **What was *not* true is that gating was ever the risky half.** Reconnaissance
  found a whole content-paywall already in the tree — `tiers.json`, `db.isFree`,
  `AccessStore.isLocked`, `Entitlement.covers` — behind `starterOnly`, which is a
  *developer* switch, off on every install. So `Entitlement.covers` now reads pack
  membership, because the honest `false` had stopped being honest, and doing so
  can only ever add a key: under `starterOnly` those entries were already locked
  (they are not in the free list), and with it off nothing is locked at all. Two
  tests pin exactly that (`packsLockNothing`, `grantingOnlyUnlocks`).
- **The device and display cartridges must not re-gate what they group.** Every
  non-default skin has required `.skins` since long before packs; giving each
  collection its own entitlement would mean a user who owns the skins bundle no
  longer owns BURGUNDY. `ChassisSkin.requiredEntitlement` is therefore untouched
  and `ExpansionPack.impliedBy` names the old bundle, so owning `.skins` owns all
  six device cartridges the moment this build lands. Ownership is the union,
  never the intersection.
- **The pack catalog is Swift, not `shared/`** — the one list in the app that
  names catalog content from Swift. A pack id is persisted inside
  `Entitlement.expansion` the moment somebody owns it, so it is storage, and
  `shared/` is edited by data batches and by the `sommbot` agent. The membership
  *rules* still point at `shared/`, and `ExpansionPackTests.atlasCountriesResolve`
  is the gate `find-missing-refs.mjs` cannot be — it audits generated data against
  itself and knows nothing about a country list in a `.swift` file.
- **Brazil, because B2 named a country that was not there.** C029 plus Serra
  Gaúcha and Campanha, both in Rio Grande do Sul, added *before* the pack
  referenced them. No new grapes — all six notable grapes across the two regions
  were already in the catalog, which is the house rule for a new country. New
  `IP` appellation expansion, and `("DO", "brazil")` split off the Spanish `DO`
  the way `DOC` was already split three ways. Brazil got a chip colour rather
  than the grey fallback, and its pixel flag had been sitting unused in
  `shared/pixelflags` since the flag drop.
- **C and D disagree with the spec's spellings, and the code won.** C1 asks for
  "Transparent", "Retro Tech" and "Seasonal"; the sections have been CLEARTECH,
  RETROFIT and FESTIVE since 0.7.0 and those words are already on screen above
  the skins they group. D1 asks for "Vintage"; 0.7.1's C1 renamed that section to
  RETRO precisely because a group called VINTAGE containing a mode called VINTAGE
  read as a mislabelled tile. Taking either literally would have put two names on
  one grouping.
- **A2 was answered by promoting a component rather than writing a fifth.**
  0.7.3b's notes flagged that the workshop's chooser duplicates the settings
  picker; A2 asks the shelf to reuse that picker's style, which taken at face
  value means a fifth hand-written grid. The workshop's `partChip` — already the
  one generalised version, serving all eight axes — became `DexPickerTile`, and
  the shelf and the workshop both use it. `skinGrid` and `modeGrid` were left
  alone deliberately: they are 50pt tiles carrying real art, in a module no Linux
  gate compiles, and rewriting the two pickers a user actually looks at was not
  this batch's ask. Four bespoke grids became three plus one shared tile.
- **No cheat code, on purpose.** `CheatCodes`' own note forbids a code that
  reports success and changes nothing, and that is exactly what a pack-granting
  code would do: with `starterOnly` off, every pack already reads as owned.

**0.7.3b, the Device Workshop** (`vinodex-0.7.3b.md`). Second of the three
0.7.3 sub-batches, built on 0.7.3a rather than beside it — C1 gates on F1's
`EntitlementStoring`, `AccessStore(defaults:store:)` and `Entitlement.workshop`,
all of which are 0.7.3a's.

- **The prerequisite check failed, and that was most of the batch.** The spec
  assumes the 0.6.x/0.7.1 chassis work left seven parts individually settable.
  It did not: the device had **two** axes — `chassisSkin` and `lcdMode` — and
  every other part was a *property of the shell*. `ChassisSkin.orb`, `.accent`,
  `.control`, `.grill`, `.marqueeText` are all switches over the skin, so
  choosing BURGUNDY chose a purple orb, purple caps and a pink marquee together;
  a skin was a dye lot, not a palette. The grille had no shape axis in any form
  (four hardcoded 64×2 capsules in `bottomVents`, identical on all twenty-one
  shells), and the font colour was whatever `LcdMode.text` said. Five of the
  seven parts, plus the grille's shape, had to be *built* before a workshop over
  them could exist.
- **`DeviceAxis` is the foundation, and empty means stock.** Eight axes (the
  grille takes two — colour and pattern), one `UserDefaults` key each, and one
  invariant that makes it safe to add to a shipped app: `""` and "no stored
  value" are the same state, so a device nobody has customised is byte-identical
  to 0.7.2's. `chassisSkin` and `lcdMode` keep their spellings — those hold real
  choices on real installs — and `ChassisSkin.storageKey`/`LcdMode.storageKey`
  now *read from* `DeviceAxis` rather than restating the literal.
- **`ChassisLook` is one resolver, not six fallbacks per call site.** The wrong
  way to add overridable parts was `partOrb.map(\.orb) ?? skin.orb` at each of
  twenty call sites — F1's copy-pasted cosmetic rule with six times the surface.
  `ChassisLook` carries the same member names `ChassisSkin` does, so three views
  changed one line each: the *type* of their `skin` property. Every `skin.orb`
  still reads `skin.orb`, and the compiler found the call sites rather than a
  search doing it.
- **One authored hex per palette entry, everything else derived.** Thirteen
  colours across five axes is sixty-five hand-written ramps otherwise — sixty-five
  chances for one stop to come from the wrong colourway, which is the fault
  `ChassisAccent`'s own note calls a manufacturing defect. `PartColor` derives
  the six-stop lit ramp, the moulded cap, the orb bead and halo and the marquee's
  three phosphors through `DexRGB.mixed(with:amount:)`, calibrated against
  CLASSIC's hand-authored parts. `DexRGB` gained `hex` for the round trip.
- **The live preview is the device.** B1 asks for a live preview and the
  workshop runs *inside the LCD of the thing being customised*, so the rows write
  the keys the chassis already reads and fitting a violet orb turns the real orb
  violet under your thumb. Nothing is threaded between the two surfaces because
  there is nothing to thread. The cost is that editing is destructive, which
  REVERT (drawn in a fixed red, not an LCD token) answers.
- **No second source of truth for what the device looks like.** A `CustomDevice`
  is a *recipe*; applying one writes the same eight keys. There is deliberately
  no stored "active build id" — `CustomDeviceStore.matching(_:)` compares, so a
  build that has had one part changed since it was fitted stops matching, which
  is the truth. That was the specific trap the spec named and F1 had just spent a
  batch clearing one layer down.
- **The font axis is the only one with a rule.** Every other part is decoration;
  the font is what the screen says things with, and IVORY on the paper-white LCD
  is a device that has stopped working — recoverable only through text you can no
  longer read. `LcdMode.accepts(_:)` refuses an ink the mode cannot show (the
  four single-phosphor modes) or that will not read on its ground, and falls back
  to the mode's own. Enforced at the point of use rather than in the picker,
  because the failure can arrive *later*: pick an ink on a dark screen, then
  switch to a pale one.
- **C1 is an entitlement flag, not a paywall.** The CUSTOMIZE section is always
  visible; unowned, it describes the workshop and its button says UNLOCK, which
  raises the ordinary `UpgradePrompt`, grants through the one store, and then
  *continues into the builder* rather than stopping at "unlocked!". The six new
  axes ride `.workshop`; the two old ones keep `.skins` and `.lightMode`, so the
  workshop cannot be used to buy twenty-one shells for the price of one bundle.
  GARAGISTE is the cheat code — a real wine word for somebody building the thing
  themselves in a workshop.
- **A 0.7.3a gap closed on the way past:** `ChromeTests.allRoutes` never listed
  `.firmwareHistory` or `.cheatConsole`, so for one sub-batch the marquee-glyph
  uniqueness gate could not see them. All three 0.7.3 routes are listed now.

**0.7.3a, the Foundation batch** (`vinodex-0.7.3a.md`). First of three 0.7.3
sub-batches. Section 0 (F1–F3) is the deliverable; 0.7.3b and 0.7.3c are built
on it, so it was written to be depended on rather than shaped around what
A1–A5 happened to need.

- **F1 — one entitlement store.** The honest finding on reconnaissance was that
  most of the unifying had already happened: `AccessStore` has always been the
  only entitlement set, and there was no parallel store to fold in. What *had*
  forked was the cosmetic *rule*, copy-pasted into four view bodies as
  `option != .classic && !access.isUnlocked(.skins)` and its screen-mode twin —
  four places encoding which option is free, none reachable from a test, in a
  module Linux cannot compile. Persistence moved out into
  `LocalEntitlementStore` behind `EntitlementStoring` (same key, same encoding —
  a "cleaner" key would silently revoke every grant on real installs), and the
  cosmetic rule moved onto the options themselves via `CosmeticOption`.
  `Entitlement` gained `.expansion`, `.workshop` and `.easterEgg` for the two
  sub-batches to come.
- **F2 — one idle timer, folding in the marquee's.** The marquee kept its own
  clock (a `Task.sleep` on the chassis) and it was reset by exactly one thing in
  the entire app: tapping the marquee. Tapping a menu tile or scrolling a list
  counted as idleness. Survivable for a panel that changes a word; not
  survivable for a screensaver, which would have covered the screen of somebody
  actively reading. `IdleClock`/`IdleSchedule` in Core now hold the policy and
  the two thresholds together (10s toast, 15s screensaver), and `MarqueeStage`
  reads the 10 from `IdleSchedule` rather than restating it. Only the WELCOME!
  *beat* is still the banner's own sleep — it is a dwell, not inactivity, and
  `awaitsIdleTimer` is how the stage says which clock owns it.
- **The activity sink is a window `UIGestureRecognizer`, not a SwiftUI
  gesture.** 0.6.9's A1 removed the app-wide LCD `simultaneousGesture` for good
  reason, and adding one back would have put the stamp drag, the globe pan and
  the quiz taps back into negotiation. `IdleTouchWatcher` fails itself in
  `touchesBegan` with `cancelsTouchesInView = false`, so it never enters
  arbitration — a tap on the shoulder, not a gate. **`DeviceBackPlate.swift` is
  untouched by this batch.**
- **F3 — the version moved into `shared/`.** `AppVersion.fallback` was a Swift
  literal with forty lines of release notes above it. The number and a
  user-facing changelog now live in `shared/data/firmware.ts`, generate into
  `firmware.json`, and arrive through `FirmwareCatalog`; `fallback` reads it.
  **`AppVersion` is not a second source of truth** — it kept the half that was
  always its own, the resolution rule (a genuinely declared bundle version wins,
  xtool's stamped `1.0.0` wins nothing), and stopped restating the number. The
  long "why does this build carry this number" notes stay in `AppVersion.swift`
  as the engineering record; the changelog is what the device says about itself.
  The generator gates ordering, three-component shape, ASCII and headline
  length, and that gate was verified to fail on a deliberately mis-ordered list.
- **A1–A5.** Boot POST inside the LCD (a BIOS is something a screen does; over
  the chassis it reads as power loss), under two seconds and pinned there by a
  test. Demo mode assigns `path` directly rather than pushing — twelve stops per
  cycle would otherwise grow a stack and chirp the page sound at a device nobody
  is holding. Firmware history and the cheat console are two new System-panel
  rows under one DEVICE heading rather than three new headings. The screensaver
  bounces a `VinodexV` drawn from scratch — **no DVD trademark, asset or naming
  anywhere**, and position is a closed form in Core (`ScreensaverBounce`) so it
  cannot drift out of its box the way a per-frame simulation would.
- **Cheat codes grant real entitlements.** CELLARDOOR, PHOSPHOR, GRANDCRU and
  MAINFRAME, all four wired to something visible today — MAINFRAME's
  `verboseBoot` egg adds POST lines. A code that reports success and changes
  nothing is the one failure a cheat console cannot survive.

**Parked from 0.7.3c:**

- **Not deployed** — stopped at the clean build by instruction. Nothing in it is
  verified on glass. First things to look at: the cartridge silhouette at 46pt
  (the stepped shoulder is what makes it read as a cartridge rather than a badge,
  and it is the detail most likely to disappear at that size), the shelf under
  the four single-phosphor modes and the Retro group, and the workshop's eight
  part chips, which now render through `DexPickerTile` and should be pixel-identical
  to 0.7.3b.
- **The Brazil prose and its two regions are conservative but unaudited.** The
  claims worth a `sommbot` pass: "third-largest wine producer in South America",
  "around nine tenths of the crop in Rio Grande do Sul", the 1875 immigration date,
  and Serra Gaúcha classified `maritime` — it is humid subtropical, and `maritime`
  is the least wrong of the five classes rather than the right one. Vale dos
  Vinhedos is folded into Serra Gaúcha's `appellations` per the house rule rather
  than minted as its own region.
- **`find-missing-refs.mjs`'s country-gate arm is dead code**, and this batch is
  how it was noticed. It reads `COUNTRY_GATE` out of `entries.json`, which the
  generator deliberately never writes there, so `countries.length` prints 0 and
  the loop validating a gate's `keyRegions` and `notableGrapes` has never run.
  Brazil's were checked by hand. Cheap fix: read `countries.ts` directly.
- **The pack shelf has no route of its own**, so it cannot be linked to from
  anywhere but the settings grid. If packs ever want a tile on TOOLS or a marquee
  pin of their own, `SettingsSection.packs` is already pinnable via `QuickPinStore`
  — the wider element type parked from 0.7.1 is the thing that is missing.
- `ExpansionPack.symbol` is not policed by `ChromeTests.glyphsAreDistinct`; two
  cartridges wearing the same glyph would be a cosmetic smudge nobody catches.

**Parked from 0.7.3a and 0.7.3b:**

- 0.7.3a **was deployed and eyeballed**: the POST pacing, the demo dwells, the
  V's size, speed and colour cycle under the monochrome modes all pass, and so
  does 0.7.2's stamp drag including the top-left-corner falsifier. Both of the
  entries that stood here are closed.
- **0.7.3b was deployed and eyeballed** at the head of 0.7.3c: the derived colour
  ramps against the authored ones, the five grille patterns at real size, the
  schematic panel and the FONT row under monochrome all pass. Committed then.
- **The palette's derivation constants are authored by eye.** The mix amounts in
  `PartColor` (0.80/0.56 pale, 0.20/0.52 dark, 0.84 for the marquee's letters)
  are calibrated against CLASSIC's ramps by arithmetic, not by looking at them on
  a phone. Retuning one is one line and repaints all thirteen colours coherently,
  which is the whole point of deriving them.
- **`PartColor` and the font-readability rule are `VinodexUI`**, so neither is
  reachable from a Linux test — the thresholds in
  `PartColor.readsAsInk(onLightGround:)` are argued in a doc comment and gated by
  nothing. Moving the palette's *hex table* to Core would make the rule testable
  and is the obvious next tidy if the font axis grows.
- The demo loop's dwells and stop order are authored by eye, like the map
  coordinates. Worth tuning once seen running.
- ~~`.expansion` covers no entries yet~~ — closed by 0.7.3c, which gave it a pack
  catalog to read.
- `testing`, `v0.7.2-batch` and now `v0.7.3-batch` are all unpushed; `main` vs
  `origin/main` is still diverged and still not reconciled.

**0.7.2, the consolidation batch** (`vinodex-0.7.2-consolidation.md`). Shares
0.7.2 with the label reader rather than taking 0.7.3, because nothing had
shipped under the number — LABEL SCAN was still uncommitted when this spec
arrived, so the two land as one release instead of a tag superseded the same
day.

- **Section 0 was git.** `testing` now contains every batch branch. Most of the
  0.6.x chain already was an ancestor; the only genuinely dangling branch was
  `v0.6.4-batch` (also local `main`, tagged `v0.6.4.0`), whose three files —
  `DeviceChassis`, `DexTheme`, `RetroGlobeScreen` — are precisely the three that
  0.6.5 through 0.7.1 rewrote. All three conflicts resolved to `testing`, and
  the merge leaves its tree byte-identical: 0.6.4's globe fix is already in the
  tree under a later name (`colorized` for `tinted`, carrying the same finding
  about `SCNMaterial.multiply`), and its island lamps predate the bezel the
  lamps now live on.
- **A2, and why two batches missed it.** The stamp drag never fired because no
  touch reached it. 0.7.0's E2 moved `.frame`/`.offset` up the chain and left
  `.contentShape(Rectangle())` outside the offset; `.offset` does not change
  layout, so the contentShape — which *replaces* a subtree's hit region rather
  than describing it — pinned all six stamps to one box in the plate's top-left
  corner. Taps were dead as well, which nobody noticed because the drag was
  what was being tested. 0.7.1's D3 then shortened the hold threshold, which
  could not have helped. **A threshold change that does nothing is evidence the
  event never arrived.** The gesture is also `highPriorityGesture` now: it sat
  under an `onTapGesture`, and `TapGesture` has no maximum duration, so a
  deliberate press-and-release was a tap.
- **The marquee stopped being a nameplate.** A9 makes the two status lamps the
  TOOLS and CUSTOMIZE buttons (which is why `bandPillHeight` is 20 and why A4's
  bead had to come off — the glyph goes where the highlight was), A7 puts
  pinned sections in its top corners, A6 makes the tap a toggle that re-titles
  the panel PINS, A3 gives MENU a glyph beside the word, and A8 brings the
  0.6.9 language toasts back — now that the script has somewhere for them to
  belong, one per idle period rather than a carousel.
- **A1** gives Africa ochre and Oceania eucalypt green. They were the pink pair
  0.7.1's A3 left behind: both sat at hue 0° with identical G and B, separated
  only by lightness. Closest pair went 40 → 151.

**Parked from 0.7.2 (consolidation):**

- **Not deployed, and could not be.** `xtool dev run` fails at provisioning with
  a 409 from the Apple Developer API — "no current iOS devices on this team
  matching the provided device IDs". The phone's UDID is not registered on the
  signing team; that is an account problem, not a build one. **A2 and the whole
  marquee rework are therefore unverified on glass.** A2's fix is a hit-testing
  correction that no Linux gate can exercise, so it is the first thing to check
  on the next successful install.
- North America `#722F37` and Europe `#9B2335` are now the closest marker pair
  at 42.8 — tighter than the pair A1 just fixed was. Out of scope here because
  the spec named Africa and Oceania, but it is the same defect one notch
  quieter and the obvious A1 follow-up.
- The A4 bead removal is scoped to the two marquee pills. The island trio and
  the vent lamps keep their specular dots, on the reading that A4 named the
  marquee lights. If the dots were meant to go everywhere, it is one default
  on `RecessedLamp.bead`.
- The corner pin buttons are 26pt, under the 44pt target guidance. Deliberate —
  see `DexMetrics.marqueePinButton` — but worth an eye on device.

**0.7.2, the label reader** (`vinodex-label-reader_1.md`, "Feature Build Spec
v7.1"). The first batch since 0.7.0 to add a screen rather than rework one, and
the first feature that takes an input from outside the app.

- **The split is the point.** `LabelReading` / `LabelTextScan` /
  `LabelRecognitionService` are Foundation-only in `VinodexCore` and covered by
  `LabelReaderTests` (38 tests), so normalisation, fuzzy matching, confidence
  scoring and the inference walk are gated by the Linux CI. `OCRService`,
  `VisionOCRProvider`, `CameraCapture` and `CameraPermission` are in
  `VinodexUI`, reachable only through the `LabelRecognitionProvider` protocol —
  which is also the swap point for a future `OpenAIProvider` if the no-paid-API
  constraint is ever lifted.
- **There is no Producer entity and there never was.** The spec's heaviest
  weight (50) is for a field the catalog cannot confirm, so producer matching is
  text-only — an estate-keyword pass then the most prominent unclaimed line —
  and the weight degrades to 15 (`LabelConfidence.producerTextOnly`). A producer
  guess alone can never carry a reading over the confidence floor.
- **§8 is a walk, not a table.** `BAROLO` → the region whose `appellations` list
  it (Piedmont) → `details.origin` (Italy) → `notableGrapes` (Nebbiolo) →
  `grapeStyle` (Full-Body Red). Nothing about that is written down in the
  feature; both spec examples (Barolo and Vouvray) are pinned as tests.
- **`isInferred`** was added mid-batch: a walked field is *shown* and scores
  *nothing*, so Barolo's 35 points do not silently become 80 for consulting the
  catalog about its own cross-references.
- **`xtool.yml` gained `infoPath`.** Both that file's comment and KNOWN-ISSUES.md
  asserted no Info.plist passthrough existed; false of xtool 1.17.0. Corrected
  in both places, and `CFBundleShortVersionString` turns out to be settable too
  (M6/M37 unblocked — not taken here).

**Parked from 0.7.2:**

- Not deployed. The last attempt failed provisioning with a 409 from the Apple
  Developer API ("no current iOS devices on this team matching the provided
  device IDs") — an account/device-registration problem, not a build one. The
  label reader has therefore **never been seen on a phone**, and it is the one
  feature in the app whose core input (the camera) the simulator cannot supply.
- The vintage floor is 1900 and the ceiling is next year. Sparkling
  disgorgement dates and multi-vintage labels are unhandled by design.
- Fuzzy suggestions in the no-match state are edit-distance only. Ranking them
  by OCR confidence as well is the obvious next refinement.
- `AppVersion.fallback` could now be stamped into the bundle via `infoPath`
  rather than living only in the constant. Deliberately not done: two places to
  keep in agreement, one source of truth.

**0.7.1, by section** (all six landed; the spec's suggested A+C+E / B / D split
was used as the *sequencing* rather than as a scope cut, each phase gated
before the next started):

- **A** — MASTER SEARCH rename plus the retirement of the dead `.masterSearch`
  route it collided with; one magnifier everywhere (`DexGlyph.search`); South
  America off North America's colour (`shared/data/continents.ts` → sync →
  generate → zero dangling); header lamps 17→22pt; and `RecessedLamp`, one
  modifier now seating all eight lamps on the device.
- **B** — `MarqueeScript` (Core, tested) drives WELCOME! → MENU → CHEERS!;
  `PixelDissolve` gives the transition its pixels; the panel is a button on
  every screen opening `MarqueeDrawer`, which carries a two-slot pin bar
  (`QuickPinStore`, Core, tested).
- **C** — VINTAGE group → RETRO, WINE.OS → Emulator, GRÜNERBOY → Retro,
  HALLOWEEN → HALLOWINE (label only), and `LcdMode.chrome(face:shadow:)` so
  Emulator modes repaint the app's coloured tiles in their own ramp.
- **D** — the tried shelf now dates its entries (`BookmarkStore.triedDaysKey`,
  new — nothing recorded a date before this), which is what the activity graph
  is built on; `PassportProgress` diffs earned badges so an unlock has a
  moment; `PassportTier` is the four-rung ladder from VINODEX MASTER.
- **E** — `DexGlyph.challenge` (`target`) replaces the flame everywhere;
  IDENTIFY → BLIND TASTING, and its glyph left the magnifier family with it.
- **F** — `DexMotion`, four named curves; seventeen longhand animation call
  sites swept onto them.

**Parked from 0.7.1** (candidates for the next batch):

- The drawer opens from the marquee but nothing else on the chassis feeds
  `MarqueeScript.noteActivity()`. Today the idle timer only resets on a
  navigation or a marquee tap, which is correct but conservative — a tap
  anywhere on the LCD arguably counts as activity.
- Africa `#C48B8B` and Oceania `#D4A5A5` are as close to each other as North
  and South America were before A3. Same fix, not asked for, worth raising.
- The 0.7.1 pin bar holds `SettingsSection`s only. Pinning a *tool* or an entry
  is the obvious next ask and `QuickPinStore` would need a wider element type.
- `LcdMode.chrome` blends toward `controlAccent`; the Retro group is
  deliberately excluded because the chassis already greys and tints the whole
  LCD for it. If those modes ever lose the grayscale pass, they need the blend.

**0.7.5, The asset gate** (`audit-review/FINDINGS.md` A026–A028). A small batch
that closes the three asset-gate findings, run while `auditbot` worked the
safe-tier housekeeping.

- **The gate found a live bug on its first run, which is the whole argument for
  it.** `assertAssetsExist` reported `flag: Brazil — expected
  Sources/VinodexUI/Resources/Flags/brazil.png`. `icons.json` has listed a Brazil
  flag since 0.7.3c; the master was in `shared/pixelflags/South America/brazil/`
  the whole time; nobody re-ran `npm run icons`, so it was never copied into the
  bundle, and `FlagLoader` returned nil for every Brazilian region. That is the
  **fourth** silent-missing-asset bug in four batches, after `icon: "fruit"`
  (0.7.4), the screensaver layers (0.7.5 A5) and the Brazil/Mexico outlines
  (0.7.5 D) — and the first one found by a machine rather than by reading.
- **auditbot's placement held: the generator, not `verify-art.py`.** Verified
  rather than assumed. `verify-art.py` re-runs the importers into a temp tree
  with `ART_OUT` and diffs pixels, so it can only answer "did the committed art
  change" — it never loads the catalog and cannot know which ids are
  *requested*. The generator already holds the manifest it just built. It is
  also the half that runs in CI: the `data` job runs `npm run generate` on every
  push, while `icons:verify` needs Pillow and is run by hand.
- **One refinement to the placement: it runs *after* the writes.** The other
  assertions throw before `writeFileSync`. This one cannot, because
  `rasterize-icons.sh` reads the `unique` list *out of* `icons.json` — a gate
  that threw first would refuse to emit the manifest the rasteriser needs in
  order to produce the file the gate is demanding, and a new icon id would be
  unbootstrappable. Ordered after the write, adding an icon is: generate (fails,
  naming the id) → `npm run icons` → generate (passes).
- **No backlog list, deliberately.** `OUTLINE_BACKLOG` earns its keep because
  drawing an outline to match the other 28 is a job that can be honestly
  outstanding. Nothing this gate checks is: every id is satisfied by `npm run
  icons`, one command and no drawing. An allowlist with nothing in it is rot
  waiting to happen.
- **Proved against injected data, all four resolution classes.** With the file
  removed, the gate names `game-icons:almond`, `art:outline-france (via
  icons.countryShapeIcons.france)`, `flavorArt: almond` and `flag: France`
  respectively. It also matches `IconLoader`'s scale walk exactly: with only
  `@3x` present and `@1x`/`@2x` gone it **passes**, because that is an icon the
  app draws.
- **The `art:` ids are collected by walking the manifest, not by listing tables.**
  Nine tables carry them today in three value shapes, and a hand-kept list of
  tables is precisely what went stale in `COUNTRY_SHAPE_ICONS`. The walk covers
  the tenth for free. The three portrait tables (`flavorArt`, `grapeArt`,
  `styleArt`) ship bare stems a walk cannot tell from prose, so those are named.
- **A026/A027: the four rosters now agree, and a test holds them there.**
  `import-logo-art.py` shipped in A5 wired into nothing — not `package.json`,
  not `rasterize-icons.sh`, not `verify-art.py` — so the screensaver wordmark was
  reproducible from `art/icons/dvd/` only by someone who knew the file existed.
  `import-stamp-art.py` had been in the rasteriser and not the verifier since
  0.6.4, so `StampArt` was generated and never checked. Both are now in all
  three, and `ArtPipelineRosterTests` treats `scripts/import-*-art.py` **on
  disk** as the authority: the rasteriser's roster, `IMPORTERS`, `DIRS` (through
  each importer's `output_dir(..., "Name")` call) and the `package.json` scripts
  are all checked against it. Injecting each of the four drifts fails the suite;
  restoring makes it green.
- **Two importers had to learn `ART_OUT` first.** `import-logo-art.py` and
  `import-stamp-art.py` hard-coded their destinations, so adding them to
  `verify-art.py` as they stood would have turned `npm run icons:verify` — a
  command whose docstring promises it "can never overwrite" the bundle — into a
  write over 256 tracked binaries.
- **`icons:verify` was already red, on six files, and is now green.** Not this
  batch's doing: the same six `ClassArt/subclass-*` files were CHANGED at
  `4c308ae`. Measured against `subclass-citrus` and `subclass-floral`, which
  already carry budgets, they are indistinguishable — 0.009–0.257% of pixels
  moved (controls 0.115–0.199%), max per-channel delta 17–31 (controls 15–37),
  and **zero alpha pixels moved** in any of the eight, which is what an actual
  art edit would show first. So they went into `TOLERANCE` as what the table
  says it is: a record of the quantiser's imprecision, here crossing a platform
  boundary — the existing budgets were measured on darwin-arm64 and the pipeline
  now also runs on win32 and in WSL.
- **The icon half is byte-reproducible, which is worth writing down.** Rasterised
  fresh in WSL into a temp tree and diffed against the bundle: all 207 PNGs
  identical, 0 of 34 flags differing but the one that was absent. `npm run icons`
  is not a lossy step for the Iconify half.
- **The silent failure itself is still silent, by design.** `IconLoader.image`
  and `PixelArtLoader.image` still end in `return nil` with no diagnostic. That
  is correct at runtime — a shipped build should degrade, not trap — and the
  point of A028 is that the id can no longer *reach* a shipped build.

## A. Audit debt — suggested next sittings (from AUDIT.md's 52 open)

Ordered by risk-times-cheapness; IDs are AUDIT.md's, one row ≈ one sitting.

1. **Robustness spine**: H2 (element-wise entries.json decode + DexAlert),
   M2 (explicit DATA LOAD ERROR state), M3's Swift half (schemaVersion
   asserted at load). One sitting, closes the "one bad regen from critical"
   risk the audit flags at the top.
2. **Perf quick wins**: M7 (CountryScreen query reuse), L14/L15 (repeat
   scans), M8/M9 (marquee measure cache + TextScale seam), L16 (font probe).
   Mechanical, testable by inspection + device feel.
3. **A11y pass**: H11 (Dynamic Type strategy), M18 (reduce-motion), M20
   (globe VoiceOver fallback), M21 (flip discoverability). One themed PR.
4. **Icon crispness**: H6 (@2x/@3x selection in IconLoader) + L28
   (`interpolation(.none)` on DexIcon) — pairs naturally with the 0.6.2
   outline work and finishes the "icons look soft" complaint at the root.
5. **Release hygiene**: M36 (font/icon licenses + LICENSE file), M37's
   CHANGELOG.md (seed it from the tag annotations), L20 (AppIcon recompress),
   L22 (pin xtool version in the release checklist).
6. **Architecture** (when a quiet stretch exists): M30 split of
   EntryDetailScreen/DeviceChassis — both grew again in 0.6.x; do it before
   the next chassis feature, not after. M27/M29 ride along.

## B. File & folder cleanup

> **Swept 0.7.5 (A029).** This section was written at 0.6.2 and four of its
> items had been done for five releases while still reading as open, which is
> its own kind of rot — a checklist nobody trusts is a checklist nobody reads.
> Done items are struck with the release that closed them; the ones still open
> keep their box, and the three that are now tracked as audit findings say so.
> The **live** items are: grape-sprite prune, KNOWN-ISSUES.md 0.6.x section,
> `HGapps` git init (A033), the spec-file move, and the web hardening list.

- **vinodex-ios repo**
  - [ ] Prune retired grape sprites: with the leaf now code-driven, only the
    `-rare` bases (+ blends' rare variants, `green-common` unused?) are
    referenced by `grapeArt`. The `-common`/`-noble` artist variants are
    dormant payload — either delete from Resources (masters stay in
    `art/icons/grapes`) or record why they stay. ~200KB.
    *Still live, and now measurable: 0.7.5's asset gate reports `grapeArt` uses
    **14 distinct stems** against **33 files** in `Resources/GrapeArt`. Note the
    gate only proves every referenced stem exists — it says nothing about
    unreferenced ones, so this stays a judgement call.*
  - [x] ~~`art/` and `pixelflags/` are untracked working dirs at repo root —
    decide: commit them or move them out.~~ **Done, and the recommendation was
    taken.** `art/` is tracked (310 files) and `pixelflags/` moved to
    `shared/pixelflags` in 0.6.5 (batch 4, phase 1) — the cross-repo master,
    because the flags are the one art asset both apps consume. There is no
    `pixelflags/` at this repo's root any more.
  - [x] ~~`.vscode/` at repo root is untracked~~ — committed; it carries the
    Swift/WSL `swift.path` wiring, as suspected.
  - [x] ~~Delete `Resources/Icons` orphans again after the next `npm run
    icons`~~ — the prune step ran clean in 0.7.5: 207 PNGs, 0 orphans, and all
    207 byte-identical when re-rasterised. Superseded as a standing chore by
    `assertAssetsExist`, which fails the *other* direction (a referenced id with
    no file) on every `npm run generate`.
  - [ ] KNOWN-ISSUES.md: add a short section for the 0.6.x additions —
    find-missing-refs.mjs as the data gate, the leaf-recolor loader, and the
    "art masters vs shipped Resources" relationship. *Add the 0.7.5 gates to the
    same section while there: `assertOutlineCoverage`, `assertAssetsExist` and
    `ArtPipelineRosterTests`.*
- **HGapps root**
  - [x] ~~Root .md census: move SHIPPING-REVIEW.md + PORT-TO-WEB.md to an
    `archive/` folder~~ — done in 0.6.5. Both have lived in `HGapps\archive\`
    since, alongside four retired scratch drops (including
    `shared-newicons-retired-0.6.5`). The live root docs are `README-layout.md`
    and `V1-ROADMAP.md`; this file moved to `vinodex-ios\horizon-md\`.
  - [ ] `HGapps` root is not a git repo — the canonical `shared/` master and
    these planning docs are unversioned. Cheap fix: `git init` at root with a
    .gitignore covering the two repos and `xtool/` — the master data deserves
    history. **Now tracked as `audit-review/FINDINGS.md` A033**, which adds the
    consequence: it is *why* the hub↔repo syncs are one-way. Still a user
    decision.
  - [ ] Downloads spec files (`vinodex-0.5.9.md`, `vinodex-0.6.2.md`,
    `vinodex-missing-data*.md`) — move into `HGapps\specs\` so batches and
    their specs live together and survive Downloads cleanup. *Still open;
    `HGapps\specs\` does not exist yet, and specs since 0.7.0 have arrived
    pasted as often as as files.*
- **vinodex-web repo**
  - [x] ~~Commit the synced `shared/` and the new `shared/newicons/` art
    drop.~~ The `shared/` sync is standing practice (behind web `npm run
    typecheck`). **`shared/newicons/` no longer exists** — it was retired in
    0.6.5 when the drawn-art masters moved to `art/icons/`, and the drop is in
    `HGapps\archive\shared-newicons-retired-0.6.5`. Committing it is not a thing
    that can be done.
  - [ ] The SHIPPING-REVIEW hardening list is still open: CI workflow
    (install/typecheck/build), master branch protection, README truth pass
    (pivot sentence, shared/ ownership table). *`paritybot`'s beat; overlaps
    A001–A004 and A031 in the audit ledger.*

## C. Product next (from V1-ROADMAP, direction updated)

1. **Web catch-up batch** — the roadmap's "web first" rule inverted while iOS
   sprinted; the highest-leverage next feature work is porting iOS 0.5–0.6
   wins to web with the Swift files as spec: chip filter tool (M1's facets),
   Wine Exam + Daily Challenge (M3), shelves/ratings (M2). Run as 2–3 dexbot
   batches in vinodex-web, one feature each, HGapps\archive\PORT-TO-WEB.md's guardrails
   (no new deps, no storage APIs beyond the agreed schema, typecheck+build
   as gates).
2. **M0 ops** — hosting decision, web CI + branch protection, privacy/support
   pages. Small, unblocks analytics and the feedback form.
3. **M4 editorial** — sources/reviewStatus fields in canonical shared (the
   one v1.0 schema change), then the long-lead content pass. Start early.
4. **iOS niceties parked from batches**: mapPosition fine-tuning by eye
   (authored coordinates are approximations), style portraits for the three
   derived stems when the artist next draws, Mexico outline art
   (`outline-mexico`) so Valle de Guadalupe gets dots.

## D. Standing conventions (so future batches stay cheap)

- Data changes: master `shared/` → sync → generate → `find-missing-refs.mjs`
  zero dangling → deliberate test-pin updates → three verification gates →
  deploy. (Encoded in dexbot.)
- Releases: one `feat(ios): vX.Y ...` commit per batch through the protected
  main, annotated tag = release notes. Bump `AppVersion.fallback`; append the
  outgoing total to `waveMilestones` when entry counts move.
- Data *accuracy* is the `sommbot` agent's beat (`.claude/agents/sommbot.md`):
  it audits `shared/` against regulator and ampelography sources, applies
  in-place corrections, and keeps `data-review/FINDINGS.md` (verification
  ledger) + `data-review/CANDIDATES.md` (ranked staging backlog). It hands
  entry additions and enum changes to dexbot rather than making them.
- Every new enum value (rarity, climate, system) touches: shared types,
  constants mapping, chipColors, generator probe+coverage lists,
  EntryDisplay names, exhaustive Swift switches (UI ones too), and test pins.

---

**0.7.6, The consolidation** (the v0.7.5-numbered spec, sections A–F). Its own
scope note splits it: A–F are "quick", and the growth trio — sharing (G), the
Wordle result string (H), daily notifications (I) — is a pass of its own and was
**not built**.

- **A1 removes two things this project built on purpose, and that is the point.**
  The device had three affordances for the same handful of destinations: the two
  marquee lamps (0.7.2 A9, fixed to TOOLS and CUSTOMIZE), two pin buttons in the
  marquee's corners (0.7.2 A7), and a swipe drawer behind the panel (0.7.1
  B4/B5) whose PINNED row was the only way to *choose* what the corners held.
  One of the three existed solely to configure another. A1 keeps the lamps'
  hardware feel and the drawer's customisation and drops everything else: tap a
  lamp to go, hold it to point it somewhere else.

  Retired with it: `MarqueeDrawer.swift`, `pinCorners` / `pinButton` /
  `pinCornerReserve`, `DexMetrics.marqueePin{Button,Inset,Glyph}` (written down
  where they were, not deleted silently — "small round shortcut buttons in the
  marquee corners" is an idea that will come back), the PINS title-swap (0.7.2
  A6), and the panel being a `Button` at all (reversing 0.7.1 B4). The drawer's
  breadth is the honest cost: its TOOLS grid and CUSTOMIZE cycles are one tap
  further away, through the two screens the lamps land on.

  **Nobody's pins are reset.** `QuickPinStore` keeps its key and its encoding;
  `MarqueePin`'s raw values are a strict superset of `SettingsSection`'s (it adds
  `TOOLS`, which is `DexRoute.minigames` and was never expressible before), so
  `"DATA,ACCESS"` decodes to what it always did. A single stored pin keeps its
  slot and the other lamp fills from the factory pair. `DEV` is the one section
  with no counterpart and is the one the chooser has never offered.

- **The hold gesture needed somewhere to be taught**, and F1 supplied it. The
  drawer carried "HOLD A SHORTCUT TO PIN IT" on its own surface; with the drawer
  gone the walkthrough is where that sentence lives — a ninth step, and the
  first ever to use `WalkthroughStep.Highlight.marquee`, which has been declared
  and unused since v0.5.4. The diagram grew the two lamps so the step has
  something to point at.

- **A3/A4: the idle timer stops being two stages.** The screensaver goes 15 → 30
  seconds and the marquee greeting, which fired at 10 on the main menu only, now
  arrives *with* it on any screen. Implemented so reverting is a threshold
  change: `IdleSchedule.toast` is a `TimeInterval?` holding `nil`, the stage
  table rebuilds itself from it, `IdleStage.toast` stays in the enum, and every
  consumer still asks `stage >= .toast` — true the instant `.screensaver` is
  entered, because the stages are `Comparable`. Give `toast` a number below
  `screensaver` and 0.7.5's behaviour comes back whole. 0.7.2's A8 rotation
  survives unchanged: one language per idle period, nine in the ring.

- **A2 keeps the closed form.** A random start is a *phase* on the existing
  triangle wave rather than a seeded simulation — one pair of numbers buys a
  random position *and* a random heading, the mark is still a pure function of
  time, and the two-hour-exactness tests are untouched. `bounces` counts walls
  since the run began rather than since the origin, so a random start does not
  also randomise the opening colour.

- **B1 is two axes, not three, and the third is a rename.** The spec asks for
  "marquee status-light button colour, footer button colour, header
  colored-lights colour". The first and third had no axis in any form; the
  second has been settable as `DeviceAxis.buttons` since 0.7.3b, under a heading
  ("BUTTONS") general enough that the workshop's own row list did not say so. It
  now reads FOOTER BUTTONS. Eight axes becomes ten.

  **The hazard B1 nearly shipped:** `DeviceBuild` is `Codable` and stored as JSON
  in `customDevices`, the synthesised decoder throws on a missing key, and
  `CustomDeviceStore` reads with `try?` — so two new fields would have made every
  build saved under 0.7.3b–0.7.5 fail to decode, the store return `[]`, and every
  saved device vanish on first launch. Hand-written `init(from:)` with
  `decodeIfPresent` on all ten, plus a test that decodes the exact JSON an older
  build wrote.

- **D1's IP line, and where it is drawn.** Inspired-by colours and silhouette
  only. The rule is `buttonSet`'s own, unchanged since 0.6.7 (K2/K3): a console
  livery takes *colours* and nothing else, the glyphs stay the house chevron,
  house, person and cog. No logo, no trade dress, and no reference in a type
  name, a comment, an asset filename or a shipped string. The rawValue `"W64"`
  was picked once for three jobs at once — the `chassisSkin` `@AppStorage` value,
  the FNV-1a seed for the back plate's procedural wear, and the `sticker-w64`
  art stem — and `displayName` restates it rather than diverging, which is what
  every rename note in `DexTheme.swift` wishes the earlier names had done.

- **E1 re-derived the clearance and it did not move.** The orb is a `Capsule`
  now, and the elongation is spent on *height*: `islandOrbInsetLeading` puts the
  slot at 64pt against a cutout starting at 133 on the narrowest island device,
  and 0.7.1's A4 is a page about what happens when that 69pt is spent twice by
  two edits that did not know about each other. Width unchanged, slot unchanged,
  inset unchanged. The bead lands at 35.2×20.1 (SMALL), which is within a point
  of `islandStatusDot` — so the two clusters either side of the cutout are the
  same height for the first time.

  One reversal it forced: 0.7.5's A2 made the orb's hit shape follow its own
  outline. That argument holds while the art fills the slot; a pill half the
  slot's height would have cut a 44pt target to 35×20, on the control carrying
  the flip gesture. Back to the slot.

- **C stays an overlay.** 0.7.5's B4 argued a route would mean a `DexRoute` case,
  `ChromeTests` coverage, a marquee title and a glyph for a card dismissed by
  looking away. Everything C2–C4 adds is content in the same scrolling column —
  larger type, a bigger product shot, and a preview strip. The line it does not
  cross: nothing in the strip is a control. Tapping a shell to try it on would
  make the splash a place you can navigate from, and that is the version that
  should be a route.

**0.7.7, The BIOS screen** (`vinodex-0.7.7-bios.md`; the document is titled
0.7.6, which is the batch above). One screen, rebuilt from a written description
of a mockup, **superseding 0.7.3a's A1 and 0.7.5's A6 wholesale** rather than
layering on them.

- **The mockup's own version string was the trap, and C3 beat it.** The
  description shows `VINODEX BIOS v1.0.0`. `1.0.0` is a member of
  `AppVersion.placeholders` — it is what xtool stamps into every bundle, the
  denylist is the only reason the app reports a version a human chose, and "the
  back plate reads 1.0.0" has been the standing signal that the denylist has
  broken. A BIOS printing it as decoration would have made that failure
  indistinguishable from the app working. Bound to `FirmwareCatalog` through
  `BootSequence.header`, and `BiosChromeTests.titleIsNotThePlaceholder` now
  asserts the denylist from the direction of a screen. The copyright year rides
  the same source — the current release's `date` — rather than a literal or the
  device clock.

- **Full-screen, which reverses 0.7.3a and needs the reversal stated.** That
  release put the POST inside the LCD, arguing that dimming the bezel, island and
  footer reads as the device losing power at the one moment it is doing the
  opposite. B1 asks for full-screen and supersedes it, and the argument does not
  survive the change of shape: what read as power loss was a *translucent overlay
  dimming* the chassis, and this is opaque and total. The composition also brings
  its own frame — terminal border, side rails, corner brackets, two status bars —
  so an inset version would have been a bezel inside a bezel. **The chassis is not
  visible around it**, deliberately: a plastic border showing at the edges is the
  dimmed-chassis reading again. Presented as an `.overlay` on `DeviceChassis`
  rather than a `ZStack` around it, so the scale `id`, the Dynamic Type pin and
  `onAppear` keep applying to both without being restated.

- **C1/C2 moved a pin, and it was re-pinned rather than widened.** 0.7.3a asserted
  the whole POST under 2s (`BootSequenceTests.brief`) and 0.7.5's A6 kept that
  while scaling the type up, on the reasoning that a POST which filled the screen
  by running longer would be worse rather than bigger. Staged checks plus an
  auto-advance timeout is a different shape: `duration` now bounds the **checks
  phase** — same number, same argument, a fourth line still fails it — and a new
  `neverTraps` bounds the rest, asserting the timeout is non-zero, at least 3s so
  the prompt is readable before it answers itself, and that the whole untouched
  launch stays under 6s. Widening `brief` would have quietly retired the only line
  stopping a fourth check.

- **B4's four glyphs, and why none is a new art asset.** The spec offers "build
  them in `art/icons/`" *or* "reuse existing equivalents", and since 0.7.5's
  A026–A028 a new asset is no longer a file in a directory — `assertAssetsExist`,
  `ArtPipelineRosterTests` and `verify-art.py`'s `DIRS` all have to be satisfied.
  Right for drawn art, wrong for these: the **wine glass** already ships
  (`game-icons:wine-glass`, in the manifest since the flavour taxonomy), the
  **battery** cannot be a sprite because D1 makes its fill a function of
  `UIDevice.batteryLevel`, the **signal bars** are four rectangles, and the
  **grape cluster** is six squares and a stem at 14pt — a master would be larger
  than the thing it draws. Code-drawn is also tintable by role and sharp at every
  `TextScale` step, which is 0.6.2's argument for recolouring the rarity leaf in
  `GrapeSpriteLoader`. **The "V" is the one reuse the spec named**, and it is not
  where the spec says: B4 points at `art/icons/dvd/`, but 0.7.5's A5 moved the
  shipped mark to `Resources/Logo` as face/shade masks split on luminance —
  which is exactly what the composition wanted, since it asks for cream pixels
  over a magenta drop shadow and the two layers were already separate.

- **The one house rule broken on purpose.** Every themed surface reads an `lcd.*`
  token; `BiosInk` is five fixed hexes. A BIOS runs before the system that knows
  what the user chose, so a boot screen that already knew your phosphor would be
  the part of the metaphor that gave the game away. The roles are what keep it to
  three colours: cream is the system talking about itself, gold is telemetry,
  magenta is the frame and the prompts.

- **D2's signal bars are drawn full and static, and that is the honest option.**
  A meter reporting a strength the app never measured would be the quiet lie
  `AppVersion` spends forty lines on; four full bars are plainly chrome. The one
  live reading is the battery, which is live because D1 asked for it and
  `BiosChrome.battery` handles the `-1` that the simulator and every
  pre-monitoring device return.

**0.7.8, Chassis & device** (spec pasted, section A only). Sections B–D — the
sharing / Wordle-string / notifications trio — are the spec's own scope note and
are a separate pass; section E ran concurrently as an `auditbot` sitting; F was
answered before the batch started. Four items, no `shared/` data touched outside
`firmware.ts`, so **438 stands and `waveMilestones` does not move**.

- **The branch note is part of the record.** The spec said "branch off `testing`",
  which was at `fc2c194` and did not contain 0.7.3 through 0.7.7 — taken literally
  it would have been destructive. The user had already verified `testing` was a
  strict ancestor of `v0.7.7-batch` with zero divergence and fast-forwarded it to
  `e6a8d1c`, so `v0.7.8-batch` is cut from a `testing` that holds all nine commits.

- **A1 undoes 0.6.5's item 8, and the thing it undoes is a category error.** That
  release replaced the per-skin die-cut sticker with a postage stamp on the badge
  stamps' own perforated frame, reasoning that the Passport stamps set the plate's
  visual dialect and the skin piece should speak it. The dialect argument was
  about *materials*; the answer it gave was about *identity*, and the plate has
  read as carrying seven collectibles ever since when it carries six and a
  decoration. The two now differ on every axis that means anything: silhouette
  (perforated portrait rectangle vs die-cut square with a lifted corner), stock,
  printing, surface (the sticker gets a gloss sweep, vinyl catches light and paper
  does not), and interaction — the stamps are tapped and dragged, the sticker is
  inert.

- **The hit-testing warning was taken seriously and cost nothing.** 0.7.2's A2
  found that `.contentShape(Rectangle())` outside `.offset` had pinned all six
  stamps' hit regions to one box in the plate's corner, dead to tap and drag for
  three releases. So: the sticker declines hits **in its own body** as well as at
  the call site, it is mounted *below* `stampField` in the plate's `ZStack` so
  even a decoration that accepted a touch could not take one from them, and there
  is deliberately no `contentShape` anywhere in `SkinSticker.swift`. The stamp
  drag chain in `DeviceBackPlate.stampField` is byte-identical.

- **`WornOverlay` is the one thing the two still share, and it moved out of both
  files.** It was declared in the stamps' file and reached across by the sticker,
  which is the shape A1 exists to undo. Sun, thumbs and shelf dust do not care
  what they are working on, so it is a material rather than either object's
  identity: `AgedMaterial.swift` now holds it and `GrainSpeckle`, and neither
  side imports the other's file. Nothing in it mentions stamps or stickers, which
  is the test of whether the split was drawn in the right place.

- **The art namespace split was free of bytes and not free of wiring.** There is
  no authored art for either family — `art/icons/stamps/` held a README and
  nothing else, and `Resources/StampArt` has never existed — so this is a pure
  rename of a contract. But `import-sticker-art.py` is a **seventh** importer, and
  since 0.7.5's A027 that means four rosters plus two search paths:
  `rasterize-icons.sh`, `verify-art.py`'s `IMPORTERS` and `DIRS`, a `package.json`
  script, `PixelArtLoader.subdirectories` and the generator's `ART_DIRS`.
  `ArtPipelineRosterTests` is exactly what turns "remember six places" into a
  failing test, which is the return on that batch. The two READMEs are now
  separate briefs, and the sticker one names all 22 skins — the old list silently
  omitted five, and a roster that disagrees with the enum is what an illustrator
  would have worked from.

- **A2's rule was already written down, ten times, in the wrong place.**
  `ChassisLook` is ten lines of `partOverride ?? skin.something` and `LcdMode` does
  the same for the font ink, so every axis already had an answer to "whose look
  shows through when I am empty?" — spelled once per member, in `VinodexUI`, where
  no gate can read it. `DeviceAxis.inherits` names it in Core, and A2 becomes a
  rule rather than a list: **a preset clears exactly the axes that would have
  inherited from it.** Seven parts follow the shell; the font follows the screen.
  That is also what keeps the two CUSTOMIZE pickers independent — picking a shell
  must not undo the screen mode in the list below it, which is a bug the rule
  prevents rather than a case it happens to miss.

- **No saved build is destroyed, and the honest statement is narrower than
  "nothing happens".** `customDevices` is a different key holding a different
  list and nothing in this batch reads or writes it; a build survives a relaunch
  byte-identical (`choosingAPresetDoesNotTouchSavedBuilds` asserts through a
  fresh store). What a fitted build stops being is *fitted*, because
  `matching(_:)` derives that by comparing values and the values just changed —
  the same thing that already happened when one part was swapped in the workshop.
  It is one tap from being fitted again. This is not the 0.7.6 decoder hazard in
  another guise: no decoding is involved.

- **The confirmation is the exception, not the rule.** A device that has never
  been through the workshop has nothing to clear, so the tap lands exactly as it
  always did — a picker raising a modal every time you tried a shell on would be
  worse than the bug. It appears only when parts would actually be lost, names
  them, and names the saved build if one is fitted.

- **A2 also closed a live inconsistency nobody had filed.** `skinGrid` wrote the
  literal `"CLASSIC"` while the workshop's own chooser wrote `""` for the same
  choice, so picking CLASSIC in Settings produced a device that was visually stock,
  reported `isStock == false` forever, and could never match a saved build whose
  shell was empty. Same for DARK and `lcdMode`. One spelling per choice is
  `DeviceBuild`'s founding invariant and this was the last writer disobeying it.

- **A3 spent the elongation on height for the third batch running.** 1.75 → 2.35,
  and **not one horizontal number moved** — `islandOrb`, `islandSlot`,
  `islandOrbInsetLeading` and `islandStatusInsetTrailing` are untouched, so the
  69pt cutout budget 0.7.1's A4 is a page about is unspent. Re-derived anyway,
  because that note's standing instruction is about proving it: the slot still
  runs 64 → 108 against a cutout at 133 (~25pt clearance) and the lamp trio still
  runs 79.4 in from 32 at SMALL, 85.4 at LARGE. The bead resolves to **35.2 × 15.0
  at SMALL and 40 × 17.0 at LARGE**.
- **A3's ceiling is derived, not chosen.** The rim is `max(height × 0.11, 2)`, so
  below a height of 18.2 the 2pt floor takes over and further elongation comes
  straight out of the coloured core rather than off the bead proportionally.
  Holding that core at ≥ 10pt at SMALL gives height ≥ 14, i.e. an aspect ceiling
  of 2.51; 2.35 sits inside it with a core of 11.0 (SMALL) and 13.0 (LARGE).
- **What A3 costs, stated rather than absorbed.** 0.7.6's E1 deliberately bought
  orb height ≈ `islandStatusDot`, so the two clusters flanking the cutout weighed
  the same. At 15 against 22 that is given up and the orb is the lighter of the
  pair. The device's own cutout is ~125 × 37 (aspect ~3.4) and A3 asks the bead
  toward it; it cannot arrive without width, which is forbidden, so the trade is
  the notch's proportion against the trio's mass. **Worth an eyeball.** The hit
  shape stays the 44pt slot and gets *more* right, not less — an outline-shaped
  target would now be 15pt on its short axis.

- **A4 reverses 0.7.7 one batch later, and the reversal is narrower than it
  looks.** 0.7.7 went full-viewport arguing that a composition carrying its own
  terminal border, side rails and corner brackets could not be nested inside the
  chassis's plastic one. A4 accepts that diagnosis in full and deletes the drawn
  frame instead — the move neither batch had considered. The device already draws
  a chamfered panel, a stone band, a white bezel and a vent strip; the screen can
  go back in the screen provided it stops bringing a second frame. `BiosFrame` is
  gone with `tickPitch`, `tickLength`, `bracket` and `frameInset`. The three
  zones, `BiosRule` (a zone divider, not the frame), the palette, the scanlines,
  the tinted logo masks and the derived title are untouched.

- **The type-scale re-derivation found the old numbers were wrong.** 0.7.7's block
  costed the status bars at their nominal 8pt; `TypeScale.resolve` applies
  `nominalFloor` (10) *before* the step factor, so `retro(8)` has always rendered
  at **8.5pt**, exactly the trap `BackPlateStampView`'s title note records. The
  real 0.7.7 top bar was 379.5pt against 353 — riding `minimumScaleFactor` at the
  default text step since it shipped, which is precisely what 0.7.5's A6 forbids.
  The LCD's content box works out to **353pt** on a 393pt phone (393 less
  `screenPanelInset`, `bezelInsetH - bezelFrame` and `bezelFrame` each side), the
  same figure the viewport offered, because the chassis's surround costs what the
  old `contentInset` did. At a 12pt inset that is 329, and 43 characters of a
  full-em face need 7.65pt each against a floor of 10 — impossible. **So the top
  bar is two lines**, same strings, same colours, same roles: 204 and 161.5 at the
  default, 276 and 218.5 at HUGE, both inside 329 at every step. A layout change
  rather than a smaller size, per A6.

- **Vertically there is no single number, so the mark is the member that gives.**
  The display is the window less the island strip, less the whole footer, less
  four bands of bezel, and the footer follows `UIScale` and the device.
  `markCeiling(in:)` measures what is left after everything with words in it is
  paid for — every term derived from `DexFont.resolvedSize`, so it follows the
  text step and the MAINFRAME cheat's two extra check lines on its own — and
  clamps between 92 (0.7.7's size, not to be exceeded) and 40. The logo is the
  one element with no text in it, which makes it the right thing to lose first.

- **The gesture was re-derived and survived its own justification.** 0.7.7's
  `Color.clear.ignoresSafeArea()` existed because a safe-area-aware stack left
  the notch and home-indicator strips falling through to the chassis, where the
  island orb is a live control. Inside the LCD every clause of that is false —
  the display never overlaps either strip, and its `clipShape` would have
  confined the layer anyway, making it a modifier that did nothing. But the
  literal reading (delete it) is worse than either: the chassis is *visible* now,
  which is the whole point of A4, and the footer buttons, marquee lamps and orb
  are all live. So **the picture is in the display and the input is the
  window's** — `BootAdvanceCatcher` is an overlay on the chassis, and a separate
  view so the reason lives where it applies.

- **The scanlines are pitch-locked, which the reframing forced.** `BiosScanlines`
  was 1pt every 3pt over a window where nothing else drew lines. Inside the LCD,
  `ScanlineOverlay` is already filling 2pt every 4 in the same coordinate space
  one layer above; 3 against 4 beats with a 12pt period, ~30 visible bands down
  the display. It rides the same 4pt pitch now and lands in the display's own
  gap, which makes the BIOS's raster *finer* than the app's rather than merely
  different. `BiosVignette`'s radii became fractions of the diagonal for the same
  reason — as points they were tuned to a 938pt viewport diagonal and would have
  put the entire vignette outside a display half that size.

- **Gates.** `npm run generate` (0.7.8, 17 releases, 337 asset ids resolve),
  `find-missing-refs.mjs` zero dangling, `swift test` 512 green in 52 suites
  (six new in `DeviceWorkshopTests` for A2), `npm run icons:verify` 239 identical
  / 16 tolerated / 0 changed, clean `rm -rf .build && xtool dev build` — the only
  thing that compiles the four rewritten `VinodexUI` files. **Not deployed**, per
  the spec.

### Parked

- ~~**`npm run icons` produces a byte diff on the two wordmark PNGs**~~ —
  **resolved in 0.7.7**, and it was never a reproducibility failure. Measured:
  the importer is bit-for-bit deterministic *within* an environment (two runs,
  identical hashes) and the two environments disagree because they ship different
  PNG encoders — WSL has Pillow 10.2 on zlib 1.3 and writes 2087 bytes, Windows
  has Pillow 12.3, which bundles zlib-ng, and writes 1968. `Image.tobytes()`
  matches exactly, so only the deflate stream differed, and no encoder argument
  fixes that. The parked note's worry that this "undermines `icons:verify`" is the
  one thing it did not do: that script already compares pixels and says so in its
  docstring. What it actually cost was a modified binary in the working tree after
  every icon run, on a file the batch had not touched. `art_common.save_stable`
  now writes only when the destination's pixels differ; `import-logo-art.py` uses
  it, the other five importers can adopt it, and the 0.7.7 run reported both marks
  `unchanged` with `icons:verify` at 255 identical.
- **`sticker-w64.png` is unauthored**, like every one of the other twenty-one
  skins. `SkinStickerView` falls back to the emblem symbol, so the back plate is
  correct rather than empty. Listed in **`art/icons/stickers/README.md`** since
  0.7.8's A1 moved the brief out of the stamps' folder, with the IP constraint
  restated, because that file is where an illustrator will read it. The six
  `stamp-*` badge glyphs are equally unauthored and now have that README to
  themselves.
- **The 0.7.8 spec's sections B–D were unbuilt at section A** — sharing, the
  Wordle result string and daily notifications, the same growth trio 0.7.6's
  G/H/I parked. They landed in the follow-up pass; see the 0.7.8 B–D entry
  below. Section F was answered before the batch; E was `auditbot`'s, run
  concurrently.
- **A3's orb is worth an eyeball before the next batch treats 2.35 as settled.**
  It gives up the orb-height ≈ `islandStatusDot` balance 0.7.6's E1 bought on
  purpose; the derived ceiling is 2.51 if it wants to go further, and the lever
  is only ever height.
- **The lamp chooser is reachable only by holding a lamp.** VoiceOver gets a
  named "Reassign" action, and the walkthrough teaches the gesture; there is no
  entry point from SETTINGS. If reassignment turns out to be something people
  look for rather than stumble on, CUSTOMIZE is where a row would go.

**0.7.8 B–D, The growth trio** (spec pasted). Sharing, the Wordle result string
and daily notifications — scoped three times (0.7.6 G/H/I, then 0.7.8 B/C/D) and
built here. Fully local: no backend, no network, no account. No `shared/` data
touched outside `firmware.ts`, so **438 stands and `waveMilestones` does not
move**.

- **C2's three preconditions were checked against the code, and all three hold.**
  The spec asked for confirmation rather than assumption, so: the daily paper is
  `DailyChallenge.seed = DailyPick.dayIndex &* 8093`, and `TastingQuiz.question`
  takes only that seed, a **fixed** `.enthusiast` tier and the shipped
  `WineDatabase` — no account, no network, and deliberately not the player's own
  unlocked tier. The streak is `StreakStore.current`, a real calendar streak. And
  there is no retry: `StreakStore.record` consumes the day on the first sitting
  win or lose, and the daily screen offers no RETRY (the exam owns that button).
- **The one caveat found, and it is recorded rather than fixed.** The paper is a
  pure function of the day index *and the shipped catalog*, and the catalog grows
  every data batch. Two players on different app versions therefore hold
  **different papers on the same date**, and their strings are not comparable.
  Nothing in the build can detect this. It is why the result string carries **no
  puzzle number** — a "Vinodex #238" would assert "we sat the same paper", which
  is the one claim this architecture cannot honour.
- **The streak the string prints is `StreakStore`, not `ExamRecordStore.passStreak`.**
  The brief's note about a streak saturating at 100 points at the wrong one:
  `passStreak` counts consecutive *exam papers*, is derived from a bounded
  history, and its own doc comment says it is deliberately not a calendar streak.
  The passport prints `StreakStore`, so the card does too — unbounded, and
  `streakPassesThrough` pins that it is not clamped at `historyLimit`.
- **Two tiles, not three, and that is a finding rather than a shortcut.** The
  brief illustrates `🟩🟩🟨🟩⬛`, borrowing Wordle's three states. The daily paper
  has no third state to encode: `QuizQuestion` is four options and one
  `answerID`, `QuizSession.choose` takes the first tap and cannot be changed, and
  `isCorrect` returns a `Bool`. A yellow tile would have had to mean something
  invented. Green right, black wrong.
- **Spoiler-freeness is a test, not a paragraph.** `resultStringLeaksNoAnswer`
  sits four real papers and checks the rendered string against every answer id,
  every question id, every topic and **every option's display name** — the wrong
  ones included, since naming a wrong option eliminates it just as usefully. The
  near-miss worth recording: `QuizQuestion.id` is `kind.rawValue + ":" + answerID`,
  so the answer is literally inside the identifier, and any encoding that reached
  for a question id would have leaked. `closedCharacterSet` is the second gate.
- **`QuizSession` gained `marks`, and the migration is the interesting part.**
  A tile grid needs per-question outcomes and the session stored only a `correct`
  *count*. Adding the field breaks synthesised `Codable` decoding of the sessions
  already on disk — Swift treats a missing key as a failure, not a default — so a
  paper half-sat across the upgrade would have been silently thrown away. Hence
  the hand-written `init(from:)` with `decodeIfPresent`, and
  `DailyResult.Card.hasGrid`, which drops the grid rather than padding it when
  the record is short. An invented tile is a wrong tile.
- **B3 does not render `DeviceChassis`, and the reasons are concrete.** Rendering
  the live chassis off-screen fails in five ways that would all ship silently: its
  `body` reads `geo.safeAreaInsets.top`, which `ImageRenderer` does not supply;
  `StretchedWordmark` measures itself in `onAppear`, which a one-shot render never
  runs; `MarqueeBanner`'s text arrives via `task`/`onChange`, so the marquee would
  export **blank**; `PulseGlow` animates `@State`, so every lamp renders at its dim
  extreme; and `Screensaver`/`MarqueeLampChooser` branch on live state, so an
  export could catch the chooser open. `ShareCardFrame` therefore takes the
  *tokens* — `ChassisLook`, `LcdMode`, the real `ChamferedPanel` silhouette (made
  `public` for this), `ScanlineOverlay` — and is deterministic. It still reads as
  the user's own device because every colour on it is theirs, including the
  monochrome pass, so an AMBER device exports an amber card.
- **`ImageRenderer.scale` is fixed at 3, not `UIScreen.main.scale`.** 1× exports a
  360pt-wide PNG that Messages upscales into mush; but taking the *screen's* scale
  is the subtler bug, because the same card would then export 1080px from a Pro
  and 720px from an SE and the product would look inconsistent for reasons the
  user cannot see. The export is not a screen render, so it does not inherit a
  screen's scale. 1080×1350 from every device.
- **B4 was the finish pass, so every renderer has a button.** SHARE on every
  entry (glyph-only — a fourth *labelled* pill shrank SAVE/WANT/TRIED toward
  illegibility), on the passport's rank card, and on each **earned** stamp, which
  became a button with a corner glyph so the affordance is visible. The result
  string gets COPY and SHARE both, because pasting into an open thread and
  picking an app are different jobs.
- **The notification toggle renders permission, not preference.** `isOn` is the
  conjunction of the stored key *and* a freshly-read `UNAuthorizationStatus`;
  `refresh()` re-reads it on every foreground, because permission can be revoked
  in iOS Settings while the app is not running. Denied is a distinct state with
  its own copy and a deep link, since the system prompt is one-shot and asking
  again returns the old answer silently. `.provisional` counts as on — those
  notifications really are delivered.
- **"Don't nag someone who already played" is why the plan is one-shots.** A
  repeating calendar trigger cannot express it: whether today's paper is done is
  known only while the app runs. So `NotificationPlan` emits a 7-day horizon of
  individually-identified one-shots, re-cut on foreground, on opt-in, and at the
  moment a paper completes — 14 pending at most, far under iOS's 64 cap, where it
  silently drops the overflow. `doneDayIsSilent` and `noStreakNoWarning` pin the
  two rules.
- **"Favourite device" does not exist in this app.** B2's phrase has no
  counterpart in the code — nothing is favourited, and grepping finds nothing.
  The card states the device they are *running*, which is what the DEVICE row in
  Settings already reports: a fitted workshop build by name, or the shell. An
  approximation, and the one item here worth a second opinion.
- **Completion % did not exist either.** The passport reports honest fractions
  and a rank ladder, never a percent. `ShareCard.Profile.completionPercent`
  **floors** and only returns 100 when genuinely complete — rounding would print
  `100%` at 437 of 438, which is the one number on an outward-facing card a
  reader would check and the one claim the player has not earned.

**0.7.9, Orb, outlines, matcher, lineage UI, and a guessing game**
(`horizon-md/vinodex-0.7.9.md`, sections A, B, C2, D-a, E, F, G). The spec's own
scope warning was right — this is not a small batch — but it ran whole rather
than split. Section C1 is **not** in this pass: it is a sommbot data sitting that
runs *after* it, and no file under `shared/` was touched here, which is what kept
the two passes off `entries.json` at the same time. Gates: 576 tests green (up
from 542, and **red at the start of the batch**), clean `xtool dev build`,
`find-missing-refs.mjs` zero dangling across 177 grapes / 124 regions / 33 styles
/ 106 flavors / 30 countries.

- **G ran first because the repo was broken.** Sommbot's P1/P2 batch landed 8
  entries (438 → 446) and 13 exam questions (407 → 420) without moving the pins,
  so `swift test` was red before a line of this batch was written. Nothing else
  in the batch is trustworthy until that is fixed, so it was fixed first.
- **Three pins moved that the spec's list did not name**, and all three are the
  gates working rather than failing. `bodyBarsAreDistinct` — the distribution
  pin 0.7.5's E added precisely so a *branch* would be observable — moved to
  `[2: 42, 3: 81, 4: 17, 5: 37]` on the six new grapes. `styleArtWiring` failed
  because Madeira and Cava had no portraits. And `unconnectedGrapesAreEmpty`
  failed because G177 Plavac Mali authors a contested `related` ref to G017, so
  Zinfandel — the suite's example of a grape with nothing to show — stopped
  being one.
- **The Zinfandel test was rewritten rather than re-pointed, and the reason is
  the suite's own structure.** `GrapeLineageTests` says in its header that its
  first half pins shipped data and its second half pins logic that must not
  move. `unconnectedGrapesAreEmpty` is in the second half and was hardcoded to
  an id, so a data batch broke a *logic* test. It now asks the index for a grape
  it says is unconnected and checks the index agrees with itself, which is the
  assertion that was actually wanted and cannot rot.
- **Gouais Blanc crossing into the catalog was the batch's most interesting
  breakage.** The spec called out lines 87/88/94 — Chardonnay's off-catalog
  parent proving an external ancestor is untappable — and was exactly right that
  renumbering would delete the property rather than move it. Substituted
  Magdeleine Noire des Charentes (named by G004 Merlot and G012 Malbec), which is
  a better fixture: nobody drinks it, so no data batch has a reason to promote
  it. The half-sibling assertion moved with it, and `throughGouais == 9` was left
  alone and still passes — the family did not come apart when its shared-parent
  key changed from a folded name to an id, which is the property worth having.
  Four doc comments across `GrapeLineageIndex`, `GrapeLineageScreen` and
  `EntryDetailScreen` called Gouais Blanc "a grape that is not in this app and
  never will be"; all four are corrected.
- **F is one line and the arithmetic checks out.** Slovenia joins
  `ExpansionPacks.oldWorld`; membership was **265 -> 264 -> 265**, GODFORSAKEN
  grew 15 -> 16 on Gouais Blanc, `stats.countries` held at 26 because Slovenia
  has no region. All four verified against the shipped catalog rather than taken
  from the spec.

- **A. The orb is the lamp trio's width now, and the aspect stopped being
  authored.** `islandOrb` is `3 x islandStatusDot + 2 x statusDotSpacing` —
  79.44pt at SMALL, 86.30 at LARGE, against 35.2 / 40.48 before. Height is the
  authored axis at `controlButton x 0.234`, which is 0.55 / 2.35 multiplied out
  and therefore reproduces 0.7.8's 14.98 / 17.22 to two decimals; the aspect
  falls out at **5.30 (SMALL) / 5.01 (LARGE)**.
- **The clearance, re-derived at both scales as A2 asks.** On the narrowest
  island device the orb runs 32 → 111.4 (SMALL) and 32 → 118.3 (LARGE) against a
  cutout starting at 133: **21.6pt and 14.7pt**. Its slot, which is transparent
  padding, runs 28 → 115.4 and 28 → 122.3 for 17.6 and 10.7. **It fits at
  LARGE**, which the spec names as the stop-and-report condition. The trio's
  clearances are 22.1 and 15.2, within half a point of the orb's — not a
  coincidence, because `islandOrbInsetLeading` is now *derived* from
  `islandStatusInsetTrailing` so the two clusters mirror by construction rather
  than by two literals staying in step. That is the direct answer to 0.7.1's A4,
  which is a page about what happens when they do not.
- **Two metrics had to be split apart before any of this could be true.**
  `islandStatusDot` read `islandOrb x 0.60`, which became a cycle the moment the
  orb was derived from the trio; it reads `controlButton x 0.33` now, the same
  number by construction. And `islandSlot` was doing two jobs — the height of the
  notch-level row *and* the side of the orb's square hit box. At 79.44 wide that
  stops being harmless: the row would have become 87pt tall and `islandTopInset`
  would have floored to 8 and stopped centring the row on the cutout at all.
  `islandSlot` is the short axis now (still exactly 44) and `islandOrbSlot` is
  the wide one, which is A3's "the slot grows to contain the bead" spelled as
  two numbers instead of one.
- **The three miniature chassis were not optional collateral.** Workshop,
  Settings and Walkthrough each hand-set an orb width and divided the aspect out
  for the height — fine at 2.35, a 2pt hairline at 5.3. Each now derives its orb
  from *its own* lamp geometry through `DexMetrics.islandOrbWidth(lamp:spacing:)`,
  which is A1's rule stated once, and gives its rim a proportional width so the
  lit core stays the same fraction of the bead it is on the real chassis. The
  chassis's own `PulseGlow` moved from `width x 0.3` to `height x 0.7` for the
  same reason: at the new width the halo would have been 23.8pt around a 15pt
  bead. 10.5 / 12.1, within a tenth of a point of what shipped.
- **One error in the inherited comments, corrected.** `islandStatusInsetTrailing`
  said the trio's two components "both scale with `UIScale`". Only the lamp does;
  `statusDotSpacing` is `0.42 x rem` with `rem` a fixed 16. That is why the trio
  grows 8.6% between the scales rather than 15%, and it is load-bearing for the
  clearance table. (0.7.8's own note also has the LARGE trio at 85.4 where the
  arithmetic gives 86.3.)

- **E. Brazil and Mexico have outlines, and `OUTLINE_BACKLOG` is deleted.** The
  backlog carried its own instruction — "the list is meant to shrink to `[]`;
  when it does, delete it and the `known`/`missing` split with it" — so a region
  naming a place with no outline is now simply a build failure with no spelling
  that lets it through. `CoverageTests.regionsHaveOutlineArt` pins the empty set.
  **This is the only live user-visible defect the batch fixed**: R117, R118 and
  R098 resolved their art through a `guard let` and drew nothing.
- **The two silhouettes are script-rasterised, not drawn, and the deleted note
  said that would show.** It is the honest trade and it is recorded here rather
  than buried: the other 28 outlines are hand-drawn, these two are rasterised
  from authored lon/lat rings and given the set's treatment (flat fill, one-cell
  black cel outline, specular mark) at a comparable 212x216 and 216x144. They are
  recognisable and they are not of that set. **Worth an artist's eye.** The
  generator script is in the session scratchpad, not the repo — it is a one-shot
  over a master, like every other derived-sprite pass.
- **The projection is uniform in x on purpose.** `regions.ts` authors
  `mapPosition` as fractions of the outline's own canvas, and Serra Gaucha's
  (0.57, 0.87) and Campanha's (0.49, 0.92) both fall in Rio Grande do Sul on this
  projection — checked against the real bounding box before the art was drawn,
  because a non-uniform x scale would have moved both dots. R098 Valle de
  Guadalupe has no `mapPosition` and still falls back to the seeded hash walk;
  authoring one is a data call and is left for sommbot.
- **Madeira and Cava needed portraits and got recolours.** `styleArtWiring`
  requires one for every style but GSM Blend, and the spec did not mention it.
  `madeira` is `port.png` with the wine swung from ruby to rancio amber (same
  fortified flask); `cava` is `prosecco.png` with the gold pulled back to pale
  straw (same flute). Keyed on hue, so glass, cork and cel outline pass through
  untouched, and both keep white backgrounds so the normal strip/quantise pass
  applies and neither joins `MASTERS`. **Placeholders. Also worth an artist's
  eye**, and they are the second-weakest thing in the batch after the outlines.

- **D-a. The label matcher: 14 of 22 identifiable bottles before, 22 of 22
  after.** `LabelCorpusTests` is new and is the baseline the D-b/D-c decision was
  asked for — twenty-four hand-written labels, twenty-two that must be identified
  and two that must *not* be, scored as a rate with a floor rather than as
  twenty-four assertions, because a tuning pass that fixes four and breaks one is
  still a win and equality pins cannot say so.
- **Every one of the eight recovered bottles failed the same way**, and that is
  the finding rather than the fix. `LabelTextScan.phrases` only ever made windows
  *inside* one recognised line, and OCR returns one string per line of type — so
  a long appellation set over two or three lines (`CHATEAUNEUF` / `DU-PAPE`,
  `VERDICCHIO DEI` / `CASTELLI DI JESI`) could not be a candidate at any
  tolerance. All eight scored exactly 20: a producer guess plus a vintage, no
  place at all. Phrases now join across a line break, restricted to the shape
  type actually breaks in — a suffix of one line onto a prefix of the next,
  contiguous, three-line joins only when the middle line is consumed whole — so
  it is not a cross product of the label's words.
- **`maxPhraseWords` was wrong, and the way it was wrong is the lesson.** It
  read 4, with a comment asserting "four covers everything the catalog actually
  holds ... the longest real multi-word names top out at four". That was a claim
  about the *data* made in prose and never checked, and the data has moved four
  batches since: `Verdicchio dei Castelli di Jesi`, `Muscat Blanc a Petits
  Grains` and `Malvasia Branca de Sao Jorge` are five words folded, and all three
  were **unmatchable at any distance**. It is 5 now, and
  `phraseWindowCoversTheLongestName` fails the day a six-word name lands. The
  test is the point of the change as much as the fifth window is.
- **Prominence ranks now, and only as a tie-break.** The exact pass took the
  first hit in phrase order; it takes the best, ranked by word count, then
  `RecognizedString.prominence`, then unbroken-over-joined, then line order for
  stability. Word count outranks type size absolutely — the longest-window rule
  is what stops `Cabernet Sauvignon` resolving to `Cabernet` and it is not for
  sale. Geometry the matcher already had and was spending only on the producer
  guess.
- **The results screen has three states, not two.** `LabelReading.outcome` is
  `identified` / `ambiguous` / `unrecognized`, and `isConfident` is now defined
  *as* the first so the two cannot drift. The middle state is the common one: a
  French label naming a region the catalog holds and a producer it never will —
  the on-device matcher is structurally incapable of finishing that, because
  there is no producer entity — and telling the user NO MATCH while a list of
  candidates sat directly beneath it threw the work away. `shortlistCard` is cyan
  and points at the sections below; `noMatchCard` stays amber and points at the
  camera, which is the right advice for exactly one of the two.
- **What the number does and does not argue.** 22/22 says the local matcher
  identifies a well-set European label with an appellation on it essentially
  always. The remaining gap is not scoring, it is knowledge: a bottle stating
  only an estate is unidentifiable here at any tuning, and the corpus
  deliberately holds one as a bottle the matcher must *decline*. That is what
  D-b/D-c would buy. `LabelRecognitionProvider` was not touched, so both remain
  the one-line swap at the `LabelReaderViewModel` initialiser they already were.

- **C2. The tree's nodes are bigger, and the biggest tier no longer runs off the
  bottom.** `LineageTile` goes 96 -> 116pt with the art well and the name up a
  step each — at the old size a node in the tree was smaller than a plain
  related-entry row on the same screen. Every tier is capped at six with a SHOW
  ALL control, on the pattern HALF-SIBLINGS has used since 0.7.5, and that is
  what makes the enlargement affordable. **Checked against the case the spec
  names**: Gouais Blanc is G176 now and is named as a parent by ten catalog
  grapes, the largest node set in the app, which at the new width is four rows of
  unlabelled squares before the footnotes.
- **The unknown-parentage contract is settled in the UI, which is why the
  sequencing was inverted.** `GrapeLineage.parentageUnknown` is an authored
  claim that research has been done and no parent pair is established — the
  opposite of the silence 116 of 177 grapes carry, which means only that nobody
  has written them down. It decodes with `decodeIfPresent` and defaults to
  `false`, so every entry in the shipped catalog still decodes; nothing in
  `shared/` sets it yet and sommbot's C1 pass is what makes it visible.
- **It deliberately does not create a tree.** `GrapeLineage.isEmpty` ignores the
  flag, so a grape whose only content is "nobody knows" does not open a pedigree
  screen with connectors and tiers and nothing in them. It is collected *before*
  the `isEmpty` guard in `GrapeLineageIndex` so it stays answerable for a grape
  with no edges — which is the common case — and `connectedIDs` does not move.
- **Three renderings, one contract.** In the tree it is
  `LineageNode.Target.unrecorded`, a third enum case rather than a nil, so every
  `switch` has to answer for it: a dashed unfilled tile with a slashed-circle
  glyph, standing where a parent would, and only when fewer than two ancestors
  are authored — appending it to a settled cross would render a data
  contradiction as fact. On the entry screen a grape with the flag and no tree
  gets a stated line instead of silence, which is the one exception the 0.7.5
  argument against NO LINEAGE DATA leaves room for: that objection was to
  reporting an absence of *authoring*, and this reports a fact about the wine.
  A slashed circle and not a question mark, because `ContestedBadge` already owns
  the question mark and means "two sources disagree" by it.

- **B. WHAT'S THAT...? is a guessing game, and the door did not move.** Same
  TOOLS tile, same `DexRoute.dailyGrape`, same marquee, same `sparkles` glyph —
  all of those are vocabulary named by `DemoMode`, `ChromeTests` and the back
  handler, and renaming the case would have been churn in four files to describe
  a change none of them care about (the convention `scanner` has followed since
  it became BLIND TASTING in 0.7.1). `DailyGrapeScreen.swift` is deleted; every
  reference was found first.
- **The daily paper is untouched and was never at risk.** DAILY CHALLENGE on the
  same shelf is `TastingQuiz` + `StreakStore` and shares no store, seed or screen
  with this. **Where "grape of the day" went**: the answer is still
  `RevealCursor` stepping through a day-seeded shuffle, exactly as the reveal
  used it — two players opening it cold on one date get the same entry, each
  reopen deals the next. The thing that used to be revealed is now the thing you
  are trying to name.
- **All of it is in `VinodexCore`**, which is the house rule `OCRService:10-15`
  states and which this feature is the strongest argument for: a guessing game is
  almost entirely rules, and rules in a view are untestable on the only machine
  that runs the tests. `WhatsThatScreen` draws and nothing else.
- **The sufficiency property is enforced by construction, not hoped for.**
  `Clue.Kind.allCases` order *is* reveal order, vague to specific; `candidates`
  runs the same predicate that generated a clue back over the whole catalog; and
  `round(for:)` only returns a round whose full set leaves the answer alone.
  Seventeen tests, including "every clue is true of its own answer" across 120
  deals — a round can be uniquely solvable and still lie, and that is the silent
  partner of the property the spec names.
- **The selection is greedy from the *specific* end, and it had to be.** Filling
  the spare chips in reveal order spends them on the next-vaguest facts — tannin,
  rarity — and hits the six-clue cap before reaching the flavour and the region,
  which are the only clues that isolate a grape. Cabernet Sauvignon was the
  proof: eight clues available, six spent, still ambiguous, round refused. The
  chosen set is re-sorted into reveal order afterwards, so selection and
  presentation are different orders on purpose. **279 of 301** grapes and regions
  are playable; the shuffle walks past the other 22 rather than dealing something
  unwinnable, and the rate is pinned so "refuse everything" cannot pass.
- **The guess input goes through `LabelRecognitionService` and nothing was
  written twice.** The guess is handed over as a single `RecognizedString` —
  exactly what a provider returns for a one-line label — which buys accent
  folding, synonyms (`Steen` is Chenin Blanc), the length-scaled edit tolerance
  and the appellation-to-region link, all already tested. Only **non-inferred**
  matches count, and that restriction is the correctness argument: a reading
  walks the catalog, so naming a region yields its notable grapes and naming an
  appellation yields a country. Counting those would let a player win a grape
  round by naming any region that grows it, which is a guess *near* the answer
  rather than at it. `judgeIgnoresInference` pins it on Nebbiolo/Piedmont.
- **A wrong guess says what it was.** "THAT'S MERLOT — NOT IT" narrows the
  field; "no" does not. Unrecognised is a third, distinct answer, on the same
  reasoning as D-a's three-state result screen.

- **The one thing this batch could not do, and it is a real gap.** The version
  and changelog live in `shared/data/firmware.ts` (0.7.3a, F3) and the batch was
  instructed not to touch `shared/` — so **`firmware.json` still reads 0.7.8 and
  the app will report 0.7.8 for 0.7.9's work**. The instruction's stated reason
  is the race with sommbot's C1 pass on `entries.json`, which `firmware.ts` does
  not feed, but the constraint was honoured literally rather than reasoned
  around. The entry has to be added and `npm run generate` re-run before this
  ships.
- **The art importers are not reproducible across environments, and the 0.7.7
  note is wrong about why.** That note concluded the difference was the deflate
  stream only, and that decoded pixels matched exactly. Running
  `import-class-art.py` and `import-style-art.py` on Windows rewrote all 123
  tracked PNGs, and **11 of them differ in decoded pixels** — up to 84 pixels of
  42,300 with a max channel delta of 39, i.e. `Image.quantize` picking a slightly
  different palette across Pillow versions. Invisible, but `icons:verify`
  compares pixels, so it would fail on a machine other than the one that
  generated them. All 123 were reverted here (the four genuinely new files are
  untracked and survive). **Neither importer uses `art_common.save_stable`**;
  adopting it would stop the 112-file churn but not the 11-file quantiser drift.
- **vinodex-web is green on typecheck and on `coverage.test.ts`** (171->177,
  31->33, 438->446) **and red on `quiz.test.ts`**, which pins the shuffled option
  ids of seeded quiz questions and moves with any catalog change. Two tests, not
  caused by this batch — the web `shared/` mirror was already synced to sommbot's
  data before it started. Left for `paritybot`; re-deriving golden option ids is
  web scope.

**0.8.1, One missing table, one missing boundary, and thirty button faces**
(`horizon-md/vinodex-0.8.1.md`, sections A-F and H-J). **G held** and untouched
on the user's instruction: it is a `shared/data/styles.ts` reclassification and
therefore sommbot's. Run B first because it gates D, then the contained items,
then J. Gates: **590 tests**, clean `xtool dev build`, `npm run generate` +
`find-missing-refs` (zero dangling) + `icons:verify` (291 identical, 0 changed)
+ `outlines:check` green. **Not deployed** -- 0.7.9 and 0.8.0 are also still
undeployed behind the pending 27015 fix.

- **B was two faults, and only their intersection was visible.**
  `EntryDisplay.colorType` is a hand port of `getColorType` and had lost the
  entire override table -- all sixteen entries, every one of which names a real
  style exactly. Fifteen of the sixteen therefore fell through to `.dual`, which
  is what an un-overridden Champagne *should* look like if you did not know the
  table existed, so nobody could see them. The sixteenth was Prosecco, because
  the port also used `contains` where the TS uses word-anchored regexes and
  **"prosecco" has "rose" inside it**. One silent fault plus one loud one in the
  same function, and only the loud one got reported. The fix is the port restored
  faithfully (table first, then word-boundary keywords) plus
  `palette.styleColorTypes`: the generator writing down the *shared* answer for
  every style so `CoverageTests` can fail in **either** direction. Nothing reads
  it at runtime, and that is deliberate -- `WineEntry.tileChips` has no database
  in scope and the label scanner asks about names that are not in the catalog, so
  a port is the right shape here. A port is also what silently lost the table, so
  the two ends are now written down side by side.
- **F3 was not the bug the spec predicted, and the difference matters.** The
  brief expected 0.8.0's rose-chip shape -- a probe key disagreeing with a reader
  key. It is not: `flavorSubclassChips` has all 22 keys, spelled identically at
  both ends, and every lookup succeeds. `getFlavorSubclassChipColors` simply had
  no `case` for GAME, SAVORY, BREAD, SMOKY, SALTY or BRINY, and its `default`
  returns the exact triple `Palette.resolve` falls back to. **A successful lookup
  and a failed one were byte-identical**, on screen and in the JSON, which is why
  six grey chips read as a styling choice for six releases. `MARINE` was the
  tell: a coloured row for an id no code path can emit, sitting beside `BRINY`
  with none -- a rename that left the old row behind. So the pin is not "does the
  key resolve" but "is the answer distinguishable from no answer", and it also
  fails on any row emitted for an id the catalog cannot produce.
- **C3 was a real geometry bug, and three of them.** The crossbar's half-span was
  `min(width * 0.5, count * 46) / 2` -- 46 being near half the *96pt* tile 0.8.0
  replaced with a 116pt one, so it had been drawn to the previous tile size for a
  release and to a guess before that. But the bigger error was that the legs ran
  to `y = 0`, the tier's edge, and the tier put its caption (offspring side) or
  its SHOW ALL button (parents side) *between* the tiles and the trunk: the lines
  were meeting the right coordinate of the wrong view, 12 to 38pt short. And
  `FlowLayout` left-packed into a full-width bounds, so a lone parent sat at the
  left while the stem came down the middle. All three fixed together --
  `FlowLayout` gains an `alignment` (leading by default, so no chip row in the
  app moves), the tier puts labels on the outside and tiles nearest the trunk,
  and `Connector` repeats the tier's own packing arithmetic off `tileWidth` and a
  named `tierSpacing` to draw a leg to every tile on the adjacent row.
- **Three spec items were wrong about the code, and one of them is still open.**
  - **H1 as written is a no-op.** The four menu tiles' glyphs have been above
    their labels since they shipped -- a `VStack`, not an `HStack`. The item is
    the *marquee* panel's glyph, which 0.7.2's A3 moved beside the word on the
    main screen and which H1 asks back above it; the `glyphBeside` flag and its
    branch are gone rather than left passing `false`. **0.8.0's L fix is intact**:
    the 56pt box stays, and J3 is why it now matters more, not less.
  - **A's premise does not hold.** There is no shared miniature-chassis
    component for the shop to be a fourth caller of -- there are three
    independent drawings (workshop, settings, walkthrough) held together by two
    metric rules and by whoever remembers to change all of them, which is exactly
    how 0.7.9's A1 grew the orb in two and left the third. `ChassisMockup` is the
    settings tile lifted out whole, because it is the only one of the three
    already parameterised by a `ChassisSkin` rather than by the *current* skin.
  - **C2 is already built and cannot be reached.** `parentageUnknown`,
    `LineageNode.Target.unrecorded` and the dashed slashed-circle tile all
    shipped in 0.8.0, in the tree *and* on the detail screen. No grape carries
    the flag: `shared/` emits it nowhere, and `GrapeLineageTests` pins that. So
    C2 needs a **data** pass deciding which varieties research genuinely calls
    unparented -- a sourced wine claim, and sommbot's. **Not guessed at**, and
    absence of authored parents was deliberately *not* treated as a claim of
    unknown parentage: `unknownParentageIsDistinctFromUnauthored` exists to stop
    exactly that. C1 was the real bug and is fixed.
- **A1's literal is not restored, on purpose.** The prior value was a hand-set
  `width: 10`, and 0.7.9's own comment records why it stopped being viable --
  at today's `islandOrbAspect` it measures a 1.9pt hairline. What 0.7.9 got
  wrong was not using the rule but feeding it the *chassis's* 10pt lamp, so a
  rule that spans a trio produced an orb 3.6x the single light beside it. It now
  takes the mockup's own part scale (3pt, the marquee strip's height in the same
  tile) and lands at 11 x 3 -- within a point of the 10 x 4.3 the tile drew
  before 0.7.9, with every proportion the chassis states preserved.
- **I2 layers on 0.7.2's rule rather than replacing it.** `idleCount` still sets
  where an idle period opens, so consecutive idles do not all start on CHEERS!
  and every existing test stays green; what is new is that a period is no longer
  one word long. `MarqueeCheers.steps(in:)` is pure and lives in Core; the view
  supplies elapsed time from `screensaverSince`, which is *already* the instant
  the toast began (`IdleSchedule.cheers` resolves to `IdleSchedule.screensaver`),
  so the words and the bouncing mark cannot keep two reckonings of one idle. The
  invalidation is `TimelineView(.periodic)` -- a clock, not a timer -- mounted
  unconditionally so the banner keeps its identity and an arrival at CHEERS!
  stays a dissolve instead of becoming a remount.
- **J is 30 of 32 placed, and the two left over are named.** `numberedstack` has
  no button anywhere -- its only plausible target is the DATA panel's TOTAL
  ENTRIES hero, which is a statistic, not a control. `user` has a home (the
  chassis USER button) but that control already carries a skin-override art path
  (`SkinMarkView`, HALLOWEEN's pumpkin), and a second art mechanism on the one
  glyph a skin may replace is a fight worth having deliberately rather than in
  passing. Everything else is wired: the four menu tiles, the six tools tiles,
  five settings feature tiles, eight settings rows, the chassis BACK / HOME /
  gear, the search shell (which converts five screens at once), PASSPORT, both
  edit pencils and the label reader's camera.
- **The box is what makes J safe, and it is the same box as 0.8.0's L.** The 32
  faces run from 0.62 to 1.88 aspect, and roughly 150 call sites size a symbol
  with `.font(.system(size:))` and no frame -- so an in-place raster swap would
  have re-broken every alignment in the app, silently, one control at a time.
  `DexChromeGlyph` never lays out at the art's size: it fits the art inside a
  square and letterboxes the remainder, so a row of them is aligned whatever is
  drawn in them. It also falls back to the SF Symbol whenever there is no PNG,
  which is what lets the conversion be partial without any control going blank
  and what makes a mistyped stem degrade to the icon that was there before.
- **Two shared-data observations, neither actioned.** Madeira resolves to DUAL
  at both ends -- it has no override row where Cava (added in the same data
  batch) does. Defensible for a wine made from four white varieties and one
  red-skinned one, but it is an omission rather than a decision, and it is a
  sommbot call. And the REGIONS menu tile wears `globe.americas.fill` while
  `EntryCategory.regions.marqueeSymbol` is `map.fill`; J gave the tile the
  `regions` face and left the marquee alone, so that disagreement is now visible
  in two media rather than one.

**0.8.0, Thirty new outlines, a reproducible art pipeline, and eleven fixes**
(`horizon-md/vinodex-0.8.0.md`, sections A-L). Run in the spec's own order --
D, H, K, I, L, J, F, G, B, E, C, then A -- so a partial batch would still have
shipped most of the value. Three commits: the eleven cheap items, the A0b
pipeline fix on its own as the spec required, then the art. Gates: **582 tests**,
clean `xtool dev build`, `npm run generate` + `find-missing-refs` (zero dangling)
+ `icons:verify` (259 identical, 0 tolerated) all green. **Not deployed** -- the
usbmuxd port race is still pending an elevated command and is unrelated to this
work.

- **A0b was the whole gate and it was worth the commit it cost.** Six importers
  called `img.quantize(colors=256)` and took three unnamed defaults: the method
  (Pillow resolves it *by mode*, so FASTOCTREE has been the effective choice by
  accident rather than by contract), the dither, and the fact that a reduction
  runs at all. `art_common.quantize_stable` pins the first two and skips the
  third when the source already fits the palette -- which is the clause section A
  needed, because a three-colour outline now never meets a quantiser and is
  therefore identical on any Pillow rather than identical by inference about an
  octree. `save_stable` went from one importer to all seven and gained
  `**save_kwargs` so `optimize=True` survives. Proof: the first run rewrote
  exactly the 16 files already in `verify-art.py`'s `TOLERANCE`, all inside their
  budgets; the second wrote nothing at all.
- **What A0b did *not* fix, measured rather than assumed.** **301 of the 307
  drawn sources carry more than 256 distinct colours** after background removal,
  so the reduction is genuinely lossy for nearly the whole bundle and cannot be
  skipped -- shipping it unreduced was costed at roughly 13MB against the current
  2.5MB. For those the octree still chooses, and different builds choose
  differently. `TOLERANCE` stays and is now dormant on this machine rather than
  deleted, because dormant here means live on the machine that measured it.
  Closing it properly means supplying the palette instead of asking for one;
  that is a real option and it is written down in `verify-art.py` rather than
  done quietly. **The 0.7.9 note that said the difference was "the deflate
  stream only" was already corrected by 0.7.9 itself; this batch adds the
  reason the pixel half exists.**
- **A1. All thirty outlines are derived, and the script is in the repo with its
  rings.** `scripts/country-outline-rings.py` holds the authored lon/lat and the
  flag-derived fills; `scripts/make-country-outlines.py` rasterises them.
  0.7.9's "it is a one-shot over a master" was true while 28 were hand-drawn and
  stops being true the moment all 30 come out of a script -- there is no other
  master now, so it ships, with `npm run outlines` and
  `npm run outlines:check`.
- **The projection is uniform in x, and the cosine is spent on the canvas
  aspect.** `x = (lon-lonMin)/dlon` with one scale for the whole canvas; a
  `cos(lat)` term *inside* the mapping would move every dot by an amount varying
  with its distance from the country's mid-latitude and nothing would report it.
  The aspect is `dlon * cos(midlat) / dlat`, which reproduces 0.7.9's two
  canvases (Brazil 212x216 against a derived 0.974) and keeps a country from
  looking stretched. Cells then an integer upscale, which is the shape 0.7.9's
  masters were already in -- 212x216 is 106x108 at 2x -- so one cell is one
  authored unit and the cel outline is exactly one cell. **No specular mark**,
  removed from Brazil and Mexico too.
- **The dot audit found eight broken dots, and only two of them were this
  batch's doing.** `--check` resolves every authored `mapPosition` against the
  new silhouette; a baseline run against the *old* committed sprites established
  that **8 of 121 were already in the sea** (Margaret River, Niagara Peninsula,
  Okanagan Valley, Santorini, Calabria, Marlborough, Canary Islands, Mallorca).
  The first draft of the rings put 12 off: six of those eight, plus six
  regressions. Every regression was a defect in a ring and was fixed in the art
  -- **Corsica** (France was mainland-only; the hand-drawn master plainly had the
  island, because R041's dot sat on it), **Sonoma** (the Mendocino coast was cut
  straight from San Francisco to Cape Mendocino), **Friuli-Venezia Giulia** and
  **Collio** (the Alpine crest and the Gulf of Trieste), and **Shandong** and
  **Guerrouane**, which turned out to be the next category:
- **Seven `mapPosition` values were simply wrong and are re-authored.** Once the
  bboxes were real, the fractions could be resolved to real coordinates, and
  seven of them named open water: Margaret River resolved to (117.21, -37.05) in
  the Southern Ocean, Okanagan Valley to (-127.74, 47.20) in the Pacific,
  Shandong to (121.29, 34.11) in the Yellow Sea. They are recomputed from the
  places themselves in `shared/data/regions.ts` -- R042, R048, R075, R069
  Okanagan, R097 Guerrouane, R081 Calabria and R047 Mallorca. **This is the one
  data change in the batch and it is a correction, not an addition.**
- **The Canary Islands cannot be drawn and the check says so out loud.** Gran
  Canaria is at (-15.60, 28.05), which on Iberia's bounding box is the fraction
  **(-0.49, 2.07)** -- not slightly wrong, off the canvas. Drawing it means
  taking Spain's longitude span from 12.8 degrees to 22.5 and rescaling every
  other Spanish dot to fit one. It was in the sea on the hand-drawn art too. It
  is named in `OFF_MAP`, which fails **both ways** like `assertOutlineCoverage`:
  a dot that starts landing on land has to come out of the list. The honest fix
  is an inset in `CountryOutlineMap`, which is a code change rather than an art
  one, and is not this batch's.
- **Three shapes needed a second pass and are recorded because the next reader
  will want to know which.** Greece came out a hollow crescent (the Aegean side
  traced too far west), India a four-pointed star (the Konkan run as a chord and
  Gujarat as a spike), Croatia a fat arrow (the Bosnian wedge filled in, which is
  the thing that makes the boomerang a boomerang). All three were re-traced.
  **The set is still worth an artist's eye** -- these are authored from
  geography, not drawn, and 0.7.9 said the same of its two.
- **`ArtPipelineRosterTests` gained the fifth roster.** The generator is *not* an
  importer -- it writes sources under `art/` that `import-class-art.py` then
  converts -- so it is outside the four `import-*-art.py` rosters by
  construction, and the test says so. What it does check, both ways, is that
  every stem in `countryShapeIcons` has an authored ring and every authored ring
  is drawn, plus that each master exists on disk. A thirty-first country now
  fails `swift test` rather than failing an importer on somebody's laptop.

- **K was a bug, not a colour.** The generator probed `colorTypeChips` with
  `'ROSE'` (accented) while every reader looks up `StyleColorType.rose.rawValue`,
  which is unaccented on both the TypeScript and the Swift side.
  `getColorTypeChipColors` answers to either spelling, so the table was full, the
  colours were right, and one of five rows was unreachable -- every rose style
  fell through to `Palette.resolve`'s neutral stone. **Identical fault and
  identical tell to 0.6.9's I1** on the grape colour chip: the chip said ROSE and
  was grey, which reads as a styling choice rather than as a miss.
  `CoverageTests.chipKeysResolve` now pins the *join* for colour types, style
  classes and rarities, because `count == 5` stayed green through the whole
  thing.
- **L was not a padding bug in two tiles.** `Image(systemName:)` lays out at the
  symbol's own bounding box, so `wineglass.fill`, `leaf.fill`,
  `circle.grid.3x3.fill` and `globe.americas.fill` at one point size are four
  different heights and four labels land at four different y positions. The two
  near-square glyphs agreeing with each other is what made it look like a fault
  in the other two. A fixed 56pt glyph box fixes all four and the fifth tile
  anybody adds.
- **H, and the half of A3's argument that was wrong.** A3 declined a minute with
  "a burn-in guard that waits a minute is a burn-in guard for a phone in a
  pocket". The premise is right -- nothing dims this screen -- but iOS dims and
  locks the *device* regardless of what `ScreenWake` pins, so this constant was
  never the burn-in guard; it is the device going idle in character, and thirty
  seconds was still inside the time it takes to read a region's soil block.
  A4's fold means one edit moved the marquee's greeting with it, which is the
  proof the fold was worth doing. `IdleTimerTests` now pins the value in exactly
  one place and derives every other assertion from it.
- **B5's ceiling is arithmetic, not taste.** `PressStart2P` advances a full em
  and the LCD's content box is 329pt at the HUGE text step, so each retro
  string's maximum nominal size is `329 / characters / 1.15`. Worked through:
  the tagline can reach 11 (328.9 of 329), the bar labels 11, the wordmark 39.
  **The prompt cannot move at all** -- PRESS ANY BUTTON TO CONTINUE is 28
  characters, ceiling 10.2, and `TypeScale.nominalFloor` already lifts its
  authored 9 to 10. It is rendering at its ceiling today, and any larger number
  would be a string riding `minimumScaleFactor` to fit, which is exactly what
  0.7.5's A6 forbids. So B5 reaches every element on that screen except the one
  that was already as large as it is allowed to be.
- **E2 is E2-a, with two clauses of the recommendation deliberately dropped.**
  The pool is entries the player has met -- the three `BookmarkStore` shelves
  plus `RecentlyViewedStore` -- and there is no general "discovered" ledger in
  this app, so those four are the honest approximation and they are already on
  disk. The two dropped clauses:
  - *"Never from the answer's own category"* **would disable the feature.** Clue
    1 of every round says IT'S A GRAPE or IT'S A WINE REGION, and those are the
    only two categories a guess can usefully be in. Suggestions are restricted to
    exactly those two instead, which is the opposite rule and the useful one.
  - *Excluding the answer itself* **would be an oracle.** A player who has met
    Nebbiolo, types `NEBB` and gets nothing back has been told which entry is
    being withheld. Silence is information. Nothing is filtered on the answer.
  The hard requirement the spec states is kept and tested: a single character
  returns nothing **even when the caller passes the whole catalog**, which fails
  on the gate rather than on the pool happening to be small.
- **C1's figures differ from the spec's, because of a floor.** The spec gives
  14.98 -> 21.12 and an aspect of 3.76, which is `controlButton x 0.33` without
  its floor; `islandStatusDot` is `max(controlButton x 0.33, 22)` and **at SMALL
  the 22 binds**. So the bead is 22.00 at SMALL and 24.29 at LARGE, and the
  derived aspect is 3.61/3.55 rather than a flat 3.76 -- the same floor that
  already makes the aspect differ between the two scales. Confirmed rather than
  assumed, as the spec asked: no horizontal number moved, `islandSlot` is
  `max(height + 8, 44)` and 30 still floors to 44, so 0.7.9's clearance table
  needed no re-deriving. **The rim is the thing to eyeball**: `max(height x 0.11,
  2)` was on its 2pt floor at 14.98 and is 2.42 at 22, so the coloured core goes
  from 10.98 to 17.16pt.
- **C2 overturns a four-batch-old argument, and the argument is kept.**
  `DeviceChassis.orbShape` carried a paragraph on why the orb must never go
  through `RecessedLamp` -- it draws a part recessed, the orb is a bead standing
  proud, and seating it would invert the lighting on the one part meant to catch
  the light. Every clause is still true of a *bead*. It stopped being one: A1
  made it the trio's length and C1 makes it a lamp's height, so two parts in the
  same row at the same scale were lit two different ways, which reads as one of
  them being wrong. The rim tone is `skin.orbGlow`, the deeper of the orb's two
  colours, which is the relationship the lamps' `(fill, border)` pairs already
  have -- no twenty-one-shell table was invented. The three miniature chassis
  follow through a new `DexMetrics.islandOrbHeight(lamp:)`, which states the rule
  once the way `islandOrbWidth` already did; they were dividing their own width
  by the *chassis's* aspect, which C1 turns into a number about nothing.
- **F: every remaining "paper" is accounted for.** Eleven player-facing strings
  changed across `WineExamScreen`, `TastingQuizScreen`, `NotificationPlan`,
  `SettingsPanel` and `ExamAssemblyFailure.message`. What is left under
  `Sources/` is: **identifiers** (`ExamPaper` and everything built on it,
  `stats.papers`, `stats.perfectPapers` -- 0.7.5's D1 precedent, the door keeps
  its name), **doc comments** describing them, and **one string that is not the
  exam at all** -- `Entitlements.swift:141`'s "paper-white", which is an LCD
  colour. `firmware.ts`'s shipped notes are untouched; the 0.7.8 and 0.7.9
  entries still say "paper" because that is what those releases said.
- **J's placeholder is derived, not passed.** `EncyclopediaListScreen` already
  holds `categories`; a `placeholder:` argument at the call site would be a
  second statement of something the screen knows, and the two call sites in
  `VinodexApp` would eventually disagree with the header above them. Multi-
  category resolves to SEARCH WORLD, which is the globe button's own wording, so
  the button and the field it opens read as one control -- the globe's ellipsis
  became U+2026 to finish that.
- **One thing to eyeball beyond the outlines**: the BIOS screen at the HUGE text
  step. The tagline lands at 328.9pt of 329 by arithmetic, which is inside the
  budget without touching its scale factor but has no margin at all.
- **Known flake, not a regression.** `TypeScaleTests.seedRunsOnce` failed once
  during the batch under the full parallel run and passed three times in
  isolation immediately after, and again in every subsequent full run. It touches
  `UserDefaults(suiteName:)` on corelibs-foundation and nothing in this batch
  goes near `TypeScale`. Worth watching rather than chasing.

**0.8.3, Four things leave the shop and nothing leaves the dex**
(`horizon-md/vinodex-0.8.3.md`, sections A-H). Gates: **601 tests**, clean
`xtool dev build`, `npm run generate` (no drift) + `find-missing-refs` (zero
dangling) + `icons:verify` (312 identical, 0 changed) + `outlines:check` green.
**Not deployed** -- 0.7.9 through 0.8.2 are also still undeployed, though 0.8.2
was put on the phone and tested before this branch was cut.

- **D's reconnaissance did not survive contact, and that is the finding.** The
  spec said "remove flavorwheel, Italy pack, France pack and Spain pack", warned
  that `ExpansionPacks.all.count` is pinned at 12, and pointed at
  `FREE_COMMON_ORIGINS`. None of those three is where the packs are. There is no
  flavorwheel `ExpansionPack` and no country `ExpansionPack`: the twelve are
  three atlas, six device and three display, and all twelve stay. The four
  things being removed are `Entitlement` rows in `SettingsPanel.shopUpgrades` --
  `.flavors`, plus three `.country(_:)` bundles that **nobody named**. A
  `topCountries` helper counted region entries per origin and took the largest
  three, which is Italy (21), France (19) and Spain (19) *today*; a data batch
  adding four Portuguese regions would silently have changed which packs the
  shop sold. That helper is gone with the rows, and `all.count == 12` and
  `FREE_COMMON_ORIGINS` are both untouched.
- **Retired, not deleted, and the two invariants are pinned separately.**
  `Entitlement.id` writes `"country:France"` into `grantedEntitlements`, and
  `LocalEntitlementStore` reads it back through `init(id:)` and `compactMap` --
  so deleting the cases would not have crashed, it would have dropped somebody's
  purchase in silence, which is worse. The cases stay, parse, and cover exactly
  what they always covered; `AccessTests.retiredGrantsSurvive` writes the raw
  strings into a defaults suite and asserts every French entry and every flavour
  still opens. What changes is only what can be *sold*:
  `LocalPurchaseProvider.canPurchase` refuses a retired bundle, so a second
  surface listing products cannot resurrect a row.
- **The orphan the item is actually about is `offer(for:)`, and it was two
  lines.** That function chose what the paywall prompt sells: flavours got the
  flavour wheel, anything with an origin got its country. Remove those from the
  shop and leave `offer` alone, and every locked French grape raises a prompt for
  a product with no storefront behind it -- content gated by an id nothing sells,
  verbatim. It collapses to `.pro`.
  `AccessTests.everyEntryHasABuyableOffer` is the gate, and it replaces a test
  that would have passed straight through the failure: the old one asserted the
  offer *covers* the entry, which a retired bundle does perfectly well. It now
  asserts covers **and** purchasable, over all 446 entries rather than only the
  locked ones.
- **Worth recording what was deliberately not done.** The free tier is
  unchanged. The temptation was to widen `tiers.json` so the retired bundles'
  content becomes literally free, and it is the wrong trade: it would move
  roughly 160 entries into the starter tier, widen `DailyPick`'s pool, and
  rewrite a product decision nobody asked about. The reachability argument does
  not need it -- `AccessStore.isLocked` returns `false` outright unless
  `starterOnly` is set, that switch is a developer control off on every real
  install, and **23 of the 26 country bundles were already unlisted**. The three
  being removed join the twenty-three; they do not form a new class.
- **C4's flagged risk was measurable, and the measurement inverted it.** The
  worry carried from 0.8.2 was that `chassisskins`, `screenmodes` and
  `vinodexpro` ship at 418x564 against the other fourteen's ~225x302, so the
  label well would not be in the same relative place on all seventeen. Measured,
  it is: the well spans y 0.813-0.934 and x 0.105-0.888 on **every one of the
  seventeen**, large files included. They are the same drawing at twice the
  resolution. What does vary is the **aspect ratio**, 0.678 (`vessel`, `wines`)
  to 0.798 (`godforsaken`), and `.aspectRatio(contentMode: .fit)` letterboxes --
  so a fraction of the *tile* would have landed in the well on whichever sprite
  the numbers were tuned against and progressively outside it on the rest.
  `PackCartridge.labelWell(for:in:)` computes the rect off the fitted image and
  adds the letterbox offset back, which is why it takes two sizes.
- **The "file icon behind the pack" is `CartridgeShape`, and it is not one
  component.** E said "if the backing icon is one component, delete it once", and
  it is one *shape* in two unrelated roles: `DexPickerTile`'s stroked border
  around the swatch (a stepped-corner square around a cartridge drawn to fit
  inside it, which is exactly what reads as a file card behind the pack), and two
  ghost plates fanned behind the splash hero. Two edits. `DexPickerTile.outline`
  became optional rather than gaining a `showsOutline` flag, so the shop's call
  site says `CartridgeShape?.none` instead of passing a shape it then suppresses;
  the workshop's colour chips are flat fills with no edge of their own and keep
  theirs.
- **B1 was art and could not have been code.** The four caps' cast shadow is
  painted into the sources as the magenta chroma key **at half value** --
  (128, 12, 102) against the key's (239, 4, 225) -- and `strip_background` keys
  out only the pure form, so it survived import as a dark plum blob.
  `ChassisButton` carried a comment explicitly declining to draw one
  (`// No .shadow: the sprite casts its own`), so there was no SwiftUI change
  available. `strip_key_shadow` in `import-footer-art.py` keys on **chroma**
  rather than on darkness, which is what makes it safe: a shadow pixel sits on
  the key's hue at any value, and every cap pixel is either cream (a green
  channel far too high) or the near-neutral black of the cel outline (a green
  channel level with the other two). 27,885 pixels cleared across four caps;
  rim, lit face, internal shading and incised symbol all intact. The correction
  lives **inside** the importer, so a re-import keeps it.
- **A and H are one mechanism with a parameter, which is what the spec asked
  for.** `DexRoute.marqueeArt` is a new Core table beside `marqueeSymbol` --
  separate rather than a rename, because `ChromeTests.glyphsAreDistinct`
  requires symbols to be unique and the art deliberately repeats (a category
  listing and its detail pages want one picture). `MarqueePin.artStem` reads the
  same table, so both marquee surfaces resolve through it. The treatment is then
  `DexChromeGlyph.flatten`: non-nil renders the face as a `.template` silhouette
  in one colour (A, black), nil keeps the drawing (H, coloured). Neither can leak
  into the other, because it is an argument at the call site.
  `ChromeTests.marqueeArtIsOnDisk` walks every stem against
  `art/icons/buttons/`, which is the only thing that can tell "not converted
  yet" from "converted, string wrong" -- both render as the old SF Symbol.
- **The ink rule A asked about does not fight black on any skin.** The marquee's
  ink is `skin.marqueeShadow` and its ground is `skin.marqueeText`, and all
  twenty-one grounds are lit colours -- the dimmest is CLASSIC's `green500`. A
  black silhouette is the highest-contrast mark available on every one, so no
  skin is exempted because none needed to be. The `ink` fallback stays for the
  sixteen routes with no drawn face: recruiting those into the flat treatment
  would have changed pages A does not name.
- **F was finishing, and the finishing found the bug.** `ScreenMockup` shipped in
  0.8.2 as a *reduction* of the CUSTOMIZE card -- bezel, ground, accent bar,
  three body lines, no glyph, and no `.grayscale` / `.colorMultiply` pass. That
  last omission is the real defect: AMBER, VINTAGE, TERMINAL and GRUENER BOY are
  built by greying the dark theme and multiplying by one phosphor, so the shop
  was previewing the RETRO pack's screens **in green**. Rather than adding the
  pass, `ScreenMockup` *became* the card and `modeGrid` now calls it, so "exactly
  as it appears in Customise" is true by construction. Both surfaces gained
  `ownInk` over `text` on the way -- `text` returns the workshop's chosen font
  colour, so the picker had been showing every mode in one ink whenever one was
  fitted.
- **G factored, as 0.8.0's G2 predicted it would.** `attributeBar` took a third
  caller with no change: same flag well, same label-over-value, same chevron. The
  one thing this caller does that the other two do not is *not appear* -- a style
  whose origin is "various" has no country to name.
- **Two smaller spec corrections.** The footer caps go through
  `import-footer-art.py`, not `import-button-art.py` as B says -- 0.8.2 split the
  two deliberately, and three of the four stems (`home`, `settings`, `user`)
  already exist under `buttons/` as different pictures. And the press feel: the
  cog was `DexPressStyle(scale: 0.9)` and the other three `0.96`, so B2 is not
  adding a depress to parts that had none but replacing two shallow ones.
  `ChassisPress` now holds the orb's three numbers once, and the orb, the three
  caps and the cog all read them -- which retires 0.6.7's "the cog presses deeper
  than its neighbours" exception by overtaking it.
- **Things to eyeball, in order.** (1) The pack splash -- the cartridge is 260pt
  now against 168, the name is printed in the sprite's own label well at a fixed
  `#2B2118`, and CHASSIS SKINS / GRAPE LINEAGE at thirteen characters are the
  longest strings it has to hold. (2) The marquee page glyph as a flat black
  silhouette: a template render discards internal detail by design, and `grapes`
  (a bunch with a leaf) and `regions` are the two whose silhouettes carry the
  most. (3) The two marquee lamps in full colour -- five faces sitting on lamp
  faces that are themselves saturated, on a skin like CHRISTMAS whose trio is
  three identical berries. (4) The four footer caps with no shadow and a 0.88
  depress, on a light shell and a dark one. (5) The shop shelf at 58pt with no
  outline around the tiles.

**0.8.2, A hundred and two new statements about parentage, and twenty-one drawn
parts** (sommbot's data-pass handoff, plus five coordinator items). Gates:
**596 tests**, clean `xtool dev build`, `npm run generate` (no drift beyond
sommbot's three regenerated resources) + `find-missing-refs` (zero dangling) +
`icons:verify` (312 identical, 0 changed) + `outlines:check` green. **Not
deployed** -- 0.7.9 through 0.8.1 are also still undeployed.

- **Three things in the handoff were wrong, and the first one mattered.** It
  said `derivedOnlyGrapesAreConnected` "CANNOT be fixed by swapping grapes" and
  should be retired with a written reason, because "after this pass there are
  zero grapes connected only by derived edges -- the category is empty." The
  category has **fourteen** members: Nebbiolo, Zinfandel, Grenache, Trebbiano,
  Touriga Nacional, Palomino, Teroldego, Primitivo, Savagnin, Garganega,
  Graciano, Hondarrabi Beltza, Pais and Gouais Blanc. What emptied was the set
  of grapes with **no lineage block at all** that are connected -- a different
  set, because the test's `g.lineage == nil` was a *proxy* for "authors no edge"
  and this is precisely the batch to break it: all fourteen now carry
  `{ parentageUnknown: true }`, a block that states an absence and authors
  nothing. So the assertion is now `lineage?.isEmpty != false` -- the same
  predicate `GrapeLineageIndex` uses to decide what goes in `authored`, so the
  test and the code read one rule instead of two that agreed by luck -- and the
  subject is derived rather than named, which is what 0.7.9 already had to do to
  the neighbouring `unconnectedGrapesAreEmpty`.
- **The handoff also missed a red test and over-reported another.**
  `siblingsGroupThroughExternalParents` was failing at 9 vs 12: sommbot gave
  Gouais Blanc three more children (Xinomavro, Romorantin, Jacquere), taking it
  from 10 to 13 and making it the only count in the suite that moved on new
  *crosses* rather than on new statements. And `colorOverridesResolve` was said
  to fail; it never did -- it iterates the table, so a seventeenth row passes as
  readily as sixteen. Only its **title** was wrong, which is the more interesting
  fault: the title asserted a number that nothing read. It reads 17 now and the
  test counts the table, so the title cannot lie again.
- **Two numbers, and the gap between them is the whole character of the pass.**
  Blocks 61 -> 163, connected 75 -> 121. It is not 102 new crosses: 56 of the new
  blocks carry `parentageUnknown` and no edge, which adds a *statement* without
  adding a relationship. 163 grapes now say something about their parentage; 121
  have a tree. `coverageIsPinned` pins the split as well as the totals, on the
  standing rule that a pin which can be right while the distribution is wrong is
  not proof -- both totals survive a batch that turned every stated absence into
  a phantom edge.
- **Verified what the new data actually draws, by tracing the two branches
  against all 177 entries.** 121 get the FAMILY TREE button, **42** get the flat
  PARENTAGE UNRECORDED panel, 14 draw nothing. Of the 121, **32** carry the
  `.unrecorded` tile inside the tree. Both branches shipped in 0.7.9 against a
  catalog that set the flag nowhere and stayed unreachable through 0.8.0 and
  0.8.1; this is the first batch in which either has a user. Off-catalog
  ancestors went from a handful to **69 distinct**, the largest being Heben with
  nine children, so 0.8.1's terminal-node box is also newly load-bearing.
- **One case the data still does not reach, and it is the one the schema
  advertises.** `shared/types.ts` says a grape may have "one established parent
  and a second that is genuinely unrecorded, which is what draws a named tile and
  an unrecorded one side by side", and `GrapeLineageScreen`'s
  `authoredAncestors.count < 2` guard exists for exactly that. **Zero** grapes
  are in that shape: all 32 tile-drawing grapes have *no* authored ancestors. The
  half-known cross remains fixture-only (`unknownParentageCoexistsWithEdges`).
  Worth a sommbot pass rather than a code change.
- **The `related` de-dupe was a live defect, not a hypothetical.** `relatives(of:)`
  built `related` as authored + derived with no `seen` set, unlike `siblings` two
  lines above. Both copies get `LineageNode.id == "e:<id>"` and the screen's
  `ForEach` is keyed on it, so a mutually-authored pair would have given SwiftUI
  two rows with one identity -- a dropped or doubled row somewhere else in the
  list, which a reader would have blamed on the tree. 0.8.2 is also the batch
  that landed the **first in-catalog `related` refs at all** (five: Cabernet
  Franc/Hondarrabi Beltza, Mourvedre/Graciano, Roussanne/Marsanne, Plavac
  Mali/Zinfandel and /Primitivo), so the reverse pass went from unexercised to
  live in the same pass that could have tripped it.
- **The footer art is not what the item described, and the art won.** The
  instruction was to wire four files through 0.8.1's `DexChromeGlyph` path and
  "keep the SF Symbol fallback per glyph". They are not glyphs: each is a **whole
  moulded cap** -- rim, lit face, cast shadow, symbol incised into it. Drawing
  one inside `ChassisButton`'s gradient circle would have stacked a painted
  button on a rendered one at two rim radii. So the sprite replaces the control,
  and the fallback is the *entire existing rendering* -- which honours the
  instruction's substance exactly: no art, and every skin renders what it
  rendered in 0.8.1. `user` was one of the two 0.8.1 could not place, because the
  User button goes through `SkinMarkView` rather than `DexChromeGlyph`; it has a
  home now.
- **"Tint with the chassis skin" needed a new mechanism, and three obvious ones
  were wrong.** One cream cap, twenty-one skins whose identity is largely these
  four colours. `.renderingMode(.template)` discards everything but alpha and
  collapses a moulded cap to a disc. `.colorMultiply` -- the LCD's own idiom --
  only darkens: a no-op on the eleven skins with a white glyph, and it crushes
  the light ones. `DexChromeGlyph`'s no-tint rule is right and stays untouched.
  What works is **0.6.2's rule, from `GrapeSpriteLoader` and the rarity leaf**:
  keep each pixel's value, take the target's hue and saturation. Measured first
  -- all four sprites are a single hue family (0.05-0.16) spanning the full value
  range, so there is no second hue for a global re-hue to destroy, which is why
  this needs none of `GrapeSpriteLoader`'s masking. Near-black is skipped so the
  outline and the cast shadow stay structure. `ChassisCapLoader` sits *on top of*
  `PixelArtLoader` keyed additionally by ink, so **no `art:` id or `ClassArt`
  asset becomes tintable as a side effect** -- the tinting is reachable from two
  chassis call sites and nowhere else. Withheld from the sketch shell, whose
  parts are pen strokes and which had its cast shadow deliberately removed in
  0.6.6.
- **Ten importers now, and the roster suite earned its keep twice in one batch.**
  `import-footer-art.py` and `import-cartridge-art.py` each had to be added to
  `rasterize-icons.sh`, `verify-art.py`'s `IMPORTERS`, its `DIRS` and
  `package.json` -- eight edits nobody would infer from "wire up some new art",
  and `ArtPipelineRosterTests` is what turned that from memory into a check.
  There is a **fifth** place it cannot see -- `PixelArtLoader.subdirectories`, in
  `VinodexUI` -- and only the clean build covers it, because a directory the
  loader never searches yields a nil image and nil images are silent. Both new
  stem sets are **prefixed** (`footer-`, `cartridge-`), joining `stamp-` and
  `sticker-` as safe by construction rather than adding a second bare-word
  directory to the ordering argument `ButtonArt`'s note had to make.
- **The cartridge mapping is a table because both vocabularies are load-bearing.**
  17 files, 12 packs and 5 upgrades. Three rows genuinely disagree and all three
  are pre-existing documented collisions: `displayvintage` -> `pack:display-retro`
  (0.7.1's C1 renamed the section to avoid VINTAGE-containing-VINTAGE, and
  `LcdMode.vintage` is persisted), `screenmodes` -> `lightMode` (the id is
  persisted and `Entitlement` says renaming it revokes the purchase), and
  `godforsaken`, where the file arrived as `godforksaken.png` and was **renamed**
  rather than mapped -- a typo in a filename is a typo, a typo in a table is a
  permanent second spelling. Nothing in the tree referenced the misspelling.
  `CartridgeArtTests` fails both ways: a stem with no file, and art nothing
  claims.
- **Two things on sale have no cartridge, and this is the report the item asked
  for**: `flavors` (the flavour wheel) and every `country(_:)` pack. Both fall
  back to `PackCartridge`'s 0.7.3c drawing, which is why that view keeps its
  whole rendering rather than becoming an image well. Pinned in
  `knownGapsFallBack` so art arriving for either is a deliberate edit. Every one
  of the four footer files mapped to a real control; nothing is half-wired.
- **A2's "no per-pack hue" argument is satisfied by the drawn art, not
  overturned by it.** That argument was that twelve chosen plastic colours arrive
  as twelve identical greys under the single-phosphor modes, so colour must not
  carry the identity. These carry theirs in the *picture* -- a map of Europe, a
  crowned V, a knurled dial -- which is still twelve different pictures after the
  LCD's `colorMultiply`. What A2 forbade was a coloured rectangle.
- **Display packs: A2's conclusion reversed, its first half kept.** A2 wrote that
  a bare disc of `mode.screen` "shows the colour without saying it is a screen"
  and concluded that a `ChassisMockup` with a mode-tinted marquee strip was the
  answer -- which made the two shelves "read as one kind of product". That is the
  problem, not the goal: the strip is 24x3pt at the reference size, so three
  display tiles differed only in the tint of a sliver inside an otherwise
  identical device. `ScreenMockup` draws the panel itself with all three of a
  mode's decisions -- ground, ink and accent -- and reads `ownInk` rather than
  `text`, because `text` returns the workshop's chosen font colour and would have
  shown every mode in the same ink. `shellSwatch` keeps `ChassisMockup`
  untouched; a device pack does sell the device.
- **The share preview is possible on this toolchain, and now exists.** The share
  sheet's header is not drawn from the activity items -- iOS asks each item
  source for an `LPLinkMetadata`, and a bare `UIImage` supplies none, which is
  why three releases of cards opened a sheet with an empty header.
  `LinkPresentation` is an ordinary iOS SDK framework with a Swift overlay, so
  `import` is the whole integration -- no linker settings, no `Package.swift`
  change; `OCRService` already imports `Vision` on the same basis, which is what
  made it worth trying rather than assuming. `SharePayload.image` now carries a
  title (the entry's name, "Cellar Profile", or the badge's) because a sheet
  headed "Vinodex" three times says less than one that names the thing.
- **Things to eyeball, in order.** (1) The footer band on several skins -- this
  is the most-looked-at chrome in the app and four caps changed on twenty of
  twenty-one shells; check a dark livery, a light one (BLANC DE BLANCS, whose
  glyph is deliberately dark), HALLOWEEN and a console livery whose four caps are
  four colours. (2) The settings cog, which is a knurled dial in the art and a
  gear glyph in the fallback. (3) The shop shelf at 46pt -- the cartridges are
  drawn at 220-420px and three of the seventeen (`chassisskins`, `screenmodes`,
  `vinodexpro`) are roughly twice the linear size of the other fourteen and were
  written seven minutes later, which reads as a partial re-drop; they render
  correctly but may sit differently in the tile. (4) The display-pack splash,
  where `ScreenMockup` is new and untested by anything but the compiler.
