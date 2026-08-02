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
    /// 8, down from 18 (0.6.6, E3). The orb and the lamp cluster move *up into
    /// the notch band* in this batch, which means the inset above them is no
    /// longer breathing room — it is the distance the hardware cutout starts
    /// at. The Dynamic Island's own top edge sits ~11pt down; anything smaller
    /// than that up here is chassis nobody sees.
    ///
    /// The floor is load-bearing: the display's 55pt corner arc cuts
    /// `55 - sqrt(55² - (55-h)²)` off each side at height `h`, which at 8pt is
    /// ~26pt — exactly `cornerGuardH`. The controls survive it because they are
    /// *circles*: the widest point of the orb sits half a slot lower, where the
    /// arc has closed to ~2pt. Going below 8 starts cutting the button's actual
    /// edge rather than the empty corner of its bounding box.
    public static let islandTopInset: CGFloat = 8
    /// The glass orb, up in the notch band since 0.6.6 (E3) and no longer one
    /// of the `controlButton`-sized parts.
    ///
    /// It broke the "one diameter for every physical control" rule by being
    /// the biggest thing on the chassis while doing the least — a decorative
    /// lamp at button size reads as a button nobody labelled, and at 64pt it
    /// was also what forced the island strip to 84pt and charged the LCD for
    /// it. 55% of a control is a bead: unmistakably a lamp, and small enough to
    /// sit beside the cutout rather than under it.
    public static var islandOrb: CGFloat { controlButton * 0.55 }
    /// The row the orb and the lamp cluster share, level with the cutout.
    ///
    /// Floored at 44 rather than sized to the orb: the orb is the flip
    /// gesture's target (see `DeviceChassis.lcdOrb`), and shrinking a control's
    /// art is not a licence to shrink its touch area below the platform
    /// minimum. The extra points are padding around the bead, not more bead.
    public static var islandSlot: CGFloat { max(islandOrb + 8, 44) }
    /// The band below the cutout that carries the two red housing lamps
    /// (0.6.6, D1). They used to take the screen housing's own top margin;
    /// deleting the title lip freed the bare chassis the mockup drew them on.
    public static let islandLampRow: CGFloat = 10
    /// Floor for the island strip: the inset above, the notch-level row, the
    /// lamp band, then the small `islandBottomInset` against the screen
    /// housing. Computed — it follows `controlButton`, which follows `UIScale`.
    ///
    /// 64 at SMALL, down from 84 (0.6.6, E3). This number is charged straight
    /// to the LCD on any device whose real top inset is smaller than it, which
    /// is every one of them — a Dynamic Island reports 59. Sizing the strip to
    /// seat a 64pt orb was the single most expensive decision in the chassis.
    public static var islandStripMinHeight: CGFloat {
        islandTopInset + islandSlot + islandLampRow + islandBottomInset
    }
    public static let islandClearance: CGFloat = 138
    /// Matches `footerPaddingH` so the orb sits directly above the Back button
    /// and the cog above Home — the four chassis controls share two columns.
    public static let islandFlankPaddingH: CGFloat = cornerGuardH
    /// The white housing's margin above the LCD.
    ///
    /// 10, down from a full rem (0.6.6, D1). It was sized to seat the two red
    /// housing lamps, which had nowhere else to go while the title lip occupied
    /// the bare chassis above; the lip is gone and the lamps went with it, so
    /// what is left only has to read as moulding. Every point of it was LCD.
    public static let bezelTopMargin: CGFloat = 10
    /// Spacing between the three status lamps. Widened with the lamps
    /// themselves (0.6.6, E3) so the trio still reads as three lights rather
    /// than one blob now that each is bigger.
    public static let statusDotSpacing: CGFloat = 0.28 * rem
    /// The three lamps in the strip's right corner, level with the cutout.
    /// Bigger since 0.6.6 (E3) — they were sized off the old oversized orb and
    /// came out as specks; now they are sized to be legible at arm's length.
    public static var islandStatusDot: CGFloat { max(islandOrb * 0.38, 13) }
    // `statusDotsGap` and `statusDotsRise` retired in 0.6.5 (C1): both measured
    // the cluster's placement relative to the orb, and the cluster no longer
    // sits beside the orb — it has the opposite corner of the strip to itself.
    public static let titleSize: CGFloat = 0.9375 * rem

    /// Screen housing
    public static let screenPanelCorner: CGFloat = 2 * rem
    /// Thinner grey edge, so more of the panel reads as the white/graphite
    /// moulding rather than outline. The stroke is inset, so what it gives up
    /// the panel colour takes.
    public static let screenPanelBorder: CGFloat = 4
    public static let screenPanelInset: CGFloat = 0.5 * rem   // m-2
    /// The housing's keyed corner (0.6.5, C2): the bottom-left is a straight
    /// diagonal cut rather than an arc, the way a moulded bezel is keyed so the
    /// part only seats one way round. Sized a little larger than
    /// `screenPanelCorner` — a chamfer the same size as the arcs beside it
    /// reads as a rounding error rather than as a deliberate cut.
    public static let screenPanelChamfer: CGFloat = 2.25 * rem
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
    /// Two control rows since 0.6.5 — Back sits under Home — so the band is
    /// `bandHeight` tall rather than one control.
    public static var footerHeight: CGFloat { footerTopInset + bandHeight + chassisEdgeInset }
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
    /// Taller than the controls flanking it since 0.6.5 (B1): the marquee is
    /// the band's centrepiece now, not a strip squeezed between two buttons,
    /// and a panel that matched the button diameter read as the smallest thing
    /// in the band rather than the largest. Taller again in 0.6.6 (C1) — the
    /// diagonal cluster gave the band back the height to spend on it.
    public static var marqueeHeight: CGFloat { bandControl * 1.32 }
    /// How far the strip's contents fade out at each end (0.6.6, C2).
    ///
    /// The panel is a window onto a longer loop, so text *has* to leave it —
    /// the complaint was never that it scrolled but that it was guillotined,
    /// with half a glyph parked against a hard edge at both ends. A gradient
    /// mask makes the same motion read as letters passing behind the housing.
    /// Sized off the glyph cell rather than fixed, so one whole character is
    /// always mid-fade at either end.
    public static var marqueeFade: CGFloat { marqueeTextSize * TextScale.current.factor * 1.15 }
    /// One size for every screen: the main screen's longer banner scrolls,
    /// so it does not need to shrink to fit. Trimmed from 1.45rem (v0.5.4)
    /// — at that size the strip read louder than the buttons beside it.
    public static let marqueeTextSize: CGFloat = 1.2 * rem

    /// Button band (0.6.5, A/B)
    ///
    /// Four physical controls — User, Settings, Home, Back — around the marquee
    /// panel, in two rows: U / S / H across the top and B under H.
    ///
    /// `bandControl` deliberately breaks the "one diameter for every control on
    /// the chassis" rule the island strip still follows. The marquee has to
    /// hold roughly half the chassis width to read as the centrepiece, and four
    /// full `footerControl` circles plus their gaps do not leave that much on a
    /// compact phone. They remain one size *as a group*, which is what the rule
    /// was actually protecting against; `bandControlSmall` is the one exception,
    /// and the mockup calls Settings out as the small button on purpose.
    public static var bandControl: CGFloat { footerControl * 0.84 }
    public static var bandControlSmall: CGFloat { bandControl * 0.72 }
    /// Gap between the band's columns.
    public static let bandSpacing: CGFloat = 10

    // MARK: The nav cluster (0.6.6, B1/F3)
    //
    // Settings, Home and Back as a **staggered triangle** rather than the
    // vertical Home-over-Back pair 0.6.5 built. 0.6.5's A2 asked for the
    // column; 0.6.6's B1 reverses it, and reversing it is worth doing because
    // the column was the most expensive shape available: two full diameters
    // plus a gap of band height, all of it charged to the LCD.
    //
    // The three are packed to mutual near-tangency — every pair sits ~0.06
    // diameters apart — which is the tightest a cluster can be and still read
    // as three separate controls. Home takes the top-right, Back is offset
    // down-and-inward from it (the diagonal the mockup draws, and the corner
    // nearest the thumb), and Settings closes the triangle below. That last
    // placement is also F3's answer: the cog is *inside* the group now instead
    // of floating above its midline.
    //
    // The geometry is expressed as fractions of `bandControl` so the whole
    // cluster scales with `UIScale` in one piece. Cluster-local origins, all
    // measured from its top-leading corner.

    /// Home's leading edge — the cluster's right-hand column.
    public static var bandClusterHomeX: CGFloat { bandControl * 0.95 }
    /// Back's top edge. Back's leading edge is the cluster's own (x = 0).
    public static var bandClusterBackY: CGFloat { bandControl * 0.475 }
    /// Settings, tucked under Home and inboard of it, closing the triangle.
    public static var bandClusterSettingsX: CGFloat { bandControl * 0.95 }
    public static var bandClusterSettingsY: CGFloat { bandControl * 1.05 }
    public static var bandClusterWidth: CGFloat { bandControl * 1.95 }
    public static var bandClusterHeight: CGFloat { bandControl * 1.77 }

    /// The band's own height. The cluster is the tallest thing in it — the
    /// marquee column and the lone User button both fit inside this.
    public static var bandHeight: CGFloat { bandClusterHeight }

    /// The drop shadow under every band control (0.6.6, B3).
    ///
    /// Was `0.6 / radius 6 / y 8`, which is a hard black plate under each
    /// circle rather than a shadow — at the band's scale that offset is most of
    /// a button's radius, so every control looked stuck on rather than set in.
    /// One set of tokens so the cog and the three moulded caps cannot drift.
    public static let bandShadowOpacity: Double = 0.28
    public static let bandShadowRadius: CGFloat = 4
    public static let bandShadowY: CGFloat = 3

    /// The two indicator pills above the marquee panel (0.6.5, B2). Wider
    /// since 0.6.6 (C3): at 18pt they read as dashes beside a panel that has
    /// since grown twice.
    public static let bandPillWidth: CGFloat = 30
    public static let bandPillHeight: CGFloat = 8
    public static let bandPillSpacing: CGFloat = 8
    /// Gap from the pills down to the panel they belong to. Small — they have
    /// to read as lamps *on* the marquee's housing, not as their own row.
    public static let bandPillGap: CGFloat = 5

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
public enum DexResources {
    public static func url(named name: String, ext: String, subdirectory: String? = nil) -> URL? {
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

    public static let storageKey = "lcdMode"

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
        // The DMG's lightest tone; everything darker falls out of the
        // grayscale multiply.
        case .gruenerBoy: Color(dexHex: "#9BBC0F")
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
        case .gruenerBoy: "gamecontroller.fill"
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
        case .gruenerBoy: Color(dexHex: "#E6EBCF")
        }
    }

    /// Primary text on that ground. VINOFD's is deliberately *not* white:
    /// the light-blue glow is what says vacuum-fluorescent rather than BSOD.
    public var text: Color {
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
    public var accent: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.green
        case .light: Color(dexHex: "#1B6B3A")
        case .vintage: Color(dexHex: "#1A1A16")
        case .wineOS: Color(dexHex: "#1D3E9E")
        // VFD electric cyan — one register brighter than the text glow.
        case .blueScreen: Color(dexHex: "#7DF9FF")
        case .starTrek: Color(dexHex: "#C983E8")
        case .gruenerBoy: Color(dexHex: "#2F3A1C")
        }
    }

    /// Body copy inside INFO blocks — mint on black, near-black on paper.
    public var bodyText: Color {
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
    public var heroWash: Color {
        switch self {
        case .dark, .amber, .terminal: Color(dexHex: "#14532d").opacity(0.1)
        case .light: Color(dexHex: "#1B6B3A").opacity(0.07)
        case .vintage: Color.black.opacity(0.06)
        case .wineOS: Color(dexHex: "#1D3E9E").opacity(0.07)
        case .blueScreen: Color.white.opacity(0.06)
        case .starTrek: Color(dexHex: "#C983E8").opacity(0.08)
        case .gruenerBoy: Color.black.opacity(0.06)
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
        case .gruenerBoy: Color(dexHex: "#3A4224")
        }
    }

    /// Filled-button ground (SAVE and friends) when *not* active.
    public var buttonWell: Color {
        switch self {
        case .dark, .amber, .terminal, .starTrek: .black.opacity(0.35)
        case .light, .vintage, .wineOS, .gruenerBoy: .white
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
        case .gruenerBoy: Color(dexHex: "#DDE3C2")
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
        case .gruenerBoy: Color(dexHex: "#EFF2DE")
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
        case .gruenerBoy: Color(dexHex: "#7A8258")
        }
    }

    /// Secondary text — captions, counts, placeholders.
    public var subtext: Color {
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
    public var well: Color {
        switch self {
        case .dark, .amber, .terminal, .starTrek: .black
        case .light, .vintage, .wineOS: Color(dexHex: "#FFFFFF")
        case .blueScreen: Color(dexHex: "#0A1690")
        case .gruenerBoy: Color(dexHex: "#F4F6E8")
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
        case .gruenerBoy: Color(dexHex: "#939B78")
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
        case .light, .vintage, .wineOS, .gruenerBoy: .white
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
        case .gruenerBoy: Color(dexHex: "#7A8258")
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
    public var controlAccent: ChassisAccent {
        switch self {
        // The house amber, exactly what the classic chassis always wore.
        case .dark:
            ChassisAccent(pale: "#fef3c7", light: "#fde68a", bright: "#fbbf24",
                          mid: "#f59e0b", edge: "#b45309", ink: "#78350f")
        case .light:
            ChassisAccent(pale: "#E8F5EC", light: "#BFE3CB", bright: "#4FA76F",
                          mid: "#1B6B3A", edge: "#0F4224", ink: "#0B2E18")
        case .vintage:
            ChassisAccent(pale: "#F2F2EA", light: "#D8D8CC", bright: "#8A8A7C",
                          mid: "#4A4A40", edge: "#26261F", ink: "#111110")
        case .amber:
            ChassisAccent(pale: "#FFF4D6", light: "#FFE29A", bright: "#FFB300",
                          mid: "#D18F00", edge: "#7A5200", ink: "#3A2600")
        case .wineOS:
            ChassisAccent(pale: "#EAF0FA", light: "#C2D2EC", bright: "#5B7FD4",
                          mid: "#1D3E9E", edge: "#0E2258", ink: "#0A1A40")
        case .terminal:
            ChassisAccent(pale: "#E8FFE8", light: "#A8FFA8", bright: "#4DFF4D",
                          mid: "#1FBF3F", edge: "#0A5A1E", ink: "#06300F")
        case .blueScreen:
            ChassisAccent(pale: "#E4F7FF", light: "#A6DBFF", bright: "#7DF9FF",
                          mid: "#2FA8D8", edge: "#0A4A70", ink: "#062A40")
        case .starTrek:
            ChassisAccent(pale: "#FFE9C7", light: "#FFC98A", bright: "#FFA94D",
                          mid: "#E08A20", edge: "#7A4A08", ink: "#341F04")
        case .gruenerBoy:
            ChassisAccent(pale: "#E6EBCF", light: "#C2CE9A", bright: "#8BAC0F",
                          mid: "#566A18", edge: "#24300C", ink: "#0F1A0A")
        }
    }

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
    public var globeTint: Color? {
        switch self {
        case .dark: nil
        // LIGHT inverts the texture instead (see `invertsGlobeTexture`); the
        // tint stays neutral so the inversion reads clean.
        case .light: Color.white
        case .vintage: Color(dexHex: "#C6CFB2")
        case .amber: Color(dexHex: "#FFD27A")
        case .wineOS: Color(dexHex: "#C2D2EC")
        case .terminal: Color(dexHex: "#A8FFA8")
        // VINOFD: the vacuum-fluorescent light blue.
        case .blueScreen: Color(dexHex: "#A6DBFF")
        // L-WINES: the console's accent purple.
        case .starTrek: Color(dexHex: "#C983E8")
        case .gruenerBoy: Color(dexHex: "#C2CE9A")
        }
    }

    /// LIGHT mode's globe is the *inverted-colour* globe (0.6.4, F1): the map
    /// texture runs through a colour inversion before it reaches the sphere,
    /// so dark oceans become paper and the globe reads as printed rather than
    /// glowing. Only LIGHT — the other pale modes keep the normal texture
    /// under their own tints.
    public var invertsGlobeTexture: Bool { self == .light }

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
    /// Atomic-purple clear shell — the second translucent colourway. Grape-
    /// juice gloss for everything powered, the guts faintly visible through it.
    case nouveau = "NOUVEAU"
    /// Walnut woodgrain deck, cream faceplate, brass for the powered parts.
    case oaked = "OAKED"
    /// Glow-in-the-dark pale luminous green with a softly glowing rim.
    case nocturne = "NOCTURNE"
    /// Brushed aluminium: mirror highlights, crisp dark seams.
    case steel = "STEEL"
    /// Rose-pink shell with a pale blush faceplate and pearl-pink lights —
    /// unapologetically pink and girly (v0.6, D1).
    case blush = "BLUSH"
    /// The DualShock 2 livery (0.6.5, item 9): matte charcoal moulding, a
    /// darker console-grey faceplate, and the four face-button colours doing
    /// all the talking — lights run triangle/circle/cross, the powered parts
    /// run the cross's blue. Subtle on purpose; the reference hardware was.
    case psvino = "PSVINO"

    public static let storageKey = "chassisSkin"

    public var id: String { rawValue }

    /// Whether the shell is see-through — `DeviceChassis`'s cue to mount the
    /// mock internals behind it. A flag rather than sniffing alpha out of a
    /// `Color`, which SwiftUI does not expose anyway.
    public var isTranslucent: Bool { self == .glouglou || self == .nouveau }

    /// A soft halo around the screen housing — NOCTURNE's glow-in-the-dark
    /// charge. Nil everywhere else; the chassis applies it as a shadow, so
    /// an absent glow costs nothing.
    public var rimGlow: Color? {
        self == .nocturne ? Color(dexHex: "#A8FF96") : nil
    }

    /// The globe screen's sphere tint (0.6.2, F1) — every skin sees the world
    /// through its own colour. Pale on purpose: the tint multiplies over the
    /// map texture, so a saturated dark here would swallow the coastlines.
    public var globeTint: Color {
        switch self {
        case .classic: Color(dexHex: "#B8FFD6")
        case .midnight: Color(dexHex: "#D6B8FF")
        case .original: Color(dexHex: "#FFEDBB")
        case .burgundy: Color(dexHex: "#E4C0FF")
        case .riesling: Color(dexHex: "#FFF4A8")
        case .vinhoVerde: Color(dexHex: "#D9FFB8")
        case .glouglou: Color(dexHex: "#FFD9B0")
        case .smartGrape: Color(dexHex: "#FFCB79")
        case .champagne: Color(dexHex: "#FFF0C8")
        case .christmas: Color(dexHex: "#FFC2C2")
        case .nouveau: Color(dexHex: "#DDBBFF")
        case .oaked: Color(dexHex: "#FFDDAF")
        case .nocturne: Color(dexHex: "#CCFFB8")
        case .steel: Color(dexHex: "#CDE7FF")
        case .blush: Color(dexHex: "#FFCCDD")
        // Console-boot blue — the cross button, paled for the multiply.
        case .psvino: Color(dexHex: "#BBD4F5")
        }
    }

    /// What sits behind the shell: the shell itself for opaque skins, a
    /// near-black base under GLOUGLOU so the smoke plastic has something to be
    /// smoke over.
    public var underlay: Color {
        isTranslucent ? Color(dexHex: "#14161A") : body
    }

    /// The clear back moulding, laid over the internals — a touch lighter than
    /// the front shell, since the back of a clear device is one moulding
    /// further from the boards. Meaningful only for translucent skins.
    /// RETROVIN's back is its own atomic purple (v0.5.9, A2): the plate used
    /// one hardcoded grey smoke, so the purple shell turned grey from behind.
    public var backSmoke: Color {
        self == .nouveau
            ? Color(dexHex: "rgba(147,51,234,0.34)")
            : Color(dexHex: "rgba(204,216,224,0.34)")
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
        case .burgundy: "BURGUNDY"
        // Renamed from ELECTRIC RIESLING (0.6.x) — label only, per the note
        // above; the yellow Walkman shell suits Jura's yellow wine as well.
        case .riesling: "VIN JAUNE"
        // Renamed labels only — the raw values are the persisted vocabulary
        // and stay put, per the note above. "VINHO VERDE" moved houses in
        // two steps: the forest-green skin became BOX WINE in 0.5.1, which
        // freed the name for the glow-green skin in 0.5.4.
        case .vinhoVerde: "BOX WINE"
        case .glouglou: "EMPTY BOTTLE"
        case .smartGrape: "SMART GRAPE"
        case .champagne: "CHAMPAGNE GOLD"
        case .christmas: "WINE XMAS"
        // Renamed from NOUVEAU (v0.5.9, A1) — label only, per the note above.
        case .nouveau: "RETROVIN"
        case .oaked: "OAKED"
        case .nocturne: "VINHO VERDE"
        case .steel: "STAINLESS STEEL"
        case .blush: "BLUSH"
        case .psvino: "PSVINO"
        }
    }

    /// A tileable pixel-art pattern drawn over the shell colour, or nil for a
    /// plain moulding. WINE XMAS wraps the chassis in wrapping paper, OAKED
    /// in walnut grain, STEEL in brushed aluminium; the pattern sits under
    /// the panel and footer wash like any other body.
    public var bodyPatternAsset: String? {
        switch self {
        case .christmas: "xmas-wrap"
        case .oaked: "oak-grain"
        case .steel: "steel-brush"
        default: nil
        }
    }

    /// Emblem glyph — the picker tile carries it the way screen-mode tiles
    /// carry theirs, and the back plate wears it as an enamel badge.
    public var symbol: String {
        switch self {
        case .classic: "gamecontroller.fill"
        case .midnight: "moon.fill"
        case .original: "sparkles"
        case .burgundy: "diamond.fill"
        case .riesling: "bolt.fill"
        case .vinhoVerde: "shippingbox.fill"
        case .glouglou: "wineglass.empty"
        case .smartGrape: "plus.forwardslash.minus"
        case .champagne: "party.popper.fill"
        case .christmas: "gift.fill"
        case .nouveau: "cpu.fill"
        case .oaked: "tree.fill"
        case .nocturne: "moon.zzz.fill"
        case .steel: "gearshape.2.fill"
        case .blush: "heart.fill"
        case .psvino: "playstation.logo"
        }
    }

    /// The three status lamps, left to right, as (fill, border) pairs — a
    /// unique trio per skin (v0.5.6, generalising WINE XMAS's all-red set,
    /// which used to be the one override on a fixed red/yellow/green).
    public var statusLights: [(fill: Color, border: Color)] {
        func trio(_ a: (String, String), _ b: (String, String), _ c: (String, String)) -> [(fill: Color, border: Color)] {
            [a, b, c].map { (Color(dexHex: $0.0), Color(dexHex: $0.1)) }
        }
        switch self {
        // The classic trio, exactly as it always was.
        case .classic:
            return trio(("#dc2626", "#991b1b"), ("#facc15", "#ca8a04"), ("#22c55e", "#15803d"))
        case .midnight:
            return trio(("#d8b4fe", "#7c3aed"), ("#a855f7", "#6b21a8"), ("#7c3aed", "#4c1d95"))
        case .original:
            return trio(("#ffd76e", "#f0b429"), ("#e8e0cc", "#9a9a93"), ("#d4a017", "#8a6820"))
        case .burgundy:
            return trio(("#f9a8d4", "#be185d"), ("#c084fc", "#7c3aed"), ("#7c3aed", "#4c1d95"))
        case .riesling:
            return trio(("#ef4444", "#b91c1c"), ("#facc15", "#ca8a04"), ("#4b5563", "#1f2937"))
        case .vinhoVerde:
            return trio(("#9BBC0F", "#6a8a0a"), ("#8BAC0F", "#5a740a"), ("#306230", "#0F380F"))
        case .glouglou:
            return trio(("#FDBA74", "#EA580C"), ("#FB923C", "#C2410C"), ("#F97316", "#9A3412"))
        case .smartGrape:
            return trio(("#FF9F0A", "#C97800"), ("#FFD60A", "#B8860B"), ("#8E8E93", "#48484A"))
        case .champagne:
            return trio(("#F5D97E", "#D4A017"), ("#E3BC5F", "#8A6820"), ("#FDF6E3", "#C8B87A"))
        // Holly-berry fairy lights, all three.
        case .christmas:
            return trio(("#FF4D4D", "#8F1414"), ("#FF4D4D", "#8F1414"), ("#FF4D4D", "#8F1414"))
        case .nouveau:
            return trio(("#E9D5FF", "#A855F7"), ("#C084FC", "#7C3AED"), ("#A855F7", "#6B21A8"))
        case .oaked:
            return trio(("#E8C15A", "#B5892E"), ("#D9AE55", "#8A6820"), ("#B5892E", "#7A5A14"))
        case .nocturne:
            return trio(("#B9FFAB", "#57D63E"), ("#8DF06A", "#2E8A20"), ("#57D63E", "#1E6A14"))
        case .steel:
            return trio(("#E8F1FF", "#9FB8D8"), ("#C7CBD1", "#6B7078"), ("#9FD4FF", "#5FA8E8"))
        // Pearl-pink fairy trio, light to deep — and the range widened in
        // 0.6.6 (E3). The three lamps grew in this batch, and at the old
        // spread (#FDA4AF / #F9A8D4 / #F472B6, three pinks within a few
        // percent of one luminance) that just made one flat pink smear three
        // times as obvious. These lamps carry no state — see
        // `DeviceChassis.statusDots` — so nothing is *lost* by a tight trio,
        // but a device with three indistinguishable indicators reads as
        // broken, and every other skin's trio steps.
        case .blush:
            return trio(("#FFE0E6", "#E11D48"), ("#F9A8D4", "#DB2777"), ("#D6296B", "#7A0B36"))
        // Triangle, circle, cross — the face buttons as indicator lamps.
        case .psvino:
            return trio(("#3AC4B4", "#0E7A6E"), ("#F0435C", "#8F0E20"), ("#6FA3E8", "#1B4470"))
        }
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
        // Atomic-purple smoke — translucent, like GLOUGLOU; see `underlay`.
        case .nouveau: Color(dexHex: "rgba(147,51,234,0.42)")
        // The walnut base the grain pattern sits over.
        case .oaked: Color(dexHex: "#5C4028")
        case .nocturne: Color(dexHex: "#C9F2BE")
        // The aluminium base the brush pattern sits over.
        case .steel: Color(dexHex: "#C7CBD1")
        // Soft rose-pink moulding.
        case .blush: Color(dexHex: "#EEA7B6")
        // DualShock matte charcoal — near-black with the plastic's warmth.
        case .psvino: Color(dexHex: "#232427")
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
        case .nouveau: Color(dexHex: "rgba(147,51,234,0.30)")
        // No wash at all (v0.5.9, A4). 0.5.8's frosted-pan fix swapped the
        // translucent wash for a solid deeper walnut, which traded the haze
        // for a solid bar — still a bar. The walnut grain runs uninterrupted
        // behind the footer now; the buttons sit directly on the deck.
        case .oaked: Color.clear
        case .nocturne: Color(dexHex: "#C9F2BE").opacity(0.75)
        case .steel: Color(dexHex: "#B8BCC2").opacity(0.8)
        case .blush: Color(dexHex: "#EEA7B6").opacity(0.75)
        case .psvino: Color(dexHex: "#232427").opacity(0.75)
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
        case .nouveau: Color(dexHex: "rgba(216,180,254,0.50)")
        // The cream faceplate against the walnut deck.
        case .oaked: Color(dexHex: "#F2E8D5")
        case .nocturne: Color(dexHex: "#E9FBE0")
        case .steel: Color(dexHex: "#DDE0E4")
        // The pale blush faceplate against the rose shell.
        case .blush: Color(dexHex: "#FBE9EC")
        // Console grey — the PS2's own two-tone: charcoal shell, grey deck.
        case .psvino: Color(dexHex: "#3B3C41")
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
        case .nouveau: Color(dexHex: "rgba(233,213,255,0.90)")
        // A hint of brass around the cream.
        case .oaked: Color(dexHex: "#B5892E")
        case .nocturne: Color(dexHex: "#8FCB7C")
        case .steel: Color(dexHex: "#6B7078")
        case .blush: Color(dexHex: "#D2718A")
        case .psvino: Color(dexHex: "#141517")
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
        // Opaque over the internals, like GLOUGLOU's.
        case .nouveau: Color(dexHex: "#7C3AED")
        case .oaked: Color(dexHex: "#8A6B45")
        case .nocturne: Color(dexHex: "#8FCB7C")
        case .steel: Color(dexHex: "#6B7078")
        case .blush: Color(dexHex: "#C8879A")
        case .psvino: Color(dexHex: "#55575E")
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
        // Holly red, completing the set: caps, Home, lamps and orb all run
        // red on the wrapping paper (was fairy-light gold through 0.5.3).
        case .christmas: Color(dexHex: "#FF4D4D")
        // Grape juice under gloss.
        case .nouveau: Color(dexHex: "#A855F7")
        // A polished chestnut knob on the walnut (v0.5.8, C1 — was brass).
        // Lighter than the #5C4028 body so it still reads as a lamp.
        case .oaked: Color(dexHex: "#B06A32")
        // The one part that is *always* charged.
        case .nocturne: Color(dexHex: "#7CFC9A")
        // Ice on silver.
        case .steel: Color(dexHex: "#E8F1FF")
        // A pearl-pink bead — the one saturated light on the pastel shell.
        case .blush: Color(dexHex: "#FF7FA8")
        // The analog-stick LED: cross-button blue on the charcoal.
        case .psvino: Color(dexHex: "#5B93D8")
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
        case .christmas: Color(dexHex: "#A61E1E")
        case .nouveau: Color(dexHex: "#7C3AED")
        case .oaked: Color(dexHex: "#7A4218")
        case .nocturne: Color(dexHex: "#3EE06C")
        case .steel: Color(dexHex: "#9FB8D8")
        case .blush: Color(dexHex: "#E1447E")
        case .psvino: Color(dexHex: "#2E6DB4")
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
        // Glossy grape juice — the whole powered set runs one purple.
        case .nouveau:
            ChassisAccent(pale: "#F3E8FF", light: "#D8B4FE", bright: "#A855F7",
                          mid: "#7C3AED", edge: "#4C1D95", ink: "#2E1065")
        // Polished brass on the cream faceplate.
        case .oaked:
            ChassisAccent(pale: "#F8EFD8", light: "#EFD9A0", bright: "#D9AE55",
                          mid: "#B5892E", edge: "#7A5A14", ink: "#3D2B05")
        // The charged phosphor itself, lit.
        case .nocturne:
            ChassisAccent(pale: "#EFFFE8", light: "#C9F9B8", bright: "#8DF06A",
                          mid: "#57D63E", edge: "#2E8A20", ink: "#0F3D08")
        // Cool steel-blue — powered, but restrained like the livery.
        case .steel:
            ChassisAccent(pale: "#F2F6FA", light: "#D7DEE6", bright: "#AEB9C6",
                          mid: "#7E8A98", edge: "#454C56", ink: "#14181D")
        // Hot-pink ramp on the pastel shell — the powered parts get the
        // saturation the moulding deliberately holds back.
        case .blush:
            ChassisAccent(pale: "#FFF1F4", light: "#FBCFE0", bright: "#F472B6",
                          mid: "#DB2777", edge: "#9D174D", ink: "#500724")
        // Cross-button blue, lit — one restrained colour on the matte black,
        // the way the console itself wore it.
        case .psvino:
            ChassisAccent(pale: "#E3EEFA", light: "#B9D2F0", bright: "#5B93D8",
                          mid: "#2E6DB4", edge: "#173D6B", ink: "#0A1F38")
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
        // Clear purple caps, moulded from the same smoke as the shell.
        case .nouveau:
            ChassisControl(top: "rgba(216,180,254,0.55)", bottom: "rgba(76,29,149,0.60)",
                           edge: "rgba(233,213,255,0.90)", glyph: "#2E1065")
        // Walnut caps with a cream glyph, like inlay.
        case .oaked:
            ChassisControl(top: "#7A5A3A", bottom: "#2E2014", edge: "#A8865E", glyph: "#F2E8D5")
        // Moulded from the luminous shell, one register deeper.
        case .nocturne:
            ChassisControl(top: "#A9D89A", bottom: "#4E7A42", edge: "#6FA75E", glyph: "#123B0C")
        // Machined caps with a dark glyph, per the Blanc de Blancs precedent.
        case .steel:
            ChassisControl(top: "#B9BEC6", bottom: "#5E646C", edge: "#3E434B", glyph: "#14181D")
        // Pink caps one register deeper than the shell, dark glyph like the
        // other pale skins.
        case .blush:
            ChassisControl(top: "#F5BBC9", bottom: "#C97F94", edge: "#8F4A5E", glyph: "#4A1220")
        // The DualShock's own grey-black buttons.
        case .psvino:
            ChassisControl(top: "#3A3B40", bottom: "#101114", edge: "#6A6C72", glyph: "#ffffff")
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
        case .nouveau: Color(dexHex: "#C084FC")
        case .oaked: Color(dexHex: "#FFB84D")
        case .nocturne: Color(dexHex: "#86FF7E")
        case .steel: Color(dexHex: "#9FD4FF")
        // Pink phosphor — period LED strips never came in pink, but this is
        // the one skin allowed to care more about the look than the period.
        case .blush: Color(dexHex: "#FF9EC0")
        // Boot-screen blue phosphor.
        case .psvino: Color(dexHex: "#7DB2F0")
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
        case .nouveau: Color(dexHex: "#A855F7")
        case .oaked: Color(dexHex: "#E69A28")
        case .nocturne: Color(dexHex: "#57D63E")
        case .steel: Color(dexHex: "#5FA8E8")
        case .blush: Color(dexHex: "#F472B6")
        case .psvino: Color(dexHex: "#2E6DB4")
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
        case .nouveau: Color(dexHex: "#22083B")
        case .oaked: Color(dexHex: "#33200A")
        case .nocturne: Color(dexHex: "#0E2E0C")
        case .steel: Color(dexHex: "#0A1A2A")
        case .blush: Color(dexHex: "#3B0A1E")
        case .psvino: Color(dexHex: "#08182E")
        }
    }

    public var next: ChassisSkin {
        let all = ChassisSkin.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
}

#endif
