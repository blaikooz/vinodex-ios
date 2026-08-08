#if canImport(SwiftUI) && canImport(UIKit)
import Testing
import SwiftUI
import UIKit
import VinodexCore
import VinodexUI

/// The theme matrix, exercised end to end (S1).
///
/// **Why this suite exists.** `DexTheme.swift` resolves every visual value the
/// device draws through two enums — `ChassisSkin` (21 cases, 27 `switch`
/// statements) and `LcdMode` (9 cases, 24 `switch` statements) — and nothing
/// has ever executed them. `VinodexUI` compiles to nothing on Linux and on
/// macOS, so `swift test` cannot see a single one of those branches, and the
/// clean `xtool dev build` type-checks them without ever evaluating one. The
/// only instrument that has ever run this code is a person holding the phone
/// and looking at it.
///
/// So these are not clever tests. They read every property of every case and
/// assert the weakest things that are certainly true. That is deliberate: the
/// value is in *evaluation*, not in the assertions. A `switch` that traps, an
/// array subscript that runs off the end, a force unwrap on an unauthored skin
/// — none of those are type errors, and every one of them is a black screen on
/// a device. Reading the value is what finds them.
///
/// **This is also the net under S3.** Decomposing `DexTheme`'s switch matrix
/// into a data registry means moving 633 branches' worth of values into rows,
/// and the only way that is reviewable is if something proves every cell still
/// resolves afterwards. Land this first; move values under it second.
@Suite("Theme matrix")
struct ThemeMatrixTests {

    // MARK: - Coverage pins
    //
    // Deliberate pins, in the sense `CoverageTests` means it: they are not here
    // to be right forever but to fail loudly when the matrix grows, so that
    // growth is a decision someone made rather than one that happened. Update
    // them with a note saying which batch moved them.

    @Test("the matrix is the size it was pinned at")
    func matrixSize() {
        #expect(ChassisSkin.allCases.count == 21)
        #expect(LcdMode.allCases.count == 9)
        #expect(UIScale.allCases.count == 2)
        #expect(TextScale.allCases.count == 3)
    }

    // MARK: - Every case resolves every value

    /// Reads all 27 skin-axis properties for all 21 skins.
    ///
    /// `_ =` rather than an assertion for most of them, and that is the point:
    /// these properties are non-optional, so there is no nil to catch and no
    /// interesting claim to make about a `Color`. What can happen is a trap, and
    /// evaluating the property is what surfaces it.
    @Test("every chassis skin resolves every property it owns")
    func everySkinResolves() {
        for skin in ChassisSkin.allCases {
            #expect(!skin.id.isEmpty)
            #expect(!skin.displayName.isEmpty, "\(skin.rawValue) has no display name")
            #expect(!skin.symbol.isEmpty, "\(skin.rawValue) has no symbol")

            _ = skin.section
            _ = skin.isTranslucent
            _ = skin.rimGlow
            _ = skin.globeTint
            _ = skin.underlay
            _ = skin.backSmoke
            _ = skin.bodyPatternAsset
            _ = skin.statusLights
            _ = skin.body
            _ = skin.footerWash
            _ = skin.panel
            _ = skin.panelEdge
            _ = skin.grill
            _ = skin.orb
            _ = skin.orbGlow
            _ = skin.accent
            _ = skin.control
            _ = skin.buttonSet
            _ = skin.drawnMark
            _ = skin.userMark
            _ = skin.backPlate
            _ = skin.sketch
            _ = skin.marqueeText
            _ = skin.marqueeGrid
            _ = skin.marqueeShadow
        }
    }

    /// Reads all 24 mode-axis properties for all 9 modes.
    @Test("every LCD mode resolves every property it owns")
    func everyModeResolves() {
        for mode in LcdMode.allCases {
            #expect(!mode.id.isEmpty)
            #expect(!mode.displayName.isEmpty, "\(mode.rawValue) has no display name")
            #expect(!mode.symbol.isEmpty, "\(mode.rawValue) has no symbol")

            _ = mode.section
            _ = mode.isLight
            _ = mode.monochromeTint
            _ = mode.screen
            _ = mode.honorsFontInk
            _ = mode.text
            _ = mode.ownInk
            _ = mode.accent
            _ = mode.bodyText
            _ = mode.heroWash
            _ = mode.heroGrid
            _ = mode.buttonWell
            _ = mode.page
            _ = mode.surface
            _ = mode.surfaceEdge
            _ = mode.subtext
            _ = mode.well
            _ = mode.disabledText
            _ = mode.onAccent
            _ = mode.ground
            _ = mode.gridLine
            _ = mode.panelGround
            _ = mode.controlAccent
            _ = mode.globeTint
            _ = mode.invertsGlobeTexture
            _ = mode.themesChrome
        }
    }

    /// The full product — 21 x 9 x 2 = 378 combinations.
    ///
    /// The two axes are resolved independently in the code, so the product is
    /// not strictly more than the two loops above. It is here because the app
    /// ships the *combination*, and because when `DexTheme` becomes a registry
    /// the lookup will be by pair — at which point a missing row is a real
    /// failure mode that neither single-axis loop can see.
    @Test("every skin x mode x scale combination resolves")
    func everyCombinationResolves() {
        var combinations = 0
        for skin in ChassisSkin.allCases {
            for mode in LcdMode.allCases {
                for scale in UIScale.allCases {
                    _ = skin.body
                    _ = skin.panel
                    _ = mode.screen
                    _ = mode.text
                    _ = scale.factor
                    combinations += 1
                }
            }
        }
        #expect(combinations == 378)
    }

    // MARK: - Legibility

    /// The screen and the ink on it cannot be the same colour.
    ///
    /// The weakest possible statement of "you can read this", and chosen for
    /// that reason — a contrast *ratio* threshold picked without a device to
    /// check it against would be a number invented to pass. Identical colours
    /// need no judgement: that mode renders an empty screen.
    ///
    /// **Asserted against `ownInk`, not `text`.** `text` is `fontInk ?? modeText`
    /// and `fontInk` reads `UserDefaults.standard`, so it answers with whatever
    /// font colour the running process last had set. That makes `text` a
    /// statement about a user setting; `ownInk` is the mode's own palette and is
    /// the thing this suite is entitled to pin.
    @Test("no LCD mode draws its ink in its background colour")
    func inkIsNotTheBackground() {
        for mode in LcdMode.allCases {
            #expect(
                rgba(mode.screen) != rgba(mode.ownInk),
                "\(mode.rawValue) draws its ink the same colour as the screen"
            )
        }
    }

    /// An accent that matches the surface it sits on is invisible chrome.
    @Test("no LCD mode hides its accent in its surface")
    func accentIsNotTheSurface() {
        for mode in LcdMode.allCases {
            #expect(
                rgba(mode.surface) != rgba(mode.accent),
                "\(mode.rawValue) draws its accent the same colour as its surface"
            )
        }
    }

    // MARK: - Type floor

    /// `DexFont` is the UI-side boundary of the floor `TypeScale` owns, and it
    /// is the side no Linux test can reach. Guards the clamp against being
    /// refactored out of `resolvedSize` while `TypeScale` keeps its own tests
    /// green — the split-brain that a Core-only suite cannot see.
    @Test("DexFont never resolves a size below the floor")
    func fontFloorHolds() {
        let floor = CGFloat(TypeScale.nominalFloor * TextScale.current.factor)
        for nominal in stride(from: CGFloat(0), through: CGFloat(40), by: 0.5) {
            #expect(
                DexFont.resolvedSize(nominal) >= floor,
                "nominal \(nominal) resolved below the floor"
            )
        }
    }

    // MARK: - Helpers

    /// A `Color`'s components, via `UIColor`.
    ///
    /// `Color` is not reliably `Equatable` for this purpose — two colours built
    /// from different initialisers can describe the same paint and compare
    /// unequal — so comparisons go through resolved RGBA instead.
    private func rgba(_ color: Color) -> [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }
}
#endif
