# HGapps plan — open issues, cleanup, and next batches

*2026-07-30, written at iOS v0.6.2 (tagged, on main). This is the working
plan that consolidates the open ends of AUDIT.md, KNOWN-ISSUES.md,
V1-ROADMAP.md and the archived shipping/port reviews. Run batches with the
`dexbot` agent (`.claude/agents/dexbot.md`); it knows the pipeline and gates.*

> **Moved 0.6.5 (batch 4 phase 3).** This file lived at `HGapps\PLAN.md` — one
> level above the repo, where only one collaborator could see it. It now sits
> in `horizon-md/` alongside AUDIT/auditS/arch so both collaborators do. The
> workspace paths it describes (`HGapps\…`) still refer to the folder **above**
> this repo. Note that several items below are already done — the pixelflags
> decision, the root-doc archive, the `README-layout.md` rewrite and this very
> move all landed in batch 4.

## Where things stand

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

- **vinodex-ios repo**
  - [ ] Prune retired grape sprites: with the leaf now code-driven, only the
    `-rare` bases (+ blends' rare variants, `green-common` unused?) are
    referenced by `grapeArt`. The `-common`/`-noble` artist variants are
    dormant payload — either delete from Resources (masters stay in
    `art/icons/grapes`) or record why they stay. ~200KB.
  - [ ] `art/` and `pixelflags/` are untracked working dirs at repo root —
    decide: commit them (they are the art masters the import scripts need;
    CI can't run imports without them) or move under `HGapps\` outside the
    repo and document. Recommendation: commit `art/icons` (small, load-bearing),
    keep `pixelflags/` as-is (already partially shipped via Resources/Flags).
  - [ ] `.vscode/` at repo root is untracked — commit if the settings are the
    Swift/WSL wiring (memory says workspace settings matter), else ignore it.
  - [ ] Delete `Sources/VinodexUI/Resources/Icons` orphans again after the
    next `npm run icons` (the prune step exists; just re-run pipeline).
  - [ ] KNOWN-ISSUES.md: add a short section for the 0.6.x additions —
    find-missing-refs.mjs as the data gate, the leaf-recolor loader, and the
    "art masters vs shipped Resources" relationship.
- **HGapps root**
  - [ ] Root .md census after this pass: README-layout.md (live),
    V1-ROADMAP.md (live), PLAN.md (this file), SHIPPING-REVIEW.md +
    PORT-TO-WEB.md (archived — move to an `archive/` folder or delete once
    the method notes have been absorbed into the roadmap).
  - [ ] `HGapps` root is not a git repo — the canonical `shared/` master and
    these planning docs are unversioned. Cheap fix: `git init` at root with a
    .gitignore covering the two repos and `xtool/` — the master data deserves
    history. (Decide before the next big data batch.)
  - [ ] Downloads spec files (`vinodex-0.5.9.md`, `vinodex-0.6.2.md`,
    `vinodex-missing-data*.md`) — move into `HGapps\specs\` so batches and
    their specs live together and survive Downloads cleanup.
- **vinodex-web repo**
  - [ ] Commit the synced `shared/` (done this pass if typecheck was green —
    see commit log) and the new `shared/newicons/` art drop.
  - [ ] The SHIPPING-REVIEW hardening list is still open: CI workflow
    (install/typecheck/build), master branch protection, README truth pass
    (pivot sentence, shared/ ownership table).

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
- Data *accuracy* is the `sommelier` agent's beat (`.claude/agents/sommelier.md`):
  it audits `shared/` against regulator and ampelography sources, applies
  in-place corrections, and keeps `data-review/FINDINGS.md` (verification
  ledger) + `data-review/CANDIDATES.md` (ranked staging backlog). It hands
  entry additions and enum changes to dexbot rather than making them.
- Every new enum value (rarity, climate, system) touches: shared types,
  constants mapping, chipColors, generator probe+coverage lists,
  EntryDisplay names, exhaustive Swift switches (UI ones too), and test pins.
