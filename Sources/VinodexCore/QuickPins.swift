import Foundation
import Observation

/// Somewhere one of the marquee's two lamp buttons can be pointed (0.7.6, A1).
///
/// **Why this type exists, when the store already had a vocabulary.** Through
/// 0.7.5 the pins were `SettingsSection` values, because the drawer's pin bar
/// only ever offered settings groups. A1 makes the *lamp buttons* the pins, and
/// their shipped defaults are TOOLS and CUSTOMIZE — of which TOOLS is
/// `DexRoute.minigames`, not a settings section at all. So the vocabulary had to
/// widen by exactly one entry, and the honest place for that is a type that can
/// hold both rather than a second store beside the first.
///
/// **The raw values are a strict superset of `SettingsSection`'s**, and that is
/// the migration. `QuickPinStore` persists these strings under the key it has
/// used since 0.7.2, so a stored `"DATA,ACCESS"` decodes to exactly what it
/// always did; nothing on disk moves and nobody's pins are reset. `"DEV"` was
/// never offered by the drawer's chip row and is not offered here either, so the
/// one `SettingsSection` case with no counterpart is one that could not have been
/// stored.
///
/// Everything else forwards. A pin's label, glyph and destination are the
/// section's or the route's, never restated — which is what stops a lamp button
/// wearing one glyph and landing on a screen wearing another, the rule
/// `DexRoute.marqueeSymbol`'s K2 audit wrote for the whole app.
public enum MarqueePin: String, CaseIterable, Hashable, Sendable, Identifiable {
    /// The tools shelf — `DexRoute.minigames`. The one pin that is not a
    /// settings group, and the left lamp's default since 0.7.2 (A9).
    case tools = "TOOLS"
    case customization = "CUSTOMIZE"
    case settings = "SETTINGS"
    case data = "DATA"
    case access = "ACCESS"

    public var id: String { rawValue }

    /// The settings group this pin names, or nil for TOOLS.
    public var section: SettingsSection? {
        switch self {
        case .tools: nil
        case .customization: .customization
        case .settings: .settings
        case .data: .data
        case .access: .access
        }
    }

    /// Where the lamp goes. One expression rather than a table, so a pin cannot
    /// name a destination its own glyph disagrees with.
    public var route: DexRoute {
        if let section { return .settingsSection(section) }
        return .minigames
    }

    /// The label, taken from whatever the destination already calls itself —
    /// which is how ACCESS reads as SHOP here without this file knowing about
    /// the 0.7.5 rename.
    public var displayName: String {
        section?.displayName ?? DexRoute.minigames.title
    }

    /// The glyph, from the same place. All iOS 17-safe, because they are the
    /// glyphs the settings grid and the route table already ship.
    public var symbol: String {
        section?.symbol ?? DexRoute.minigames.marqueeSymbol
    }

    /// The drawn face, from the same two places (0.8.3, H).
    ///
    /// All five resolve — `SettingsSection.artStem` is total and TOOLS has its
    /// own — so the lamps are the one marquee surface where the conversion is
    /// complete. The fallback stays wired anyway: a sixth pin would arrive
    /// through this expression, and a lamp with no glyph reads as a fault.
    public var artStem: String? {
        section?.artStem ?? DexRoute.minigames.marqueeArt
    }
}

/// What the marquee's two lamp buttons are pointed at (0.7.1 B5; rebuilt 0.7.6, A1).
///
/// **What A1 changed, and what it deliberately did not.** Through 0.7.5 the
/// device had three ways to reach the same handful of places: two lamp buttons
/// hardwired to TOOLS and CUSTOMIZE (0.7.2, A9), up to two pin buttons in the
/// marquee's top corners (0.7.2, A7), and a swipe drawer behind the panel itself
/// (0.7.1, B4/B5) whose PINNED row is where the pins were chosen. The Decision in
/// 0.7.6 collapses all three into the first: the lamps *are* the pins, always
/// visible, one tap, and each reassignable. The drawer and the corner buttons go.
///
/// What did not change is this store, its key, or the encoding. The pins were
/// already persisted here and the decoder already dropped values it did not
/// recognise; widening the vocabulary to `MarqueePin` (see above) is the whole of
/// the data change, and every raw value that could previously be on disk still
/// decodes to the same thing.
///
/// **Two differences in behaviour, both forced by the lamps being physical.**
///
/// 1. **The list is always full.** A lamp cannot be empty — it is a moulded part
///    of the shell, and a dark one reads as a fault, not as an invitation. So
///    `pins` always holds exactly `capacity` entries, and an under-filled stored
///    value is padded from `defaults` rather than left short. The drawer could
///    afford dashed EMPTY slots because it was a panel that opened; a chassis
///    cannot.
/// 2. **Assignment is by slot, not by set.** The old `toggle(_:)` was a
///    membership rule with an eviction queue, which is right for "these two
///    things are pinned" and wrong for "the *left* lamp goes here". `assign(_:to:)`
///    replaces it, and assigning a pin that the other lamp already holds swaps
///    the two rather than putting the same destination on both — a device with
///    two identical buttons is not a choice anybody made.
///
/// **Why a store and not `@AppStorage`.** Unchanged from 0.7.1: the value is an
/// ordered fixed-length list with a padding rule, a swap rule and a defaults
/// rule, and `@AppStorage` can only hold the string. Putting the rules in the
/// view means the chassis re-implements them — in a module Linux cannot compile,
/// so the first version to get one wrong ships.
@MainActor
@Observable
public final class QuickPinStore {
    public static let shared = QuickPinStore()

    /// One key holding a comma-joined list of `MarqueePin` raw values.
    ///
    /// **The spelling is 0.7.2's and stays 0.7.2's.** It says "quick pins"
    /// because it was written for the drawer's pin bar; the pins have moved to
    /// the lamps and the key has not, for the reason `DeviceAxis.storageKey`
    /// gives about `chassisSkin`: a tidier name here would silently reset the
    /// pins of everyone who had set any.
    ///
    /// `nonisolated`, with the three constants below it and `decode(_:)`,
    /// matching `CustomDeviceStore`: this type is `@MainActor` because its
    /// *state* is, and a key, a cap, a default list and a pure decoder are
    /// none of those. `ChromeTests` reads them off the main actor.
    public nonisolated static let storageKey = "marqueeQuickPins"

    /// Two, because there are two lamps. The cap and the slot count are the same
    /// number by construction now rather than by the coincidence 0.7.2's corner
    /// buttons relied on.
    public nonisolated static let capacity = 2

    /// What the lamps say on a device nobody has reassigned: TOOLS on the left,
    /// CUSTOMIZE on the right.
    ///
    /// The same pair 0.7.2's A9 hardwired, and in the same order — left to right,
    /// matching the order the retired drawer listed its two sections in. A1 adds
    /// the ability to change them; it does not change what they start as.
    public nonisolated static let defaults: [MarqueePin] = [.tools, .customization]

    /// Named `store` rather than `defaults` so it cannot be confused with the
    /// constant above it — `Self.defaults` is the factory pin pair, and a
    /// property of the same name two lines away is exactly the sort of shadowing
    /// that reads correctly and compiles into the wrong thing.
    private let store: UserDefaults
    /// Always exactly `capacity` entries, always distinct. See `decode(_:)`.
    private(set) public var pins: [MarqueePin]

    public init(defaults: UserDefaults = .standard) {
        self.store = defaults
        let raw = defaults.string(forKey: Self.storageKey) ?? ""
        self.pins = Self.decode(raw)
    }

    /// Split, resolve, drop unknowns, drop duplicates, take the first
    /// `capacity` — then **pad the rest from `defaults`**.
    ///
    /// The first four steps are 0.7.1's decoder unchanged, and they are still a
    /// defence against a value this app did not write: an older build's list, a
    /// hand-edited plist, a section removed between releases. The pad is the new
    /// half and is what makes "a lamp is never empty" true from the first read
    /// rather than at each call site.
    ///
    /// Worked through, because the migration is the interesting case:
    ///
    /// - `""` (nobody ever pinned anything) → `[TOOLS, CUSTOMIZE]`, which is the
    ///   pair the lamps were hardwired to. The overwhelming majority of installs.
    /// - `"SETTINGS"` (one pin, from the drawer) → `[SETTINGS, TOOLS]`: the pin
    ///   they chose keeps the slot it was in, and the first unused default fills
    ///   the other.
    /// - `"DATA,ACCESS"` (two pins) → `[DATA, ACCESS]`, untouched — the lamps
    ///   simply become the buttons those pins already were.
    /// - `"PACKS,DATA"` (a pin for the section 0.7.5's B1 retired) → `[DATA,
    ///   TOOLS]`, which is the same silent drop 0.7.5 already documented.
    public nonisolated static func decode(_ raw: String) -> [MarqueePin] {
        var seen: Set<MarqueePin> = []
        var out: [MarqueePin] = []
        for piece in raw.split(separator: ",") {
            guard
                let pin = MarqueePin(rawValue: String(piece)),
                !seen.contains(pin)
            else { continue }
            seen.insert(pin)
            out.append(pin)
            if out.count == capacity { break }
        }
        // Pad, skipping anything already assigned so the two lamps never carry
        // the same destination.
        for fallback in defaults where out.count < capacity {
            guard !seen.contains(fallback) else { continue }
            seen.insert(fallback)
            out.append(fallback)
        }
        // Belt and braces: `defaults` is `capacity` long, so the loop above
        // always finishes the job — unless somebody shortens it, in which case a
        // list of the wrong length would be far worse than a repeated pin.
        for fallback in MarqueePin.allCases where out.count < capacity {
            guard !seen.contains(fallback) else { continue }
            seen.insert(fallback)
            out.append(fallback)
        }
        return out
    }

    public func isPinned(_ pin: MarqueePin) -> Bool { pins.contains(pin) }

    /// What the lamp in `slot` is pointed at. Nil only for a slot that does not
    /// exist, which the chassis cannot ask for — it draws `capacity` lamps.
    public func pin(at slot: Int) -> MarqueePin? {
        pins.indices.contains(slot) ? pins[slot] : nil
    }

    /// Point a lamp somewhere.
    ///
    /// **Assigning a destination the other lamp holds swaps them**, rather than
    /// refusing or duplicating. Refusing would mean the user has to clear the
    /// other lamp first and come back; duplicating would give the device two
    /// identical buttons. A swap is what the tap plainly meant and is undone by
    /// repeating it.
    ///
    /// - Returns: whether anything moved, so a caller can pick its haptic without
    ///   re-reading.
    @discardableResult
    public func assign(_ pin: MarqueePin, to slot: Int) -> Bool {
        guard pins.indices.contains(slot), pins[slot] != pin else { return false }
        if let other = pins.firstIndex(of: pin) {
            pins[other] = pins[slot]
        }
        pins[slot] = pin
        persist()
        return true
    }

    /// Back to TOOLS and CUSTOMIZE.
    public func reset() {
        pins = Self.defaults
        persist()
    }

    /// Removes the key outright when the lamps are back at their defaults,
    /// matching `StampLayoutStore` and `DeviceBuild`: a stored value equal to the
    /// default and no stored value must not be two different states, or
    /// `SavedDataReset` has to know about both.
    private func persist() {
        if pins == Self.defaults {
            store.removeObject(forKey: Self.storageKey)
        } else {
            store.set(pins.map(\.rawValue).joined(separator: ","), forKey: Self.storageKey)
        }
    }
}
