#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The user screen: who you are, and what you have saved.
///
/// Reuses `EntryTileView` for the saved rows so a bookmark looks exactly like
/// the same entry in any list — it is a pointer, not a different kind of thing.
public struct BookmarksScreen: View {
    let onSelect: (WineEntry) -> Void
    let onSelectCountry: (String) -> Void
    let onSelectState: (String) -> Void

    @State private var bookmarks = BookmarkStore.shared
    @State private var confirmingClear = false
    @State private var pendingDelete: SavedItem?
    @State private var access = AccessStore.shared
    /// Local only, and deliberately so — there is no account, and inventing a
    /// backend for a display name would be the tail wagging the dog.
    @AppStorage("userDisplayName") private var displayName = ""
    private let db = WineDatabase.shared

    public init(
        onSelect: @escaping (WineEntry) -> Void,
        onSelectCountry: @escaping (String) -> Void = { _ in },
        onSelectState: @escaping (String) -> Void = { _ in }
    ) {
        self.onSelect = onSelect
        self.onSelectCountry = onSelectCountry
        self.onSelectState = onSelectState
    }

    /// Everything saved, including countries and states — those have no entry
    /// to resolve against and were being dropped entirely.
    private var items: [SavedItem] { bookmarks.saved(in: db) }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    profileSection

                    savedHeader

                    if items.isEmpty {
                        emptyState
                    } else {
                        ForEach(items) { item in
                            row(item)
                                // Back at top-trailing: the tile no longer
                                // draws a chevron there, so nothing collides.
                                .overlay(alignment: .topTrailing) {
                                    removeButton(item)
                                }
                        }
                    }
                }
                .padding(10)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        // Clearing every bookmark is one tap from a scroll view and cannot be
        // undone, so it asks first. Removing a single entry does not — that one
        // is cheap to redo. Rendered in-screen rather than as a system dialog,
        // which would slide up from the device and break the chassis metaphor.
        .overlay {
            if confirmingClear {
                DexAlert(
                    title: "CLEAR ALL SAVED?",
                    message: "\(items.count) saved \(items.count == 1 ? "item" : "items") will be removed. This cannot be undone.",
                    confirmLabel: "CLEAR",
                    onConfirm: {
                        bookmarks.removeAll()
                        confirmingClear = false
                    },
                    onCancel: { confirmingClear = false }
                )
            }
        }
        .overlay {
            if let pendingDelete {
                DexAlert(
                    title: "REMOVE FROM SAVED?",
                    message: pendingDelete.displayName.uppercased(),
                    confirmLabel: "REMOVE",
                    onConfirm: {
                        bookmarks.remove(pendingDelete.storageID)
                        self.pendingDelete = nil
                    },
                    onCancel: { self.pendingDelete = nil }
                )
            }
        }
        .animation(.easeOut(duration: 0.15), value: confirmingClear)
        .animation(.easeOut(duration: 0.15), value: pendingDelete?.id)
    }

    private var savedHeader: some View {
        HStack {
            Text("\(items.count) SAVED")
                .font(DexFont.retro(10))
                .tracking(2)
                .foregroundStyle(Dex.green)
            Spacer()
            if !items.isEmpty {
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
        }
        .padding(.horizontal, 2)
        .padding(.top, 6)
    }

    /// Name entry. Placed above the saved list because it is the part that
    /// makes this feel like *your* screen rather than a second list.
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Dex.stone200, Dex.stone400, Dex.stone600],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName.isEmpty ? "TASTER" : displayName.uppercased())
                        .font(DexFont.retro(13))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(items.count) SAVED")
                        .font(DexFont.mono(16))
                        .foregroundStyle(Dex.stone600)
                }
                Spacer(minLength: 0)
            }

            Text("NAME")
                .font(DexFont.retro(9))
                .foregroundStyle(Dex.green)

            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Dex.green500)
                DexSearchField(text: $displayName, placeholder: "ENTER NAME...", fontSize: 22)
                    .frame(height: 30)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Capsule().fill(.black))
            .overlay(Capsule().strokeBorder(Dex.stone600, lineWidth: 2))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Dex.stone900)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Dex.stone700, lineWidth: 2)
        )
        .padding(.bottom, 6)
    }

    /// Rows are entries or places. Places carry a flag and route to their own
    /// screen; entries reuse the standard tile minus its chevron — a saved row
    /// is already a destination, and the arrow only fought the delete button.
    @ViewBuilder
    private func row(_ item: SavedItem) -> some View {
        switch item {
        case .entry(let entry):
            EntryTileView(
                entry: entry,
                palette: db.palette,
                locked: access.isLocked(entry, in: db),
                showsChevron: false
            ) {
                onSelect(entry)
            }
        case .country(let name):
            placeRow(name: name, kind: "COUNTRY") { onSelectCountry(name) }
        case .state(let name):
            placeRow(name: name, kind: "STATE") { onSelectState(name) }
        }
    }

    private func placeRow(
        name: String,
        kind: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 12) {
                FlagSwatch(country: name)
                    .frame(width: 48, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(.black.opacity(0.3), lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 5) {
                    Text(name.uppercased())
                        .font(DexFont.retro(13))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    ChipView(
                        label: kind,
                        chip: Palette.Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
                    )
                }
                Spacer(minLength: 34)
            }
            .padding(8)
            .frame(minHeight: 72)
            .background(Dex.stone900)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Dex.stone700, lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
    }

    private func removeButton(_ item: SavedItem) -> some View {
        Button {
            Haptics.select()
            pendingDelete = item
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
        .accessibilityLabel("Remove \(item.displayName) from saved")
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
