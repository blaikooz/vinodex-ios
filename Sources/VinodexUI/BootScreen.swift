#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The power-on self test (0.7.3, A1).
///
/// **Inside the LCD, not over the whole device.** A BIOS is something a screen
/// does; the plastic around it has no boot sequence. Drawing this over the
/// chassis would dim the bezel, island and footer, which — as the note beside
/// `RootView`'s upgrade prompt puts it — reads as the device losing power, and
/// this is the one moment in the app's life when the device is doing the exact
/// opposite.
///
/// **What it claims is real.** The entry count is the catalog's, the version is
/// `FirmwareCatalog`'s through `AppVersion` (A1 reads F3), and both come from
/// `BootSequence` in Core so a test can pin them. The memory figure is the one
/// deliberate joke; `BootSequence` says why.
///
/// **Skippable, and brief enough not to need to be.** Tapping ends it
/// immediately. The whole run is under two seconds — `BootSequenceTests` holds
/// that line, because a boot animation is a tax on every single launch forever.
public struct BootScreen: View {
    /// Called when the POST finishes or is skipped.
    let onFinish: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    /// How many lines have been revealed.
    @State private var shown = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lines: [BootLine]
    private let header: String

    public init(entries: Int, verbose: Bool, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        self.lines = BootSequence.lines(
            entries: entries,
            version: AppVersion.current,
            verbose: verbose
        )
        self.header = BootSequence.header(version: AppVersion.current)
    }

    public var body: some View {
        ZStack {
            lcd.screen

            VStack(alignment: .leading, spacing: 14) {
                Text(header)
                    .font(DexFont.retro(11))
                    .tracking(1)
                    .foregroundStyle(lcd.accent)

                Rectangle()
                    .fill(lcd.accent.opacity(0.4))
                    .frame(height: 2)

                ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                    if index < shown {
                        HStack(spacing: 8) {
                            Text(line.label)
                                .font(DexFont.mono(16))
                                .foregroundStyle(lcd.subtext)
                            // The dot leader a POST screen has. A single
                            // repeated glyph in a flexible frame rather than a
                            // computed run of periods: the width is whatever is
                            // left, and nothing has to measure a font to know it.
                            Text(String(repeating: ".", count: 40))
                                .font(DexFont.mono(16))
                                .foregroundStyle(lcd.subtext.opacity(0.35))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .layoutPriority(-1)
                            Text(line.result)
                                .font(DexFont.mono(16))
                                .foregroundStyle(lcd.text)
                        }
                        .transition(.opacity)
                    }
                }

                Spacer(minLength: 0)

                Text("TAP TO SKIP")
                    .font(DexFont.retro(8))
                    .tracking(1)
                    .foregroundStyle(lcd.subtext.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .contentShape(Rectangle())
        .onTapGesture { onFinish() }
        .task { await run() }
        // The POST is the one thing on screen; announcing it as a unit stops
        // VoiceOver reading a half-drawn table line by line as it fills.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Starting up")
    }

    private func run() async {
        // Reduce Motion skips the reveal but not the screen: the boot state is
        // information, not decoration, and the version is genuinely the answer
        // to "what am I running". It appears whole and holds for the settle.
        guard !reduceMotion else {
            shown = lines.count
            try? await Task.sleep(for: .seconds(BootSequence.settle))
            onFinish()
            return
        }

        var elapsed: TimeInterval = 0
        for (index, line) in lines.enumerated() {
            let wait = max(line.at - elapsed, 0)
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            elapsed = line.at
            withAnimation(.easeOut(duration: 0.12)) { shown = index + 1 }
            Sounds.tap()
        }
        try? await Task.sleep(for: .seconds(BootSequence.settle))
        guard !Task.isCancelled else { return }
        onFinish()
    }
}
#endif
