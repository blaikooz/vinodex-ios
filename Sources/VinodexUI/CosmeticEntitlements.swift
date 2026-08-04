#if canImport(SwiftUI) && canImport(UIKit)
import VinodexCore

/// Which bundle each cosmetic needs (0.7.3, F1).
///
/// **This is the rule that had forked.** Skins and screen modes were always
/// stored in the one entitlement set — there was never a second store to unify
/// — but the *rule* was copy-pasted into four view bodies, twice in the settings
/// pickers and twice in the marquee drawer:
///
/// ```swift
/// let locked = option != .classic && !access.isUnlocked(.skins)
/// let locked = option != .dark    && !access.isUnlocked(.lightMode)
/// ```
///
/// Four places encoding which option is free and which bundle covers the rest,
/// none of them reachable from a test, in a module Linux cannot compile. A fifth
/// picker would have made it five, and the first one written slightly wrong
/// would have quietly given away a bundle.
///
/// It lives in this file rather than beside the enums in `DexTheme.swift`
/// because `DexTheme.swift` is a hundred and sixty thousand characters of colour
/// tables, and a two-line ownership rule buried at line 2000 of it is
/// discoverable by nobody. Both conformances together is four lines and the
/// whole policy.
extension ChassisSkin: CosmeticOption {
    /// CLASSIC is the shell the device ships in; every other colourway rides the
    /// one bundle. There is deliberately no per-skin entitlement — twenty-one
    /// products for twenty-one shells is a storefront nobody would read.
    public var requiredEntitlement: Entitlement? {
        self == .classic ? nil : .skins
    }
}

extension LcdMode: CosmeticOption {
    /// DARK is the default display; the other eight ride `.lightMode` — whose id
    /// is a fossil of when the only alternate was the paper-white one, and which
    /// cannot be renamed because it is persisted. See `Entitlement.title`, where
    /// only the shopfront copy widened.
    public var requiredEntitlement: Entitlement? {
        self == .dark ? nil : .lightMode
    }
}
#endif
