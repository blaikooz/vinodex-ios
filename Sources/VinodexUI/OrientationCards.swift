#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// **The four pillars, shown once, straight after the name card** (0.9.57).
///
/// Deliberately the same panel as `VinoIntroCard` — same scrim, same portrait
/// size, same width, same buttons — because it is the same conversation
/// continuing. A new player should not be able to tell where one screen ended
/// and the next began; what changes is that he has stopped asking and started
/// telling.
///
/// `Orientation` in Core holds the copy and is what the tests read. This is
/// layout and paging, and nothing else.
public struct OrientationCards: View {
    var settings: AppSettings = .shared
    let onFinish: () -> Void

    /// `startAt` is for the screenshot probe only — every real caller takes the
    /// default. The cards need two taps and a name card to reach, and the
    /// simulator has no tap tooling, so without a way in they could only ever
    /// be photographed as card one.
    public init(
        settings: AppSettings = .shared,
        startAt: Int = 0,
        onFinish: @escaping () -> Void
    ) {
        self.settings = settings
        self.onFinish = onFinish
        _page = State(initialValue: startAt)
    }

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    @AppStorage(VinoName.storageKey) private var displayName = ""

    /// Which card is up. `Orientation.count` is the closing line, which is a
    /// page rather than a card — see the note in Core.
    @State private var page: Int

    private var isClosing: Bool { page >= Orientation.count }
    private var card: OrientationCard? {
        page < Orientation.count ? Orientation.cards[page] : nil
    }

    /// Matches `VinoIntroCard.portraitSize` exactly. Two values that must agree
    /// and do not share a constant would drift the moment either is tuned, and
    /// the drift would read as the card jumping between pages.
    private var portraitSize: CGFloat { 84 * UIScale.current.factor }

    public var body: some View {
        ZStack {
            Color.black.opacity(lcd.isLight ? 0.4 : 0.76)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                DexChromeGlyph(
                    (card?.expression ?? .raiseaglass).artStem,
                    symbol: "cpu",
                    size: portraitSize,
                    weight: .semibold,
                    tint: lcd.accent
                )

                if let card {
                    Text(card.title)
                        .font(DexFont.retro(12))
                        .tracking(2)
                        .foregroundStyle(lcd.accent)

                    Text(card.body)
                        .font(DexFont.mono(19))
                        .foregroundStyle(lcd.text)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    // Where you are in four. A card count is worth showing when
                    // the answer is "nearly done" — it is the thing that stops
                    // a reader skipping out of impatience.
                    Text("\(page + 1) OF \(Orientation.count)")
                        .font(DexFont.retro(10))
                        .tracking(2)
                        .foregroundStyle(lcd.subtext)
                } else {
                    Text(closingLine)
                        .font(DexFont.mono(20))
                        .foregroundStyle(lcd.text)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    // SKIP stays on every card, not just the first. Someone who
                    // decides on card three that they would rather be using the
                    // app should not have to read card four to get there.
                    if !isClosing {
                        button("SKIP", accent: false) {
                            Haptics.select()
                            onFinish()
                        }
                    }
                    button(isClosing ? "LET'S GO" : "NEXT", accent: true) {
                        Haptics.screenTap()
                        if isClosing {
                            onFinish()
                        } else {
                            withAnimation(DexMotion.overlay) { page += 1 }
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 8).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 8).strokeBorder(lcd.accent.opacity(0.8), lineWidth: 2)
            )
            .padding(.horizontal, 16)
        }
        .animation(DexMotion.overlay, value: page)
    }

    /// The closing line with the name resolved — `explorer` where the ask was
    /// skipped, which is what `VinoName.fallback` is for.
    private var closingLine: String {
        let name = VinoName.clean(displayName) ?? VinoName.fallback
        return Orientation.closing.replacingOccurrences(of: "{name}", with: name)
    }

    private func button(_ text: String, accent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(DexFont.retro(11))
                .tracking(1.5)
                .foregroundStyle(accent ? (lcd.isLight ? .white : .black) : lcd.subtext)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(accent ? lcd.accent : lcd.surface))
                .overlay(
                    Capsule().strokeBorder(accent ? lcd.accent : lcd.surfaceEdge, lineWidth: 2)
                )
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
    }
}
#endif
