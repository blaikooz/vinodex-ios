#if canImport(SwiftUI) && canImport(UIKit)
import PhotosUI
import SwiftUI
import VinodexCore

/// The profile's only stored field. A named constant so CLEAR SAVED DATA can
/// name the key without spelling the literal twice.
public enum UserProfile {
    public static let displayNameKey = "userDisplayName"
}

/// The user screen: who you are, and your three shelves.
///
/// SAVED is reference, WANT TO TRY is the wishlist, TRIED is the history —
/// one segmented row switches between them, because three stacked lists would
/// bury the third below the fold and three routes would be three screens
/// pretending not to be one.
///
/// Reuses `EntryTileView` for the rows so a shelved entry looks exactly like
/// the same entry in any list — it is a pointer, not a different kind of thing.
public struct BookmarksScreen: View {
    let onSelect: (WineEntry) -> Void
    let onSelectCountry: (String) -> Void
    let onSelectState: (String) -> Void
    let onPassport: () -> Void

    @State private var bookmarks = BookmarkStore.shared
    /// The recent trail (0.6.3, item 3) — read-only here; the entry screen
    /// writes it.
    @State private var recents = RecentlyViewedStore.shared
    @State private var confirmingClear = false
    @State private var pendingDelete: SavedItem?
    /// The tried entry whose rating is being edited, driving a `RatingPrompt`
    /// overlay — the journal is editable where it is read, not only back on
    /// the entry's own screen.
    @State private var editingRating: WineEntry?
    @State private var access = AccessStore.shared
    @State private var streak = StreakStore.shared
    /// Scroll position outlives the view — see `ScreenStateStore`.
    @State private var screens = ScreenStateStore.shared
    /// The active shelf. Session state, like the scroll position: a cold
    /// launch opens on SAVED.
    @State private var shelfRaw = Shelf.saved.rawValue
    /// Local only, and deliberately so — there is no account, and inventing a
    /// backend for a display name would be the tail wagging the dog.
    @AppStorage(UserProfile.displayNameKey) private var displayName = ""
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
        onSelectState: @escaping (String) -> Void = { _ in },
        onPassport: @escaping () -> Void = {}
    ) {
        self.onSelect = onSelect
        self.onSelectCountry = onSelectCountry
        self.onSelectState = onSelectState
        self.onPassport = onPassport
    }

    private var shelf: Shelf { Shelf(rawValue: shelfRaw) ?? .saved }

    /// The active shelf's rows. Saved includes places; the tasting shelves
    /// hold entries only, by construction.
    private var items: [SavedItem] {
        switch shelf {
        case .saved: bookmarks.saved(in: db)
        case .wantToTry, .tried: bookmarks.entries(on: shelf, in: db).map { .entry($0) }
        }
    }

    private func title(of shelf: Shelf) -> String {
        switch shelf {
        case .saved: "SAVED"
        case .wantToTry: "WANT"
        case .tried: "TRIED"
        }
    }

    /// One screen, so one key — unlike the countries and entries, there is only
    /// ever a single saved list.
    private static let profileAnchor = "__profile__"

    /// Keyed per shelf, so switching to TRIED and back does not try to restore
    /// a row id the other shelf cannot resolve.
    private var anchorBinding: Binding<String?> {
        Binding(
            get: { screens.anchor(for: ScreenStateStore.shelf(shelfRaw)) },
            set: { screens.setAnchor($0, for: ScreenStateStore.shelf(shelfRaw)) }
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

                        // Between the profile and the shelves: recents are
                        // *yours* but not *kept* — a trail, not a shelf — so
                        // they sit above the deliberate lists without joining
                        // them. Hidden entirely when empty; an empty state for
                        // a passive record would be a nag. (0.6.3, item 3)
                        if !recents.isEmpty {
                            recentStrip
                        }

                        shelfPicker

                        shelfHeader
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
        .onAppear {
            if let held = screens.value("shelf", for: ScreenStateStore.bookmarks) {
                shelfRaw = held
            }
        }
        .onChange(of: shelfRaw) { _, new in
            screens.setValue(new, "shelf", for: ScreenStateStore.bookmarks)
        }
        // Clearing a whole shelf is one tap from a scroll view and cannot be
        // undone, so it asks first. Removing a single entry does not — that one
        // is cheap to redo. Rendered in-screen rather than as a system dialog,
        // which would slide up from the device and break the chassis metaphor.
        .overlay {
            if confirmingClear {
                DexAlert(
                    title: "CLEAR ALL \(title(of: shelf))?",
                    message: shelf == .tried
                        ? "\(items.count) tasting\(items.count == 1 ? "" : "s") will be removed — ratings and notes go with them."
                        : "\(items.count) \(items.count == 1 ? "item" : "items") will be removed. This cannot be undone.",
                    confirmLabel: "CLEAR",
                    onConfirm: {
                        bookmarks.removeAll(on: shelf)
                        confirmingClear = false
                    },
                    onCancel: { confirmingClear = false }
                )
            }
        }
        .overlay {
            if let pendingDelete {
                DexAlert(
                    title: "REMOVE FROM \(title(of: shelf))?",
                    message: pendingDelete.displayName.uppercased(),
                    confirmLabel: "REMOVE",
                    onConfirm: {
                        bookmarks.remove(pendingDelete.storageID, on: shelf)
                        self.pendingDelete = nil
                    },
                    onCancel: { self.pendingDelete = nil }
                )
            }
        }
        .overlay {
            if let entry = editingRating {
                RatingPrompt(
                    entryName: entry.name,
                    initial: bookmarks.rating(for: entry.id),
                    onSave: { stars, note in
                        bookmarks.setRating(
                            TriedRating(rating: stars, note: note, day: DailyPick.dayIndex()),
                            for: entry.id
                        )
                        editingRating = nil
                    },
                    onSkip: { editingRating = nil }
                )
            }
        }
        .animation(.easeOut(duration: 0.15), value: confirmingClear)
        .animation(.easeOut(duration: 0.15), value: pendingDelete?.id)
        .animation(.easeOut(duration: 0.15), value: editingRating?.id)
    }

    /// The shelf switch, in the settings panel's equal-width segment idiom.
    /// Counts ride in the labels so the other shelves advertise what they
    /// hold before you visit them.
    private var shelfPicker: some View {
        HStack(spacing: 8) {
            ForEach(Shelf.allCases, id: \.self) { option in
                let active = shelf == option
                Button {
                    Haptics.select()
                    withAnimation(.easeOut(duration: 0.15)) { shelfRaw = option.rawValue }
                } label: {
                    Text("\(title(of: option)) \(count(of: option))")
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(active ? lcd.onAccent : lcd.subtext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(active ? lcd.accent : lcd.surface)
                        )
                }
                .buttonStyle(DexPressStyle(scale: 0.97))
            }
        }
        .padding(.top, 4)
    }

    private func count(of shelf: Shelf) -> Int {
        shelf == .saved ? bookmarks.saved(in: db).count : bookmarks.count(on: shelf)
    }

    /// The active shelf's heading and its clear-all.
    private var shelfHeader: some View {
        HStack(alignment: .bottom) {
            Text(shelf == .wantToTry ? "WANT TO TRY" : title(of: shelf))
                .font(DexFont.retro(14))
                .tracking(2)
                .foregroundStyle(lcd.accent)
            Spacer()
            if !items.isEmpty {
                Button {
                    Haptics.screenTap()
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
        .padding(.top, 6)
        .padding(.bottom, 5)
        .overlay(alignment: .bottom) { lcd.accent.opacity(0.45).frame(height: 2) }
    }

    /// The recently-viewed trail: a horizontal strip of icon wells, newest
    /// first. Wells rather than full tiles because this is a scent trail, not
    /// a list — a tap reopens the entry (through the same access gate as any
    /// other row), and the full tile treatment belongs to things deliberately
    /// shelved. Stale ids are already dropped by `entries(in:)`.
    private var recentStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENTLY VIEWED")
                .font(DexFont.retro(11))
                .tracking(2)
                .foregroundStyle(lcd.subtext)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(recents.entries(in: db)) { entry in
                        Button {
                            Haptics.select()
                            onSelect(entry)
                        } label: {
                            VStack(spacing: 4) {
                                EntryIconWell(entry: entry, size: 56, cornerRadius: 8)
                                Text(entry.name.uppercased())
                                    .font(DexFont.retro(10))
                                    .foregroundStyle(lcd.subtext)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(width: 64)
                            }
                        }
                        .buttonStyle(DexPressStyle(scale: 0.95))
                        .accessibilityLabel("Recently viewed: \(entry.name)")
                    }
                }
            }
        }
        .padding(12)
        .background(lcd.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(lcd.surfaceEdge, lineWidth: 2)
        )
        .padding(.bottom, 2)
    }

    /// Who you are. Placed above the shelves because it is the part that
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
                statRow
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
                    Haptics.screenTap()
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
                Image(systemName: editingName ? "checkmark" : "square.and.pencil")
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

    /// The way into the passport, and the streak flame beneath it when one is
    /// alight.
    ///
    /// **Stacked rather than side by side since 0.6.7 (D1).** The two shared a
    /// row, and the row is not wide: the avatar takes 96pt plus its gap, so on a
    /// compact phone two capsules were splitting ~200pt between them and the
    /// PASSPORT label was being squeezed down its `minimumScaleFactor` — the
    /// full name only rendered when no streak was running. Nothing on this
    /// panel is competing for the vertical, so a column costs a row of height
    /// and buys both labels their full size.
    ///
    /// Passport first, streak under it: one is the control and one is a
    /// readout, and putting the readout on top would push the button further
    /// from the thumb to no purpose.
    private var statRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Haptics.screenTap()
                onPassport()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("PASSPORT")
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .lineLimit(1)
                }
                .foregroundStyle(lcd.onAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Capsule().fill(lcd.accent))
            }
            .buttonStyle(DexPressStyle(scale: 0.95))

            if streak.current > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Dex.yellow)
                    Text("\(streak.current) DAY\(streak.current == 1 ? "" : "S")")
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .foregroundStyle(lcd.subtext)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Capsule().fill(lcd.well))
                .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 2))
            }
        }
    }

    /// Rows are entries or places. Places carry a flag and route to their own
    /// screen; entries reuse the standard tile minus its chevron — a saved row
    /// is already a destination, and the arrow only fought the delete button.
    /// Tried rows carry their journal line underneath.
    @ViewBuilder
    private func row(_ item: SavedItem) -> some View {
        switch item {
        case .entry(let entry):
            VStack(alignment: .leading, spacing: 0) {
                EntryTileView(
                    entry: entry,
                    palette: db.palette,
                    locked: access.isLocked(entry, in: db),
                    showsChevron: false
                ) {
                    onSelect(entry)
                }

                // The journal line renders for every tried row — rated or not —
                // because it now carries the pencil: an unrated tasting used
                // to have no way into the prompt from this screen at all.
                if shelf == .tried {
                    let rating = bookmarks.rating(for: entry.id)
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= (rating?.rating ?? 0) ? "star.fill" : "star")
                                .font(.system(size: 11))
                                .foregroundStyle(star <= (rating?.rating ?? 0) ? Dex.yellow : lcd.disabledText)
                        }
                        if let note = rating?.note, !note.isEmpty {
                            Text(note)
                                .font(DexFont.mono(16))
                                .foregroundStyle(lcd.subtext)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Spacer(minLength: 0)
                        Button {
                            Haptics.select()
                            editingRating = entry
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(lcd.accent)
                                // 44pt target around the 13pt glyph, same rule
                                // as the remove button above it.
                                .frame(width: 40, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(DexPressStyle(scale: 0.9))
                        .accessibilityLabel("Edit your rating for \(entry.name)")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(lcd.well)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                    )
                }
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
        .accessibilityLabel("Remove \(item.displayName) from \(title(of: shelf).lowercased())")
    }

    private var emptyState: some View {
        let (glyph, headline, hint): (String, String, String) = switch shelf {
        case .saved:
            ("bookmark", "NOTHING SAVED", "Tap SAVE on any entry to keep it here.")
        case .wantToTry:
            ("plus.circle", "NOTHING ON THE WISHLIST", "Tap WANT on a grape or style you're curious about.")
        case .tried:
            ("checkmark.circle", "NOTHING TRIED YET", "Tap TRIED on a grape or style you've drunk — then rate it.")
        }

        return VStack(spacing: 12) {
            Image(systemName: glyph)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Dex.stone600)
            Text(headline)
                .font(DexFont.retro(12))
                .tracking(2)
                .foregroundStyle(lcd.subtext)
            Text(hint)
                .font(DexFont.mono(18))
                .foregroundStyle(Dex.stone600)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
    }
}
#endif
