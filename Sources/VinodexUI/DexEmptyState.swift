#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// Why a screen has nothing on it.
public enum DexDataState: Sendable {
    /// The database is healthy. The query, or the filter, or the day's shuffle
    /// simply produced nothing — an answer, not a fault.
    case noResults
    /// Entries decoded, but the loader reported failures alongside them. A
    /// screen showing nothing may be showing the truth about a short catalog.
    case partialLoad
    /// Nothing decoded at all. No screen in the app can do its job.
    case loadFailed
}

public extension WineDatabase {
    /// What an empty screen means (AUDIT M2).
    ///
    /// Deliberately **not** a function of the search string. `SearchStateStore`
    /// persists queries across navigation, so the old
    /// `!decodeErrors.isEmpty && search.isEmpty` gate suppressed the error on
    /// exactly the path that produces the reported symptom: come back to a list
    /// with a query still in the box, and a database that failed to load reads
    /// as "NO DATA FOUND" — a no-results message — sending you hunting for a
    /// typo in a search that was never the problem.
    var dataState: DexDataState {
        if decodeErrors.isEmpty { return .noResults }
        return entries.isEmpty ? .loadFailed : .partialLoad
    }
}

/// A screen's own "found nothing" panel, with the truth about the database
/// behind it.
///
/// Every list-shaped screen has some version of "nothing here", and before this
/// only `EncyclopediaListScreen` knew that a failed load was a different thing
/// from an empty result — so a build with no database answered "NOTHING
/// MATCHES" on the chip filter and "NOTHING TODAY" on the daily grape, both
/// of which read as facts about wine rather than about the build (AUDIT M2).
///
/// Wrap the screen's existing panel; it is shown unchanged on a healthy
/// database, footnoted on a partial load, and replaced outright when nothing
/// decoded.
public struct DexEmptyState<Empty: View>: View {
    private let db: WineDatabase
    private let empty: () -> Empty

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(db: WineDatabase = .shared, @ViewBuilder empty: @escaping () -> Empty) {
        self.db = db
        self.empty = empty
    }

    public var body: some View {
        switch db.dataState {
        case .noResults:
            empty()
        case .partialLoad:
            // The screen's own answer still stands — the query really did match
            // nothing — but a catalog that is missing records is a plausible
            // reason for that, and only the DEV panel knew it.
            VStack(spacing: 14) {
                empty()
                note(
                    "SOME RECORDS FAILED TO LOAD",
                    "The catalog is incomplete. See SETTINGS > DEV for details."
                )
            }
        case .loadFailed:
            loadFailedPanel
        }
    }

    /// The truth when the database itself failed to load (0.6.3, item 1 —
    /// AUDIT H2/M2). "NO DATA FOUND" reads as a no-results message, which sent
    /// anyone hitting a broken build hunting for a typo in their search; the
    /// detail lives in the DEV panel, and this points there.
    private var loadFailedPanel: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Dex.red500)
            Text("DATA LOAD ERROR")
                .font(DexFont.retro(11))
                .foregroundStyle(Dex.red500)
            Text("The wine database failed to load. See SETTINGS > DEV for details.")
                .font(DexFont.mono(16))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func note(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(DexFont.retro(10))
                    .tracking(1)
            }
            .foregroundStyle(Dex.yellow)
            Text(detail)
                .font(DexFont.mono(16))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(Dex.yellow.opacity(0.5), lineWidth: 2)
        )
    }
}
#endif
