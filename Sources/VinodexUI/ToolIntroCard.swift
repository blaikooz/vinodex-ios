#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The card raised the first time a tool is opened (0.8.8, D1).
///
/// **`DexAlert`'s clothes, not `DexAlert`.** The house rule is that modals are
/// `DexAlert`, and that control is a title, a message and up to two buttons —
/// this needs the tool's own drawing at a size worth looking at, a tagline and a
/// body, and a third control that is not about *this* card. Rather than grow the
/// shared alert with a picture well and a third button for one caller, this
/// borrows its scrim, its panel and its motion so the two read as the same kind
/// of interruption.
///
/// The face colour is the shelf tile's, so the card is visibly the tile you just
/// pressed rather than a generic panel that happens to have arrived.
/// `public`, like `DexAlert` and `UpgradePrompt` beside it: `VinodexApp` is a
/// separate module and raises this, so internal would not be visible there.
public struct ToolIntroCard: View {
    let intro: ToolIntro
    let onStart: () -> Void
    let onSkipAll: () -> Void

    public init(
        intro: ToolIntro,
        onStart: @escaping () -> Void,
        onSkipAll: @escaping () -> Void
    ) {
        self.intro = intro
        self.onStart = onStart
        self.onSkipAll = onSkipAll
    }

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var face: Color { Color(dexHex: intro.faceHex) }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                DexChromeGlyph(
                    intro.art,
                    symbol: intro.symbol,
                    size: 64,
                    weight: .semibold,
                    tint: face
                )
                .padding(.top, 4)

                Text(intro.title)
                    .font(DexFont.retro(20))
                    .tracking(1.5)
                    .foregroundStyle(lcd.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                Text(intro.tagline)
                    .font(DexFont.retro(12))
                    .tracking(0.5)
                    .foregroundStyle(face)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(intro.body)
                    .font(DexFont.mono(14))
                    .foregroundStyle(lcd.subtext)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Haptics.screenTap()
                    onStart()
                } label: {
                    Text("START")
                        .font(DexFont.retro(14))
                        .tracking(2)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Capsule().fill(face))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(DexPressStyle(scale: 0.97))

                // **The returning player's answer, and the reason there is no
                // seed flag.** See `ToolIntroStore`'s note: the app has no record
                // of which tools anybody has used, so rather than guess and
                // suppress, it asks once and takes an answer for all six.
                Button {
                    Haptics.select()
                    onSkipAll()
                } label: {
                    Text("SKIP THESE")
                        .font(DexFont.retro(11))
                        .tracking(1.2)
                        .foregroundStyle(Dex.stone400)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                }
                .buttonStyle(DexPressStyle(scale: 0.98))
            }
            .padding(18)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 10).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(face.opacity(0.7), lineWidth: 2)
            )
            .padding(.horizontal, 20)
            .scaleEffect(landed ? 1 : 0.94)
            .opacity(landed ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else { landed = true; return }
            withAnimation(DexMotion.settle) { landed = true }
        }
    }
}
#endif
