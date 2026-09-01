#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// **Vinobot's dialogue scene** (V1 of the rework, 2026-09-01; was Prof.
/// Vino's page from 0.8.93).
///
/// The page's whole history was a diagram of a character — faces, duties, a
/// dev ledger — stripped section by section through 0.9.4x until only a hero
/// and a switch remained. The rework spec's V1 makes it the thing the route
/// comment always promised: **a place to interact with him directly**, in
/// the RPG register — his portrait, a typewriter line, tappable choices,
/// his face changing as the conversation moves.
///
/// The graph and every authored word live in Core (`VinoScenes`), behind
/// `VinoSceneTests` — this file only walks the graph. The typewriter
/// respects Reduce Motion (instant reveal) and a tap skips to the full
/// line; choices appear when the line lands, per the register's grammar.
///
/// The silence switch survives as a conversation: SPEAK LESS / SPEAK MORE
/// on the root node performs the toggle and answers in character, stating
/// the new truth. The file keeps its name — the route, the tile and the
/// tests all point here, and per the house rule the label is what renamed,
/// never the vocabulary.
public struct ProfVinoScreen: View {
    @State private var triggers = FirstTimeTriggerStore.shared
    @State private var bookmarks = BookmarkStore.shared
    @AppStorage(VinoName.storageKey) private var displayName = ""
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    @State private var graph: [String: VinoSceneNode] = [:]
    @State private var currentID = "root"
    @State private var revealed = 0
    @State private var typing: Task<Void, Never>?

    /// V2: the two ways a conversation leaves the scene — a pick opens its
    /// entry page, SIT A PAPER opens the WINE EXAM. Wired by the app shell;
    /// default to no-ops so previews and tests can build the screen bare.
    let onOpenEntry: (String) -> Void
    let onExam: () -> Void

    public init(
        onOpenEntry: @escaping (String) -> Void = { _ in },
        onExam: @escaping () -> Void = {}
    ) {
        self.onOpenEntry = onOpenEntry
        self.onExam = onExam
    }

    private var node: VinoSceneNode? { graph[currentID] }
    private var lineDone: Bool {
        guard let node else { return true }
        return revealed >= node.text.count
    }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            VStack(spacing: 16) {
                portrait
                dialoguePanel
                Spacer(minLength: 0)
                choicePills
            }
            .padding(14)
        }
        .onAppear {
            if graph.isEmpty { rebuild(showing: "root") }
        }
        .onDisappear { typing?.cancel() }
    }

    // MARK: The scene pieces

    private var portrait: some View {
        VStack(spacing: 8) {
            DexChromeGlyph(
                (node?.expression ?? .neutral).artStem,
                symbol: "graduationcap.fill",
                size: 110,
                tint: lcd.accent
            )
            .animation(DexMotion.overlay, value: node?.expression)
            Text("VINOBOT")
                .font(DexFont.retro(20))
                .tracking(2)
                .foregroundStyle(lcd.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private var dialoguePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The typewriter line. `prefix` is safe past the end, so the
            // reveal counter never needs clamping.
            Text(String((node?.text ?? "").prefix(revealed)))
                .font(DexFont.mono(21))
                .foregroundStyle(lcd.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)

            if lineDone, let body = node?.importedBody {
                ScrollView {
                    Text(body)
                        .font(DexFont.mono(18))
                        .foregroundStyle(lcd.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxHeight: 170)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
        )
        .contentShape(Rectangle())
        // A tap mid-type lands the whole line — the register's universal
        // "yes yes, get on with it" gesture.
        .onTapGesture { skipToEnd() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vinobot: \(node?.text ?? "")")
    }

    @ViewBuilder
    private var choicePills: some View {
        // Choices arrive when the line has landed — tapping through text to
        // find buttons that were always there breaks the conversation's
        // rhythm; Reduce Motion never waits.
        if lineDone, let node {
            VStack(spacing: 8) {
                ForEach(node.choices, id: \.self) { choice in
                    Button {
                        Haptics.select()
                        advance(choice)
                    } label: {
                        Text(choice.label)
                            .font(DexFont.retro(12))
                            .tracking(1)
                            .foregroundStyle(lcd.accent)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(lcd.accent.opacity(0.6), lineWidth: 2)
                            )
                    }
                    .buttonStyle(DexPressStyle(scale: 0.98))
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: Walking the graph

    private func advance(_ choice: VinoSceneChoice) {
        // The quiet door performs its toggle BEFORE the graph rebuilds, so
        // the node it reveals states the new truth — see `VinoScenes`.
        if choice.goes == "quiet" {
            triggers.setSilenced(!triggers.isSilenced)
            rebuild(showing: "quiet")
            return
        }
        // The external destinations (V2): the conversation hands over to a
        // real page. `openRoute` semantics belong to the shell; here they
        // are plain callbacks.
        if choice.goes.hasPrefix("open:") {
            onOpenEntry(String(choice.goes.dropFirst("open:".count)))
            return
        }
        if choice.goes == "exam:" {
            onExam()
            return
        }
        show(choice.goes)
    }

    private func rebuild(showing id: String) {
        let db = WineDatabase.shared
        let triedIDs = bookmarks.ids(on: .tried)

        // MY PICKS: the same engine the passport strip reads, capped at the
        // three pills a scene can seat.
        let index = DiscoveryIndex(tried: triedIDs, in: db)
        let picks = PalateProfile(index: index)
            .recommendations(index: index, limit: 3)
            .map { VinoScenePick(id: $0.id, name: $0.name) }

        // The reason line's evidence: the origin the shelf leans on. Blends
        // ("Various") are excluded — leaning on nowhere is not a lean.
        var originCounts: [String: Int] = [:]
        for id in triedIDs {
            if let origin = db.entry(id: id)?.origin, origin != "Various" {
                originCounts[origin, default: 0] += 1
            }
        }
        let favorite = originCounts.filter { $0.value >= 2 }.max {
            $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value
        }?.key

        // STUDY: the exam ledger's own weakest-category rule, verbatim.
        let study = ExamRecordStore.shared.stats.weakest().map {
            VinoStudyReading(
                categoryLabel: $0.category.rawValue.replacingOccurrences(of: "_", with: " "),
                right: $0.tally.right,
                asked: $0.tally.asked
            )
        }

        graph = VinoScenes.compose(VinoSceneInput(
            name: displayName,
            moonDay: MoonCalendar.day(),
            goodDay: MoonCalendar.day().isGoodForDrinking,
            bestStreak: StreakStore.shared.best,
            triedCount: triedIDs.count,
            silenced: triggers.isSilenced,
            picks: picks,
            favoriteOrigin: favorite,
            study: study
        ))
        show(id)
    }

    private func show(_ id: String) {
        typing?.cancel()
        currentID = id
        revealed = 0
        guard let text = graph[id]?.text else { return }
        if reduceMotion {
            revealed = text.count
            return
        }
        typing = Task {
            for count in 1...text.count {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 18_000_000)
                if Task.isCancelled { return }
                revealed = count
            }
        }
    }

    private func skipToEnd() {
        guard let node, !lineDone else { return }
        typing?.cancel()
        revealed = node.text.count
    }
}
#endif
