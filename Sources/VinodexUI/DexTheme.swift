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

    /// Stat-bar fills. Ported from the reference exactly, and named here rather
    /// than spelled inline in a `[String: String]` keyed on the bar's *label*
    /// (AUDIT **L33**) — that table was one authored rename away from silently
    /// painting every bar the BODY green.
    public static let statBody = green500
    public static let statAcid = Color(dexHex: "#eab308")
    public static let statTannin = red500
    public static let statAromatics = Color(dexHex: "#c084fc")
    public static let statColor = amber500
}

/// The painted-plastic tile livery: a filled face, a darker extrusion under it,
/// and the ink on top.
///
/// One table for both grids (AUDIT **L33**). The main menu spelled its four
/// faces as hex pairs at the call site, and the settings grid kept two parallel
/// six-row tables switched on the tile's **title string** — so a renamed tile
/// fell through to the ACCESS purple, silently, and neither table was reachable
/// from the other even though five of the ten colours were the same colour.
///
/// Both modes are declared for every livery. That is the point of hoisting
/// these: light mode was added to the settings grid and missed on the main
/// menu, because there was no one place that knew a tile face has two values.
/// Light runs the deeper cuts — a bright face washes out on the pale page.
enum DexTileLivery: Sendable {
    case violet
    case green
    case amber
    case red
    case orange
    case sky
    case emerald

    private var dark: (face: String, shadow: String) {
        switch self {
        case .violet: ("#a855f7", "#6b21a8")
        case .green: ("#22c55e", "#15803d")
        case .amber: ("#eab308", "#a16207")
        case .red: ("#ef4444", "#991b1b")
        case .orange: ("#f97316", "#9a3412")
        case .sky: ("#2ab5ff", "#136a99")
        case .emerald: ("#10b981", "#065f46")
        }
    }

    private var light: (face: String, shadow: String) {
        switch self {
        case .violet: ("#7e22ce", "#4c1d95")
        case .green: ("#15803d", "#0b4a24")
        case .amber: ("#b45309", "#7a3606")
        case .red: ("#b91c1c", "#7a1010")
        case .orange: ("#c2410c", "#7c2d12")
        case .sky: ("#1d6fa8", "#11486e")
        case .emerald: ("#047857", "#064e3b")
        }
    }

    func face(_ lcd: LcdMode) -> Color {
        Color(dexHex: lcd.isLight ? light.face : dark.face)
    }

    func shadow(_ lcd: LcdMode) -> Color {
        Color(dexHex: lcd.isLight ? light.shadow : dark.shadow)
    }

    /// White on every livery, in both modes — the faces are all deep enough to
    /// carry it. Declared rather than assumed so a future livery has somewhere
    /// to disagree. (TOOLS used dark-amber ink until 0.6.4, which made it the
    /// odd one out on the grid.)
    var ink: Color { .white }
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
    /// `islandBottomInset` against the screen housing. Computed — it follows
    /// `controlButton`, which follows `UIScale`.
    public static var islandStripMinHeight: CGFloat { islandTopInset + controlButton + islandBottomInset }
    public static let islandClearance: CGFloat = 138

    /// Whether this display has a notch or a Dynamic Island — i.e. whether
    /// `islandClearance` is holding a gap open for anything (AUDIT **L32**).
    ///
    /// Keyed off the **bottom** inset, and that is the whole subtlety. The
    /// obvious signal is `safeAreaInsets.top`, and it is wrong here: the app
    /// sets `.statusBarHidden()` (`VinodexApp`), which can collapse the top
    /// inset to zero *on cutout devices* — see the note on
    /// `islandStripMinHeight`. Keying the clearance off it would therefore
    /// close the gap on exactly the phones that need it open.
    ///
    /// The home indicator has no such trapdoor: nothing this app does hides
    /// it, and the device split is clean — every display with a cutout has one,
    /// and every home-button device (the SE class) has neither. So a zero
    /// bottom inset means a flat top edge, and the 138pt reservation is a hole
    /// held open for a cutout that does not exist.
    public static func hasDisplayCutout(bottomSafeArea: CGFloat) -> Bool {
        bottomSafeArea > 0
    }
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
    public static var ventStripHeight: CGFloat { 1.75 * rem * UIScale.current.factor }
    public static var ventDot: CGFloat { 0.5 * rem * UIScale.current.factor }   // w-2

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
    public static var footerHeight: CGFloat { footerTopInset + footerControl + chassisEdgeInset }
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
    public static var controlButton: CGFloat { footerControl }
    /// Computed, not stored: the chrome members follow `UIScale.current`
    /// (v0.5.8, F1), and a stored `let` would freeze whatever the factor was
    /// at first touch. Text sizes deliberately do not scale here — they have
    /// their own axis in `TextScale`.
    public static var footerControl: CGFloat { 4 * rem * UIScale.current.factor }
    public static let marqueeMaxWidth: CGFloat = 16.5 * rem
    public static let marqueeCorner: CGFloat = 0.8 * rem
    public static let marqueeInnerCorner: CGFloat = 0.6 * rem
    /// The banner matches the control buttons so the footer reads as one row.
    public static var marqueeHeight: CGFloat { footerControl }
    /// One size for every screen: the main screen's longer banner scrolls,
    /// so it does not need to shrink to fit. Trimmed from 1.45rem (v0.5.4)
    /// — at that size the strip read louder than the buttons beside it.
    public static let marqueeTextSize: CGFloat = 1.2 * rem

    /// Icon wells (v0.5.8, F1): the list-row well and the detail-hero well,
    /// scaled with the chrome so LARGE grows the pictures, not the words.
    public static var iconWell: CGFloat { 48 * UIScale.current.factor }
    public static var heroWell: CGFloat { 148 * UIScale.current.factor }

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

    /// The point size a nominal size actually draws at — floor and step applied.
    ///
    /// Public because three places outside `DexFont` need the same number: the
    /// marquee derives its glyph gap from it, and anything measuring a label has
    /// to measure the size that was drawn. Every one of them used to re-derive
    /// `size * TextScale.current.factor` by hand, which stopped being correct
    /// the moment a floor existed.
    public static func resolvedSize(_ nominal: CGFloat) -> CGFloat {
        CGFloat(TypeScale.resolve(nominal: Double(nominal), step: TextScale.current))
    }

    /// Pixel display face — titles, category labels, chips.
    ///
    /// `fixedSize:`, not `size:`, and that one token is half of AUDIT H11.
    /// `Font.custom(_:size:)` auto-scales with the system text size while
    /// `Font.system(size:...)` below does not, so the two branches of this
    /// function used to have *different* accessibility behaviour — a failed font
    /// registration silently froze the app's type. Both are fixed now, so the
    /// fallback changes the typeface and nothing else, and `TextScale` is the
    /// single axis. See VinodexCore/TypeScale.swift.
    public static func retro(_ size: CGFloat) -> Font {
        let pt = resolvedSize(size)
        return retroAvailable
            ? .custom(names.retro, fixedSize: pt)
            : .system(size: pt, weight: .bold, design: .monospaced)
    }

    /// CRT terminal face — body copy and readouts.
    public static func mono(_ size: CGFloat) -> Font {
        let pt = resolvedSize(size)
        return monoAvailable
            ? .custom(names.mono, fixedSize: pt)
            : .system(size: pt, design: .monospaced)
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
enum DexResources {
    static func url(named name: String, ext: String, subdirectory: String? = nil) -> URL? {
        if let subdirectory,
           let hit = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            return hit
        }
        return Bundle.module.url(forResource: name, withExtension: ext)
    }
}

// `TextScale` moved to VinodexCore/TypeScale.swift in 0.6.4 (AUDIT H11), along
// with the size resolver it now goes through. It is re-exported by the
// `import VinodexCore` every file here already carries.

#endif
