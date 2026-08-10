#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// One screen mode, drawn as a screen (0.8.2, coordinator 4; finished 0.8.3, F).
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
/// **0.8.3's F: this is the CUSTOMIZE card now, not a likeness of it.** 0.8.2
/// shipped this untested by anything but the compiler, and what it drew was a
/// *reduction* of the picker's card — a bezel, a ground, an accent bar and
/// three ragged body lines, with no glyph and, more seriously, no monochrome
/// pass. That last omission is the reason F exists: AMBER, VINTAGE, TERMINAL
/// and GRÜNER BOY are built by taking the dark theme's tokens, greying them and
/// multiplying by one phosphor, and a preview that skips that step shows four
/// modes as the *green* they are made from. The shop was selling the RETRO pack
/// with two of its three screens previewed in the wrong colour.
///
/// So `modeGrid` in `SettingsPanel` calls this view rather than drawing its own,
/// and "exactly as it appears in Customise" is true by construction instead of
/// by two files agreeing. Everything is a fraction of `height`, so the picker's
/// 50 and the shop's 40 are one drawing at two sizes.
///
/// **Two deliberate departures from the card as it stood**, both of which the
/// picker inherits:
///
/// - **The bezel is gone.** 0.8.2 added a dark surround so "a light mode reads
///   as a lit panel rather than as a pale rectangle on a pale tile". The picker
///   never had one — it uses `surfaceEdge`, the mode's own frame colour, which
///   is a register off the ground on every one of the nine and solves the same
///   problem without putting a second material around the screen. F asks for
///   the picker's drawing; this is the picker's answer.
/// - **`ownInk`, not `text`.** `LcdMode.text` and `LcdMode.subtext` both return
///   the workshop's chosen font colour when one is fitted, so a card drawn
///   through them shows every mode in one ink and hides the axis this pack
///   sells. `ownInk` exists for exactly this — it is what the workshop's own
///   FOLLOW swatch reads — and the second line takes `ownInk.opacity(0.62)`,
///   which is what `subtext` itself computes from a chosen ink. The picker
///   drew through `text` and had the same defect; it is fixed here for both.
struct ScreenMockup: View {
    let mode: LcdMode
    /// 50 is the reference: it is the height the CUSTOMIZE card has always
    /// drawn at, and every number below is that card's own.
    var height: CGFloat = 50

    private var s: CGFloat { height / 50 }

    var body: some View {
        RoundedRectangle(cornerRadius: 5 * s)
            .fill(mode.screen)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay {
                VStack(spacing: 4 * s) {
                    // The mode's own glyph — the "with icons" half of F, and
                    // the thing that makes nine near-identical rectangles nine
                    // recognisable screens.
                    Image(systemName: mode.symbol)
                        .font(.system(size: 15 * s, weight: .semibold))
                        .foregroundStyle(mode.accent)
                    RoundedRectangle(cornerRadius: 1 * s)
                        .fill(mode.ownInk.opacity(0.85))
                        .frame(width: 34 * s, height: 3 * s)
                    RoundedRectangle(cornerRadius: 1 * s)
                        // 0.5, which is the card's own 0.8 over the 0.62
                        // `subtext` derives from an ink, folded into one number
                        // rather than left as two chained opacities.
                        .fill(mode.ownInk.opacity(0.5))
                        .frame(width: 24 * s, height: 3 * s)
                }
            }
            // **The pass that was missing.** Applied to the whole stack — ground,
            // glyph and both lines — because that is what the LCD does to a real
            // screen in these modes. Skipped entirely on the five colour modes,
            // where `monochromeTint` is nil and a grayscale of 0 with a white
            // multiply is a no-op by construction rather than by luck.
            .grayscale(mode.monochromeTint == nil ? 0 : 1)
            .colorMultiply(mode.monochromeTint ?? .white)
            .clipShape(RoundedRectangle(cornerRadius: 5 * s))
            .overlay(
                RoundedRectangle(cornerRadius: 5 * s)
                    .strokeBorder(mode.surfaceEdge, lineWidth: 1)
            )
    }
}
#endif
