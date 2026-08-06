#if canImport(SwiftUI)
import SwiftUI

/// One screen mode, drawn as a screen (0.8.2, coordinator 4).
///
/// **What this replaces and why.** 0.8.1's A2 gave the shop's two cosmetic
/// shelves the same preview: `ChassisMockup`, a whole device, with the display
/// packs distinguished only by the colour of the marquee capsule inside it —
/// 24pt by 3pt at the reference size, and proportionally smaller at the 40pt
/// the shop asks for. That was defensible while the argument was "put the
/// swatch in the device it belongs to", and it is wrong on the thing being
/// sold: a display pack sells a screen, and A2 previewed it as three virtually
/// identical devices with a differently-tinted sliver.
///
/// A device pack genuinely does sell the device, so `shellSwatch` keeps
/// `ChassisMockup` unchanged. The asymmetry between the two shelves is the
/// point rather than an inconsistency: each previews its own product.
///
/// **It is the LCD, not a colour chip.** The screen a mode produces is at least
/// three decisions — the ground, the ink and the accent — and a disc of
/// `mode.screen` shows one of them. So this draws the bezel, the ground, a
/// title bar in the accent and three lines of body text in the ink, which is
/// the smallest arrangement in which those three colours are visibly *doing*
/// what they do on a real screen. At 40pt the lines are one point tall, which
/// is legible as text-shaped without pretending to be readable.
///
/// **`ownInk`, not `text`.** `LcdMode.text` returns the workshop's chosen font
/// colour when one is set, so previewing a mode through it would show every
/// mode in the same ink and hide the axis this pack sells. `ownInk` exists for
/// exactly this — it is what the workshop's own FOLLOW swatch reads.
struct ScreenMockup: View {
    let mode: LcdMode
    var height: CGFloat = 40

    /// Everything is a fraction of this, so the shop's 40pt and any later
    /// caller are the same drawing at two sizes. 40 is the reference because it
    /// is what `screenSwatch` asks for.
    private var s: CGFloat { height / 40 }

    var body: some View {
        RoundedRectangle(cornerRadius: 4 * s)
            // The bezel: a dark surround, so a light mode reads as a lit panel
            // rather than as a pale rectangle on a pale tile.
            .fill(Color(dexHex: "#1B1D21"))
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: 2 * s)
                    .fill(mode.screen)
                    .padding(3 * s)
                    .overlay(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2 * s) {
                            // The title bar, in the accent — the mode's third
                            // colour and the one a bare swatch never shows.
                            Capsule()
                                .fill(mode.accent)
                                .frame(height: 3 * s)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            // Body lines in the mode's own ink, ragged like
                            // text rather than three equal bars.
                            ForEach([1.0, 0.72, 0.86], id: \.self) { fraction in
                                Capsule()
                                    .fill(mode.ownInk.opacity(0.75))
                                    .frame(height: 1.5 * s)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    // Shortened by scale rather than by a
                                    // width, because the available width is
                                    // whatever the tile gives us and a
                                    // fraction of it is not a number this view
                                    // can name.
                                    .scaleEffect(x: fraction, anchor: .leading)
                            }
                        }
                        .padding(.horizontal, 6 * s)
                        .padding(.top, 7 * s)
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4 * s)
                    .strokeBorder(.black.opacity(0.55), lineWidth: 1)
            )
    }
}
#endif
