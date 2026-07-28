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
    private let db = WineDatabase.shared
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(state: String, onSelectRegion: @escaping (WineEntry) -> Void) {
        self.state = state
        self.onSelectRegion = onSelectRegion
    }

    private var bookmarkID: String { "STATE_\(state)" }

    private var regions: [WineEntry] {
        db.entries(in: .regions).filter {
            if case .region(let r) = $0 { return r.details.state == state }
            return false
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                regionsSection
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 72)
        }
        .background(lcd.page)
        .id(state)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            FlagSwatch(country: state)
                .frame(width: 96, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.black.opacity(0.35), lineWidth: 2)
                )

            Text(state.uppercased())
                .font(DexFont.retro(21))
                .foregroundStyle(lcd.text)
                .shadow(color: lcd.accent.opacity(0.55), radius: 0, x: 4, y: 4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            saveButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            ZStack {
                lcd.heroWash
                DexGridBackground(spacing: 34, color: Color(dexHex: "#14532d"), opacity: 0.5)
            }
        )
        .overlay(alignment: .bottom) { lcd.accent.frame(height: 4) }
        .padding(.horizontal, -14)
        .padding(.bottom, 16)
    }

    private var saveButton: some View {
        let saved = bookmarks.contains(bookmarkID)
        return Button {
            Haptics.select()
            bookmarks.toggle(bookmarkID)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: saved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14, weight: .bold))
                Text(saved ? "SAVED" : "SAVE")
                    .font(DexFont.retro(10))
                    .tracking(2)
            }
            .foregroundStyle(saved ? .white : lcd.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(saved ? lcd.accent : lcd.buttonWell))
            .overlay(Capsule().strokeBorder(lcd.accent, lineWidth: 2))
        }
        .buttonStyle(DexPressStyle(scale: 0.94))
    }

    private var regionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(lcd.accent)
                Text("REGIONS")
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(lcd.accent)
            }
            .padding(.bottom, 2)
            .overlay(alignment: .bottom) { lcd.accent.opacity(0.4).frame(height: 2) }

            VStack(spacing: 8) {
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
