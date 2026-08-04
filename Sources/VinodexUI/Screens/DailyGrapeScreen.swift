#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// "Grape of the day", played as a reveal.
///
/// The silhouette-then-reveal is the whole point: a shuffled entry shown
/// outright is just a list of one. Holding the name back for a beat turns it
/// into a guess, which is the thing worth reopening the app for.
///
/// The pick itself is deterministic from the date (`DailyPick`), so it does not
/// change when you leave and come back — only the reveal state is local.
public struct DailyGrapeScreen: View {
    let onOpen: (WineEntry) -> Void

    @State private var revealed = false
    /// Position in the cycle for *this* visit, fixed on appear.
    ///
    /// Read into state rather than off `RevealCursor` each time `pick` is
    /// evaluated: the pick is computed during `body`, and reading a value that
    /// advances would give a different entry on every re-render — the icon and
    /// the name would disagree.
    @State private var cursor: Int?
    /// Keeps the cursor and the reveal across a trip into the entry.
    ///
    /// "Once per open" was being measured in *view lifetimes*, and this view is
    /// destroyed by any navigation away from it — so tapping OPEN ENTRY on a
    /// revealed grape and pressing Back advanced the cycle and put the
    /// silhouette back up. You could not return to the thing you had just
    /// looked at. A visit now ends at Back-to-the-hub or Home, not at the first
    /// link you follow out of it.
    @State private var screens = ScreenStateStore.shared
    /// The database this screen reads. Defaulted so no call site changes, but
    /// injectable, which is the whole of **M27**: a screen that hard-reads
    /// `WineDatabase.shared` cannot be put in front of a fixture.
    private let db: WineDatabase
    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }

    public init(db: WineDatabase = .shared, onOpen: @escaping (WineEntry) -> Void) {
        self.db = db
        self.onOpen = onOpen
    }

    /// A new entry every time the game is opened — see `DailyPick.entry(cursor:)`.
    private var pick: WineEntry? {
        guard let cursor else { return nil }
        return DailyPick.entry(cursor: cursor, in: db)
    }

    /// "WHAT'S THAT GRAPE / REGION / STYLE" — named for whatever today is.
    private var kindWord: String {
        switch pick?.category {
        case .regions: "REGION"
        case .styles: "STYLE"
        default: "GRAPE"
        }
    }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            if let pick {
                content(pick)
            } else {
                // "NOTHING TODAY" is a fact about the shuffle, and on an empty
                // database it is a lie about the build — the game has nothing
                // to pick *from*. `DexEmptyState` says which (AUDIT M2).
                DexEmptyState(db: db) {
                    Text("NOTHING TODAY")
                        .font(DexFont.retro(12))
                        .foregroundStyle(Dex.stone400)
                }
            }
        }
        // Advance once per visit, not once per render and not once per rebuild.
        .onAppear {
            guard cursor == nil else { return }
            if let held = screens.number("cursor", for: ScreenStateStore.dailyGrape) {
                cursor = Int(held)
                revealed = screens.isOn("revealed", for: ScreenStateStore.dailyGrape)
            } else {
                cursor = RevealCursor.shared.advance()
                screens.setNumber(Double(cursor ?? 0), "cursor", for: ScreenStateStore.dailyGrape)
            }
        }
        .onChange(of: revealed) { _, shown in
            screens.setFlag("revealed", shown, for: ScreenStateStore.dailyGrape)
        }
    }

    private func content(_ grape: WineEntry) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            Text(revealed ? "TODAY'S \(kindWord)" : "WHAT'S THAT \(kindWord)?")
                .font(DexFont.retro(13))
                .tracking(2)
                .foregroundStyle(Dex.yellow)
                .multilineTextAlignment(.center)

            // Silhouette until revealed: the real icon well, flattened to a
            // single dark shape so the outline still teases the answer.
            EntryIconWell(db: db, entry: grape, size: 132, cornerRadius: 16)
                .saturation(revealed ? 1 : 0)
                .brightness(revealed ? 0 : -0.55)
                .overlay {
                    if !revealed {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.black.opacity(0.55))
                    }
                }
                .animation(.easeOut(duration: 0.35), value: revealed)

            Text(revealed ? grape.name.uppercased() : "? ? ?")
                .font(DexFont.retro(20))
                .foregroundStyle(lcd.text)
                .shadow(color: lcd.accent.opacity(0.55), radius: 0, x: 3, y: 3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)

            if revealed {
                Text(grape.entryDescription)
                    .font(DexFont.mono(18))
                    .foregroundStyle(lcd.bodyText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            if revealed {
                Button {
                    Haptics.tap()
                    onOpen(grape)
                } label: {
                    label("OPEN ENTRY", fill: Dex.green, text: .black)
                }
                .buttonStyle(DexPressStyle(scale: 0.96))
            } else {
                Button {
                    Haptics.select()
                    withAnimation(.easeOut(duration: 0.35)) { revealed = true }
                } label: {
                    label("REVEAL", fill: Dex.yellow, text: Dex.amber900)
                }
                .buttonStyle(DexPressStyle(scale: 0.96))
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func label(_ text: String, fill: Color, text textColor: Color) -> some View {
        Text(text)
            .font(DexFont.retro(12))
            .tracking(2)
            .foregroundStyle(textColor)
            .padding(.horizontal, 30)
            .padding(.vertical, 14)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
    }
}
#endif
