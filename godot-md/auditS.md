# Vinodex Targeted Audit — Compliance · Security · Test

**Authored by Godot.**

**Written 2026-07-29 against `fb5dcf2`. Re-verified 2026-07-31 against `b48ad20`,
and again 2026-08-03 against the working tree at `da787a8`.**

> **Read the working tree, not `HEAD`.** The 2026-08-03 pass verified against the
> tree as it stands, because **every AUDIT.md fix from 2026-08-01 and 2026-08-03
> is uncommitted** — 85 dirty paths and 26 untracked files, including
> `EntryPalette.swift`, `SavedData*.swift`, `DatabaseFixture.swift` and the four
> new test files. `git stash` would reopen eleven of the items below.

> **Path note (added 0.6.5, batch 4 — findings below are unchanged).** Read
> every `pixelflags/` reference in this document as **`shared/pixelflags/`**:
> the flags moved into the cross-repo master (`HGapps\shared`, mirrored into
> both repos by `sync-shared.ps1`) because the web app consumes the same set.
> The relocation is a move, not a remediation — **H2** (provenance/licensing)
> and **M5** (trademarked logos under `Other/`) remain exactly as open as they
> are recorded below, and the `git rm -r pixelflags/Other` remedy now reads
> `git rm -r shared/pixelflags/Other` **plus** the same removal from the master.

Three-dimension audit (compliance, security, tests). The original 50 findings were
produced by 8 finder agents with independent adversarial verification; the one
critical item was confirmed by running `swift build`.

Nine feature commits landed between the two dates (v0.5.0 → v0.6.3): the catalog
grew 284 → 375 entries, thirteen new VinodexCore modules and nineteen new UI
screens arrived, CI was added, and bundled binary assets went 350 → 492 files.
Every finding below was re-checked against the code as it actually stands at
`b48ad20`, each re-check adversarially verified. Two verdicts were overturned by
the verifier (H1, L12).

**IDs are permanent** and independent of [AUDIT.md](AUDIT.md)'s numbering — when
both files are in play, reference these as `auditS C1` / `auditS H3` to avoid
collision with AUDIT.md's own H/M/L series.

Format: `ID · Tag · issue · location → fix`, followed by the 2026-07-31 re-check.

## Status

**11 resolved · 9 partial · 20 still open · 10 worse** — as of 2026-08-03.

| Severity | Resolved | Partial | Open | Worse | Total |
|---|---:|---:|---:|---:|---:|
| Critical | 1 | 0 | 0 | 0 | 1 |
| High | 0 | 1 | 4 | 0 | 5 |
| Medium | 6 | 4 | 5 | 3 | 18 |
| Low | 4 | 4 | 11 | 7 | 26 |
| **Total** | **11** | **9** | **20** | **10** | **50** |

Movement since 2026-07-31 (`2 resolved · 7 partial · 27 open · 14 worse`):

| Went | Count | Items |
|---|---:|---|
| open/worse → **resolved** | 7 | **C1** · **M11** **M12** **M17** · **L4** **L7** **L15** |
| partial → **resolved** | 2 | **M16** · **L12** |
| open/worse → **partial** | 5 | **M14** **M18** · **L6** **L10** **L13** |

**Not one of those nine closures came from work aimed at this file.** Six were
taken outright by an AUDIT.md item covering the same ground — M11/M12 by AUDIT
**M33**, M17 by **M29**, L4 by **M6**, L7 by **L10**, L15 by **M47**. The two
structural ones, **C1** and **M16**, fell together to the CI rewrite. **L12**
closed by a doc edit. That inverts the 2026-07-31 headline, where nine feature
commits had built *on top* of these findings rather than around them. See
[What actually moved](#what-actually-moved).

**Worse** means the described defect is intact *and* the surface it applies to
grew. Ten remain, and the column is now almost entirely compliance and test
hygiene: **M3 M4 M7** (trade dress, dataset provenance, privacy policy) and
**L1 L3 L14 L18 L22 L23 L24**.

**Bookkeeping correction to the 2026-07-31 table.** It reported Medium as
`partial 4 / worse 4`; the items themselves said `partial 3 / worse 5`
(partial: M10 M13 M16 — worse: M3 M4 M7 M11 M14). Totals were right, the split
was not. Nothing was re-litigated; the table above is counted from the items.

### What to fix first

1. **C1 is resolved but uncommitted** — as is every other fix in the working
   tree. Committing is the single highest-value action available, and CI's new
   `ios` job now pins C1's failure class permanently. See
   [The testing gap](#the-testing-gap).
2. **H1 · H2 · M1 · M2** — the app ships 165 CC BY 3.0 icon PNGs, 33 pixel-art
   flags, two OFL fonts and a 217 KB map with no LICENSE, no NOTICE and no in-app
   credits anywhere. These are hard license conditions, not hygiene. **This is
   now the only row on the list with nothing moving in it**, and AUDIT **M36**
   records why: the top-level LICENSE is an ownership decision the maintainer has
   deferred, and a `NOTICE` cannot be written until the SFX provenance question
   is answered. Both are one-sentence answers from the owner, not engineering.
3. **H3 · H4 · M6** — `PrivacyInfo.xcprivacy`, a real bundle ID and an Info.plist
   source. Each one independently blocks App Store submission. **M6's proposed
   fix is now known to be non-viable** — see the item.
4. **L22 · L23 · L24** — the test suite's own defects, untouched while the suite
   grew from 15 files to 22. L24 is sharper than it was: its own premise has now
   gone stale twice in a row.

## The testing gap

*(Rewritten 2026-08-03. The 2026-07-31 version of this section proposed a
three-gate CI table and a `VinodexUITests` target. **The table has been built.**
What follows is what is true now.)*

The main developer builds with [xtool](https://github.com/xtool-org/xtool) from
WSL and no maintainer can install Xcode. That has not changed, and neither have
the four facts underneath it:

- **xtool has no `test` subcommand and no simulator support.** It builds and
  sideloads to a physical device only.
- **A type error inside `#if canImport(UIKit)` is invisible to `swift build` on
  macOS and to `swift test` on Linux.** Proven by injecting an undefined symbol
  into `Sources/VinodexUI/Haptics.swift`: macOS reported `Build complete!`. This
  is exactly the C1 failure class.
- **A *syntax* error in an inactive `#if` branch *is* caught**, because inactive
  branches are still parsed. `README.md`'s old claim that "a syntax error there
  passes `swift test`" was wrong — the real hole is name and type resolution.
- **`swift test` on macOS needs full Xcode**, not Command Line Tools. With CLT
  only it fails on `no such module '_Testing_Foundation'`.

**What changed is everything above that.** `.github/workflows/ci.yml` now runs
four jobs, and the trigger is `on: push: branches: ['**']` — so topic branches
are covered, which they were not:

| Gate | Runs on | Catches | Status |
|---|---|---|---|
| `swift test` | Linux `swift:6.0` | VinodexCore logic | was there |
| `xcodebuild -destination 'generic/platform=iOS'` | `macos-15` | **UI type errors — C1's class** | **new** |
| `xcodebuild test -destination 'platform=iOS Simulator'` | `macos-15` | iOS-hosted tests | **new** |
| `npm run generate` + drift | Linux | stale committed JSON | was there |

Two local checks also now exist, and they are the ones a maintainer actually
runs before pushing — neither existed when this audit was written:

- **`scripts/typecheck-ios-surface.sh`** copies the tree, shims UIKit
  (`typecheck-shim.swift`) and type-checks all of `VinodexUI`/`VinodexApp`
  against the macOS SDK. It reproduced all six of the BookmarksScreen
  actor-isolation errors that broke CI on 2026-07-31, at identical
  `file:line:col`. It is the only thing on either maintainer's machine that sees
  the UI layer at all, and it catches more than CI's `ios` job does — that job
  stops after its first batch of files, so one error hides every file
  alphabetically after it.
- **`scripts/typecheck-core-tests.py`** strips the swift-testing macros and
  type-checks all 22 test files against the built `VinodexCore`. Until it
  existed, the test target was checked by *nothing* locally.

**Still missing, and still this section's real remainder:**

- **No `VinodexUITests` target.** `Package.swift` declares only
  `VinodexCoreTests` depending on `VinodexCore`, so nothing can link against
  `VinodexUI` — which is why **M14**, **L19** and **L20** cannot be closed where
  they stand. The `ios-test` job is now the place such a target would run: guard
  every file with `#if canImport(SwiftUI) && canImport(UIKit)`, exactly as all
  files in `Sources/VinodexUI/` already are, and it compiles to an empty module
  on Linux while running for real on the simulator.
- **`swift test` has still never been executed by a maintainer.** Both AUDIT
  passes say so explicitly. CI is the first thing that runs these suites, and
  the CI runs happen on push — so the 22 test files, four of them written on
  2026-08-03, are type-checked locally and *executed* nowhere yet.

Longer term, the structural fix is the one **M17**, **M18**, **L19** and **L20**
each asked for individually: move pure logic out of `VinodexUI` into
`VinodexCore`, where it is testable on the Linux host the developer works on.
**M17 is now done** (`EntryPalette.swift`), and it is the proof the pattern
works — a file move plus a test file, no device required. M18, L19 and L20 are
the same shape and still undone.

## What actually moved

Nine items closed between 2026-07-31 and 2026-08-03, none of them by work aimed
at this file. Recorded here because the mapping is the useful part — an AUDIT ID
is where the reasoning lives:

| auditS | Closed by | What landed |
|---|---|---|
| **C1** | — | The two-condition guard, plus CI's `ios` job so it cannot recur |
| **M11** | AUDIT **M33** | Eight filter-branch tests; found and fixed two live bugs |
| **M12** | AUDIT **M33** | `StyleInferenceTests`; the false doc comment corrected |
| **M16** | — | `ios` + `ios-test` jobs, `branches: ['**']` |
| **M17** | AUDIT **M29** | `EntryPalette.swift` in Core + `EntryPaletteTests` |
| **L4** | AUDIT **M6** | `Diagnostics.emit()` behind `#if DEBUG`, off-main |
| **L7** | AUDIT **L10** | `dismantleUIView` + `detach(from:)` — *not* `deinit` |
| **L12** | — | No committed file leaks a username or home path |
| **L15** | AUDIT **M47** | `DexRouteTests` walks all 28 routes |

Two of those closures contradict the fix this file proposed, and the AUDIT
entries say why. **L7**: a `deinit` on `GlobeModel` could never have worked — the
run loop retains the link, which retains the proxy, so the model's `deinit` never
fires while the link is live; the teardown had to hang off `dismantleUIView`, and
it had to be conditional or an `.id(…)` skin change would freeze the globe.
**M11/M12**: the branch tests this file asked for turned up two shipped bugs
neither audit predicted — `Rosé` and `Orange Wine` opened their COLOR chip onto
an empty list, and `Prosecco` was labelled a rosé because `colorType` matched
`"rose"` inside `"p-rose-cco"`.

---

## Critical

- [x] **C1** · Test · `swift build`/`swift test` fail on macOS — VinodexApp guarded only by `canImport(SwiftUI)` but references UIKit-gated VinodexUI symbols (`TextScale` not found; verified by building) · `Sources/VinodexApp/VinodexApp.swift:1` → change guard to `#if canImport(SwiftUI) && canImport(UIKit)`
  **@0731 STILL OPEN in committed code — fix staged in the working tree.** The guard at
  `b48ad20` is still the single-condition form, while all 34 VinodexUI files use the
  two-condition form (32 with `canImport(SwiftUI) && canImport(UIKit)`, plus
  DexSound.swift and Haptics.swift with equivalent UIKit gates). Reading
  `VinodexUI.abi.json` from a macOS build confirms the consequence exactly: `TextScale`,
  `UIScale`, `DexAlert`, `ScreenWake` and `Sounds` are all ABSENT, and the whole macOS
  VinodexUI module contains **one** symbol. `swift build` therefore dies on five
  "cannot find … in scope" errors at VinodexApp.swift:33, :34, :110, :127 and :130.
  **Now at** `Sources/VinodexApp/VinodexApp.swift:1` → change `#if canImport(SwiftUI)`
  to `#if canImport(SwiftUI) && canImport(UIKit)`; the matching `#endif` at line 369
  needs no change. **This one-line edit is already applied in the working tree and
  verified — `swift build` now exits 0 with "Build complete!". It is uncommitted.**
  Note that fixing C1 does *not* make `swift test` pass on a Command Line Tools–only
  Mac: it then fails on `no such module '_Testing_Foundation'`, because swift-testing
  ships with full Xcode, not with CLT. That is a separate environment constraint, not a
  repo defect — see [The testing gap](#the-testing-gap).
  **@0803 RESOLVED.** `Sources/VinodexApp/VinodexApp.swift:1` reads
  `#if canImport(SwiftUI) && canImport(UIKit)`, matching every file in
  `Sources/VinodexUI/`. **Still uncommitted** — it is one of 85 dirty paths in the
  working tree, so `HEAD` (`da787a8`) is still broken and this closure evaporates
  under `git stash`. Ticked anyway, because the item is about the code, and the
  regression guard the finding really wanted now exists independently of it: CI's
  new `ios` job compiles the whole package for `generic/platform=iOS` on `macos-15`,
  which is the only gate that can see this class of error. Its own comment names
  this finding — *"that is exactly the class of break that shipped as auditS C1"*.
  The tail of the item stands: `swift test` on a CLT-only Mac still fails on
  `_Testing_Foundation`, and neither maintainer has ever run it. See
  [The testing gap](#the-testing-gap).


## High

- [ ] **H1** · Compliance · 92 CC BY 3.0 game-icons.net icons (+13 Lucide ISC, 1 MDI Apache-2.0) rasterized into 318 shipped PNGs with zero attribution — CC BY attribution is a hard license condition · `scripts/rasterize-icons.sh:56` → add NOTICE crediting game-icons.net artists plus Lucide/MDI license texts; surface credits in-app
  **@0731 STILL OPEN** — Genuinely half-done, in both directions. Better: a real (if
  thin) Credits block now exists and the licensed-icon corpus is 36% smaller. Still
  broken: the README names only game-icons — Lucide (11 icons, ISC) and MDI (1 icon,
  Apache-2.0) get no credit at all; no license is identified (CC BY 3.0 is never named,
  no link to license text, no individual artist names); there is no NOTICE or LICENSE
  file anywhere; and there is no in-app credits screen. README.md is not part of the
  .ipa, so the shipped binary still carries 198 CC BY 3.0 PNGs with zero accompanying
  attribution — the license violation in the distributed artifact is unchanged. On the newly-added assets: the 254 new art PNGs (FlavorArt 96,
  ClassArt 94, GrapeArt 33, StyleArt 31) and the 4 SFX MP3s carry first-party authorship
  claims in-repo, not third-party marks — import-flavor-art.py calls them "hand-drawn
  PNGs", import-grape-art.py says "the artist's masters", import-class-art.py "the
  artist's filenames", and DexSound.swift:5 says "the authored SFX pack (v0.5.6)". Nothing indicates these are third-party, so they are not counted as unlicensed here; but no
  rights documentation exists for them either. (The audio masters moved to `art/sfx`
  in 0.6.4 — AUDIT H12. The "three byte-identical 25389-byte files" note was wrong:
  buttontap/orbdepress/`warm ping` are *not* identical to each other. What is true is
  that orbdepress, `correct answer` and `warm ping` are byte-identical to their already
  bundled counterparts under `Resources/SFX`, while buttontap.mp3 at 25,389 B is the
  untrimmed master of the 4,653 B bundled trim — the one genuinely sole-copy file.)
  **Now at** `README.md:220-224; scripts/rasterize-icons.sh:56;
  Sources/VinodexUI/Resources/Icons/ (198 PNGs)` → Add a top-level NOTICE (and LICENSE)
  covering all three upstreams by name and license: game-icons.net artists under CC BY
  3.0 with a link to the license text, Lucide under ISC, Material Design Icons under
  Apache-2.0. Bundle NOTICE as a resource on the VinodexUI target and surface it from
  SettingsPanel.swift so the credit ships inside the app, not just in the source repo.
  Have scripts/rasterize-icons.sh emit a per-icon attribution manifest alongside the
  PNGs so the NOTICE cannot drift from the 66 icons actually shipped. Separately, record
  provenance for the 254 art PNGs and 4 SFX files (author, commission/ownership terms)
  in the same NOTICE so the first-party claim is documented rather than implied by code
  comments.
  **@0803 STILL OPEN, and it is now the only row on this list with nothing moving in
  it.** No LICENSE, no NOTICE, no in-app credits; `README.md` still names only
  game-icons. AUDIT **M36** records why, and it is not engineering: the maintainer
  deferred the top-level LICENSE on 2026-08-03 as an ownership decision
  (all-rights-reserved / MIT / a split keeping the drawn art proprietary), and a
  NOTICE is blocked behind a second deferred question — `DexSound.swift` calls the
  four SFX "the authored SFX pack", which does not distinguish *we made them* from
  *we licensed a pack*, so a NOTICE written today would assert first-party ownership
  of four files nobody has confirmed. **Both are one-sentence answers from the owner.**
  **Counts in this item are wrong and are superseded** — the corpus was re-derived
  from `icons.json` on 2026-08-03: **68 unique ids, not 92/99** — **55 game-icons
  (CC BY 3.0)**, **12 lucide (ISC)**, **1 mdi (Apache-2.0)** — shipped as **204 PNGs**
  (68 × three scales), of which the CC BY subset is **165**. AUDIT M36 reached the
  same 55/12/1 split independently, and notes its own "11 lucide" was off by one.
  **The one thing that is no longer a question:** both fonts' licences were read
  straight out of their `name` tables (nameID 13/14) — Press Start 2P, *"Copyright
  2012 The Press Start 2P Project Authors (cody@zone38.net), with Reserved Font
  Name"*, SIL OFL 1.1; VT323, *"Copyright 2011, The VT323 Project Authors
  (peter.hull@oikoi.com)"*, SIL OFL 1.1, no reserved name. Both ship unmodified, so
  the RFN is satisfied. That is **M1**'s entire research half, done — see M1.
  **Now at** `README.md Credits; scripts/rasterize-icons.sh:81 (the fetch);
  Sources/VinodexUI/Resources/Icons/ (204 PNGs, 68 ids)`.

- [ ] **H2** · Compliance · 465 pixel-art flag PNGs redistributed (28 shipped in-app) with no license or provenance — filenames like `r_vexillology.png` indicate an unattributed community pack · `pixelflags/` → identify the pack's origin and license; document rights or replace the artwork
  **@0731 STILL OPEN** — Completely unaddressed — not one commit has touched pixelflags/
  since fb5dcf2, and the pack still has no license, no attribution, and no stated
  origin. The shipped surface ticked up by one flag (mexico.png, 28 -> 29). Two
  aggravating details the original audit did not call out. First, the redistributed pack
  is broader than flags: pixelflags/Other/Tech-Brands holds mcdonalds.png, twitter.png,
  tiktok.png, youtube.png, discord.png, bluesky.png and email.png — pixel renderings of
  registered trademarks — and pixelflags/Other/Organizations holds nato.png,
  olympics.png, united_nations.png, world_health_organization.png, royal_air_force.png
  and order_of_malta.png, several of which are protected by statute independently of
  copyright (the Olympic rings and the UN emblem in particular). None of these ship in
  the app today, but all 465 are committed and public in this repo. Second, the
  directory layout (continent/country/subdivision, with historical and micronational
  entries like manchukuo, yugoslavia, cascadia, artsakh) matches a redistributed
  community pixel-flag pack rather than anything authored here, and nothing in the repo
  claims authorship of it — unlike the newer art, which at least carries in-code
  authorship claims.
  **Now at** `pixelflags/ (465 PNGs, 0 provenance files);
  Sources/VinodexUI/Resources/Flags/ (29 shipped PNGs); scripts/rasterize-icons.sh flag-
  copy block` → Identify the pack's actual origin and license before any signed build.
  If it can be traced and the license permits redistribution, add pixelflags/LICENSE
  plus a NOTICE entry naming the pack, its author and its terms, and mirror the credit
  into the in-app credits surface from H1. If it cannot be traced, treat it as
  unlicensed: delete pixelflags/ from the repo and regenerate the 29 shipped flags from
  a known-licensed source (e.g. the public-domain flag set on Wikimedia Commons,
  downscaled by a committed script) so provenance is reproducible. Independently of the
  copyright question, drop pixelflags/Other/Tech-Brands and the statute-protected
  emblems in pixelflags/Other/Organizations — those are a trademark exposure that no
  upstream license would cure. Add a check to scripts/rasterize-icons.sh that refuses to
  copy from a flag source lacking a sibling LICENSE file.
  **@0803 STILL OPEN, and the pack moved without being touched.** Commit `7c19238`
  relocated it to **`shared/pixelflags/`** — the cross-repo master mirrored from
  `HGapps\shared`, because the web app consumes the same set. Still **465 PNGs, 0
  provenance files**, still **88 under `Other/`**. The relocation makes the remedy
  *harder*, not easier: `git rm -r shared/pixelflags/Other` now has to be mirrored
  into the master or `sync-shared.ps1` puts it straight back. The shipped surface
  grew again, **29 → 33 flags**, with the batch-2 FR/IT/ES expansion.

- [ ] **H3** · Compliance · No PrivacyInfo.xcprivacy despite required-reason UserDefaults API use — guarantees ITMS-91053 App Store rejection · `Package.swift:29` → add PrivacyInfo.xcprivacy declaring UserDefaults category with reason CA92.1 and bundle it as a resource
  **@0731 STILL OPEN** — Not merely unfixed but materially larger: the required-reason
  UserDefaults surface grew from 3 files to 13 (a 4.3x increase) across the
  v0.5.0-v0.6.3 feature work, while the privacy manifest that must declare it still does
  not exist. ProfileAvatar.swift additionally writes user-supplied image data to the
  file system, so the manifest will likely need a file-timestamp category too.
  Package.swift has not been touched at all since the audit, so nothing is in flight.
  ITMS-91053 rejection on first App Store submission remains certain.
  **Now at** `Package.swift:26-35 (VinodexCore/VinodexUI resource blocks); no
  PrivacyInfo.xcprivacy anywhere in the repo` → Create
  Sources/VinodexUI/Resources/PrivacyInfo.xcprivacy declaring
  NSPrivacyAccessedAPICategoryUserDefaults with reason CA92.1 (app-group-free, same-app
  access only), and audit ProfileAvatar.swift for whether
  NSPrivacyAccessedAPICategoryFileTimestamp (C617.1) is also needed. Set
  NSPrivacyTracking=false, NSPrivacyTrackingDomains=[] and
  NSPrivacyCollectedDataTypes=[] since nothing leaves the device. It is already covered
  by the existing `.copy("Resources")` on the VinodexUI target, but verify xtool places
  it at the .app bundle root rather than nested inside Resources/ — Apple's scanner only
  reads the top level. Add a CI or pre-release check that fails when no *.xcprivacy is
  present, so the 3-to-13 growth pattern cannot repeat unnoticed.
  **@0803 STILL OPEN.** No `*.xcprivacy` exists anywhere in the tree. Two things
  changed around it, both of which enlarge the manifest rather than the fix. (1) The
  persisted surface is now **enumerable and exactly 20 keys** — `SavedDataKey`
  (`Sources/VinodexCore/SavedData.swift`) owns every literal and `allCases` drives
  both the wipe and the new archive, so the required-reason declaration can be
  written *from the enum* instead of from a grep. That is the one genuinely easier
  thing here. (2) AUDIT **M35** added `SavedDataArchive` with BACK UP / RESTORE,
  which writes a user-exportable JSON document — so the file-system surface is no
  longer just `ProfileAvatar`'s `avatar.jpg`, and the `NSPrivacyAccessedAPICategory
  FileTimestamp` (C617.1) question the item raises now has a second call site to
  answer for. `Package.swift`'s resource blocks are still untouched.

- [ ] **H4** · Compliance · Placeholder bundleID `com.example.Vinodex` on a free profile blocks App Store/TestFlight, and nothing enforces its replacement · `xtool.yml:8` → register a real reverse-DNS App ID on a paid account; add a release check failing on `com.example` prefixes
  **@0731 STILL OPEN** — Both halves of the finding are untouched. The placeholder
  bundle ID is unchanged, and the second half — "nothing enforces its replacement" — is
  if anything more conspicuous now, because a CI workflow was added in this window and
  the opportunity to add the guard was passed over. The in-file comment is an
  acknowledgement, not a mitigation; per the audit rules a doc note does not move the
  status. Any App Store or TestFlight submission still fails at upload.
  **Now at** `xtool.yml:8` → Register a real reverse-DNS App ID (e.g.
  com.blaikooz.vinodex) on a paid account and set it at xtool.yml:8. Then add
  enforcement so the placeholder cannot return: a release job or a step in
  .github/workflows/ci.yml that runs `grep -q '^bundleID: com\.example' xtool.yml && {
  echo '::error::placeholder bundleID'; exit 1; }`, gated to tags or a release branch so
  day-to-day free-profile development on com.example is still possible. A repo-root
  Makefile/npm `preflight` target bundling this check with the H3 xcprivacy check would
  give one gate for both App Store blockers.
  **@0803 STILL OPEN on both halves, but half the item's *consequence* is now paid
  for.** `xtool.yml:8` is still `com.example.Vinodex` and CI gained two more jobs
  without gaining the guard. What changed is what the ID change would have cost:
  AUDIT **M35** established that "a data-migration step" is not implementable at all
  — on iOS the bundle ID *is* the container identity, so a new App ID gets an empty
  `Library/Preferences/<bundleID>.plist` and cannot read the old one — and shipped
  `SavedDataArchive` + BACK UP / RESTORE instead, an export the user carries across.
  The intended ID is recorded (`com.blaikooz.vinodex`, which existed at `b59cafb`
  and was reverted at `b732221` for the quota), so no naming decision is
  outstanding. **The enforcement half is untouched and is still the cheap one** —
  and it is cheaper now than when this was written, because a release job has four
  sibling jobs to sit beside instead of one.

- [ ] **H5** · Test · Shipped daily-pick path `entry(for:in:)` (category rotation + empty-pool fallback) has zero tests — DailyPickTests only exercise `grape()`, which no production code calls · `Sources/VinodexCore/DailyPick.swift:42` → test `entry(for:in:)` rotation, `category(for:)` cycle, and empty-category fallback; delete or wire unused `grape()`/`isSameDay`
  **@0731 PARTIAL** — The headline gap is closed. The shipped path is now
  DailyGrapeScreen.swift:44 `DailyPick.entry(cursor: cursor, in: db)`, a v0.5.x overload
  the audit never saw, and it is well covered (determinism, advancement, 200-open
  spread, cursor persistence) — so the new code did not repeat the bug class.
  `entry(for:in:)` rotation is covered too. Three residuals. (a) The empty-pool fallback
  branch, named explicitly in the audit's fix, is still never executed by a test. (b)
  `grape(for:in:)` still has no production caller — the "delete or wire unused grape()"
  half of the fix was not done, and DailyPickTests.swift is unchanged, so 5 of its 6
  tests still exercise dead code while the file's suite name "Grape of the day" no
  longer matches the feature. (c) `isSameDay` is likewise production-dead. Mild new
  wrinkle: `entry(for:in:calendar:)` has itself become production-dead now that
  DailyGrapeScreen uses the cursor overload, so the rotation tests at
  MinigameTests.swift:205-227 now guard an unshipped path.
  **Now at** `Sources/VinodexCore/DailyPick.swift:60 (untested empty-pool fallback);
  Sources/VinodexCore/DailyPick.swift:76 and :94 (still-dead grape()/isSameDay);
  Tests/VinodexCoreTests/MinigameTests.swift:205-285 (new coverage)` → Add one test that
  builds a WineDatabase with an empty `.grapes` category (the pattern at
  AccessTests.swift:92) and asserts `DailyPick.entry(for:in:calendar:)` falls through to
  the next category, plus one with all three empty asserting nil — that is the last
  uncovered branch at DailyPick.swift:60. Then resolve the dead API: delete
  `grape(for:in:)` (DailyPick.swift:76-90) and `isSameDay` (:94-100) along with the five
  `grape` tests and `sameDay` in DailyPickTests.swift, or wire them to real call sites.
  If `entry(for:in:calendar:)` is also no longer shipped, either delete it or state in
  its doc comment that it is retained as the seedless variant, so the MinigameTests
  rotation cases are not silently testing an unreachable path. Consider folding the
  remaining DailyPickTests cases into MinigameTests so all DailyPick coverage lives in
  one suite.
  **@0803 PARTIAL — residual (a) closed, (b) and (c) unchanged.** AUDIT **M32**
  landed the fixture this needed. `Tests/VinodexCoreTests/DatabaseFixture.swift`
  (`DBFixture`) builds a `WineDatabase` over hand-written JSON, and five new tests in
  `DailyRevealTests` reach the branches no test could touch before: *an empty
  database reveals nothing rather than trapping* (`MinigameTests.swift:292`), *a
  database with no grapes, regions or styles* (`:305`), *one surviving category
  carries every day of the rotation* (`:315`), and *the fallback walks the rotation
  order, not the database order* (`:331`) — that last one loads the style first, so
  a naive "take the first entry" implementation fails it. **That is the empty-pool
  fallback and the `return nil` the audit named, both now executed.** Two more pin
  the pre-epoch case (`:344`, `:356`).
  The fixture takes JSON and not Swift literals for a reason worth knowing: all five
  `WineEntry` variants declare `init(from:)` in the type body, which suppresses the
  synthesised memberwise initialiser, so **a `WineEntry` cannot be constructed by
  hand at all**. Going through `decodeEntries(from:)` is the app's real load path,
  so a fixture that stops decoding is one that has drifted from the schema.
  **Residuals (b) and (c) are verbatim.** `DailyPick.grape(for:in:)` and `isSameDay`
  still have **zero production callers** — grepped 2026-08-03 — so the "delete or
  wire" half was not done, `DailyPickTests.swift` is untouched since `fb5dcf2`, and
  its suite name "Grape of the day" still names a feature that no longer works that
  way. The `entry(for:in:calendar:)` wrinkle stands too. AUDIT L3 already calls
  `isSameDay` "vestigial (test-only) — a candidate for dead-code removal"; nobody
  has removed it. **Now at** `DailyPick.swift:76` (`grape`), `:94` (`isSameDay`) ·
  `MinigameTests.swift:292–366` (the new coverage).


## Medium

- [ ] **M1** · Compliance · OFL fonts PressStart2P and VT323 redistributed (repo + app bundle) without the required OFL license text and copyright notices · `Sources/VinodexUI/Resources/Fonts/` → add OFL.txt with each font's copyright notice beside the .ttf files and bundle it
  **@0731 STILL OPEN** — Unchanged in substance. The two .ttf files are byte-identical
  to the audit tree, still copied into the app bundle and registered at launch, and
  there is still no OFL.txt, no copyright notice, and no in-app credits surface. A
  README credit line naming the two faces was added after fb5dcf2, but it carries
  neither of the two things OFL actually requires (the license text and each font's
  copyright notice) and does not even name the license, so it does not satisfy the
  condition.
  **Now at** `Sources/VinodexUI/Resources/Fonts/ (dir listing); registration at
  Sources/VinodexUI/DexTheme.swift:306-311` → Add
  `Sources/VinodexUI/Resources/Fonts/OFL.txt` containing the SIL Open Font License 1.1
  text plus both copyright lines (Press Start 2P: Copyright (c) Cody "CodeMan38"
  Boisclair; VT323: Copyright (c) Peter Hull). It ships automatically via the existing
  `.copy("Resources")` in Package.swift. Then surface a credits row in SettingsPanel
  that names the fonts, the license and the copyright holders — the README bullet at
  README.md:224 is not distributed with the binary.
  **@0803 STILL OPEN — but the research half is done and the item is now purely
  clerical.** No `OFL.txt`; the two `.ttf` files are unchanged. What no longer needs
  investigating is the exact text OFL requires, which AUDIT **M36** read straight out
  of the fonts' own `name` tables (nameID 13/14): **Press Start 2P** — *"Copyright
  2012 The Press Start 2P Project Authors (cody@zone38.net), with Reserved Font
  Name"*, SIL OFL 1.1; **VT323** — *"Copyright 2011, The VT323 Project Authors
  (peter.hull@oikoi.com)"*, SIL OFL 1.1, no reserved name. Both ship unmodified, so
  the RFN is satisfied and no rename is needed. **Unlike H1 and M2, this item is not
  waiting on the maintainer** — the two copyright lines above plus the OFL 1.1 text
  in `Sources/VinodexUI/Resources/Fonts/OFL.txt` closes it, and it ships via the
  existing `.copy("Resources")`. Registration is now at
  `Sources/VinodexUI/DexTheme.swift:462` (the file was split by AUDIT M30).

- [ ] **M2** · Compliance · Publicly published repo has no LICENSE file and states no terms anywhere — defaults to all-rights-reserved while redistributing third-party content · `README.md:6` → choose and commit a top-level LICENSE, propagated by the monorepo publish script
  **@0731 STILL OPEN** — Still no LICENSE and still no statement of terms anywhere. The
  README gained a `## Credits` section since fb5dcf2 that names game-icons and the two
  fonts, but it grants nothing and states no terms — the repo remains implicit all-
  rights-reserved while redistributing 465 pixel flags, 318 rasterized CC BY/ISC/Apache
  icons and two OFL fonts.
  **Now at** `repo root (no LICENSE file); README.md:220-224 (Credits is the last
  section, file ends at line 224)` → Commit a top-level LICENSE (the code is
  unambiguous; the bundled third-party art is not, so pair it with a NOTICE that carves
  out `pixelflags/`, `Sources/Vinodex*/Resources/Icons`, `.../Fonts` and `.../Maps`
  under their own terms). Add a matching `"license"` field to package.json. The audit's
  "propagated by the monorepo publish script" clause is now moot — KNOWN-
  ISSUES.md:370-384 records that `scripts/publish-swift.mjs` and the mirror were deleted
  on 2026-07-29, so this repo is the only place the file has to land.
  **@0803 STILL OPEN, and it is the blocking item of the four.** No LICENSE. AUDIT
  **M36** was deliberately held on 2026-08-03 at the maintainer's direction for
  exactly this: the choice between all-rights-reserved, MIT, and a split that keeps
  the drawn art proprietary is an ownership call, not a technical one. **H1, M1 and
  L1 all want a NOTICE that carves out territory this file has to define first**, so
  the ordering is M2 → NOTICE → the rest. The carve-out list has grown: it is now
  `shared/pixelflags/` (moved), `Sources/VinodexUI/Resources/{Icons,Fonts,Maps,SFX}`
  **plus the four drawn-art directories** — `ClassArt` (94), `FlavorArt` (96),
  `GrapeArt` (33), `StyleArt` (30) — and `art/`, which AUDIT **H12** established is
  the only surviving copy of every drawn source. 501 binaries under `Sources/` now,
  up from 492.

- [ ] **M3** · Compliance · Chassis replicates Pokédex trade dress — #DC0A2D red, #98CB98 green LCD, blue orb lens, red/yellow/green LEDs, "-dex" naming (no Nintendo names/assets present) · `Sources/VinodexUI/DexTheme.swift:48` → differentiate chassis colorway, lens, and LED cluster; obtain legal review before release
  **@0731 WORSE** — Every element the audit named is still present in the default,
  shipped configuration: #DC0A2D body, cyan orb lens with glow, red/yellow/green LED
  trio, "-dex" naming (DexRoute, DexTheme, `Text("VINODEX")` at
  DeviceChassis.swift:208). A code comment now states the default is deliberately not to
  be changed. Meanwhile the skin/mode roster grew 3→15 and 2→9 and the new entries add
  trade-dress exposure to three further rights holders rather than reducing it: a skin
  and an LCD mode that are explicit Game Boy DMG homages down to the exact four-tone
  palette and a "GRÜNERBOY" name, a literal "STAR TREK" persisted enum rawValue, and an
  "iPhone calculator's livery" skin. The single element that got better is #98CB98,
  which is now dead code — but the green-LCD role moved to LcdMode tints, including the
  DMG green.
  **Now at** `Sources/VinodexUI/DexTheme.swift:48 (#DC0A2D), :1080 (LED trio), :1117
  (classic body), :1242-1247 (cyan orb); new exposure at :485, :491, :913-915, :919-921,
  :1090, :1492` → (a) Change the `.classic` defaults at DexTheme.swift:48, :1080 and
  :1242 — a non-#DC0A2D body, a non-cyan orb and an LED cluster that is not the
  red/amber/green triad — or make a differentiated skin the `@AppStorage` default in the
  seven files that hardcode `ChassisSkin.classic.rawValue`. (b) Rename `case starTrek =
  "STAR TREK"` (DexTheme.swift:485); because the rawValue is the persisted `lcdMode`
  value, do it the way `displayName` already documents — add a new case and migrate the
  stored string, do not edit the literal in place. (c) Re-tone VINHO VERDE off the exact
  DMG palette at :1090/:1256/:1288/:1446/:1470/:1492 and drop the "DMG homage"/"DMG dot-
  matrix" comments at :913 and :486, which are an admission of intent in the source. (d)
  Delete `#98CB98` at :51 — it is unused. (e) Legal review before release still applies
  and now covers Nintendo, Paramount and Apple, not Nintendo alone.
  **@0803 STILL WORSE — unchanged in substance, and every line anchor above is now
  stale.** AUDIT **M30** split `DexTheme.swift` (1661 → 499 lines) into
  `ScreenModes.swift` and `ChassisSkins.swift`, which was pure code motion: it moved
  the exposure, it did not reduce it. Re-pinned 2026-08-03:
  - `#DC0A2D` — `DexTheme.swift:48` (unchanged)
  - `#98CB98` — `DexTheme.swift:51`, **still dead code**, still not deleted
  - `case starTrek = "STAR TREK"` — `ScreenModes.swift:74`
  - the "DMG dot-matrix" comment — `ScreenModes.swift:75-76`; `"GRÜNERBOY"` at `:94`
  - the DMG palette commentary — `ChassisSkins.swift:100`, `:461`, `:536`, which
    still says the buttons are *"the DMG's burgundy … aged into leather"*
  Remedy (d) is a one-line deletion that has now survived two passes. The rest is
  unchanged, including (e): the review still covers Nintendo, Paramount and Apple.

- [ ] **M4** · Compliance · Wine dataset authorship unrecorded while the upstream monorepo commits a copyrighted 4.5 MB Sotheby's encyclopedia as a data source · `KNOWN-ISSUES.md:284` → document dataset provenance in shared/, confirming independence from the Sotheby's text
  **@0731 WORSE** — Two things moved and both moved the wrong way. The undocumented
  corpus grew from 284 to 375 entries (+32%) across shared/data/grapes.ts, regions.ts,
  styles.ts and countries.ts, with authorship still recorded nowhere. And the KNOWN-
  ISSUES.md paragraph that named `sothebys-wine-encyclopedia-2005.raw.txt` as a
  committed copyrighted source in the upstream monorepo was removed in the mirror-
  section rewrite — so the repo now contains no trace at all of the exposure, which is
  the opposite of the requested fix. Nothing here asserts the text is independently
  written.
  **Now at** `shared/ (no provenance file); Sources/VinodexCore/Resources/entries.json
  (375 entries); KNOWN-ISSUES.md (the Sotheby's note is gone — was at :284)` → Add
  `shared/PROVENANCE.md` stating, per collection (grapes.ts, regions.ts, styles.ts,
  countries.ts, grapeCards.ts, continents.ts), who wrote the descriptions and from what
  — and state explicitly that no text derives from `sothebys-wine-
  encyclopedia-2005.raw.txt`. Restore a short note recording that the file exists in
  `blaikooz/vinodex` and is not a source for this repo; deleting the record does not
  delete the exposure. If any of the 375 entries' prose was in fact paraphrased from
  that text, that has to be established before release, and the +91 new entries need the
  same check.
  **@0803 STILL WORSE — the corpus grew again and provenance is still recorded
  nowhere.** `shared/PROVENANCE.md` does not exist. Entries are now **405**
  (146 GRAPES · 116 REGIONS · 106 FLAVORS · 31 STYLES · 6 CONTINENTS), up from 375
  at the last pass and **284 at the audit — +43%**, with the FR/IT/ES expansion in
  `295bda8` adding the newest tranche. The only place the Sotheby's exposure is
  written down anywhere in the repo is now **`godot-md/arch.md:238`**, and it
  survives there only as a *reference to a deleted line* — "the 4.5 MB copyrighted
  Sotheby's text noted at `KNOWN-ISSUES.md:284`", which no longer exists. So the
  record is not merely gone, it is now a dangling citation. Restoring a short note
  is still the first half of this fix, and it is cheaper than the checking half.

- [ ] **M5** · Compliance · Repo redistributes pixel renderings of trademarked logos (McDonald's, TikTok, Twitter, YouTube, Discord, Olympic rings) that the app never uses · `pixelflags/Other/` → delete `pixelflags/Other`, or at minimum the brand-logo and Olympic files
  **@0731 STILL OPEN** — Byte-for-byte unchanged since the tree the audit was written
  against; no commit in the entire history other than the import has touched
  pixelflags/. All 88 files under Other/ remain in the public repo, including pixel
  renderings of five brand logos, the Olympic rings, NATO, the UN and the WHO, and the
  app ships none of them. Deleting the directory still costs nothing functionally.
  **Now at** `pixelflags/Other/ — specifically pixelflags/Other/Tech-Brands/ (7 files)
  and pixelflags/Other/Organizations/ (8 files)` → `git rm -r pixelflags/Other` —
  nothing in Sources/, scripts/ or shared/ references it (the 29 shipped flags are
  copied from the continent directories by scripts/rasterize-icons.sh). If the
  vexillology set is wanted for future countries, keep only the continent directories
  and drop `Other/` entirely; a partial delete of just Tech-Brands and Organizations
  leaves `Cultural-Religious-Language/` and `Nautical/`, which is defensible but leaves
  the same unlicensed-pack question (H2) open.
  **@0803 STILL OPEN, and the delete got a step harder.** All **88** files under
  `Other/` are intact and still shipped by nothing. The path is now
  **`shared/pixelflags/Other/`** (commit `7c19238`), and `shared/` is the cross-repo
  master mirrored from `HGapps\shared` by `sync-shared.ps1` — so the remedy is
  `git rm -r shared/pixelflags/Other` **plus the identical removal in the master**,
  or the next sync restores it. Verify the web app does not reference `Other/` before
  removing it from the master; nothing in this repo's `Sources/`, `scripts/` or
  `shared/data/` does.

- [ ] **M6** · Compliance · No Info.plist source — export-compliance key, display name, and app version cannot be set · `xtool.yml:9` → add an Info.plist source with `ITSAppUsesNonExemptEncryption=false`, display name, and versions
  **@0731 STILL OPEN** — No Info.plist source exists and xtool.yml is byte-identical to
  the audit tree. All three named consequences stand: ITSAppUsesNonExemptEncryption
  cannot be set (every App Store Connect upload will stall on the export-compliance
  question), no CFBundleDisplayName, and the real bundle still reports
  CFBundleShortVersionString 1.0.0 / CFBundleVersion 1 on every build. AppVersion.swift
  only fixes what the back plate *prints* — it detects the placeholder and substitutes a
  constant — which is a UI patch over the same missing plist, not a fix for it. The gap
  also now blocks more than it did: AUDIT.md M17's portrait lock, and the app gained a
  photo picker (Sources/VinodexUI/BookmarksScreen.swift:381 `PhotosPicker(selection:
  $pickedPhoto, matching: .images, photoLibrary: .shared())`) writing to Application
  Support, so backup/usage declarations have nowhere to live either.
  **Now at** `xtool.yml:1-9 (whole file, 9 lines, no Info.plist key)` → Add an
  `Info.plist` (e.g. `Sources/VinodexApp/Info.plist`) and point xtool.yml at it with
  `infoPath: Sources/VinodexApp/Info.plist`; verify the key name against the installed
  xtool version, since AppVersion.swift's doc says 1.17.0 was checked and found to have
  no *version* override — confirm whether an info-plist merge key exists at all, and if
  it does not, that is a blocker to record rather than to work around. The plist must
  carry ITSAppUsesNonExemptEncryption=false, CFBundleDisplayName,
  CFBundleShortVersionString driven from AppVersion.fallback (0.6.3), CFBundleVersion,
  and UISupportedInterfaceOrientations portrait-only. Once it exists,
  AppVersion.placeholders becomes removable and the H3 PrivacyInfo.xcprivacy gains a
  home.
  **@0803 STILL OPEN — and the fix above was investigated and is not viable.** No
  Info.plist source exists. The `infoPath:` key this item proposes **does not exist
  in xtool 1.17**: AUDIT **M17** checked it directly and recorded the finding in
  `xtool.yml` itself, in a comment that now runs 15 lines. `version:` in that file is
  the *config-schema* version, not the app's; xtool generates the Info.plist itself
  and `xtool.yml` is not a passthrough for it. So the item's remedy would have added
  a key that reads as a declaration while doing nothing — which is exactly what the
  AUDIT entry says it refused to do. **Treat the missing plist as a blocker to
  record, not a gap to work around** — the item's own escape clause ("if it does not,
  that is a blocker to record rather than to work around") is now the operative half.
  One of the four consequences is independently fixed, by a mechanism the plist could
  not have beaten: **portrait lock is real**, via
  `AppDelegate.application(_:supportedInterfaceOrientationsFor:)` returning
  `.portrait`, wired with `@UIApplicationDelegateAdaptor`. That callback is consulted
  per window and takes precedence over the plist regardless, so it is the stronger
  mechanism, not a fallback.
  **The other three stand and one grew.** `ITSAppUsesNonExemptEncryption` still
  cannot be set, so every App Store Connect upload stalls on export compliance;
  there is still no `CFBundleDisplayName`; and every build still reports
  `CFBundleShortVersionString 1.0.0` with `AppVersion.placeholders` patching what
  the back plate *prints*. The declarations with nowhere to live now include AUDIT
  **M35**'s `SavedDataArchive` export alongside the photo picker. **What this
  actually blocks on is H4** — a real signing pipeline, at which point both this and
  M37's bundle-version half reopen together.

- [ ] **M7** · Compliance · No privacy policy anywhere despite the app storing a user-entered display name locally · `README.md` → write a privacy policy stating local-only storage; link it from the README
  **@0731 WORSE** — Still zero privacy policy, and the thing a policy would have to
  describe grew roughly threefold: 6 stored keys at fb5dcf2 → 19 at HEAD, plus a file on
  disk. Two of the additions change the category of the claim, not just its size —
  `triedRatings` stores free-text tasting notes the user types, and the profile avatar
  is an image taken from the photo library and persisted to Application Support. A one-
  line "we store a display name locally" would now be inaccurate. On the credit side,
  deletion is genuinely complete: SettingsPanel.swift:1226-1258
  `SavedDataReset.wipeAll()` calls `BookmarkStore.shared.removeEverything()`,
  `RecentlyViewedStore.shared.clear()`, `AvatarStore.shared.clear()` (which removes
  avatar.jpg) and the rest, then removes 16 keys — so a policy can honestly promise an
  in-app wipe.
  **Now at** `repo root (no privacy policy anywhere); persisted keys across
  Sources/VinodexCore/*.swift and Sources/VinodexUI/*.swift; photo file at
  Sources/VinodexUI/ProfileAvatar.swift:48` → Write PRIVACY.md at the repo root and link
  it from README.md, stating: no network calls, no analytics, no accounts; all data is
  on-device; enumerate what is stored — display name, profile photo (copied from the
  photo library, downscaled to 512px and written to Application Support as avatar.jpg,
  never uploaded), three shelves of entry ids, tried ratings *including the free-text
  note field*, recently-viewed ids, daily-challenge streak, quiz tier, reveal cursor,
  entitlements and UI preferences; and state that SETTINGS → CLEAR SAVED DATA deletes
  all of it (accurate per SettingsPanel.swift:1226). App Store Connect also needs a
  hosted URL for this, and it must agree with the PrivacyInfo.xcprivacy that H3
  requires.
  **@0803 STILL WORSE, and the policy now has to describe a new *capability*, not
  just more keys.** No `PRIVACY.md`. Two changes:
  - **The key list is now authoritative and is 20, not 19.** `SavedDataKey`
    (`Sources/VinodexCore/SavedData.swift`) owns every persisted literal, and AUDIT
    **M35** found the old hand-kept 17-key array had silently drifted —
    `recentlyViewedEntryIDs`, `starterTierOnly` and `grantedEntitlements` were
    persisted and cleared through their stores and never appeared in it. **Write the
    policy's enumeration from `SavedDataKey.allCases` and it cannot drift again.**
  - **BACK UP / RESTORE is a new claim to make.** `SavedDataArchive` writes the whole
    device state to a JSON document the user exports — so "all data is on-device" is
    now conditionally false in a way a policy must state: it is on-device *unless the
    user exports it*, at which point it goes wherever they send it. One deliberate
    asymmetry belongs in the policy too: `export` records `starterTierOnly` and
    `grantedEntitlements`, and `apply` **refuses** both, because an importable
    entitlement list is a free unlock for anyone with a text editor.
  Deletion is still complete and still honestly promisable — `wipeAll()` now
  iterates `allCases` rather than a hand-kept array, which is strictly better than
  what the 2026-07-31 note credited it with.

- [x] **M8** · Security · One malformed entry fails the entire `[WineEntry]` decode, shipping an app with zero entries — one bad regeneration from a bricked launch · `Sources/VinodexCore/WineDatabase.swift:249` → decode entries individually via a lossy wrapper, recording per-entry failures in `decodeErrors`
  **@0731 RESOLVED** — This is a genuine per-entry lossy decode, not a doc note: one
  malformed entry now costs exactly that entry, the rest of the 375 survive, and the
  reason lands in `decodeErrors` → the launch DexAlert (VinodexApp.swift:109-118) and
  the DEV panel. v0.6.3 also added a schema-version stamp (WineDatabase.swift:384,
  Resources/schema.json, SCHEMA_VERSION=1 in scripts/generate-ios-data.ts:1050) whose
  mismatch is recorded rather than thrown. Two caveats that do not reopen M8: (a) a file
  that is not a JSON array still throws into the empty-database fallback, which is the
  intended file-level behaviour and is pinned at DecodeRobustnessTests.swift:61-66; (b)
  these tests only actually execute on the Linux CI runner, because `swift test` fails
  to build on macOS at HEAD (VinodexApp.swift:1 lacks `&& canImport(UIKit)`) — that is a
  separate finding, and the VinodexCore fix itself is correct and compiled.
  **@0803 STILL RESOLVED, and generalised past what this item asked for.** AUDIT
  **M46** rebuilt the loader around `ResourceLoad<T>` — one `loadResource(_:from:)`
  naming the same three outcomes for all five optional tables, so per-entry lossy
  decode is no longer the one place robustness lives. Caveat (b) above is void: C1 is
  fixed, so these tests build on macOS, and CI now runs them on Linux *and* on the
  iOS Simulator. Caveat (a) is now covered by a test rather than merely intended —
  `LoaderFallbackTests` walks every branch through `WineDatabase(reading: .fixture)`,
  including *a well-formed but empty catalogue is still a fault*, a hole M46 found
  that this item did not name: a valid empty array reported nothing at all, so a
  build with no catalogue showed NO DATA FOUND everywhere and never raised the alert.

- [ ] **M9** · Test · Paywall gate `open`/`openRoute` has zero test coverage and already regressed once per its own comment · `Sources/VinodexApp/VinodexApp.swift:47` → move the gate and pure route-resolution logic into VinodexCore; add host tests
  **@0731 STILL OPEN** — Neither half of the recommended fix landed: the gate was not
  moved into VinodexCore and no host tests exist. AccessTests.swift does cover the
  underlying predicate `AccessStore.isLocked` heavily (~20 assertions), but that is the
  input to the gate, not the gate: the `.detail` unwrap-and-re-gate in `openRoute`, the
  `lockedAttempt` assignment, and the grant-then-continue path at :96-98 are all
  untestable as written. The blast radius grew since fb5dcf2: `open($0)` call sites went
  from 8 to 12 (new chipFilter, wsetQuiz/dailyChallenge quiz, scanner and passport-
  adjacent screens all funnel through it), and `swift test` cannot build VinodexApp on
  macOS at all, so even a hypothetical host test could not run there today.
  **Now at** `Sources/VinodexApp/VinodexApp.swift:41 (`open(_:)`) and :54
  (`openRoute(_:)`)` → Move the pure part into VinodexCore: add e.g. `enum EntryGate {
  static func resolve(_ route: DexRoute, in db: WineDatabase, access: AccessStore) ->
  GateOutcome }` returning `.push(DexRoute)` or `.locked(WineEntry)`, covering both the
  entry and the `.detail(id)` route forms. Leave only `Haptics.select()`/`lockedAttempt
  = ...`/`push(...)` in VinodexApp.swift:41-60. Add VinodexCoreTests cases for: locked
  entry → `.locked`; unlocked entry → `.push(entry.destination)`; `.detail(lockedID)` →
  `.locked` (the exact 0.5.x regression); `.detail(unknownID)` → `.push` unchanged;
  non-`.detail` route → `.push` unchanged.
  **@0803 STILL OPEN, and it is now the cheapest of the extraction items to take.**
  No `EntryGate`; `open(_:)` and `openRoute(_:)` are unchanged, only shifted to
  `VinodexApp.swift:107` and `:120`. But three of the four obstacles the 2026-07-31
  note listed are gone. `swift test` builds VinodexApp on macOS now (C1). CI's
  `ios-test` job means a host test would actually *run*. And AUDIT **M47** built the
  precedent: `DexRoute`'s vocabulary is now pinned by `DexRouteTests`, including
  `WineEntry.destination`'s `.detail` fall-through — which is one of the five cases
  this item asks for, already written. The gate itself is the remaining half.
  **Take it with M18** — same module, same reason, and the pattern is now proven
  three times over (**M17** → `EntryPalette`, AUDIT M47 → `DexRoute`, AUDIT M32 →
  `DBFixture`).

- [ ] **M10** · Security · No lockfile — unpinned ts-node/typescript ranges resolve fresh at install and regenerate the shipped app JSON with an unvetted toolchain · `package.json:11` → commit package-lock.json and install with `npm ci`
  **@0731 PARTIAL** — The lockfile commit removes the worst case (a fresh resolve of the
  whole tree on every clone), but the finding explicitly asked for `npm ci`, and no
  command anywhere uses it. `npm install` will silently rewrite package-lock.json rather
  than fail when the tree and the manifest disagree — and in the one place it matters,
  the CI `data` job, that rewrite is invisible: the drift check is scoped `git diff
  --quiet -- Sources/VinodexCore/Resources`, so a mutated lockfile never trips it, and
  the shipped app JSON can still be regenerated by a toolchain nobody reviewed.
  arch.md:743-745 is also now stale, still asserting "No `package-lock.json` ... because
  there is no lockfile **`npm ci` cannot run at all**".
  **Now at** `package-lock.json (present, root); .github/workflows/ci.yml:80;
  README.md:188; KNOWN-ISSUES.md:286; package.json:14-18` → Change
  .github/workflows/ci.yml:80 to `npm ci --no-audit --no-fund` (add `cache: npm` to the
  setup-node step, which requires the lockfile that now exists). Update README.md:188
  and KNOWN-ISSUES.md:286 to `npm ci`. Add `"engines": { "node": ">=22" }` to
  package.json. Either widen the CI drift check to the whole tree (`git diff --quiet`)
  or add package-lock.json to its path list so a lockfile mutation fails the job.
  Correct the stale B3 paragraph at arch.md:743-745.
  **@0803 STILL PARTIAL — nothing in this item moved, and the anchors need
  re-pinning.** Verified line by line: `.github/workflows/ci.yml:162` is still
  `npm install --no-audit --no-fund`, the setup-node step still has no `cache: npm`,
  the drift check at `:172` is still scoped `git diff --quiet -- Sources/VinodexCore/
  Resources`, `package.json` still has no `engines` (and no `license`, which
  **M2** will want), and `README.md:247` and `KNOWN-ISSUES.md:369` both still say
  `npm install`. `package-lock.json` is tracked, 8,601 bytes.
  **The stale doc is at `arch.md:753-755`, not `:743-745`**, and it is worse than
  recorded — three separate paragraphs are now wrong: `:230` files
  `package-lock.json` as "neither tracked nor ignored", `:339` says "there is no
  lockfile … Land the lockfile first", and `:896` says the pipeline "cannot use
  `npm ci`". All three describe a repo that stopped existing on 2026-07-31.
  **This is a five-line change and it has survived two passes.** It is also the one
  remaining item that touches the supply chain for the shipped app JSON.

- [x] **M11** · Test · EntryFilter `.type`, `.tasting`, `.soil`, and `.system` predicate branches have zero test coverage · `Sources/VinodexCore/EntryFilter.swift:105` → add branch tests for each filter case against known entries
  **@0731 WORSE** — Untested branch count is unchanged at 4 of 9 predicate cases (the
  new `.flavorSubclass` case did arrive with tests, FilterTests.swift:61-78), but the
  untested lines inside the four named branches roughly doubled — `.type` gained a
  semantic early-return that makes every grape match a DUAL filter, and `.system` gained
  a whole second resolution strategy for styles that routes through
  `EntryDisplay.styleClass` (itself untested — see M12). Two of these were shipped
  explicitly as bug fixes ("0.6.2, D1"/"D2") and nothing pins them, so the exact
  regressions they fixed can silently return. Note also
  `EntryFilter.scanTitle`/`indicatorText` have no test at all for any case.
  **Now at** `Sources/VinodexCore/EntryFilter.swift:118 (.type), :133 (.tasting), :145
  (.soil), :156 (.system)` → Add branch tests to
  Tests/VinodexCoreTests/FilterTests.swift, one per case, asserting both the positive
  and the exclusion half: `.type("red")` matches grapes by grapeType/wineType/grapeStyle
  and returns nothing for regions; `.type("dual")` returns every grape and still no non-
  grape (pins EntryFilter.swift:128); `.tasting(<a real note>)` matches on
  tastingProfile and separately on `classification`, and returns false when neither;
  `.soil("limestone")` matches only regions whose `details.soilType` contains it and
  excludes regions with nil soilType; `.system("ORIGIN")` returns exactly the styles
  whose `EntryDisplay.styleClass` is ORIGIN (Champagne, Port, Sherry, Prosecco, Crémant,
  Cru Beaujolais, Super Tuscan) and `.system("STYLE")` does NOT return all 31 (pins
  EntryFilter.swift:162-168), plus a region case going through the `classification`
  path. Add a small table pinning `scanTitle`/`indicatorText` for all nine cases,
  including `.system("origin")` → "ORIGIN SCAN".
  **@0803 RESOLVED by AUDIT M33.** All four named branches are covered, by eight new
  tests in `FilterTests.swift`: `.type` (`:151` colour and style, `:178` the DUAL
  early-return this item specifically called out, `:198`, `:230`, `:245`), `.tasting`
  (`:260`, both the classification and the note haystack), `.system` (`:282` through
  the inferred class, `:313` the raw-classification fall-through for non-styles) and
  `.soil` (`:329`). One further test — *the indexed and unindexed paths agree on
  every filter branch* (`:349`) — pins `entries(matching:)` against
  `[WineEntry].apply` across all nine cases; nothing had been comparing them.
  `.soil` was reachable only through `DBFixture`, since no shipped call site
  constructs it, and it was kept rather than deleted: 36 shipped regions carry a
  `details.soilType` and re-deriving the substring-vs-equality semantics when the
  GEOLOGY chip ships costs more than the fixture test.
  **The prediction in this item was right and cost two shipped bugs to prove it.**
  Writing the branch tests surfaced both, and both are fixed: three COLOR chips
  (`ROSE`, `ORANGE`) opened onto an **empty list** because `GrapeColor` has only two
  cases — the same defect D2 fixed for DUAL and left unfixed for these — and
  **`Prosecco` was labelled a rosé**, because `colorType` matched substrings and
  "rose" sits inside "p-*rose*-cco". The second was live on the entry page, in the
  chip text and in the filter behind it. `colorType` now uses `matchesWholeTerm`.
  **One residual, and it is small.** The `scanTitle`/`indicatorText` table this item
  asked for is partial rather than absent: AUDIT **M47** pins them for `.region`
  (`RouteAndSearchStateTests.swift:31-32`) and `scanTitle`/`scanSymbol` for all five
  `WineEntry` cases (`:190`, `:199`), but not for all nine filter cases. Ticked
  because the predicate branches — the whole substance of the finding — are done;
  fold the remaining table into `RouteAndSearchStateTests` whenever that file is next
  open.

- [x] **M12** · Test · Hand-transcribed styleClass/colorType keyword tables with load-bearing precedence have no tests despite claiming test-driven placement · `Sources/VinodexCore/EntryDisplay.swift:43` → pin styleClass/colorType outputs and keyword precedence with table-driven tests
  **@0731 STILL OPEN** — Still exactly as the audit described, and the consequence of a
  bad table edit is now larger than it was: since fb5dcf2 `styleClass` gained a second,
  non-cosmetic consumer — EntryFilter.swift:162-168 uses it to decide which entries a
  CLASS-chip filter returns — so the tables now determine list contents, not just a chip
  label and a glyph (EntryDetailScreen.swift:385,609; EntryVisual.swift:187-188). The
  stale doc comment at :41-42 is direct evidence that this table has already drifted
  from its stated behaviour with nothing to catch it.
  **Now at** `Sources/VinodexCore/EntryDisplay.swift:26-38 (the three keyword tables),
  :43 (`styleClass`), :56 (`colorType`)` → Add a table-driven suite in VinodexCoreTests
  pinning `EntryDisplay.styleClass(name:classification:)` and
  `EntryDisplay.colorType(name:)` for every one of the 31 shipped style names, plus the
  precedence pairs that would flip if the three `if` statements at
  EntryDisplay.swift:50-52 were reordered: "Sparkling Wine" → .type (matches
  typeKeywords "sparkling wine" AND methodKeywords "sparkling"), "Sparkling Red" →
  .type, "Orange Wine" → .method with colorType .orange,
  "Champagne"/"Prosecco"/"Crémant" → .origin (diacritic folding included), "Rosé" →
  .type/.rose, "Qvevri Amber"/"Noble Grapes"/"GSM Blend"/"Bordeaux Blend" → .style.
  Assert the classification override wins only for ORIGIN/METHOD/TYPE/BLEND and that a
  literal "STYLE" classification falls through to keywords (EntryDisplay.swift:46). Then
  fix the false comment at :41-42, or make BLEND reachable if the four fallthroughs are
  wrong.
  **@0803 RESOLVED by AUDIT M33**, including the doc-comment half. The
  `StyleInferenceTests` suite (`FilterTests.swift:435`) covers what the item asked
  for: *an explicit classification overrides the keyword tables* (`:437`), *a STYLE
  classification is not an override* (`:447` — the exact `EntryDisplay.swift:46`
  fall-through), *keyword precedence is ORIGIN, then TYPE, then METHOD* (`:456`), and
  *colour precedence is ORANGE, ROSE, RED, WHITE, then DUAL* (`:467`). The
  31-style table this item requested is covered by walking rather than by
  transcription — *every style's inferred class round-trips through its own CLASS
  chip* (`:485`) iterates all shipped styles, which is strictly better: a per-name
  table goes stale the next time a style is added, and the catalogue has grown twice
  since this was written.
  **The false comment is fixed.** `EntryDisplay.swift:62-64` now states the truth —
  *"`classification: "STYLE"` is not an override — only ORIGIN, METHOD, TYPE and
  BLEND are … which is why no entry in the database resolves to `.style`"* — which
  is the second branch of this item's remedy, chosen deliberately over making BLEND
  reachable.
  **And the drift this item predicted was real.** The load-bearing second consumer it
  flagged — `EntryFilter` using `styleClass` to decide chip contents — is exactly
  where the `Prosecco`-is-a-rosé bug lived, undetected. Tables now pinned; see M11.

- [ ] **M13** · Test · No synthetic-JSON tests — encode paths, unknown-category rejection, and `decodeIfPresent` defaults are all uncovered · `Sources/VinodexCore/WineEntry.swift:420` → add fixture-JSON decode tests, an encode/decode round-trip, and a bad-category failure test
  **@0731 PARTIAL** — DecodeRobustnessTests.swift was added in a8fd7bb (v0.6.3) and
  closes two of the audit's three asks: fixture-JSON decode through
  `WineDatabase.decodeEntries(from:)` and an unknown-category rejection test. The third
  ask is not met: encode is *executed* but never *asserted* — no round-trip equality
  check exists anywhere (`grep -rn JSONEncoder Tests/` hits only
  ToolsTests/ScreenStateTests for unrelated types), and because the fixtures take the
  first 1-2 bundled entries (both GRAPES),
  `RegionEntry`/`StyleEntry`/`FlavorEntry`/`ContinentEntry` `encode(to:)` are never run
  at all. The `decodeIfPresent` defaults are likewise still uncovered: every bundled
  entry carries `grapeAlternateNames`, `grapeNotableRegions`, `wineType` and
  `tastingProfile`, so re-encoded fixtures always include those keys and the `?? []`
  branches never fire.
  **Now at** `Tests/VinodexCoreTests/DecodeRobustnessTests.swift:1-76;
  Sources/VinodexCore/WineEntry.swift:134-320 (per-variant encode/decode), :449-471
  (union Codable)` → Add to DecodeRobustnessTests: (1) a round-trip fidelity test
  looping one entry per `EntryCategory` — `let back = try
  JSONDecoder().decode(WineEntry.self, from: JSONEncoder().encode(original));
  #expect(back == original)` (WineEntry is Hashable, so `==` is free) — which covers all
  five `encode(to:)` implementations and would catch a dropped `encodeIfPresent`; (2) a
  hand-written minimal-grape fixture that omits `grapeAlternateNames`,
  `grapeNotableRegions`, `wineType` and `tastingProfile`, asserting the decoded entry
  has empty arrays and nil optionals, and a minimal-flavor fixture omitting
  `tastingProfile` asserting `[]`.
  **@0803 STILL PARTIAL, and the third ask has half-closed by accident.** AUDIT
  **M46** added `LoaderFallbackTests`, whose fixtures re-encode the *real* bundled
  tables — `encoder.encode(live.palette)`, `.icons`, `.countries` and
  `Array(live.entries.prefix(3))` at `DecodeRobustnessTests.swift:103-111` — so
  `encode(to:)` is now executed across far more of the surface than before, and the
  encoded output is fed straight back through a decode. **But it is still never
  asserted equal**: no `#expect(back == original)` round-trip exists anywhere, so a
  dropped `encodeIfPresent` would still pass. And `prefix(3)` is three GRAPES, so
  `RegionEntry`/`StyleEntry`/`FlavorEntry`/`ContinentEntry`'s `encode(to:)`
  implementations are still never run.
  **The `decodeIfPresent` half is now trivially writable and was not written.**
  `DBFixture` (AUDIT M32) exists precisely to hand-write minimal JSON — its own doc
  comment describes *"the minimum a `GRAPES` record needs"* — so the second half of
  this item's remedy is a fixture fragment plus four assertions, in a file that
  already exists. Take it next time `DatabaseFixture.swift` is open.
  **Now at** `Tests/VinodexCoreTests/DecodeRobustnessTests.swift:96-230`
  (`LoaderFallbackTests`) · `Tests/VinodexCoreTests/DatabaseFixture.swift`.

- [ ] **M14** · Test · No test asserts manifest icons and flags resolve to bundled PNGs; flagSlug logic is duplicated in shell · `Sources/VinodexCore/WineDatabase.swift:190` → add a resources test asserting every unique icon and flag has a bundled PNG
  **@0731 WORSE** — The defect is unchanged — no test asserts any manifest key resolves
  to a bundled PNG, and flagSlug is still reimplemented in shell — but the untested
  surface grew substantially. At fb5dcf2 only two mappings existed (Icons 318 files / 99
  `unique` ids, Flags 28); at HEAD four brand-new manifest->PNG schemes joined the same
  uncovered class with zero coverage: `art:` ids into ClassArt (0 -> 94 files),
  flavorArt (0 -> 96), grapeArt (0 -> 33), styleArt (0 -> 31) = 254 new PNGs and 4 new
  resolution rules. Total bundled art went 346 -> 481 files across 6 directories. (Icons
  themselves shrank to 198 files / 66 unique ids, Flags 28 -> 29.) Verified by hand
  that nothing is currently missing — all 66 unique ids and all 29 flags resolve — so
  this is purely an unguarded invariant, and each new naming scheme is a fresh way for
  it to break silently.
  **Now at** `Package.swift:40-43 (test target);
  Sources/VinodexCore/WineDatabase.swift:246-249 (flagSlug), :252-254 (slug);
  scripts/rasterize-icons.sh:144` → Two parts. (1) Add a `VinodexUITests` test target
  (or move the PNGs to VinodexCore/Resources) so a test can reach `Bundle.module`; then
  assert, for every `db.icons.unique` id, that `Bundle.module.url(forResource:
  IconManifest.slug(for: id), withExtension: "png", subdirectory: "Resources/Icons")` is
  non-nil — with `art:`-prefixed ids checked against Resources/ClassArt — and likewise
  every value of `flags`, `flavorArt`, `grapeArt` and `styleArt` against
  Flags/FlavorArt/GrapeArt/StyleArt. Assert the reverse direction too, so orphan PNGs
  fail. (2) Kill the shell duplicate: have scripts/generate-ios-data.ts emit the
  resolved flag stem into icons.json alongside the source path so rasterize-icons.sh
  reads it instead of recomputing `tr '[:upper:] ' '[:lower:]-'`, leaving
  WineDatabase.flagSlug the single definition.
  **@0803 PARTIAL — part (2) resolved verbatim, part (1) untouched.** AUDIT **L25**
  implemented exactly the mechanism proposed here: `generate-ios-data.ts` emits a
  **`flagSlugs`** table (33 entries, confirmed present in `icons.json`), and both
  consumers read it — `rasterize-icons.sh:171-190` names the copied PNG from it and
  **fails loudly on a missing entry** rather than falling back, and
  `IconManifest.flagSlug(for:)` (`WineDatabase.swift:269`) returns the generated
  value with the old rule kept only as a fallback for a manifest that predates it.
  The generator's rule folds diacritics and collapses non-alphanumeric runs, so it
  answers for the names that would have diverged, and is byte-identical to both old
  rules on all 33 current keys. `flagSlugs` is asserted non-empty in
  `ICONS_REQUIRED_NONEMPTY`. **The shell duplicate is dead.**
  **Part (1) — the test — is still absent, and cannot be written where it stands.**
  `grep -rn "Bundle.module" Tests/` returns nothing; `Package.swift` still declares
  only `VinodexCoreTests → VinodexCore`, so no test can reach the PNGs. What exists
  instead is a *runtime* probe: AUDIT **L26** added `DexAssetAudit`, which resolves
  every manifest id through the bundle at all three scales and reports per surface in
  SETTINGS ▸ DEV, and the README release checklist now names reading it as step 3.
  **That is a checklist item, not a gate** — it fires only when a human opens the DEV
  panel, which is the difference this finding is about. Re-counted 2026-08-03,
  nothing missing: **68/68** icon ids · **204** Icons PNGs (68×3) · 94 `art:` ·
  96 FlavorArt · 33 GrapeArt · 30 StyleArt · **33/33** flags. The unguarded surface
  is now six directories and 501 bundled binaries.

- [x] **M15** · Test · Nothing verifies committed `Resources/*.json` match the shared/ sources — a stale regeneration ships silently · `scripts/generate-ios-data.ts:626` → add a check regenerating to a temp directory and diffing against committed JSON
  **@0731 RESOLVED** — Added in commit 0a446d3 ('own this repo — end the mirror, restore
  AUDIT.md, add CI'). The check does exactly what the finding asked, just in-place plus
  `git diff` rather than into a temp directory — functionally equivalent and it covers
  the whole Resources directory, i.e. all six generated JSON files, not a subset. The
  generator is hermetic (only `existsSync` call is generate-ios-data.ts:76 on
  Package.swift; no network), and package-lock.json now exists, so `npm install` is
  reproducible. Two residual gaps, neither the finding's stated defect: `git diff` does
  not surface a *new untracked* output file should the generator start emitting one, and
  icons are deliberately not regenerated (documented in the job comment: 'Icons are not
  regenerated: that step needs network access to the Iconify API and rsvg-convert') —
  but the finding scoped itself to `Resources/*.json`. Note the workflow only triggers
  on main-targeted push/PR, so the check does not run on the current `audit` branch
  until a PR is opened.
  **@0803 STILL RESOLVED, and the trigger caveat is void.** `on:` is now
  `push: branches: ['**']` plus an unscoped `pull_request:`, so the `data` job runs
  on every branch — see **M16**. The check itself is unchanged at `ci.yml:160-176`.
  Both residuals stand: `git diff` still cannot see a *new untracked* output file,
  and icons are still deliberately not regenerated (network + `rsvg-convert`). The
  first of those is the one that matters for **M10**, whose fix is to widen this same
  path list.

- [x] **M16** · Test · No CI — `swift test` never runs automatically, which is how the macOS build breakage (C1) went unnoticed · `Package.swift` → add a CI workflow running `swift test` on Linux and macOS
  **@0731 PARTIAL** — CI now exists (commits 0a446d3, fbc51a0), so half the finding is
  met: `swift test` runs automatically on Linux. The macOS half is entirely absent —
  there is no `runs-on: macos-*` job anywhere. This is not a theoretical gap: at HEAD
  `swift build` and `swift test` both FAIL on macOS because
  Sources/VinodexApp/VinodexApp.swift:1 is still `#if canImport(SwiftUI)` without `&&
  canImport(UIKit)`, so the file compiles on macOS and dies on 'cannot find
  TextScale/UIScale/DexAlert/ScreenWake/Sounds in scope'. That is precisely the C1
  breakage the finding said CI was meant to catch, and the CI as written still cannot
  see it — the Linux container has no SwiftUI, so VinodexApp compiles to nothing there
  and the job goes green. Second gap: the branch filter is `[main]` only, so pushes to
  the current working branch `audit` (and to any other topic branch) run neither job;
  coverage begins only when a PR against main is opened.
  **Now at** `.github/workflows/ci.yml:11-15 (`on:` block), :26-29 (only Swift job)` →
  Add a second job to ci.yml: `build (macOS)` with `runs-on: macos-14`, `- uses: maxim-
  lobanov/setup-xcode@v1` (or the runner default), running `swift build` and `swift
  test` — that job fails today and pins C1. Until C1 is fixed, gate it with `continue-
  on-error: false` deliberately so the red is visible rather than tolerated. Separately,
  broaden the triggers so topic-branch work is covered: `on: push: branches: ['**']` (or
  at minimum add `audit`), keeping `pull_request: branches: [main]`.
  **@0803 RESOLVED, and past what the item asked for.** Both gaps are closed and the
  workflow now runs **four** jobs. The trigger is `on: push: branches: ['**']` with an
  unscoped `pull_request:`, so topic branches are covered — the second gap, verbatim.
  The first gap was closed **better than proposed**: a `macos-*` job running
  `swift build` would *not* have worked, and the workflow's own comment records why —
  *"UIKit is unavailable there too, so VinodexUI compiles to nothing on macOS just as
  it does on Linux."* A macOS Swift build would have gone green on the same blind
  spot. What landed instead:
  - **`ios`** — `xcodebuild build -scheme Vinodex -destination
    'generic/platform=iOS'` on `macos-15`, `CODE_SIGNING_ALLOWED=NO`. This is the
    only gate that can see a type error inside `#if canImport(UIKit)`, which is C1's
    failure class, and its comment names this finding directly.
  - **`ios-test`** — `xcodebuild test` on an iPhone 16 Simulator, which is what makes
    a `VinodexUITests` target writable at all.
  - `test` (Linux) gained `--enable-code-coverage`, a `.build` cache keyed on the
    repository name (a rename once poisoned it), `concurrency` cancel-in-progress,
    and a **type-floor grep** holding AUDIT H11's sub-10pt line, which the unit tests
    cannot see.
  **The remaining gap is no longer CI's** — it is that no `VinodexUITests` target
  exists for `ios-test` to run, and that `swift test` has still never been executed
  by a maintainer. See [The testing gap](#the-testing-gap).
  **Now at** `.github/workflows/ci.yml:16-19` (trigger), `:47` (Linux test), `:99`
  (`ios`), `:130` (`ios-test`), `:145` (`data`).

- [x] **M17** · Test · `grapeWellColor`/`styleTone` keyword-to-color logic is pure but sits in the untestable UI module · `Sources/VinodexUI/EntryVisual.swift:72` → move the keyword-to-tone mapping into VinodexCore returning hex strings; test there
  **@0731 STILL OPEN** — Nothing moved. The keyword-to-tone matching is still in the UI
  module returning `Color`, behind the SwiftUI/UIKit guard, and Package.swift:40-43
  still declares only `VinodexCoreTests` depending on `VinodexCore` — so no test can
  even link against it. The file was touched three times since fb5dcf2 (869c3b7,
  adcd77b, a4077a3) without extracting the logic. The source's own doc comment at :111
  states the split that was never completed: 'The palette is generated, the matching is
  here.' The one core-side assertion, CoverageTests.swift:143, only checks the generated
  dictionary is non-empty — it exercises none of the ~14 keyword branches in `styleTone`
  or the 8 fallback branches in `grapeWellColor`.
  **Now at** `Sources/VinodexUI/EntryVisual.swift:87 (`grapeWellColor`) and :113
  (`styleTone`)` → Move both functions into VinodexCore (e.g. a `StyleTone`/`EntryTone`
  helper next to EntryDisplay.swift) with signatures `public static func
  styleToneKey(for style: String) -> String?` and `public static func
  grapeWellHex(style: String, body: String, db: WineDatabase = .shared) -> String`,
  returning hex strings and doing no SwiftUI work. Leave a one-line shim in
  EntryVisual.swift:87 — `Color(dexHex: EntryTone.grapeWellHex(style:body:db:))`. Then
  test in VinodexCoreTests: each of the ~14 `styleTone` keys resolves from at least two
  spelling variants ('full-body red' and 'full bodied red'), each `grapeWellColor`
  fallback branch (red/white x light/full/default, rose, sweet) returns its distinct
  hex, and the empty-style case returns '#78716c'.
  **@0803 RESOLVED by AUDIT M29**, along the exact line this item drew.
  `Sources/VinodexCore/EntryPalette.swift` now holds `styleToneKey(for:)` (`:34`) and
  `grapeWellFallbackHex(style:body:)` (`:79`), recombined by
  `Palette.grapeWellHex(style:body:)` (`:133`); `Palette.resolve` (`:106`) moved with
  them. Hex strings, not `Color` — which is this item's central point, and the
  precedent it follows is `GrapeArt.leafHex(rarity:)`. `EntryVisual.swift` keeps the
  shim. Covered by `Tests/VinodexCoreTests/EntryPaletteTests.swift`.
  **One trap, which is why the "file move" framing understates it.** The ladder's
  literals were uppercase and every value in `palette.json` is lowercase — and
  `bright red`'s tone is `#dc143c`, the *same colour* the ladder returned as
  `#DC143C`. `Color(dexHex:)` parses case-insensitively so nothing ever rendered
  differently, but the first consumer to compare the two strings would have reported
  identical answers as disagreeing. Every hex leaving Core is lowercase now, and a
  test says so.
  **Two tests buy more than this item asked for:** `styleTones` is *generated* while
  the twelve-branch ladder is hand-written, and nothing could have noticed them
  parting company. Now every key the ladder emits is asserted to exist in the
  generated table, and every authored `grapeStyle` in the shipped data is asserted to
  resolve or be the one known exception (`Sparkling Red`, which is what the fallback
  exists for). **This is the proof the extraction pattern works without a device** —
  M18, L19 and L20 are the same shape.

- [ ] **M18** · Test · Country page derivations (grape frequency sort, states, appellations, region counts) are untested pure logic · `Sources/VinodexUI/CountryScreen.swift:154` → extract a CountryPage model into VinodexCore and test its derivations
  **@0731 STILL OPEN** — No `CountryPage` model was extracted; the derivations sit
  exactly where the audit found them, only shifted a few lines by the 0.6 work (commit
  869c3b7 touched this file). Because they are `private` members of a SwiftUI `View`
  behind the UIKit guard, and Package.swift:40-43 declares only `VinodexCoreTests` ->
  `VinodexCore`, none of it is reachable from any test. Only the region *lookup* is
  testable core code — :70 `db.entries.apply(EntryQuery(categories: [.regions], filter:
  .origin(country), search: ""))` — and that is not what the finding is about. The 0.6
  change also made the logic more branchy without adding coverage: `appellations` now
  has two paths (authored `countries.json` list vs the pre-0.6 derived fallback), and
  the authored path is never exercised by a test. The compound sort key at :202
  (`($0.value, $1.key) > ($1.value, $0.key)` — count descending, name ascending as
  tiebreak) is exactly the kind of easy-to-invert tuple comparison that needs a test and
  has none.
  **Now at** `Sources/VinodexUI/CountryScreen.swift:75 (states), :197-203 (notableGrapes
  frequency sort), :267 (appellations), :355 (regionCount)` → Add
  `Sources/VinodexCore/CountryPage.swift`: `public struct CountryPage { public let
  country: String; public let regions: [WineEntry]; public let states: [String]; public
  let notableGrapes: [String]; public let grapeEntries: [WineEntry]; public let
  appellations: [String]; public func regionCount(in state: String) -> Int; public
  init(country: String, db: WineDatabase = .shared) }`, moving the bodies of
  CountryScreen.swift:69-81, :197-203, :267-278 and :355-360 verbatim. Reduce
  CountryScreen to `private var page: CountryPage { CountryPage(country: country, db:
  db) }` and read `page.states` etc. Then add CountryPageTests asserting: notableGrapes
  is count-descending with a name-ascending tiebreak on a two-grape tie; states for
  'USA' is non-empty and sorted while a non-USA country yields []; regionCount(in:) sums
  to regions.count over all states; appellations prefers the authored `countryInfo` list
  and falls back to the derived set when it is absent or empty.
  **@0803 PARTIAL — the derivations were hoisted but not moved, so the perf half is
  done and the testability half is not.** AUDIT **M7** rewrote `CountryScreen` so
  `regions`, `states`, `regionCounts`, `notableGrapes`, `grapeEntries` and
  `appellations` are stored `let`s resolved once in `init` from a single query and a
  single walk (`CountryScreen.swift:80-137`, `init` at `:86`). `regionCount(in:)` —
  the `regions.filter` inside a `ForEach` — is gone, replaced by the `regionCounts`
  dictionary. **That is a straight improvement and it moves this item's anchors, but
  it does not move its status**: they are still `private let`s on a SwiftUI `View`
  behind the UIKit guard, and `Package.swift` still declares only `VinodexCoreTests →
  VinodexCore`, so no test can reach any of them. No `CountryPage.swift` exists.
  **What is now cheaper.** The bodies this item asked to move verbatim are already
  gathered into one `init` instead of scattered across four computed properties, so
  the extraction is closer to a cut-and-paste than it was. And the pattern is proven:
  **M17** did exactly this and closed. The two untested things this item singles out
  are unchanged — the compound sort key (`($0.value, $1.key) > ($1.value, $0.key)`,
  count-descending with a name-ascending tiebreak, at `:128-131`) and the authored-vs-
  derived `appellations` fork (`:134-138`).


## Low

- [ ] **L1** · Compliance · Bundled 217 KB world-map image has no recorded source, author, or license · `Sources/VinodexUI/Resources/Maps/updatedglobemap.jpg` → record the map's origin and license, or regenerate it from documented data
  **@0731 WORSE** — The map itself is unchanged and still carries no recorded source,
  author, or license — the original defect is fully intact. It is WORSE rather than OPEN
  because the bundled-asset surface with no provenance grew from 350 to 492 binary files
  (+142, +41%) and now includes a brand-new media class (4 MP3 audio files) that carries
  its own licensing regime, while the repo still has zero LICENSE, NOTICE, or
  attribution file of any kind.
  **Now at** `/opt/projects/vinodex-
  swift-g/Sources/VinodexUI/Resources/Maps/updatedglobemap.jpg (referenced at
  /opt/projects/vinodex-swift-g/Sources/VinodexUI/RetroGlobeScreen.swift:288)` → Add a
  NOTICE (or ASSETS.md) recording origin + license for updatedglobemap.jpg, and extend
  it to cover the whole 492-file bundled-asset set — at minimum the 4
  Resources/SFX/*.mp3 files, the Resources/Fonts, the Resources/Flags pixel flags, and
  the Iconify-derived Resources/Icons PNGs. Regenerate the map from documented public-
  domain data (e.g. Natural Earth) if its origin cannot be established.
  **@0803 STILL WORSE.** `updatedglobemap.jpg` is byte-identical (216,812 B) with no
  recorded source, and the unprovenanced bundle grew again: **501 binaries** under
  `Sources/`, up from 492 and from 350 at the audit. The map's consumer moved to
  `RetroGlobeScreen.swift` (the file was rewritten by AUDIT M11/M18/M20; search
  `updatedglobemap` rather than trusting the old `:288`). **This is downstream of
  M2** — the NOTICE this item wants cannot be written until the LICENSE question it
  carves out of is answered. AUDIT **H12** did settle provenance for one neighbouring
  class: the 254 drawn PNGs regenerate from `art/`, verified 244/254 pixel-identical
  by `npm run icons:verify`, so their *derivation* is now reproducible even though
  their *rights* are still undocumented.

- [ ] **L2** · Compliance · Back plate displays a fictitious "© HORIZON / ALL RIGHTS RESERVED" copyright notice · `Sources/VinodexUI/DeviceBackPlate.swift:160` → replace the HORIZON flavor text with the real rights holder or drop the notice
  **@0731 STILL OPEN** — The fictitious notice is still rendered, and the change since
  the audit went the wrong way in substance: the creator string was expanded from
  "HORIZON" to "HORIZON/GODOT", inventing a second non-existent rights holder. The only
  thing removed was the separate "CREATED BY" line — the code comment at :257-259 even
  states the maker's mark deliberately "lives in the © line" now. Line number moved from
  the audited 160 to 262.
  **Now at** `/opt/projects/vinodex-swift-g/Sources/VinodexUI/DeviceBackPlate.swift:17
  and :262-263` → Replace `DeviceBackPlate.creator` (line 17) with the actual rights
  holder, or delete the `Text("© ...")` and `Text("ALL RIGHTS RESERVED")` rows at lines
  262-263 and keep only the `SN:` line as chassis flavor text.
  **@0803 STILL OPEN, unchanged in substance.** `DeviceBackPlate.creator` is still
  `"HORIZON/GODOT"` at `:17` and the two rows still render. Lines moved again, 262-263
  → **`:304-305`**. Worth noting the notice is now *doubly* wrong rather than merely
  fictitious: the repo has **no LICENSE at all** (**M2**), so "ALL RIGHTS RESERVED" is
  the app asserting terms the project has explicitly declined to state — and if M2
  resolves to MIT or a split, the back plate will be contradicting the repo. **Take
  L2 with M2**, in that order.

- [ ] **L3** · Compliance · All-alcohol content requires a 17+ age rating at submission; the constraint is documented nowhere · `Sources/VinodexCore/Resources/entries.json:2210` → document the required alcohol-references age rating in the README or a release checklist
  **@0731 WORSE** — The constraint remains documented nowhere, and the exposure grew
  materially: alcohol-domain entries (GRAPES+REGIONS+STYLES) went from 169 to 263
  (+56%), and v0.5.0 added alcohol-themed gamification —
  Sources/VinodexCore/TastingQuiz.swift ("the shape a WSET Level 1 paper asks them"),
  DailyChallenge.swift ("one short quiz per local day"), and Passport.swift — which push
  the content toward App Store's 'Frequent/Intense Alcohol, Tobacco, or Drug Use or
  References' tier rather than away from it.
  **Now at** `/opt/projects/vinodex-swift-g/Sources/VinodexCore/Resources/entries.json
  (now minified to 1 line; audited line 2210 no longer exists) — and the missing
  documentation in README.md / KNOWN-ISSUES.md / arch.md` → Add a release/submission
  checklist (README.md or a RELEASE.md) recording the required App Store age rating for
  frequent alcohol references (17+ under the legacy scale / 18+ under the current one),
  and note it alongside the already-tracked A2 privacy-manifest and M35 bundle-ID gates
  so the three land together.
  **@0803 STILL WORSE — but it finally has somewhere to land.** Grepped: no mention
  of an age rating in `README.md`, `KNOWN-ISSUES.md` or `CHANGELOG.md`. The exposure
  grew again with the catalogue — alcohol-domain entries (GRAPES + REGIONS + STYLES)
  are now **293**, from 263 at the last pass and **169 at the audit**.
  **What changed is the destination.** AUDIT **L22** added a real **Release
  checklist** to `README.md:176-201`, with four numbered gates (toolchain, data
  currency, asset probe, test gates) whose first two lines go into the tag
  annotation. This item is now a fifth entry in an existing list rather than a
  document somebody has to invent — and the two items it asked to be filed beside,
  the privacy manifest (**H3**) and the bundle ID (**H4**), both belong in the same
  list for the same reason. **One paragraph, one file, already-open section.**

- [x] **L4** · Compliance · `Diagnostics.emit()` logs app state to syslog on every launch with no DEBUG guard · `Sources/VinodexApp/VinodexApp.swift:216` → wrap in `#if DEBUG` or use os.Logger at debug level
  **@0731 STILL OPEN** — The file was heavily rewritten (165 insertions) but Diagnostics
  is untouched: still called unconditionally from the App's `init()`, still writing
  entry counts, decodeErrors and every continent's full region list to syslog via NSLog
  on every launch of a release build. The only enclosing conditional is the file-level
  `#if canImport(SwiftUI)` at line 1, which is a platform guard, not a build-
  configuration guard. Line number moved from the audited 216 to 349.
  **Now at** `/opt/projects/vinodex-swift-g/Sources/VinodexApp/VinodexApp.swift:9 (call
  site) and :349-368 (Diagnostics.emit)` → Wrap the `Diagnostics.emit()` call at
  VinodexApp.swift:9 in `#if DEBUG` / `#endif`, or convert the loop at :363-366 to
  `os.Logger(subsystem:category:).debug(...)` with `%{private}@` interpolation so
  release builds redact the payload.
  **@0803 RESOLVED by AUDIT M6**, taking the first branch of the remedy. The call is
  now `#if DEBUG` / `Diagnostics.emit()` / `#endif` at `VinodexApp.swift:52-54`, so a
  release build writes nothing to syslog. **The fix went further than this item
  needed, for a different reason.** M6 was a *performance* finding — the same `init`
  was running six full filter+sort passes over the catalogue synchronously on the
  first-frame path — so the whole block moved into a detached `.userInitiated` task,
  which also serves as the off-main database warm-up. So the diagnostics are now
  DEBUG-only *and* off the launch path; the item asked for the first and got both.
  **Now at** `VinodexApp.swift:38-54` (the task and the guard), `:476`
  (`enum Diagnostics`).

- [ ] **L5** · Security · Shipped icon PNGs come from unpinned api.iconify.design downloads validated only by an `<svg` sniff — no version pin or checksum · `scripts/rasterize-icons.sh:56` → vendor the SVG sources, or pin icon-set versions and verify checksums
  **@0731 STILL OPEN** — Mechanism is completely unchanged: unversioned
  api.iconify.design fetch, no integrity check beyond a case-insensitive '<svg' match on
  the first 200 bytes, and the rendered PNGs are committed. The blast radius shrank
  rather than grew — icons.json 'unique' dropped from 99 to 66 entries and the committed
  Icons tree from 318 to 198 PNGs, because v0.5.7 moved much of the taxonomy to locally
  drawn `art:` ids. Note the same commit added a chained pipeline at :177-184 running
  four local Python importers, which are NOT network-sourced and do not extend this
  finding.
  **Now at** `/opt/projects/vinodex-swift-g/scripts/rasterize-icons.sh:57 (unpinned URL)
  and :67 (the sniff)` → Vendor the 66 SVGs from icons.json's `unique` list into a
  committed scripts/icons-src/ tree, or add a checksums file (slug -> sha256) consulted
  after the curl at line 59 and before rasterizing, plus an explicit Iconify icon-set
  version in the URL so a silently-updated upstream glyph cannot land in the bundle.
  **@0803 STILL OPEN — mechanism unchanged, and there is now a completed plan sitting
  behind an unauthorised fetch.** `rasterize-icons.sh:81` still builds
  `https://api.iconify.design/${prefix}/${name}.svg?color=white` with no version and
  no checksum, validated only by the `<svg` sniff. Corpus is flat at 68 unique / 204
  PNGs. AUDIT **M40** was **deferred on 2026-08-03 at the maintainer's direction**:
  the fix vendors the 68 SVGs (~150–250 KB) into `art/iconify/`, and that network
  fetch was not authorised in the pass. Three things it established that are worth
  keeping, because they change how this should be done:
  - **`@iconify-json` pinning loses**, even though `package-lock.json` is now tracked
    and would genuinely pin it: one glyph (`mdi:help-circle-outline`) drags in a
    ~7,500-icon package, the rasteriser is bash/curl/python3 and touches Node
    nowhere, and consuming IconifyJSON means reimplementing `iconToSVG` in bash.
    **Vendor the SVGs.**
  - **`?color=white` is load-bearing and its loss is invisible.** Drop it and
    `rsvg-convert` resolves `currentColor` to black — identical alpha, inverted RGB,
    **all 204 files byte-different, and no visual symptom**, because `DexIcon` renders
    them as templates and UIKit discards the RGB.
  - **Do not vendor from `game-icons.net` directly** — that yields 55 solid black
    squares, because Iconify strips a full-bleed background rect the upstream SVGs
    carry.
  A fingerprint was taken so "not a single pixel changed" is checkable afterwards
  without a renderer: `python3 scripts/recompress-png.py --check
  Sources/VinodexUI/Resources/Icons` reports **204 files, 729,772 B, 204
  recompressible, 78,661 B (10.8%)** — four numbers that move if any PNG does.

- [ ] **L6** · Security · Missing or malformed tiers.json silently unlocks all paid entries and never surfaces in `decodeErrors`; the generator never asserts tiers output · `Sources/VinodexCore/WineDatabase.swift:253` → record the decode failure in `decodeErrors` (keeping fail-open) and assert `tiers.free` non-empty in the generator
  **@0731 PARTIAL** — v0.6.3's robustness spine genuinely closed the corrupt-manifest
  half — a malformed tiers.json now lands in decodeErrors and raises the launch alert
  seeded at VinodexApp.swift:28. Two gaps remain. (1) The generator assertion the audit
  asked for was not added: validateOutputs checks only presence and Array-ness, so an
  emitted `{"free":[]}` passes the self-check, decodes cleanly in Swift, produces zero
  decodeErrors, and silently unlocks all 375 entries via the `freeIDs.isEmpty` short-
  circuit. (2) A wholly missing tiers.json is still swallowed by the `.fileNoSuchFile`
  catch with no record — that is the documented fail-open, but it is also still silent.
  **Now at** `Swift half fixed at /opt/projects/vinodex-
  swift-g/Sources/VinodexCore/WineDatabase.swift:476-489; generator half still open at
  /opt/projects/vinodex-swift-g/scripts/generate-ios-data.ts:1095-1098; unlock rule at
  WineDatabase.swift:372` → In scripts/generate-ios-data.ts:1096, strengthen to `if
  (!Array.isArray(free) || free.length === 0) problems.push('tiers.json free[] is empty
  — every entry would be unlocked')`. Optionally also append a low-severity note to
  `loadErrors` in the `.fileNoSuchFile` branch at WineDatabase.swift:485 so the fail-
  open is visible in the DEV panel rather than indistinguishable from a healthy free
  build.
  **@0803 PARTIAL — gap (2) closed, gap (1) untouched.** AUDIT **M46** rebuilt the
  loader around `ResourceLoad<T>`, and tiers now runs through the same three-outcome
  switch as everything else (`WineDatabase.swift:684-692`): `.missing` appends
  **`"tiers.json is not bundled — every entry is free"`** to `loadNotices`, `.corrupt`
  appends a fault to `decodeErrors`. So **the wholly-missing case is no longer
  silent** — it is a maintainer-visible notice in the DEV panel, which is exactly the
  optional half this item proposed, and the fail-open behaviour is preserved. The
  notice/fault split is AUDIT M45's: a *fault* means the app lost data and a user can
  see it, a *notice* means a documented fallback took effect. `LoaderFallbackTests`
  pins it — *"tiers keep M1's missing-versus-corrupt split"*.
  **Gap (1) is verbatim.** `scripts/generate-ios-data.ts:1305-1307` still reads
  `if (!has(tiers,'free') || !Array.isArray(tiers.free)) problems.push('tiers.json
  missing free[]')` — presence and Array-ness only. An emitted `{"free":[]}` still
  passes the self-check, decodes cleanly, produces **zero** decodeErrors and **zero**
  notices, and silently unlocks all **405** entries through the `freeIDs.isEmpty`
  short-circuit at `WineDatabase.swift:459`. This is a one-line change and it is the
  same line **L17** wants to extend. Note the free set is now 180 ids, all resolving
  — verified 2026-08-03.

- [x] **L7** · Security · GlobeModel's display link is invalidated only via `onDisappear` with no deinit fallback, leaking ticks · `Sources/VinodexUI/RetroGlobeScreen.swift:344` → invalidate the display link from GlobeModel `deinit` as a fallback
  **@0731 STILL OPEN** — Unchanged. The run loop retains the CADisplayLink, which
  retains DisplayLinkProxy; GlobeModel is reachable only weakly from the tick closure,
  so the model can deallocate while the link keeps firing at display refresh rate
  forever. If onDisappear is skipped or the view is torn down out of band, the ticks and
  the saveHeading() write are both lost. Line moved from the audited 344 to 406.
  **Now at** `/opt/projects/vinodex-
  swift-g/Sources/VinodexUI/RetroGlobeScreen.swift:398-410 (start/stop) — onDisappear at
  :92, model at :25` → Add to GlobeModel a nonisolated deinit that invalidates the link
  without touching main-actor state — e.g. hold the link in a small final class box
  captured by the proxy, or `deinit { displayLink?.invalidate() }` with `displayLink`
  made `nonisolated(unsafe)` — so teardown does not depend on onDisappear firing. Keep
  `stop()` as the normal path since it also calls saveHeading().
  **@0803 RESOLVED by AUDIT L10 — and the fix proposed above could not have worked.**
  A `deinit` on `GlobeModel` is unreachable while the link is live: the run loop
  retains the `CADisplayLink`, which retains `DisplayLinkProxy`, so the model never
  deallocates at the moment teardown is needed. `RetroGlobeScreen.swift:945-948` now
  records this in the source — *"`deinit` on the model could never have done it"*.
  What landed instead: `GlobeSceneView.makeCoordinator()` returns the model so the
  **static** `dismantleUIView` can reach it (`:413-415`), calling `detach(from:)`
  (`:728`), which invalidates **only if the view being dismantled is still the one
  the model holds**. `DisplayLinkProxy` also takes the link off the run loop when its
  target has gone, which is the `deinit` half by another route. `stop()` stays the
  normal path and still calls `saveHeading()`.
  **The conditional is the whole fix, not a detail.** SwiftUI may build the
  replacement before dismantling the original on an `.id(…)` change — and
  `GlobeSceneView` is `.id("\(lcd)|\(skin)")`-keyed — so an unconditional `stop()`
  there would have killed the *new* link and frozen the globe on the first skin
  change. The restart guard in `start()` (`displayLink == nil`) landed in the same
  edit for that reason.

- [ ] **L8** · Security · StatBar traps on negative or non-finite maximum via `ForEach(0..<Int(maximum))` — unreachable today but one data edit away · `Sources/VinodexUI/CatalogScreen.swift:258` → clamp the range with `max(0, Int(maximum.rounded()))`
  **@0731 STILL OPEN** — Completely unchanged, same line number as audited (258).
  `Int(maximum)` traps on NaN/infinity and `0..<n` with n<0 traps with 'Range requires
  lowerBound <= upperBound'. Still latent because no caller overrides `maximum`, but
  StatBar is `public` with a `public init`, so the trap is one call site away. Nothing
  in the v0.5.x/v0.6.x work touched it, and no other ForEach in VinodexUI uses a
  computed range — all six other hits are integer literals (0..<6, 0..<3, 0..<2).
  **Now at** `/opt/projects/vinodex-swift-g/Sources/VinodexUI/CatalogScreen.swift:258` →
  At CatalogScreen.swift:258 replace `ForEach(0..<Int(maximum), id: \.self)` with a
  clamped, finite-safe bound, e.g. compute `private var segments: Int { maximum.isFinite
  ? max(0, Int(maximum.rounded())) : 0 }` and use `ForEach(0..<segments, id: \.self)`.
  **@0803 STILL OPEN**, unchanged, now at **`CatalogScreen.swift:296`**. `maximum` is
  still `public var maximum: Double = 5` with a `public init` (`:239`, `:242`), so the
  trap is still one call site away. AUDIT **M49** worked on this exact type — it
  derived `StatBar.labelWidth` from the type scale to stop AROMATICS overflowing the
  96pt well — and **left the `ForEach` alone**, which is worth knowing: someone was in
  this view, doing arithmetic on it, and this line survived. Still the cheapest fix in
  the file.

- [ ] **L9** · Compliance · GNU-only `mktemp --suffix` kills the script immediately on macOS, and python3 is never preflighted · `scripts/rasterize-icons.sh:54` → use the portable mktemp template syntax and preflight python3 like rsvg-convert
  **@0731 PARTIAL** — Half resolved. The GNU-only `mktemp --suffix` is gone and the
  replacement is verified working under BSD mktemp, so the script no longer dies on line
  55 on macOS. The preflight half is untouched: python3 is invoked at lines 38, 108, 152
  and 179 with no `command -v` check, so a machine without it fails at line 38 under
  `set -euo pipefail` with a bare 'python3: command not found' instead of the actionable
  message rsvg-convert gets. The gap also widened slightly — the new importer chain at
  :177-184 (`for importer in import-flavor-art.py import-grape-art.py import-style-
  art.py import-class-art.py`) adds a Pillow dependency (documented only in a comment:
  "Requires Pillow (apt: python3-pil)") that is likewise never preflighted.
  **Now at** `mktemp fixed at /opt/projects/vinodex-swift-g/scripts/rasterize-
  icons.sh:55; python3 preflight still missing — only rsvg-convert is checked at :32,
  python3 first used unguarded at :38 (also :108, :152, :179)` → Add next to the rsvg-
  convert check at rasterize-icons.sh:32: `command -v python3 >/dev/null || { echo
  "python3 not found (Linux: apt install python3 • macOS: brew install python)"; exit 1;
  }`, and when SKIP_ART is unset also preflight Pillow with `python3 -c 'import PIL'
  2>/dev/null || { echo "Pillow not found (apt install python3-pil / pip install
  Pillow); set SKIP_ART=1 to skip the art importers"; exit 1; }` before the loop at
  :178.
  **@0803 PARTIAL — the Pillow half landed, the python3 half did not, and the two
  now interact badly.** AUDIT **H12** added a Pillow preflight at
  `rasterize-icons.sh:45` (`python3 -c 'import PIL'`), deliberately non-fatal: a
  machine without Pillow still regenerates every Iconify glyph and copies the flags,
  and `SKIP_ART=1` now announces itself the way `SKIP_FLAGS=1` always did. That is
  this item's second clause, done.
  **But `command -v python3` is still missing** — only `rsvg-convert` is checked, at
  `:59` — and python3 is used unguarded at `:64`, `:132` and `:193`. The interaction
  is new and makes the diagnosis worse than it was: on a machine with **no python3 at
  all**, line 45's probe fails with `2>/dev/null` swallowing the reason and prints
  **"Pillow not found"**, which is the wrong cause; the run then continues past the
  rsvg check and dies at `:64` with a bare `python3: command not found` under
  `set -euo pipefail`. Two lines beside the `rsvg-convert` check fix both.

- [ ] **L10** · Security · Manifest icon slugs and flag relpaths are interpolated into URLs, filenames, and `cp` paths without sanitization · `scripts/rasterize-icons.sh:112` → validate slugs, countries, and relpaths against a strict allowlist pattern
  **@0731 STILL OPEN** — Commit 26a2a3e ("harden rasterize-icons.sh") landed in this
  range but hardened different things: portable mktemp, atomic 3-scale moves, orphan
  pruning, explicit SKIP_FLAGS. Zero sanitization was added. The `tr '[:upper:] '
  '[:lower:]-'` on line 144 lowercases and replaces spaces but leaves `/` and `..`
  intact, so a country key of `../../x` still escapes $FLAGDIR. Manifest size is roughly
  flat (unique 99->66, flags 28->29), so the exposure did not grow.
  **Now at** `/opt/projects/vinodex-swift-g/scripts/rasterize-icons.sh:51, :57, :83,
  :143-146` → Before use, reject any manifest-derived string that is not
  `[A-Za-z0-9._-]+` (prefix/name/country) or a relative path with no `..` segment and no
  leading `/` (relpath). Add the same assertion to `validateOutputs` in
  scripts/generate-ios-data.ts:1064 so a bad manifest fails generation rather than the
  rasteriser.
  **@0803 PARTIAL — one interpolation is now generator-controlled, the rest are not.**
  AUDIT **L25** removed the `tr '[:upper:] ' '[:lower:]-'` recomputation this item
  named: the destination filename comes from the generator's **`flagSlugs`** table
  (`rasterize-icons.sh:171-190`), and a missing entry now fails loudly rather than
  falling back. That is the output side. **The input side is unchanged** — `src` is
  still `"$PIXELFLAGS/$relpath"` at `:173` with `relpath` read straight from the
  manifest, so a crafted `../../x` still escapes the flag directory, and `prefix`/
  `name` are still interpolated into the Iconify URL at `:81` unvalidated.
  **The threat model is unchanged and still narrow** — the manifest is generated from
  `shared/` by a script in this repo, so this is defence against a bad generator
  edit, not against a remote attacker. But `validateOutputs` is exactly where the
  assertion belongs, and AUDIT **M3** rebuilt that function around declared contract
  tables (`generate-ios-data.ts:1182`), so there is now a structured place to add it
  that did not exist when this was written.

- [ ] **L11** · Security · .gitignore has no patterns for signing certificates, provisioning profiles, keys, or .env files · `.gitignore` → add `*.p12`, `*.mobileprovision`, `*.pem`, `*.p8`, and `.env` patterns
  **@0731 STILL OPEN** — Untouched since the audit. Still relevant: xtool.yml carries a
  bundleID and the documented device workflow signs locally, so a .mobileprovision or
  .p12 landing in the tree would be committed by a bare `git add -A`. arch.md itself
  flags this ("This is the single most likely route by which a credential enters this
  repo. -> Append those seven patterns.") but the patterns were never appended.
  **Now at** `/opt/projects/vinodex-swift-g/.gitignore (whole file, 15 lines)` → Append
  to .gitignore: `*.p12`, `*.mobileprovision`, `*.provisionprofile`, `*.cer`,
  `*.certSigningRequest`, `*.pem`, `*.p8`, `*.key`, `.env`, `.env.*`. Optionally add a
  pre-commit hook or CI grep so the patterns are enforced rather than advisory.
  **@0803 STILL OPEN — untouched across two passes.** `.gitignore` is 15 lines and
  carries none of the ten patterns; it grew only by `scripts/__pycache__/`. `arch.md`
  still flags it as *"the single most likely route by which a credential enters this
  repo"* and still ends with *"Append those seven patterns"*, unappended.
  **The exposure is larger than it was**, and by the working tree's own doing: the
  tree currently holds **85 dirty paths and 26 untracked files**, which is exactly the
  state where someone reaches for `git add -A`. This is a ten-line append with no
  code impact and it is the last item in this file that costs nothing to take.

- [x] **L12** · Compliance · Committed doc embeds the developer's personal Windows username and home path in an rsync example · `KNOWN-ISSUES.md:145` → replace the personal path with a neutral placeholder like `/mnt/c/<repo-root>/ios/`
  **@0731 PARTIAL** — The suspicion that d5383b5 re-introduced the
  personal path is half right: d5383b5 did keep
  `/mnt/c/Users/StreetPC/Desktop/HGapps/...`, but the later commit 4b75fae replaced it
  with a drive path carrying no username and no home directory. No committed file at
  HEAD leaks a Windows username, a home path, or an email address. A machine-specific
  absolute path (`/mnt/h/vscode-projects/HGapps/`) remains, but it identifies no person
  and is not what the finding described.
  **@0803 RESOLVED.** Re-grepped the whole tree for `StreetPC`, `/mnt/c/Users` and
  home-directory patterns: **no committed file leaks a username, a home path or an
  email address.** `KNOWN-ISSUES.md:198` now reads
  `wsl.exe -d xtool-ubuntu -- bash /mnt/c/Users/.../script.sh`, elided exactly as the
  remedy proposed. The machine-specific `/mnt/h/vscode-projects/HGapps/` at `:257`
  stays, and stays out of scope: it identifies a drive, not a person. Ticked rather
  than left partial — the finding as written is answered, and the residual was already
  recorded as not-the-finding at the last pass.

- [ ] **L13** · Test · All logic tests couple to the bundled dataset; empty and single-entry database behavior is untested · `Sources/VinodexCore/WineDatabase.swift:221` → add fixture-database tests covering empty and single-entry pools
  **@0731 WORSE** — WORSE by growth, not by regression: the coupling is unchanged but
  the code it fails to cover roughly tripled. Newly added empty-pool branches that no
  test can reach include DailyPick.swift:60 `guard !pool.isEmpty else { continue }`,
  DailyPick.swift:64 `return nil`, and DailyPick.swift:126 `guard !pool.isEmpty else {
  return nil }`, plus every db-derived accessor in the new Passport, TastingQuiz,
  ChipFilter, GrapeScan and DailyChallenge modules. The catch-all empty-DB init at
  WineDatabase.swift:506 (entries: [], emptyPalette, all-empty IconManifest) existed at
  fb5dcf2 and is still never constructed by a test.
  **Now at** `/opt/projects/vinodex-swift-g/Tests/VinodexCoreTests/ (all 15 files);
  empty-DB fallback at Sources/VinodexCore/WineDatabase.swift:506-530` → Add a fixture
  helper (e.g. `func makeDB(_ entries: [WineEntry]) -> WineDatabase`) and a suite that
  drives the zero-entry and one-entry cases through
  DailyPick.grape/entry/entry(cursor:), Passport totals, ChipFilter counts, TastingQuiz
  session building and WineDatabase.entry(named:) — asserting nil/empty rather than a
  crash or a modulo-by-zero.
  **@0803 PARTIAL — the fixture helper this item asked for exists, and two of its
  seven consumers use it.** `Tests/VinodexCoreTests/DatabaseFixture.swift`
  (`DBFixture.database(_:)`, AUDIT **M32**) is the helper, built from JSON fragments
  rather than Swift literals because all five `WineEntry` variants declare
  `init(from:)` in the type body and therefore cannot be constructed by hand at all.
  Two suites drive it: `DailyRevealTests` reaches every empty-pool branch this item
  named (`DailyPick.swift:60`'s `continue`, `:64`'s `return nil`, and the cursor
  overload) and `FilterTests` reaches `.soil`, which no shipped call site constructs.
  A second seam landed beside it — `WineDatabase(reading: .fixture(...))` from AUDIT
  **M46** — which covers the whole-database-empty case from the loader side, including
  *a well-formed but empty catalogue is still a fault*.
  **Still uncovered, and now a small job rather than a blocked one:** Passport totals,
  ChipFilter counts, `TastingQuiz` session building and `WineDatabase.entry(named:)`
  against zero- and one-entry pools. Every one of those is a `DBFixture.database(…)`
  call plus an assertion. The catch-all empty-DB init (`WineDatabase.swift:506`) is
  still never constructed directly, though `.fixture([:])` now exercises the same
  fallback path.

- [ ] **L14** · Test · DailyPick is tested only with a UTC calendar — local-midnight turnover and DST behavior are unverified · `Sources/VinodexCore/DailyPick.swift:12` → add tests with non-UTC/DST calendars and midnight-boundary dates
  **@0731 WORSE** — WORSE by spread. At fb5dcf2 `calendar: Calendar = .current` appeared
  5 times, all in DailyPick.swift. At HEAD it appears 12 times across three modules —
  DailyPick.swift (6: dayIndex, category, entry(for:), grape, isSameDay,
  entry(cursor:)), MoonCalendar.swift (4, lines 96/104/120/135) and DailyChallenge.swift
  (2, lines 22/26). The new date-driven features (streak chaining in StreakStore, the
  moon dial's day type, the daily paper) all inherited the UTC-only convention, so
  local-midnight turnover and DST are unverified across the whole date surface rather
  than just one file.
  **Now at** `/opt/projects/vinodex-
  swift-g/Tests/VinodexCoreTests/DailyPickTests.swift:9-13 and
  MinigameTests.swift:14-17, 190-193; production default at
  Sources/VinodexCore/DailyPick.swift:14` → Parameterise the existing date suites over
  at least three calendars — UTC, a large negative offset (America/Los_Angeles) and a
  DST-transition zone — and add explicit cases: two instants straddling local midnight
  must yield different dayIndex values, and the 23-hour and 25-hour DST days must each
  advance dayIndex by exactly 1. Cover StreakStore chaining and MoonCalendar.quote with
  the same matrix.
  **@0803 STILL WORSE — untouched, and the six new date tests inherited the
  convention.** Grepped the whole test target for `America/`, `TimeZone(identifier:`
  and `DST`: **one hit**, `DailyChallengeTests.swift:11`, and it is `"GMT"`. Every
  other date suite still runs UTC-only. AUDIT **M32** added six date tests to
  `DailyRevealTests` on 2026-08-03 — including the pre-epoch and negative-index cases
  at `MinigameTests.swift:344` and `:356`, which are precisely boundary tests — and
  every one of them uses the same fixed-offset calendar. So the audit's point stands
  sharper than before: **the convention is now being copied by tests written to
  examine boundaries.** Local-midnight turnover and DST remain unverified across
  `DailyPick`, `MoonCalendar` and `DailyChallenge` alike. Parameterising the existing
  suites over three calendars is still the fix, and doing it now costs less than
  doing it after the next date feature.

- [x] **L15** · Test · `DexRoute.title`, `WineEntry.scanTitle`, and the `.detail` destination branch have no tests · `Sources/VinodexCore/DexRoute.swift:37` → add a table-driven test over title, scanTitle, and destination
  **@0731 WORSE** — All three items named in the finding remain untested. The single new
  test covers a fourth thing (the `.continent` destination branch added in v0.5.7),
  which does not touch any of them. Meanwhile the untested surface in this file roughly
  doubled and gained two entirely new untested computed properties.
  **Now at** `/opt/projects/vinodex-swift-g/Sources/VinodexCore/DexRoute.swift:113
  (title), :167 (marqueeSymbol), :235 (destination, .detail branch), :241 (scanTitle)` →
  Add a DexRouteTests suite: assert `WineEntry.destination` returns `.detail(entryID:
  id)` for a grape/region/flavor/style; assert `scanTitle` and `scanSymbol` for all five
  WineEntry cases; and iterate a constructed list of all 25 DexRoute cases asserting
  `title` and `marqueeSymbol` are non-empty and mutually distinct where intended (a
  CaseIterable-style fixture array keeps new cases from silently escaping).
  **@0803 RESOLVED by AUDIT M47**, in
  `Tests/VinodexCoreTests/RouteAndSearchStateTests.swift`. `DexRouteTests` (5 tests)
  covers all three named items and takes the CaseIterable-style approach this item
  recommended: `everyRouteIsLabelled` walks all **28** constructible routes asserting
  `title` and `marqueeSymbol`. Both properties are exhaustive switches, so a new case
  cannot compile without an answer — but an *empty* answer compiles fine and renders
  as a blank marquee, which only the walk catches, which is the argument this item
  made. `scanTitle`/`scanSymbol` are pinned for all five `WineEntry` cases (`:190`,
  `:199`) and the `.detail` destination fall-through is covered.
  **One correction to the item, from M47:** `ContinentTests.swift` already covered one
  branch of `WineEntry.destination` — the `.continent` early return — so "the `.detail`
  destination branch has no tests" was true of `.detail` specifically, not of
  `destination`. The rest was accurate.

- [ ] **L16** · Test · TextNormalize `label`/`key`/`term`/`matchesWholeTerm` underpin all search but have no direct unit tests · `Sources/VinodexCore/EntryFilter.swift:9` → add direct unit tests for the four functions with edge-case inputs
  **@0731 STILL OPEN** — Unchanged gap, but a much wider blast radius: TextNormalize
  call sites in Sources went 31 -> 96, and from 1 file (EntryFilter.swift) to 11 (now
  also GrapeArt.swift, ChipFilter.swift, TastingQuiz.swift, Passport.swift and others).
  Not marked WORSE because the untested code itself is byte-identical; the risk, not the
  defect, grew.
  **Now at** `/opt/projects/vinodex-swift-g/Sources/VinodexCore/EntryFilter.swift:16
  (label), :21 (key), :32 (term), :43 (matchesWholeTerm)` → Add a TextNormalizeTests
  suite with table-driven cases: `label` folds diacritics and case ("Grüner Veltliner"
  -> "gruner veltliner"); `key` collapses punctuation and runs of separators to single
  spaces and trims; `term` maps only `_-/(),.;` to spaces; and `matchesWholeTerm`
  returns true on exact and whole-word-inside matches but false on prefix/substring
  matches ("Chile" must not match "Chilean-style" via a bare contains) and false when
  either side normalises to empty.
  **@0803 STILL OPEN, and it just became load-bearing in a new place.** No
  `TextNormalizeTests`; `TextNormalize` is still only ever exercised incidentally,
  through assertions about something else, across seven test files. The blast radius
  is unchanged from the last count (96 call sites, 11 files).
  **What is new: `matchesWholeTerm` gained a second consumer, and it was a bug fix.**
  AUDIT **M33** found `EntryDisplay.colorType` matching colour words as substrings —
  which labelled **`Prosecco` a rosé**, because "rose" sits inside "p-*rose*-cco" —
  and fixed it by routing through `matchesWholeTerm`, the same whole-term test
  `.origin` has always used. So the function this item wants pinned is now the thing
  standing between the catalogue and a repeat of that bug, and it still has no direct
  test. **L26** wants the same function tested from the other end. Write one suite
  and both items shrink.

- [ ] **L17** · Test · No test verifies every tiers.json free id resolves to an existing entry · `Sources/VinodexCore/WineDatabase.swift:243` → assert every `freeIDs` member resolves via `db.entry(id:)`
  **@0731 STILL OPEN** — No test added in this range. The surface to drift grew:
  tiers.json free[] went 132 -> 153 ids and entries.json 284 -> 375, and both files are
  regenerated together by commits like 869c3b7, which is exactly the situation where a
  renamed id silently drops out of the free tier. A stale free id degrades quietly —
  `isFree` just returns false for an id nobody looks up — so only a test will catch it.
  **Now at** `/opt/projects/vinodex-swift-g/Sources/VinodexCore/WineDatabase.swift:277
  (freeIDs) and :481-489 (tiers load)` → Add to AccessTests: `for id in db.freeIDs {
  #expect(db.entry(id: id) != nil, "tiers.json free id \(id) has no entry") }`, plus a
  companion assertion that the free set is non-empty. Mirror it in `validateOutputs`
  (scripts/generate-ios-data.ts:1064) so generation fails before the drift is committed
  and the CI generated-data drift check catches it.
  **@0803 STILL OPEN, and the surface grew again.** No test references `db.freeIDs`.
  `tiers.json` free[] is now **180 ids** (132 at the audit, 153 at the last pass) and
  `entries.json` is **405** — both regenerated together by the batch-2 expansion
  (`295bda8`), which is exactly the situation this item is about. **Verified by hand
  2026-08-03: all 180 free ids resolve to an entry, so there is no live drift** — this
  is purely an unguarded invariant, as it was. The `validateOutputs` half is the same
  line **L6** wants strengthened, and AUDIT **M3** rebuilt that function around
  declared contract tables, so both assertions now have an obvious shape to follow.

- [ ] **L18** · Test · `BookmarkStore.remove(_:)`, used by swipe-delete in BookmarksScreen, has zero test coverage · `Sources/VinodexCore/Bookmarks.swift:48` → add remove() present/absent tests and displayName assertions
  **@0731 WORSE** — WORSE: the untested method itself grew. At fb5dcf2 remove was 4
  lines against a single id list (`guard let index = ids.firstIndex(of: id) else {
  return }; ids.remove(at: index); persist()`). It now dispatches across three shelves
  and carries a data-destroying side effect — `clearRating(for: id)` wipes the user's
  rating and note when the shelf is .tried — and that side effect has zero coverage even
  though removeAll(on: .tried)'s equivalent cleanup IS tested (BookmarkTests.swift:205).
  The un-suffixed facade at :103 is also now unreferenced anywhere in Sources/, so it is
  both untested and unexercised.
  **Now at** `/opt/projects/vinodex-swift-g/Sources/VinodexCore/Bookmarks.swift:103
  (facade) and :178-184 (implementation)` → Add BookmarkTests cases: remove(_:on:) drops
  only the named id and leaves the rest in order; removing an id not on the shelf is a
  no-op and does not touch persistence; removing from .tried also clears that id's
  TriedRating while leaving other ratings intact; removing from .saved or .wantToTry
  leaves ratings untouched; and the un-suffixed remove(_:) hits the saved shelf only.
  Either cover or delete the now-unused facade at Bookmarks.swift:103.
  **@0803 STILL WORSE — unchanged, and a neighbouring fix walked right past it.**
  `grep '\.remove(' Tests/VinodexCoreTests/BookmarkTests.swift` returns **nothing**:
  none of the 15 tests in that suite touches either `remove` overload. The
  data-destroying side effect is intact — `remove(_:on:)` calls `clearRating(for:)`
  on the `.tried` shelf, wiping the user's rating *and* their written note — while
  `removeAll(on: .tried)`'s equivalent cleanup is still tested at
  `BookmarkTests.swift:205`. The un-suffixed facade at `Bookmarks.swift:123` is still
  unreferenced in `Sources/`; the only production caller is
  `BookmarksScreen.swift:204`, which uses the shelf form.
  **AUDIT L37 was in this exact code and did not add the test.** It examined the ✕
  confirm dialog, concluded the *comment* was wrong rather than the code — precisely
  because "cheap to redo" does not hold on the TRIED shelf, *"where `remove(_:on:)`
  takes the rating and the written note with the row"* — and rewrote the dialog copy
  to say so. So the destructive behaviour this item wants pinned is now **documented
  in two places and asserted in none**. Lines: facade `:123`, implementation `:198`.

- [ ] **L19** · Test · Diagnostics OK/fail string-matching against `DexFont.statusReport` wording sits inline in a View, untestable · `Sources/VinodexUI/DiagnosticsReport.swift:19` → extract report lines into a pure `(text, ok)` model and test it
  **@0731 STILL OPEN** — Unchanged since fb5dcf2 and still untestable: the OK/fail
  predicate is an inline expression in a SwiftUI `body`, coupled to three separate
  literal spellings in DexFont.statusReport with no shared constant. Concretely it
  already mis-reports: the line `registered 0/2` contains neither "FALLBACK" nor the
  "FAILED" prefix, so a build where both faces failed to register still renders that
  line with a green "OK" badge. Nothing in the repo can assert this because VinodexUI
  has no test target.
  **Now at** `/opt/projects/vinodex-
  swift-g/Sources/VinodexUI/DiagnosticsReport.swift:19` → Move the health decision into
  VinodexCore (or a UIKit-free file in VinodexUI) as a value type, e.g. `public struct
  DiagnosticLine { public let text: String; public let ok: Bool }` plus `public static
  func fontDiagnostics(registered: Int, expected: Int, retroAvailable: Bool,
  monoAvailable: Bool, failed: [String]) -> [DiagnosticLine]`, returning `ok` from the
  booleans rather than by re-parsing prose (and marking `registered n/2` not-ok when n <
  2). DiagnosticsReport.body then becomes `ForEach(lines) { row($0.text, ok: $0.ok) }`,
  and add a VinodexCoreTests case covering the all-failed, one-fallback and all-OK
  inputs.
  **@0803 STILL OPEN, and the mis-report is confirmed live.** The predicate is
  unchanged at `DiagnosticsReport.swift:19` —
  `row(line, ok: !line.contains("FALLBACK") && !line.hasPrefix("FAILED"))` — an inline
  expression in a `body`, coupled to three literal spellings produced twenty lines
  apart in `DexFont.statusReport` (`DexTheme.swift:470-476`). Re-read both sides on
  2026-08-03 and the defect holds exactly as described: `statusReport`'s first line is
  `"registered \(registration.registered.count)/2"`, which contains neither
  `"FALLBACK"` nor a `"FAILED"` prefix — **so a build where both faces failed to
  register renders `registered 0/2` with a green OK badge.**
  **The file grew around it without the predicate changing.** AUDIT **M45** added
  `loadNotices` rows and AUDIT **L26** replaced the count-only asset rows with
  `DexAssetAudit`, which resolves every manifest id through the bundle and returns its
  own `(line, ok)` pairs — `row(surface.line, ok: surface.ok)` at `:31`. **That is
  this item's remedy, implemented for the asset rows and not for the font rows**: a
  value type carrying `ok` as a boolean instead of re-derived from prose. The pattern
  to copy now lives four lines below the bug. `VinodexUI` still has no test target,
  so the assertion half depends on the same gap as **M14** and **L20**.

- [ ] **L20** · Test · The uppercase-with-caret-preservation transform is welded to UITextField and has no test · `Sources/VinodexUI/DexSearchField.swift:69` → extract the transform as a pure function and test it
  **@0731 STILL OPEN** — The file grew by +130/-13 since fb5dcf2 (clear button,
  applyColors, focusesOnAppear, DexSearchBarShell/Bar/BarButton), but the uppercase-
  plus-caret-restore block itself is byte-identical and merely moved from line 69 to
  line 100. It is still welded to UITextField inside an `#if canImport(SwiftUI) &&
  canImport(UIKit)` Coordinator, so it cannot run on the Linux CI host, and
  Package.swift ships no VinodexUI test target. Zero coverage.
  **Now at** `/opt/projects/vinodex-swift-g/Sources/VinodexUI/DexSearchField.swift:100`
  → Extract the pure part into VinodexCore, e.g. `public enum SearchInput { public
  static func normalized(_ raw: String) -> String { raw.uppercased() } ; public static
  func caretOffset(from raw: String, offset: Int) -> Int }`, and have `editingChanged`
  call it (`let upper = SearchInput.normalized(field.text ?? "")`) while keeping only
  the `selectedTextRange` save/restore in the Coordinator. Then add VinodexCoreTests
  cases for lowercase paste, mixed case, empty string, and a string whose uppercasing
  changes length (e.g. "ß" → "SS", the case where preserving the raw UITextPosition is
  actually wrong).
  **@0803 STILL OPEN — byte-identical, moved again, `:100` → `:148`.** No
  `SearchInput` in Core; the uppercase-plus-caret-restore block is still welded to
  `UITextField` inside the Coordinator, and `Package.swift` still ships no
  `VinodexUI` test target.
  **AUDIT M50 rewrote the sizing of this exact file and left the transform alone**,
  which is worth recording because it narrows the remaining work: `uiFont` now builds
  through `DexFont.resolvedSize(_:)` and three hand-pinned frames derive from one
  `DexSearchField.height(nominal:atLeast:)`, with the arithmetic pushed into
  `TypeScale` in **Core** and asserted in `TypeScaleTests`. So the file's *other*
  pure part has already made the trip this item proposes, by the route this item
  proposes. The transform is the last piece left in it, and the `"ß" → "SS"` case —
  where preserving the raw `UITextPosition` is actually wrong — is still the case
  nothing can catch.

- [ ] **L21** · Test · `freeTierIsClosed` title promises only-free grapes but asserts at-least-one; its AccessStore setup is dead code · `Tests/VinodexCoreTests/AccessTests.swift:55` → align the assertion or title with intent; delete the unused setup
  **@0731 STILL OPEN** — Both halves of the finding survive verbatim at HEAD (the block
  only moved from line 55 to 43/55). The title says "only reference free grapes" but
  `contains(where:)` is an at-least-one check, so a free region naming one free grape
  and nine locked ones still passes — exactly the dead-end the doc comment above it says
  the test exists to prevent. The AccessStore setup remains inert: `store` influences no
  assertion. The catalog growing 284 → 375 entries widens the blind spot but does not
  change the defect class.
  **Now at** `/opt/projects/vinodex-swift-g/Tests/VinodexCoreTests/AccessTests.swift:43`
  → Drop the unused `let store = makeStore(); store.starterOnly = true` (or actually
  assert through it), and make the assertion match the title: `let stranded =
  linked.filter { db.entry(named: $0) != nil && !freeGrapeNames.contains($0) }` then
  `#expect(stranded.isEmpty, "\\(entry.name) is free but links locked grapes
  \\(stranded)")`. If an all-free requirement is genuinely too strict for the current
  data, rename the test to "free regions and styles reference at least one free grape"
  so the name stops overselling the check.
  **@0803 STILL OPEN, verbatim.** Re-read at `AccessTests.swift:42-60`. The title is
  still *"free regions and styles only reference free grapes"* while the assertion is
  still `linked.contains(where:)` — an at-least-one check — and the two setup lines
  `let store = makeStore(); store.starterOnly = true` are still inert, influencing no
  assertion in the test. The blind spot widened with the data: **405 entries and 180
  free ids**, up from 375/153.

- [ ] **L22** · Test · Test UserDefaults suites are never removed after tests, leaking UUID-named plists on every run · `Tests/VinodexCoreTests/BookmarkTests.swift:9` → remove persistent domains in teardown and deduplicate the makeStore helper
  **@0731 WORSE** — All six new/expanded suite-backed test files repeat the leaking
  pattern instead of fixing it. Leaking files went 2 → 6 (PassportTests,
  ScreenStateTests, GrapeArtTests, AppVersionTests, DecodeRobustnessTests,
  ContinentTests and CoverageTests are clean — they touch no UserDefaults). Suites
  created and abandoned per run went from roughly 15 to roughly 68, a ~4.5x increase in
  leaked UUID-named plists. The `removePersistentDomain(forName:)` call at the top of
  each helper is a no-op by construction, since the suite name is a freshly minted UUID
  that has never existed.
  **Now at** `/opt/projects/vinodex-
  swift-g/Tests/VinodexCoreTests/BookmarkTests.swift:10 (plus
  AccessTests.swift:12,75,208,228; RecentlyViewedTests.swift:10,56,85;
  BookmarkTests.swift:41,150,188; DailyChallengeTests.swift:63; ToolsTests.swift:500;
  MinigameTests.swift:276)` → Add one shared helper and use it everywhere, e.g. `func
  withTempDefaults<T>(_ body: (UserDefaults) throws -> T) rethrows -> T { let name =
  UUID().uuidString; let d = UserDefaults(suiteName: name)!; defer {
  d.removePersistentDomain(forName: name); UserDefaults.standard.removeSuite(named:
  name) }; return try body(d) }`, and convert the six files'
  `makeStore()`/`makeDefaults()` helpers plus the 9 inline sites to it. Note that a
  helper returning a store cannot clean up on its own — the tests need the closure form
  (or a `Suite` with a `deinit` that tears down the names it handed out).
  **@0803 STILL WORSE — the pattern spread into three more files, including two
  written the day of this re-verification.** No `withTempDefaults`, no teardown
  anywhere; every site is still the same shape, with
  `removePersistentDomain(forName:)` called at the **top** of the helper on a
  freshly-minted UUID that has never existed — a no-op by construction, exactly as
  recorded. Leaking files went **6 → 9**: the three new ones are
  `TypeScaleTests.swift:15` (AUDIT M49/M50), `SavedDataArchiveTests.swift:15` (AUDIT
  M35) and `RouteAndSearchStateTests.swift` via `ScreenStateStore`. The full site
  list is now `AccessTests:11,74,207,227` · `BookmarkTests:9,40,149,187` ·
  `RecentlyViewedTests:9,55,84` · `DailyChallengeTests:62` · `ToolsTests:499` ·
  `MinigameTests:275` · `TypeScaleTests:15` · `SavedDataArchiveTests:15`.
  **`SavedDataArchiveTests` is the one to look at when writing the helper.** It is the
  heaviest defaults user in the suite — AUDIT M35's `reloadPicksUpAnImport` drives six
  stores through real `UserDefaults` suites, 67 assertions in that pass alone — so it
  leaks the most and would benefit most from the closure form. The note in the remedy
  stands and is the reason this has not been done casually: a helper that *returns* a
  store cannot clean up after itself.

- [ ] **L23** · Test · The `date` fixture's DateFormatter omits en_US_POSIX locale and Gregorian calendar despite a fixed format · `Tests/VinodexCoreTests/DailyPickTests.swift:16` → set the formatter's locale to en_US_POSIX and calendar to Gregorian
  **@0731 WORSE** — The original defect is untouched, and the new-since-audit
  MinigameTests copied it verbatim twice: a fixed `dateFormat` on a `DateFormatter` that
  inherits the process locale and calendar. On a machine whose region uses a non-
  Gregorian calendar (Buddhist in Thailand, Japanese-era, ROC) or non-Latin digits,
  `f.date(from:)` returns nil and the `!` force-unwrap crashes the test process rather
  than failing an expectation. Instances of the pattern went 1 → 3, across 1 → 2 files.
  Notably the neighbouring `utc` property in both files already does the right thing
  (`Calendar(identifier: .gregorian)`), so the fixture is inconsistent with the code
  sitting three lines below it.
  **Now at** `/opt/projects/vinodex-
  swift-g/Tests/VinodexCoreTests/DailyPickTests.swift:16 (plus new copies at
  MinigameTests.swift:8 and MinigameTests.swift:197)` → In all three fixtures set
  `f.locale = Locale(identifier: "en_US_POSIX")` and `f.calendar = Calendar(identifier:
  .gregorian)` alongside the existing `f.timeZone`; better, replace the whole thing with
  the pattern DailyChallengeTests already uses (`ISO8601DateFormatter` with
  `formatOptions = [.withFullDate]` and `timeZone = TimeZone(secondsFromGMT: 0)!`) and
  hoist it into a single shared test helper file so the next suite copies a correct
  fixture instead of this one.
  **@0803 STILL WORSE — unchanged at all three sites, and now feeding six more
  tests.** `DailyPickTests.swift:16`, `MinigameTests.swift:8` and
  `MinigameTests.swift:197` all still build a `DateFormatter` with a fixed
  `dateFormat` and a `timeZone`, and **no `locale` and no `calendar`** — inheriting
  the process's. On a machine whose region uses a non-Gregorian calendar (Buddhist,
  Japanese-era, ROC) or non-Latin digits, `f.date(from:)` returns nil and the `!`
  force-unwrap **crashes the test process** rather than failing an expectation.
  The inconsistency this item flagged is intact: in both files the neighbouring `utc`
  property three lines away does it correctly, with
  `Calendar(identifier: .gregorian)`. And `MinigameTests.swift:197`'s fixture now
  feeds the six date tests AUDIT M32 added on 2026-08-03 — so the count of tests
  resting on a locale-dependent force-unwrap went up while the fixture stayed wrong.
  `DailyChallengeTests.swift:16` still shows the correct pattern
  (`ISO8601DateFormatter`), which is what should be hoisted.
  **This is also the cheapest of the three test-hygiene items** — two lines in three
  places, or one shared helper — and it is the only one that can take a *runner*
  down rather than a test.

- [ ] **L24** · Test · `crossLinksResolve` doc claims the test flags a filled gap, but the `<= 24` upper bound passes silently when gaps close · `Tests/VinodexCoreTests/FilterTests.swift:148` → pin the exact unresolved-name set instead of an upper-bound count
  **@0731 WORSE** — This is the exact scenario the audit predicted, now realized. The
  v0.5.8–v0.6.2 catalog expansion filled 23 of the 24 gaps, but neither the bound nor
  the doc comment was touched — the test passed silently through the very event its
  comment promises it would report. The assertion is now 24x looser than reality:
  unresolved names could regress from 1 back to 24 (and cross-link instances from 1 to
  ~49 before the secondary `> 0.85` ratio guard trips) with the suite still green. Every
  named example in the doc comment is now factually wrong. Worse than at audit time,
  when the bound was at least tight.
  **Now at** `/opt/projects/vinodex-
  swift-g/Tests/VinodexCoreTests/FilterTests.swift:191` → Pin the bound to the current
  truth and make it two-sided so the next fill is also reported: replace with
  `#expect(unresolved == ["Various"], "cross-link gap changed:
  \\(unresolved.sorted())")` — an exact-set assertion, which is what "pinned" was
  supposed to mean. Rewrite the doc comment to say the only unresolved name is the
  literal placeholder "Various" on Pétillant Naturel. Separately, note the ratio guard
  at FilterTests.swift:196-200 mixes units — `let resolved = total - unresolved.count`
  subtracts a count of unique names from a count of link instances — so fix it to count
  unresolved instances if that guard is meant to mean anything.
  **@0803 STILL WORSE — and this item's own 2026-07-31 correction has now gone stale
  in turn, which is the finding.** The bound is untouched at `unresolved.count <= 24`
  (`FilterTests.swift:410-413`) and so is the doc comment above it.
  **Recomputed against the shipped `entries.json` on 2026-08-03: 354 cross-links,
  6 unresolved** — `Alvarinho`, `Garnacha`, `Pinot Grigio`, `Shiraz`, `Tinta Roriz`,
  `Various`. Not 24 (the audit's figure), and **not 1** (the last pass's figure, which
  said the only survivor was the literal `"Various"` on Pétillant Naturel). The
  batch-2 FR/IT/ES expansion (`295bda8`) reopened five of them, and five of the six
  are **synonyms of grapes that are in the table** — Alvarinho/Albariño,
  Garnacha/Grenache, Pinot Grigio/Pinot Gris, Shiraz/Syrah, Tinta Roriz/Tempranillo —
  which is a different content gap from the one the doc comment describes, and
  arguably a resolver gap rather than a data one, since `details.synonyms` already
  carries these names for search.
  **The assertion passed silently through both moves.** It has now been 24× loose,
  then 4× loose, and every named example in its doc comment (Rioja → Graciano, Douro →
  Tinta Roriz, Jura → Poulsard/Savagnin/Trousseau) is wrong except one. That is two
  content changes the test was written to report and did not.
  **Revised fix.** Pin the exact set, not a bound:
  `#expect(unresolved == ["Alvarinho", "Garnacha", "Pinot Grigio", "Shiraz",
  "Tinta Roriz", "Various"], "cross-link gap changed: \\(unresolved.sorted())")`, and
  rewrite the comment to say what the six are — one placeholder plus five synonyms.
  Then decide the real question this exposed: whether `entry(named:)` should consult
  `details.synonyms`, which would resolve five of the six and is the fix a user would
  notice. The unit-mixing nit at `:416` is unchanged.

- [ ] **L25** · Test · `searchFields` title promises tags matching but no assertion exercises a tags-only match · `Tests/VinodexCoreTests/FilterTests.swift:10` → add an assertion matching via tags only, or rename the test
  **@0731 STILL OPEN** — Still three assertions for four advertised fields, and the
  coverage is weaker than the comments claim. "napa" matches `Napa Valley` through the
  `name` haystack before the synonym haystack is ever consulted, so the line labelled
  `// synonym` proves nothing about synonyms; "japan" matches Yamanashi through both
  `origin` and `tags`, so it isolates neither. No assertion targets a tags-only match,
  meaning `haystacks.append(contentsOf: tags)` could be deleted from
  EntryFilter.swift:214 and this suite would stay green. Untouched by the v0.5.x/v0.6.x
  work despite `description` and `keyRegions` also being searched and also untested.
  **Now at** `/opt/projects/vinodex-swift-g/Tests/VinodexCoreTests/FilterTests.swift:10`
  → Add assertions that only one haystack can satisfy. Tags-only: search `"koshu"` and
  expect `Yamanashi` (its tags are `['Japan','Koshu']` and neither its name nor origin
  contains it). Synonyms-only: search `"vidure"` and expect `Cabernet Sauvignon` (a
  `details.synonyms` entry appearing in no other field). Then change the `"japan"`
  line's comment to say it covers origin-or-tags, or replace it with a region whose
  origin term appears in no tag.
  **@0803 STILL OPEN, verbatim at `FilterTests.swift:10-19`.** Three assertions for
  four advertised fields; no assertion targets a tags-only match, so
  `haystacks.append(contentsOf: tags)` could still be deleted and this suite would
  stay green. The mislabelled `// synonym` comment on the `"napa"` line is unchanged.
  **One thing changed underneath it, and it makes the gap slightly worse.** AUDIT
  **M5** replaced the per-field scan with a pre-folded `searchHaystack` —
  `WineEntry.searchFields` is now the single definition of what search scans, folded
  once at load and joined with a newline, and `WineDatabase` serves queries from
  `sortedEntries`/`searchHaystacks` built in `init`. So there are now **two**
  implementations that must agree about which fields are searchable (the indexed one
  and `[WineEntry].apply`, kept as the documented unindexed path), and this test
  pins neither of them field by field. AUDIT M33 did add *the indexed and unindexed
  paths agree on every filter branch* (`:349`) — but that compares the two paths to
  each other, so a field dropped from `searchFields` would leave both agreeing and
  both wrong.

- [ ] **L26** · Test · `originFilter` claims whole-term-only matching but never asserts a partial term is rejected · `Tests/VinodexCoreTests/FilterTests.swift:59` → assert a partial term such as "Fran" matches no region
  **@0731 STILL OPEN** — Unchanged since the audit. The whole-term guarantee — the
  single behaviour that distinguishes `.origin` from the `contains`-based `.region` and
  `.soil` filters — has no test. Swapping `matchesWholeTerm` for a plain
  `TextNormalize.label(origin).contains(...)` would leave both existing assertions
  passing, since "France" is a whole term either way. Verified by hand that the
  rejection the title promises does hold today (`matchesWholeTerm("France", "Fran")` →
  `" france ".contains(" fran ")` → false), so the missing assertion would pass if
  written. Also worth noting the second assertion is incidentally over-strict: `.origin`
  also matches via `entry.tags`, so `allSatisfy { $0.origin == "France" }` only holds
  because no non-French region happens to carry a "France" tag.
  **Now at** `/opt/projects/vinodex-swift-g/Tests/VinodexCoreTests/FilterTests.swift:80`
  → Add the negative case the title promises:
  `#expect(db.entries.apply(.category(.regions, filter: .origin("Fran"))).isEmpty, "a
  partial term matched")`, plus a mid-word case such as `.origin("rance")`. Add a direct
  unit test for `TextNormalize.matchesWholeTerm` covering equality, whole-word-inside-a-
  phrase ("Loire" in "Loire Valley"), prefix rejection, suffix rejection, empty
  candidate and empty term. Optionally assert the tags path explicitly so the
  `allSatisfy { $0.origin == "France" }` line is not silently relying on a data
  coincidence.
  **@0803 STILL OPEN, verbatim at `FilterTests.swift:80-85`** — two assertions, both
  positive, no partial-term rejection. Swapping `matchesWholeTerm` for a plain
  `contains` would still leave both passing.
  **And the failure mode this item is guarding against actually shipped, elsewhere.**
  AUDIT **M33** found `EntryDisplay.colorType` doing exactly the substring match this
  test exists to forbid — `"rose"` inside `"p-rose-cco"` — which labelled **Prosecco a
  rosé** on its detail page, in its chip text and in the filter behind it. The fix
  routed `colorType` through `matchesWholeTerm`. So the whole-term guarantee is no
  longer a property of one filter case: it is shared by `.origin` and by colour
  inference, it has a demonstrated failure history, and it still has **no direct
  test** — see **L16**, which wants the same function pinned from the other end.
  The second assertion's incidental over-strictness (`.origin` also matches via
  `entry.tags`, so `allSatisfy { $0.origin == "France" }` holds only because no
  non-French region carries a "France" tag) is unchanged, and the catalogue grew by
  30 entries since it was last true by coincidence.


---

## Update log

**2026-08-03 — re-verified against the working tree.** All 50 items re-read
against current source; every one carries a `@0803` note whether or not it moved.
**11 resolved · 9 partial · 20 open · 10 worse**, from
`2 · 7 · 27 · 14` at the last pass.

- **The tree, not `HEAD`.** Every fix from AUDIT.md's 2026-08-01 and 2026-08-03
  passes is uncommitted — 85 dirty paths, 26 untracked files. Nine of the eleven
  closures below live only in that working tree, **C1 among them**, so `HEAD`
  (`da787a8`) still has a macOS build that does not compile. Committing is the
  highest-value action available and it is not an audit item.
- **Nine items closed, none by work aimed at this file.** Six were taken by an
  AUDIT item covering the same ground — **M11**/**M12** by AUDIT M33, **M17** by
  M29, **L4** by M6, **L7** by L10, **L15** by M47 — and **C1** and **M16** were
  closed together by the CI rewrite. **L12** closed by a doc edit. That inverts
  the 2026-07-31 headline, where nine feature commits had built *on top* of these
  findings rather than around them. Mapping table under
  [What actually moved](#what-actually-moved).
- **Two closures contradict the fix this file proposed, and the reasons are
  worth keeping.** **L7**'s `deinit` could never have fired — the run loop
  retains the link, which retains the proxy, so the model does not deallocate
  while the link is live; teardown had to hang off `dismantleUIView`, and it had
  to be *conditional* or an `.id(…)` skin change would freeze the globe.
  **M16**'s proposed `macos-*` Swift job would have gone green on the same blind
  spot it was meant to close, because UIKit is absent on macOS too — the gate had
  to be `xcodebuild -destination 'generic/platform=iOS'`.
- **The branch tests this file asked for found two shipped bugs.** Writing
  **M11**/**M12**'s coverage surfaced them: `Rosé` and `Orange Wine` opened their
  COLOR chip onto an **empty list**, and **`Prosecco` was labelled a rosé**
  because `colorType` matched `"rose"` inside `"p-rose-cco"`. Both fixed. That is
  the argument for **L16** and **L26**, which want the whole-term matcher pinned
  directly and still have no test.
- **Three items' own premises had gone stale and are corrected in place.**
  **L24** is the sharpest: its 2026-07-31 note said 23 of 24 cross-link gaps had
  been filled and only the literal `"Various"` remained — recomputed, it is **6**,
  five of them synonyms of grapes that *are* in the table (Alvarinho, Garnacha,
  Pinot Grigio, Shiraz, Tinta Roriz). The `<= 24` bound passed silently through
  both moves. **H1**'s icon census was wrong in both directions and is now
  **68 unique ids — 55 game-icons CC BY 3.0, 12 lucide ISC, 1 mdi Apache-2.0 —
  shipped as 204 PNGs**, matching AUDIT M36's independent count. **M7**'s key
  count is **20**, not 19, and is now enumerable from `SavedDataKey.allCases`.
- **M6's remedy is not implementable and the item now says so.** `xtool.yml` has
  no `infoPath:` key in xtool 1.17 and is not a passthrough for the generated
  Info.plist — AUDIT M17 checked directly and left a comment in the file saying
  so. Portrait lock landed by `AppDelegate` instead, which is the stronger
  mechanism; the other three consequences stand and reopen with H4's signing
  pipeline.
- **Bookkeeping.** The 2026-07-31 status table said Medium `partial 4 / worse 4`
  while the items said `partial 3 / worse 5`. Totals were right; the table above
  is now counted from the items.
- **Verification.** Everything above was read against source or computed from the
  shipped JSON — entry counts, the free-tier resolution check (180/180), the
  cross-link recount, the icon-prefix census, the asset directory counts. **No
  build and no test run was attempted**, per the standing constraint: `swift
  test` has still never been executed by a maintainer, and CI is the first thing
  that runs these suites.
