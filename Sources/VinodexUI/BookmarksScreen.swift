#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// Saved entries, newest first.
///
/// Reuses `EntryTileView` so a saved row looks exactly like the same entry in
/// any list — a bookmark is a pointer, not a different kind of thing.
public struct BookmarksScreen: View {
    let onSelect: (WineEntry) -> Void

    @State private var bookmarks = BookmarkStore.shared
    @State private var confirmingClear = false
    private let db = WineDatabase.shared

    public init(onSelect: @escaping (WineEntry) -> Void) {
        self.onSelect = onSelect
    }

    private var entries: [WineEntry] { bookmarks.entries(in: db) }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        header
                        ForEach(entries) { entry in
                            EntryTileView(entry: entry, palette: db.palette) {
                                onSelect(entry)
                            }
                            // Swipe is not discoverable on a custom row, so
                            // removal is an explicit control on each tile.
                            .overlay(alignment: .topTrailing) {
                                removeButton(entry)
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
        // Clearing every bookmark is one tap from a scroll view and cannot be
        // undone, so it asks first. Removing a single entry does not — that one
        // is cheap to redo. Rendered in-screen rather than as a system dialog,
        // which would slide up from the device and break the chassis metaphor.
        .overlay {
            if confirmingClear {
                DexAlert(
                    title: "CLEAR ALL SAVED?",
                    message: "\(entries.count) saved \(entries.count == 1 ? "entry" : "entries") will be removed. This cannot be undone.",
                    confirmLabel: "CLEAR",
                    onConfirm: {
                        bookmarks.removeAll()
                        confirmingClear = false
                    },
                    onCancel: { confirmingClear = false }
                )
            }
        }
        .animation(.easeOut(duration: 0.15), value: confirmingClear)
    }

    private var header: some View {
        HStack {
            Text("\(entries.count) SAVED")
                .font(DexFont.retro(10))
                .tracking(2)
                .foregroundStyle(Dex.green)
            Spacer()
            Button {
                Haptics.tap()
                confirmingClear = true
            } label: {
                Text("CLEAR ALL")
                    .font(DexFont.retro(9))
                    .tracking(1)
                    .foregroundStyle(Dex.stone400)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Dex.stone700, lineWidth: 1)
                    )
            }
            .buttonStyle(DexPressStyle(scale: 0.95))
        }
        .padding(.horizontal, 2)
    }

    private func removeButton(_ entry: WineEntry) -> some View {
        Button {
            Haptics.select()
            bookmarks.remove(entry.id)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Dex.stone400)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Dex.stone900))
                .overlay(Circle().strokeBorder(Dex.stone700, lineWidth: 1))
        }
        .buttonStyle(DexPressStyle(scale: 0.9))
        .padding(6)
        .accessibilityLabel("Remove \(entry.name) from saved")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Dex.stone600)
            Text("NOTHING SAVED")
                .font(DexFont.retro(12))
                .tracking(2)
                .foregroundStyle(Dex.stone400)
            Text("Tap SAVE on any entry to keep it here.")
                .font(DexFont.mono(18))
                .foregroundStyle(Dex.stone600)
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }
}
#endif
