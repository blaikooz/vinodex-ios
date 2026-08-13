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
//
// `LcdModeSection` (0.7.0, B1) lands on the same side of that line and for the
// same reason: a picker heading is a raw string and a *rule* about
// `LcdMode.allCases`, with no `Color` in it anywhere. So is `section`, so is
// `themesChrome`. What reads them — the grouped picker, the cartridge join in
// `Sources/VinodexUI/ExpansionPackMembers.swift`, `chrome(face:shadow:)` — is
// still UI, which is exactly the arrangement A6 asks for.

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

/// A heading in the screen-mode picker (0.7.0, B1).
///
/// Nine modes in one undifferentiated three-column grid was a wall of tiles
/// with no argument in it — the picker showed the range without saying what the
/// range *was*. These three headings are the three things a mode can be: the
/// app's own themes, a period display technology, and an homage to a specific
/// machine.
///
/// `allCases` order is picker order. Membership is *not* declared here — see
/// `LcdMode.section` for why the arrow points that way.
///
/// Declared in Core, not beside the picker: nothing on it resolves to a
/// `Color`, and `modes` is a partition rule over `LcdMode.allCases` — the exact
/// kind of claim arch **A6** moved this file for so that it can be asserted from
/// `swift test`. The cartridge each section is sold as is a separate join and
/// stays in `Sources/VinodexUI/ExpansionPackMembers.swift`.
public enum LcdModeSection: String, CaseIterable, Identifiable, Sendable {
    /// The house themes: no conceit beyond light and dark.
    case classic = "CLASSIC"
    /// Period display hardware — phosphor and reflective LCD, monochrome by
    /// construction rather than by palette.
    ///
    /// **VINTAGE → RETRO (0.7.1, C1.)** The heading and the mode `LcdMode.vintage`
    /// both read "VINTAGE", so the picker printed a group called VINTAGE with a
    /// tile called VINTAGE inside it and two other tiles that were not — the
    /// heading looked like a mislabelled tile. RETRO names the same idea without
    /// colliding with any mode, and the case is renamed with it because *no
    /// section is persisted anywhere*: the mode rawValues are the storage, and
    /// they do not move.
    case retro = "RETRO"
    /// Modes that quote one specific machine's screen.
    case emulator = "EMULATOR"

    public var id: String { rawValue }

    /// The modes under this heading, in `LcdMode.allCases` order.
    ///
    /// Derived rather than declared, so every mode appears exactly once across
    /// the whole picker by construction: this is a partition of `allCases`, not
    /// three hand-kept lists that have to agree with it.
    public var modes: [LcdMode] { LcdMode.allCases.filter { $0.section == self } }
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
    /// purpose (it persists); shipped labelled GRÜNERBOY, relabelled
    /// GROOVEE in 0.9.2 — see `displayName`.
    case gruenerBoy = "GRUNER BOY"

    /// Derived, not restated — the literal is `"lcdMode"` and it is written
    /// down once, in `SavedDataKey` (AUDIT **M35**), because that registry is
    /// what `SavedDataArchiver` switches over to build an export.
    ///
    /// 0.7.3's B1 makes the same argument from the other end and points at
    /// `DeviceAxis.screen.storageKey`: the shell and the screen hold real
    /// choices on real installs, so a tidier spelling anywhere would reset every
    /// device in the field back to a black CLASSIC. Both registries need the key
    /// for their own reason — M35 to *enumerate* it, `DeviceBuild` to read and
    /// write it beside nine others — and `AppSettingsTests` and
    /// `DeviceWorkshopTests` each pin their side to the same string, so the two
    /// cannot drift apart in silence. `ChassisSkin.storageKey` resolves the same
    /// way for the same pair of reasons.
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
        // GRÜNERBOY → GROOVEE (0.9.2, item 1). Label only, per the note above
        // — the rawValue "GRUNER BOY" is the persisted choice and stays. The
        // old label grafted a grape onto a handheld's name; GROOVEE is
        // nobody's, keeps the retro register, and drops the umlaut this
        // label existed to carry.
        case .gruenerBoy: "GROOVEE"
        // Capitalized like the rest of the roster since 0.5.8 (E1); the dot
        // keeps the file-name conceit.
        case .wineOS: "WINE.OS"
        case .starTrek: "L-WINES"
        default: rawValue
        }
    }

    /// Which heading this mode sits under in the picker (0.7.0, B1).
    ///
    /// An exhaustive switch rather than a table on `LcdModeSection`, and that is
    /// the whole safety argument: a section list written as
    /// `[.dark, .light, .wineOS]` somewhere can silently *omit* a mode, and the
    /// omitted one simply stops appearing in the picker with nothing failing.
    /// Written this way round the compiler will not build a mode that has no
    /// home, and `LcdModeSection.modes` derives from `allCases`, so a mode
    /// cannot be listed twice either.
    ///
    /// **Two modes swapped groups in 0.7.1 (C2, C3).** WINE.OS was filed under
    /// CLASSIC because it is a *light* mode and the light modes lived together;
    /// but it is an homage to one specific desktop, which is the whole
    /// definition of EMULATOR, and it left CLASSIC as what that heading always
    /// meant — light and dark, and nothing else. GROOVEE (then GRÜNERBOY) went
    /// the other way:
    /// it is a reflective dot-matrix LCD running the same grayscale-and-tint
    /// pass as VINTAGE, AMBER and TERMINAL, so it belongs with the period
    /// display *hardware* rather than with the machines that merely quote a
    /// colour scheme. Membership is derived from this switch, so both moves are
    /// one line each and the picker follows.
    public var section: LcdModeSection {
        switch self {
        case .dark, .light: .classic
        case .amber, .vintage, .terminal, .gruenerBoy: .retro
        case .starTrek, .blueScreen, .wineOS: .emulator
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

    // `isSketchPaper` retired with the NOTEBOOK mode itself (0.7.0, C1).
    //
    // 0.6.9's M1 shipped the hand-drawn look as two independent halves — a
    // shell (`ChassisSkin.sketch`, still here, still PÉT-NAT's) and a screen
    // (this flag, plus `SketchRender.RuledPaper`). C1 removes the screen
    // mode and B2 keeps the shell, which is the two halves being independent
    // working exactly as designed: PÉT-NAT is now a drawn shell around an
    // ordinary gridded LCD, the same way it was always allowed to be a drawn
    // shell around AMBER.
    //
    // `RuledPaper` is deliberately left in `SketchRender.swift` rather than
    // deleted with its only call site: it is a finished drawing with no
    // owner, and the decision it is waiting on (whether the paper should
    // follow the *skin* instead of a mode) is the user's, not this batch's.
    // Re-mounting it is one `if` in `DexScreenBackground`.

    // `next` retired in 0.7.6 (A1), with `ChassisSkin.next` and
    // `ChassisLook.next` beside it. All three existed for one caller: the
    // marquee drawer's NEXT SCREEN and NEXT SKIN tiles (0.7.1, B5), which cycled
    // the two axes without leaving the screen you were on. The Decision retires
    // the drawer, and a cycle-to-the-next helper that nothing cycles is exactly
    // the code-nothing-reaches `MarqueeBanner`'s own D1 note argues against
    // keeping. Both pickers still choose either axis directly.

    // MARK: Themed chrome (0.7.1, C5)

    /// Whether this mode repaints the LCD's coloured controls in its own
    /// palette.
    ///
    /// True for the EMULATOR group only, and the group is the argument. CLASSIC
    /// is the app being itself — DARK and LIGHT are supposed to show the house
    /// colours, and a green BLIND TASTING tile beside a purple WINE EXAM tile is
    /// the design, not a leak. RETRO already has a stronger mechanism: those
    /// four modes run the chassis's grayscale-and-tint pass over the entire LCD
    /// (`DeviceChassis`), so their tiles are *already* one palette and tinting
    /// the source colours first would only change which greys came out.
    ///
    /// That leaves EMULATOR, where every mode quotes a specific machine in full
    /// colour and nothing was making the chrome agree with it. L-WINES is a
    /// black-glass console with amber readouts that had six saturated Tailwind
    /// tiles bolted to it.
    ///
    /// The blend itself is `chrome(face:shadow:)` in
    /// `Sources/VinodexUI/Theme/ScreenModes.swift` — it returns `Color`, so it
    /// cannot live here. This is the *rule* it consults, which can.
    public var themesChrome: Bool { section == .emulator }

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
