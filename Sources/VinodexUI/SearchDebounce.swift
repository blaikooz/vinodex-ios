#if canImport(SwiftUI) && canImport(UIKit)
import Foundation

/// How long a screen waits before acting on a changed query (AUDIT M5).
///
/// Long enough that a burst of typing produces one query rather than one per
/// character; short enough that a deliberate single keystroke still feels
/// immediate. The cost being avoided is not really the filtering — that is
/// indexed now, see `WineDatabase.entries(matching:)` — it is rebuilding the
/// row tree, where every row resolves an icon and a flag and a set of chips.
private let searchDebounce = Duration.milliseconds(180)

/// The debounce every search screen shares, called at the top of a
/// `.task(id: query)`.
///
/// Returns `false` if the run was cancelled while waiting — `task(id:)` cancels
/// the pending run when the query changes again, which is what makes this a
/// debounce rather than a delay — and the caller should then do nothing.
///
/// Skipped when either end of the transition is an empty query. That keystroke
/// is the one that swaps an unfiltered list for a filtered one (or, on the
/// scanner, a taxonomy browser for a result list), and pausing there reads as
/// the screen failing to respond rather than as smoothing.
@MainActor
func awaitSearchDebounce(from previous: String, to current: String) async -> Bool {
    guard !previous.isEmpty, !current.isEmpty else { return true }
    try? await Task.sleep(for: searchDebounce)
    return !Task.isCancelled
}
#endif
