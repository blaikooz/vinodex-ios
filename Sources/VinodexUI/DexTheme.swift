#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import CoreText
import VinodexCore

// MARK: - Colour

public extension Color {
    /// Builds a colour from `#RRGGBB` or `rgba(r,g,b,a)`, falling back to stone grey.
    ///
    /// The rgba form matters: three chip styles in `chipColors.ts`
    /// (SYSTEM / CLIMATE / BLUE) specify their background that way rather than as hex.
    init(dexHex raw: String) {
        let value = raw.trimmingCharacters(in: .whitespaces)

        if value.hasPrefix("rgba(") || value.hasPrefix("rgb(") {
            let inner = value
                .replacingOccurrences(of: "rgba(", with: "")
                .replacingOccurrences(of: "rgb(", with: "")
                .replacingOccurrences(of: ")", with: "")
            let parts = inner.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count >= 3, let r = parts[0], let g = parts[1], let b = parts[2] {
                let a = parts.count > 3 ? (parts[3] ?? 1) : 1
                self = Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
                return
            }
        }

        let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard hex.count == 6, let bits = UInt32(hex, radix: 16) else {
            self = Color(.sRGB, red: 0.47, green: 0.44, blue: 0.42, opacity: 1)
            return
        }
        self = Color(
            .sRGB,
            red: Double((bits >> 16) & 0xFF) / 255,
            green: Double((bits >> 8) & 0xFF) / 255,
            blue: Double(bits & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Chassis and LCD tokens, from the `@theme` block in `index.css` plus the
/// Tailwind palette values the chassis markup references directly.
public enum Dex {
    // index.css @theme
    public static let red = Color(dexHex: "#DC0A2D")
    public static let darkRed = Color(dexHex: "#89061C")
    public static let screen = Color(dexHex: "#232323")
    public static let screenBg = Color(dexHex: "#98CB98")
    public static let ui = Color(dexHex: "#DEDEDE")
    /// Midnight-skin equivalents of the chassis body and its front panel.
    public static let graphite = Color(dexHex: "#17161A")
    public static let graphitePanel = Color(dexHex: "#2B2A30")
    public static let graphiteEdge = Color(dexHex: "#4A4852")
    /// The original handheld's off-white shell and its cooler grey panel.
    public static let bone = Color(dexHex: "#D8D8D0")
    public static let bonePanel = Color(dexHex: "#EFEFE9")
    public static let boneEdge = Color(dexHex: "#9A9A93")
    /// Burgundy Velour — a velvet purple shell with a dusty lilac panel, so the
    /// pairing reads as upholstery rather than as a flat purple slab.
    public static let velour = Color(dexHex: "#4B1D3F")
    public static let velourPanel = Color(dexHex: "#D3BBCE")
    public static let velourEdge = Color(dexHex: "#2C0F24")
    /// Electric Riesling — the yellow of a 1980s sports Walkman. The panel is a
    /// dark grey with a light-grey edge: the pale panel it launched with sat so
    /// close to the classic white that the skin read as unskinned around the
    /// screen, and the pale-on-dark inversion is what the sports liveries did.
    public static let walkman = Color(dexHex: "#F2C11B")
    public static let walkmanPanel = Color(dexHex: "#4A4F55")
    public static let walkmanEdge = Color(dexHex: "#B9BEC4")
    public static let blue = Color(dexHex: "#2AB5FF")
    public static let yellow = Color(dexHex: "#FACC15")
    public static let green = Color(dexHex: "#4ADE80")

    // Tailwind values used by DeviceLayout.tsx
    public static let neutral900 = Color(dexHex: "#171717")
    public static let stone950 = Color(dexHex: "#0c0a09")
    public static let stone900 = Color(dexHex: "#1c1917")
    public static let stone800 = Color(dexHex: "#292524")
    public static let stone700 = Color(dexHex: "#44403c")
    public static let stone600 = Color(dexHex: "#57534e")
    public static let stone400 = Color(dexHex: "#a8a29e")
    public static let stone200 = Color(dexHex: "#e7e5e4")

    public static let cyan300 = Color(dexHex: "#67e8f9")
    public static let amber100 = Color(dexHex: "#fef3c7")
    public static let amber200 = Color(dexHex: "#fde68a")
    public static let amber400 = Color(dexHex: "#fbbf24")
    public static let amber500 = Color(dexHex: "#f59e0b")
    public static let amber700 = Color(dexHex: "#b45309")
    public static let amber900 = Color(dexHex: "#78350f")

    public static let red500 = Color(dexHex: "#ef4444")
    public static let red600 = Color(dexHex: "#dc2626")
    public static let red800 = Color(dexHex: "#991b1b")
    public static let yellow400 = Color(dexHex: "#facc15")
    public static let yellow600 = Color(dexHex: "#ca8a04")
    public static let green500 = Color(dexHex: "#22c55e")
    public static let green700 = Color(dexHex: "#15803d")
}

// MARK: - Metrics
//
// Values transcribed from `DeviceLayout.tsx`, mobile branch (below the `md:`
// breakpoint) — that is the branch the chassis uses on a phone, and the
// re-proportion-to-fill decision means we keep it rather than the fixed
// 522x850 desktop box. Tailwind rem = 16pt.

public enum DexMetrics {
    public static let rem: CGFloat = 16

    /// Outer chassis
    ///
    /// `deviceCorner` approximates the physical display's corner radius so the
    /// chassis outline follows it instead of being cropped by it; the inset
    /// keeps the stroke fully on-screen at the top corners.
    public static let chassisCorner: CGFloat = 2.5 * rem
    /// Main-menu tiles. Much rounder than the 12pt they were — at tile size a
    /// small radius reads as a plain rectangle.
    public static let menuTileCorner: CGFloat = 26
    public static let deviceCorner: CGFloat = 55
    public static let chassisBorderInset: CGFloat = 2
    public static let chassisBorder: CGFloat = 3
    /// Horizontal clearance for the display's rounded corners.
    ///
    /// A control sitting `chassisEdgeInset` (10pt) above the bottom edge is cut
    /// into by ~23pt of a 55pt corner arc — `deviceCorner - sqrt(r² - (r-h)²)`.
    /// The old 12pt padding put the outer edge of Back and Home inside that
    /// arc, so they were clipped on the diagonal. 26pt clears it with a margin.
    public static let cornerGuardH: CGFloat = 26

    /// Island strip
    ///
    /// The web app gives the orb, status lights and title their own red band
    /// above the bezel. On a phone that band is pure overhead — so they move
    /// into the top safe-area strip, flanking the Dynamic Island, which is dead
    /// chassis otherwise. The bezel keeps none of that height.
    ///
    /// `islandClearance` is the gap held open for the cutout: the Dynamic Island
    /// is ~126pt wide on Pro models, and this is deliberately wider so the flank
    /// content never tucks under it.
    public static let headerPaddingH: CGFloat = rem
    /// Floor for the island strip. `.statusBarHidden()` can collapse
    /// `safeAreaInsets.top` to zero on cutout devices, so this must independently
    /// be tall enough to contain the island (~11pt from the top, ~37pt tall).
    /// Equal breathing room above the header row and below the footer row.
    /// This is the only thing holding either row off the display's rounded
    /// corners, and using one value for both is what makes the chassis read as
    /// symmetric top to bottom.
    public static let chassisEdgeInset: CGFloat = 16
    /// Gap between the screen housing and the bands. Minimal on purpose — every
    /// point here comes off the LCD — but non-zero so the housing does not butt
    /// straight into the controls.
    public static let housingGap: CGFloat = 4
    /// Gap from the island controls down to the screen housing. Used to match
    /// `footerTopInset` (6); tightened so the controls sit closer to the
    /// housing while the raised `islandTopInset` gives them air above instead.
    public static let islandBottomInset: CGFloat = 2
    /// Gap from the display's top edge down to the island controls.
    ///
    /// This was `chassisEdgeInset` (16), on the argument that the band should
    /// mirror the footer — big inset against the display edge, small one against
    /// the screen. The footer earns its 16 because the home indicator lands in
    /// it. There is no home indicator up here, so the same number bought
    /// nothing and simply pushed the orb and cog down into the LCD's height.
    ///
    /// 12, and the floor below it is load-bearing: the display's 55pt corner
    /// arc cuts `55 - sqrt(55² - (55-h)²)` off each side at height `h`, which
    /// at 8pt is ~26pt — exactly `cornerGuardH`. The controls survive it
    /// because they are *circles*: the widest point of the orb sits half a
    /// control lower, where the arc has closed to ~2pt. Going below 8 starts
    /// cutting the button's actual edge rather than the empty corner of its
    /// bounding box; above it is always safe, and the breathing room above
    /// the island controls is the whole point of the raise.
    public static let islandTopInset: CGFloat = 18
    /// Floor for the island strip: the inset above, one control, then the small
    /// `islandBottomInset` against the screen housing.
    public static let islandStripMinHeight: CGFloat = islandTopInset + controlButton + islandBottomInset
    public static let islandClearance: CGFloat = 138
    /// Matches `footerPaddingH` so the orb sits directly above the Back button
    /// and the cog above Home — the four chassis controls share two columns.
    public static let islandFlankPaddingH: CGFloat = cornerGuardH
    /// Matched to `ventStripHeight` so the white housing frames the LCD evenly
    /// top and bottom. Trimmed from 1.75rem: symmetric was right, but that much
    /// white read as a thick border and it was all LCD height.
    public static let bezelTopMargin: CGFloat = rem
    /// Tightened so the three status lights read as one cluster next to the
    /// larger orb rather than a spread-out row.
    public static let statusDotSpacing: CGFloat = 0.2 * rem
    /// Gap between the orb and the status-light cluster now that the lights sit
    /// beside it rather than on its shoulder. Tightened from 6 to pull the
    /// cluster in toward the orb.
    public static let statusDotsGap: CGFloat = 3
    /// How far the status cluster rides above the orb's centre line.
    ///
    /// Centred, the three lights read as a continuation of the orb — one row of
    /// four round things. Lifted, they read as indicator lamps set into the
    /// chassis *above* the control, which is where a period device puts them.
    /// An offset rather than an alignment guide: this is decoration and must not
    /// change what the strip reserves.
    public static let statusDotsRise: CGFloat = 12
    public static let titleSize: CGFloat = 0.9375 * rem

    /// Screen housing
    public static let screenPanelCorner: CGFloat = 2 * rem
    /// Thinner grey edge, so more of the panel reads as the white/graphite
    /// moulding rather than outline. The stroke is inset, so what it gives up
    /// the panel colour takes.
    public static let screenPanelBorder: CGFloat = 4
    public static let screenPanelInset: CGFloat = 0.5 * rem   // m-2
    public static let bezelCorner: CGFloat = 1.75 * rem
    public static let bezelInsetH: CGFloat = 0.75 * rem       // mx-3
    /// Thickness of the stone frame around the LCD. Kept small on purpose:
    /// every point here is a point of screen height.
    public static let bezelFrame: CGFloat = 4
    /// The white panel's skirt below the LCD. Deliberately taller than
    /// `bezelTopMargin` rather than matched to it: this one has to seat the vent
    /// dot and the three grill slats, and at 1rem they were crowding its edges.
    /// The top margin holds nothing, so it stays thin.
    public static let ventStripHeight: CGFloat = 1.75 * rem
    public static let ventDot: CGFloat = 0.5 * rem            // w-2

    /// Footer
    ///
    /// Trimmed from the web app's 6.5rem band: the marquee was tall enough to
    /// crowd the LCD on a phone, and its height is what drives the footer's.
    ///
    /// The band is **deliberately asymmetric** — `footerTopInset` above the row,
    /// `chassisEdgeInset` below. It was centred in a band shared with the island
    /// strip, which put an equal 16pt on both sides; but the two sides are not
    /// equivalent. Below the row is home-indicator territory and has to stay
    /// clear, while above it is just a gap to the screen housing, and closing
    /// that gap is what brings the controls up under the screen where the thumb
    /// already is.
    ///
    /// It still deliberately does **not** add the home-indicator safe-area
    /// inset: that inset alone is 34pt and made the bottom chrome nearly twice
    /// the top. The indicator falls in the `chassisEdgeInset` of bare chassis
    /// below the row rather than over a control.
    public static let footerHeight: CGFloat = footerTopInset + footerControl + chassisEdgeInset
    /// Gap between the screen housing and the footer row. Much tighter than the
    /// inset below the row — see `footerHeight`.
    public static let footerTopInset: CGFloat = 6
    public static let footerPaddingH: CGFloat = cornerGuardH
    /// **One** diameter for every physical control on the chassis: the orb and
    /// the cog on the island strip, Back/saved and Home in the footer.
    ///
    /// The island pair used to be 3.5rem against the footer's 4rem, on the
    /// argument that the footer buttons are the ones in constant use. Sitting in
    /// the same two columns at two different sizes just read as a mistake, so
    /// they are all `footerControl` now and the strip is sized to seat it.
    public static let controlButton: CGFloat = footerControl
    public static let footerControl: CGFloat = 4 * rem
    public static let marqueeMaxWidth: CGFloat = 16.5 * rem
    public static let marqueeCorner: CGFloat = 0.8 * rem
    public static let marqueeInnerCorner: CGFloat = 0.6 * rem
    /// The banner matches the control buttons so the footer reads as one row.
    public static let marqueeHeight: CGFloat = footerControl
    /// One size for every screen: the main screen's longer banner scrolls,
    /// so it does not need to shrink to fit. Scaled with `footerControl`.
    public static let marqueeTextSize: CGFloat = 1.45 * rem

    /// How long the device takes to turn over.
    ///
    /// Lives here rather than on `DeviceChassis` because that type is generic
    /// over its content, and Swift has no static stored properties on generic
    /// types — the half of this value is what times the face swap, so the two
    /// must come from one number.
    public static let flipDuration: Double = 0.7

    /// Scanline overlay
    public static let scanlineSpacing: CGFloat = 4
    public static let scanlineThickness: CGFloat = 2
    public static let scanlineOpacity: Double = 0.2
}

// MARK: - Fonts
//
// Registered from the bundle at runtime via CoreText. This is the pattern
// salvaged from the Rork skeleton and it is the correct one here: `actool` is
// macOS-only, so there is no asset catalog to declare fonts in.
//
// Swift 6 strict concurrency forbids mutable statics, so the registration
// result is computed once into an immutable value.

public enum DexFont {
    public struct Registration: Sendable {
        public var registered: [String] = []
        public var failed: [String] = []
        public var available: Bool { failed.isEmpty }
    }

    static let names = (retro: "PressStart2P-Regular", mono: "VT323-Regular")

    public static let registration: Registration = {
        var out = Registration()
        for name in [names.retro, names.mono] {
            guard let url = DexResources.url(named: name, ext: "ttf", subdirectory: "Resources/Fonts") else {
                out.failed.append(name + " (not in bundle)")
                continue
            }
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                out.registered.append(name)
            } else {
                // Already-registered is not a failure worth reporting.
                let code = (error?.takeUnretainedValue() as (any Error)?).map { ($0 as NSError).code } ?? -1
                if code == Int(CTFontManagerError.alreadyRegistered.rawValue) {
                    out.registered.append(name)
                } else {
                    out.failed.append("\(name) (register failed, code \(code))")
                }
            }
        }
        return out
    }()

    /// Font availability resolved once. A face's registration state cannot change
    /// at runtime, so probing `UIFont(name:)` on every `retro`/`mono` call (which
    /// happens per glyph, per render) was pure waste. The initialiser forces
    /// `registration` first so the probe runs after the fonts are registered.
    public static let retroAvailable: Bool = { _ = registration; return isAvailable(names.retro) }()
    public static let monoAvailable: Bool = { _ = registration; return isAvailable(names.mono) }()

    /// Pixel display face — titles, category labels, chips.
    public static func retro(_ size: CGFloat) -> Font {
        let size = size * TextScale.current.factor
        return retroAvailable
            ? .custom(names.retro, size: size)
            : .system(size: size, weight: .bold, design: .monospaced)
    }

    /// CRT terminal face — body copy and readouts.
    public static func mono(_ size: CGFloat) -> Font {
        let size = size * TextScale.current.factor
        return monoAvailable
            ? .custom(names.mono, size: size)
            : .system(size: size, design: .monospaced)
    }

    /// Whether a face actually resolved. Distinguishes "registered" from
    /// "silently falling back to a system font", which looks fine but is wrong.
    public static func isAvailable(_ name: String) -> Bool {
        UIFont(name: name, size: 12) != nil
    }

    /// Human-readable status for the debug catalog and syslog diagnostics.
    public static var statusReport: [String] {
        var lines = ["registered \(registration.registered.count)/2"]
        lines.append("PressStart2P: " + (isAvailable(names.retro) ? "OK" : "FALLBACK"))
        lines.append("VT323: " + (isAvailable(names.mono) ? "OK" : "FALLBACK"))
        lines.append(contentsOf: registration.failed.map { "FAILED " + $0 })
        return lines
    }
}

// MARK: - Resources

/// Bundle lookup without an asset catalog.
///
/// SwiftPM places target resources in `Bundle.module`, not `Bundle.main` — a
/// distinction that matters because the skeleton's version looked in `.main`.
public enum DexResources {
    public static func url(named name: String, ext: String, subdirectory: String? = nil) -> URL? {
        if let subdirectory,
           let hit = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            return hit
        }
        return Bundle.module.url(forResource: name, withExtension: ext)
    }
}

/// Main-screen text scale. Deliberately a small adjustment with a hard floor
/// and ceiling: the retro face has no optical sizes, so a large jump breaks the
/// tile layout and a small one stops being legible at arm's length.
///
/// Applies to the main menu only — entry screens carry long copy and already
/// wrap, so scaling those is a different problem.
public enum TextScale: String, CaseIterable, Identifiable, Sendable {
    case small = "SMALL"
    case large = "LARGE"

    public static let storageKey = "textScale"

    public var id: String { rawValue }

    /// Both steps moved down one notch: LARGE is now what SMALL used to be
    /// (1.0), and SMALL goes below it. The old pair ran 1.0/1.2, which meant
    /// the *smallest* the app could be was already the size the tiles were
    /// drawn against — there was headroom above the layout but none below it,
    /// and LARGE was the one that crowded its tiles.
    ///
    /// 1.0 stays the ceiling for the same reason it was the old floor: the
    /// retro face has no optical sizes and the tile metrics are tuned to it.
    public var factor: CGFloat {
        switch self {
        case .small: 0.85
        case .large: 1.0
        }
    }

    /// Read straight from defaults so `DexFont` can apply it without every
    /// call site threading it through. Views re-render because `RootView`
    /// keys its content on the setting — see `VinodexApp`.
    public static var current: TextScale {
        TextScale(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .small
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
    /// The vintage CRT diagnostic screen: deep blue ground, white text, a
    /// pale cyan for everything that would be green elsewhere.
    case blueScreen = "BLUE SCREEN"
    /// A vintage starship console: black glass, amber readouts, and purple
    /// for the accents — the two colours those panels actually ran.
    case starTrek = "STAR TREK"

    public static let storageKey = "lcdMode"

    public var id: String { rawValue }

    /// Whether the screen ground is pale. An explicit list, not `!= .dark`:
    /// vintage is dark ink on a pale ground and wants every light branch, but
    /// amber is a *dark* mode — pale scrims and dark-on-accent ink on it would
    /// be wrong in both directions. WINE OS joins the pale side; the other
    /// themed modes are dark glass.
    public var isLight: Bool { self == .light || self == .vintage || self == .wineOS }

    /// The tint the chassis multiplies the grayscaled LCD by — nil renders in
    /// colour. This is what turns "black on white" into "black on grey-green"
    /// (vintage) and "white on black" into "amber on black" (amber) or
    /// terminal green (terminal).
    public var monochromeTint: Color? {
        switch self {
        case .dark, .light, .wineOS, .blueScreen, .starTrek: nil
        case .vintage: Color(dexHex: "#C6CFB2")
        case .amber: Color(dexHex: "#FFB300")
        case .terminal: Color(dexHex: "#4DFF4D")
        }
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
        }
    }

    /// LCD ground.
    public var screen: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.screen
        case .light: Color(dexHex: "#E8E8E2")
        case .vintage: Color(dexHex: "#E4E4DC")
        case .wineOS: Color(dexHex: "#C7D3E6")
        case .blueScreen: Color(dexHex: "#1021B4")
        case .starTrek: Color(dexHex: "#0B0910")
        }
    }

    /// Primary text on that ground.
    public var text: Color {
        switch self {
        case .dark, .amber, .terminal: .white
        case .light: Color(dexHex: "#1F1F1C")
        case .vintage: Color(dexHex: "#101010")
        case .wineOS: Color(dexHex: "#0E2258")
        case .blueScreen: Color(dexHex: "#F4F7FF")
        case .starTrek: Color(dexHex: "#FFA94D")
        }
    }

    /// Section rules, headers and glyph tints. The dark theme's #4ADE80 is
    /// invisible on white, so light mode drops to a deep bottle green that
    /// still reads as "the green" without disappearing. Vintage has no colour
    /// to keep — its accent is simply ink. The themed modes each pick the one
    /// colour their reference hardware used for emphasis.
    public var accent: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.green
        case .light: Color(dexHex: "#1B6B3A")
        case .vintage: Color(dexHex: "#1A1A16")
        case .wineOS: Color(dexHex: "#1D3E9E")
        case .blueScreen: Color(dexHex: "#93DBFF")
        case .starTrek: Color(dexHex: "#C983E8")
        }
    }

    /// Body copy inside INFO blocks — mint on black, near-black on paper.
    public var bodyText: Color {
        switch self {
        case .dark, .amber, .terminal: Color(dexHex: "#bbf7d0")
        case .light: Color(dexHex: "#23342A")
        case .vintage: Color(dexHex: "#20201C")
        case .wineOS: Color(dexHex: "#22335E")
        case .blueScreen: Color(dexHex: "#DCE4FF")
        case .starTrek: Color(dexHex: "#F2CD9A")
        }
    }

    /// Hero panel wash behind an entry title.
    public var heroWash: Color {
        switch self {
        case .dark, .amber, .terminal: Color(dexHex: "#14532d").opacity(0.1)
        case .light: Color(dexHex: "#1B6B3A").opacity(0.07)
        case .vintage: Color.black.opacity(0.06)
        case .wineOS: Color(dexHex: "#1D3E9E").opacity(0.07)
        case .blueScreen: Color.white.opacity(0.06)
        case .starTrek: Color(dexHex: "#C983E8").opacity(0.08)
        }
    }

    /// Grid lines drawn over the hero wash. Dark mode's deep #14532d reads heavy
    /// on the light hero, so light mode lifts it toward the paper.
    public var heroGrid: Color {
        switch self {
        case .dark, .amber, .terminal: Color(dexHex: "#14532d")
        case .light: Color(dexHex: "#1B6B3A")
        case .vintage: Color(dexHex: "#3A3A34")
        case .wineOS: Color(dexHex: "#1D3E9E")
        case .blueScreen: Color(dexHex: "#4A5FE0")
        case .starTrek: Color(dexHex: "#7A4E9E")
        }
    }

    /// Filled-button ground (SAVE and friends) when *not* active.
    public var buttonWell: Color {
        switch self {
        case .dark, .amber, .terminal, .starTrek: .black.opacity(0.35)
        case .light, .vintage, .wineOS: .white
        case .blueScreen: Color(dexHex: "#0A1690")
        }
    }

    /// Ground behind entry screens, which paint their own black rather than
    /// using `DexScreenBackground`.
    public var page: Color {
        switch self {
        case .dark, .amber, .terminal: .black
        case .light: Color(dexHex: "#F2F2EC")
        case .vintage: Color(dexHex: "#EDEDE4")
        case .wineOS: Color(dexHex: "#D6DFEE")
        case .blueScreen: Color(dexHex: "#0E1CA8")
        case .starTrek: .black
        }
    }

    /// Row and card fill.
    public var surface: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone900
        case .light: Color(dexHex: "#FFFFFF")
        case .vintage: Color(dexHex: "#F6F6EF")
        case .wineOS: Color(dexHex: "#E9EEF6")
        case .blueScreen: Color(dexHex: "#1F31CE")
        case .starTrek: Color(dexHex: "#191022")
        }
    }

    public var surfaceEdge: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone700
        case .light: Color(dexHex: "#C9C9C1")
        case .vintage: Color(dexHex: "#84847A")
        case .wineOS: Color(dexHex: "#8598B8")
        case .blueScreen: Color(dexHex: "#5D74E8")
        case .starTrek: Color(dexHex: "#5C3E78")
        }
    }

    /// Secondary text — captions, counts, placeholders.
    public var subtext: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone400
        case .light: Color(dexHex: "#5A5A54")
        case .vintage: Color(dexHex: "#42423C")
        case .wineOS: Color(dexHex: "#465578")
        case .blueScreen: Color(dexHex: "#B8C4F8")
        case .starTrek: Color(dexHex: "#C2915C")
        }
    }

    /// Fill behind search fields, which are black wells on the dark theme.
    public var well: Color {
        switch self {
        case .dark, .amber, .terminal, .starTrek: .black
        case .light, .vintage, .wineOS: Color(dexHex: "#FFFFFF")
        case .blueScreen: Color(dexHex: "#0A1690")
        }
    }

    /// Text on a row that exists but cannot be opened — a cross-link pointing
    /// outside the current selection, or a country with no region written yet.
    ///
    /// Has to read as *inactive* without disappearing, which is why light mode
    /// does not simply share the dark theme's stone600: against `surface` that
    /// grey is close enough to `text` to look like an ordinary enabled row.
    public var disabledText: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone600
        case .light: Color(dexHex: "#A3A39B")
        case .vintage: Color(dexHex: "#96968C")
        case .wineOS: Color(dexHex: "#9FACC6")
        case .blueScreen: Color(dexHex: "#6272D4")
        case .starTrek: Color(dexHex: "#6D5A49")
        }
    }

    /// Foreground for content sitting on an `accent` fill (selected settings
    /// options, active chips). Dark mode's accent is mint (#4ADE80) — white text
    /// on it is ~1.8:1 — so it takes black; light mode's accent is deep green and
    /// takes white, as does vintage's ink-black. Blue Screen's accent is a pale
    /// cyan, so it takes the deep well blue rather than plain black.
    public var onAccent: Color {
        switch self {
        case .dark, .amber, .terminal, .starTrek: .black
        case .light, .vintage, .wineOS: .white
        case .blueScreen: Color(dexHex: "#0A1690")
        }
    }

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
    public var gridLine: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone700
        case .light, .vintage: Dex.stone400
        case .wineOS: Color(dexHex: "#8598B8")
        case .blueScreen: Color(dexHex: "#4A5FE0")
        case .starTrek: Color(dexHex: "#3A2C1E")
        }
    }

    /// Ground for full-screen panels (settings and friends), which used to
    /// paint `Dex.screen` on dark and `page` on light. One token so the
    /// themed modes get their own colour in both directions.
    public var panelGround: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.screen
        default: page
        }
    }

    public static var current: LcdMode {
        LcdMode(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .dark
    }
}

/// The six-stop colour ramp one lit chassis button is built from.
///
/// A struct rather than six properties on `ChassisSkin` because they are only
/// ever used together, and a skin that got four of them right and two of them
/// from the previous colourway would look like a manufacturing fault rather than
/// like a mistake in the code.
///
/// Named by lightness rather than by where each one lands, so a skin author does
/// not have to know that `mid` is both the outer button's bottom stop and the
/// inner disc's ring. `ChassisButton` owns that arrangement.
public struct ChassisAccent: Sendable {
    /// Inner disc, top.
    public let pale: Color
    /// Outer button, top.
    public let light: Color
    /// Inner disc, bottom.
    public let bright: Color
    /// Outer button, bottom — and the inner disc's hairline.
    public let mid: Color
    /// Outer border.
    public let edge: Color
    /// The glyph.
    public let ink: Color

    public init(pale: String, light: String, bright: String, mid: String, edge: String, ink: String) {
        self.pale = Color(dexHex: pale)
        self.light = Color(dexHex: light)
        self.bright = Color(dexHex: bright)
        self.mid = Color(dexHex: mid)
        self.edge = Color(dexHex: edge)
        self.ink = Color(dexHex: ink)
    }
}

/// The moulded (unlit) chassis buttons: Back and the user/saved button.
///
/// Separate from `ChassisAccent` because these are a different *kind* of part.
/// The accent ramp describes something that looks powered — six stops, an inner
/// disc, a glow. This is a moulded cap: a face, a shadow under it, a rim, and
/// whatever colour the glyph has to be to sit on it.
///
/// `glyph` is here rather than assumed white because one skin needs it dark.
/// Blanc de Blancs' buttons are the original handheld's pale grey, and white on
/// pale grey is unreadable.
public struct ChassisControl: Sendable {
    /// Top of the cap's gradient.
    public let top: Color
    /// Bottom of it.
    public let bottom: Color
    /// The rim.
    public let edge: Color
    /// The chevron or person glyph.
    public let glyph: Color

    public init(top: String, bottom: String, edge: String, glyph: String) {
        self.top = Color(dexHex: top)
        self.bottom = Color(dexHex: bottom)
        self.edge = Color(dexHex: edge)
        self.glyph = Color(dexHex: glyph)
    }
}

/// Chassis colourway. The LCD itself never changes — only the moulding around
/// it — so a skin swap cannot affect legibility of the content.
///
/// Persisted under this key by both `DeviceChassis` and `SettingsPanel`;
/// `@AppStorage` keeps the two in sync without threading state between them.
///
/// A skin used to be four greys and a body colour: swap it and you got the same
/// cyan orb, the same amber Home button and the same green marquee in a
/// different-coloured tray. The moulding changed and none of the *parts* did,
/// which is why four of the five read as recolours of one device rather than as
/// five devices. Each now carries its own orb, its own lit-button ramp and its
/// own marquee phosphor.
///
/// **Vinodex Classic is deliberately untouched** — every value below for
/// `.classic` is what the whole chassis used before this existed. It is the
/// house device and the reference the others are variations on; changing it
/// would move the baseline rather than add to it.
public enum ChassisSkin: String, CaseIterable, Identifiable, Sendable {
    case classic = "CLASSIC"
    case midnight = "MIDNIGHT"
    /// The original grey-and-white shell rather than the red one.
    case original = "ORIGINAL"
    /// Velvet purple.
    case burgundy = "BURGUNDY"
    /// Vintage Walkman yellow.
    case riesling = "RIESLING"
    /// Forest-green DMG homage: pea-green screen tint, grey/black buttons,
    /// dark brown accents.
    case vinhoVerde = "VINHO VERDE"
    /// The clear-technology shell — translucent smoke plastic over mock
    /// internals, with bright orange for everything powered.
    case glouglou = "GLOUGLOU"
    /// The iPhone calculator's livery: near-black shell, warm dark-grey keys
    /// with a brown cast, and calculator-orange for everything powered.
    case smartGrape = "SMART GRAPE"
    /// Pale champagne-gold shell with gold-leaf powered parts — elegant, not
    /// garish; the dressing-table of the range.
    case champagne = "CHAMPAGNE"
    /// Pine shell, snow panel, red caps and gold lights. Seasonal in theme
    /// only — a skin that vanished in January would read as a bug, not a gift.
    case christmas = "CHRISTMAS"

    public static let storageKey = "chassisSkin"

    public var id: String { rawValue }

    /// Whether the shell is see-through — `DeviceChassis`'s cue to mount the
    /// mock internals behind it. A flag rather than sniffing alpha out of a
    /// `Color`, which SwiftUI does not expose anyway.
    public var isTranslucent: Bool { self == .glouglou }

    /// What sits behind the shell: the shell itself for opaque skins, a
    /// near-black base under GLOUGLOU so the smoke plastic has something to be
    /// smoke over.
    public var underlay: Color {
        isTranslucent ? Color(dexHex: "#14161A") : body
    }

    /// What the picker calls this skin.
    ///
    /// Deliberately separate from `rawValue`: the raw value is the persisted
    /// `@AppStorage` key, so renaming ORIGINAL to "Blanc de Blancs" by editing
    /// the case would silently reset every device already storing "ORIGINAL"
    /// back to the default shell. The stored vocabulary stays put and only the
    /// label moves.
    public var displayName: String {
        switch self {
        // The house colourway, named for the house rather than described as
        // "classic" — every other skin here has a wine name, and the default
        // was the only one still labelled by category.
        case .classic: "VINODEX CLASSIC"
        case .midnight: "CÔTE DE NUITS"
        case .original: "BLANC DE BLANCS"
        case .burgundy: "BURGUNDY VELOUR"
        case .riesling: "ELECTRIC RIESLING"
        // Renamed for v0.5.1 — labels only. The raw values are the persisted
        // vocabulary and stay put, per the note above.
        case .vinhoVerde: "BOX WINE"
        case .glouglou: "EMPTY BOTTLE"
        case .smartGrape: "SMART GRAPE"
        case .champagne: "CHAMPAGNE GOLD"
        case .christmas: "WINE XMAS"
        }
    }

    /// A tileable pixel-art pattern drawn over the shell colour, or nil for a
    /// plain moulding. WINE XMAS wraps the chassis in wrapping paper; the
    /// pattern sits under the panel and footer wash like any other body.
    public var bodyPatternAsset: String? {
        self == .christmas ? "xmas-wrap" : nil
    }

    /// Overrides the three status lamps' red/yellow/green when a skin wants
    /// its own signal colour. WINE XMAS runs all three red, like a string of
    /// holly-berry fairy lights.
    public var statusLightOverride: (fill: Color, border: Color)? {
        self == .christmas
            ? (Color(dexHex: "#FF4D4D"), Color(dexHex: "#8F1414"))
            : nil
    }

    /// The moulding.
    public var body: Color {
        switch self {
        case .classic: Dex.red
        case .midnight: Dex.graphite
        case .original: Dex.bone
        case .burgundy: Dex.velour
        case .riesling: Dex.walkman
        case .vinhoVerde: Color(dexHex: "#24402B")
        // Smoke plastic — the only translucent body; see `underlay`.
        case .glouglou: Color(dexHex: "rgba(204,216,224,0.40)")
        case .smartGrape: Color(dexHex: "#1C1C1E")
        case .champagne: Color(dexHex: "#E8D5A6")
        case .christmas: Color(dexHex: "#1B4332")
        }
    }

    /// Wash behind the footer row, a shade off the body.
    public var footerWash: Color {
        switch self {
        case .classic: Dex.red.opacity(0.7)
        case .midnight: Dex.graphite.opacity(0.75)
        case .original: Dex.bone.opacity(0.75)
        case .burgundy: Dex.velour.opacity(0.75)
        case .riesling: Dex.walkman.opacity(0.7)
        case .vinhoVerde: Color(dexHex: "#24402B").opacity(0.75)
        case .glouglou: Color(dexHex: "rgba(204,216,224,0.28)")
        case .smartGrape: Color(dexHex: "#1C1C1E").opacity(0.75)
        case .champagne: Color(dexHex: "#E8D5A6").opacity(0.75)
        case .christmas: Color(dexHex: "#1B4332").opacity(0.75)
        }
    }

    /// The panel the LCD is set into — white on the classic shell.
    public var panel: Color {
        switch self {
        case .classic: Dex.ui
        case .midnight: Dex.graphitePanel
        case .original: Dex.bonePanel
        case .burgundy: Dex.velourPanel
        case .riesling: Dex.walkmanPanel
        case .vinhoVerde: Color(dexHex: "#2E4F36")
        case .glouglou: Color(dexHex: "rgba(234,241,246,0.55)")
        case .smartGrape: Color(dexHex: "#2C2A28")
        case .champagne: Color(dexHex: "#F6EEDC")
        case .christmas: Color(dexHex: "#F4F7F2")
        }
    }

    public var panelEdge: Color {
        switch self {
        case .classic: Dex.stone400
        case .midnight: Dex.graphiteEdge
        case .original: Dex.boneEdge
        case .burgundy: Dex.velourEdge
        case .riesling: Dex.walkmanEdge
        case .vinhoVerde: Color(dexHex: "#16281B")
        case .glouglou: Color(dexHex: "rgba(148,163,184,0.85)")
        case .smartGrape: Color(dexHex: "#5A5148")
        case .champagne: Color(dexHex: "#B49B62")
        case .christmas: Color(dexHex: "#9CAF9C")
        }
    }

    /// Speaker grill slats.
    public var grill: Color {
        switch self {
        case .classic: Dex.stone400
        case .midnight: Dex.stone600
        case .original: Dex.stone400
        case .burgundy: Dex.velourEdge
        case .riesling: Dex.walkmanEdge
        case .vinhoVerde: Color(dexHex: "#16281B")
        // Opaque on purpose: the slats sit over the internals and would
        // otherwise vanish into them.
        case .glouglou: Color(dexHex: "#64748B")
        case .smartGrape: Color(dexHex: "#5A5148")
        case .champagne: Color(dexHex: "#B49B62")
        case .christmas: Color(dexHex: "#9CAF9C")
        }
    }

    // MARK: Parts
    //
    // The three things on the chassis that emit light rather than merely being
    // moulded: the orb, the lit button, and the marquee. Everything above this
    // point is plastic; everything below it is powered, which is why these are
    // the parts worth varying — a skin reads as a different *device* when its
    // indicators are a different colour, and as a paint job when they are not.

    /// The glass orb on the island strip.
    public var orb: Color {
        switch self {
        case .classic: Dex.cyan300
        // Pinot noir after dark: amethyst rather than ice.
        case .midnight: Color(dexHex: "#d8b4fe")
        // A champagne bead on the pale shell — cyan vanished against bone.
        case .original: Color(dexHex: "#ffd76e")
        // Deep purple, matching the buttons — the whole powered set on this
        // shell now runs one colour, like a single dye lot.
        case .burgundy: Color(dexHex: "#7c3aed")
        // A red signal lamp on the yellow shell — the one saturated colour the
        // grey-buttoned livery leaves room for.
        case .riesling: Color(dexHex: "#ef4444")
        // The DMG's own pea-green screen, reborn as a lamp.
        case .vinhoVerde: Color(dexHex: "#9BBC0F")
        case .glouglou: Color(dexHex: "#FB923C")
        // Calculator-orange, the operator key.
        case .smartGrape: Color(dexHex: "#FF9F0A")
        // A gold bead in a gold shell — one dye lot, like burgundy's purple.
        case .champagne: Color(dexHex: "#F5D97E")
        // The warm fairy-light gold, not the caps' red — red-on-pine is the
        // moulding's job.
        case .christmas: Color(dexHex: "#FFD166")
        }
    }

    /// Its halo. Deeper than `orb` in every case — the glow reads as the orb's
    /// own colour bleeding out, not as a second light behind it.
    public var orbGlow: Color {
        switch self {
        case .classic: Dex.blue
        case .midnight: Color(dexHex: "#a855f7")
        case .original: Color(dexHex: "#f0b429")
        case .burgundy: Color(dexHex: "#5b21b6")
        case .riesling: Color(dexHex: "#b91c1c")
        case .vinhoVerde: Color(dexHex: "#8BAC0F")
        case .glouglou: Color(dexHex: "#EA580C")
        case .smartGrape: Color(dexHex: "#C97800")
        case .champagne: Color(dexHex: "#D4A017")
        case .christmas: Color(dexHex: "#D9962B")
        }
    }

    /// Home, and anything else built to look powered.
    public var accent: ChassisAccent {
        switch self {
        // Amber, exactly as before.
        case .classic:
            ChassisAccent(pale: "#fef3c7", light: "#fde68a", bright: "#fbbf24",
                          mid: "#f59e0b", edge: "#b45309", ink: "#78350f")
        case .midnight:
            ChassisAccent(pale: "#f3e8ff", light: "#e9d5ff", bright: "#c084fc",
                          mid: "#a855f7", edge: "#6b21a8", ink: "#3b0764")
        // Yellow — sunlight on the bone shell, and the one warm colour the
        // pale moulding leaves room for. (Was magenta, after the original
        // handheld's A/B buttons, which read as an error state on white.)
        case .original:
            ChassisAccent(pale: "#fefce8", light: "#fef08a", bright: "#facc15",
                          mid: "#eab308", edge: "#a16207", ink: "#713f12")
        // Deep purple, one shade brighter than the shell so Home still reads
        // as the powered part rather than more upholstery.
        case .burgundy:
            ChassisAccent(pale: "#ede9fe", light: "#ddd6fe", bright: "#8b5cf6",
                          mid: "#6d28d9", edge: "#4c1d95", ink: "#2e1065")
        // Greys, to match the moulded caps — on this shell the red orb is the
        // only powered colour, which is what makes it a signal lamp.
        case .riesling:
            ChassisAccent(pale: "#f4f5f6", light: "#d8dadd", bright: "#b6b9be",
                          mid: "#8b8f95", edge: "#4b4f54", ink: "#1c1e21")
        // Dark brown — the DMG's burgundy buttons aged into leather.
        case .vinhoVerde:
            ChassisAccent(pale: "#E7D8C9", light: "#C8A98B", bright: "#8B5E3C",
                          mid: "#6B4226", edge: "#3E2417", ink: "#241207")
        case .glouglou:
            ChassisAccent(pale: "#FFEDD5", light: "#FED7AA", bright: "#FB923C",
                          mid: "#F97316", edge: "#C2410C", ink: "#7C2D12")
        // The operator key: calculator orange, lit.
        case .smartGrape:
            ChassisAccent(pale: "#FFE8C7", light: "#FFC66E", bright: "#FF9F0A",
                          mid: "#E08600", edge: "#8F5600", ink: "#3D2400")
        // Gold leaf, one register deeper than the shell.
        case .champagne:
            ChassisAccent(pale: "#FDF6E3", light: "#F5E3AE", bright: "#E3BC5F",
                          mid: "#C89B3C", edge: "#8A6820", ink: "#4A3510")
        // Holly-berry red, to match the caps and the lights — the whole
        // powered set runs red on the wrapping paper. (Was bauble gold; the
        // orb keeps the fairy-light gold so the shell still carries both
        // Christmas colours.)
        case .christmas:
            ChassisAccent(pale: "#FFE7E7", light: "#FFB3B3", bright: "#F25454",
                          mid: "#D32F2F", edge: "#7A1010", ink: "#3D0000")
        }
    }

    /// Back and the user button.
    ///
    /// These were one dark cap on all five shells, on the argument that the
    /// mechanical controls should stay the same part across the range while only
    /// Home looked powered. In practice a near-black button reads as a hole
    /// punched in a bone or yellow shell — the two pale skins were the ones it
    /// suited least, and they are the ones whose real-world references had
    /// *light* buttons. The cap is moulded from the shell now, like the rest of
    /// the plastic; Home still reads as the lit one because it is the only thing
    /// on the chassis carrying a six-stop ramp and an inner disc.
    public var control: ChassisControl {
        switch self {
        // Stone, exactly as before.
        case .classic:
            ChassisControl(top: "#44403c", bottom: "#0c0a09", edge: "#a8a29e", glyph: "#ffffff")
        case .midnight:
            ChassisControl(top: "#3b3746", bottom: "#0b0a10", edge: "#8b86a3", glyph: "#ffffff")
        // Pale grey with a dark glyph — the original handheld's own d-pad.
        case .original:
            ChassisControl(top: "#c2c2ba", bottom: "#83837b", edge: "#5f5f59", glyph: "#262622")
        // Deep purple caps, matching the accent ramp and the orb.
        case .burgundy:
            ChassisControl(top: "#5b21b6", bottom: "#1e0a38", edge: "#a78bfa", glyph: "#ffffff")
        // Neutral grey — the blue cast the caps used to carry fought the
        // livery once the orb went red.
        case .riesling:
            ChassisControl(top: "#5a6068", bottom: "#14171c", edge: "#a7adb5", glyph: "#ffffff")
        case .vinhoVerde:
            ChassisControl(top: "#4B4F54", bottom: "#111316", edge: "#8A9096", glyph: "#ffffff")
        // Clear caps: the rgba stops are what makes the buttons read as
        // moulded from the same smoke plastic as the shell.
        case .glouglou:
            ChassisControl(top: "rgba(203,213,225,0.55)", bottom: "rgba(51,65,85,0.60)",
                           edge: "rgba(226,232,240,0.90)", glyph: "#0F172A")
        // The number key: dark grey with the brown cast of the brief.
        case .smartGrape:
            ChassisControl(top: "#4A4239", bottom: "#151210", edge: "#8A7B6B", glyph: "#ffffff")
        // Pale gold caps with a dark glyph, per the Blanc de Blancs precedent.
        case .champagne:
            ChassisControl(top: "#D8C48E", bottom: "#7A6535", edge: "#55431F", glyph: "#2E2410")
        // The holly-berry caps.
        case .christmas:
            ChassisControl(top: "#C93B3B", bottom: "#5C1010", edge: "#E88A8A", glyph: "#ffffff")
        }
    }

    /// Marquee phosphor. Period LED strips came in green, amber, red and blue,
    /// so this is the one part where a colour change is period-correct rather
    /// than merely decorative.
    public var marqueeText: Color {
        switch self {
        case .classic: Dex.green500
        case .midnight: Color(dexHex: "#c084fc")
        case .original: Color(dexHex: "#fbbf24")
        case .burgundy: Color(dexHex: "#f9a8d4")
        case .riesling: Dex.green500
        case .vinhoVerde: Color(dexHex: "#9BBC0F")
        case .glouglou: Color(dexHex: "#FB923C")
        case .smartGrape: Color(dexHex: "#FF9F0A")
        case .champagne: Color(dexHex: "#F2C14E")
        case .christmas: Color(dexHex: "#FF6B6B")
        }
    }

    /// The faint grid behind the phosphor, and the colour its letters are cut
    /// out of. One step deeper, so the strip still reads as glass over a grid.
    public var marqueeGrid: Color {
        switch self {
        case .classic: Dex.green
        case .midnight: Color(dexHex: "#a855f7")
        case .original: Color(dexHex: "#f59e0b")
        case .burgundy: Color(dexHex: "#ec4899")
        case .riesling: Color(dexHex: "#16a34a")
        case .vinhoVerde: Color(dexHex: "#8BAC0F")
        case .glouglou: Color(dexHex: "#F97316")
        case .smartGrape: Color(dexHex: "#E08600")
        case .champagne: Color(dexHex: "#D4A017")
        case .christmas: Color(dexHex: "#E03131")
        }
    }

    /// Hard drop shadow under each glyph on the strip — a very dark form of the
    /// phosphor, which is what makes the letters look lit rather than printed.
    public var marqueeShadow: Color {
        switch self {
        case .classic: Color(dexHex: "#082010")
        case .midnight: Color(dexHex: "#1e0b32")
        case .original: Color(dexHex: "#301a02")
        case .burgundy: Color(dexHex: "#3b0723")
        case .riesling: Color(dexHex: "#082010")
        case .vinhoVerde: Color(dexHex: "#0F380F")
        case .glouglou: Color(dexHex: "#33130A")
        case .smartGrape: Color(dexHex: "#331F04")
        case .champagne: Color(dexHex: "#33240A")
        case .christmas: Color(dexHex: "#240808")
        }
    }

    public var next: ChassisSkin {
        let all = ChassisSkin.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
}

#endif
