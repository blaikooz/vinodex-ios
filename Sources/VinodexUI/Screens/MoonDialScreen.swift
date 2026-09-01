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
    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }

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
    ///
    /// ## Larger, and still one page (0.7.0, J1)
    ///
    /// J1 asks for a bigger UI here; K2 above says the page must not need to
    /// scroll. Those are only in conflict if "bigger" means a fixed number of
    /// points added to everything, which is what a naive read of J1 would do —
    /// and it is the same hard floor K2 was written to keep out, arrived at from
    /// the other side.
    ///
    /// So nothing here grows by a constant. Everything grows by `growth`, which
    /// is a measurement of the slack the page actually has, on the two axes that
    /// consume it: the LCD's height and the text scale. On the shortest
    /// supported screen at HUGE text `growth` is 0 and every number below
    /// resolves to exactly what 0.6.9 shipped — the fit K2 established is
    /// therefore not merely preserved, it is the *floor case of the same
    /// arithmetic*. On a tall phone at SMALL text it is 1 and the page uses the
    /// room it was leaving in the `Spacer` at the bottom.
    ///
    /// This is why there is still no `minHeight` anywhere on this screen.
    public var body: some View {
        ZStack {
            DexScreenBackground()

            GeometryReader { geo in
                let grow = Self.growth(geo.size.height)
                VStack(spacing: 12 + 8 * grow) {
                    Text(dateLine)
                        .font(DexFont.retro(11 + 3 * grow))
                        .tracking(1)
                        .foregroundStyle(lcd.subtext)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)

                    dial(in: geo.size.height, grow: grow)

                    dayType(grow: grow)
                    verdict(grow: grow)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
        }
    }

    /// How much room this page has to spare, from 0 (none) to 1 (plenty).
    ///
    /// The rule lives in `PageRoom` (Core) rather than here because all three of
    /// J's pages need it and because Core is the half of this app that
    /// `swift test` can actually see — VinodexUI compiles to nothing off-device,
    /// so a layout rule written here is a rule no gate can check. See
    /// `PageRoomTests`.
    private static func growth(_ pageHeight: CGFloat) -> CGFloat {
        CGFloat(PageRoom.growth(pageHeight: Double(pageHeight)))
    }

    /// The illustration: the day's glyph in a ring tinted by the verdict.
    ///
    /// Sized off the page (0.6.9, K2) rather than at the flat 150 it carried:
    /// 0.30 of the LCD's height, clamped so it neither disappears on a short
    /// screen nor grows past what it was on a tall one. Everything inside is a
    /// fraction of that, so the ring, the ticks and the glyph scale as one
    /// piece — the ticks used to sit at a hardcoded `-75`, which is the old
    /// radius written twice.
    private func dial(in pageHeight: CGFloat, grow: CGFloat) -> some View {
        // **Larger where there is room** (0.7.0, J1). Both the fraction and the
        // ceiling ride `grow`, and both collapse to 0.6.9's 0.30/150 when it is
        // zero. The 104 floor is untouched — it is what keeps a short screen
        // readable, and raising it is precisely the hard floor K2 forbids.
        let size = min(max(pageHeight * (0.30 + 0.09 * grow), 104), 150 + 64 * grow)
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
                // The drawn day faces since 0.9.43 — grape bunch, blossom,
                // vine leaf, taproot — flattened to the day's tint exactly as
                // the SF symbols were. FRUIT's `applelogo` stand-in retires
                // with them: a literal Apple trademark had no business on a
                // biodynamic dial.
                DexChromeGlyph(
                    artStem,
                    symbol: symbol,
                    size: size * 0.27,
                    weight: .semibold,
                    tint: tint,
                    flatten: tint
                )
                Text(day.rawValue)
                    .font(DexFont.retro(16 + 5 * grow))
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

    /// The drawn face beside each fallback symbol (0.9.43) — total, so the
    /// symbols above are reachable only if a master goes missing from the
    /// bundle.
    private var artStem: String {
        switch day {
        case .fruit: "moonday-fruit"
        case .flower: "moonday-flower"
        case .leaf: "moonday-leaf"
        case .root: "moonday-root"
        }
    }

    private func dayType(grow: CGFloat) -> some View {
        VStack(spacing: 8 + 5 * grow) {
            row("DAY TYPE", "\(day.rawValue) DAY", grow: grow)
            row("ELEMENT", day.element, grow: grow)
            row("MOON IN", MoonCalendar.zodiac(for: now), grow: grow)
        }
        .padding(.horizontal, 12 + 4 * grow)
        .padding(.vertical, 12 + 6 * grow)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
        )
    }

    private func row(_ label: String, _ value: String, grow: CGFloat) -> some View {
        HStack(spacing: 10) {
            // Guarded like every other block on this page (0.7.1, A4). The
            // file's own header states the rule — everything `lineLimit`-ed
            // with a `minimumScaleFactor` so a larger text step shrinks words
            // into the rows they have — and the label was the one exception.
            // At HUGE on the shortest device, MOON IN / SAGITTARIUS needs
            // 276.4pt in a 273.7pt card and DAY TYPE / FLOWER DAY needs 275.1:
            // the value can shrink and the label could not, so the *label* was
            // what broke, to DAY / TYPE.
            Text(label)
                .font(DexFont.retro(10 + 3 * grow))
                .tracking(1)
                .foregroundStyle(lcd.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 8)
            Text(value)
                .font(DexFont.retro(11 + 3.5 * grow))
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
    private func verdict(grow: CGFloat) -> some View {
        VStack(spacing: 10 + 4 * grow) {
            // The wine glass with its check, and the raised hand (0.9.43) —
            // the verdict pair from the same drop as the day faces.
            DexChromeGlyph(
                day.isGoodForDrinking ? "moonday-drink" : "moonday-hold",
                symbol: day.isGoodForDrinking ? "checkmark.seal.fill" : "hand.raised.fill",
                size: 28 + 12 * grow,
                weight: .bold,
                tint: tint,
                flatten: tint
            )

            Text(day.verdict)
                .font(DexFont.retro(15 + 5 * grow))
                .tracking(1)
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
        }
        .padding(14 + 6 * grow)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.1)))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(tint.opacity(0.5), lineWidth: 2)
        )
    }
}
#endif
