#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// "WHAT'S THAT…?", played clue by clue (0.7.9, B).
///
/// **This file draws and nothing else.** Every rule the game has — which facts
/// become clues, what order they come out in, what a guess is worth, and whether
/// a typed answer is right — is in `WhatsThat` over in `VinodexCore`, where
/// `swift test` on Linux can see it. That is the house rule `OCRService` states
/// and this screen is the reason it is worth restating: a guessing game is
/// almost entirely rules, and putting them in a view would make the whole
/// feature untestable on the only machine that runs the tests.
///
/// **It replaces `DailyGrapeScreen`, behind the same door.** Same TOOLS tile,
/// same `DexRoute.dailyGrape`, same marquee, same `sparkles` glyph — the spec's
/// instruction was to replace what is behind the door and keep the door, and
/// every one of those is vocabulary rather than copy. What is gone is the
/// silhouette-and-REVEAL, whose own doc comment had already reasoned its way to
/// this screen's premise: "a shuffled entry shown outright is just a list of
/// one. Holding the name back for a beat turns it into a guess." Clues turn the
/// beat into a decision.
///
/// **The daily paper is a different feature and is untouched.** DAILY CHALLENGE
/// on the same shelf is `TastingQuiz` + `StreakStore`, and nothing here shares a
/// store, a seed or a screen with it.
///
/// **Where "grape of the day" went.** The pick is still `RevealCursor` stepping
/// through a day-seeded shuffle, exactly as the reveal used it: two players
/// opening it cold on the same date get the same entry, and each reopen deals
/// the next one. The answer is the thing that used to be revealed; it is now the
/// thing you are trying to name.
public struct WhatsThatScreen: View {
    let onOpen: (WineEntry) -> Void

    /// The round, and how much of it is showing. Held in `ScreenStateStore`
    /// rather than in `@State` alone for the reason `DailyGrapeScreen` recorded
    /// the hard way: this view is destroyed by any navigation away from it, so
    /// opening the answer's entry and pressing Back used to deal a new hand and
    /// lose the game you had just won.
    @State private var screens = ScreenStateStore.shared
    @State private var round: WhatsThat.Round?
    @State private var revealed = 1
    @State private var guess = ""
    @State private var verdict: WhatsThat.Verdict?
    @State private var solvedAt: Int?
    @State private var gaveUp = false

    private let db = WineDatabase.shared
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(onOpen: @escaping (WineEntry) -> Void) {
        self.onOpen = onOpen
    }

    /// The screen-state key is `dailyGrape`, unchanged. `ScreenStateStore` is
    /// session state and is never persisted (see its own note), so there is no
    /// stored vocabulary to migrate and no reason to mint a second key for the
    /// same door.
    private var stateKey: String { ScreenStateStore.dailyGrape }

    private var answer: WineEntry? {
        round.flatMap { db.entry(id: $0.answerID) }
    }

    private var isOver: Bool { solvedAt != nil || gaveUp }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            if let round {
                ScrollView {
                    content(round)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                // A catalog that cannot produce one solvable round is a broken
                // build, not an empty day — say which, as AUDIT M2 asks.
                DexEmptyState {
                    Text("NO ROUND AVAILABLE")
                        .font(DexFont.retro(12))
                        .foregroundStyle(Dex.stone400)
                }
            }
        }
        .onAppear(perform: restoreOrDeal)
        .onChange(of: revealed) { _, _ in save() }
        .onChange(of: solvedAt) { _, _ in save() }
        .onChange(of: gaveUp) { _, _ in save() }
    }

    // MARK: - Deal, restore, save

    /// Advance the cursor **once per visit**, never per render. `body` runs on
    /// every keystroke of the guess field, and a pick read there would deal a
    /// new answer under the player's fingers.
    private func restoreOrDeal() {
        guard round == nil else { return }
        if let held = screens.decoded(WhatsThat.Round.self, "round", for: stateKey) {
            round = held
            revealed = Int(screens.number("revealed", for: stateKey) ?? 1)
            gaveUp = screens.isOn("gaveUp", for: stateKey)
            if let at = screens.number("solvedAt", for: stateKey) { solvedAt = Int(at) }
            return
        }
        deal()
    }

    private func deal() {
        round = WhatsThat.round(cursor: RevealCursor.shared.advance(), in: db)
        revealed = 1
        guess = ""
        verdict = nil
        solvedAt = nil
        gaveUp = false
        save()
    }

    private func save() {
        screens.encode(round, "round", for: stateKey)
        screens.setNumber(Double(revealed), "revealed", for: stateKey)
        screens.setFlag("gaveUp", gaveUp, for: stateKey)
        screens.setNumber(solvedAt.map(Double.init), "solvedAt", for: stateKey)
    }

    // MARK: - Layout

    @ViewBuilder
    private func content(_ round: WhatsThat.Round) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // **E1 (0.8.0) takes the whole screen up one register**, the same
            // ask B5 makes of the BIOS and for the same reason: this is a
            // fixed, non-scrolling-by-choice page read at arm's length, and it
            // was set at the sizes a dense list uses. Everything with words in it
            // moves by roughly 15%, except the labels already sitting on
            // `TypeScale.nominalFloor` (the clue index, the feedback line) —
            // those are at 10 and a larger number there would be the first size
            // on this screen that is *not* the floor, which is a different
            // change from the one E1 asks for.
            //
            // Unlike the BIOS there is no width budget to derive against: this
            // page is inside a `ScrollView`, so the failure mode of going too far
            // is a longer scroll rather than a clipped composition.
            Text(isOver ? "IT WAS…" : "WHAT'S THAT…?")
                .font(DexFont.retro(17))
                .tracking(2)
                .foregroundStyle(Dex.yellow)
                .frame(maxWidth: .infinity, alignment: .center)

            clueList(round)

            if isOver {
                resultCard(round)
            } else {
                nextClueButton(round)
                guessField(round)
            }
        }
    }

    /// The chips, revealed ones first and the rest as empty slots.
    ///
    /// The unrevealed slots are drawn rather than omitted, because how many are
    /// left is the whole tension of the round — and because the score the player
    /// is playing for is a fraction of the total (see `Round.score`), which they
    /// cannot reason about without seeing the denominator.
    private func clueList(_ round: WhatsThat.Round) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(round.clues.enumerated()), id: \.element.id) { index, clue in
                let shown = index < revealed || isOver
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(DexFont.retro(10))
                        .foregroundStyle(shown ? lcd.accent : Dex.stone600)
                        .frame(width: 20)
                    Text(shown ? clue.text : "· · · · ·")
                        .font(DexFont.retro(13))
                        .tracking(0.5)
                        .foregroundStyle(shown ? lcd.text : Dex.stone600)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(shown ? lcd.surface : lcd.well)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            shown ? lcd.surfaceEdge : Dex.stone800,
                            style: StrokeStyle(lineWidth: 2, dash: shown ? [] : [4, 3])
                        )
                )
            }
        }
    }

    private func nextClueButton(_ round: WhatsThat.Round) -> some View {
        let last = revealed >= round.clues.count
        return Button {
            Haptics.select()
            withAnimation(DexMotion.settle) { revealed = min(revealed + 1, round.clues.count) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                // The cost is printed on the button. A player who cannot see
                // what a clue costs is not making a choice.
                Text(last
                     ? "NO CLUES LEFT"
                     : "NEXT CLUE  ·  \(round.score(revealed: revealed + 1)) PTS")
                    .font(DexFont.retro(13))
                    .tracking(1)
            }
            .foregroundStyle(last ? Dex.stone600 : lcd.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Capsule().fill(lcd.well))
            .overlay(Capsule().strokeBorder(last ? Dex.stone800 : lcd.surfaceEdge, lineWidth: 2))
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        .disabled(last)
    }

    // MARK: - Guessing

    /// **The real search shell, not a lookalike well (0.8.1, E).**
    ///
    /// The field was already a `DexSearchField` — the same control the list
    /// screens type into — sitting in a hand-rolled rounded rectangle with no
    /// magnifier. So the one place in the app where you type the name of an
    /// entry *at* the app was the one place that did not look like search.
    /// `DexSearchBarShell` is the extracted capsule the other four affordances
    /// wear, and it is generic over its content, so GUESS rides inside it
    /// rather than beside it.
    ///
    /// **This changes the field's clothes and nothing else.** The suggestion
    /// pool below is still `discoveredIDs` — bookmark shelves plus recently
    /// viewed — because suggesting an entry the player has never met hands over
    /// the answer, and filtering the answer out of a pool they *have* met would
    /// be an oracle: silence on `NEBB` tells you it is Nebbiolo. A search bar
    /// that searches the catalog is what this must never become.
    private func guessField(_ round: WhatsThat.Round) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DexSearchBarShell {
                DexSearchField(text: $guess, placeholder: "TYPE YOUR GUESS…", fontSize: 25)
                    .frame(height: 34)
                Button {
                    submit(round)
                } label: {
                    Text("GUESS")
                        .font(DexFont.retro(12))
                        .tracking(1)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(Capsule().fill(Dex.green))
                }
                .buttonStyle(DexPressStyle(scale: 0.96))
                .disabled(guess.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            suggestionRow

            if let verdict, case .correct = verdict {} else if let verdict {
                verdictLine(verdict)
            }

            // **A red button rather than a line of text (0.8.0, E3).** GIVE UP
            // was grey type on the background, which put the one irreversible
            // control on this screen in the register the app uses for captions —
            // and directly under a field whose Return key is the *reversible*
            // action. The treatment is `Dex.red800` filled with a `red500` edge:
            // plainly a control, plainly not the one you press by accident,
            // and visibly subordinate to GUESS above it, which is filled solid
            // green. It stays full-width and short, so it reads as the end of the
            // panel rather than as a second primary action beside GUESS.
            Button {
                Haptics.select()
                withAnimation(DexMotion.settle) { gaveUp = true }
            } label: {
                Text("GIVE UP")
                    .font(DexFont.retro(12))
                    .tracking(1.5)
                    .foregroundStyle(Dex.red200)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Capsule().fill(Dex.red800.opacity(0.55)))
                    .overlay(Capsule().strokeBorder(Dex.red500, lineWidth: 2))
            }
            .buttonStyle(DexPressStyle(scale: 0.98))
        }
    }

    /// The type-ahead (0.8.0, E2).
    ///
    /// **The rule is in `WhatsThat.suggestions` and the reasoning with it** — this
    /// is the drawing, per the file's own note. What lives here is only the pool:
    /// which ids count as "the player has met this". Four sources, all of them
    /// acts the player performed —
    ///
    ///   * the three `BookmarkStore` shelves (saved, want-to-try, tried), and
    ///   * `RecentlyViewedStore`, which is what covers browsing without saving.
    ///
    /// Recently-viewed leads, so the ties resolve toward what was just looked at.
    /// There is no general "discovered" ledger in this app and inventing one for a
    /// type-ahead would be a new persisted vocabulary for a convenience; these
    /// four are the honest approximation and they are all already on disk.
    ///
    /// Nothing is drawn until the round is live and two characters are in — the
    /// row simply is not there, rather than being there and empty, so it costs no
    /// height on the round's first move.
    @ViewBuilder
    private var suggestionRow: some View {
        let names = WhatsThat.suggestions(for: guess, among: discoveredIDs, in: db)
        if !names.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(names, id: \.self) { name in
                        Button {
                            Haptics.tap()
                            // Fills the field rather than submitting: the guess is
                            // still the player's to make, and a tap that both
                            // completed and answered would spend a round on a
                            // mis-tap.
                            guess = name.uppercased()
                        } label: {
                            Text(name.uppercased())
                                .font(DexFont.retro(11))
                                .tracking(0.5)
                                .foregroundStyle(lcd.accent)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(lcd.well))
                                .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 2))
                        }
                        .buttonStyle(DexPressStyle(scale: 0.96))
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 40)
        }
    }

    /// Entry ids the player has demonstrably encountered — see `suggestionRow`.
    private var discoveredIDs: [String] {
        RecentlyViewedStore.shared.ids
            + Shelf.allCases.flatMap { BookmarkStore.shared.ids(on: $0) }
    }

    /// A wrong guess that named something real says *what* it named — "that's
    /// Merlot" narrows the field, "no" does not.
    @ViewBuilder
    private func verdictLine(_ verdict: WhatsThat.Verdict) -> some View {
        switch verdict {
        case .correct:
            EmptyView()
        case .wrong(let named):
            feedback("THAT'S \(named.uppercased()) — NOT IT", tint: Dex.red500)
        case .unrecognized:
            feedback("NOTHING IN THE DEX BY THAT NAME", tint: Dex.amber400)
        }
    }

    private func feedback(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(DexFont.retro(10))
            .tracking(0.8)
            .foregroundStyle(tint)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func submit(_ round: WhatsThat.Round) {
        let result = WhatsThat.judge(guess, in: round)
        verdict = result
        guard case .correct = result else {
            Haptics.tap()
            return
        }
        Haptics.select()
        withAnimation(DexMotion.settle) { solvedAt = revealed }
    }

    // MARK: - The end of a round

    private func resultCard(_ round: WhatsThat.Round) -> some View {
        let won = solvedAt != nil
        let score = solvedAt.map { round.score(revealed: $0) } ?? 0
        return VStack(spacing: 14) {
            if let answer {
                EntryIconWell(entry: answer, size: 110, cornerRadius: 14)
            }
            Text(round.answerName.uppercased())
                .font(DexFont.retro(23))
                .foregroundStyle(lcd.text)
                .shadow(color: lcd.accent.opacity(0.55), radius: 0, x: 3, y: 3)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)

            Text(won
                 ? "SOLVED ON CLUE \(solvedAt ?? 0)  ·  \(score) PTS"
                 : "NOT GUESSED  ·  0 PTS")
                .font(DexFont.retro(13))
                .tracking(1)
                .foregroundStyle(won ? Dex.green : Dex.stone400)

            if let answer {
                Button {
                    Haptics.screenTap()
                    onOpen(answer)
                } label: {
                    pill("OPEN ENTRY", fill: Dex.green, ink: .black)
                }
                .buttonStyle(DexPressStyle(scale: 0.96))
            }

            Button {
                Haptics.select()
                withAnimation(DexMotion.settle) { deal() }
            } label: {
                pill("PLAY AGAIN", fill: Dex.yellow, ink: Dex.amber900)
            }
            .buttonStyle(DexPressStyle(scale: 0.96))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 8).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder((won ? Dex.green : Dex.stone600).opacity(0.6), lineWidth: 2)
        )
    }

    private func pill(_ text: String, fill: Color, ink: Color) -> some View {
        Text(text)
            .font(DexFont.retro(14))
            .tracking(2)
            .foregroundStyle(ink)
            .padding(.horizontal, 30)
            .padding(.vertical, 15)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
    }
}
#endif
