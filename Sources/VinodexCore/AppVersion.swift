import Foundation

/// The running build's version, for anywhere in the UI that states it.
///
/// The back plate carried a hardcoded `"v0.3.5"` string, which had been wrong
/// for several releases — a literal nobody remembers to edit is a literal that
/// silently lies, and the back plate is the one screen whose whole job is to
/// state what this thing is.
///
/// Reads `CFBundleShortVersionString` first so a real plist value always wins,
/// with `fallback` behind it. Keeping both means the constant below is the
/// *only* place to bump, and the moment the build pipeline does start stamping a
/// version, this starts reporting it without another change.
///
/// **xtool does generate a version, and it is a lie.** The comment here used to
/// say `xtool.yml` declares no version and nothing generates an Info.plist with
/// one, so the fallback was always what a build got. Untrue: xtool 1.17 writes
/// `CFBundleShortVersionString = 1.0.0` and `CFBundleVersion = 1` into the
/// bundle unconditionally, and the guard below only rejected the literal
/// `"1.0"`. So `current` returned `"1.0.0"` and the back plate read `v1.0.0` on
/// every build ever shipped — the identical silent lie the hardcoded `"v0.3.5"`
/// string was deleted for, arrived at from the opposite direction.
///
/// Hence `placeholders`. There is no `xtool.yml` key to override the stamped
/// value (checked against xtool 1.17.0), so recognising it is the only lever
/// available, and a version the build did not choose is worth less than the
/// constant a human did.
///
/// **This number is the iOS app's own.** `vinodex-web` used to mirror it — the
/// two apps were one repo shipping one product, and a build claiming a
/// different version from its sibling was worse than no version at all. The
/// repos split on 2026-07-29 and both halves of that stopped being true: they
/// release on different clocks (a Vercel push is live in a minute, an App Store
/// build waits on review), and the feature sets diverged on purpose — the web
/// has no paywall, no `tiers.json`, no haptics, and a whole splash/website
/// branch with no counterpart here.
///
/// The mirroring had in fact already failed: this constant sat at 0.4.1.5 while
/// the web's `appVersion.ts` claimed 0.4.1.7. So the numbers are separate now.
/// The web restarted at 0.1.0 and counts on its own; that is not this file's
/// business, and neither is this number the web's.
///
/// **Three components from 0.4.3 onward.** The numbers had been growing a joint
/// per release — 0.4.1 begat 0.4.1.5, then 0.4.1.7, 0.4.2.1, 0.4.2.1.1, and
/// three branches open at once each claimed a different fourth or fifth level
/// for the same work. A scheme where the next number is not obvious is a scheme
/// that gets one per branch, and none of those extra digits ever meant anything
/// a reader could name.
///
/// 0.4.3 is the three branches landing together, and it is also the last version
/// that has to be explained. From here: patch for fixes, minor for features,
/// nothing deeper. It is what `CFBundleShortVersionString` will accept when
/// signing eventually matters — Apple takes at most three integers, so the old
/// five-part strings could never have been stamped into a real bundle anyway.
public enum AppVersion {
    /// The authored version — what this build reports when the bundle does not
    /// declare one it chose itself.
    ///
    /// **No longer a literal (0.7.3, F3).** From 0.4.3 to 0.7.2 this was a
    /// `static let` string bumped by hand each batch, and the release notes below
    /// grew underneath it because there was nowhere else for them to go. F3 asks
    /// for one data source behind both the boot POST and the FIRMWARE HISTORY
    /// panel, so the number and a per-release changelog now live in
    /// `shared/data/firmware.ts`, generate into `firmware.json`, and arrive here
    /// through `FirmwareCatalog`.
    ///
    /// **This file kept the half of the job that was actually its own.**
    /// Everything below `placeholders` is a *resolution* rule — a version the
    /// build genuinely declares wins, xtool's stamped `1.0.0` wins nothing — and
    /// that reasoning has nothing to do with where the authored number is
    /// written down. What changed is that this constant no longer restates a
    /// number that also exists somewhere else. There is one place to bump, and
    /// it is the head of the array in `shared/data/firmware.ts`.
    ///
    /// The long notes that follow stay here rather than moving into the
    /// changelog data. They are the engineering record — why 0.6.4 is not
    /// "0.6.3", why the scheme has three components, why a batch labelled
    /// "0.6.7.2" shipped as 0.6.9 — and they answer a question no player asks.
    /// `shared/data/firmware.ts` carries what the device is willing to say about
    /// itself; this carries what a maintainer needs to know. Both describe the
    /// same releases and neither is the other's summary.
    ///
    /// Historical note on the entries below: through 0.7.2 they were attached to
    /// the literal directly, so "bump with the batch" and "explain the bump"
    /// were one edit. They are now two, and the changelog is the one users see.
    ///
    /// 0.6.4: the spec was authored as "0.6.3", but that number shipped with
    /// the robustness/audit batch and is already tagged — a version that names
    /// two different builds names neither, so this batch takes the next patch.
    ///
    /// 0.6.5: the batch the user labelled "6.3.3" — same convention as above,
    /// the label maps to the next patch after what the tree actually holds.
    ///
    /// 0.6.6: the corrective polish pass over the chassis 0.6.5 shipped —
    /// per-mode globe tint, the diagonal button cluster, the wordmark moved
    /// into the grille. No catalog change, so `waveMilestones` does not move.
    ///
    /// 0.6.7: the second corrective pass over the same chassis — the wordmark
    /// out of the grille and into the bottom strip, the red lamps anchored to
    /// the bezel, the button band rebuilt as two recessed diagonal bundles —
    /// plus two new skins, per-button console palettes, draggable back-plate
    /// stamps and the LCD-resize fix. Still no catalog change, so
    /// `waveMilestones` does not move.
    ///
    /// 0.6.8: the batch the user labelled "6.7.1". Same resolution as 0.6.4 and
    /// 0.6.5 above — the label names the work, the scheme names the build, and
    /// the scheme has been three components since 0.4.3 for reasons this file
    /// spends forty lines on. A fourth joint would be the exact thing that
    /// paragraph was written to stop, and `AppVersionTests.threeComponents`
    /// would fail on it. It is a polish pass over 0.6.7's chassis — the footer
    /// controls at 1.74×, the red lamps back on the white bezel, an app-wide
    /// LCD back swipe, press-and-hold stamp dragging — so it takes the next
    /// patch. No catalog change again, so `waveMilestones` still does not move.
    ///
    /// 0.6.9: the batch the user labelled "0.6.7.2". Same resolution as 0.6.4,
    /// 0.6.5 and 0.6.8 above, and by now the pattern is the point rather than
    /// the exception — the label names the work in whatever shape it arrived
    /// in, the scheme names the build, and the scheme has been three components
    /// since 0.4.3. `AppVersionTests.threeComponents` is what keeps the two
    /// from being confused. It is a third corrective pass over the same chassis
    /// — the LCD back swipe removed outright, the footer caps down a quarter
    /// and re-paired, the marquee stopped scrolling in favour of a glyph and a
    /// cycling greeting, a hand-drawn skin and screen mode — plus one catalog
    /// change (Morellino as a Sangiovese synonym), which adds no entry, so
    /// `waveMilestones` still does not move.
    /// 0.7.0: **the first batch since 0.4.3 whose label needed no
    /// reinterpretation.** Five of the last six arrived as "6.3.3", "6.7.1",
    /// "0.6.7.2" and so on, and each of those notes above records the same
    /// resolution: the label names the work, the scheme names the build. The
    /// user named this one 0.7.0, which already *is* the scheme — a minor bump,
    /// which is the right joint for a batch that adds two chassis skins, three
    /// new filter facets, a per-skin back plate and a new tool slot, rather than
    /// the patch a corrective pass would take.
    ///
    /// A minor bump has no `waveMilestones` implication, and it is worth saying
    /// why rather than leaving it as an absence: that list records *catalog
    /// totals*, not versions. It moves when the entry count moves and at no
    /// other time. This batch touches no `shared/` data at all — nothing was
    /// regenerated, `entries.json` is byte-identical, and the total stands at
    /// 405 — so the list does not move, exactly as it did not for 0.6.6 through
    /// 0.6.9.
    ///
    /// The work: the picker grouped into sections on both axes, the NOTEBOOK
    /// screen mode removed while the PÉT-NAT shell stays, WALDGLAS and
    /// HALLOWEEN added, a back plate per skin, the stamp drag rebuilt on the
    /// right coordinate space, filter chips on the world/styles/flavour scans,
    /// the tools shelf re-cut, three fixed pages grown into their measured
    /// slack, and the marquee glyph table audited end to end.
    ///
    /// 0.7.1: **the label and the scheme agreed for the second time running**,
    /// and the second one is what makes it a habit rather than a coincidence.
    /// A patch, correctly: everything here is a fix, a rename or a feature
    /// grown out of a surface that already existed, and nothing changes what
    /// the app *is* the way 0.7.0's two new skins and three new facets did.
    ///
    /// The catalog moved for the first time since 0.6.4 — and did not move.
    /// South America's marker colour changed (A3: `#73343A` sat within five
    /// points a channel of North America's `#722F37`, so the two continents
    /// drew the same dot on the globe), which means `shared/` was edited,
    /// synced, regenerated and re-audited for dangling references. But a colour
    /// is not an entry: the total stands at 405 and `waveMilestones` does not
    /// move, exactly as it has not since 0.6.2's 375 was appended.
    ///
    /// The work, by section. **A:** FILTER SEARCH became MASTER SEARCH and the
    /// dead `.masterSearch` route was retired so the two could not both hold
    /// the name; every search affordance in the app collapsed onto one
    /// magnifier (`DexGlyph.search`); the header lamps grew from 17pt to 22pt;
    /// and every lamp on the device — the island trio, the two on the white
    /// bezel, the one in the vent strip, the two over the marquee — now sits in
    /// a milled recess (`RecessedLamp`) instead of being a flat disc with a
    /// hairline. **B:** the marquee is scripted (WELCOME! → MENU → CHEERS!
    /// after ten idle seconds, `MarqueeScript` in Core so a Linux gate can see
    /// it), transitions on a pixel dissolve rather than a cross-fade, and is a
    /// button on every screen that opens a swipeable quick-access drawer with
    /// a two-slot pin bar. **C:** the VINTAGE picker group became RETRO,
    /// WINE.OS and GRÜNERBOY swapped groups, HALLOWEEN became HALLOWINE, and
    /// the Emulator modes now repaint the app's coloured chrome in their own
    /// ramps. **D:** the passport gained a per-day activity graph (which
    /// required the tried shelf to start dating its entries at all), a
    /// stamp-unlock moment, a four-rung rank ladder beginning with VINODEX
    /// MASTER, and two more fixes to the stamp drag. **E:** the daily
    /// challenge's fire became a target, and IDENTIFY became BLIND TASTING.
    ///
    /// 0.7.2: **LABEL SCAN**, from the `vinodex-label-reader` spec — the first
    /// batch since 0.7.0 to add a screen rather than rework one, and the first
    /// feature in the app that takes an input from outside it. Point the camera
    /// at a bottle, run Apple Vision on-device, and match what it read against
    /// the catalog: `LabelRecognitionService`, `LabelTextScan` and the result
    /// models are Foundation-only in Core and gated by `swift test`, while
    /// Vision, the camera and the pickers sit in `VinodexUI` behind
    /// `LabelRecognitionProvider`. No network, no API key, no account.
    ///
    /// The place walk is the part worth naming: an appellation off the label
    /// (`BAROLO`) resolves to the region that lists it, which yields the
    /// country, the notable grapes and — through each grape's own `grapeStyle`
    /// — the styles. None of that is written down anywhere in this feature. It
    /// is the catalog's existing cross-references being read in a new direction.
    ///
    /// Two things the spec assumed and the code did not have: there is **no
    /// Producer entity** in Vinodex and there never was, so producer matching is
    /// text-only and its 50-point weight degrades to 15 (see `LabelConfidence`);
    /// and `TextNormalize.key` is the app's normaliser, reused here rather than
    /// reimplemented, which is what makes a phrase off a photograph comparable
    /// to a catalog key at all.
    ///
    /// Also: `xtool.yml` gained `infoPath`, which the file's own comment and
    /// KNOWN-ISSUES.md had both said did not exist. It does, on the installed
    /// xtool 1.17. The camera and photo usage strings go through it, and the
    /// stale claim is corrected in both places.
    ///
    /// No catalog change — 405 stands and `waveMilestones` does not move.
    ///
    /// 0.7.2 also carries the **consolidation batch** (`vinodex-0.7.2`), which
    /// shares this number rather than taking 0.7.3 because nothing had shipped
    /// under it: LABEL SCAN was still uncommitted when the fixes arrived, so the
    /// two land as one release rather than as a version tagged and superseded
    /// the same day.
    ///
    /// Its section 0 was git, not code. Every outstanding batch branch is now
    /// contained in `testing` — 0.6.5 through 0.6.7.2 already were, and the last
    /// genuinely dangling one was 0.6.4, whose three files had been rewritten by
    /// five later batches. That merge resolves wholly to `testing` and changes
    /// no content; see its commit message for why each conflict went that way.
    ///
    /// **A2 is the one that matters.** Stamps had been undraggable since 0.7.0
    /// and two batches had tried to fix it by tuning the hold threshold. No
    /// touch was ever reaching the recogniser: E2's reorder left
    /// `.contentShape(Rectangle())` *outside* `.offset`, and since `.offset`
    /// does not change layout, that pinned all six stamps' hit regions to one
    /// 88×104 box in the plate's top-left corner. Taps were dead too — nobody
    /// reported it because the drag was what people were trying. The lesson is
    /// in `DeviceBackPlate.stampField`: a threshold that changes nothing is
    /// evidence the event never arrived, not evidence it needs to be lower.
    ///
    /// The rest is the marquee, which is now the app's control surface rather
    /// than its nameplate: its two status lamps are the TOOLS and CUSTOMIZE
    /// buttons (A9, and 20pt tall to earn it), pinned sections sit in its top
    /// corners (A7), tapping it toggles the drawer and re-titles the panel PINS
    /// (A6), MENU gained a glyph beside the word (A3), the idle toast rotates
    /// through nine languages (A8) — the 0.6.9 list back, now that the script
    /// gives it somewhere to belong — and the specular bead came off the two
    /// pills (A4), which is where A9's glyph goes. Africa and Oceania finally
    /// have their own marker colours (A1); they were the pink pair 0.7.1's A3
    /// left behind.
    ///
    /// 0.7.3: **the Foundation batch.** First of three 0.7.3 sub-batches, and
    /// the number is a patch because what a user can point at — a boot screen, a
    /// demo loop, two new panels, a screensaver — is device furniture rather
    /// than a change to what the app *is*. Most of the work is underneath it:
    /// one entitlement store behind a protocol (F1), one idle timer where there
    /// were two clocks (F2), and this constant's own contents moving into
    /// `shared/` (F3). 0.7.3b and 0.7.3c build on those three.
    ///
    /// No catalog change — 405 stands and `waveMilestones` does not move. The
    /// generated set grew by one file, `firmware.json`, which is data the app
    /// reads rather than an entry anyone can browse.
    ///
    /// 0.7.5: **the shop.** A patch again, and for the 0.7.3 reason: nothing
    /// about what the app *is* changed. B moves the expansion packs out of
    /// CUSTOMIZE into a renamed ACCESS — SHOP, the route for paid content — and
    /// redraws the whole of it in 0.7.3c's cartridge tile, which finishes the
    /// grid consolidation that batch started for every surface but the two
    /// pickers carrying real art. `SettingsSection.packs` retires into the shop
    /// that now holds its shelves, so `ChromeTests`' route count goes 32 → 31.
    /// Underneath it, `PurchaseProviding` beside F1's `EntitlementStoring`: the
    /// step where money would change hands, with the local implementation doing
    /// exactly what 0.7.4 did inline. **No StoreKit and no payment path** — see
    /// `LocalPurchaseProvider` for what an adapter would have to supply.
    ///
    /// A is six fixes: bigger marquee lamps paid for out of the panel again
    /// (A1), a squared orb (A2), a refresh flash on the four single-phosphor
    /// modes (A3), PÉT-NAT → FIBERGLASS (A4), the real wordmark bouncing in the
    /// screensaver instead of a drawn stand-in (A5), and the POST scaled up to
    /// fill the LCD (A6) — still inside it, still skippable, still under two
    /// seconds, and `BootSequenceTests` unchanged.
    ///
    /// E is **interactive grape lineage**: `sommbot` authored a pedigree off VIVC
    /// passports (57 grapes carrying one, 68 of 171 in a relationship once the
    /// reverse pass runs, 42 in-catalog edges and 36 off-catalog ancestors), and
    /// this batch built everything that consumes it — the `constants.ts`
    /// pass-through, `GrapeLineage`/`LineageRef` on `GrapeEntry`,
    /// `GrapeLineageIndex` deriving offspring, mutations and half-siblings from
    /// the one child-facing direction that is stored, a `find-missing-refs.mjs`
    /// arm, and the tree screen behind a new `Entitlement.lineage`. `DexRoute`
    /// gains `.lineage`, so `ChromeTests`' route count goes 31 → 32.
    ///
    /// **The tree is not offered on the 103 grapes with no relatives.** A screen
    /// that opens empty for three grapes in five is worse than a feature you find
    /// in the shop; see PLAN.md.
    ///
    /// E also carries the `bodyFromText` fix `levelFromText`'s note pointed at in
    /// 0.7.4: `full` was tested above `medium-full` and every test in the function
    /// is a substring test, so **16 grapes drew a 5/5 body bar they never
    /// earned**. Unlike the tannin fix, this one moves rendered values — 16 of
    /// them, on iOS and on web.
    ///
    /// No catalog change — 438 stands and `waveMilestones` does not move.
    /// `lineage` is a new *optional* field on grape entries, not a new entry.
    ///
    /// 0.7.6: **the consolidation.** A patch, and for the reason 0.7.3 and 0.7.5
    /// were: nothing about what the app *is* changed. What changed is that three
    /// features stopped being three.
    ///
    /// The spec arrived numbered 0.7.5 — a version already shipped and on the
    /// device — so it lands as 0.7.6, and its own back-references to "0.7.4 B"
    /// (the shop) and "0.7.4 A2" (the orb) are 0.7.5's. That resolution is the
    /// same one 0.6.4, 0.6.5, 0.6.8 and 0.6.9 record above: the label names the
    /// work, the scheme names the build.
    ///
    /// **The Decision, which is section A and most of the batch.** Through 0.7.5
    /// the device offered three ways to reach the same handful of places: two
    /// marquee lamp buttons hardwired to TOOLS and CUSTOMIZE (0.7.2, A9), two pin
    /// buttons in the marquee's corners (0.7.2, A7), and a swipe drawer behind
    /// the panel (0.7.1, B4/B5) whose PINNED row was the only way to choose what
    /// the corners held. A1 collapses all three into the lamps: always visible,
    /// one tap, and each reassignable by holding it. `MarqueeDrawer` is deleted,
    /// the corner buttons and their three metrics go with it, the panel stops
    /// being a button (reversing B4), and the PINS title-swap (A6) has nothing
    /// left to name. `QuickPinStore` is reused rather than forked: its key and
    /// encoding are 0.7.2's, and `MarqueePin`'s raw values are a strict superset
    /// of `SettingsSection`'s, so **nobody's pins are reset** — one stored pin
    /// keeps its slot and the other lamp fills from the factory pair.
    ///
    /// **The idle timer stopped being two stages** (A3/A4). The screensaver moves
    /// 15 → 30 seconds and the marquee's greeting, which fired at 10 on the main
    /// menu only, now arrives *with* it, on any screen. `IdleSchedule.toast` is an
    /// optional holding `nil`; every consumer still asks `stage >= .toast` and
    /// `.screensaver` outranks it, so reverting the fold is giving that constant a
    /// number back rather than a rewrite. A8's nine languages survive intact —
    /// one per idle period. A2 gives the bouncing mark a random start, kept as a
    /// *phase* on the existing triangle wave so the closed form and its
    /// two-hour-exact tests are untouched.
    ///
    /// The rest: B1 adds two genuinely new workshop axes (the header lamp trio,
    /// the two marquee lamps) and relabels the third thing the spec asked for,
    /// which has been settable as `buttons` since 0.7.3b — eight axes becomes
    /// ten, and `DeviceBuild` gains a hand-written decoder, because the
    /// synthesised one would have thrown on every build saved before this batch
    /// and `CustomDeviceStore`'s `try?` would have deleted the lot. C enlarges the
    /// shop splashes and gives them previews of what is inside; it stays an
    /// overlay, deliberately, because everything C adds is content in the same
    /// scrolling column. D adds the W64 shell — inspired-by colours and nothing
    /// else, per the rule `buttonSet` has carried since 0.6.7. E makes the orb a
    /// stadium, spending the elongation on height so the cutout clearance
    /// `islandOrbInsetLeading` guards does not move. F moves the tutorial into
    /// SETTINGS > DEVICE, beside 0.7.3a's firmware and cheat-console rows rather
    /// than into a second section of the same name.
    ///
    /// **G, H and I are not in this build.** Sharing, the Wordle result string
    /// and daily notifications are the spec's own scope note — its growth trio,
    /// and its own recommendation that they be their own pass.
    ///
    /// No catalog change: 438 stands, and `waveMilestones` does not move.
    ///
    /// 0.7.7: **the BIOS screen.** A patch, and the narrowest batch since the
    /// scheme settled — one screen, rebuilt, plus the two Core types it needed.
    /// The spec arrived titled 0.7.6, which is the batch above; same resolution
    /// as 0.6.4, 0.6.5, 0.6.8, 0.6.9 and 0.7.6, and its back-reference to
    /// "0.7.4 A6" is 0.7.5's.
    ///
    /// **It matters to this file specifically, which is why it has a note at
    /// all.** The mockup the redesign was drawn from prints
    /// `VINODEX BIOS v1.0.0`, and `1.0.0` is a member of `placeholders` below —
    /// the literal xtool stamps into every bundle, and the value whose *absence*
    /// from the UI is how anyone would notice the denylist had stopped working.
    /// A boot screen printing it as decoration would have made that failure
    /// invisible: the back plate reading `v1.0.0` is a bug report, and a BIOS
    /// reading it would have been a design. So C3 of the spec beat its own
    /// mockup, the title goes through `BootSequence.header`, and
    /// `BiosChromeTests.titleIsNotThePlaceholder` asserts the resolved version
    /// is not in this set — the first test to check the denylist from the
    /// direction of a *screen* rather than of `resolve(bundled:)`.
    ///
    /// The BIOS also reverses 0.7.3a's "inside the LCD" decision and re-pins
    /// `BootSequenceTests.brief`; both are argued where they live, in
    /// `BootScreen` and in the test.
    ///
    /// No catalog change: 438 stands, `waveMilestones` does not move, and no
    /// `shared/` data outside `firmware.ts` was touched.
    ///
    /// **The value below is no longer edited here.** See the note at the top of
    /// this comment: it reads the head of `shared/data/firmware.ts`.
    static var fallback: String { FirmwareCatalog.shared.version }

    /// Versions no build deliberately chose.
    ///
    /// `1.0.0` and `1` are what xtool stamps when nothing declares a version;
    /// `1.0` is Xcode's own template default, kept because a future Xcode project
    /// would reintroduce it. A bundled value in this set means "the build tool
    /// filled the blank in", not "this is release 1.0.0".
    ///
    /// A denylist is a liability — the day the app genuinely ships 1.0.0 this
    /// file has to change or the release reports the fallback instead. That is
    /// the smaller of the two liabilities, it fails loudly in the test below
    /// rather than silently on the back plate, and there is a note in
    /// `KNOWN-ISSUES.md` pointing here.
    static let placeholders: Set<String> = ["1.0", "1.0.0", "1"]

    /// The version to report given whatever the bundle carries.
    ///
    /// Split out from `current` purely so it is reachable from a test:
    /// `Bundle.main` on Linux carries no Info.plist at all, so a test that goes
    /// through `current` can only ever exercise the nil path — which is exactly
    /// how the `1.0.0` bug survived having a test suite written about it.
    static func resolve(bundled: String?) -> String {
        guard let bundled else { return fallback }
        let trimmed = bundled.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !placeholders.contains(trimmed) else { return fallback }
        return trimmed
    }

    /// Bare version, no prefix — e.g. `0.4.3`.
    public static var current: String {
        resolve(bundled: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }

    /// Display form, e.g. `v0.4.3`.
    public static var display: String { "v" + current }
}
