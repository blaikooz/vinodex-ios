#if canImport(SwiftUI) && canImport(UIKit)
import PhotosUI
import SwiftUI
import VinodexCore

/// The profile's only stored field. A named constant so CLEAR SAVED DATA can
/// name the key without spelling the literal twice.
///
/// **The literal moved to `VinoName.storageKey` in 0.8.9c** and this forwards to
/// it. Professor Vino addresses the player by the name they gave themselves
/// here, so Core needs to read the same default this screen writes — and a key
/// spelled in two modules is a key that can be renamed in one of them. Same
/// value, same behaviour, one spelling. See `VinoName` for why no second name
/// was minted.
///
/// This screen no longer reads it: the name is `AppSettings.displayName` now
/// (arch **A17**), which persists under `SavedDataKey.displayName`. What is
/// left are the two call sites that still have to *name a key* rather than read
/// a setting — `SettingsPanel`'s CLEAR SAVED DATA loop and `ProfileShareCard`'s
/// `@AppStorage` — so the constant stays for them.
public enum UserProfile {
    public static let displayNameKey = VinoName.storageKey
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
    /// The picture, which is local only and deliberately so — there is no
    /// account, and inventing a backend for a profile would be the tail
    /// wagging the dog. See `AvatarStore`.
    @State private var avatar = AvatarStore.shared
    @State private var pickedPhoto: PhotosPickerItem?
    /// The database this screen reads. Defaulted so no call site changes, but
    /// injectable, which is the whole of **M27**: a screen that hard-reads
    /// `WineDatabase.shared` cannot be put in front of a fixture.
    private let db: WineDatabase
    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }

    public init(
        db: WineDatabase = .shared,
        onSelect: @escaping (WineEntry) -> Void,
        onSelectCountry: @escaping (String) -> Void = { _ in },
        onSelectState: @escaping (String) -> Void = { _ in },
        onPassport: @escaping () -> Void = {}
    ) {
        self.db = db
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
                // Lazy, like every other list screen (AUDIT **L12**). This was
                // the last eager one: an ordinary saved shelf builds every row
                // — tile, icon well, chips, and for TRIED a five-star strip and
                // a journal line — before the first of them is on screen.
                LazyVStack(alignment: .leading, spacing: 8) {
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
        // Both removals ask first, and the comment here used to say the single
        // one did not — three lines above the overlay that shows the dialog
        // (AUDIT **L37**). The comment was the thing that was wrong, not the
        // code: "cheap to redo" holds for a saved bookmark, which is one SAVE
        // tap away from coming back, and does not hold on the TRIED shelf,
        // where removing a row takes its rating and its written note with it
        // (see `BookmarkStore.remove(_:on:)`). One ✕ is a small target near a
        // scrolling list, and there is nothing behind it to restore what it
        // deletes.
        //
        // Both are rendered in-screen rather than as system dialogs, which
        // would slide up from the device and break the chassis metaphor.
        .overlay {
            if confirmingClear {
                DexAlert(
                    title: "CLEAR ALL \(title(of: shelf))?",
                    message: shelf == .tried
                        ? "\(items.count) tasting\(items.count == 1 ? "" : "s") will be removed — ratings and notes go with them."
                        : "\(items.count) \(items.count == 1 ? "item" : "items") will be removed. This cannot be undone.",
                    confirmLabel: "CLEAR",
                    destructive: true,
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
                    message: shelf == .tried
                        ? "\(pendingDelete.displayName.uppercased()) — its rating and note go with it."
                        : pendingDelete.displayName.uppercased(),
                    confirmLabel: "REMOVE",
                    destructive: true,
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
        .animation(DexMotion.overlay, value: confirmingClear)
        .animation(DexMotion.overlay, value: pendingDelete?.id)
        .animation(DexMotion.overlay, value: editingRating?.id)
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
                    withAnimation(DexMotion.overlay) { shelfRaw = option.rawValue }
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
                                EntryIconWell(db: db, entry: entry, size: 56, cornerRadius: 8)
                                // Two lines and a scale floor (0.7.1, A4).
                                // The retro face advances a full em, so a
                                // 64pt box at one line held seven characters
                                // at SMALL and *five* at HUGE — CABERNET
                                // SAUVIGNON came out as CABE…, and this strip
                                // is the one place in the app where the name
                                // is the only thing telling two rows apart
                                // (the wells above are frequently the same
                                // art).
                                Text(entry.name.uppercased())
                                    .font(DexFont.retro(10))
                                    .foregroundStyle(lcd.subtext)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.6)
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
                ProfileNameRow(lcd: lcd)
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
    ///
    /// The picture itself is `AvatarBadge` rather than inline content because
    /// `PhotosPicker.init` is `nonisolated` and takes its label as a `@Sendable`
    /// builder, so nothing inside that closure may touch this screen — and this
    /// screen is main-actor isolated, inferred from the `@MainActor` singletons
    /// its `@State` properties are seeded with. Under Swift 5 that was a warning
    /// nobody saw; `swift-tools-version: 6.0` makes it six hard errors, and they
    /// only ever appeared in the iOS compile, since `VinodexUI` builds to nothing
    /// on the host. So the isolated reads happen *here* and cross as values: an
    /// `AvatarStore` is `@MainActor`, hence `Sendable`, and so is `LcdMode`.
    private var avatarPicker: some View {
        let store = avatar
        let mode = lcd
        // No `photoLibrary:` argument, which is what picks the out-of-process
        // picker the note above promises. Passing `.shared()` selects the
        // in-process one instead — it reads the library directly, so it wants
        // an authorisation prompt and an `NSPhotoLibraryUsageDescription` that
        // this app has nowhere to put (auditS **M6**: there is no Info.plist).
        return PhotosPicker(selection: $pickedPhoto, matching: .images) {
            AvatarBadge(store: store, lcd: mode)
        }
        .buttonStyle(DexPressStyle(scale: 0.95))
        .accessibilityLabel(avatar.hasImage ? "Change your picture" : "Add a picture")
    }

    /// The way into the passport, and the streak mark beneath it when one is
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
    ///
    /// The name row that used to sit above this one is `ProfileNameRow`, at
    /// file scope — see its own note (AUDIT **L12**).
    private var statRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Haptics.screenTap()
                onPassport()
            } label: {
                HStack(spacing: 6) {
                    DexChromeGlyph("passport", symbol: "book.closed.fill", size: 13, weight: .bold)
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
            // The second half of the walkthrough's last step (0.8.9d, G2): the
            // chassis user button gets you here, this gets you to the passport.
            // One target id, two publishers, one on screen at a time.
            .coachmarkTarget(.passportButton)

            if streak.current > 0 {
                HStack(spacing: 6) {
                    // The Tools tile's own face (0.8.9a, A7). The streak is
                    // the daily challenge's number, so it wears the daily
                    // challenge's picture -- the tile has had this art since
                    // 0.8.1 and the counter it feeds had not.
                    DexChromeGlyph(
                        "dailychallenge", symbol: DexGlyph.challenge,
                        size: 13, weight: .bold, tint: Dex.yellow
                    )
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
                    // The TRIED shelf's own rows all wear it, which is correct
                    // rather than redundant: the shelves share one list style,
                    // and a border that vanished on the shelf it names would
                    // read as the shelf being a different kind of thing.
                    tried: bookmarks.contains(entry.id, on: .tried),
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
                            DexChromeGlyph("edit", symbol: "square.and.pencil", size: 13, weight: .bold, tint: lcd.accent)
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
                FlagSwatch(db: db, country: name, width: 60, height: 38)
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

/// The name, and the one control that edits it.
///
/// Resting state is a name and a pencil. Engaged, the name becomes the field
/// and the pencil becomes a tick — one row either way, so nothing below it
/// moves when you start or finish typing.
///
/// A view of its own rather than a `nameRow` property on the screen, and that
/// is the whole point of it (AUDIT **L12**). The name is read from
/// `AppSettings` and `editingName` is `@State`; held on `BookmarksScreen`,
/// every keystroke invalidated the *screen* — the profile block, the
/// recently-viewed strip and its twenty icon wells, the shelf picker with its
/// three `saved(in:)` counts, and every row of the active shelf — to redraw one
/// text field. Owning both here confines the rebuild to this row.
///
/// `lcd` arrives as a value rather than being read from defaults again, so the
/// row still repaints with the rest of the screen on a mode change.
private struct ProfileNameRow: View {
    let lcd: LcdMode

    /// Local only, and deliberately so — there is no account, and inventing a
    /// backend for a display name would be the tail wagging the dog. The one
    /// setting written outside SETTINGS (arch **A17**).
    var settings: AppSettings = .shared
    private var displayName: String { settings.displayName }

    /// Hand-rolled because `settings` is a plain stored property rather than a
    /// property wrapper, so there is no `$settings` to project — the same
    /// shape `SettingsPanel.anchorBinding` uses over `ScreenStateStore`.
    private var nameBinding: Binding<String> {
        Binding(get: { settings.displayName }, set: { settings.displayName = $0 })
    }
    /// Whether the row is showing its field. Off by resting state: the field
    /// used to be permanently on screen, which made the top of the user screen
    /// a form.
    @State private var editingName = false

    var body: some View {
        HStack(spacing: 10) {
            if editingName {
                DexSearchField(
                    text: nameBinding,
                    placeholder: "YOUR NAME",
                    fontSize: 26,
                    focusesOnAppear: true
                )
                // See DexSearchField.height — this frame and the field's font
                // have to move together, or the name row desynchronises from the
                // search bar it copies. (AUDIT **M50**)
                .frame(height: DexSearchField.height(nominal: DexSearchField.defaultFontSize, atLeast: 34))
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
                withAnimation(DexMotion.overlay) { editingName.toggle() }
            } label: {
                // Only half the ternary has a face: `edit` is the resting
                // state, and the tick that confirms it is not an edit button
                // (0.8.1, J3).
                DexChromeGlyph(
                    editingName ? "checkmark" : "edit",
                    symbol: editingName ? "checkmark" : "square.and.pencil",
                    size: 17, weight: .bold, tint: lcd.accent
                )
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(lcd.well))
                    .overlay(Circle().strokeBorder(lcd.surfaceEdge, lineWidth: 2))
            }
            .buttonStyle(DexPressStyle(scale: 0.9))
            .accessibilityLabel(editingName ? "Done editing name" : "Edit name")
        }
        .frame(minHeight: 44)
    }
}

/// The picture inside the profile's photo picker.
///
/// A view of its own, and at file scope rather than nested, purely so that
/// nothing about it is main-actor isolated: `PhotosPicker`'s label builder is
/// `@Sendable`, so it can construct this — the memberwise initialiser is
/// `nonisolated` and both stored properties are `Sendable` — but it could not
/// have read `BookmarksScreen`'s state to draw the same thing inline. See
/// `BookmarksScreen.avatarPicker`.
///
/// The store is passed in rather than read from `AvatarStore.shared` here so
/// this stays exercisable against a throwaway directory (`AvatarStore` takes
/// one), in the spirit of audit **M27**. `body` is `@MainActor` by protocol, so
/// reading the `@Observable` store inside it is both legal and what registers
/// the dependency — holding it in `@State` would only own a lifetime the
/// singleton already has.
private struct AvatarBadge: View {
    let store: AvatarStore
    let lcd: LcdMode

    var body: some View {
        ZStack {
            if let image = store.image {
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
        //
        // The drawn camera face since 0.9.43 — the same master TAKE PHOTO
        // wears in the label reader (`LabelReaderView.buttonArt`), flattened
        // to the badge's ink so it reads as a badge rather than a painting.
        .overlay(alignment: .bottomTrailing) {
            DexChromeGlyph(
                "camera",
                symbol: "camera.fill",
                size: 16,
                weight: .bold,
                tint: lcd.isLight ? .white : .black,
                flatten: lcd.isLight ? .white : .black
            )
            .frame(width: 30, height: 30)
            .background(Circle().fill(lcd.accent))
            .overlay(Circle().strokeBorder(lcd.surface, lineWidth: 2))
        }
        .shadow(color: .black.opacity(0.45), radius: 4, y: 3)
    }
}
#endif
