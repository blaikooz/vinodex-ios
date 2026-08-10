#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// A state's regions, with the state's own flag as the hero.
///
/// Same construction as `CountryScreen` — assembled from region fields rather
/// than an entry — but keyed on `details.state`. Its own screen rather than a
/// filtered list so the state flag has somewhere to be: a plain list header
/// could not carry it, and the flags are the point of the section that leads
/// here.
public struct StateScreen: View {
    let state: String
    let onSelectRegion: (WineEntry) -> Void

    @State private var access = AccessStore.shared
    @State private var bookmarks = BookmarkStore.shared
    /// Scroll position outlives the view — see `ScreenStateStore`.
    @State private var screens = ScreenStateStore.shared
    /// The database this screen reads. Defaulted so no call site changes, but
    /// injectable, which is the whole of **M27**: a screen that hard-reads
    /// `WineDatabase.shared` cannot be put in front of a fixture.
    private let db: WineDatabase
    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }

    public init(db: WineDatabase = .shared, state: String, onSelectRegion: @escaping (WineEntry) -> Void) {
        self.db = db
        self.state = state
        self.onSelectRegion = onSelectRegion
    }

    /// Through `SavedItem` rather than a string literal, for the reason spelled
    /// out on `CountryScreen.bookmarkID` (AUDIT **L1**).
    private var bookmarkID: String { SavedItem.state(state).storageID }

    private var screenKey: String { ScreenStateStore.state(state) }

    private enum Anchor {
        static let hero = "hero"
        static let regions = "regions"
    }

    private var anchorBinding: Binding<String?> {
        Binding(
            get: { screens.anchor(for: screenKey) },
            set: { screens.setAnchor($0, for: screenKey) }
        )
    }

    private var regions: [WineEntry] {
        db.entries(in: .regions).filter {
            if case .region(let r) = $0 { return r.details.state == state }
            return false
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero.id(Anchor.hero)
                regionsSection.id(Anchor.regions)
            }
            .scrollTargetLayout()
        }
        // Content margins rather than padding around the target layout — see
        // the note in `EncyclopediaListScreen`. The generous tail keeps the
        // last section clear of the footer, matching pb-20.
        .contentMargins(.horizontal, 14, for: .scrollContent)
        .contentMargins(.bottom, 72, for: .scrollContent)
        .scrollPosition(id: anchorBinding)
        .background(lcd.page)
        .id(state)
    }

    private var hero: some View {
        DexHero(title: state) {
            // Hero-sized, matching `CountryScreen` — the two screens are the
            // same shape and a state's flag is doing the same job.
            FlagSwatch(country: state, width: 168, height: 106)
                .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
        } actions: {
            DexSaveButton(id: bookmarkID, store: bookmarks)
        }
    }

    private var regionsSection: some View {
        DexSection("REGIONS", symbol: "mappin.and.ellipse") {
            VStack(spacing: 8) {
                // A heading with nothing under it reads as a fault, not as an
                // answer — see `DexSectionEmpty` (AUDIT **L36**).
                if regions.isEmpty {
                    DexEmptyState(db: db) {
                        DexSectionEmpty(
                            symbol: "mappin.slash",
                            message: "NO REGIONS FOUND"
                        )
                    }
                }
                ForEach(regions) { entry in
                    EntryTileView(
                        entry: entry,
                        palette: db.palette,
                        locked: access.isLocked(entry, in: db)
                    ) {
                        onSelectRegion(entry)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
