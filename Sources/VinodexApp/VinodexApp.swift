#if canImport(SwiftUI)
import SwiftUI
import VinodexCore
import VinodexUI

@main
struct VinodexApp: App {
    init() {
        Diagnostics.emit()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var path: [DexRoute] = []
    /// Set when a locked entry is tapped; drives the upgrade prompt.
    @State private var lockedAttempt: WineEntry?
    /// Raised once per launch when the database reported load errors (0.6.3,
    /// item 1 — AUDIT H2). Seeded here rather than checked in `body` so
    /// dismissing it sticks: the errors themselves are immutable for the life
    /// of the process, and re-raising a permanent condition on every render
    /// would make the alert un-dismissable. Detail stays in the DEV panel.
    @State private var showingDataAlert = !WineDatabase.shared.decodeErrors.isEmpty
    @State private var access = AccessStore.shared
    /// DexFont and DexMetrics read their scales from defaults, which SwiftUI
    /// cannot observe. Keying the chassis on both forces a rebuild so a
    /// change takes effect immediately rather than on the next navigation.
    @AppStorage(TextScale.storageKey) private var scaleRaw = TextScale.small.rawValue
    @AppStorage(UIScale.storageKey) private var uiScaleRaw = UIScale.small.rawValue

    private let db = WineDatabase.shared

    /// Single gate for every navigation into an entry, wherever it came from —
    /// a list row, a cross-link, a search result or a bookmark. Putting it here
    /// rather than in each screen means a new screen cannot forget it.
    private func open(_ entry: WineEntry) {
        if access.isLocked(entry, in: db) {
            Haptics.select()
            lockedAttempt = entry
        } else {
            push(entry.destination)
        }
    }

    /// Routes from header-tile cross-links. A `.detail` route names an entry,
    /// so it has to clear the same gate `open(_:)` does — a tile linking to a
    /// locked grape (Loire's key grape Chenin Blanc, say) was pushing straight
    /// past the paywall because it carried a route rather than an entry.
    private func openRoute(_ route: DexRoute) {
        if case .detail(let id) = route, let entry = db.entry(id: id) {
            open(entry)
        } else {
            push(route)
        }
    }

    /// No `NavigationStack`: the chassis is physical furniture and should not
    /// slide off-screen when you press a button on it. Only the LCD content
    /// changes, which is also what the device metaphor implies. `path` is still
    /// a stack, so Back and Home behave exactly as before.
    var body: some View {
        DeviceChassis(
            title: currentTitle,
            marqueeSymbol: currentMarqueeSymbol,
            showsBack: !path.isEmpty,
            onBack: path.isEmpty ? nil : { goBack() },
            onHome: { goHome() },
            onBookmarks: { push(.bookmarks) },
            onSettings: { push(.settings) }
        ) {
            // The prompt lives inside the LCD, like every other popup — an
            // overlay on the chassis itself would dim the bezel, island and
            // footer too, which reads as the device losing power.
            ZStack {
                screen
                    // Content swaps instantly; no push transition.
                    .transaction { $0.animation = nil }

                if let entry = lockedAttempt {
                    // Offers the bundle the entry actually belongs to rather than
                    // Pro every time — a locked Bordeaux region prompts for the
                    // France bundle. See `Entitlement.offer(for:)`.
                    let offer = Entitlement.offer(for: entry)
                    UpgradePrompt(
                        entitlement: offer,
                        onUnlock: {
                            // Grants for real, then continues to the entry the user
                            // was trying to open. Stopping at "unlocked!" and making
                            // them find their way back was the other half of why
                            // this button felt broken.
                            access.grant(offer)
                            lockedAttempt = nil
                            push(entry.destination)
                        },
                        onCancel: { lockedAttempt = nil }
                    )
                }

                // The data-health notice, above everything else in the LCD: a
                // partially (or wholly) missing database changes what every
                // other screen means, so it cannot wait to be discovered via
                // an oddly short list. One button — this is a notice, not a
                // choice. (0.6.3, item 1 — AUDIT H2)
                if showingDataAlert {
                    DexAlert(
                        title: "DATA LOAD ERROR",
                        message: dataAlertMessage,
                        confirmLabel: "OK",
                        cancelLabel: nil,
                        onConfirm: { showingDataAlert = false },
                        onCancel: { showingDataAlert = false }
                    )
                }
            }
            .animation(.easeOut(duration: 0.15), value: lockedAttempt?.id)
            .animation(.easeOut(duration: 0.15), value: showingDataAlert)
        }
        .id(scaleRaw + "|" + uiScaleRaw)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            ScreenWake.keepAwake(true)
            // The power-on chime, once per launch — this view appears exactly
            // once, so no flag is needed.
            Sounds.boot()
        }
        .onDisappear { ScreenWake.keepAwake(false) }
        // The system panel (settings, diagnostics, catalog) is owned by
        // DeviceChassis so it can be confined to the LCD; the app module no
        // longer presents it.
    }

    /// Counts, not the raw error strings — those are developer diagnostics
    /// (decode paths, type names) and belong in the DEV panel this points to.
    private var dataAlertMessage: String {
        let failures = db.decodeErrors.count
        if db.entries.isEmpty {
            return "The wine database failed to load. See SETTINGS > DEV for details."
        }
        return "\(failures) problem\(failures == 1 ? "" : "s") loading the wine database — some entries may be missing. See SETTINGS > DEV for details."
    }

    private var currentTitle: String {
        guard let route = path.last else { return "VINODEX" }
        if case .detail(let id) = route, let entry = db.entry(id: id) {
            return entry.scanTitle
        }
        return route.title
    }

    /// The glyph between the marquee's repetitions — resolved the same way
    /// `currentTitle` is, so the pair can never disagree about which page
    /// they describe. Nil on the main screen: the chassis supplies its own.
    private var currentMarqueeSymbol: String? {
        guard let route = path.last else { return nil }
        if case .detail(let id) = route, let entry = db.entry(id: id) {
            return entry.scanSymbol
        }
        return route.marqueeSymbol
    }

    @ViewBuilder
    private var screen: some View {
        switch path.last {
        case .none:
            MainMenuScreen { push($0) }

        case .list(let category, let filter):
            EncyclopediaListScreen(
                categories: [category],
                filter: filter,
                showsSearch: category != .regions
            ) { open($0) }

        case .masterSearch:
            EncyclopediaListScreen(
                categories: Set(EntryCategory.allCases),
                showsCountries: true,
                onSelect: { open($0) },
                onSelectCountry: { push(.country(name: $0)) }
            )

        case .detail(let id):
            if let entry = db.entry(id: id) {
                EntryDetailScreen(
                    entry: entry,
                    onSelectRelated: { open($0) },
                    onOpenRoute: { openRoute($0) }
                )
            } else {
                notFound
            }

        case .globe:
            RetroGlobeScreen(
                onSelectContinent: { continent in
                    // Matches the web app: a globe marker opens the continent
                    // info screen rather than jumping straight to its regions.
                    push(.continent(entryID: "CONT_\(continent.rawValue)"))
                },
                onWorldSearch: { push(.globeSearch) }
            )

        case .bookmarks:
            BookmarksScreen(
                onSelect: { open($0) },
                onSelectCountry: { push(.country(name: $0)) },
                onSelectState: { push(.state(name: $0)) },
                onPassport: { push(.passport) }
            )

        case .passport:
            PassportScreen()

        case .globeSearch:
            // Continents and regions between them carry country and state
            // names; countries join as rows of their own (v0.5.6).
            EncyclopediaListScreen(
                categories: [.continents, .regions],
                showsCountries: true,
                onSelect: { open($0) },
                onSelectCountry: { push(.country(name: $0)) }
            )

        case .country(let name):
            CountryScreen(
                country: name,
                onSelectRegion: { open($0) },
                onSelectState: { push(.state(name: $0)) }
            )

        case .state(let name):
            StateScreen(state: name) { open($0) }

        case .dailyGrape:
            DailyGrapeScreen { open($0) }

        case .settings:
            SettingsPanel(
                onClose: { goBack() },
                onSection: { push(.settingsSection($0)) },
                onMinigames: { push(.minigames) },
                onWalkthrough: { push(.walkthrough) }
            )

        case .settingsSection(let section):
            SettingsSectionPanel(section: section, onDev: { push(.settingsSection(.dev)) })

        case .minigames:
            ToolsScreen(
                onDailyGrape: { push(.dailyGrape) },
                onScanner: { push(.scanner) },
                onMoonDial: { push(.moonDial) },
                onChipFilter: { push(.chipFilter) },
                onQuiz: { push(.wsetQuiz) },
                onDailyChallenge: { push(.dailyChallenge) }
            )

        case .chipFilter:
            ChipFilterScreen(
                onSelect: { open($0) },
                onSelectCountry: { push(.country(name: $0)) }
            )

        case .wsetQuiz:
            TastingQuizScreen(onOpen: { open($0) }, onExit: { goBack() })

        case .dailyChallenge:
            TastingQuizScreen(mode: .daily, onOpen: { open($0) }, onExit: { goBack() })

        case .walkthrough:
            // FINISH goes Home rather than Back: the tour's last step tells you
            // to press Home and pick a tile, and landing back in the settings
            // grid you started from would contradict it.
            WalkthroughScreen { goHome() }

        case .scanner:
            ScannerScreen { open($0) }

        case .moonDial:
            MoonDialScreen()

        case .continent(let id):
            if let entry = db.entry(id: id), case .continent(let c) = entry {
                ContinentScreen(continent: c) { country in
                    push(.country(name: country))
                }
            } else {
                notFound
            }
        }
    }

    private var notFound: some View {
        ZStack {
            DexScreenBackground()
            Text("ENTRY NOT FOUND")
                .font(DexFont.retro(12))
                .foregroundStyle(Dex.red500)
        }
    }

    private func push(_ route: DexRoute) {
        Sounds.page()
        var next = path
        next.append(route)
        path = next
    }

    /// Back pops one route — and, for the daily reveal, ends the visit.
    ///
    /// Every other screen's state is kept until Home so that stepping *into*
    /// something and coming out of it lands you where you were. The reveal is
    /// the one screen whose contract is the opposite: it is meant to hand you a
    /// new entry each time you open it, so leaving it for the minigames hub has
    /// to drop the held pick, while opening the revealed entry from inside it
    /// must not. `goBack` is the only place that can tell those two apart,
    /// because it is the only place that knows *which* screen you are leaving.
    private func goBack() {
        guard let leaving = path.last else { return }
        // The scanner gets first refusal (0.6.4, B2): its questionnaire
        // persists across route pops, so popping it from question three just
        // meant re-entering on question three — the chassis Back button
        // looked dead on scanner pages. Stepping the questionnaire back is
        // what "back" means there; the route only pops once the scanner says
        // there is nothing left to unwind.
        if leaving == .scanner, ScannerBackRouter.shared.handleBack() {
            Sounds.page()
            return
        }
        Sounds.page()
        path.removeLast()
        if leaving == .dailyGrape {
            ScreenStateStore.shared.forget(ScreenStateStore.dailyGrape)
        }
    }

    /// Home is the reset. Searches, scroll positions and expanded sections all
    /// survive Back — that is the point of `SearchStateStore` and
    /// `ScreenStateStore` — but they must not survive Home, or re-entering a
    /// list from the main menu would silently open it pre-filtered by something
    /// you typed several screens ago, and a country would open halfway down.
    private func goHome() {
        Sounds.page()
        path.removeAll()
        SearchStateStore.shared.clear()
        ScreenStateStore.shared.clear()
    }
}

/// Writes startup state to syslog. `idevicescreenshot` needs Developer Mode and
/// the developer disk image; `idevicesyslog` needs neither, so this is the
/// channel for confirming runtime facts from WSL.
enum Diagnostics {
    static func emit() {
        let db = WineDatabase.shared
        var lines: [String] = []

        lines.append(contentsOf: DexFont.statusReport.map { "font: " + $0 })
        lines.append("entries: \(db.entries.count)")
        lines.append("decodeErrors: \(db.decodeErrors.isEmpty ? "none" : db.decodeErrors.joined(separator: " | "))")

        for continent in Continent.allCases {
            let names = db.regions(in: continent).map(\.name)
            lines.append("globe \(continent.rawValue): \(names.isEmpty ? "EMPTY" : names.joined(separator: ", "))")
        }

        for line in lines {
            NSLog("VDX %@", line)
            print("VDX " + line)
        }
    }
}
#endif
