#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// One tile in a picker: a swatch, an optional glyph over it, and a label
/// (0.7.3, 0.7.3c — A2).
///
/// **This is 0.7.3b's `partChip`, promoted rather than copied.** By the end of
/// 0.7.3b the app had four hand-written picker grids — `skinGrid` and `modeGrid`
/// in the CUSTOMIZE panel, `shellChooser` and `screenChooser` in the workshop —
/// doing the same job over the same two stored keys, and 0.7.3b's own notes
/// flagged the duplication rather than fixing it. A2 asks the cartridge shelf to
/// reuse "the picker mockup style of the screen-mode / chassis-skin picker",
/// which taken literally means writing a fifth. So the workshop's chip, which was
/// already the one *generalised* version of the pattern (it serves all eight
/// `DeviceAxis` rows from one function), moved here and grew the two parameters
/// the shelf needed: a swatch size and an outline shape.
///
/// **What was deliberately not done.** `skinGrid` and `modeGrid` still stand.
/// They are 50pt tiles carrying real art — a fake device with an orb, an accent
/// dot, a `SkinEmblem` and a marquee strip; a fake LCD with a monochrome tint
/// pass — and folding those bodies in here would have rewritten the two pickers
/// a user actually looks at, in a module no Linux gate can compile, for a tidy
/// this batch was not asked for. The count therefore went from four bespoke
/// grids to three plus one shared tile with three users, which is the right
/// direction; finishing the job is a CUSTOMIZE-panel sitting of its own and
/// belongs beside AUDIT.md's M30 split.
///
/// The interaction model is the picker's, unchanged: tap selects, the chosen
/// tile takes `lcd.accent`, a locked tile dims and wears a padlock in place of
/// its own glyph, and the *caller* decides what a tap on a locked tile raises.
/// Nothing here knows about entitlements — the workshop and the shelf both
/// resolve that before they build the tile, which is why this can be used for a
/// row that has no lock state at all.
///
/// `Outline` is a generic rather than an `AnyShape` because the border is drawn
/// with `strokeBorder`, which insets the line instead of straddling the path —
/// and `strokeBorder` lives on `InsettableShape`, which `AnyShape` does not
/// conform to. Erasing it would have quietly demoted the outline to `stroke`
/// and moved every chip's border half a line-width outward.
struct DexPickerTile<Swatch: View, Outline: InsettableShape>: View {
    let label: String
    /// Drawn with the accent background and the heavier outline.
    let isChosen: Bool
    /// Over the swatch. `nil` for none; callers pass `"lock.fill"` for a gated
    /// option, which is why a locked tile loses its own glyph rather than
    /// gaining a second one.
    let symbol: String?
    let lcd: LcdMode
    /// 26pt is the workshop's chip; the cartridge shelf runs larger, because a
    /// cartridge has to read as an object rather than as a swatch.
    var swatchSize: CGFloat = 26
    /// The label's size and the floor its box reserves. Two lines either way —
    /// GRIS DE GRIS and GODFORSAKEN both wrap.
    var labelSize: CGFloat = 8
    var labelMinHeight: CGFloat = 20
    /// The border drawn around the swatch. A circle for the workshop's colour
    /// chips, a rounded rectangle for a cartridge. No default — Swift has none
    /// for a generic parameter, and the two call sites both mean something by it.
    let outline: Outline
    let action: () -> Void
    @ViewBuilder let swatch: () -> Swatch

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            VStack(spacing: 5) {
                swatch()
                    .frame(width: swatchSize, height: swatchSize)
                    .overlay {
                        if let symbol {
                            Image(systemName: symbol)
                                .font(.system(size: max(10, swatchSize * 0.38), weight: .bold))
                                .foregroundStyle(.white)
                                // A hard one-pixel drop rather than a blur: the
                                // glyph sits over arbitrary swatch colours and a
                                // soft shadow reads as a smudge at this size.
                                .shadow(color: .black.opacity(0.7), radius: 0, x: 1, y: 1)
                        }
                    }
                    .overlay(
                        outline.strokeBorder(
                            isChosen ? lcd.onAccent : lcd.surfaceEdge,
                            lineWidth: isChosen ? 2 : 1
                        )
                    )
                Text(label)
                    .font(DexFont.retro(labelSize))
                    .tracking(0.5)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .frame(minHeight: labelMinHeight)
            }
            .foregroundStyle(isChosen ? lcd.onAccent : lcd.subtext)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isChosen ? lcd.accent : lcd.surface)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.96))
    }
}
#endif
