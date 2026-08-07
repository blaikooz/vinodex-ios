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

                // **Its own size, not the plate's** (0.8.6, C1). C1 shrinks
                // `BackPlateStampView`'s default to 72x66 because six stamps
                // scattered on the back of a device should be small; this is one
                // stamp being handed to you, and it is the only thing on the
                // card. So the size is passed rather than inherited, at the
                // drawn stamps' own 1.1 aspect rather than the retired 88x104,
                // which was a portrait box sized for a title the art carries
                // itself.
                BackPlateStampView(stamp: stamp, width: 132, height: 120)
                    .rotationEffect(.degrees(landed ? -7 : 14))
                    .scaleEffect(landed ? 1 : 2.1)
                    .opacity(landed ? 1 : 0)
                    .shadow(color: ink.opacity(landed ? 0.5 : 0), radius: 14)
                    // Sized to the resting stamp so the oversized first frame
                    // does not push the card open and then let it collapse.
                    .frame(width: 132, height: 120)

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

/// The moment a rung of the ladder is crossed (0.8.7, D1).
///
/// **A sibling of `StampUnlockedPrompt`, deliberately, and not a `DexAlert`.**
/// The ladder is the other half of the passport's progression — the rank card is
/// the first thing on that page and the stamps are the second — and until now
/// only one of them had a moment. Crossing into VINODEX MASTER changed a line of
/// text on a screen the player might not open for a week.
///
/// It borrows this file's grammar rather than inventing a second celebration:
/// same scrim, same ~320pt card, same `.isModal`, same NICE, same over-damped
/// spring, same Reduce Motion rule. What differs is what lands, and that is the
/// honest difference between the two events: a stamp is an *object* you won, so
/// D2 shows you the object; a rank is a *standing*, so this shows the seal the
/// rank card already wears, at the size of the thing it is announcing.
///
/// The blurb is `PassportTier.blurb` — the same sentence the rank card prints —
/// rather than new copy. Two places describing one rung is how they end up
/// disagreeing, and the tier already owns the words.
struct RankUnlockedPrompt: View {
    let tier: PassportTier
    let onDismiss: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    /// The rank card's own gold, so the two surfaces are announcing the same
    /// thing. `Dex.yellow` there, `Dex.yellow` here.
    private var ink: Color { Dex.yellow }

    var body: some View {
        ZStack {
            Color.black.opacity(lcd.isLight ? 0.35 : 0.72)
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 14) {
                Text("RANK UP")
                    .font(DexFont.retro(12))
                    .tracking(2)
                    .foregroundStyle(ink)

                Image(systemName: "seal.fill")
                    .font(.system(size: 76, weight: .semibold))
                    .foregroundStyle(ink)
                    .rotationEffect(.degrees(landed ? 0 : -18))
                    .scaleEffect(landed ? 1 : 2.1)
                    .opacity(landed ? 1 : 0)
                    .shadow(color: ink.opacity(landed ? 0.5 : 0), radius: 14)
                    .frame(height: 96)

                Text(tier.displayName)
                    .font(DexFont.retro(14))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)

                Text(tier.blurb)
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // What is left, or that there is nothing left. `nextTier` is nil
                // only at the top, and a player who has just finished the ladder
                // should be told so in the same breath they are told they
                // finished it -- the rank card's own line, verbatim.
                Text(
                    tier.next.map { "NEXT: \($0.displayName) AT \($0.threshold)." }
                        ?? "THE LADDER IS FINISHED."
                )
                .font(DexFont.mono(14))
                .foregroundStyle(lcd.disabledText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
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
