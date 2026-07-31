#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The passport: what the tried shelf adds up to, plus the stamps.
///
/// A dumb renderer over `Passport.compute` — every number on this screen is
/// produced (and tested) in Core. The screen owns nothing but layout.
public struct PassportScreen: View {
    @State private var bookmarks = BookmarkStore.shared
    @State private var streak = StreakStore.shared
    @State private var progress = QuizProgress.shared
    private let db = WineDatabase.shared

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init() {}

    private var passport: Passport {
        Passport.compute(
            tried: bookmarks.ids(on: .tried),
            in: db,
            bestStreak: streak.best,
            highestTier: progress.highestUnlocked
        )
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    public var body: some View {
        let passport = passport

        ZStack {
            DexScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("TASTINGS") {
                        LazyVGrid(columns: columns, spacing: 8) {
                            statTile(
                                symbol: "circle.grid.3x3.fill",
                                tint: Color(dexHex: "#a855f7"),
                                value: "\(passport.triedGrapes)/\(passport.totalGrapes)",
                                label: "GRAPES"
                            )
                            statTile(
                                symbol: "wineglass.fill",
                                tint: Color(dexHex: "#f97316"),
                                value: "\(passport.triedStyles)/\(passport.totalStyles)",
                                label: "STYLES"
                            )
                            statTile(
                                symbol: "flag.fill",
                                tint: Dex.yellow,
                                value: "\(passport.countries)",
                                label: "COUNTRIES"
                            )
                            statTile(
                                symbol: "map.fill",
                                tint: Dex.blue,
                                value: "\(passport.continents.count)/6",
                                label: "CONTINENTS"
                            )
                        }
                    }

                    section("BY COLOUR") {
                        VStack(spacing: 10) {
                            progressRow(
                                label: "RED",
                                done: passport.byColor[.red] ?? 0,
                                total: passport.colorTotals[.red] ?? 0,
                                fill: Dex.red500
                            )
                            progressRow(
                                label: "WHITE",
                                done: passport.byColor[.white] ?? 0,
                                total: passport.colorTotals[.white] ?? 0,
                                fill: Color(dexHex: "#d6d3d1")
                            )
                        }
                    }

                    section("BY RARITY") {
                        VStack(spacing: 10) {
                            ForEach(RarityLabel.allCases, id: \.self) { rarity in
                                progressRow(
                                    label: rarity.rawValue,
                                    done: passport.byRarity[rarity] ?? 0,
                                    total: passport.rarityTotals[rarity] ?? 0,
                                    fill: rarityTint(rarity)
                                )
                            }
                        }
                    }

                    section("STAMPS") {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(passport.badges) { badge in
                                badgeTile(badge)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentMargins(12, for: .scrollContent)
        }
    }

    private func rarityTint(_ rarity: RarityLabel) -> Color {
        switch rarity {
        case .common: Dex.green500
        case .uncommon: Dex.blue
        case .rare: Color(dexHex: "#a855f7")
        case .noble: Dex.yellow
        // Cursed gold — the tier above nobility (0.6.2, A1).
        case .godforsaken: Color(dexHex: "#ca8a04")
        }
    }

    // MARK: Furniture

    /// The settings panels' section heading, verbatim — same size, same rule.
    private func section<C: View>(
        _ title: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(DexFont.retro(14))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)
                .padding(.bottom, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { lcd.accent.opacity(0.45).frame(height: 2) }
            content()
        }
    }

    /// The DATA panel's stat tile, at passport duty.
    private func statTile(symbol: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(DexFont.retro(15))
                    .foregroundStyle(lcd.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(DexFont.mono(15))
                    .foregroundStyle(lcd.subtext)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(0.45), lineWidth: 1)
        )
    }

    /// A labelled progress bar with the honest fraction at its end — the bar
    /// gives the shape, the numbers give the truth.
    private func progressRow(label: String, done: Int, total: Int, fill: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(DexFont.mono(17))
                .foregroundStyle(lcd.text)
                .frame(width: 92, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(lcd.well)
                    if total > 0, done > 0 {
                        Capsule()
                            .fill(fill)
                            .frame(width: max(geo.size.width * CGFloat(done) / CGFloat(total), 8))
                    }
                }
            }
            .frame(height: 10)
            .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 1))

            Text("\(done)/\(total)")
                .font(DexFont.mono(16))
                .foregroundStyle(lcd.subtext)
                .frame(width: 52, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func badgeTile(_ badge: Passport.Badge) -> some View {
        VStack(spacing: 8) {
            Image(systemName: badge.earned ? badgeSymbol(badge.id) : "lock.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(badge.earned ? badgeTint(badge.id) : lcd.disabledText)
                .frame(height: 30)
            Text(badge.title)
                .font(DexFont.retro(10))
                .tracking(1)
                .foregroundStyle(badge.earned ? lcd.text : lcd.disabledText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(badge.blurb)
                .font(DexFont.mono(15))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    badge.earned ? badgeTint(badge.id).opacity(0.5) : lcd.surfaceEdge,
                    lineWidth: badge.earned ? 2 : 1
                )
        )
        .opacity(badge.earned ? 1 : 0.75)
    }

    private func badgeSymbol(_ id: String) -> String {
        switch id {
        case "firstSip": "drop.fill"
        case "tenBottles": "shippingbox.fill"
        case "allNoble": "crown.fill"
        case "regionComplete": "map.fill"
        case "streakWeek": "flame.fill"
        case "sommelier": "graduationcap.fill"
        default: "seal.fill"
        }
    }

    private func badgeTint(_ id: String) -> Color {
        switch id {
        case "firstSip": Dex.red500
        case "tenBottles": Dex.blue
        case "allNoble": Dex.yellow
        case "regionComplete": Dex.green500
        case "streakWeek": Color(dexHex: "#f97316")
        case "sommelier": Color(dexHex: "#a855f7")
        default: lcd.accent
        }
    }
}
#endif
