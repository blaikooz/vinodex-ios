#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// A titled block: an accent heading over a rule, with its content beneath.
///
/// Six copies before this, in four visual treatments that had drifted apart
/// rather than been chosen (AUDIT **M28**):
///
/// - `EntryDetailScreen` and `ContinentScreen` — 15pt semibold glyph,
///   `retro(10)` at tracking 1.5, and a rule hardcoded to `#166534`.
/// - `CountryScreen` — 14pt bold glyph, `retro(12)` at tracking 1, rule from
///   `lcd.accent.opacity(0.4)`.
/// - `StateScreen` — the CountryScreen treatment, inlined rather than even
///   having a helper to copy.
/// - `PassportScreen` — no glyph, `retro(14)` at tracking 1.5, rule from
///   `lcd.accent.opacity(0.45)`.
///
/// The hardcoded `#166534` is the reason this is a bug and not only untidy: a
/// fixed dark green under a heading is invisible against a light theme's page,
/// the same failure as **H5**, **M14** and **L30** before it. Every rule here
/// comes off `lcd.accent` and follows the theme.
///
/// Two ranks rather than one, because there is a real distinction underneath
/// the accidental ones: `.block` heads a section *within* a page and carries a
/// glyph, `.screen` heads a whole screen and does not. Three type sizes
/// collapse to two, and both are declared instead of inherited.
struct DexSection<Content: View, Accessory: View>: View {
    enum Rank {
        /// A section within a page — the INFO, CHARACTERISTICS, STATES kind.
        case block
        /// A heading for a whole screen's worth of content, as the passport's
        /// TASTINGS and STAMPS are.
        case screen
    }

    private let title: String
    private let symbol: String?
    private let rank: Rank
    private let content: Content
    private let accessory: Accessory

    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }

    init(
        _ title: String,
        symbol: String? = nil,
        rank: Rank = .block,
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.symbol = symbol
        self.rank = rank
        self.content = content()
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: rank == .screen ? 12 : 10) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(lcd.accent)
                }
                Text(title)
                    .font(DexFont.retro(rank == .screen ? 14 : 11))
                    .tracking(1.5)
                    .foregroundStyle(lcd.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                accessory
            }
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) { lcd.accent.opacity(0.45).frame(height: 2) }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // A screen heading's content runs to the end of the screen, so the
        // tail spacing is the scroll view's business rather than this one's.
        .padding(.bottom, rank == .screen ? 0 : 22)
    }
}

extension DexSection where Accessory == EmptyView {
    /// The common case: no trailing control beside the heading.
    init(
        _ title: String,
        symbol: String? = nil,
        rank: Rank = .block,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title, symbol: symbol, rank: rank, content: content, accessory: { EmptyView() })
    }
}
#endif
