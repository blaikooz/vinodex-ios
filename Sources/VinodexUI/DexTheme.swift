#if canImport(SwiftUI)
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
    public static let deviceCorner: CGFloat = 55
    public static let chassisBorderInset: CGFloat = 2
    public static let chassisBorder: CGFloat = 3

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
    public static let islandStripMinHeight: CGFloat = 55
    public static let islandClearance: CGFloat = 138
    public static let islandFlankPaddingH: CGFloat = 0.5 * rem
    /// Pulls flank content in toward the cutout rather than the screen edges.
    /// Small on purpose: the orb and status lights sit closer to the island,
    /// which reads as deliberate rather than stranded at the corner.
    public static let islandFlankInnerGap: CGFloat = 0.125 * rem
    public static let bezelTopMargin: CGFloat = 0.5 * rem
    public static let lcdOrb: CGFloat = 1.75 * rem
    public static let statusDot: CGFloat = 0.5 * rem
    public static let titleSize: CGFloat = 0.9375 * rem

    /// Screen housing
    public static let screenPanelCorner: CGFloat = 2 * rem
    public static let screenPanelBorder: CGFloat = 6          // l/r/b only, no top
    public static let screenPanelInset: CGFloat = 0.5 * rem   // m-2
    public static let bezelCorner: CGFloat = 1.75 * rem
    public static let bezelInsetH: CGFloat = 0.75 * rem       // mx-3
    /// Thickness of the stone frame around the LCD. Kept small on purpose:
    /// every point here is a point of screen height.
    public static let bezelFrame: CGFloat = 4
    /// The white panel's skirt below the LCD, carrying the red dot and the
    /// speaker grill. Taller than the web's h-6 so the two are framed by white
    /// rather than crowded against the panel's bottom edge.
    public static let ventStripHeight: CGFloat = 2.25 * rem
    public static let ventDot: CGFloat = 0.5 * rem            // w-2

    /// Footer
    ///
    /// Trimmed from the web app's 6.5rem band: the marquee was tall enough to
    /// crowd the LCD on a phone, and its height is what drives the footer's.
    /// Tightened again so the white housing above it reaches as far down the
    /// chassis as the control row allows. `controlButton` (3.5rem) is the hard
    /// floor — the band cannot go below that plus the nudge.
    public static let footerHeight: CGFloat = 4.25 * rem
    public static let footerPaddingH: CGFloat = 0.75 * rem
    /// Pushes the footer row down toward the bottom edge.
    public static let footerTopNudge: CGFloat = 22
    public static let controlButton: CGFloat = 3.5 * rem
    public static let marqueeMaxWidth: CGFloat = 16.5 * rem
    public static let marqueeCorner: CGFloat = 0.8 * rem
    public static let marqueeInnerCorner: CGFloat = 0.6 * rem
    /// The banner matches the control buttons so the footer reads as one row.
    public static let marqueeHeight: CGFloat = controlButton
    /// One size for every screen: the main screen's longer banner scrolls,
    /// so it does not need to shrink to fit.
    public static let marqueeTextSize: CGFloat = 1.3 * rem

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

    /// Pixel display face — titles, category labels, chips.
    public static func retro(_ size: CGFloat) -> Font {
        _ = registration
        return isAvailable(names.retro)
            ? .custom(names.retro, size: size)
            : .system(size: size, weight: .bold, design: .monospaced)
    }

    /// CRT terminal face — body copy and readouts.
    public static func mono(_ size: CGFloat) -> Font {
        _ = registration
        return isAvailable(names.mono)
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
#endif
