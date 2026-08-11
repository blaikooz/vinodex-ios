#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The device, drawn small enough to put in a tile (0.8.1, A2).
///
/// **Extracted rather than written.** There were already three miniature
/// chassis in this app — the workshop's `miniDevice`, the walkthrough's
/// `DeviceDiagram`, and the skin picker's tile — and the 0.8.1 spec assumed a
/// fourth caller of a shared component. There was no shared component: the
/// three are three independent drawings that happen to agree, held together by
/// two metric rules in `DexMetrics` and by whoever last remembered to change
/// all of them. 0.7.9's A1 is what that costs — it grew the orb in two of the
/// three and left the walkthrough's alone.
///
/// This is the skin picker's tile lifted out whole, because it is the one of
/// the three that was already parameterised by a `ChassisSkin` rather than by
/// the *current* skin: the workshop's reads ten `@AppStorage` axes and cannot
/// draw anything but the device you own, which is precisely the wrong answer
/// for a shop tile showing you what you do not.
///
/// Every part is a fraction of `height`, so the shop's 44pt preview and the
/// picker's 50pt tile are the same drawing at two sizes rather than two
/// drawings. The reference height is 50 — the picker's, since v0.5.6 — and the
/// literals below are the ones that tile has always used.
struct ChassisMockup: View {
    let skin: ChassisSkin
    /// A screen to light the panel strip with, or nil for the skin's own
    /// marquee phosphor.
    ///
    /// **No caller passes one as of 0.8.2, and the parameter stays.** It was
    /// added in 0.8.1 (A2) so a display pack could be previewed through the
    /// strip, and coordinator 4 reverses that: the strip is 24×3pt at the
    /// reference size, which is too little of the drawing to sell a screen
    /// with, so `SettingsPanel.screenSwatch` draws a `ScreenMockup` instead.
    /// What survives is the honest reading of this property — "light the
    /// marquee with a mode rather than with the skin's phosphor" — which is a
    /// real thing a caller may want and costs one optional to keep. Nil is the
    /// skin picker's behaviour and always has been.
    var screen: LcdMode?
    var height: CGFloat = 50

    /// Everything scales off the picker tile's 50pt. Not a magic number so much
    /// as the size this drawing was designed at, named once so a caller can ask
    /// for it smaller without every part needing its own opinion.
    private var s: CGFloat { height / 50 }

    var body: some View {
        RoundedRectangle(cornerRadius: 5 * s)
            // The dark base under the body is for the translucent skins, whose
            // smoke needs something to be over.
            .fill(Color(dexHex: "#1B1D21"))
            .overlay(RoundedRectangle(cornerRadius: 5 * s).fill(skin.body))
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topLeading) {
                // A stadium, with the real orb (0.7.5 A2, 0.7.6 E1) — a mockup
                // whose parts are the wrong shape is worse than no mockup.
                // Sized from the mockup's own 3pt part scale rather than the
                // chassis's 10pt lamp; see the note this replaced in
                // `SettingsPanel.skinGrid` (0.8.1, A1).
                Capsule(style: .continuous)
                    .fill(skin.orb)
                    .frame(
                        width: DexMetrics.islandOrbWidth(lamp: 3 * s, spacing: 1 * s),
                        height: DexMetrics.islandOrbHeight(lamp: 3 * s)
                    )
                    .padding(5 * s)
            }
            .overlay(alignment: .topTrailing) {
                // The home stand-in, in the material Home actually wears
                // (0.8.95). `skin.accent.bright` through 0.8.94, which kept
                // every picker tile showing an accent-lit Home after the
                // device stopped having one — the preview contradicting the
                // part is what the §A screenshots caught.
                Circle()
                    .fill(skin.homeAccent.bright)
                    .frame(width: 10 * s, height: 10 * s)
                    .padding(5 * s)
            }
            .overlay {
                // Through `SkinEmblem` rather than `Image(systemName:)` since
                // 0.6.7 (K1): PSVino's badge is a drawing now, not a symbol.
                SkinEmblem(skin: skin, size: 17 * s, tint: skin.accent.pale)
                    .shadow(color: .black.opacity(0.55), radius: 0, x: 1, y: 1)
                    // Centred in the deck, not the tile — the bottom 14pt (at
                    // the reference size) is the panel strip.
                    .offset(y: -7 * s)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(skin.panel)
                    .frame(height: 14 * s)
                    .overlay {
                        Capsule()
                            .fill(screen?.screen ?? skin.marqueeText)
                            .frame(width: 24 * s, height: 3 * s)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5 * s))
            .overlay(
                RoundedRectangle(cornerRadius: 5 * s)
                    .strokeBorder(skin.panelEdge, lineWidth: 1)
            )
    }
}
#endif
