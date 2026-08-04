import Foundation
import Observation

/// The marquee drawer's pinned settings shortcuts (0.7.1, B5).
///
/// B5 asks for "a customizable pin bar where the user can pin up to two
/// Settings shortcuts". Two, and the limit is the feature rather than a
/// restriction on it: the drawer opens over the LCD from a panel at the bottom
/// of the device, and a pin bar that grows takes the room the TOOLS and
/// CUSTOMIZE sections need. A pin bar of five is the settings grid with extra
/// steps.
///
/// **Why a store and not `@AppStorage`.** The value is an ordered list with a
/// cap and a toggle rule, and `@AppStorage` can only hold the string. Putting
/// the rule in the view means every surface that ever shows the pin bar
/// re-implements "already pinned → unpin; two already → refuse", and the first
/// one to get it wrong silently stores three. This is the same shape as
/// `StampLayoutStore` and for the same reason, down to the injectable
/// `UserDefaults` so the tests do not fight each other.
@MainActor
@Observable
public final class QuickPinStore {
    public static let shared = QuickPinStore()

    /// One key holding a comma-joined list of `SettingsSection` raw values.
    ///
    /// The raw values are *display copy* (`SettingsSection`'s own note says so)
    /// and could in principle be renamed — so unknown entries are dropped on
    /// read rather than trusted, and a rename costs a user their pins instead
    /// of crashing or resurrecting a section that no longer exists.
    public static let storageKey = "marqueeQuickPins"

    /// The cap, named rather than typed as a literal `2` in three places.
    public static let capacity = 2

    private let defaults: UserDefaults
    private(set) public var pins: [SettingsSection]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.storageKey) ?? ""
        self.pins = Self.decode(raw)
    }

    /// Split, resolve, drop unknowns, drop duplicates, take the first `capacity`.
    ///
    /// Every one of those steps is a defence against a value this app did not
    /// write — an older build's list, a hand-edited plist, a section removed
    /// between releases. The store's invariant is that `pins` is always a valid
    /// list of at most two distinct sections, and it holds from the first read.
    static func decode(_ raw: String) -> [SettingsSection] {
        var seen: Set<SettingsSection> = []
        var out: [SettingsSection] = []
        for piece in raw.split(separator: ",") {
            guard
                let section = SettingsSection(rawValue: String(piece)),
                !seen.contains(section)
            else { continue }
            seen.insert(section)
            out.append(section)
            if out.count == capacity { break }
        }
        return out
    }

    public func isPinned(_ section: SettingsSection) -> Bool { pins.contains(section) }

    /// Whether pinning one more would be refused. The drawer reads this to dim
    /// the unpinned chips rather than letting a tap do nothing.
    public var isFull: Bool { pins.count >= Self.capacity }

    /// Pin an unpinned section, unpin a pinned one.
    ///
    /// **Oldest out when full**, rather than refusing. A pin bar that says "no"
    /// makes the user work out which of their two pins to remove first and then
    /// come back; a queue of two just does what the tap plainly meant. It is
    /// also reversible in one more tap, which "refuse" is not.
    ///
    /// Returns the resulting pinned state of `section`, so a caller can pick
    /// its haptic without re-reading.
    @discardableResult
    public func toggle(_ section: SettingsSection) -> Bool {
        if let index = pins.firstIndex(of: section) {
            pins.remove(at: index)
            persist()
            return false
        }
        pins.append(section)
        if pins.count > Self.capacity {
            pins.removeFirst(pins.count - Self.capacity)
        }
        persist()
        return true
    }

    public func reset() {
        pins = []
        persist()
    }

    /// Removes the key outright when the list empties, matching
    /// `StampLayoutStore`: an empty stored value and no stored value must not
    /// be two different states, or `SavedDataReset` has to know about both.
    private func persist() {
        if pins.isEmpty {
            defaults.removeObject(forKey: Self.storageKey)
        } else {
            defaults.set(pins.map(\.rawValue).joined(separator: ","), forKey: Self.storageKey)
        }
    }
}
