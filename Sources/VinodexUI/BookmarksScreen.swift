#if canImport(SwiftUI) && canImport(UIKit)
import PhotosUI
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
    /// Scroll position outlives the view — see `ScreenStateStore`.
    @State private var screens = ScreenStateStore.shared
    /// Local only, and deliberately so — there is no account, and inventing a
    /// backend for a display name would be the tail wagging the dog.
    @AppStorage("userDisplayName") private var displayName = ""
    /// The picture, which is local for the same reason. See `AvatarStore`.
    @State private var avatar = AvatarStore.shared
    @State private var pickedPhoto: PhotosPickerItem?
    /// Whether the name row is showing its field. Off by resting state: the
    /// field used to be permanently on screen, which made the top of this
    /// screen a form.
    @State private var editingName = false
    private let db = WineDatabase.shared
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

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

    /// One screen, so one key — unlike the countries and entries, there is only
    /// ever a single saved list.
    private static let profileAnchor = "__profile__"

    private var anchorBinding: Binding<String?> {
        Binding(
            get: { screens.anchor(for: ScreenStateStore.bookmarks) },
            set: { screens.setAnchor($0, for: ScreenStateStore.bookmarks) }
        )
    }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // The profile block and the header are one scroll target
                    // between them, so an anchor pointing here means "the top".
                    VStack(alignment: .leading, spacing: 8) {
                        profileSection

                        savedHeader
                    }
                    .id(Self.profileAnchor)

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
                .scrollTargetLayout()
            }
            // A content margin, not padding around the target layout — see the
            // note in `EncyclopediaListScreen`. Padding here moved the list
            // left by its own leading inset on every restore.
            .contentMargins(10, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            // Row-level, since the rows carry stable ids: coming back from a
            // saved entry lands on the row you tapped. An id that is no longer
            // saved simply resolves to nothing and the list opens at the top.
            .scrollPosition(id: anchorBinding)
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

    /// The one section heading on this screen.
    ///
    /// It was 10pt retro — smaller than the body copy under it and smaller than
    /// the same headings in the settings panels, which had already been lifted
    /// to 14 over a 2pt rule for exactly this reason. A heading that is the
    /// smallest type on its screen is not a heading. The count moved into the
    /// profile card above, where it belongs with the rest of the who-you-are
    /// readout and stops being printed twice.
    private var savedHeader: some View {
        HStack(alignment: .bottom) {
            Text("SAVED")
                .font(DexFont.retro(14))
                .tracking(2)
                .foregroundStyle(lcd.accent)
            Spacer()
            if !items.isEmpty {
                Button {
                    Haptics.tap()
                    confirmingClear = true
                } label: {
                    Text("CLEAR ALL")
                        // Merge of two passes that both had a point: the size and
                        // padding are v0.4.2.1's enlargement (this is a
                        // destructive action and was a 9pt target), and the ink is
                        // audit M14's contrast fix — `Dex.stone400` is a hardcoded
                        // ~2.3:1 grey that also ignores light mode, where
                        // `lcd.subtext` adapts. Neither side needed the other's
                        // regression.
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .foregroundStyle(lcd.subtext)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                        )
                }
                .buttonStyle(DexPressStyle(scale: 0.95))
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 10)
        .padding(.bottom, 5)
        .overlay(alignment: .bottom) { lcd.accent.opacity(0.45).frame(height: 2) }
    }

    /// Who you are. Placed above the saved list because it is the part that
    /// makes this feel like *your* screen rather than a second list.
    ///
    /// It used to be a 34pt system glyph, a name, and — below both — a labelled
    /// text field that was permanently open for typing. Three problems with
    /// that. The identity was a piece of SF Symbols furniture nobody could
    /// change; the name was printed twice, once as a caption and once as
    /// whatever was in the field; and an always-live input made the top of the
    /// screen a form you had to look past to reach your bookmarks.
    ///
    /// Now: one large avatar you can put your own photograph in, one name, and
    /// a pencil. The field only exists while the pencil is engaged.
    private var profileSection: some View {
        HStack(alignment: .top, spacing: 16) {
            avatarPicker

            VStack(alignment: .leading, spacing: 10) {
                nameRow
                savedStat
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(lcd.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(lcd.surfaceEdge, lineWidth: 2)
        )
        .padding(.bottom, 6)
        // The picker is out-of-process, so it needs no photo-library usage
        // description and no permission prompt — the user selects in Apple's
        // own UI and this app only ever receives the one image.
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    avatar.adopt(data)
                    Haptics.tap()
                }
                pickedPhoto = nil
            }
        }
    }

    /// The avatar, at 96pt — an actual portrait rather than a row glyph.
    private var avatarPicker: some View {
        PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
            ZStack {
                if let image = avatar.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    // The placeholder keeps the old brushed-metal treatment, so
                    // an empty avatar still reads as part of the device.
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 78))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Dex.stone200, Dex.stone400, Dex.stone600],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(lcd.accent.opacity(0.7), lineWidth: 3))
            // A camera badge rather than a caption: the affordance has to be on
            // the avatar, because the avatar is the target.
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(lcd.isLight ? .white : .black)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(lcd.accent))
                    .overlay(Circle().strokeBorder(lcd.surface, lineWidth: 2))
            }
            .shadow(color: .black.opacity(0.45), radius: 4, y: 3)
        }
        .buttonStyle(DexPressStyle(scale: 0.95))
        .accessibilityLabel(avatar.hasImage ? "Change your picture" : "Add a picture")
    }

    /// The name, and the one control that edits it.
    ///
    /// Resting state is a name and a pencil. Engaged, the name becomes the
    /// field and the pencil becomes a tick — one row either way, so nothing
    /// below it moves when you start or finish typing.
    @ViewBuilder
    private var nameRow: some View {
        HStack(spacing: 10) {
            if editingName {
                DexSearchField(
                    text: $displayName,
                    placeholder: "YOUR NAME",
                    fontSize: 26,
                    focusesOnAppear: true
                )
                .frame(height: 34)
            } else {
                Text(displayName.isEmpty ? "TASTER" : displayName.uppercased())
                    .font(DexFont.retro(17))
                    .foregroundStyle(displayName.isEmpty ? lcd.subtext : lcd.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 0)
            }

            Button {
                Haptics.select()
                withAnimation(.easeOut(duration: 0.15)) { editingName.toggle() }
            } label: {
                Image(systemName: editingName ? "checkmark" : "pencil")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(lcd.accent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(lcd.well))
                    .overlay(Circle().strokeBorder(lcd.surfaceEdge, lineWidth: 2))
            }
            .buttonStyle(DexPressStyle(scale: 0.9))
            .accessibilityLabel(editingName ? "Done editing name" : "Edit name")
        }
        .frame(minHeight: 44)
    }

    private var savedStat: some View {
        HStack(spacing: 8) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(lcd.accent)
            Text("\(items.count) SAVED")
                .font(DexFont.retro(12))
                .tracking(1)
                .foregroundStyle(lcd.subtext)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Capsule().fill(lcd.well))
        .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 2))
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
                FlagSwatch(country: name, width: 60, height: 38)
                VStack(alignment: .leading, spacing: 5) {
                    Text(name.uppercased())
                        .font(DexFont.retro(13))
                        .foregroundStyle(lcd.text)
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
            .background(lcd.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(lcd.surfaceEdge, lineWidth: 2)
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
                .foregroundStyle(lcd.subtext)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Dex.stone900))
                .overlay(Circle().strokeBorder(lcd.surfaceEdge, lineWidth: 1))
                // 44pt hit target around the 26pt visual (audit M25).
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(DexPressStyle(scale: 0.9))
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
                .foregroundStyle(lcd.subtext)
            Text("Tap SAVE on any entry to keep it here.")
                .font(DexFont.mono(18))
                .foregroundStyle(Dex.stone600)
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }
}
#endif
