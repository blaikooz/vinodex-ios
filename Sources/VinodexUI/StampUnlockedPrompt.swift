#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The moment a passport stamp is earned (0.7.1, D2).
///
/// **Why a view of its own rather than a `DexAlert`.** The same reason
/// `RatingPrompt` gives: `DexAlert` is a title and a message with buttons, and
/// it is deliberately dumb. This has to show the stamp itself — the real
/// `BackPlateStampView`, at rest and then landing — and the whole point of D2
/// is that you *see the thing you won*, not that you read its name in a
/// dialogue box. Everything else follows `DexAlert`'s conventions exactly:
/// in-LCD, scrim, ~320pt card, `.isModal`, scrim-tap dismisses.
///
/// **The animation is a stamp being pressed, because that is what the object
/// is.** It arrives large, rotated and transparent, and drops to its resting
/// size, angle and opacity — an over-damped spring so it lands with a single
/// small settle rather than bouncing, which is what a rubber stamp on paper
/// does. There is no confetti and no particle system in this app and this is
/// not the place to introduce one: the device is a piece of moulded plastic
/// from 1998 and it does not throw a party.
///
/// Under Reduce Motion the stamp is simply *there*, at rest, from the first
/// frame. The information is the stamp, not the movement.
struct StampUnlockedPrompt: View {
    let stamp: BackPlateStamp
    let onDismiss: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Flipped once, on appear, to run the press. `@State` rather than a
    /// transition so the two halves — scale and rotation — cannot be dropped
    /// separately, which is the trap the chassis flip documents.
    @State private var landed = false

    private var ink: Color { Color(dexHex: stamp.colorHex) }

    var body: some View {
        ZStack {
            Color.black.opacity(lcd.isLight ? 0.35 : 0.72)
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 14) {
                Text("STAMP EARNED")
                    .font(DexFont.retro(12))
                    .tracking(2)
                    .foregroundStyle(ink)

                BackPlateStampView(stamp: stamp)
                    .rotationEffect(.degrees(landed ? -7 : 14))
                    .scaleEffect(landed ? 1 : 2.1)
                    .opacity(landed ? 1 : 0)
                    .shadow(color: ink.opacity(landed ? 0.5 : 0), radius: 14)
                    // Sized to the resting stamp so the oversized first frame
                    // does not push the card open and then let it collapse.
                    .frame(width: 88, height: 104)

                Text(stamp.title)
                    .font(DexFont.retro(14))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)

                Text(stamp.info)
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // **No longer says where it went** (0.7.2, A5). This line used
                // to read "IT IS ON THE BACK PLATE — HOLD THE ORB TO TURN THE
                // DEVICE OVER", which spent the one celebratory moment a stamp
                // gets on filing instructions, and named an internal part of the
                // chassis to do it. A stamp is a reward; the card should say
                // well done and stop.
                //
                // The wayfinding is not lost, it is just not here: the plate is
                // reachable by holding the orb whether or not this card mentions
                // it, the engraved hint on the plate itself explains the drag,
                // and PASSPORT lists every stamp earned. Telling someone about a
                // storage location three seconds after they earned something is
                // the wrong moment to teach navigation anyway.
                Text("ADDED TO YOUR COLLECTION.")
                    .font(DexFont.mono(14))
                    .foregroundStyle(lcd.disabledText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Haptics.screenTap()
                    onDismiss()
                } label: {
                    Text("NICE")
                        .font(DexFont.retro(12))
                        .tracking(1)
                        .foregroundStyle(lcd.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.accent))
                }
                .buttonStyle(DexPressStyle(scale: 0.97))
            }
            .padding(18)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 8).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 8).strokeBorder(ink.opacity(0.7), lineWidth: 2)
            )
            .padding(20)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
        .onAppear {
            guard !reduceMotion else {
                landed = true
                return
            }
            Haptics.answer(correct: true)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { landed = true }
        }
    }
}
#endif
