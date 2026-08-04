#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

// The LCD's palette, one table per screen mode.
//
// `LcdMode` and `UIScale` themselves — the cases, the persisted raw values,
// the storage keys, the labels and the glyphs — moved to
// `Sources/VinodexCore/ScreenMode.swift` (arch **A6**), so the vocabulary a
// device has already written to disk is reachable from `swift test`. What is
// left here is the half that needs `Color`, as an extension.
//
// This is the same split **H11** made for `TextScale`: the arithmetic went to
// Core and `DexFont` kept the `Font`. The file itself was split out of
// DexTheme.swift by AUDIT **M30**; nothing in either move changed a value.

// Internal, not `public`: `controlAccent` returns `ChassisAccent`, which is a
// UI-only type, and the enum itself was internal before A6 moved it — nothing
// outside this module has ever read a colour off it. Widening the extension
// because the *enum* is now public would be exporting a surface that has no
// consumer, which is the accident **L9** spent 195 `public` keywords undoing.
extension LcdMode {
    /// The tint the chassis multiplies the grayscaled LCD by — nil renders in
    /// colour. This is what turns "black on white" into "black on grey-green"
    /// (vintage) and "white on black" into "amber on black" (amber) or
    /// terminal green (terminal).
    var monochromeTint: Color? {
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

    /// LCD ground.
    var screen: Color {
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
    var text: Color {
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
    var accent: Color {
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
    var bodyText: Color {
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
    var heroWash: Color {
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
    var heroGrid: Color {
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
    var buttonWell: Color {
        switch self {
        case .dark, .amber, .terminal, .starTrek: .black.opacity(0.35)
        case .light, .vintage, .wineOS, .gruenerBoy: .white
        case .blueScreen: Color(dexHex: "#0A1690")
        }
    }

    /// Ground behind entry screens, which paint their own black rather than
    /// using `DexScreenBackground`.
    var page: Color {
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
    var surface: Color {
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

    var surfaceEdge: Color {
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
    var subtext: Color {
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
    var well: Color {
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
    var disabledText: Color {
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
    var onAccent: Color {
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
    var ground: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone950
        default: screen
        }
    }

    /// The faint atmosphere grid drawn over `ground`.
    var gridLine: Color {
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
    var panelGround: Color {
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
    var controlAccent: ChassisAccent {
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
    var globeTint: Color? {
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
}
#endif
