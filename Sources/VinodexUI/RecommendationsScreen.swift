#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// **YOU MIGHT LIKE, in full** (0.8.91, B3).
///
/// The passport's strip shows `PalateProfile.recommendationStrip` rows and this
/// is what SHOW ALL opens: the same ranking with the cap removed. Not a second
/// query — `allRecommendations` is `recommendations(index:limit:)` with the
/// prefix taken off, and `InsightTests.recommendationsAreTheHead` holds the two
/// together, because a SHOW ALL that reshuffles reads as the whole feature being
/// arbitrary.
///
/// **Rows are `EntryTileView`, not the passport's `LinkedRow`.** The strip is a
/// pointer inside a page about something else, so a compact linked row is right
/// there; this page *is* the list, so it uses the row every other listing in the
/// app uses — which also means the paywall treatment and §B2's tried border
/// arrive for free rather than being reimplemented. (No recommendation can be
/// tried, by construction, so the border is dead here — the rest of the
/// treatment is not.)
///
/// The score is not printed. It is an internal 0-100 that
/// `PalateProfile.recommendationFloor` already gates on, and putting it on a row
/// would invite the reader to compare a 71 with a 68 as though the difference
/// meant something the arithmetic can support.
public struct RecommendationsScreen: View {
    private let onSelect: (WineEntry) -> Void

    public init(onSelect: @escaping (WineEntry) -> Void) {
        self.onSelect = onSelect
    }

    @State private var bookmarks = BookmarkStore.shared
    @State private var access = AccessStore.shared
    private let db = WineDatabase.shared

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    private var picks: [WineEntry] {
        let index = DiscoveryIndex(tried: bookmarks.ids(on: .tried), in: db)
        return PalateProfile(index: index).allRecommendations(index: index)
    }

    public var body: some View {
        let picks = picks

        return ZStack {
            DexScreenBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    header(count: picks.count)

                    if picks.isEmpty {
                        // The same judgement the strip makes by withholding
                        // itself: a thin profile is not a failure, it is a
                        // device that has not been told enough yet. Said out
                        // loud here, because unlike the strip this page was
                        // asked for and cannot simply not appear.
                        DexEmptyState {
                            Text("NOTHING YET")
                                .font(DexFont.retro(14))
                                .tracking(1.5)
                                .foregroundStyle(lcd.accent)
                            Text(
                                """
                                Mark a few more entries tried and the device \
                                will start guessing. It would rather say \
                                nothing than guess from two.
                                """
                            )
                            .font(DexFont.mono(18))
                            .foregroundStyle(lcd.bodyText)
                            .multilineTextAlignment(.center)
                        }
                    } else {
                        ForEach(picks) { entry in
                            EntryTileView(
                                entry: entry,
                                palette: db.palette,
                                locked: access.isLocked(entry, in: db),
                                tried: bookmarks.contains(entry.id, on: .tried)
                            ) {
                                onSelect(entry)
                            }
                        }
                    }
                }
                .padding(10)
            }
        }
    }

    private func header(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOU MIGHT LIKE")
                .font(DexFont.retro(14))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)
                .padding(.bottom, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { lcd.accent.opacity(0.45).frame(height: 2) }

            Text(
                count == 0
                    ? "Ranked against what you have tasted."
                    : "\(count) untried, ranked against what you have tasted."
            )
            .font(DexFont.mono(16))
            .foregroundStyle(lcd.subtext)
        }
        .padding(.bottom, 4)
    }
}
#endif
