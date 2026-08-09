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

/// How much spare room a fixed, non-scrolling page has (0.7.0, J1/J2/J3).
///
/// **The problem this exists to solve.** 0.6.7's I1 made the LCD a genuinely
/// fixed box that clips, and 0.6.9's K2 then had to make the moon dial actually
/// fit inside it. 0.7.0's J asks for all three of the fixed pages — the moon
/// dial, the daily reveal and the exam — to be *larger*. Read naively those are
/// contradictory: adding points to a page that only just fits is how a page
/// stops fitting, and inside a clipping LCD the overflow does not scroll into
/// view, it silently disappears at the bezel.
///
/// They are only contradictory if "larger" means a constant. Here it means a
/// fraction of the room the page actually has, and the room is *measured*:
///
/// - **0** means no slack. Every call site is written so that a `growth` of zero
///   resolves to exactly the numbers that shipped in 0.6.9, which makes the
///   previously-verified fit the floor case of the new arithmetic rather than a
///   separate case somebody has to re-check.
/// - **1** means plenty, on a tall phone at the SMALL text step, where those
///   pages were leaving room in a trailing `Spacer` and looking sparse for it.
///
/// **Why the height is divided by the text factor.** Points are the wrong unit.
/// What decides whether a page of words fits is height *relative to how big the
/// words are*, and `TextScale` runs to 1.15 at HUGE — so a 480pt LCD at HUGE has
/// the same room for content as a ~355pt LCD at LARGE, and this treats them as
/// equal. That is what makes the growth back off on both of the axes that
/// actually consume a page, rather than only on the obvious one.
///
/// **No floor is introduced.** Whatever minimum a page already had for its own
/// reasons stays exactly as it was; this only ever adds on top, and only where
/// there is measured room to add into.
public enum PageRoom {
    /// Below this many text units a page gets no growth at all.
    ///
    /// **340 is set from the measurement 0.6.9's K2 left behind.** That note
    /// records the moon dial's ring coming out "around 105pt on the smallest
    /// supported device" at a fraction of 0.30, which puts the shortest LCD at
    /// roughly 350pt. 340 units therefore means: at the HUGE text step — the
    /// worst case, and the one K2 says was actually breaking the fixed pages —
    /// no growth happens at all below ~391pt, comfortably past that shortest
    /// screen. The layout 0.6.9 verified is untouched in the case it was
    /// verified in.
    ///
    /// It deliberately does *not* mean "no growth on a short screen at any text
    /// step". At SMALL every glyph renders at 0.85×, so a short screen genuinely
    /// does have room, and refusing to use it would be the same mistake as
    /// adding a constant — a number chosen for a case that is not the one in
    /// front of the user. The safety property is the one that matters: growth is
    /// zero wherever the page is tightest.
    public static let floorUnits: Double = 340
    /// The window over which growth ramps from 0 to 1.
    public static let windowUnits: Double = 220

    /// `pageHeight` in points, `step` the active text scale.
    public static func growth(pageHeight: Double, step: TextScale) -> Double {
        guard pageHeight > 0 else { return 0 }
        let units = pageHeight / step.factor
        return min(max((units - floorUnits) / windowUnits, 0), 1)
    }

    /// The defaults-reading form, for views that do not thread the step.
    public static func growth(pageHeight: Double) -> Double {
        growth(pageHeight: pageHeight, step: TextScale.current)
    }
}
