import Testing
import Foundation
@testable import VinodexCore

/// The Device Workshop's Core half (0.7.3, B1/B2).
///
/// **What is checkable here and what is not.** The palette, the ramps derived
/// from it, the grille patterns and the whole builder are `VinodexUI` — they
/// resolve to `Color`, which Linux cannot compile — so none of that is reachable
/// from this suite and only the clean `xtool` build proves it. What *is* here is
/// the part that would be silently wrong: which key an axis writes, whether an
/// unset axis and an axis set to `""` are the same state, whether applying a
/// saved build reproduces it exactly, and every rule about naming a build. Those
/// are the rules a view would otherwise re-implement per call site, which is the
/// failure F1 spent a batch undoing one layer down.
@MainActor
@Suite("Device workshop")
struct DeviceWorkshopTests {

    /// A defaults suite of its own per test, so two tests cannot fight over
    /// `chassisSkin` — which is a *real* key holding a real user's shell, and the
    /// one thing in this suite it would be genuinely rude to write to.
    private func scratch() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: The axes

    /// The two axes that predate the workshop keep the keys they have always
    /// had.
    ///
    /// This is the assertion that matters most in the whole suite: those two keys
    /// hold real choices on real installs, and moving either would reset every
    /// device in the field to a black CLASSIC on first launch of the update. The
    /// spellings are load-bearing exactly as `Entitlement.id`'s are.
    @Test("the shell and screen keys are the ones already in the field")
    func legacyKeysAreUntouched() {
        #expect(DeviceAxis.shell.storageKey == "chassisSkin")
        #expect(DeviceAxis.screen.storageKey == "lcdMode")
    }

    @Test("every axis has a distinct key, title and glyph")
    func axesAreDistinct() {
        var keys: Set<String> = []
        var titles: Set<String> = []
        var symbols: Set<String> = []
        for axis in DeviceAxis.allCases {
            #expect(!axis.storageKey.isEmpty)
            #expect(!axis.title.isEmpty)
            #expect(!axis.symbol.isEmpty)
            keys.insert(axis.storageKey)
            titles.insert(axis.title)
            symbols.insert(axis.symbol)
        }
        #expect(keys.count == DeviceAxis.allCases.count, "two axes share a storage key")
        #expect(titles.count == DeviceAxis.allCases.count, "two axes share a row title")
        #expect(symbols.count == DeviceAxis.allCases.count, "two axes share a glyph")
    }

    /// **The axis roster, pinned** (0.7.6, B1).
    ///
    /// A count, and it is a weak gate on purpose — it fails only when somebody
    /// adds an axis and bumps the number without meaning to. What it is really
    /// for is the sentence below it: `chosenCount` and the workshop's "n OF m
    /// PARTS" readout both count `allCases`, and a batch that adds a part without
    /// noticing that a *saved build* has to keep decoding is the failure
    /// `buildsFromAnEarlierBuildStillDecode` covers.
    @Test("the ten axes are the ten the workshop draws")
    func axisRoster() {
        // Eight through 0.7.5; ten since 0.7.6 (B1) added the header lamp trio
        // and the two marquee lamps as separate colour axes.
        #expect(DeviceAxis.allCases.count == 10)
        #expect(DeviceAxis.allCases.contains(.headerLamps))
        #expect(DeviceAxis.allCases.contains(.marqueeLamps))
        // The two new keys, spelled out. They are `@AppStorage` keys from the
        // moment this ships, so they are as unmovable as the eight before them.
        #expect(DeviceAxis.headerLamps.storageKey == "devicePartHeaderLamps")
        #expect(DeviceAxis.marqueeLamps.storageKey == "devicePartMarqueeLamps")
    }

    /// **A build saved before this batch must still decode** (0.7.6, B1).
    ///
    /// The synthesised `Codable` decoder throws on a missing key, and
    /// `CustomDeviceStore` reads its list with `try?` — so adding a field would
    /// have made every device saved under 0.7.3b–0.7.5 fail to decode, the store
    /// return an empty array, and every saved build vanish on first launch of the
    /// update. Nothing in the project would have reported it, because the store's
    /// own defensive `sanitize` never runs on a list that failed to decode at all.
    ///
    /// This is that failure, written as the JSON an older build actually wrote.
    @Test("a build saved by an earlier version still decodes")
    func buildsFromAnEarlierBuildStillDecode() throws {
        // Exactly the eight keys 0.7.5 encoded, and no others.
        let json = """
        {"shell":"STEEL","buttons":"COBALT","orb":"VIOLET","marquee":"STRAW",\
        "grilleColor":"SLATE","grilleShape":"MESH","screen":"TERMINAL","font":"IVORY"}
        """
        let build = try JSONDecoder().decode(DeviceBuild.self, from: Data(json.utf8))
        #expect(build.shell == "STEEL")
        #expect(build.grilleShape == "MESH")
        #expect(build.font == "IVORY")
        // The two axes that did not exist arrive unset, which is this type's own
        // "as the device ships" — so an old build describes the same device it
        // always did, plus two parts nobody had chosen.
        #expect(build.headerLamps.isEmpty)
        #expect(build.marqueeLamps.isEmpty)
        #expect(build.chosenCount == 8)

        // The whole-store path, which is where the data loss would have landed.
        let device = try JSONDecoder().decode(
            [CustomDevice].self,
            from: Data("[{\"id\":\"abc\",\"name\":\"KEEPER\",\"build\":\(json)}]".utf8)
        )
        #expect(device.count == 1)
        #expect(device[0].build.shell == "STEEL")

        // And an empty object — the most degenerate thing a hand-edited plist
        // could hold — is the stock device rather than a throw.
        let empty = try JSONDecoder().decode(DeviceBuild.self, from: Data("{}".utf8))
        #expect(empty.isStock)
    }

    /// The subscript reaches the field it names, for all ten.
    ///
    /// The builder draws one row per axis and sets it through this subscript, so
    /// a mis-wired arm would put the orb colour on the marquee with nothing in a
    /// view to say so. Setting each axis to its own name and reading them all
    /// back catches any crossed pair.
    @Test("the axis subscript round-trips every field")
    func axesRoundTrip() {
        var build = DeviceBuild()
        for axis in DeviceAxis.allCases {
            build[axis] = axis.rawValue
        }
        for axis in DeviceAxis.allCases {
            #expect(build[axis] == axis.rawValue, "\(axis) does not read back what it was set to")
        }
        #expect(build.chosenCount == DeviceAxis.allCases.count)
    }

    /// Whitespace cannot mint a third state.
    ///
    /// `""` means "as the device ships" and absence means the same thing; a value
    /// of `"  "` that survived would be neither, and the axis would read as
    /// chosen while painting nothing.
    @Test("a whitespace-only choice is no choice")
    func whitespaceNormalises() {
        var build = DeviceBuild()
        build[.orb] = "   "
        #expect(build.orb.isEmpty)
        #expect(build.isStock)
    }

    @Test("the stock build has nothing fitted")
    func stockIsEmpty() {
        #expect(DeviceBuild.stock.chosenCount == 0)
        #expect(DeviceBuild.stock.isStock)
        for axis in DeviceAxis.allCases {
            #expect(DeviceBuild.stock[axis].isEmpty)
        }
    }

    // MARK: The live device

    @Test("a build applies and reads back identically")
    func applyRoundTrips() {
        let defaults = scratch()
        let build = DeviceBuild(
            shell: "MIDNIGHT",
            buttons: "COBALT",
            orb: "VIOLET",
            headerLamps: "ABSINTHE",
            marquee: "STRAW",
            marqueeLamps: "CLARET",
            grilleColor: "SLATE",
            grilleShape: "MESH",
            screen: "TERMINAL",
            font: "IVORY"
        )
        build.apply(to: defaults)
        #expect(DeviceBuild.active(in: defaults) == build)
        #expect(build.chosenCount == DeviceAxis.allCases.count)
    }

    /// An empty axis removes its key rather than storing `""`.
    ///
    /// The same rule `QuickPinStore` and `StampLayoutStore` follow, and it is not
    /// housekeeping: `chassisSkin` set to the empty string would make
    /// `ChassisSkin(rawValue: "")` fail on every launch — which it survives, via
    /// `?? .classic` — while leaving a key in the defaults that a reader could
    /// reasonably take as a choice.
    @Test("clearing a part removes its key")
    func emptyAxesLeaveNothingBehind() {
        let defaults = scratch()
        DeviceBuild(orb: "VIOLET").apply(to: defaults)
        #expect(defaults.string(forKey: DeviceAxis.orb.storageKey) == "VIOLET")

        DeviceBuild.stock.apply(to: defaults)
        for axis in DeviceAxis.allCases {
            #expect(defaults.object(forKey: axis.storageKey) == nil, "\(axis) left a key behind")
        }
        #expect(DeviceBuild.active(in: defaults).isStock)
    }

    /// A device nobody has customised reads as stock.
    @Test("an untouched install is factory stock")
    func freshInstallIsStock() {
        #expect(DeviceBuild.active(in: scratch()).isStock)
    }

    // MARK: Saved builds

    @Test("save, load, apply")
    func saveAndApply() {
        let defaults = scratch()
        let store = CustomDeviceStore(defaults: defaults)
        let build = DeviceBuild(shell: "STEEL", orb: "GLACIER", grilleShape: "DOTS")

        guard case .saved = store.save(name: "workbench", build: build) else {
            Issue.record("first save should be a new build")
            return
        }
        #expect(store.devices.count == 1)
        // Normalised on the way in — see `CustomDeviceStore.normalize(_:)`.
        #expect(store.devices[0].name == "WORKBENCH")

        store.devices[0].build.apply(to: defaults)
        #expect(DeviceBuild.active(in: defaults) == build)
    }

    /// Saving under a name already in the list replaces that build — which is
    /// what "edit" is, and is the alternative to a list with three GARAGEs in it.
    @Test("re-saving a name replaces rather than duplicates")
    func saveReplacesByName() {
        let store = CustomDeviceStore(defaults: scratch())
        guard case .saved(let first) = store.save(name: "GARAGE", build: DeviceBuild(orb: "AMBER")) else {
            Issue.record("expected a new build")
            return
        }
        guard case .replaced(let second) = store.save(name: " garage ", build: DeviceBuild(orb: "ONYX")) else {
            Issue.record("expected a replacement")
            return
        }
        #expect(first == second, "a replacement keeps the build's identity")
        #expect(store.devices.count == 1)
        #expect(store.devices[0].build.orb == "ONYX")
    }

    @Test("a build needs a name")
    func namelessSaveIsRefused() {
        let store = CustomDeviceStore(defaults: scratch())
        #expect(store.save(name: "   ", build: DeviceBuild(orb: "ROSE")) == .needsName)
        #expect(store.devices.isEmpty)
    }

    @Test("names are trimmed, collapsed, uppercased and clipped")
    func namesNormalise() {
        #expect(CustomDeviceStore.normalize("  my   little  device ") == "MY LITTLE DEVICE")
        #expect(CustomDeviceStore.normalize("") == "")
        #expect(CustomDeviceStore.normalize("\n\t ") == "")
        let long = CustomDeviceStore.normalize(String(repeating: "A", count: 40))
        #expect(long.count == CustomDeviceStore.nameLimit)
    }

    @Test("the list stops at capacity")
    func capacityHolds() {
        let store = CustomDeviceStore(defaults: scratch())
        for index in 0..<CustomDeviceStore.capacity {
            guard case .saved = store.save(name: "BUILD \(index)", build: DeviceBuild(orb: "AMBER")) else {
                Issue.record("build \(index) should have saved")
                return
            }
        }
        #expect(store.isFull)
        #expect(store.save(name: "ONE MORE", build: DeviceBuild()) == .full)
        // A *replacement* still goes through when full — it adds nothing.
        guard case .replaced = store.save(name: "BUILD 0", build: DeviceBuild(orb: "ONYX")) else {
            Issue.record("replacing at capacity should be allowed")
            return
        }
        #expect(store.devices.count == CustomDeviceStore.capacity)
    }

    @Test("renaming refuses a name another build holds")
    func renameGuardsCollisions() {
        let store = CustomDeviceStore(defaults: scratch())
        guard
            case .saved(let a) = store.save(name: "ALPHA", build: DeviceBuild(orb: "AMBER")),
            case .saved = store.save(name: "BETA", build: DeviceBuild(orb: "ONYX"))
        else {
            Issue.record("setup failed")
            return
        }
        #expect(store.rename(id: a, to: "BETA") == .nameTaken)
        #expect(store.device(id: a)?.name == "ALPHA")
        guard case .replaced = store.rename(id: a, to: "gamma") else {
            Issue.record("a free name should be accepted")
            return
        }
        #expect(store.device(id: a)?.name == "GAMMA")
        #expect(store.device(named: "gamma")?.id == a)
    }

    @Test("deleting removes exactly one build")
    func deleteRemovesOne() {
        let store = CustomDeviceStore(defaults: scratch())
        guard
            case .saved(let a) = store.save(name: "ALPHA", build: DeviceBuild(orb: "AMBER")),
            case .saved = store.save(name: "BETA", build: DeviceBuild(orb: "ONYX"))
        else {
            Issue.record("setup failed")
            return
        }
        store.delete(id: a)
        #expect(store.devices.map(\.name) == ["BETA"])
        // Deleting something already gone is a no-op rather than a crash.
        store.delete(id: a)
        #expect(store.devices.count == 1)
    }

    /// Which build the device is wearing is **derived**, never stored.
    ///
    /// The point of the comparison is what it does *after* a part changes: the
    /// device stops matching, because it is no longer that build. A stored
    /// "active build id" would have gone on claiming otherwise, which is the
    /// second-source-of-truth fork this whole design refuses.
    @Test("the fitted build is worked out, not remembered")
    func fittedBuildIsDerived() {
        let defaults = scratch()
        let store = CustomDeviceStore(defaults: defaults)
        let build = DeviceBuild(shell: "BLUSH", marquee: "ROSE")
        store.save(name: "PINK ONE", build: build)

        build.apply(to: defaults)
        #expect(store.matching(DeviceBuild.active(in: defaults))?.name == "PINK ONE")

        var tweaked = DeviceBuild.active(in: defaults)
        tweaked[.orb] = "GLACIER"
        tweaked.apply(to: defaults)
        #expect(store.matching(DeviceBuild.active(in: defaults)) == nil)
    }

    // MARK: Choosing a preset (0.7.8, A2)

    /// The governance graph is a graph — two roots, every other axis hanging off
    /// exactly one of them, and nothing hanging off a part.
    ///
    /// This is the gate on the eleventh axis. `inherits` is an exhaustive switch,
    /// so a new case cannot compile without an answer; what it cannot catch is an
    /// answer that is *wrong in shape* — a part naming another part as its preset,
    /// or a third preset appearing and quietly governing nothing, which would make
    /// it a picker whose choices override nothing at all.
    @Test("every axis inherits from a preset, and only presets are presets")
    func everyAxisDeclaresItsPreset() {
        let presets = DeviceAxis.allCases.filter(\.isPreset)
        #expect(Set(presets) == Set([.shell, .screen]))

        for axis in DeviceAxis.allCases {
            if let parent = axis.inherits {
                #expect(parent.isPreset, "\(axis) inherits from \(parent), which is not a preset")
                #expect(parent != axis, "\(axis) inherits from itself")
            }
        }
        // Every part is governed by exactly one preset, and every preset governs
        // something — so the two lists partition the axes with nothing over.
        let governed = presets.flatMap(\.governs)
        #expect(Set(governed).count == governed.count, "an axis is governed twice: \(governed)")
        #expect(Set(governed) == Set(DeviceAxis.allCases.filter { !$0.isPreset }))
        for preset in presets {
            #expect(!preset.governs.isEmpty, "\(preset) is a preset that overrides nothing")
        }
        // The split as it stands, pinned so a part moving between the two roots
        // is a deliberate edit. Seven parts follow the shell; the font follows
        // the screen, because `LcdMode.fontInk` is what it falls back into.
        #expect(DeviceAxis.shell.governs.count == 7)
        #expect(DeviceAxis.screen.governs == [.font])
    }

    /// **The behaviour A2 asks for.** Choosing a shell clears the parts fitted on
    /// top of it, so the shell's own palette is what shows.
    @Test("a chosen preset clears the parts that were overriding it")
    func choosingAPresetClearsWhatItGoverns() {
        let defaults = scratch()
        DeviceBuild(shell: "MIDNIGHT", buttons: "COBALT", orb: "AMBER",
                    headerLamps: "ROSE", grilleShape: "BARS", font: "IVORY")
            .apply(to: defaults)

        // Announced before it happens, in workshop order, and only the parts
        // actually fitted — GRILLE was never set, so it is not in the list.
        let cleared = DeviceBuild.overrides(clearedByChoosing: .shell, in: defaults)
        #expect(cleared == [.buttons, .orb, .headerLamps, .grilleShape])

        DeviceBuild.choose(.shell, "BLUSH", defaultValue: "CLASSIC", in: defaults)

        let after = DeviceBuild.active(in: defaults)
        #expect(after.shell == "BLUSH")
        for axis in DeviceAxis.shell.governs {
            #expect(after[axis].isEmpty, "\(axis) survived a preset choice")
            #expect(defaults.object(forKey: axis.storageKey) == nil, "\(axis) left an empty string behind")
        }
    }

    /// The two pickers on CUSTOMIZE are independent, and this is the bug the
    /// governance rule exists to prevent: picking a shell must not reach across
    /// and undo the screen mode listed below it.
    @Test("a preset clears its own parts and nobody else's")
    func choosingAPresetLeavesTheOtherPresetAlone() {
        let defaults = scratch()
        DeviceBuild(shell: "OAKED", orb: "GLACIER", screen: "AMBER", font: "IVORY")
            .apply(to: defaults)

        DeviceBuild.choose(.shell, "STEEL", defaultValue: "CLASSIC", in: defaults)
        var after = DeviceBuild.active(in: defaults)
        #expect(after.orb.isEmpty)
        #expect(after.screen == "AMBER", "the shell reached into the screen mode")
        #expect(after.font == "IVORY", "the shell cleared a part the screen governs")

        DeviceBuild.choose(.screen, "DARK", defaultValue: "DARK", in: defaults)
        after = DeviceBuild.active(in: defaults)
        #expect(after.font.isEmpty)
        #expect(after.shell == "STEEL", "the screen reached into the shell")
    }

    /// Picking the shipped default stores absence, not its name.
    ///
    /// The two writers disagreed about this until 0.7.8: the workshop's chooser
    /// wrote `""` for CLASSIC and the settings grid wrote `"CLASSIC"`, so the
    /// same choice produced two different `DeviceBuild`s and a visually stock
    /// device could report `isStock == false` forever.
    @Test("choosing the default preset leaves no key behind")
    func choosingTheDefaultStoresNothing() {
        let defaults = scratch()
        DeviceBuild(shell: "BLUSH", orb: "ROSE").apply(to: defaults)

        DeviceBuild.choose(.shell, "CLASSIC", defaultValue: "CLASSIC", in: defaults)
        #expect(defaults.object(forKey: DeviceAxis.shell.storageKey) == nil)
        #expect(DeviceBuild.active(in: defaults).isStock)

        // Whitespace is not a third state here either.
        DeviceBuild.choose(.shell, "  BLUSH  ", defaultValue: "CLASSIC", in: defaults)
        #expect(DeviceBuild.active(in: defaults).shell == "BLUSH")
    }

    /// **Nothing saved is destroyed.** The build stops being *fitted*, because
    /// `matching(_:)` compares values and the values changed — which is the same
    /// thing that already happened when one part was swapped in the workshop. It
    /// is still in the list, still named, one tap from being fitted again.
    @Test("choosing a preset unfits a saved build without deleting it")
    func choosingAPresetDoesNotTouchSavedBuilds() {
        let defaults = scratch()
        let store = CustomDeviceStore(defaults: defaults)
        let build = DeviceBuild(shell: "BLUSH", buttons: "ROSE", orb: "AMBER")
        store.save(name: "PINK ONE", build: build)
        build.apply(to: defaults)
        #expect(store.matching(DeviceBuild.active(in: defaults))?.name == "PINK ONE")

        DeviceBuild.choose(.shell, "STEEL", defaultValue: "CLASSIC", in: defaults)

        #expect(store.matching(DeviceBuild.active(in: defaults)) == nil, "it should no longer be fitted")
        #expect(store.devices.count == 1, "the saved build was deleted")
        #expect(store.devices[0].build == build, "the saved build was rewritten")
        // And it survives a relaunch, which is the check that the blob itself
        // was never rewritten rather than merely that this instance still holds it.
        #expect(CustomDeviceStore(defaults: defaults).devices[0].build == build)

        // Re-fitting it is one call and restores every axis.
        build.apply(to: defaults)
        #expect(store.matching(DeviceBuild.active(in: defaults))?.name == "PINK ONE")
    }

    /// An untouched device asks nothing, which is what keeps the confirmation in
    /// `SettingsPanel.fit(_:)` an exception rather than a tax on every tap.
    @Test("a stock device has nothing to clear")
    func stockDeviceClearsNothing() {
        let defaults = scratch()
        #expect(DeviceBuild.overrides(clearedByChoosing: .shell, in: defaults).isEmpty)
        #expect(DeviceBuild.overrides(clearedByChoosing: .screen, in: defaults).isEmpty)

        // A shell on its own is not a fitted part — swapping shells on a device
        // that has never seen the workshop must not raise a prompt.
        DeviceBuild(shell: "MIDNIGHT", screen: "AMBER").apply(to: defaults)
        #expect(DeviceBuild.overrides(clearedByChoosing: .shell, in: defaults).isEmpty)
        #expect(DeviceBuild.overrides(clearedByChoosing: .screen, in: defaults).isEmpty)
    }

    /// Saved builds survive a relaunch, and arrive normalised.
    @Test("saved builds persist across a fresh store")
    func buildsPersist() {
        let defaults = scratch()
        let first = CustomDeviceStore(defaults: defaults)
        first.save(name: "KEEPER", build: DeviceBuild(shell: "OAKED", grilleShape: "BARS"))

        let second = CustomDeviceStore(defaults: defaults)
        #expect(second.devices.count == 1)
        #expect(second.devices[0].name == "KEEPER")
        #expect(second.devices[0].build.grilleShape == "BARS")

        second.reset()
        #expect(CustomDeviceStore(defaults: defaults).devices.isEmpty)
        #expect(defaults.object(forKey: CustomDeviceStore.storageKey) == nil)
    }

    /// A stored list this app did not write is repaired on read rather than
    /// trusted — an older build, a restored backup, a hand-edited plist.
    @Test("a stored list is sanitised on the way in")
    func storedListIsRepaired() {
        let raw = [
            CustomDevice(name: "  keeper ", build: DeviceBuild(orb: "AMBER")),
            CustomDevice(name: "KEEPER", build: DeviceBuild(orb: "ONYX")),
            CustomDevice(name: "   ", build: DeviceBuild()),
        ]
        let clean = CustomDeviceStore.sanitize(raw)
        #expect(clean.map(\.name) == ["KEEPER"], "duplicates and unnameable entries are dropped")

        let overflowing = (0..<(CustomDeviceStore.capacity + 5)).map {
            CustomDevice(name: "BUILD \($0)", build: DeviceBuild())
        }
        #expect(CustomDeviceStore.sanitize(overflowing).count == CustomDeviceStore.capacity)
    }

    // MARK: The gate

    /// The workshop is gated on the entitlement F1 added for it, through the one
    /// store — not a flag of its own.
    @Test("the workshop rides the workshop entitlement")
    func workshopIsGatedOnItsBundle() {
        let defaults = scratch()
        let access = AccessStore(defaults: defaults, store: LocalEntitlementStore(defaults: defaults))
        access.starterOnly = true

        #expect(!access.isUnlocked(.workshop))
        access.grant(.workshop)
        #expect(access.isUnlocked(.workshop))
        // Buying the workshop buys the workshop. The shell and screen pickers
        // keep their own bundles — see `DeviceWorkshopScreen.shellChooser`.
        #expect(!access.isUnlocked(.skins))
        #expect(!access.isUnlocked(.lightMode))
    }

    /// GARAGISTE grants the real bundle, like every other code (A4/F1).
    @Test("the workshop cheat code grants the workshop")
    func garagisteUnlocksTheWorkshop() {
        let code = CheatCodes.match("garagiste")
        #expect(code?.grants == .workshop)
        // Forgiving matching, per `CheatCodes.match(_:)`.
        #expect(CheatCodes.match(" GARAGISTE ")?.grants == .workshop)
        #expect(CheatCodes.match("garage") == nil, "no fuzzy matching on a secret")
    }
}
