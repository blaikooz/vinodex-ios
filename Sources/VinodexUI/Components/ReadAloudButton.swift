#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// **The read-aloud control** (0.9.53, maintainer order): one full-width
/// button under an INFO section's text, everywhere an info section exists —
/// entries, countries, continents. A shared view so the label, face and
/// speaking state cannot drift between screens.
///
/// Reads through `VinoVoice`, whose `speak(_:)` is a toggle — a second tap
/// stops — and whose voice ladder (Reed on device, Daniel on the simulator)
/// lives with it.
struct ReadAloudButton: View {
    let text: String

    @State private var vinoVoice = VinoVoice.shared
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    var body: some View {
        Button {
            Haptics.select()
            vinoVoice.speak(text)
        } label: {
            HStack(spacing: 10) {
                DexChromeGlyph(
                    "sounds-on",
                    symbol: vinoVoice.speaking ? "speaker.wave.2.fill" : "speaker.wave.2",
                    size: 22,
                    tint: vinoVoice.speaking ? lcd.onAccent : lcd.accent
                )
                Text(vinoVoice.speaking ? "STOP READING" : "READ ALOUD")
                    .font(DexFont.retro(12))
                    .tracking(2)
                    .foregroundStyle(vinoVoice.speaking ? lcd.onAccent : lcd.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(vinoVoice.speaking ? AnyShapeStyle(lcd.accent) : AnyShapeStyle(lcd.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(lcd.accent.opacity(0.7), lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        .accessibilityLabel(vinoVoice.speaking ? "Stop reading aloud" : "Read this section aloud")
    }
}
#endif
