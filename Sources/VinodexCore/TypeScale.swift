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
    ///
    /// **Widened from 1.15 to 1.30 by AUDIT M49**, which owns the *range* H11
    /// deliberately did not. It stays three steps rather than four: a fourth
    /// button splits the picker row into ~69pt columns, and a control the user
    /// has to squint at to pick a text size is its own joke. The range goes
    /// into the step that already exists instead.
    case huge = "HUGE"

    public static let storageKey = SavedDataKey.textScale.rawValue

    public var id: String { rawValue }

    /// `small` and `large` are unchanged from 0.5.x and must stay so — they are
    /// the persisted vocabulary, and moving them would resize the app under
    /// anyone who has already chosen one.
    ///
    /// **`huge` moved 1.15 → 1.30 (M49), and the old number was arithmetic
    /// rather than taste.** Four fixed frames overflowed above it, the tightest
    /// at **1.206**: `StatBar`'s 96pt label well against AROMATICS at
    /// `mono(19)` with 1.5 tracking — VT323's advance is exactly 0.4 em, read
    /// out of the shipped `.ttf`, so that label wants `9 × (7.6f + 1.5)`
    /// points. All four derive from the factor now and `TypeScaleTests` pins
    /// each one, so the ceiling that set 1.15 no longer exists.
    ///
    /// **1.30 is a judgement, and this is the honest account of it.** With the
    /// frames derived there is no computable ceiling left — what remains is
    /// whether the *tile* layouts hold, and nothing in this repo can render a
    /// tile. 1.30 keeps the app inside the range `UIScale` already ships at and
    /// stays under the tightest ceiling that existed before this pass (1.462,
    /// the search shell), so it is safe even if one of the four fixes is wrong.
    /// The system's range still reaches 3.12; this narrows the gap without
    /// pretending to close it.
    ///
    /// Moving `huge` rather than adding a fourth step does re-size the app for
    /// anyone already on it. That is deliberate and was cheap here: `huge` is
    /// three days old (0.6.4) and the build is not publicly distributed.
    public var factor: Double {
        switch self {
        case .small: 0.85
        case .large: 1.00
        case .huge: 1.30
        }
    }

    /// Read from defaults so `DexFont` can apply it without every call site
    /// threading it through. Views re-render because `RootView` keys its
    /// content on the setting — see `VinodexApp`.
    ///
    /// An injected store reads straight through; `.standard` goes via
    /// `SettingsCache` (AUDIT **L16**). This is the hottest defaults read in
    /// the app — `DexFont.resolvedSize` calls it to build every `Font` —
    /// and the `.id()` rebuild contract still holds, because the cache is
    /// dropped by `UserDefaults.didChangeNotification` on the same write that
    /// changes the key `RootView` is keyed on.
    public static func current(in defaults: UserDefaults = .standard) -> TextScale {
        TextScale(rawValue: defaults.string(forKey: storageKey) ?? "") ?? SettingsDefault.textScale
    }

    public static var current: TextScale {
        TextScale(rawValue: SettingsCache.string(forKey: storageKey) ?? "") ?? SettingsDefault.textScale
    }

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
    /// The whole accessibility band seeds `huge`, which is the top. That was
    /// already true before M49 and stays true after it — what changed is that
    /// `huge` is now worth 1.30 rather than 1.15, so the same seed hands an
    /// accessibility user meaningfully more than it used to.
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
    /// Applied *before* the factor, so it is exactly equivalent to having
    /// written `nominalFloor` at the call site. H11 raised the ten sub-10pt
    /// literals to clear it and a CI grep keeps them clear.
    public static let nominalFloor: Double = 10

    /// No label is *drawn* smaller than this, whatever the step.
    ///
    /// The second half of AUDIT **M49**, and the half H11 declined to take
    /// blind: a nominal floor alone still let the shipped default (`small`,
    /// 0.85) draw a 10pt label at 8.5pt, under Apple's 11pt guidance. 11 is
    /// that guidance.
    ///
    /// **What it costs, stated rather than buried.** At `small` every nominal
    /// from 10 to 12 now draws at 11 — three authored sizes collapse onto one,
    /// and 41 call sites at `retro(10)`/`retro(11)` grow by up to 29%. That is
    /// the trade M49 is: a ≤1.7pt distinction nobody can perceive at those
    /// sizes, exchanged for every label in the app clearing the legibility
    /// floor. Above 12 nothing changes at any step, and above `small` the floor
    /// binds on less and less — at `maximum` it binds on nothing at all.
    ///
    /// It is a *widening* change, so the risk it carries is layout rather than
    /// type, and it lands with the four fixed frames that would have clipped
    /// first already derived. The remaining check is on a device.
    public static let renderedFloor: Double = 11

    /// The rendered point size for `nominal` at `step`.
    ///
    /// Both floors apply: the nominal one first, so a call site below it reads
    /// as if it had been authored at the floor, and the rendered one last, so
    /// no step can take the result under the legibility minimum.
    public static func resolve(nominal: Double, step: TextScale) -> Double {
        max(renderedFloor, max(nominalFloor, nominal) * step.factor)
    }

    // MARK: - Measuring a run

    /// VT323's advance width, in ems. The face is monospaced, so a run's width
    /// is character count times one cell and needs no text engine to compute —
    /// which is the only reason a label well can be sized correctly from a host
    /// that cannot render a single view.
    ///
    /// Read out of the shipped `VT323-Regular.ttf` (`unitsPerEm` 1000, every
    /// non-zero advance 400), not estimated. `PressStart2P-Regular.ttf` is
    /// 1.0 em by the same measurement — the marquee already relies on it.
    public static let monoAdvanceEm: Double = 0.4
    public static let retroAdvanceEm: Double = 1.0

    /// The drawn width of a `mono(nominal)` run.
    ///
    /// `tracking` is added per character including the last, which is what
    /// SwiftUI's `.tracking(_:)` does — it is extra advance, not a gap between
    /// glyphs, so an n-character run gets n of them.
    public static func monoRunWidth(
        characters: Int,
        nominal: Double,
        tracking: Double = 0,
        step: TextScale
    ) -> Double {
        Double(characters) * (monoAdvanceEm * resolve(nominal: nominal, step: step) + tracking)
    }

    /// The drawn width of a `retro(nominal)` run — the pixel face, 1.0 em.
    public static func retroRunWidth(
        characters: Int,
        nominal: Double,
        tracking: Double = 0,
        step: TextScale
    ) -> Double {
        Double(characters) * (retroAdvanceEm * resolve(nominal: nominal, step: step) + tracking)
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
