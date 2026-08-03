#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore
import VinodexUI

/// Portrait-only, declared at run time (AUDIT M17).
///
/// The chassis is not a layout that reflows — it is a fixed portrait stack with
/// a hard 138pt island band across the top (`DexMetrics.islandStripMinHeight`),
/// a bezel that absorbs the remaining height, and a footer pinned to the bottom
/// edge. Landscape does not degrade it, it dismantles it: the island band eats
/// most of a landscape screen's height and the LCD collapses to a strip.
///
/// A delegate rather than the Info.plist because the Info.plist is not ours to
/// write. xtool generates the whole thing and exposes only `bundleID` and
/// `iconPath` through `xtool.yml` — it does not even let the app set its own
/// version (see KNOWN-ISSUES.md, "xtool stamps a fake version into every
/// bundle"), so `UISupportedInterfaceOrientations` has nowhere to be declared.
/// This callback is consulted per window and overrides the plist in any case,
/// so it is both the available lock and the authoritative one.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }
}

@main
struct VinodexApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Nothing here blocks the first frame (AUDIT M6).
        //
        // `Diagnostics.emit()` used to run *synchronously, in release*: it
        // forces the whole database decode and then runs six `regions(in:)`
        // queries, each a filter + sort over every entry. That is seven full
        // passes over the catalog before SwiftUI is allowed to build a scene,
        // for output nobody but a maintainer tailing `idevicesyslog` ever
        // reads. It is now DEBUG-only and off the main actor.
        //
        // The detached task still touches `WineDatabase.shared` in release, so
        // the decode gets a head start on a background thread while the main
        // actor builds the scene. `shared` is a `static let`, so whichever
        // thread arrives second blocks on the same `swift_once` and sees the
        // finished value — the work is never done twice.
        Task.detached(priority: .userInitiated) {
            _ = WineDatabase.shared
            #if DEBUG
            Diagnostics.emit()
            #endif
        }
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
    @State private var showingDataAlert: Bool
    @State private var access = AccessStore.shared
    /// DexFont and DexMetrics read their scales from defaults, which SwiftUI
    /// cannot observe. Keying the chassis on both forces a rebuild so a
    /// change takes effect immediately rather than on the next navigation.
    @AppStorage(TextScale.storageKey) private var scaleRaw = TextScale.small.rawValue
    @AppStorage(UIScale.storageKey) private var uiScaleRaw = UIScale.small.rawValue
    /// The system text size, read *above* the pin below so it is the real
    /// setting rather than the capped one. Used once, to seed TEXT SIZE for
    /// someone who had already enlarged their system text — see
    /// `TextScale.seedIfUnset`. (0.6.4, AUDIT H11)
    @Environment(\.dynamicTypeSize) private var systemType

    /// **The composition root.** This is the one place in the app where the
    /// singleton is named, and it stays defaulted rather than injected because
    /// everything below it now takes a `db:` parameter — which is what M27
    /// asked for. The two remaining `.shared` reads in this file are the M6
    /// warm-up (whose entire purpose is to force `swift_once` off the main
    /// thread) and `Diagnostics.emit`, and both are deliberate.
    private let db: WineDatabase

    init(db: WineDatabase = .shared) {
        self.db = db
        // Seeded from the injected database, not from `.shared` — otherwise a
        // fixture with a clean load would still raise the alert. Seeded here
        // rather than checked in `body` so dismissing it sticks: the errors are
        // immutable for the life of the process.
        _showingDataAlert = State(initialValue: !db.decodeErrors.isEmpty)
    }

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
            // Stated, not inferred from the title string (AUDIT **L2**) — the
            // empty path *is* the definition of the root screen, and it is
            // known here and nowhere else.
            isRoot: path.isEmpty,
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
                // Content swaps instantly; no push transition. The suppression
                // lives on the three `path` writes below rather than here,
                // because a `.transaction` modifier applies to *every* change
                // under it, not only the ones that swap the screen — this used
                // to null seventeen in-screen `withAnimation` calls, the daily
                // reveal and the entry expander among them. (AUDIT **M24**)
                screen

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
        // The app's declared position on Dynamic Type (0.6.4, AUDIT H11):
        // Vinodex sizes its own text and does not follow the system control.
        // `DexFont` already builds every font at a fixed size, so this pin is a
        // guard rather than the mechanism — it is here so that anything landing
        // later with a stock SwiftUI font (an alert, a share sheet, a future
        // system control) cannot quietly reintroduce the second axis. The
        // user-facing axis is SETTINGS > TEXT SIZE, and the seed below is how
        // someone who never opens it still gets a sensible starting step.
        .dynamicTypeSize(.large)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            // Before anything reads TEXT SIZE. A no-op on every launch after the
            // first, and on any device where the user has set it themselves.
            TextScale.seedIfUnset(
                systemOrdinal: DynamicTypeSize.allCases.firstIndex(of: systemType) ?? 3
            )
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
        // Since M46 a support table can fail without costing a single entry, so
        // "some entries may be missing" is no longer a safe thing to say — it
        // sends someone looking for a gap in the catalog that is not there.
        if !db.decodeErrors.contains(where: { $0.hasPrefix("entries.json") }) {
            return "\(failures) problem\(failures == 1 ? "" : "s") loading the wine database — entries are complete, but some colours, icons or map data are missing. See SETTINGS > DEV for details."
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
                filter: filter
                // Regions used to be the one category with no search bar
                // (AUDIT **L39**). The single route that reaches here with
                // `.regions` is the climate-filtered list from an entry page,
                // and it can run to dozens of rows — a list long enough to
                // need scrolling is a list long enough to need searching.
            ) { open($0) }

        case .masterSearch:
            EncyclopediaListScreen(
                categories: Set(EntryCategory.allCases),
                // The one route whose whole purpose is typing (AUDIT **L35**).
                focusesSearchOnAppear: true,
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

    /// Every route change goes through `withTransaction(.instant)` — see the
    /// note in `body`. It has to be explicit rather than merely default,
    /// because a caller inside `withAnimation` would otherwise donate its
    /// animation to the screen swap.
    ///
    /// No `Sounds.page()` any more: it was an empty function body, called on
    /// every push and pop for nothing. A screen change already rides the click
    /// of the button that caused it. (AUDIT **L43**)
    private func push(_ route: DexRoute) {
        var next = path
        next.append(route)
        withTransaction(.instant) { path = next }
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
            return
        }
        // `_ =` because `removeLast()` hands back the popped route, which
        // would otherwise become `withTransaction`'s discarded return value.
        withTransaction(.instant) { _ = path.removeLast() }
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
        withTransaction(.instant) { path.removeAll() }
        SearchStateStore.shared.clear()
        ScreenStateStore.shared.clear()
    }
}

extension Transaction {
    /// A transaction that carries no animation, for the navigation writes.
    /// Named because `Transaction(animation: nil)` at three call sites reads
    /// like three unrelated defaults rather than one deliberate rule.
    static var instant: Transaction { Transaction(animation: nil) }
}

/// Writes startup state to syslog. `idevicescreenshot` needs Developer Mode and
/// the developer disk image; `idevicesyslog` needs neither, so this is the
/// channel for confirming runtime facts from WSL.
///
/// DEBUG-only, and never on the main actor — the six `regions(in:)` queries
/// below are a filter + sort over the whole catalog each (AUDIT M6). Call it
/// from a detached task, not from `App.init`.
enum Diagnostics {
    static func emit() {
        let db = WineDatabase.shared
        var lines: [String] = []

        lines.append(contentsOf: DexFont.statusReport.map { "font: " + $0 })
        lines.append("entries: \(db.entries.count)")
        lines.append("decodeErrors: \(db.decodeErrors.isEmpty ? "none" : db.decodeErrors.joined(separator: " | "))")
        lines.append("loadNotices: \(db.loadNotices.isEmpty ? "none" : db.loadNotices.joined(separator: " | "))")

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
