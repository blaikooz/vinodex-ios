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
            Text(isOver ? "IT WAS…" : "WHAT'S THAT…?")
                .font(DexFont.retro(15))
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
                        .frame(width: 18)
                    Text(shown ? clue.text : "· · · · ·")
                        .font(DexFont.retro(11))
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
                    .font(.system(size: 14, weight: .bold))
                // The cost is printed on the button. A player who cannot see
                // what a clue costs is not making a choice.
                Text(last
                     ? "NO CLUES LEFT"
                     : "NEXT CLUE  ·  \(round.score(revealed: revealed + 1)) PTS")
                    .font(DexFont.retro(11))
                    .tracking(1)
            }
            .foregroundStyle(last ? Dex.stone600 : lcd.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Capsule().fill(lcd.well))
            .overlay(Capsule().strokeBorder(last ? Dex.stone800 : lcd.surfaceEdge, lineWidth: 2))
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        .disabled(last)
    }

    // MARK: - Guessing

    private func guessField(_ round: WhatsThat.Round) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                DexSearchField(text: $guess, placeholder: "TYPE YOUR GUESS…", fontSize: 22)
                    .frame(height: 40)
                Button {
                    submit(round)
                } label: {
                    Text("GUESS")
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(Capsule().fill(Dex.green))
                }
                .buttonStyle(DexPressStyle(scale: 0.96))
                .disabled(guess.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(lcd.well)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(lcd.surfaceEdge, lineWidth: 2))

            if let verdict, case .correct = verdict {} else if let verdict {
                verdictLine(verdict)
            }

            Button {
                Haptics.select()
                withAnimation(DexMotion.settle) { gaveUp = true }
            } label: {
                Text("GIVE UP")
                    .font(DexFont.retro(10))
                    .tracking(1)
                    .foregroundStyle(Dex.stone400)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
            }
            .buttonStyle(DexPressStyle(scale: 0.98))
        }
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
                EntryIconWell(entry: answer, size: 96, cornerRadius: 12)
            }
            Text(round.answerName.uppercased())
                .font(DexFont.retro(20))
                .foregroundStyle(lcd.text)
                .shadow(color: lcd.accent.opacity(0.55), radius: 0, x: 3, y: 3)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)

            Text(won
                 ? "SOLVED ON CLUE \(solvedAt ?? 0)  ·  \(score) PTS"
                 : "NOT GUESSED  ·  0 PTS")
                .font(DexFont.retro(11))
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
            .font(DexFont.retro(12))
            .tracking(2)
            .foregroundStyle(ink)
            .padding(.horizontal, 28)
            .padding(.vertical, 13)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
    }
}
#endif
