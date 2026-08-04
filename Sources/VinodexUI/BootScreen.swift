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
///
/// **Scaled up to fill the panel in 0.7.5 (A6), and both of 0.7.3a's rules
/// survive it.** It is still inside the LCD, for the reason at the top of this
/// comment, and it is still skippable on a tap anywhere. **The timing pin does
/// not move**: `BootSequence.duration` is 1.9s, `BootSequenceTests.brief` still
/// asserts it is under two, and nothing below is a timing constant — A6 is
/// entirely a question of type sizes, and a bigger POST that ran longer would be
/// a worse POST, not a larger one.
///
/// The sizes are what they are because two typefaces with very different
/// metrics share this screen. `VT323` (the `mono` face) advances about 0.4em,
/// so a line's nineteen characters of label and result cost ~0.4 × 19 × size —
/// at 28pt that is ~213 of the ~277pt the LCD offers inside the padding, which
/// leaves five or six dots of leader. `PressStart2P` (the `retro` face) advances
/// a full em, so the header's nineteen characters cost nineteen times its size:
/// 14pt is the ceiling on a 393pt phone, and the reason it is not larger than
/// the lines it introduces. Every one of the three now carries a `lineLimit(1)`
/// and a `minimumScaleFactor` it did not need at the old sizes, because at HUGE
/// the user's own `TextScale` multiplies all of this again and the failure at
/// the top of that range should be a smaller line, not a wrapped one.
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

    // MARK: Type scale (0.7.5, A6)
    //
    // Named rather than inline so the four sizes that have to move together
    // can be seen together. The arithmetic behind each is in this type's doc
    // comment; what matters here is that they are *nominal* sizes — `DexFont`
    // puts them through `TextScale` afterwards, so these are the numbers at
    // SETTINGS > TEXT SIZE = default and every one of them can be up to a
    // third larger on a real device.

    /// 11 → 14, and 14 is the ceiling rather than a taste. `PressStart2P`
    /// advances a full em and `"VINODEX BIOS v0.7.5"` is nineteen characters,
    /// so the header costs 19 × size plus 19pt of tracking: 285pt at 14 against
    /// the ~297 the LCD offers inside the padding, and 304 at 15 — over, and
    /// permanently riding `minimumScaleFactor` even at the default text step.
    /// The scale factor is there for the narrower phones and the larger steps,
    /// not to absorb a size that never fitted.
    private static let headerSize: CGFloat = 14
    /// 16 → 28. The POST's voice, and the whole of A6: at 16 the sequence sat
    /// in the top-left corner of a 586pt panel reading like a debug log, and at
    /// 28 it is what the display is doing.
    private static let lineSize: CGFloat = 28
    /// 8 → 12. Grown with the rest, but deliberately still the smallest thing
    /// on the screen — it is an instruction, not part of the POST.
    private static let hintSize: CGFloat = 12
    /// 14 → 20, tracking the line height so the block stays a table rather
    /// than becoming a list of separated rows.
    private static let lineGap: CGFloat = 20
    /// 22 → 24. Barely moved, on purpose: the padding is what stops the text
    /// touching the bezel, and every point spent here is a point off the width
    /// the dot leader lives in.
    private static let inset: CGFloat = 24

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

            VStack(alignment: .leading, spacing: Self.lineGap) {
                Text(header)
                    .font(DexFont.retro(Self.headerSize))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(lcd.accent)

                Rectangle()
                    .fill(lcd.accent.opacity(0.4))
                    .frame(height: 3)

                ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                    if index < shown {
                        HStack(spacing: 10) {
                            Text(line.label)
                                .font(DexFont.mono(Self.lineSize))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .foregroundStyle(lcd.subtext)
                            // The dot leader a POST screen has. A single
                            // repeated glyph in a flexible frame rather than a
                            // computed run of periods: the width is whatever is
                            // left, and nothing has to measure a font to know it.
                            //
                            // Forty is still plenty at the 0.7.5 size — the
                            // count only has to exceed what will ever fit, and
                            // a bigger face fits fewer, not more.
                            Text(String(repeating: ".", count: 40))
                                .font(DexFont.mono(Self.lineSize))
                                .foregroundStyle(lcd.subtext.opacity(0.35))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .layoutPriority(-1)
                            Text(line.result)
                                .font(DexFont.mono(Self.lineSize))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .foregroundStyle(lcd.text)
                        }
                        .transition(.opacity)
                    }
                }

                Spacer(minLength: 0)

                Text("TAP TO SKIP")
                    .font(DexFont.retro(Self.hintSize))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(lcd.subtext.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(Self.inset)
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
