#if canImport(SwiftUI) && canImport(UIKit)
import Testing
import SwiftUI
import UIKit
import VinodexCore
import VinodexUI

/// The footer-cap invariant (0.8.94, A3): **Home can never fork again.**
///
/// §A's history is three consecutive batches of cap fixes that each "missed
/// the home button", because Home resolved its colours through a separate
/// `ChassisAccent` branch whose fallback was `skin.accent` while every fix
/// landed on the `ChassisControl` path. A1 rewired the fallback and A2 put
/// all four kinds through `ChassisLook.footerCap`; this suite is what turns
/// that from this batch's state into a standing rule.
///
/// In the UI test target rather than Core because the whole colour model —
/// `ChassisSkin`, `ChassisLook`, the ramps — lives in `VinodexUI`, which
/// Linux `swift test` cannot see. This target is the instrument that runs the
/// theme layer (see `ThemeMatrixTests`), and this is a theme-layer law.
@MainActor
@Suite("Footer caps")
struct FooterCapTests {

    /// The A1 equality, on every skin: an unlit Home is made of the same
    /// material as the cap beside it, and a lit Home is the livery's own.
    @Test("Home matches its neighbours' material, or wears its authored livery")
    func homeNeverForks() {
        for skin in ChassisSkin.allCases {
            let look = ChassisLook(skinRaw: skin.rawValue)
            let home = look.homeAccent
            if let set = look.buttonSet {
                // A livery that authors a lit Home keeps it, verbatim.
                #expect(
                    home.lightHex == set.home.lightHex && home.inkHex == set.home.inkHex,
                    "\(skin.rawValue): lit Home lost its livery"
                )
            } else {
                // No livery: Home's face and ink are the cap's, byte for
                // byte — the same strings `ChassisCapLoader` re-inks Back
                // with, so the four drawn caps are one material by identity
                // rather than by resemblance.
                let cap = look.footerCap(.home)
                #expect(
                    home.lightHex == cap.topHex,
                    "\(skin.rawValue): Home's face forked from the cap (\(home.lightHex) vs \(cap.topHex))"
                )
                #expect(
                    home.inkHex == cap.glyphHex,
                    "\(skin.rawValue): Home's glyph ink forked from the cap"
                )
            }
        }
    }

    /// All four kinds resolve a cap through the one path, on every skin —
    /// the evaluation half, in `ThemeMatrixTests`' sense: reading the value
    /// is what finds a trap, and a cap whose colour string is empty is a
    /// button drawn from nothing.
    @Test("all four kinds resolve on every skin")
    func fourKindsResolve() {
        for skin in ChassisSkin.allCases {
            let look = ChassisLook(skinRaw: skin.rawValue)
            for kind in FooterCapKind.allCases {
                let cap = look.footerCap(kind)
                #expect(!cap.topHex.isEmpty, "\(skin.rawValue)/\(kind.rawValue): no face")
                #expect(!cap.glyphHex.isEmpty, "\(skin.rawValue)/\(kind.rawValue): no glyph ink")
                #expect(!cap.bottomHex.isEmpty, "\(skin.rawValue)/\(kind.rawValue): no shadow")
                #expect(!cap.edgeHex.isEmpty, "\(skin.rawValue)/\(kind.rawValue): no rim")
            }
        }
    }

    /// A workshop button colour lights Home on purpose — `PartColor.buttonSet`
    /// always authors a home ramp — and must keep doing so through the new
    /// fallback: choosing a button colour is choosing it for the lit button
    /// most of all.
    @Test("a workshop button colour keeps Home lit")
    func workshopColoursStayLit() {
        for part in PartColor.allCases {
            let look = ChassisLook(skinRaw: ChassisSkin.classic.rawValue, buttons: part.rawValue)
            #expect(
                look.homeAccent.lightHex == part.buttonSet.home.lightHex,
                "\(part.rawValue): the chosen colour did not reach Home"
            )
        }
    }

    /// The adapter itself: a cap restated as a ramp carries the cap's own
    /// strings in the stops the drawn cap re-inks from, whatever the cap.
    @Test("the cap-to-ramp adapter preserves the material")
    func adapterPreservesMaterial() {
        let cap = ChassisControl(top: "#44403C", bottom: "#0C0A09", edge: "#A8A29E", glyph: "#F5F5F4")
        let ramp = ChassisAccent(cap: cap)
        #expect(ramp.lightHex == "#44403C")
        #expect(ramp.inkHex == "#F5F5F4")
    }

    /// **The lit roster is pinned** (0.8.95, closing the hole the screenshot
    /// report exposed). `homeNeverForks` above asserts the fallback's
    /// behaviour — but if every skin quietly acquired a `buttonSet`, every
    /// skin would take the lit branch and the test would pass without one
    /// shipped skin ever exercising the fallback. Pinning which skins are lit
    /// makes that unreachable: a fifth entrant here is a decision somebody
    /// records, not a data change that vacuously greens the suite.
    @Test("exactly the four console liveries light their Home")
    func litRosterIsPinned() {
        let lit = ChassisSkin.allCases
            .filter { $0.buttonSet != nil }
            .map(\.rawValue)
            .sorted()
        #expect(
            lit == ["CLASSIC", "PSVINO", "VINHO VERDE", "W64"],
            "the lit-Home roster moved: \(lit) — update this pin with the batch that moved it"
        )
    }

    /// **The previews resolve what the device resolves** (0.8.95). This is
    /// the failure mode the user's screenshots actually caught: A1 fixed
    /// `ChassisButton` while `ChassisMockup` and the workshop schematic kept
    /// reading the bare accent, so the pickers showed a Home the chassis no
    /// longer draws. Both now read a `homeAccent`; this holds the two
    /// spellings of the rule — `ChassisSkin`'s for bare-skin previews,
    /// `ChassisLook`'s for the live device — equal on every skin, so a
    /// preview cannot drift from the part again without a red test.
    @Test("the bare-skin rule and the device rule agree on every skin")
    func previewsAgreeWithTheDevice() {
        for skin in ChassisSkin.allCases {
            let bare = skin.homeAccent
            let device = ChassisLook(skinRaw: skin.rawValue).homeAccent
            #expect(
                bare.lightHex == device.lightHex && bare.inkHex == device.inkHex,
                "\(skin.rawValue): the preview's Home is not the device's"
            )
        }
    }
}
#endif
