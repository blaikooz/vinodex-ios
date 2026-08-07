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
    /// **One `Play` where there were four loose flags (0.8.8, E1/E2).**
    ///
    /// `revealed`/`solvedAt`/`gaveUp` were `@State` here and the transitions
    /// between them were written in this file, which put the game's rules in the
    /// module `swift test` cannot reach — in the file whose own header says it
    /// draws and nothing else. `WhatsThat.Play` is the same shape `QuizSession`
    /// has, for the same reason, and it is why the economy this batch adds is
    /// covered by tests rather than by eyeballing.
    @State private var screens = ScreenStateStore.shared
    @State private var play: WhatsThat.Play?
    @State private var guess = ""
    @State private var verdict: WhatsThat.Verdict?
    /// The clue a wrong guess just turned over, so the screen can say which.
    @State private var forfeited: WhatsThat.Clue?
    /// Whether this round has already been folded into the record.
    ///
    /// Persisted alongside the play in `ScreenStateStore`, because leaving the
    /// screen and coming back restores a *finished* round and must not count it
    /// a second time. `PassportProgress.announce`'s "record at the moment it
    /// happens" is the same hazard from the other side.
    @State private var recorded = false
    @State private var records = WhatsThatRecordStore.shared

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
        play.flatMap { db.entry(id: $0.round.answerID) }
    }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            if let play {
                ScrollView {
                    content(play)
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
        .onChange(of: play) { _, _ in save() }
    }

    // MARK: - Deal, restore, save

    /// Advance the cursor **once per visit**, never per render. `body` runs on
    /// every keystroke of the guess field, and a pick read there would deal a
    /// new answer under the player's fingers.
    private func restoreOrDeal() {
        guard play == nil else { return }
        // The key holds a whole `Play` since 0.8.8 where it held a `Round` and
        // three scalars. `ScreenStateStore` is session state and is never
        // written to disk (see its own note), so there is no stored vocabulary
        // to migrate and a session held across the update simply deals again.
        if let held = screens.decoded(WhatsThat.Play.self, "play", for: stateKey) {
            play = held
            recorded = screens.isOn("recorded", for: stateKey)
            return
        }
        deal()
    }

    private func deal() {
        play = WhatsThat.round(cursor: RevealCursor.shared.advance(), in: db)
            .map { WhatsThat.Play(round: $0) }
        guess = ""
        verdict = nil
        forfeited = nil
        recorded = false
        save()
    }

    private func save() {
        screens.encode(play, "play", for: stateKey)
        screens.setFlag("recorded", recorded, for: stateKey)
    }

    /// Fold a finished round into the record exactly once.
    ///
    /// Called from the three transitions that can end a round — never from a
    /// body, which is `PassportProgress.announce`'s contract and would otherwise
    /// count a re-render. `recorded` rides in `ScreenStateStore` so navigating
    /// away from a finished round and back cannot count it again either.
    private func bank() {
        guard let play, play.isOver, !recorded else { return }
        records.record(play)
        recorded = true
        save()
    }

    // MARK: - Layout

    @ViewBuilder
    private func content(_ play: WhatsThat.Play) -> some View {
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
            Text(play.isOver ? "IT WAS…" : "WHAT'S THAT…?")
                .font(DexFont.retro(17))
                .tracking(2)
                .foregroundStyle(Dex.yellow)
                .frame(maxWidth: .infinity, alignment: .center)

            scoreBar(play)
            clueList(play)

            if play.isOver {
                resultCard(play)
            } else {
                guessField(play)
            }
        }
    }

    /// What the round is currently worth, and the run it belongs to (0.8.8, E2/E3).
    ///
    /// The score used to appear only on the NEXT CLUE button, as the value the
    /// *next* purchase would leave you with, which meant the number a player was
    /// playing for was legible only as a consequence of an action they had not
    /// taken. It is a live readout now, beside the streak — because a score that
    /// feeds a run is a different number from one that does not, and E3 is what
    /// makes that true.
    private func scoreBar(_ play: WhatsThat.Play) -> some View {
        HStack(spacing: 10) {
            readout("WORTH", "\(play.round.score(revealed: play.revealedKinds))", tint: lcd.accent)
            readout("STREAK", "\(records.record.streak)", tint: Dex.yellow)
            readout("BEST", "\(records.record.bestScore)", tint: Dex.green)
        }
    }

    private func readout(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DexFont.retro(15))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(DexFont.retro(10))
                .tracking(0.8)
                .foregroundStyle(lcd.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 5).fill(lcd.well))
        .overlay(
            RoundedRectangle(cornerRadius: 5).strokeBorder(tint.opacity(0.4), lineWidth: 1)
        )
    }

    /// **The chips, and the hidden ones are the shop (0.8.8, E2).**
    ///
    /// The unrevealed slots were drawn rather than omitted because how many are
    /// left is the tension of the round, and that reason still holds. What is
    /// new is that each one is a *button* carrying its own price, because the
    /// clues are no longer interchangeable and pricing them alike is what left
    /// NEXT CLUE as the only decision on the screen. Buying the appellation
    /// early is now a thing a player can do and pay four times over for.
    ///
    /// The order stays the round's own vague-to-specific order rather than
    /// re-sorting bought clues to the top: the list is the round's shape, and a
    /// list that reorders under a tap is a list you have to re-read.
    private func clueList(_ play: WhatsThat.Play) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(play.round.clues.enumerated()), id: \.element.id) { index, clue in
                let shown = play.revealedKinds.contains(clue.kind) || play.isOver
                let cost = play.price(of: clue)
                Button {
                    guard !shown, !play.isOver else { return }
                    Haptics.select()
                    forfeited = nil
                    withAnimation(DexMotion.settle) { self.play?.reveal(clue.kind) }
                } label: {
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
                        // The price rides on the chip it buys. A player who
                        // cannot see what a clue costs is not making a choice —
                        // 0.8.0's argument for printing it on NEXT CLUE, now
                        // that there are five different answers to it.
                        if !shown && !play.isOver {
                            Text("−\(cost)")
                                .font(DexFont.retro(11))
                                .foregroundStyle(Dex.amber400)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(shown ? lcd.surface : lcd.well)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                clue.id == forfeited?.id ? Dex.red500
                                    : (shown ? lcd.surfaceEdge : Dex.stone800),
                                style: StrokeStyle(lineWidth: 2, dash: shown ? [] : [4, 3])
                            )
                    )
                }
                .buttonStyle(DexPressStyle(scale: 0.99))
                .disabled(shown || play.isOver)
            }
        }
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
    ///
    /// **What a guess costs now (0.8.8, E1).** The caption under the field says
    /// it outright, because the round's whole economy changed and a control that
    /// silently started charging would be worse than one that never did. A
    /// named-but-wrong guess turns over the cheapest clue left; typing something
    /// the dex has never heard of is free.
    private func guessField(_ play: WhatsThat.Play) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DexSearchBarShell {
                DexSearchField(text: $guess, placeholder: "TYPE YOUR GUESS…", fontSize: 25)
                    .frame(height: 34)
                Button {
                    submit()
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

            Text(play.forfeit.map { "A WRONG NAME COSTS \(play.price(of: $0)) PTS" }
                 ?? "NO CLUES LEFT — A WRONG NAME ENDS IT")
                .font(DexFont.retro(10))
                .tracking(0.8)
                .foregroundStyle(Dex.stone400)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                withAnimation(DexMotion.settle) { self.play?.giveUp() }
                bank()
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

    /// **Judge, then let the round absorb it (0.8.8, E1).**
    ///
    /// The verdict is still `WhatsThat.judge`'s and the consequence is now
    /// `Play.record`'s — this function does neither, which is the file's own
    /// rule finally applied to the one place that was breaking it. What is left
    /// here is the two things that genuinely are drawing: which haptic fires,
    /// and which chip flashes red.
    private func submit() {
        guard var current = play, !current.isOver else { return }
        let result = WhatsThat.judge(guess, in: current.round)
        verdict = result
        let taken = current.record(result)
        withAnimation(DexMotion.settle) {
            play = current
            forfeited = taken
        }
        if case .correct = result { Haptics.select() } else { Haptics.tap() }
        bank()
    }

    // MARK: - The end of a round

    private func resultCard(_ play: WhatsThat.Play) -> some View {
        let won = play.outcome == .solved
        return VStack(spacing: 14) {
            if let answer {
                EntryIconWell(entry: answer, size: 110, cornerRadius: 14)
            }
            Text(play.round.answerName.uppercased())
                .font(DexFont.retro(23))
                .foregroundStyle(lcd.text)
                .shadow(color: lcd.accent.opacity(0.55), radius: 0, x: 3, y: 3)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)

            // Three endings now, where there were two. Running out of clues with
            // a wrong name on the field is a *loss* rather than a surrender, and
            // saying so is the difference between a game you failed and a game
            // you left.
            Text(endingLine(play))
                .font(DexFont.retro(13))
                .tracking(1)
                .foregroundStyle(won ? Dex.green : Dex.stone400)
                .multilineTextAlignment(.center)

            if won, records.record.streak > 1 {
                Text("\(records.record.streak) IN A ROW")
                    .font(DexFont.retro(11))
                    .tracking(1)
                    .foregroundStyle(Dex.yellow)
            }

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

    private func endingLine(_ play: WhatsThat.Play) -> String {
        switch play.outcome {
        case .solved:
            let opened = play.revealed.count
            return "SOLVED ON \(opened) CLUE\(opened == 1 ? "" : "S")  ·  \(play.score) PTS"
        case .lost:
            return "OUT OF CLUES  ·  0 PTS"
        case .gaveUp, .none:
            return "NOT GUESSED  ·  0 PTS"
        }
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
