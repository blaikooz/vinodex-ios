#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The plate every destination screen wears at the top: a portrait, the name
/// in shadowed caps, and the shelf controls, on a washed grid with an accent
/// rule under it.
///
/// Four screens drew this by hand — `EntryDetailScreen`, `ContinentScreen`,
/// `CountryScreen`, `StateScreen` — in twenty-odd lines that agreed on every
/// number: 14pt stacking, 18pt vertical padding, a 34pt grid at half opacity,
/// a 4pt rule, and a -14pt horizontal bleed to reach past the scroll inset.
/// Agreement maintained by hand is agreement waiting to end, and here it has
/// ended once already: **L30** was this hero's title shadow drifting to a
/// hardcoded `#006400` that read as blur in light mode, and it had to be
/// repaired in one file rather than made impossible in all four.
/// (AUDIT **M28**)
///
/// Only the portrait genuinely varies — an icon well for an entry or a
/// continent, a flag for a country or a state — so it is the one thing passed
/// in, along with whatever controls belong under the name.
struct DexHero<Portrait: View, Actions: View>: View {
    private let title: String
    private let portrait: Portrait
    private let actions: Actions

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    init(
        title: String,
        @ViewBuilder portrait: () -> Portrait,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.portrait = portrait()
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 14) {
            portrait

            Text(title.uppercased())
                .font(DexFont.retro(21))
                .foregroundStyle(lcd.text)
                .shadow(color: lcd.accent.opacity(0.55), radius: 0, x: 4, y: 4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            actions
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            ZStack {
                lcd.heroWash
                DexGridBackground(spacing: 34, color: lcd.heroGrid, opacity: 0.5)
            }
        )
        .overlay(alignment: .bottom) { lcd.accent.frame(height: 4) }
        // Negative, to bleed past the scroll content's own 14pt inset — the
        // plate reaches the LCD's edges while everything below it does not.
        .padding(.horizontal, -14)
        .padding(.bottom, 16)
    }
}

/// The hero's SAVE capsule: bookmark glyph, SAVE/SAVED, filled when on.
///
/// Three verbatim copies before this — `CountryScreen`, `StateScreen` and, as
/// of 0.6.5, `ContinentScreen`, which was pasted rather than reused. All three
/// toggled a `BookmarkStore` id and differed in nothing but which id.
/// (AUDIT **M28**)
///
/// `EntryDetailScreen` keeps its own row: an entry carries three shelves
/// (SAVE, WANT, TRIED) and a rating prompt hanging off the third, which is a
/// different control that happens to share a capsule.
struct DexSaveButton: View {
    private let id: String
    private let store: BookmarkStore

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    init(id: String, store: BookmarkStore) {
        self.id = id
        self.store = store
    }

    var body: some View {
        let saved = store.contains(id)
        return Button {
            // Saving succeeds; un-saving is just a toggle going back. Two
            // different feelings for two different outcomes, where both used
            // to be the same generic ping (AUDIT **L38**) — the button's own
            // label changes SAVE → SAVED, and now the hand hears about it too.
            if saved {
                Haptics.select()
            } else {
                Haptics.success()
            }
            store.toggle(id)
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
}
#endif
