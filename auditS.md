# Vinodex Targeted Audit — Compliance · Security · Test

**Written 2026-07-29 against `fb5dcf2`. Re-verified 2026-07-31 against `b48ad20`.**

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

**2 resolved · 7 partial · 27 still open · 14 worse**

| Severity | Resolved | Partial | Open | Worse | Total |
|---|---:|---:|---:|---:|---:|
| Critical | 0 | 0 | 1 | 0 | 1 |
| High | 0 | 1 | 4 | 0 | 5 |
| Medium | 2 | 4 | 8 | 4 | 18 |
| Low | 0 | 2 | 14 | 10 | 26 |
| **Total** | **2** | **7** | **27** | **14** | **50** |

**Worse** means the described defect is intact *and* the surface it applies to
grew — more unlicensed assets, more untested branches, more copies of a bad
pattern. Fourteen items in that column is the headline: the nine feature commits
were built on top of the audit's findings rather than around them, so most of
this work order got larger rather than smaller.

Two genuine fixes landed, both in v0.6.3's "robustness spine": **M8** (per-entry
lossy decode — one bad entry no longer zeroes the catalog) and **M15** (CI now
proves the committed JSON matches `shared/`).

### What to fix first

1. **C1** — one line. `swift build` and `swift test` are both broken on macOS
   today; nothing else on this list can be verified on an Apple platform until
   it lands. See [The testing gap](#the-testing-gap).
2. **H1 · H2 · M1 · M2** — the app ships 198 CC BY 3.0 icons, 29 pixel-art flags,
   two OFL fonts and a 217 KB map with no LICENSE, no NOTICE and no in-app
   credits anywhere. These are hard license conditions, not hygiene.
3. **H3 · H4 · M6** — `PrivacyInfo.xcprivacy`, a real bundle ID and an Info.plist
   source. Each one independently blocks App Store submission.
4. **L22 · L23 · L24** — the test suite's own defects, all now multiplied across
   the new test files. L24 is the sharpest: the assertion the audit predicted
   would silently stop working has now silently stopped working.

## The testing gap

The main developer builds with [xtool](https://github.com/xtool-org/xtool) from
WSL and no maintainer can install Xcode. Verified 2026-07-31:

- **xtool has no `test` subcommand and no simulator support.** Its documented
  commands are `setup`, `auth`, `sdk`, `new`, `dev`, `ds`, `devices`, `install`,
  `uninstall`, `launch` — it builds and sideloads to a physical device only. No
  iOS-hosted test can be run by the current toolchain, which is why none exist.
- **A type error inside `#if canImport(UIKit)` is invisible to every check the
  project runs.** Proven by injecting an undefined symbol into
  `Sources/VinodexUI/Haptics.swift`: `swift build` on macOS reported
  `Build complete!`. On Linux the same code compiles to nothing. This is exactly
  the C1 failure class, and nothing in CI can see it.
- **A *syntax* error in an inactive `#if` branch *is* caught**, because inactive
  branches are still parsed. `README.md`'s claim that "a syntax error there
  passes `swift test`" is wrong — the real hole is narrower but far more
  dangerous: name and type resolution.
- **`swift test` on macOS needs full Xcode**, not Command Line Tools. With CLT
  only it fails on `no such module '_Testing_Foundation'` even after C1 is fixed.

The workaround is that **nobody needs to own a Mac** — this repo is public, so
GitHub's `macos-15` runners are free:

| Gate | Runs on | Catches |
|---|---|---|
| `swift test` (exists) | Linux | VinodexCore logic |
| `xcodebuild -destination 'generic/platform=iOS'` | macos-15 | **UI type errors — C1's class** |
| `xcodebuild test -destination 'platform=iOS Simulator'` | macos-15 | iOS-hosted tests, which can now exist |

Add a `VinodexUITests` target whose files open with
`#if canImport(SwiftUI) && canImport(UIKit)`, matching the convention all 34
files in `Sources/VinodexUI/` already use. On Linux it compiles to an empty
module and the Linux job stays green; on the simulator the tests actually run.
The developer never touches a Mac — they push and read the CI result.

Longer term, the structural fix is the one **M17**, **M18**, **L19** and **L20**
each ask for individually: move pure logic out of `VinodexUI` into `VinodexCore`,
where it is testable on the Linux host the developer actually works on. Every
line moved is a line that stops depending on a device to verify.

Also fix the CI trigger while you are there: `on:` is scoped to `branches: [main]`,
so pushes to `audit` and to the `vN.N-batch` branches — where all the work happens
— run nothing at all.

---

## Critical

- [ ] **C1** · Test · `swift build`/`swift test` fail on macOS — VinodexApp guarded only by `canImport(SwiftUI)` but references UIKit-gated VinodexUI symbols (`TextScale` not found; verified by building) · `Sources/VinodexApp/VinodexApp.swift:1` → change guard to `#if canImport(SwiftUI) && canImport(UIKit)`
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

- [ ] **M11** · Test · EntryFilter `.type`, `.tasting`, `.soil`, and `.system` predicate branches have zero test coverage · `Sources/VinodexCore/EntryFilter.swift:105` → add branch tests for each filter case against known entries
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

- [ ] **M12** · Test · Hand-transcribed styleClass/colorType keyword tables with load-bearing precedence have no tests despite claiming test-driven placement · `Sources/VinodexCore/EntryDisplay.swift:43` → pin styleClass/colorType outputs and keyword precedence with table-driven tests
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

- [ ] **M16** · Test · No CI — `swift test` never runs automatically, which is how the macOS build breakage (C1) went unnoticed · `Package.swift` → add a CI workflow running `swift test` on Linux and macOS
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

- [ ] **M17** · Test · `grapeWellColor`/`styleTone` keyword-to-color logic is pure but sits in the untestable UI module · `Sources/VinodexUI/EntryVisual.swift:72` → move the keyword-to-tone mapping into VinodexCore returning hex strings; test there
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

- [ ] **L4** · Compliance · `Diagnostics.emit()` logs app state to syslog on every launch with no DEBUG guard · `Sources/VinodexApp/VinodexApp.swift:216` → wrap in `#if DEBUG` or use os.Logger at debug level
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

- [ ] **L7** · Security · GlobeModel's display link is invalidated only via `onDisappear` with no deinit fallback, leaking ticks · `Sources/VinodexUI/RetroGlobeScreen.swift:344` → invalidate the display link from GlobeModel `deinit` as a fallback
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

- [ ] **L12** · Compliance · Committed doc embeds the developer's personal Windows username and home path in an rsync example · `KNOWN-ISSUES.md:145` → replace the personal path with a neutral placeholder like `/mnt/c/<repo-root>/ios/`
  **@0731 PARTIAL** — The suspicion that d5383b5 re-introduced the
  personal path is half right: d5383b5 did keep
  `/mnt/c/Users/StreetPC/Desktop/HGapps/...`, but the later commit 4b75fae replaced it
  with a drive path carrying no username and no home directory. No committed file at
  HEAD leaks a Windows username, a home path, or an email address. A machine-specific
  absolute path (`/mnt/h/vscode-projects/HGapps/`) remains, but it identifies no person
  and is not what the finding described.

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

- [ ] **L15** · Test · `DexRoute.title`, `WineEntry.scanTitle`, and the `.detail` destination branch have no tests · `Sources/VinodexCore/DexRoute.swift:37` → add a table-driven test over title, scanTitle, and destination
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

