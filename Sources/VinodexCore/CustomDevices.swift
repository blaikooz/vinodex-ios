import Foundation
import Observation

/// One saved handheld, named by the player (0.7.3, B2).
///
/// A name and a `DeviceBuild`, and nothing else. In particular **no "is this the
/// active one" flag**: which build the device is currently wearing is answered by
/// comparing the live keys against each saved build (`CustomDeviceStore.matching(_:)`),
/// not by a stored marker. A flag would be a second answer to "what does the
/// device look like right now", and the first one — the eight defaults keys the
/// chassis actually reads — would win every disagreement while the flag went on
/// being displayed. That is the fork F1 spent a batch removing from the
/// entitlement layer and it is not being reintroduced one release later.
///
/// `id` is a UUID string rather than the name, so renaming a build is a rename
/// rather than a delete and a re-save.
public struct CustomDevice: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    /// Normalised — see `CustomDeviceStore.normalize(_:)`. Never empty.
    public var name: String
    public var build: DeviceBuild

    public init(id: String = UUID().uuidString, name: String, build: DeviceBuild) {
        self.id = id
        self.name = name
        self.build = build
    }
}

/// The player's saved builds (0.7.3, B2).
///
/// **Why a store rather than `@AppStorage`.** The value is an ordered list with
/// a cap, a name-normalisation rule and a save-or-replace rule, and `@AppStorage`
/// can only hold the blob. Putting the rules in the view means the workshop
/// re-implements "trim it, uppercase it, refuse an empty one, replace rather than
/// duplicate a name already taken" — in a module Linux cannot compile, so the
/// first version of it to get the rule wrong ships. This is the same shape as
/// `QuickPinStore` and `StampLayoutStore`, down to the injectable `UserDefaults`
/// so the tests do not fight each other.
///
/// **`apply` is not on this type.** Applying a build is `build.apply(to:)` —
/// writing the eight device keys — and a store of saved recipes has no business
/// owning that. Keeping it out is what stops this becoming the second place that
/// knows what the device currently looks like.
@MainActor
@Observable
public final class CustomDeviceStore {
    public static let shared = CustomDeviceStore()

    /// A JSON array of `CustomDevice`. New in 0.7.3b, so there is no legacy
    /// encoding to preserve — unlike `LocalEntitlementStore.storageKey`, which
    /// could not be improved for exactly that reason.
    public nonisolated static let storageKey = "customDevices"

    /// The cap, named rather than typed as a literal in three places.
    ///
    /// Twelve, because the saved-build list is a scrolling column inside an LCD
    /// roughly nine rows tall, and a list you have to scroll to find the build
    /// you made yesterday is a list that wants a search field — which is a
    /// second feature growing out of the side of this one. Twelve is more builds
    /// than the seven axes can meaningfully distinguish anyway.
    public nonisolated static let capacity = 12

    /// The longest name that fits a saved-build row beside its swatch strip at
    /// the retro face's 12pt without scaling down.
    public nonisolated static let nameLimit = 16

    private let defaults: UserDefaults
    public private(set) var devices: [CustomDevice]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([CustomDevice].self, from: data) {
            // Re-normalised on read rather than trusted: this is a value the app
            // did not necessarily write (an older build, a restored backup, a
            // hand-edited plist), and every rule below is cheaper to re-apply
            // than to reason about having been skipped once.
            devices = Self.sanitize(decoded)
        } else {
            devices = []
        }
    }

    /// Drop the unnameable, dedupe by name, take the first `capacity`.
    nonisolated static func sanitize(_ raw: [CustomDevice]) -> [CustomDevice] {
        var seen: Set<String> = []
        var out: [CustomDevice] = []
        for device in raw {
            let name = normalize(device.name)
            guard !name.isEmpty, !seen.contains(name) else { continue }
            seen.insert(name)
            out.append(CustomDevice(id: device.id, name: name, build: device.build))
            if out.count == capacity { break }
        }
        return out
    }

    /// Trim, collapse internal runs of whitespace, uppercase, clip to
    /// `nameLimit`.
    ///
    /// Uppercase because every label on this device is — the retro face has one
    /// case and a lowercase name would render as capitals anyway, so storing it
    /// lowercase would make two builds called `garage` and `GARAGE` look
    /// identical in the list while counting as different names. Normalising up
    /// front means the uniqueness rule below is the rule the user can see.
    public nonisolated static func normalize(_ raw: String) -> String {
        let collapsed = raw
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .uppercased()
        return String(collapsed.prefix(nameLimit))
    }

    /// What `save(name:build:)` did.
    public enum SaveOutcome: Equatable, Sendable {
        /// A new build was added.
        case saved(id: String)
        /// A build of that name already existed and now holds the new parts.
        /// This is what "edit" is: re-saving under the same name.
        case replaced(id: String)
        /// The name normalised to nothing, or named a build that is not there.
        case needsName
        /// `capacity` builds already exist and none of them is called this.
        case full
        /// A *different* build already holds that name. Only `rename` can
        /// produce this — `save` treats a name already in the list as the
        /// instruction to overwrite it.
        case nameTaken
    }

    public func device(id: String) -> CustomDevice? {
        devices.first { $0.id == id }
    }

    public func device(named raw: String) -> CustomDevice? {
        let name = Self.normalize(raw)
        guard !name.isEmpty else { return nil }
        return devices.first { $0.name == name }
    }

    /// The saved build the device is wearing right now, if any.
    ///
    /// **Derived, never stored** — see the note on `CustomDevice`. A build that
    /// has been applied and then had one part changed in the workshop stops
    /// matching, which is correct and is the whole reason this is a comparison:
    /// the device is not "wearing GARAGE with modifications", it is wearing
    /// something that is no longer GARAGE, and the list says so by ticking
    /// nothing.
    public func matching(_ build: DeviceBuild) -> CustomDevice? {
        devices.first { $0.build == build }
    }

    /// Save under a name, replacing a build already called that.
    ///
    /// **Replace rather than duplicate**, because the alternative is a list with
    /// three builds called GARAGE in it and no way to tell which the user meant.
    /// It also gives B2's "edit" its natural verb: change some parts, save under
    /// the same name, done — rather than a modal edit mode that has to be
    /// entered, exited and cancelled.
    @discardableResult
    public func save(name rawName: String, build: DeviceBuild) -> SaveOutcome {
        let name = Self.normalize(rawName)
        guard !name.isEmpty else { return .needsName }

        if let index = devices.firstIndex(where: { $0.name == name }) {
            devices[index].build = build
            persist()
            return .replaced(id: devices[index].id)
        }
        guard devices.count < Self.capacity else { return .full }

        let device = CustomDevice(name: name, build: build)
        devices.append(device)
        persist()
        return .saved(id: device.id)
    }

    /// Give a saved build a different name.
    ///
    /// Refuses a name another build already holds rather than silently merging
    /// two builds into one — `save` may replace by name because the user just
    /// typed that name over a build they were looking at; a rename that ate an
    /// unrelated build would be a delete nobody asked for.
    @discardableResult
    public func rename(id: String, to rawName: String) -> SaveOutcome {
        let name = Self.normalize(rawName)
        guard !name.isEmpty else { return .needsName }
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return .needsName }
        if devices.contains(where: { $0.id != id && $0.name == name }) {
            return .nameTaken
        }
        devices[index].name = name
        persist()
        return .replaced(id: id)
    }

    public func delete(id: String) {
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        devices.remove(at: index)
        persist()
    }

    public var isFull: Bool { devices.count >= Self.capacity }

    public func reset() {
        devices = []
        defaults.removeObject(forKey: Self.storageKey)
    }

    /// Removes the key outright when the list empties — see `reset`'s siblings
    /// in `QuickPinStore` and `StampLayoutStore` for why absence and emptiness
    /// must not be two states.
    private func persist() {
        guard !devices.isEmpty, let data = try? JSONEncoder().encode(devices) else {
            defaults.removeObject(forKey: Self.storageKey)
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }
}
