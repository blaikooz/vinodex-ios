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
/// A delegate rather than the Info.plist, and **still a delegate now that the
/// Info.plist is ours to write** (corrected 0.7.2). This note used to say xtool
/// exposed only `bundleID` and `iconPath` and that
/// `UISupportedInterfaceOrientations` therefore had nowhere to be declared; that
/// was wrong about xtool 1.17.0, which takes an `infoPath:` passthrough, and the
/// repo has an `Info.plist` going through it since LABEL SCAN needed camera
/// usage strings.
///
/// The reasoning survives the correction intact, because it was never really
/// about availability: this callback is consulted per window and **overrides**
/// the plist, so declaring the orientation in both places would leave two
/// things to keep in agreement and only one of them deciding. The lock stays
/// here, and `Info.plist` stays free of it.
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
    @State private var showingDataAlert = !WineDatabase.shared.decodeErrors.isEmpty
    @State private var access = AccessStore.shared
    /// Which tool cards have been shown (0.8.8, D1). See `toolIntro`.
    @State private var toolIntros = ToolIntroStore.shared
    /// The boot POST (0.7.3, A1). True for the first ~1.9 seconds of a launch,
    /// or until the screen is tapped.
    @State private var booting = true
    /// The app's one idle timer (0.7.3, F2), held here so the boot screen and
    /// demo mode can pause it. The chassis reads the same instance.
    @State private var idle = IdleMonitor.shared
    @Environment(\.scenePhase) private var scenePhase
    /// Which stop demo mode is on, or nil when it is not running (0.7.3, A2).
    @State private var demoStop: Int?
    /// The activity count when demo mode started.
    ///
    /// **The tap that starts the demo must not also stop it.**
    /// `IdleTouchWatcher` sees a touch on the way *down*, and the button's
    /// action runs on the way *up*, so by the time the demo begins the counter
    /// has already moved once. Comparing against the value captured at start is
    /// exact, where a grace period would be a guess.
    @State private var demoStartedAtTick = 0
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
            marqueeArt: currentMarqueeArt,
            showsBack: !path.isEmpty,
            onBack: path.isEmpty ? nil : { goBack() },
            onHome: { goHome() },
            onBookmarks: { push(.bookmarks) },
            onSettings: { push(.settings) },
            // The marquee's two lamp buttons (0.7.1 B5; the lamps' own since
            // 0.7.6, A1). `openRoute`, not `push`, so a shortcut to an entry
            // would still clear the paywall gate — no `MarqueePin` resolves to a
            // `.detail` today, and the point of routing it through the one gate
            // is that the next one added cannot forget.
            //
            // **Replaces the stack rather than growing it** when a lamp is
            // pressed from a pushed screen: a pin is a way of *going* somewhere,
            // not of drilling in, and a Back button that walked you through every
            // screen you had jumped between would turn a shortcut into a longer
            // path than the one it saved. Home stays one tap.
            onQuickRoute: { route in
                path = []
                openRoute(route)
            }
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
                            //
                            // Through `AccessStore.purchase` since 0.7.5 (B2) —
                            // the same grant, reached through the seam a payment
                            // step would live in. The push is inside the `Task`
                            // and gated on the outcome, so a purchase that did
                            // not happen does not open the entry.
                            let destination = entry.destination
                            lockedAttempt = nil
                            Task {
                                if await access.purchase(offer).entitlement != nil {
                                    push(destination)
                                }
                            }
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

                // The BIOS (0.7.7, B1) — **inside the LCD, framed by the
                // chassis** (0.7.8, A4), which puts back where 0.7.3a had it and
                // reverses 0.7.7's move to a full-viewport overlay.
                //
                // 0.7.7's argument was that its composition carried its own
                // terminal border, side rails and corner brackets, and nesting
                // that inside the plastic one would be a bezel inside a bezel.
                // A4 agrees and deletes the drawn frame instead: the device's
                // own surround is the frame, so the screen can go back in the
                // screen. The 0.7.3a objection it was answering — a translucent
                // overlay dimming the chassis reads as power *loss* — does not
                // apply either, because this is opaque and it is not an overlay.
                // See `BootScreen` for the long version.
                //
                // **The tool's own introduction, once each** (0.8.8, D1).
                //
                // Here rather than inside the six tool screens, which is the
                // whole reason it is one flag check and not six: `toolIntro`
                // reads the current route, so a seventh tool is a roster entry
                // and a route arm rather than another screen learning to raise a
                // card. It sits above the upgrade prompt and the data notice for
                // the ordinary reason — it is the newest thing on screen — and
                // below the BIOS, which must cover everything.
                //
                // Raised on the route rather than in `onAppear` so it cannot
                // fire twice for one arrival, and dismissed by writing the id,
                // which is what makes it once-ever.
                if let intro = toolIntro {
                    ToolIntroCard(
                        intro: intro,
                        onStart: { toolIntros.markSeen(intro.id) },
                        onSkipAll: { toolIntros.markAllSeen() }
                    )
                }

                // Last in this stack, so it covers the two prompts above rather
                // than booting underneath them.
                if booting {
                    BootScreen(
                        entries: db.entries.count,
                        // The MAINFRAME cheat (A4). Reads the entitlement store
                        // like every other unlock (F1).
                        verbose: access.hasFound(CheatCodes.verboseBoot),
                        onFinish: finishBoot
                    )
                }
            }
            .animation(DexMotion.overlay, value: lockedAttempt?.id)
            .animation(DexMotion.overlay, value: showingDataAlert)
            .animation(DexMotion.overlay, value: toolIntro?.id)
        }
        // **The picture is in the display; the input is the window's** (0.7.8,
        // A4). Everything on the chassis is live and now visible around the
        // booting screen — the footer buttons, the marquee lamps, and the island
        // orb, which flips the device on a one-second hold. A touch during boot
        // must advance the BIOS rather than press any of them, so the capture
        // layer stays over the whole window even though the composition no
        // longer is. `BootAdvanceCatcher` carries the full re-derivation.
        //
        // An `overlay` on `DeviceChassis` rather than a `ZStack` around it: the
        // chassis is a `GeometryReader` filling the window, so the overlay gets
        // the same bounds, and the modifiers below (the scale `id`, the type
        // pin, `onAppear`) keep applying to both without being restated.
        .overlay {
            if booting { BootAdvanceCatcher(onAdvance: finishBoot) }
        }
        .animation(DexMotion.overlay, value: booting)
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
            // The app-wide activity sink (0.7.3, F2). On the window, so it sees
            // touches on the chassis furniture and the LCD alike without either
            // knowing it exists — and it never competes for a gesture. See
            // `IdleTouchWatcher`.
            IdleTouchWatcher.install()
            // Held frozen through the boot POST: a screensaver over a boot
            // screen would be absurd, and the boot screen is not idleness.
            idle.isPaused = booting
            idle.start()
        }
        .onDisappear {
            ScreenWake.keepAwake(false)
            idle.stop()
        }
        // **Any input exits demo mode** (0.7.3, A2). One line, because F2 gave
        // the app a single place that hears about every touch — before it, this
        // would have meant a recogniser per screen.
        .onChange(of: idle.activityTick) { _, tick in
            if demoStop != nil, tick > demoStartedAtTick { stopDemo() }
        }
        // The demo's own clock. Keyed on the stop, so each assignment cancels
        // the previous sleep and starts the next dwell — the same `task(id:)`
        // lifetime argument the marquee script makes.
        .task(id: demoStop) { await runDemo() }
        // Reminders re-read their real permission and re-cut their plan on every
        // foreground (0.7.8, D1). Both halves have to happen here: authorization
        // can be withdrawn in iOS Settings while the app is not running, and the
        // pending week goes stale the moment a paper is sat or a day rolls over.
        // A no-op when the user has never opted in.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await NotificationScheduler.shared.syncFromStores() }
        }
        // The system panel (settings, diagnostics, catalog) is owned by
        // DeviceChassis so it can be confined to the LCD; the app module no
        // longer presents it.
    }

    // MARK: Boot (0.7.3, A1)

    /// The POST finished, or was tapped through.
    ///
    /// Idempotent: the tap and the sequence's own completion race by design —
    /// tapping on the last frame is a legitimate thing to do — and whichever
    /// arrives second must not restart the idle timer a second time.
    private func finishBoot() {
        guard booting else { return }
        booting = false
        idle.isPaused = false
    }

    // MARK: Demo mode (0.7.3, A2)

    /// Start the attract loop from the System panel.
    ///
    /// Goes Home first: the demo drives the whole route stack, and starting it
    /// from three screens deep would leave those screens underneath it for Back
    /// to walk out through once it stopped.
    private func startDemo() {
        goHome()
        demoStartedAtTick = idle.activityTick
        // Frozen while it runs. The demo navigates without being touched, so
        // the screensaver would otherwise cover it half a minute in (0.7.6, A3)
        // — the one case where the device is genuinely busy and genuinely
        // untouched. And it would bring the marquee greeting with it now (A4),
        // over a loop whose whole job is to show the panel naming each tool.
        idle.isPaused = true
        demoStop = 0
    }

    /// Any input stopped it. Returns to the main menu rather than leaving the
    /// user on whichever tool the loop happened to be showing — they did not
    /// choose to be there.
    private func stopDemo() {
        guard demoStop != nil else { return }
        demoStop = nil
        idle.isPaused = false
        goHome()
    }

    /// Hold the current stop, then move to the next.
    ///
    /// Assigns `path` directly rather than going through `push`: the demo
    /// *replaces* where you are on every stop, so a stack would grow twelve
    /// deep per cycle, and `push` plays the page sound — twelve chirps a minute
    /// from a device nobody is holding.
    private func runDemo() async {
        guard let index = demoStop else { return }
        let stop = DemoTour.stop(at: index)
        path = [stop.route]
        try? await Task.sleep(for: .seconds(stop.dwell))
        guard !Task.isCancelled, demoStop == index else { return }
        demoStop = index + 1
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

    /// The drawn face for that glyph (0.8.3, A), resolved through the same two
    /// branches for the same reason: a stem taken from a different route than
    /// the symbol would put one page's picture over another page's name.
    private var currentMarqueeArt: String? {
        guard let route = path.last else { return nil }
        if case .detail(let id) = route, let entry = db.entry(id: id) {
            return entry.scanArt
        }
        return route.marqueeArt
    }

    /// The introduction owed for the route currently open, if any (0.8.8, D1).
    ///
    /// Nil while booting, because a card raised over the BIOS would be waiting
    /// behind it — the boot screen covers this stack deliberately, and a player
    /// who lands on a tool through the demo loop or a restored route should meet
    /// the card when the device is actually on.
    ///
    /// The route-to-tool pairing lives on `ToolRoster` rather than here, because
    /// this module is the one no test can see: `ToolRosterTests` walks the roster
    /// against it and fails on an entry no route produces, so a card that is
    /// written and never raised is a test failure rather than a thing nobody
    /// notices. All this holds is the "and has it been shown yet" half.
    private var toolIntro: ToolIntro? {
        guard !booting, let route = path.last,
              let intro = ToolRoster.intro(for: route) else { return nil }
        return toolIntros.pending(intro.id)
    }

    /// Which chip rows a category listing offers (0.7.0, H2/H3, extending
    /// 0.6.9's I3).
    ///
    /// I3 put chips on the varieties scan and explicitly deferred the rest,
    /// noting that REGIONS and STYLES "would each want a facet set argued on its
    /// own terms rather than this one reused". H asks for three of those sets,
    /// and this is the table rather than a ternary because that is what a
    /// per-category argument looks like written down.
    ///
    /// The rule every row here obeys: inside a listing that is *already* one
    /// category, a facet is only worth offering if it has more than one live
    /// value and no value that empties the list. That is what rules TYPE and
    /// CLIMATE out of the grape listing, and it is what rules COUNTRY out of the
    /// flavour one — flavours have no origin at all.
    ///
    /// - GRAPES: unchanged from I3.
    /// - STYLES: STYLE CLASS only, per H2's "styles only". RARITY and COUNTRY
    ///   both technically work on styles, and both were declined for H1's
    ///   reason: the spec names one axis.
    /// - FLAVORS: TASTE and FAMILY, the flavour taxonomy's two levels — the same
    ///   two a flavour's own detail page puts in its header tiles. Neither
    ///   existed as a facet before H3; see `ChipFacet`.
    /// - REGIONS and CONTINENTS: none. The regions listing has no search bar
    ///   (see `showsSearch` below) and the world search is where place
    ///   filtering lives — H1 put the chips there rather than here.
    private static func chipFacets(for category: EntryCategory) -> [ChipFacet] {
        switch category {
        // **GRAPES gains STYLE (0.8.8, C1)**, for 0.8.7's reason on REGIONS: the
        // body tile's cross-link is a chip now, so the row it lands in has to
        // exist — without it the arrival would light a chip nobody could see or
        // clear, and `EncyclopediaListScreen.init`'s guard would decline to seed
        // it, leaving a FILTER SEARCH title over an untouched list.
        //
        // Last of the four, not beside BODY. The rule this table states is that a
        // facet earns its row by having more than one live value and no value
        // that empties the list, which STYLE passes on ten. But it is the longest
        // row of the four and the only one that wraps, and COLOUR/BODY/RARITY are
        // the three this screen has taught since 0.6.9.
        case .grapes: [.color, .body, .rarity, .grapeStyle]
        // COLOUR and COUNTRY join STYLE CLASS (0.8.1, D). Both tables already
        // shipped — `colorTypeChips` and `countryChips` are probed by the
        // generator and drawn on every style tile — so this is a screen being
        // offered data it was already displaying. STYLE CLASS stays first: it
        // is the narrowest of the three and the one this screen has taught.
        case .styles: [.styleClass, .styleColor, .country]
        case .flavors: [.flavorClass, .flavorSubclass]
        // **REGIONS gains CLIMATE (0.8.7, C1).** The note above says place
        // filtering lives on the world search and this screen has none, which
        // was true of *place* — country and region are search-bar territory by
        // `ChipFacet`'s own closed-set rule. Climate is not a place: it is five
        // values, regions-only, and it is what a region's CLIMATE tile
        // cross-links on. C1 turns that cross-link into a pre-selected chip, so
        // the row it lands in has to exist; without it the arrival would light a
        // chip nobody could see or clear. The guard in
        // `EncyclopediaListScreen.init` checks exactly that and would have
        // declined to seed rather than break, which is how this was caught.
        case .regions: [.climate]
        case .continents: []
        }
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
                showsSearch: category != .regions,
                chipFacets: Self.chipFacets(for: category)
            ) { open($0) }

        // `.masterSearch` retired in 0.7.1 (A1) — see `DexRoute`. It was this
        // one `EncyclopediaListScreen` configuration and no screen of its own;
        // `.chipFilter` is MASTER SEARCH now and runs the same query.
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
            PassportScreen(onStampCollection: { push(.stampCollection) })

        case .stampCollection:
            StampCollectionScreen()

        case .globeSearch:
            // Continents and regions between them carry country and state
            // names; countries join as rows of their own (v0.5.6).
            EncyclopediaListScreen(
                categories: [.continents, .regions],
                showsCountries: true,
                // **World-search chips** (0.7.0, H1) — countries, continents and
                // regions, and nothing else. One facet does all three: TYPE is
                // the row that chooses between the tables, and
                // `ChipFilter.options(for:in:includingCountries:)` scopes it to
                // the two categories this screen holds plus the COUNTRIES
                // pseudo-value. CLIMATE and COUNTRY were both candidates and
                // both declined: H1 names three things, and a facet nobody asked
                // for is a row every user of this screen has to read past.
                chipFacets: [.category],
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

        // The route case keeps its name (0.7.9, B): `DexRoute` is vocabulary,
        // `DemoMode` names it, and what changed is the screen behind the door
        // rather than the door. See `WhatsThatScreen`.
        case .dailyGrape:
            WhatsThatScreen { open($0) }

        case .settings:
            SettingsPanel(
                onClose: { goBack() },
                onSection: { push(.settingsSection($0)) },
                onMinigames: { push(.minigames) }
            )

        case .settingsSection(let section):
            SettingsSectionPanel(
                section: section,
                onDev: { push(.settingsSection(.dev)) },
                onFirmwareHistory: { push(.firmwareHistory) },
                onCheatConsole: { push(.cheatConsole) },
                // The tour moved into SETTINGS > DEVICE in 0.7.6 (F1), so the
                // callback moved with it — the grid no longer has a TUTORIAL
                // tile to raise it from.
                onWalkthrough: { push(.walkthrough) },
                onDemoMode: { startDemo() },
                onDeviceWorkshop: { push(.deviceWorkshop) },
                // C1: the shelf's tiles push a frame instead of raising an
                // overlay over themselves.
                onOpenPack: { push(.pack(id: $0)) }
            )

        // The shop's own panel, told which cartridge is open (0.8.4, C1).
        //
        // **The same view, not a second one**, and that is the whole of why this
        // fix is four lines rather than an extraction. The splash was already a
        // branch inside `SettingsSectionPanel`'s overlay chain, closing over the
        // shop's item list, the access store, the tried shelf and the upgrade
        // prompt; lifting it out would have meant threading five dependencies
        // into a new type to move a `nil` from one place to another. What was
        // wrong was never where the view lived, it was that the value driving it
        // was `@State` on a frame the user had already navigated past — so the
        // value moves onto the route and the view stays where it is.
        //
        // `section: .access` because that is what this panel *is* while a pack
        // is open: the marquee reads PACKS off the route, not off the section.
        case .pack(let id):
            SettingsSectionPanel(
                section: .access,
                openPack: id,
                onDev: { push(.settingsSection(.dev)) },
                onFirmwareHistory: { push(.firmwareHistory) },
                onCheatConsole: { push(.cheatConsole) },
                onWalkthrough: { push(.walkthrough) },
                onDemoMode: { startDemo() },
                onDeviceWorkshop: { push(.deviceWorkshop) },
                // Already open; a tile behind the splash is not reachable.
                onOpenPack: { push(.pack(id: $0)) },
                // CLOSE and the chassis Back are now the same operation, which
                // is the property C1 is really asking for.
                onClosePack: { goBack() }
            )

        case .minigames:
            ToolsScreen(
                onDailyGrape: { push(.dailyGrape) },
                onScanner: { push(.scanner) },
                onMoonDial: { push(.moonDial) },
                onQuiz: { push(.wsetQuiz) },
                onDailyChallenge: { push(.dailyChallenge) },
                onLabelReader: { push(.labelReader) }
            )

        case .chipFilter:
            ChipFilterScreen(
                onSelect: { open($0) },
                onSelectCountry: { push(.country(name: $0)) }
            )

        // WINE EXAM. The authored bank since 0.7.5 (D) — the same route, the
        // same ladder, a different room behind the door. See `WineExamScreen`.
        case .wsetQuiz:
            WineExamScreen(onOpen: { open($0) }, onExit: { goBack() })

        // The daily paper is still generated from the catalog, and deliberately
        // — see `Exam.swift` on why the split is not leftover.
        case .dailyChallenge:
            TastingQuizScreen(onOpen: { open($0) }, onExit: { goBack() })

        case .walkthrough:
            // FINISH goes Home rather than Back: the tour's last step tells you
            // to press Home and pick a tile, and landing back in the settings
            // grid you started from would contradict it.
            WalkthroughScreen { goHome() }

        case .scanner:
            ScannerScreen { open($0) }

        // Through `open(_:)` like every other screen that offers an entry, so a
        // label that resolves to a locked grape hits the paywall gate rather
        // than walking past it (0.7.2, LR1).
        case .labelReader:
            LabelReaderView { open($0) }

        case .moonDial:
            MoonDialScreen()

        // The two System-panel panels (0.7.3, A3/A4). Both read `AccessStore`
        // and `FirmwareCatalog` directly rather than taking them as arguments —
        // neither offers an entry, so neither needs the `open(_:)` gate every
        // catalog screen goes through.
        case .firmwareHistory:
            FirmwareHistoryScreen()

        case .cheatConsole:
            CheatConsoleScreen()

        // The premium builder (0.7.3, B1/B2). Reads and writes the eight
        // `DeviceAxis` keys directly — the same keys the chassis around this LCD
        // is reading, which is what makes the device its own live preview — so it
        // takes no arguments either. The `Entitlement.workshop` gate is on the
        // CUSTOMIZE button that pushes this, not here: routes in this app are
        // destinations rather than gates, and the one place a route *is* checked
        // (`open(_:)`) is checked because entries arrive from twenty screens.
        case .deviceWorkshop:
            DeviceWorkshopScreen()

        // The pedigree tree (0.7.5, E1). Gated on `Entitlement.lineage` at the
        // LINEAGE button that pushes it, not here — see `.deviceWorkshop` above
        // for the same reasoning.
        case .lineage(let id):
            if let entry = db.entry(id: id), case .grape(let g) = entry {
                GrapeLineageScreen(grape: g) { open($0) }
            } else {
                notFound
            }

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

// **Xcode only, and it has to be gated.** `#Preview` expands through the
// `PreviewsMacros` compiler plugin, which ships in Xcode's toolchain and not in
// the Linux swiftly toolchain that `xtool dev build` runs on — there, it is a
// hard error ("plugin for module 'PreviewsMacros' not found"), not a skipped
// macro. This arrived with the Aug 5 Xcode/simulator branch, where it built
// correctly; it only became a break when that branch met the xtool line.
//
// A flag rather than a deletion, because the preview is genuinely useful on the
// toolchain that can expand it: build with `-D XCODE_PREVIEWS` (Xcode: Build
// Settings ▸ Other Swift Flags) and it comes back. There is no source-level
// condition that detects the *host* toolchain, which is why this is opt-in
// rather than automatic.
#if XCODE_PREVIEWS
#Preview {
    RootView()
}
#endif
#endif
