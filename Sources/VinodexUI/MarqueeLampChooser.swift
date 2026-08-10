#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// Where one marquee lamp button points (0.7.6, A1).
///
/// **What this replaces.** `MarqueeDrawer` — 0.7.1's B4/B5 swipe panel, with its
/// PINNED row, its TOOLS grid and its CUSTOMIZE shortcuts — is deleted, and the
/// Decision this batch opens with says why: the two lamp buttons became the pins,
/// so a drawer whose main job was choosing what the *other* always-visible
/// buttons held was a second access pattern maintaining a third. What survives
/// from it is the one thing the lamps genuinely could not do on their own, which
/// is say where they go.
///
/// **So this is a chooser, not a menu.** Every difference from the drawer follows
/// from that. It does not navigate — tapping a chip assigns and closes, it does
/// not take you there — because a surface that both configures a button and
/// duplicates it is the duplication that was just removed. It has no TOOLS grid,
/// because the TOOLS shelf is one lamp press away. It has no swipe, because there
/// is nothing to browse: it is five chips and a heading, and it fits without
/// scrolling at every text step.
///
/// **Drawn in the LCD**, like `DexAlert`, `UpgradePrompt`, the shop splash and
/// every other overlay in this app — a system sheet sliding up from the bottom of
/// the *phone* breaks the handheld metaphor, and this one is raised from a button
/// on the chassis, which makes it the surface with the strongest claim to sit
/// outside the display and the strongest reason not to. Inside, it inherits the
/// screen's monochrome pass, its scanlines and its palette.
struct MarqueeLampChooser: View {
    /// Which lamp is being pointed. 0 is the left button, 1 the right — the same
    /// order `QuickPinStore.pins` holds and the same order they are drawn in.
    let slot: Int
    let onClose: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    /// The marquee's phosphor follows the workshop override (0.7.3, B1), and the
    /// hairline below follows the phosphor — so the chooser is tinted by the
    /// panel it came out of, exactly as the drawer's top edge was.
    @AppStorage(DeviceAxis.marquee.storageKey) private var partMarquee = ""

    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    private var skin: ChassisLook { ChassisLook(skinRaw: skinRaw, marquee: partMarquee) }

    @State private var pins = QuickPinStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Which lamp this is, in words. "LEFT" and "RIGHT" rather than "1" and "2":
    /// the two buttons are physical objects on the shell and the user is looking
    /// straight at them, so the label that identifies one is the one they can see.
    private var slotName: String { slot == 0 ? "LEFT" : "RIGHT" }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tapping outside dismisses — `DexAlert`'s convention and the one
            // every modal in this app follows.
            Color.black.opacity(lcd.isLight ? 0.32 : 0.66)
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            card
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // The one glyph the app has ever used for pinning — see
                // `DexGlyph.pins`, which outlived the drawer that taught it.
                Image(systemName: DexGlyph.pins)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(lcd.accent)
                Text("\(slotName) BUTTON")
                    .font(DexFont.retro(12))
                    .tracking(1.5)
                    .foregroundStyle(lcd.text)
            }

            // `retro(10)` and guarded, per 0.7.1's A4: `TypeScale.nominalFloor`
            // is 10 and applies before the scale factor, so nothing here renders
            // below it, and a line that wrapped at the HUGE step would displace
            // the chip grid under it.
            Text("POINT IT AT")
                .font(DexFont.retro(10))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(lcd.disabledText)

            // Five chips in a three-column grid: two rows, the second half
            // empty. A grid rather than the drawer's single row of four,
            // because five chips across a 295pt panel gives 55pt columns and
            // CUSTOMIZE needs 108 even at the scale floor — the exact
            // arithmetic 0.7.1's A4 wrote down when PACKS briefly made that row
            // five wide. Three columns is 91pt and CUSTOMIZE fits on two lines.
            LazyVGrid(columns: Self.columns, spacing: 8) {
                ForEach(MarqueePin.allCases) { pin in
                    chip(pin)
                }
            }

            Button {
                Haptics.select()
                onClose()
            } label: {
                Text("CLOSE")
                    .font(DexFont.retro(11))
                    .tracking(1)
                    .foregroundStyle(lcd.subtext)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(lcd.surfaceEdge, lineWidth: 2)
                    )
            }
            .buttonStyle(DexPressStyle(scale: 0.98))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(lcd.surface)
                .overlay(alignment: .top) {
                    // The skin's phosphor as a hairline along the top edge — the
                    // one place the card admits it came out of the marquee, which
                    // is that colour. Inherited from the drawer, whose own note
                    // made this argument.
                    skin.marqueeText.frame(height: 2)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(lcd.accent.opacity(0.55), lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        )
        .shadow(color: .black.opacity(0.5), radius: 14, y: -4)
        .padding(.horizontal, 6)
    }

    /// One destination.
    ///
    /// Three states rather than two: the pin **this** lamp holds is accented and
    /// ticked, the pin the *other* lamp holds is outlined and marked with its own
    /// slot's initial, and the rest are plain. The middle state is what makes the
    /// swap rule legible — assigning an already-used destination trades the two
    /// lamps (see `QuickPinStore.assign`), and a chooser that gave no sign the
    /// other button held it would make that read as the app losing a setting.
    private func chip(_ pin: MarqueePin) -> some View {
        let mine = pins.pin(at: slot) == pin
        let elsewhere = !mine && pins.isPinned(pin)

        return Button {
            Haptics.select()
            pins.assign(pin, to: slot)
            onClose()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: pin.symbol)
                    .font(.system(size: 17, weight: .semibold))
                Text(pin.displayName)
                    .font(DexFont.retro(10))
                    .tracking(0.5)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(mine ? lcd.onAccent : lcd.text)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(mine ? lcd.accent : lcd.well)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(
                                elsewhere ? lcd.accent.opacity(0.7) : lcd.surfaceEdge,
                                lineWidth: elsewhere ? 2 : 1
                            )
                    )
            )
            .overlay(alignment: .topTrailing) {
                if mine {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(lcd.onAccent)
                        .padding(4)
                } else if elsewhere {
                    // The other lamp, named by the side it is on rather than by
                    // a number nobody has been shown.
                    Text(slot == 0 ? "R" : "L")
                        .font(DexFont.retro(10))
                        .foregroundStyle(lcd.accent)
                        .padding(4)
                }
            }
        }
        .buttonStyle(DexPressStyle(scale: 0.95))
        .accessibilityLabel(pin.displayName)
        .accessibilityHint(
            mine
                ? "Already on the \(slotName.lowercased()) button"
                : (elsewhere
                    ? "Currently on the other button. Choosing it swaps the two."
                    : "Point the \(slotName.lowercased()) button here")
        )
    }

    private static let columns = [GridItem(.flexible(), spacing: 8),
                                  GridItem(.flexible(), spacing: 8),
                                  GridItem(.flexible(), spacing: 8)]
}
#endif
