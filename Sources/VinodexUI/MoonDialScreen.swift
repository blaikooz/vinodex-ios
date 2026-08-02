#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import VinodexCore

/// The moon dial: today's date, what kind of day it is, whether that is a good
/// day to drink, and a line about it.
///
/// Deliberately a readout with no interaction. The web reference
/// (`MoonDialScreen.tsx`) drove a draggable dial through the lunar month, which
/// is a lot of machinery in front of a single fact — the only thing anyone
/// wants from it is whether tonight is a good night. Everything here answers
/// that in one screenful, and the dial is reduced to an illustration of the
/// answer rather than a control.
public struct MoonDialScreen: View {
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    /// Captured once so the screen cannot change under the reader if it is left
    /// open across midnight — and so every value below agrees with every other.
    private let now: Date

    public init(now: Date = Date()) {
        self.now = now
    }

    private var day: MoonDay { MoonCalendar.day(for: now) }

    private var tint: Color {
        day.isGoodForDrinking ? Dex.green : Dex.amber400
    }

    private var dateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE d MMMM yyyy"
        return f.string(from: now).uppercased()
    }

    /// **One page, no scroll** (0.6.9, K2).
    ///
    /// This is the same bug class 0.6.7's I1 fixed in the chassis, arrived at
    /// from the other end. There, a fixed page reported a height larger than
    /// the display and the *LCD* grew to fit it; the fix was to make the LCD's
    /// size the housing's and clip. So the LCD now genuinely is a fixed box —
    /// which means "make the page fit" has to be answered here, by the page
    /// actually fitting, rather than by anything giving way. Whatever overflows
    /// is now silently cut off at the bezel.
    ///
    /// Two mechanisms, and neither of them is a `minHeight` floor:
    ///
    /// 1. The dial is sized as a **fraction of the height it is given**
    ///    (`GeometryReader`), not at a fixed 150pt. It is the one element on
    ///    the page with no information in its size, so it is the one that
    ///    should absorb a short screen — on the smallest supported device it
    ///    comes out around 105pt and still reads as a dial.
    /// 2. Every text block is `lineLimit`-ed with a `minimumScaleFactor`, so a
    ///    larger step in SETTINGS > TEXT SIZE shrinks the words into the rows
    ///    they already have instead of adding rows. That is the axis that
    ///    actually breaks a fixed page: `TextScale` runs to HUGE, and at HUGE
    ///    the untouched version was a screen and a half.
    ///
    /// A floor would defeat the point twice over — it is what makes a page
    /// unfittable, and inside 0.6.7's clipping LCD it would not scroll to
    /// reveal what it pushed out, it would simply hide it.
    public var body: some View {
        ZStack {
            DexScreenBackground()

            GeometryReader { geo in
                VStack(spacing: 12) {
                    Text(dateLine)
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .foregroundStyle(lcd.subtext)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)

                    dial(in: geo.size.height)

                    dayType
                    verdict
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
        }
    }

    /// The illustration: the day's glyph in a ring tinted by the verdict.
    ///
    /// Sized off the page (0.6.9, K2) rather than at the flat 150 it carried:
    /// 0.30 of the LCD's height, clamped so it neither disappears on a short
    /// screen nor grows past what it was on a tall one. Everything inside is a
    /// fraction of that, so the ring, the ticks and the glyph scale as one
    /// piece — the ticks used to sit at a hardcoded `-75`, which is the old
    /// radius written twice.
    private func dial(in pageHeight: CGFloat) -> some View {
        let size = min(max(pageHeight * 0.30, 104), 150)
        let radius = size / 2

        return ZStack {
            Circle()
                .strokeBorder(tint.opacity(0.35), lineWidth: 3)
                .frame(width: size, height: size)

            // Four ticks, one per day type, with today's lit. Enough to say
            // "this is a cycle and you are here" without being a control.
            ForEach(Array(MoonDay.allCases.enumerated()), id: \.element.id) { index, mark in
                Circle()
                    .fill(mark == day ? tint : lcd.subtext.opacity(0.4))
                    .frame(width: mark == day ? size * 0.08 : size * 0.047)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(Double(index) / Double(MoonDay.allCases.count) * 360))
            }

            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.27, weight: .semibold))
                    .foregroundStyle(tint)
                Text(day.rawValue)
                    .font(DexFont.retro(16))
                    .tracking(2)
                    .foregroundStyle(lcd.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(height: size + 18)
    }

    /// All iOS 17-safe — see KNOWN-ISSUES on symbols with a later OS floor
    /// rendering blank rather than failing to compile.
    private var symbol: String {
        switch day {
        case .fruit: "applelogo"
        case .flower: "camera.macro"
        case .leaf: "leaf.fill"
        case .root: "mountain.2.fill"
        }
    }

    private var dayType: some View {
        VStack(spacing: 8) {
            row("DAY TYPE", "\(day.rawValue) DAY")
            row("ELEMENT", day.element)
            row("MOON IN", MoonCalendar.zodiac(for: now))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
        )
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(DexFont.retro(10))
                .tracking(1)
                .foregroundStyle(lcd.subtext)
            Spacer(minLength: 8)
            Text(value)
                .font(DexFont.retro(11))
                .tracking(1)
                .foregroundStyle(lcd.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    /// The headline. Big, tinted, and unambiguous — it is the one thing the
    /// screen exists to say.
    ///
    /// **The prose under it is gone (0.6.9, K1).** `day.summary` was a sentence
    /// restating the verdict directly above it in longer words, and the quote
    /// block under *that* (`MoonCalendar.quote(for:)`) was a second one. The
    /// screen's whole contract is one fact in one screenful; two paragraphs of
    /// elaboration were most of what made it not fit (K2). The verdict line
    /// stays because it is the answer.
    ///
    /// `MoonCalendar.quote(for:)` is left in Core rather than deleted with its
    /// only call site: it is data with a deterministic per-day rule and its own
    /// tests, and the next surface that wants a line about today should have it
    /// to hand.
    private var verdict: some View {
        VStack(spacing: 10) {
            Image(systemName: day.isGoodForDrinking ? "checkmark.seal.fill" : "hand.raised.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(tint)

            Text(day.verdict)
                .font(DexFont.retro(15))
                .tracking(1)
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.1)))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(tint.opacity(0.5), lineWidth: 2)
        )
    }
}
#endif
