import Testing
import Foundation
@testable import VinodexCore

/// The cash-in of arch **A6**. That item's entire justification was "the
/// persisted vocabulary should be reachable from `swift test`" — `LcdMode`,
/// `ChassisSkin` and `UIScale` moved to Core, `AppSettings` (**A17**) followed,
/// and then nothing tested any of it. These tests are the difference between
/// "moved to Core" and "moved to Core for a reason".
///
/// What they pin, and why it is this and not something else:
///
/// - **The 27 raw values.** Every one is written into `UserDefaults` on a real
///   device, so a renamed case silently resets that user's stored choice —
///   the exact class of loss **M35** built `SavedDataKey` against, now applied
///   to the vocabularies that registry protects the keys of.
/// - **The model's write discipline.** `AppSettings.reload()` after a wipe must
///   leave the keys *absent*, not re-created at their defaults — `isAdopting`
///   exists for that one call, and only a test can keep it existing.
/// - **The first-launch seed.** `seedTextScaleIfUnset` must move the model and
///   storage together; the shipped bug it replaces had them disagreeing for a
///   whole session, with a settings picker that highlighted SMALL and did
///   nothing when tapped.
/// - **What an absent key means.** `SettingsDefault` is one declaration read by
///   two mechanisms — this model and the nonisolated statics (`Haptics`,
///   `Sounds`, `ScreenWake`) that ~55 view-less call sites consult. The statics
///   themselves are UI-side and cannot compile here, so what gets pinned is
///   the contract they are one `??` away from: `SettingsCache` reports an
///   absent key as `nil` rather than `false`, and this model resolves the same
///   absence to the same `SettingsDefault` value.
@MainActor
@Suite("Settings model")
struct AppSettingsTests {
    /// Each test gets its own suite so they cannot see each other's keys,
    /// matching `SavedDataArchiveTests.makeDefaults`. `.standard` is touched
    /// only by the `SettingsCache` test, under a throwaway key it removes.
    private func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - The persisted vocabulary (A6)

    /// One assertion per roster pins count, order and spelling at once. Order
    /// is not decoration: the pickers present `allCases` as-is.
    @Test("the twenty-seven raw values are pinned, in order")
    func vocabularyIsStable() {
        #expect(UIScale.allCases.map(\.rawValue) == ["SMALL", "LARGE"])
        #expect(LcdMode.allCases.map(\.rawValue) == [
            "DARK", "LIGHT", "VINTAGE", "AMBER", "WINE OS", "TERMINAL",
            "BLUE SCREEN", "STAR TREK", "GRUNER BOY",
        ])
        #expect(ChassisSkin.allCases.map(\.rawValue) == [
            "CLASSIC", "MIDNIGHT", "ORIGINAL", "BURGUNDY", "RIESLING",
            "VINHO VERDE", "GLOUGLOU", "SMART GRAPE", "CHAMPAGNE", "CHRISTMAS",
            "NOUVEAU", "OAKED", "NOCTURNE", "STEEL", "BLUSH", "PSVINO",
        ])
        // GRUNER BOY's raw value is ASCII on purpose — it persists, and the
        // umlaut lives in `displayName`. Hold the whole roster to that rule:
        // a stored string with a code point that can differ by normalisation
        // form is a stored string that can fail to round-trip.
        for raw in UIScale.allCases.map(\.rawValue)
            + LcdMode.allCases.map(\.rawValue)
            + ChassisSkin.allCases.map(\.rawValue) {
            // A closure, not `\.isASCII`: #expect decomposes a top-level call
            // into its expression tree, and a *key-path* argument to a
            // `rethrows` function expands into a wrapper the compiler flags
            // as un-`try`'d. Trailing closures are never decomposed.
            #expect(raw.allSatisfy { $0.isASCII }, "\(raw) is not ASCII")
        }
        // The chrome factors ride along, as `TypeScaleTests.stepsAreStable`
        // does for text: SMALL is the pre-0.5.8 layout and must stay 1.0;
        // 1.15 is as far as the chassis stretches before the footer trio
        // squeezes the marquee on a compact-width phone.
        #expect(UIScale.small.factor == 1.0)
        #expect(UIScale.large.factor == 1.15)
    }

    /// The strings on disk, not just the derivations. `SavedDataArchiveTests`
    /// proves each `storageKey` resolves to its registry case; this pins what
    /// the case *is*, because renaming a `SavedDataKey` raw value orphans the
    /// stored data exactly as renaming an enum's would.
    @Test("the eight settings keys are the stored bytes")
    func storageKeysAreStable() {
        #expect(SavedDataKey.textScale.rawValue == "textScale")
        #expect(SavedDataKey.uiScale.rawValue == "uiScale")
        #expect(SavedDataKey.lcdMode.rawValue == "lcdMode")
        #expect(SavedDataKey.chassisSkin.rawValue == "chassisSkin")
        #expect(SavedDataKey.hapticsEnabled.rawValue == "hapticsEnabled")
        #expect(SavedDataKey.soundsEnabled.rawValue == "soundsEnabled")
        #expect(SavedDataKey.keepAwakeEnabled.rawValue == "keepAwakeEnabled")
        // Not "displayName" — the key predates the registry, and "fixing" the
        // mismatch is precisely the rename this test exists to catch.
        #expect(SavedDataKey.displayName.rawValue == "userDisplayName")
    }

    /// The round trip a device actually performs: every choice a user can
    /// store must decode back to itself, and anything else — absent key, or a
    /// value written by some other build — must fall back to the default
    /// rather than crash or stick.
    @Test("every stored choice decodes back to its case")
    func decodeRoundTrips() {
        let d = makeDefaults()
        for mode in LcdMode.allCases {
            d.set(mode.rawValue, forKey: LcdMode.storageKey)
            #expect(LcdMode.current(in: d) == mode)
        }
        for skin in ChassisSkin.allCases {
            d.set(skin.rawValue, forKey: ChassisSkin.storageKey)
            #expect(ChassisSkin.current(in: d) == skin)
        }
        for scale in UIScale.allCases {
            d.set(scale.rawValue, forKey: UIScale.storageKey)
            #expect(UIScale.current(in: d) == scale)
        }

        let empty = makeDefaults()
        #expect(LcdMode.current(in: empty) == SettingsDefault.lcdMode)
        #expect(ChassisSkin.current(in: empty) == SettingsDefault.chassisSkin)
        #expect(UIScale.current(in: empty) == SettingsDefault.uiScale)

        empty.set("CHARTREUSE", forKey: LcdMode.storageKey)
        empty.set("CHARTREUSE", forKey: ChassisSkin.storageKey)
        empty.set("CHARTREUSE", forKey: UIScale.storageKey)
        #expect(LcdMode.current(in: empty) == SettingsDefault.lcdMode)
        #expect(ChassisSkin.current(in: empty) == SettingsDefault.chassisSkin)
        #expect(UIScale.current(in: empty) == SettingsDefault.uiScale)
    }

    /// `displayName` exists so a rename moves the label and only the label.
    /// Each pair below is a shipped rename riding on an unchanged raw value —
    /// collapse either side into the other and users get renamed tiles or
    /// reset choices respectively.
    @Test("a label rename moves the label and only the label")
    func labelsAreSplitFromStorage() {
        // BLUE SCREEN shipped in 0.5.1 and re-branded as VINOFD; the umlaut
        // that cannot be in GRUNER BOY's stored form lives in its label.
        #expect(LcdMode.blueScreen.rawValue == "BLUE SCREEN")
        #expect(LcdMode.blueScreen.displayName == "VINOFD")
        #expect(LcdMode.gruenerBoy.displayName == "GRÜNERBOY")
        #expect(LcdMode.wineOS.displayName == "WINE.OS")
        #expect(LcdMode.starTrek.displayName == "L-WINES")

        // The trap this split makes survivable: "VINHO VERDE" the *name* moved
        // houses (0.5.1 → 0.5.4) while "VINHO VERDE" the *stored value* stayed
        // put. The forest-green skin keeps the raw value and shows BOX WINE;
        // the glow skin wears the name. An "obvious" cleanup aligning them
        // would silently re-skin two sets of devices.
        #expect(ChassisSkin.vinhoVerde.rawValue == "VINHO VERDE")
        #expect(ChassisSkin.vinhoVerde.displayName == "BOX WINE")
        #expect(ChassisSkin.nocturne.rawValue == "NOCTURNE")
        #expect(ChassisSkin.nocturne.displayName == "VINHO VERDE")

        // Duplicate raw values cannot compile; duplicate labels can, and two
        // indistinguishable picker tiles is what they look like.
        let modeLabels = LcdMode.allCases.map(\.displayName)
        let skinLabels = ChassisSkin.allCases.map(\.displayName)
        #expect(Set(modeLabels).count == modeLabels.count)
        #expect(Set(skinLabels).count == skinLabels.count)
        #expect((modeLabels + skinLabels).allSatisfy { !$0.isEmpty })
    }

    /// `isLight` is an explicit list, not `!= .dark`, because membership is
    /// wrong in both directions when it drifts: vintage is dark ink on a pale
    /// ground and wants every light branch, amber is a dark mode that would
    /// get pale scrims. The globe inversion is LIGHT's alone — the other pale
    /// modes keep the normal texture under their own tints.
    @Test("the pale set is explicit, and only LIGHT inverts the globe")
    func paleSetIsExact() {
        let pale: Set<LcdMode> = [.light, .vintage, .wineOS, .gruenerBoy]
        for mode in LcdMode.allCases {
            #expect(mode.isLight == pale.contains(mode),
                    "\(mode.rawValue) on the wrong side of the pale set")
            #expect(mode.invertsGlobeTexture == (mode == .light),
                    "\(mode.rawValue) inverts the globe")
        }
    }

    /// The cue `DeviceChassis` mounts the mock internals on. A skin added to
    /// this set without art behind it shows an empty cavity.
    @Test("the translucent shells are exactly the two clear ones")
    func translucentSetIsExact() {
        let clear: Set<ChassisSkin> = [.glouglou, .nouveau]
        for skin in ChassisSkin.allCases {
            #expect(skin.isTranslucent == clear.contains(skin),
                    "\(skin.rawValue) on the wrong side of the clear set")
        }
    }

    // A `nextCyclesTheRoster` test stood here against `ChassisSkin.next` — a
    // member Core retired in 0.7.6 (A1) with the back-plate cycler it served;
    // the test was written from the stale API and never compiled. The roster
    // pin above is the half of it that was real.

    // MARK: - What an absent key means

    /// The declared defaults, pinned so flipping one is a deliberate change
    /// with a failing test to acknowledge, not a drive-by. Three of these are
    /// product decisions with histories: haptics default *on* (opt-out —
    /// part of the device's character), sounds *off* since 0.5.1 (opt-in),
    /// keep-awake *on* because **L40** carved the setting out of behaviour
    /// that was previously unconditional and changing the default would have
    /// changed the app under everyone.
    @Test("the declared defaults are the shipped ones")
    func defaultsAreStable() {
        #expect(SettingsDefault.textScale == .small)
        #expect(SettingsDefault.uiScale == .small)
        #expect(SettingsDefault.lcdMode == .dark)
        #expect(SettingsDefault.chassisSkin == .classic)
        #expect(SettingsDefault.hapticsEnabled == true)
        #expect(SettingsDefault.soundsEnabled == false)
        #expect(SettingsDefault.keepAwakeEnabled == true)
        #expect(SettingsDefault.displayName == "")
    }

    /// The three-state read the boolean defaults depend on. `Haptics.enabled`,
    /// `Sounds.enabled` and `ScreenWake.enabled` are all
    /// `SettingsCache.bool(forKey:) ?? SettingsDefault.…` — UI-side, so the
    /// spelling cannot compile here, but the mechanism can: an absent key must
    /// read as `nil`, because `bool(forKey:)`'s own answer for absence is
    /// `false`, which would turn haptics' and keep-awake's opt-*out* into an
    /// opt-in on every fresh install.
    ///
    /// The cache serves `.standard` only, so this test touches `.standard` —
    /// under a throwaway key it removes. Invalidation is explicit rather than
    /// trusted to `UserDefaults.didChangeNotification`, which is platform
    /// plumbing (macOS/iOS post it synchronously; this suite also runs on
    /// Linux). The contract under test is the read, not the wiring.
    @Test("the cache reports an absent key as nil, not false")
    func cacheKeepsAbsenceDistinct() {
        let key = "test-scratch-\(UUID().uuidString)"
        defer {
            UserDefaults.standard.removeObject(forKey: key)
            SettingsCache.invalidate()
        }

        #expect(SettingsCache.bool(forKey: key) == nil)
        #expect(SettingsCache.string(forKey: key) == nil)

        UserDefaults.standard.set(true, forKey: key)
        SettingsCache.invalidate()
        #expect(SettingsCache.bool(forKey: key) == true)

        UserDefaults.standard.set(false, forKey: key)
        SettingsCache.invalidate()
        // The state that separates "off" from "never asked":
        #expect(SettingsCache.bool(forKey: key) == false)

        UserDefaults.standard.removeObject(forKey: key)
        SettingsCache.invalidate()
        #expect(SettingsCache.bool(forKey: key) == nil)

        UserDefaults.standard.set("LARGE", forKey: key)
        SettingsCache.invalidate()
        #expect(SettingsCache.string(forKey: key) == "LARGE")
    }

    // MARK: - The model (A17)

    /// A fresh install answers `SettingsDefault` on every axis *without
    /// writing anything*: `init` must snapshot, not populate. A key created
    /// here would flip that user's absent-means-default into a stored literal
    /// — which is the difference between following a future default change
    /// and being pinned to the old one forever.
    @Test("a fresh install reads as the defaults and stores nothing")
    func freshInstallIsDefaultAndUnstored() {
        let d = makeDefaults()
        let settings = AppSettings(defaults: d)

        #expect(settings.textScale == SettingsDefault.textScale)
        #expect(settings.uiScale == SettingsDefault.uiScale)
        #expect(settings.lcdMode == SettingsDefault.lcdMode)
        #expect(settings.chassisSkin == SettingsDefault.chassisSkin)
        #expect(settings.hapticsEnabled == SettingsDefault.hapticsEnabled)
        #expect(settings.soundsEnabled == SettingsDefault.soundsEnabled)
        #expect(settings.keepAwakeEnabled == SettingsDefault.keepAwakeEnabled)
        #expect(settings.displayName == SettingsDefault.displayName)

        for key in SavedDataKey.allCases {
            #expect(d.object(forKey: key.rawValue) == nil,
                    "init wrote \(key.rawValue)")
        }
    }

    /// The other side of `init`: a device with history gets its history, not
    /// the defaults — including a false for a default-true flag, which is the
    /// case `Stored.flag`'s absent-check exists to keep distinct.
    @Test("a populated store is adopted, not defaulted")
    func populatedStoreIsAdopted() {
        let d = makeDefaults()
        d.set("HUGE", forKey: TextScale.storageKey)
        d.set("LARGE", forKey: UIScale.storageKey)
        d.set("AMBER", forKey: LcdMode.storageKey)
        d.set("PSVINO", forKey: ChassisSkin.storageKey)
        d.set(false, forKey: SavedDataKey.hapticsEnabled.rawValue)
        d.set(true, forKey: SavedDataKey.soundsEnabled.rawValue)
        d.set(false, forKey: SavedDataKey.keepAwakeEnabled.rawValue)
        d.set("TASTER IN CHIEF", forKey: SavedDataKey.displayName.rawValue)

        let settings = AppSettings(defaults: d)
        #expect(settings.textScale == .huge)
        #expect(settings.uiScale == .large)
        #expect(settings.lcdMode == .amber)
        #expect(settings.chassisSkin == .psvino)
        #expect(settings.hapticsEnabled == false)
        #expect(settings.soundsEnabled == true)
        #expect(settings.keepAwakeEnabled == false)
        #expect(settings.displayName == "TASTER IN CHIEF")
    }

    /// A change writes its key and only its key; re-assigning the value
    /// already held writes nothing at all. The second half is what keeps a
    /// fresh device fresh — SwiftUI bindings re-assign on appearance, and
    /// each spurious write would both create the key (see above) and post a
    /// `didChangeNotification` that drops `SettingsCache` for nothing.
    @Test("a change writes exactly its key; a non-change writes nothing")
    func writesAreExactAndGuarded() {
        let d = makeDefaults()
        let settings = AppSettings(defaults: d)

        settings.textScale = SettingsDefault.textScale
        for key in SavedDataKey.allCases {
            #expect(d.object(forKey: key.rawValue) == nil,
                    "re-assigning the default wrote \(key.rawValue)")
        }

        settings.textScale = .huge
        #expect(d.string(forKey: TextScale.storageKey) == "HUGE")
        for key in SavedDataKey.allCases where key != .textScale {
            #expect(d.object(forKey: key.rawValue) == nil,
                    "changing textScale wrote \(key.rawValue)")
        }

        settings.uiScale = .large
        settings.lcdMode = .terminal
        settings.chassisSkin = .christmas
        settings.hapticsEnabled = false
        settings.soundsEnabled = true
        settings.keepAwakeEnabled = false
        settings.displayName = "E"

        #expect(d.string(forKey: UIScale.storageKey) == "LARGE")
        #expect(d.string(forKey: LcdMode.storageKey) == "TERMINAL")
        #expect(d.string(forKey: ChassisSkin.storageKey) == "CHRISTMAS")
        #expect(d.object(forKey: SavedDataKey.hapticsEnabled.rawValue) != nil)
        #expect(d.bool(forKey: SavedDataKey.hapticsEnabled.rawValue) == false)
        #expect(d.bool(forKey: SavedDataKey.soundsEnabled.rawValue) == true)
        #expect(d.bool(forKey: SavedDataKey.keepAwakeEnabled.rawValue) == false)
        #expect(d.string(forKey: SavedDataKey.displayName.rawValue) == "E")
    }

    /// The **M35** restore path: `SavedDataRestore.apply` writes the keys
    /// behind the model's back and calls `reload()`. Without the reload the
    /// import changes nothing on screen and the next toggle writes the stale
    /// value back over the imported one.
    @Test("reload adopts a restore's writes")
    func reloadAdoptsExternalWrites() {
        let d = makeDefaults()
        let settings = AppSettings(defaults: d)
        #expect(settings.lcdMode == .dark)

        d.set("WINE OS", forKey: LcdMode.storageKey)
        d.set("HUGE", forKey: TextScale.storageKey)
        d.set(true, forKey: SavedDataKey.soundsEnabled.rawValue)
        settings.reload()

        #expect(settings.lcdMode == .wineOS)
        #expect(settings.textScale == .huge)
        #expect(settings.soundsEnabled == true)
    }

    /// The `isAdopting` pin, and the reason it is not bookkeeping:
    /// `SavedDataReset.wipeAll` removes every key and reloads, and a reload
    /// whose `didSet`s write back would re-create each key the user had moved
    /// off its default — with the default in it. `TextScale.seedIfUnset` keys
    /// on *absence*, so that write-back would permanently disable the
    /// first-launch accessibility seed for anyone who had ever changed their
    /// text size; `displayName` would come back as a stored `""` and ride
    /// into every future export.
    @Test("a wipe stays wiped: reload does not write the defaults back")
    func wipeStaysWiped() {
        let d = makeDefaults()
        let settings = AppSettings(defaults: d)
        settings.textScale = .huge
        settings.lcdMode = .amber
        settings.chassisSkin = .steel
        settings.hapticsEnabled = false
        settings.displayName = "E"
        #expect(d.object(forKey: TextScale.storageKey) != nil)

        // What wipeAll actually does, minus the UI-side stores.
        for key in SavedDataKey.allCases {
            d.removeObject(forKey: key.rawValue)
        }
        settings.reload()

        #expect(settings.textScale == SettingsDefault.textScale)
        #expect(settings.lcdMode == SettingsDefault.lcdMode)
        #expect(settings.chassisSkin == SettingsDefault.chassisSkin)
        #expect(settings.hapticsEnabled == SettingsDefault.hapticsEnabled)
        #expect(settings.displayName == SettingsDefault.displayName)
        for key in SavedDataKey.allCases {
            #expect(d.object(forKey: key.rawValue) == nil,
                    "reload re-created \(key.rawValue)")
        }

        // Still a working model afterwards — the adopting flag must not stick.
        settings.textScale = .large
        #expect(d.string(forKey: TextScale.storageKey) == "LARGE")
    }

    /// The regression `seedTextScaleIfUnset` was written for, end to end. The
    /// model is built when `RootView` is constructed — *before* `onAppear`
    /// runs the seed — so calling `TextScale.seedIfUnset` alone left a model
    /// still holding `.small` over storage that now said `.huge`: `DexFont`
    /// drew the seeded step, the picker highlighted SMALL, and tapping SMALL
    /// did nothing because the `oldValue` guard saw no change. Routed through
    /// the model, all three surfaces move together — and the tap works.
    @Test("the first-launch seed moves the model and storage together, once")
    func seedMovesModelAndStorageTogether() {
        let d = makeDefaults()
        let settings = AppSettings(defaults: d)

        #expect(settings.seedTextScaleIfUnset(systemOrdinal: 7) == .huge)
        #expect(settings.textScale == .huge)
        #expect(d.string(forKey: TextScale.storageKey) == "HUGE")

        // Second launch: the key exists now, so the seed stands down.
        #expect(settings.seedTextScaleIfUnset(systemOrdinal: 0) == nil)
        #expect(settings.textScale == .huge)
        #expect(d.string(forKey: TextScale.storageKey) == "HUGE")

        // The half of the old bug the picker felt: choosing SMALL after the
        // seed is a real change and must write.
        settings.textScale = .small
        #expect(d.string(forKey: TextScale.storageKey) == "SMALL")
    }

    /// A stored choice wins even when it *equals* the default — SMALL chosen
    /// is not SMALL absent. The seed keys on the key, not the value, which is
    /// exactly what the wipe test above protects the other side of.
    @Test("the seed never overrides a stored choice")
    func seedRespectsStoredChoice() {
        let d = makeDefaults()
        d.set("SMALL", forKey: TextScale.storageKey)
        let settings = AppSettings(defaults: d)

        #expect(settings.seedTextScaleIfUnset(systemOrdinal: 11) == nil)
        #expect(settings.textScale == .small)
        #expect(d.string(forKey: TextScale.storageKey) == "SMALL")
    }
}
