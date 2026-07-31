import Foundation

// MARK: - Text scale
//
// The app's *only* text-size axis (0.6.4, AUDIT H11).
//
// Vinodex used to have two, multiplied together and never reconciled: this
// setting, and the system's Dynamic Type — which reached the app only because
// `Font.custom(_:size:)` happens to auto-scale relative to `.body`. That was
// not a decision anyone made, and it showed: every layout metric in the app is
// a fixed literal tuned to a pixel font, so an accessibility text size blew the
// tiles, marquee and chips apart, while the `.system(size:)` *fallback* taken
// when font registration fails does not auto-scale at all — meaning a failed
// CoreText registration silently changed the app's accessibility behaviour as
// well as its typeface.
//
// So the two axes are now one. `DexFont` builds every font at a fixed size,
// the root pins `dynamicTypeSize`, and this enum is what a user turns. The
// honest cost is written down in AUDIT.md under H11: this axis spans 0.85-1.15,
// where the system's spans 0.82-3.12, so Vinodex is not a Dynamic Type app and
// should not claim to be one. What it is instead is an app whose smallest label
// went from 6.8pt to 8.5pt at the default step and 11.5pt at the largest, and
// whose layout no longer comes apart at an accessibility size.
//
// This lives in Core rather than beside `DexFont` for one reason: VinodexUI is
// behind `#if canImport(SwiftUI) && canImport(UIKit)` and compiles to nothing
// on the Linux host, so nothing in it can be unit-tested. Here it runs under
// `swift test`.

/// How large the app draws its text. Applies everywhere.
///
/// Deliberately a narrow range with a hard floor and ceiling: the retro face
/// has no optical sizes, so a large jump breaks the tile layout and a small one
/// stops being legible at arm's length.
public enum TextScale: String, CaseIterable, Identifiable, Sendable {
    case small = "SMALL"
    case large = "LARGE"
    /// Added in 0.6.4. Pinning the system control without offering a way *up*
    /// would have left a low-vision user with strictly less than they had, so
    /// the axis that used to top out at as-drawn now goes past it.
    case huge = "HUGE"

    public static let storageKey = "textScale"

    public var id: String { rawValue }

    /// `small` and `large` are unchanged from 0.5.x — they are the persisted
    /// vocabulary, and moving them would resize the app under existing users.
    ///
    /// 1.15 is deliberately modest, and matches the ceiling `UIScale` already
    /// proved the chassis survives. It is also far below where this app used to
    /// go: `Font.custom` at an accessibility size reached ~3.1x, which is the
    /// blow-out H11 describes. Going past 1.15 needs the three fixed frames
    /// named in the audit re-tuned first.
    public var factor: Double {
        switch self {
        case .small: 0.85
        case .large: 1.00
        case .huge: 1.15
        }
    }

    /// Read straight from defaults so `DexFont` can apply it without every call
    /// site threading it through. Views re-render because `RootView` keys its
    /// content on the setting — see `VinodexApp`.
    ///
    /// Not cached: the `.id()` rebuild contract depends on a fresh read.
    public static func current(in defaults: UserDefaults = .standard) -> TextScale {
        TextScale(rawValue: defaults.string(forKey: storageKey) ?? "") ?? .small
    }

    public static var current: TextScale { current(in: .standard) }

    /// First-launch courtesy for someone who had already enlarged their system
    /// text: writes a matching step *once*, if they have never opened TEXT SIZE.
    ///
    /// A permanent `max(stored, system)` was the other option and is worse — it
    /// makes the settings picker lie, because the panel highlights the stored
    /// value while the app renders the larger one. Seeding writes the stored
    /// value itself, so what the picker shows is always what the app does, and
    /// the user owns the setting from then on.
    ///
    /// `ordinal` is an index into `DynamicTypeSize.allCases`: 0 xSmall … 3 large
    /// (the iOS default) … 6 xxxLarge, 7+ accessibility1…5.
    ///
    /// - Returns: the step written, or `nil` if the user already has one.
    @discardableResult
    public static func seedIfUnset(systemOrdinal ordinal: Int, in defaults: UserDefaults = .standard) -> TextScale? {
        guard defaults.string(forKey: storageKey) == nil else { return nil }
        let seeded: TextScale = ordinal >= 7 ? .huge : (ordinal >= 4 ? .large : .small)
        defaults.set(seeded.rawValue, forKey: storageKey)
        return seeded
    }
}

// MARK: - Resolver

/// Turns a call site's nominal size into the point size that gets drawn.
///
/// One function, so the floor cannot be applied in some places and forgotten in
/// others — which is how the app ended up with ten labels under 10pt across six
/// screens while nobody was looking.
public enum TypeScale {
    /// No label is authored smaller than this.
    ///
    /// A *nominal* floor, not a rendered one, and the distinction is the honest
    /// part: at the `small` step (0.85, the shipped default) a 10pt nominal
    /// renders at 8.5pt, which is still under Apple's 11pt guidance. A true
    /// rendered floor would clamp everything up to `retro(12)` and silently
    /// re-size 41 further call sites whose layouts nothing in this project can
    /// check — VinodexUI compiles to nothing off-device. So the floor is set
    /// where it is provably a no-op for every call site that already clears it,
    /// and the remaining gap is tracked in AUDIT.md rather than closed blind.
    public static let nominalFloor: Double = 10

    /// The rendered point size for `nominal` at `step`.
    ///
    /// The floor is applied *before* the factor, so this is exactly equivalent
    /// to having written `nominalFloor` at the call site. Every existing site at
    /// or above the floor is therefore untouched at every step — the guarantee
    /// that makes this change reviewable without a device.
    public static func resolve(nominal: Double, step: TextScale) -> Double {
        max(nominalFloor, nominal) * step.factor
    }
}
