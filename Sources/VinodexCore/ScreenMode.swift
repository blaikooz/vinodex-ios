import Foundation

// MARK: - The two screen axes
//
// `UIScale` (how large the chassis furniture draws) and `LcdMode` (what the
// screen is made of). Moved here from VinodexUI by arch **A6**, which is the
// same edit **H11** already made for `TextScale` and for the same reason:
// VinodexUI sits behind
// `#if canImport(SwiftUI) && canImport(UIKit)` and compiles to nothing on the
// Linux host, so nothing in it can be unit-tested — and a *persisted
// vocabulary* is exactly the kind of thing that wants a test. Every raw value
// below is written into `UserDefaults` on a real device; renaming one silently
// resets that user's choice.
//
// **Only the persisted half moved.** Each type kept every SwiftUI member it
// had — `screen`, `text`, `accent`, `controlAccent` and the rest are still
// declared in `Sources/VinodexUI/Theme/ScreenModes.swift`, now as an
// extension. That is the split A6 proposed and H11 proved out: the arithmetic and the
// vocabulary come to Core, the colours stay where `Color` exists.

/// Chrome scale (v0.5.8, F1) — a second axis, independent of `TextScale`.
///
/// Scales the *furniture*: footer controls, marquee band, vents, icon wells.
/// Text keeps its own setting, so a user can have big controls with small
/// type, or the reverse. SMALL is exactly the pre-0.5.8 layout.
///
/// Applied inside `DexMetrics`' computed members rather than at call sites,
/// for the same reason `TextScale` lives inside `DexFont`: the call site that
/// threads a factor through by hand is the one that forgets to.
public enum UIScale: String, CaseIterable, Identifiable, Sendable {
    case small = "SMALL"
    case large = "LARGE"

    public static let storageKey = SavedDataKey.uiScale.rawValue

    public var id: String { rawValue }

    /// 1.15 is as far as the chassis stretches before the footer trio starts
    /// squeezing the marquee on a compact-width phone.
    ///
    /// `Double`, not `CGFloat`, following `TextScale.factor` — Core is
    /// deliberately Foundation-only and the six `DexMetrics` members that use
    /// this convert at the point of use.
    public var factor: Double {
        switch self {
        case .small: 1.0
        case .large: 1.15
        }
    }

    /// Mirrors `TextScale.current` — defaults-read through `SettingsCache`
    /// (AUDIT **L16**), rebuild forced by `RootView` keying on the raw value.
    public static var current: UIScale {
        UIScale(rawValue: SettingsCache.string(forKey: storageKey) ?? "")
            ?? SettingsDefault.uiScale
    }

    /// The injected-store form, for `AppSettings` and for tests. Reads
    /// straight through rather than via `SettingsCache`, which only ever
    /// caches `.standard` — see the note there.
    public static func current(in defaults: UserDefaults) -> UIScale {
        UIScale(rawValue: defaults.string(forKey: storageKey) ?? "")
            ?? SettingsDefault.uiScale
    }
}

/// Whether the LCD renders dark-on-black or the original handheld's dark-on-
/// light-grey. Independent of `ChassisSkin`: the shell and the screen are
/// separate choices, and pairing a light screen with the red shell is a
/// perfectly good combination.
public enum LcdMode: String, CaseIterable, Identifiable, Sendable {
    case dark = "DARK"
    case light = "LIGHT"
    /// Monochrome — black pixels on a grey-green ground, like a vintage Palm
    /// or e-ink screen. Colour is deliberately lost: the chassis applies a
    /// grayscale-and-tint pass over the whole LCD (see `DeviceChassis`), so
    /// the tokens in the UI extension only have to be high-contrast, not
    /// tastefully hued.
    case vintage = "VINTAGE"
    /// Monochrome the other way up — amber phosphor on black, like a CRT
    /// terminal. Same grayscale-and-tint pass as vintage, over the dark
    /// theme's tokens instead of the light ones.
    case amber = "AMBER"
    /// Early-desktop GUI: a grey-blue desktop with navy ink and titlebar
    /// blues. A *light* mode — the pale branch everywhere light takes it.
    case wineOS = "WINE OS"
    /// Green phosphor on black — the amber treatment with the other classic
    /// tube. Same grayscale-and-tint pass, over the dark tokens.
    case terminal = "TERMINAL"
    /// VINOFD: deep blue CRT ground with a light-blue vacuum-fluorescent
    /// glow for the text. Shipped in 0.5.1 as "Blue Screen" (white text) —
    /// the rawValue keeps that name because it is persisted; the label and
    /// the glow are what changed.
    case blueScreen = "BLUE SCREEN"
    /// A vintage starship console: black glass, amber readouts, and purple
    /// for the accents — the two colours those panels actually ran.
    case starTrek = "STAR TREK"
    /// DMG dot-matrix: dark ink on pea green, four tones total. Runs the
    /// vintage/amber grayscale-and-tint pass with the DMG's own green, so
    /// only the tokens' *luminance* matters — that is what collapses the
    /// whole LCD to the handheld's palette. The rawValue is ASCII on
    /// purpose (it persists); the umlaut lives in `displayName`.
    case gruenerBoy = "GRUNER BOY"

    public static let storageKey = SavedDataKey.lcdMode.rawValue

    public var id: String { rawValue }

    /// What the picker calls this mode. Separate from `rawValue` for the
    /// same reason `ChassisSkin.displayName` is: the raw value is persisted,
    /// so a rename must move the label and only the label. BLUE SCREEN
    /// shipped in 0.5.1 and re-brands as VINOFD without resetting anyone's
    /// stored choice.
    public var displayName: String {
        switch self {
        case .blueScreen: "VINOFD"
        case .gruenerBoy: "GRÜNERBOY"
        // Capitalized like the rest of the roster since 0.5.8 (E1); the dot
        // keeps the file-name conceit.
        case .wineOS: "WINE.OS"
        case .starTrek: "L-WINES"
        default: rawValue
        }
    }

    /// Whether the screen ground is pale. An explicit list, not `!= .dark`:
    /// vintage is dark ink on a pale ground and wants every light branch, but
    /// amber is a *dark* mode — pale scrims and dark-on-accent ink on it would
    /// be wrong in both directions. WINE OS joins the pale side; the other
    /// themed modes are dark glass.
    public var isLight: Bool {
        self == .light || self == .vintage || self == .wineOS || self == .gruenerBoy
    }

    /// Glyph for the screen-mode picker's preview cards.
    public var symbol: String {
        switch self {
        case .dark: "moon.fill"
        case .light: "sun.max.fill"
        case .vintage: "hourglass"
        case .amber: "lightbulb.fill"
        case .wineOS: "macwindow"
        case .terminal: "terminal.fill"
        case .blueScreen: "pc"
        case .starTrek: "atom"
        case .gruenerBoy: "gamecontroller.fill"
        }
    }

    /// LIGHT mode's globe is the *inverted-colour* globe (0.6.4, F1): the map
    /// texture runs through a colour inversion before it reaches the sphere,
    /// so dark oceans become paper and the globe reads as printed rather than
    /// glowing. Only LIGHT — the other pale modes keep the normal texture
    /// under their own tints.
    public var invertsGlobeTexture: Bool { self == .light }

    /// Via `SettingsCache` — see the note there (AUDIT **L16**).
    public static var current: LcdMode {
        LcdMode(rawValue: SettingsCache.string(forKey: storageKey) ?? "")
            ?? SettingsDefault.lcdMode
    }

    /// The injected-store form — see `UIScale.current(in:)`.
    public static func current(in defaults: UserDefaults) -> LcdMode {
        LcdMode(rawValue: defaults.string(forKey: storageKey) ?? "")
            ?? SettingsDefault.lcdMode
    }
}
