#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import CoreText
import VinodexCore

// MARK: - LcdMode

// The screen modes -- what the LCD looks like, per mode.

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

    public static let storageKey = "uiScale"

    public var id: String { rawValue }

    /// 1.15 is as far as the chassis stretches before the footer trio starts
    /// squeezing the marquee on a compact-width phone.
    public var factor: CGFloat {
        switch self {
        case .small: 1.0
        case .large: 1.15
        }
    }

    /// Mirrors `TextScale.current` — defaults-read, rebuild forced by
    /// `RootView` keying on the raw value.
    public static var current: UIScale {
        UIScale(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .small
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
/// The flat half of an LCD mode's look, grouped by mode (S3, phase 3).
///
/// One row per mode instead of one `switch` per property. See
/// `LcdMode.palette` for what is deliberately not here.
public struct LcdModePalette: Sendable {
    public let section: LcdModeSection
    public let symbol: String
    public let monochromeTint: Color?
    public let screen: Color
    public let accent: Color
    public let heroWash: Color
    public let heroGrid: Color
    public let buttonWell: Color
    public let page: Color
    public let surface: Color
    public let surfaceEdge: Color
    public let well: Color
    public let disabledText: Color
    public let onAccent: Color
    public let gridLine: Color
    public let controlAccent: ChassisAccent
    public let globeTint: Color?
}

public enum LcdMode: String, CaseIterable, Identifiable, Sendable {
    case dark = "DARK"
    case light = "LIGHT"
    /// Monochrome — black pixels on a grey-green ground, like a vintage Palm
    /// or e-ink screen. Colour is deliberately lost: the chassis applies a
    /// grayscale-and-tint pass over the whole LCD (see `DeviceChassis`), so
    /// the tokens below only have to be high-contrast, not tastefully hued.
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

    /// Read from `DeviceAxis` since 0.7.3 (B1) — see `ChassisSkin.storageKey`
    /// for why. The literal is unchanged: `"lcdMode"`.
    public static var storageKey: String { DeviceAxis.screen.storageKey }

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
    /// meant — light and dark, and nothing else. GRÜNERBOY went the other way:
    /// it is a reflective dot-matrix LCD running the same grayscale-and-tint
    /// pass as VINTAGE, AMBER and TERMINAL, so it belongs with the period
    /// display *hardware* rather than with the machines that merely quote a
    /// colour scheme. Membership is derived from this switch, so both moves are
    /// one line each and the picker follows.
    public var section: LcdModeSection { palette.section }

    /// Whether the screen ground is pale. An explicit list, not `!= .dark`:
    /// vintage is dark ink on a pale ground and wants every light branch, but
    /// amber is a *dark* mode — pale scrims and dark-on-accent ink on it would
    /// be wrong in both directions. WINE OS joins the pale side; the other
    /// themed modes are dark glass.
    public var isLight: Bool {
        self == .light || self == .vintage || self == .wineOS
            || self == .gruenerBoy
    }

    /// The tint the chassis multiplies the grayscaled LCD by — nil renders in
    /// colour. This is what turns "black on white" into "black on grey-green"
    /// (vintage) and "white on black" into "amber on black" (amber) or
    /// terminal green (terminal).
    public var monochromeTint: Color? { palette.monochromeTint }

    /// Glyph for the screen-mode picker's preview cards.
    public var symbol: String { palette.symbol }

    /// LCD ground.
    public var screen: Color { palette.screen }

    // MARK: The font axis (0.7.3, B1)

    /// Whether a chosen font colour survives this mode.
    ///
    /// **It cannot on the four monochrome modes.** VINTAGE, AMBER, TERMINAL and
    /// GRÜNERBOY are not colour schemes — they are a `grayscale(1)` and a
    /// `colorMultiply(tint)` over the whole LCD (see `DeviceChassis.innerBezel`),
    /// which is exactly what collapses their tokens to one phosphor. A chosen ink
    /// pushed through that pass arrives as a *lightness* change of the mode's own
    /// tint: pick COBALT on AMBER and you get slightly darker amber. Rather than
    /// ship a control that silently does almost nothing, the axis declares itself
    /// inapplicable and the workshop's FONT row says so on its face.
    ///
    /// Derived from `monochromeTint` rather than listed, so a tenth mode arriving
    /// with a tint is covered by having a tint, not by being remembered here.
    public var honorsFontInk: Bool { monochromeTint == nil }

    /// Whether this mode will actually draw in a chosen ink.
    ///
    /// Two reasons it will not, and they are different in kind: the mode may
    /// collapse every hue to one phosphor (`honorsFontInk`), or the ink may be
    /// the wrong side of this mode's ground to read as text at all
    /// (`PartColor.readsAsInk(onLightGround:)`). Both answer here, because a
    /// caller only ever wants the one question — *will this show up* — and the
    /// second reason has a property the first does not: it can become true after
    /// the fact, when somebody picks an ink on a dark screen and then changes to
    /// a pale one. A filter in the picker could not have caught that; refusing at
    /// the point of use can, and does.
    public func accepts(_ ink: PartColor) -> Bool {
        honorsFontInk && ink.readsAsInk(onLightGround: isLight)
    }

    /// The player's chosen text ink, or nil to use this mode's own.
    ///
    /// Read straight from defaults rather than through `@AppStorage`, because
    /// this is consulted from a computed property on an enum that thirty screens
    /// hold as a value — there is nowhere to put a property wrapper. That has one
    /// consequence worth stating: a change here does not invalidate any SwiftUI
    /// view on its own, which is why `RootView` keys the whole chassis on this
    /// axis. See the note there.
    ///
    /// A defaults lookup per token read is the established cost in this file —
    /// `DexFont.retro` reads `TextScale.current` the same way on every call, and
    /// AUDIT M8 resolved that in the one hot spot rather than in general. The
    /// fast path here is a single `string(forKey:)` returning nil, which is what
    /// every device that has not opened the workshop takes.
    private var fontInk: Color? {
        guard
            let raw = UserDefaults.standard.string(forKey: DeviceAxis.font.storageKey),
            let part = PartColor(rawValue: raw),
            accepts(part)
        else { return nil }
        return part.color
    }

    /// Primary text on that ground. VINOFD's is deliberately *not* white:
    /// the light-blue glow is what says vacuum-fluorescent rather than BSOD.
    ///
    /// **Three tokens, one choice** (0.7.3, B1). A mode declares a primary ink, a
    /// body ink and a muted one; a chosen font colour replaces all three, as the
    /// same colour at three weights. Overriding only `text` would leave every
    /// INFO block and every caption in the previous mode's colour, which reads as
    /// a half-applied theme rather than as a font choice — and letting the player
    /// choose three inks separately is three axes, not the one the spec asks for.
    public var text: Color {
        fontInk ?? modeText
    }

    /// This mode's own ink, with any chosen font colour ignored (0.7.3, B1).
    ///
    /// The workshop's FOLLOW swatch has to show what *unsetting* the font axis
    /// would give, and `text` cannot answer that because `text` is the axis —
    /// asking it while a colour is chosen returns the chosen colour, so the
    /// "leave this to the screen" chip would preview the thing it undoes.
    public var ownInk: Color { modeText }

    private var modeText: Color {
        switch self {
        case .dark, .amber, .terminal: .white
        case .light: Color(dexHex: "#1F1F1C")
        case .vintage: Color(dexHex: "#101010")
        case .wineOS: Color(dexHex: "#0E2258")
        case .blueScreen: Color(dexHex: "#A6DBFF")
        case .starTrek: Color(dexHex: "#FFA94D")
        case .gruenerBoy: Color(dexHex: "#141A0C")
        }
    }

    /// Section rules, headers and glyph tints. The dark theme's #4ADE80 is
    /// invisible on white, so light mode drops to a deep bottle green that
    /// still reads as "the green" without disappearing. Vintage has no colour
    /// to keep — its accent is simply ink. The themed modes each pick the one
    /// colour their reference hardware used for emphasis.
    public var accent: Color { palette.accent }

    /// Body copy inside INFO blocks — mint on black, near-black on paper.
    ///
    /// 0.86 of the chosen ink when the font axis is set: body copy sits one
    /// register below a heading in every mode's own table (`#bbf7d0` under white
    /// on DARK), and an opacity step is the only way to reproduce that from a
    /// single colour without a second authored value per palette entry.
    public var bodyText: Color {
        if let fontInk { return fontInk.opacity(0.86) }
        return modeBodyText
    }

    private var modeBodyText: Color {
        switch self {
        case .dark, .amber, .terminal: Color(dexHex: "#bbf7d0")
        case .light: Color(dexHex: "#23342A")
        case .vintage: Color(dexHex: "#20201C")
        case .wineOS: Color(dexHex: "#22335E")
        case .blueScreen: Color(dexHex: "#BFE4FF")
        case .starTrek: Color(dexHex: "#F2CD9A")
        case .gruenerBoy: Color(dexHex: "#202817")
        }
    }

    /// Hero panel wash behind an entry title.
    public var heroWash: Color { palette.heroWash }

    /// Grid lines drawn over the hero wash. Dark mode's deep #14532d reads heavy
    /// on the light hero, so light mode lifts it toward the paper.
    public var heroGrid: Color { palette.heroGrid }

    /// Filled-button ground (SAVE and friends) when *not* active.
    public var buttonWell: Color { palette.buttonWell }

    /// Ground behind entry screens, which paint their own black rather than
    /// using `DexScreenBackground`.
    public var page: Color { palette.page }

    /// Row and card fill.
    public var surface: Color { palette.surface }

    public var surfaceEdge: Color { palette.surfaceEdge }

    /// Secondary text — captions, counts, placeholders.
    public var subtext: Color {
        if let fontInk { return fontInk.opacity(0.62) }
        return modeSubtext
    }

    private var modeSubtext: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone400
        case .light: Color(dexHex: "#5A5A54")
        case .vintage: Color(dexHex: "#42423C")
        case .wineOS: Color(dexHex: "#465578")
        case .blueScreen: Color(dexHex: "#8FB0F0")
        case .starTrek: Color(dexHex: "#C2915C")
        case .gruenerBoy: Color(dexHex: "#455030")
        }
    }

    /// Fill behind search fields, which are black wells on the dark theme.
    public var well: Color { palette.well }

    /// Text on a row that exists but cannot be opened — a cross-link pointing
    /// outside the current selection, or a country with no region written yet.
    ///
    /// Has to read as *inactive* without disappearing, which is why light mode
    /// does not simply share the dark theme's stone600: against `surface` that
    /// grey is close enough to `text` to look like an ordinary enabled row.
    public var disabledText: Color { palette.disabledText }

    /// Foreground for content sitting on an `accent` fill (selected settings
    /// options, active chips). Dark mode's accent is mint (#4ADE80) — white text
    /// on it is ~1.8:1 — so it takes black; light mode's accent is deep green and
    /// takes white, as does vintage's ink-black. Blue Screen's accent is a pale
    /// cyan, so it takes the deep well blue rather than plain black.
    public var onAccent: Color { palette.onAccent }

    /// The LCD's raw ground, behind every screen. The three stone-dark modes
    /// keep the near-black CRT well; every themed mode grounds in its own
    /// colour instead. `DexScreenBackground` reads this rather than branching
    /// on `isLight`, which painted BLUE SCREEN's blue over with stone.
    public var ground: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone950
        default: screen
        }
    }

    /// The faint atmosphere grid drawn over `ground`.
    public var gridLine: Color { palette.gridLine }

    /// Ground for full-screen panels (settings and friends), which used to
    /// paint `Dex.screen` on dark and `page` on light. One token so the
    /// themed modes get their own colour in both directions.
    public var panelGround: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.screen
        default: page
        }
    }

    // MARK: Chrome
    //
    // On-LCD chrome only (narrowed in v0.5.4): the master-search button and
    // the settings tiles follow the screen mode, because they are pixels on
    // the screen. The physical chassis controls — Back, Home, Saved, the cog
    // — belong to the skin again; 0.5.3 briefly tied them to the mode, and
    // every colourway read as the same device the moment the LCD changed.
    // These ramps sit outside the LCD's grayscale-and-tint pass, so the
    // monochrome modes spell their colours out literally.

    /// The on-LCD powered chrome's six-stop ramp — the search button, the
    /// settings tiles. Same vocabulary as `ChassisAccent` for the same
    /// reason: the stops are only ever used together.
    public var controlAccent: ChassisAccent { palette.controlAccent }

    /// The globe screen's sphere tint per *screen mode* (0.6.4, F1 — the redo).
    ///
    /// 0.6.2's F1 keyed the tint on `ChassisSkin`, but the modes the user
    /// switches between on the LCD are `LcdMode`s — so flipping L-WINES or
    /// VINOFD on left the globe unchanged, which is why the feature read as
    /// not having gone through. The mode now owns the colour; DARK alone
    /// returns nil and defers to the skin's tint, keeping the per-skin
    /// behaviour as the default mode's flavour rather than losing it.
    ///
    /// Pale on purpose, like the skin table: the tint multiplies over the map
    /// texture, and a saturated dark would swallow the coastlines. The
    /// monochrome modes still pass through the chassis grayscale-and-tint, so
    /// their values only need the right luminance.
    public var globeTint: Color? { palette.globeTint }

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

    public static var current: LcdMode {
        LcdMode(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .dark
    }

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
    public var themesChrome: Bool { section == .emulator }

    /// A coloured control's face and shadow under this screen mode (0.7.1, C5).
    ///
    /// Call sites keep passing the hand-picked hex pair they always passed;
    /// under an Emulator mode this folds it toward that mode's own ramp and
    /// hands back the result. **The blend, not a replacement**, and that is the
    /// legibility half of C5: replacing the literals would make all six tools
    /// tiles the same colour and destroy the only thing telling them apart at a
    /// glance, so the original hue survives at 40% and the mode's `bright`
    /// supplies the other 60%. Six distinguishable tiles that are recognisably
    /// one machine's palette, rather than six identical ones or six that ignore
    /// the machine.
    ///
    /// Contrast is not left to the blend. The ink a caller draws on top is
    /// `chromeInk(over:)`, which picks black or white by the *blended* face's
    /// luminance rather than by the literal that went in — the two can land on
    /// opposite sides of the line, which is exactly how a themed control ends up
    /// with unreadable text.
    ///
    /// Non-Emulator modes get `Color(dexHex:)` on the untouched strings, so this
    /// is a no-op everywhere it should be one.
    public func chrome(face: String, shadow: String) -> (face: Color, shadow: Color) {
        guard themesChrome else {
            return (Color(dexHex: face), Color(dexHex: shadow))
        }
        let ramp = controlAccent
        return (
            DexRGB(hex: face).mixed(with: ramp.brightRGB, amount: 0.6).color,
            DexRGB(hex: shadow).mixed(with: ramp.edgeRGB, amount: 0.6).color
        )
    }

    /// The ink to draw over a face this mode produced.
    ///
    /// Callers pass the *literal* they would have used, and the face string they
    /// gave `chrome(face:shadow:)`; on a non-Emulator mode the preference is
    /// honoured untouched, because the existing tiles were hand-checked (the
    /// tools shelf's note on why the yellow and cyan faces deepened a step to
    /// keep white on them is exactly that work, and it should not be redone by a
    /// formula). On an Emulator mode the face has moved, so the preference is
    /// re-derived from where it moved to.
    public func chromeInk(over face: String, preferring preferred: Color) -> Color {
        guard themesChrome else { return preferred }
        let blended = DexRGB(hex: face).mixed(with: controlAccent.brightRGB, amount: 0.6)
        // 0.55 rather than 0.5: white-on-mid reads worse than black-on-mid at
        // the 13pt retro face these labels use, so the tie goes to dark ink.
        return blended.luminance > 0.55 ? controlAccent.ink : .white
    }

    /// Every flat value this mode owns, in one place.
    ///
    /// **This replaced seventeen parallel `switch self` statements**, the same
    /// transposition `ChassisSkin.palette` undid: each column a function, each
    /// row repeated nine times, and adding a mode meant seventeen edits with
    /// nothing to catch a miss. A `switch` rather than a dictionary so the
    /// compiler refuses a new mode until it carries every value.
    ///
    /// Seven properties stay as their own switches because they branch rather
    /// than tabulate: `text`, `bodyText` and `subtext` route through the font
    /// axis, `isLight` derives, and `displayName`, `ground` and `panelGround`
    /// carry a `default`. Forcing those into a table would mean inventing a
    /// value for every mode that currently falls through.
    private var palette: LcdModePalette {
        switch self {
        case .dark:
            LcdModePalette(
                section: .classic,
                symbol: "moon.fill",
                monochromeTint: nil,
                screen: Dex.screen,
                accent: Dex.green,
                heroWash: Color(dexHex: "#14532d").opacity(0.1),
                heroGrid: Color(dexHex: "#14532d"),
                buttonWell: .black.opacity(0.35),
                page: .black,
                surface: Dex.stone900,
                surfaceEdge: Dex.stone700,
                well: .black,
                disabledText: Dex.stone600,
                onAccent: .black,
                gridLine: Dex.stone700,
                // The house amber, exactly what the classic chassis always wore.
                controlAccent: ChassisAccent(pale: "#fef3c7", light: "#fde68a", bright: "#fbbf24", mid: "#f59e0b", edge: "#b45309", ink: "#78350f"),
                globeTint: nil
            )
        case .light:
            LcdModePalette(
                section: .classic,
                symbol: "sun.max.fill",
                monochromeTint: nil,
                screen: Color(dexHex: "#E8E8E2"),
                accent: Color(dexHex: "#1B6B3A"),
                heroWash: Color(dexHex: "#1B6B3A").opacity(0.07),
                heroGrid: Color(dexHex: "#1B6B3A"),
                buttonWell: .white,
                page: Color(dexHex: "#F2F2EC"),
                surface: Color(dexHex: "#FFFFFF"),
                surfaceEdge: Color(dexHex: "#C9C9C1"),
                well: Color(dexHex: "#FFFFFF"),
                disabledText: Color(dexHex: "#A3A39B"),
                onAccent: .white,
                gridLine: Dex.stone400,
                controlAccent: ChassisAccent(pale: "#E8F5EC", light: "#BFE3CB", bright: "#4FA76F", mid: "#1B6B3A", edge: "#0F4224", ink: "#0B2E18"),
                // LIGHT inverts the texture instead (see `invertsGlobeTexture`); the
                // tint stays neutral so the inversion reads clean.
                globeTint: Color.white
            )
        case .vintage:
            LcdModePalette(
                section: .retro,
                symbol: "hourglass",
                monochromeTint: Color(dexHex: "#C6CFB2"),
                screen: Color(dexHex: "#E4E4DC"),
                accent: Color(dexHex: "#1A1A16"),
                heroWash: Color.black.opacity(0.06),
                heroGrid: Color(dexHex: "#3A3A34"),
                buttonWell: .white,
                page: Color(dexHex: "#EDEDE4"),
                surface: Color(dexHex: "#F6F6EF"),
                surfaceEdge: Color(dexHex: "#84847A"),
                well: Color(dexHex: "#FFFFFF"),
                disabledText: Color(dexHex: "#96968C"),
                onAccent: .white,
                gridLine: Dex.stone400,
                controlAccent: ChassisAccent(pale: "#F2F2EA", light: "#D8D8CC", bright: "#8A8A7C", mid: "#4A4A40", edge: "#26261F", ink: "#111110"),
                globeTint: Color(dexHex: "#C6CFB2")
            )
        case .amber:
            LcdModePalette(
                section: .retro,
                symbol: "lightbulb.fill",
                monochromeTint: Color(dexHex: "#FFB300"),
                screen: Dex.screen,
                accent: Dex.green,
                heroWash: Color(dexHex: "#14532d").opacity(0.1),
                heroGrid: Color(dexHex: "#14532d"),
                buttonWell: .black.opacity(0.35),
                page: .black,
                surface: Dex.stone900,
                surfaceEdge: Dex.stone700,
                well: .black,
                disabledText: Dex.stone600,
                onAccent: .black,
                gridLine: Dex.stone700,
                controlAccent: ChassisAccent(pale: "#FFF4D6", light: "#FFE29A", bright: "#FFB300", mid: "#D18F00", edge: "#7A5200", ink: "#3A2600"),
                globeTint: Color(dexHex: "#FFD27A")
            )
        case .wineOS:
            LcdModePalette(
                section: .emulator,
                symbol: "macwindow",
                monochromeTint: nil,
                screen: Color(dexHex: "#C7D3E6"),
                accent: Color(dexHex: "#1D3E9E"),
                heroWash: Color(dexHex: "#1D3E9E").opacity(0.07),
                heroGrid: Color(dexHex: "#1D3E9E"),
                buttonWell: .white,
                page: Color(dexHex: "#D6DFEE"),
                surface: Color(dexHex: "#E9EEF6"),
                surfaceEdge: Color(dexHex: "#8598B8"),
                well: Color(dexHex: "#FFFFFF"),
                disabledText: Color(dexHex: "#9FACC6"),
                onAccent: .white,
                gridLine: Color(dexHex: "#8598B8"),
                controlAccent: ChassisAccent(pale: "#EAF0FA", light: "#C2D2EC", bright: "#5B7FD4", mid: "#1D3E9E", edge: "#0E2258", ink: "#0A1A40"),
                globeTint: Color(dexHex: "#C2D2EC")
            )
        case .terminal:
            LcdModePalette(
                section: .retro,
                symbol: "terminal.fill",
                monochromeTint: Color(dexHex: "#4DFF4D"),
                screen: Dex.screen,
                accent: Dex.green,
                heroWash: Color(dexHex: "#14532d").opacity(0.1),
                heroGrid: Color(dexHex: "#14532d"),
                buttonWell: .black.opacity(0.35),
                page: .black,
                surface: Dex.stone900,
                surfaceEdge: Dex.stone700,
                well: .black,
                disabledText: Dex.stone600,
                onAccent: .black,
                gridLine: Dex.stone700,
                controlAccent: ChassisAccent(pale: "#E8FFE8", light: "#A8FFA8", bright: "#4DFF4D", mid: "#1FBF3F", edge: "#0A5A1E", ink: "#06300F"),
                globeTint: Color(dexHex: "#A8FFA8")
            )
        case .blueScreen:
            LcdModePalette(
                section: .emulator,
                symbol: "pc",
                monochromeTint: nil,
                screen: Color(dexHex: "#1021B4"),
                // VFD electric cyan — one register brighter than the text glow.
                accent: Color(dexHex: "#7DF9FF"),
                heroWash: Color.white.opacity(0.06),
                heroGrid: Color(dexHex: "#4A5FE0"),
                buttonWell: Color(dexHex: "#0A1690"),
                page: Color(dexHex: "#0E1CA8"),
                surface: Color(dexHex: "#1F31CE"),
                surfaceEdge: Color(dexHex: "#5D74E8"),
                well: Color(dexHex: "#0A1690"),
                disabledText: Color(dexHex: "#6272D4"),
                onAccent: Color(dexHex: "#0A1690"),
                gridLine: Color(dexHex: "#4A5FE0"),
                controlAccent: ChassisAccent(pale: "#E4F7FF", light: "#A6DBFF", bright: "#7DF9FF", mid: "#2FA8D8", edge: "#0A4A70", ink: "#062A40"),
                // VINOFD: the vacuum-fluorescent light blue.
                globeTint: Color(dexHex: "#A6DBFF")
            )
        case .starTrek:
            LcdModePalette(
                section: .emulator,
                symbol: "atom",
                monochromeTint: nil,
                screen: Color(dexHex: "#0B0910"),
                accent: Color(dexHex: "#C983E8"),
                heroWash: Color(dexHex: "#C983E8").opacity(0.08),
                heroGrid: Color(dexHex: "#7A4E9E"),
                buttonWell: .black.opacity(0.35),
                page: .black,
                surface: Color(dexHex: "#191022"),
                surfaceEdge: Color(dexHex: "#5C3E78"),
                well: .black,
                disabledText: Color(dexHex: "#6D5A49"),
                onAccent: .black,
                gridLine: Color(dexHex: "#3A2C1E"),
                controlAccent: ChassisAccent(pale: "#FFE9C7", light: "#FFC98A", bright: "#FFA94D", mid: "#E08A20", edge: "#7A4A08", ink: "#341F04"),
                // L-WINES: the console's accent purple.
                globeTint: Color(dexHex: "#C983E8")
            )
        case .gruenerBoy:
            LcdModePalette(
                section: .retro,
                symbol: "gamecontroller.fill",
                // The DMG's lightest tone; everything darker falls out of the
                // grayscale multiply.
                monochromeTint: Color(dexHex: "#9BBC0F"),
                screen: Color(dexHex: "#E6EBCF"),
                accent: Color(dexHex: "#2F3A1C"),
                heroWash: Color.black.opacity(0.06),
                heroGrid: Color(dexHex: "#3A4224"),
                buttonWell: .white,
                page: Color(dexHex: "#DDE3C2"),
                surface: Color(dexHex: "#EFF2DE"),
                surfaceEdge: Color(dexHex: "#7A8258"),
                well: Color(dexHex: "#F4F6E8"),
                disabledText: Color(dexHex: "#939B78"),
                onAccent: .white,
                gridLine: Color(dexHex: "#7A8258"),
                controlAccent: ChassisAccent(pale: "#E6EBCF", light: "#C2CE9A", bright: "#8BAC0F", mid: "#566A18", edge: "#24300C", ink: "#0F1A0A"),
                globeTint: Color(dexHex: "#C2CE9A")
            )
        }
    }
}

#endif
