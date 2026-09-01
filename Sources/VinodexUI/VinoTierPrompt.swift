#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// **The exam tier's celebration card, presented by Vinobot** (rework V2).
///
/// The one rank-up in the app with no card: `WineExamScreen` computed
/// `newlyUnlocked` since 0.8.x and spent it on a single gold text line in
/// the results column. The rework's coach role makes the examiner hand you
/// the certificate himself — `RankUnlockedPrompt`'s shape (scrim, landing
/// animation, one dismiss) with his face where the shield goes and a line
/// in his voice, gated by the same word/ASCII discipline as the scenes.
///
/// The gold text line in the results stays: the card is the moment, the
/// line is the record.
struct VinoTierPrompt: View {
    let tier: QuizTier
    let onDismiss: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    private var ink: Color { Dex.yellow }

    var body: some View {
        ZStack {
            Color.black.opacity(lcd.isLight ? 0.35 : 0.72)
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 14) {
                Text("TIER UNLOCKED")
                    .font(DexFont.retro(12))
                    .tracking(2)
                    .foregroundStyle(ink)

                DexChromeGlyph(
                    VinoExpression.goodjob.artStem,
                    symbol: "checkmark.seal.fill",
                    size: 76,
                    tint: ink
                )
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

                Text("A harder paper, unlocked. I taught you most of what you know - not most of what I know.")
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Haptics.screenTap()
                    onDismiss()
                } label: {
                    Text("SANTE")
                        .font(DexFont.retro(12))
                        .tracking(2)
                        .foregroundStyle(lcd.onAccent)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.accent))
                }
                .buttonStyle(DexPressStyle(scale: 0.98))
            }
            .padding(18)
            .frame(maxWidth: 300)
            .background(RoundedRectangle(cornerRadius: 10).fill(lcd.page))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(ink.opacity(0.7), lineWidth: 2)
            )
        }
        .onAppear {
            if reduceMotion {
                landed = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                    landed = true
                }
            }
        }
    }
}
#endif
