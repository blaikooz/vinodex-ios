---
description: Cut the next Vinodex release from main and dispatch it to TestFlight — tag, generate, archive, upload via the ASC API key.
---

Cut and dispatch a Vinodex iOS release. Follow every step in order; stop and
report rather than improvising if any gate fails.

## Preconditions — verify all before touching anything
1. `git -C ~/Developer/HGapps/vinodex-ios status` — working tree clean, on
   `main`, up to date with `origin/main`. If not, stop and say so.
2. The tip of main must be CI-green: check the latest run on main (or the
   testing/PR run for the same tree) with `gh run list`. No green, no cut.
3. SIM-VERIFIED FIRST (maintainer flow, 2026-09-01): a dispatch ships only
   a tree the maintainer has walked on the simulator — build to a sim
   (`xcodebuild -destination 'id=<sim udid>'`, install, launch) and get
   their thumbs-up before any tag. Batches accumulate between dispatches
   on purpose; do not dispatch per-change.
4. HEAD must not already carry an annotated release tag — never re-archive
   a commit already shipped: TestFlight rejects duplicate version+build
   pairs, and the build number is the commit count, so a new upload needs
   at least one new commit.

## Version
4. Read the newest tag (`git tag --sort=-creatordate | head -1`) and pick
   the next per the maintainer's cadence (small steps toward v1: v0.9.41 →
   v0.9.42 → …). If the user named a version in their message, use theirs.
   Confirm the choice in one line before tagging only if it deviates from
   the cadence.

## Ceremony — commit → tag → generate → archive → upload, in that order
5. `git tag -a <version> -m "<version>: <one-line summary of what shipped>"`
   on HEAD, then `git push origin <version>`. (Tags on post-fbac0d7 commits
   are safe — the Codemagic tag trap is dead — but never tag older commits.)
6. `./scripts/generate-xcodeproj.sh` — the first output line must print the
   new version and a build number you haven't shipped before. If the
   version printed is not the tag you just made, stop: the tag didn't take.
7. Archive (run in background, it takes minutes):
   `xcodebuild archive -project Vinodex.xcodeproj -scheme Vinodex
   -destination 'generic/platform=iOS' -allowProvisioningUpdates
   -archivePath build/Vinodex.xcarchive`
   Then verify the stamps:
   `plutil -extract ApplicationProperties xml1 -o - build/Vinodex.xcarchive/Info.plist`
   must show the new version and build.
8. Ensure `build/ExportOptions.plist` exists with: method
   `app-store-connect`, destination `upload`, teamID `N6BL8PYJ5X`,
   signingStyle `automatic`, uploadSymbols true,
   manageAppVersionAndBuildNumber false. Create it if missing.
9. Dispatch (run in background). The `PATH` prefix is load-bearing: Xcode runs
   `/usr/bin/rsync -8aPhhE` to build the .ipa and spawns rsync's "remote" side
   via PATH, so Homebrew's rsync 3.5.0 answers and rejects `--extended-attributes`
   (`Copy failed`). Keep `/usr/bin` first so both ends are Apple's openrsync.
   `PATH="/usr/bin:$PATH" xcodebuild -exportArchive -archivePath build/Vinodex.xcarchive
   -exportOptionsPlist build/ExportOptions.plist -exportPath build/export
   -allowProvisioningUpdates
   -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_3AT44222Q9.p8
   -authenticationKeyID 3AT44222Q9
   -authenticationKeyIssuerID 22c75307-c762-4946-8f4b-a6fbdfd42334`
   Success is `EXPORT SUCCEEDED` in the log — that includes the upload.
   Never paste the key file's contents anywhere.

## Report
10. State: version, build number, tag pushed, archive verified, upload
    result. Remind the user the build takes a few minutes to clear
    TestFlight processing (export compliance is auto-answered by the
    ITSApp plist key). If any xcodebuild step was denied by permissions,
    hand the user the exact command to run themselves instead of retrying.
