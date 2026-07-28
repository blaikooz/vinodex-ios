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

    private let db = WineDatabase.shared

    /// No `NavigationStack`: the chassis is physical furniture and should not
    /// slide off-screen when you press a button on it. Only the LCD content
    /// changes, which is also what the device metaphor implies. `path` is still
    /// a stack, so Back and Home behave exactly as before.
    var body: some View {
        DeviceChassis(
            title: currentTitle,
            showsBack: !path.isEmpty,
            onBack: path.isEmpty ? nil : { goBack() },
            onHome: { goHome() }
        ) {
            screen
                // Content swaps instantly; no push transition.
                .transaction { $0.animation = nil }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear { ScreenWake.keepAwake(true) }
        .onDisappear { ScreenWake.keepAwake(false) }
        // The system panel (settings, diagnostics, catalog) is owned by
        // DeviceChassis so it can be confined to the LCD; the app module no
        // longer presents it.
    }

    private var currentTitle: String {
        guard let route = path.last else { return "VINODEX" }
        if case .detail(let id) = route, let entry = db.entry(id: id) {
            return entry.scanTitle
        }
        return route.title
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
            ) { push($0.destination) }

        case .masterSearch:
            EncyclopediaListScreen(categories: Set(EntryCategory.allCases)) { push($0.destination) }

        case .detail(let id):
            if let entry = db.entry(id: id) {
                EntryDetailScreen(entry: entry) { push($0.destination) }
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

        case .globeSearch:
            // Continents and regions between them carry country and state
            // names, and `matchesSearch` already looks at origin and state.
            EncyclopediaListScreen(categories: [.continents, .regions]) { push($0.destination) }

        case .continent(let id):
            if let entry = db.entry(id: id), case .continent(let c) = entry {
                ContinentScreen(continent: c) { country in
                    push(.list(category: .regions, filter: .origin(country)))
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
        var next = path
        next.append(route)
        path = next
    }

    private func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    private func goHome() {
        path.removeAll()
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
