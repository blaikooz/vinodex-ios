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

    public var body: some View {
        ZStack {
            DexScreenBackground()

            ScrollView {
                VStack(spacing: 16) {
                    Text(dateLine)
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .foregroundStyle(lcd.subtext)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    dial

                    dayType
                    verdict
                    quote
                }
                .frame(maxWidth: .infinity)
                .padding(18)
            }
        }
    }

    /// The illustration: the day's glyph in a ring tinted by the verdict.
    private var dial: some View {
        ZStack {
            Circle()
                .strokeBorder(tint.opacity(0.35), lineWidth: 3)
                .frame(width: 150, height: 150)

            // Four ticks, one per day type, with today's lit. Enough to say
            // "this is a cycle and you are here" without being a control.
            ForEach(Array(MoonDay.allCases.enumerated()), id: \.element.id) { index, mark in
                Circle()
                    .fill(mark == day ? tint : lcd.subtext.opacity(0.4))
                    .frame(width: mark == day ? 12 : 7)
                    .offset(y: -75)
                    .rotationEffect(.degrees(Double(index) / Double(MoonDay.allCases.count) * 360))
            }

            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(tint)
                Text(day.rawValue)
                    .font(DexFont.retro(16))
                    .tracking(2)
                    .foregroundStyle(lcd.text)
            }
        }
        .frame(height: 168)
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
                .font(DexFont.retro(9))
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
                .fixedSize(horizontal: false, vertical: true)

            Text(day.summary)
                .font(DexFont.mono(18))
                .foregroundStyle(lcd.bodyText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.1)))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(tint.opacity(0.5), lineWidth: 2)
        )
    }

    private var quote: some View {
        Text(MoonCalendar.quote(for: now))
            .font(DexFont.mono(19))
            .foregroundStyle(lcd.text)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
            .padding(.vertical, 10)
            .background(alignment: .leading) { tint.frame(width: 4) }
            .background(lcd.accent.opacity(0.06))
    }
}
#endif
