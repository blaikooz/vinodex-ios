#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// Which paper this screen is sitting: the practice ladder or the daily.
public enum QuizMode: Equatable {
    case practice
    case daily
}

/// A WSET Level 1-style paper, in two flavours.
///
/// **Practice** is the ladder: pick an unlocked tier, ten questions, 8/10 to
/// pass, and a pass opens the next tier. **Daily** is one five-question paper
/// per local day — everyone gets the same one, there is no retry (the retry
/// would be the identical paper), and passing keeps the streak alive.
///
/// The reveal is the point. Every option is a real entry, so answering does not
/// end at a tick or a cross — the correct entry appears as the tile it appears
/// as everywhere else in the app, with its own page one tap away. A question you
/// got wrong is the best possible moment to be offered the reading, and a
/// question you got right is the moment you are most likely to take it.
///
/// Questions come from `TastingQuiz`, which builds them out of the shipped data
/// rather than from an authored bank — see the reasoning there. The run itself
/// is a `QuizSession`, so the whole thing survives the trip into an entry and
/// LEARN MORE does not cost you the paper you are halfway through.
public struct TastingQuizScreen: View {
    let mode: QuizMode
    let onOpen: (WineEntry) -> Void
    let onExit: () -> Void

    @State private var session: QuizSession?
    /// Set at the moment a practice pass opens a new tier, so the results
    /// screen can say so. State rather than recomputed: `recordPass` must
    /// fire exactly once per completion, not once per render.
    @State private var newlyUnlocked: QuizTier?
    /// The tier whose locked row was tapped; drives the explain alert.
    @State private var lockedTier: QuizTier?
    @State private var screens = ScreenStateStore.shared
    @State private var progress = QuizProgress.shared
    @State private var streak = StreakStore.shared

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    /// The database this screen reads. Defaulted so no call site changes, but
    /// injectable, which is the whole of **M27**: a screen that hard-reads
    /// `WineDatabase.shared` cannot be put in front of a fixture.
    private let db: WineDatabase

    public init(
        db: WineDatabase = .shared,
        mode: QuizMode = .practice,
        onOpen: @escaping (WineEntry) -> Void,
        onExit: @escaping () -> Void = {}
    ) {
        self.db = db
        self.mode = mode
        self.onOpen = onOpen
        self.onExit = onExit
    }

    private var question: QuizQuestion? {
        guard let session, !session.isComplete else { return nil }
        return TastingQuiz.question(
            number: session.index,
            sessionSeed: session.seed,
            tier: session.tier,
            in: db
        )
    }

    private var answered: Bool { session?.answered ?? false }
    private var chosenID: String? { session?.chosenID }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            // Centered unless the content overflows the LCD, in which case it
            // scrolls from the top like any other screen.
            GeometryReader { geo in
                ScrollView {
                    Group {
                        if let session, session.isComplete {
                            results(session)
                        } else if let session, let question {
                            content(question, session: session)
                        } else if mode == .daily {
                            dailyDone
                        } else {
                            tierPicker
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
        .onAppear(perform: restore)
        .onChange(of: session) { _, _ in persist() }
        // The verdict as a popup over the question (v0.5.9, D2), not a panel
        // appended below the options — inline, it landed off-screen exactly
        // when the question was long enough to scroll, and NEXT QUESTION with
        // it. Same in-LCD overlay language as `DexAlert`; no scrim-tap
        // dismissal, because the only ways on are the card's own buttons.
        .overlay {
            if answered, let session, !session.isComplete, let question {
                answerOverlay(question, session: session)
            }
        }
        .animation(.easeOut(duration: 0.2), value: answered)
        .overlay {
            if let lockedTier, let previous = previousTier(of: lockedTier) {
                DexAlert(
                    title: "\(lockedTier.displayName) IS LOCKED",
                    message: "Pass \(previous.displayName) — \(QuizSession.passMark) of \(QuizSession.length) — to unlock it.",
                    confirmLabel: "OK",
                    cancelLabel: nil,
                    onConfirm: { self.lockedTier = nil },
                    onCancel: { self.lockedTier = nil }
                )
            }
        }
        .animation(.easeOut(duration: 0.15), value: lockedTier)
    }

    private func previousTier(of tier: QuizTier) -> QuizTier? {
        QuizTier.allCases.first { $0.next == tier }
    }

    // MARK: State

    private var key: String {
        mode == .daily ? ScreenStateStore.dailyChallenge : ScreenStateStore.wsetQuiz
    }

    private func restore() {
        if let held = screens.decoded(QuizSession.self, "session", for: key) {
            session = held
            return
        }
        guard session == nil else { return }
        switch mode {
        case .practice:
            // No auto-start: the screen opens on the tier picker.
            break
        case .daily:
            // One sitting per day — a done day shows the done card instead.
            if !streak.isTodayDone() {
                session = DailyChallenge.session()
            }
        }
    }

    private func persist() {
        screens.encode(session, "session", for: key)
    }

    private func begin(_ tier: QuizTier) {
        guard progress.unlocked(tier) else {
            Haptics.select()
            lockedTier = tier
            return
        }
        Haptics.tap()
        newlyUnlocked = nil
        withAnimation(.easeOut(duration: 0.2)) {
            // Seeded off the reveal cursor so two runs started back to back do
            // not open on the same question.
            session = QuizSession(
                seed: RevealCursor.shared.value &+ DailyPick.dayIndex(),
                tier: tier
            )
        }
    }

    private func choose(_ id: String, in question: QuizQuestion) {
        guard var current = session, !current.answered else { return }
        // The one branch in the app where the *outcome* is the message, so it
        // gets the outcome haptics rather than the generic tap and ping both
        // answers used to share (AUDIT **L38**). A wrong answer has no
        // authored sound and no longer pretends to — `Sounds.wrong()` was an
        // empty stub, which left the wrong branch with nothing at all
        // (**L43**); the warning buzz is now what carries it.
        if question.isCorrect(id) {
            Sounds.correct()
            Haptics.success()
        } else {
            Haptics.warning()
        }
        current.choose(id, in: question)
        withAnimation(.easeOut(duration: 0.25)) { session = current }
    }

    private func next() {
        guard var current = session else { return }
        Haptics.tap()
        current.advance()

        // The one moment a paper completes — progression records exactly here,
        // never in a view body where re-renders would double-fire it.
        if current.isComplete {
            switch mode {
            case .practice:
                if current.passed {
                    newlyUnlocked = QuizProgress.shared.recordPass(tier: current.tier)
                }
            case .daily:
                StreakStore.shared.record(passed: current.passed)
            }
        }
        withAnimation(.easeOut(duration: 0.2)) { session = current }
    }

    private func retry() {
        Haptics.tap()
        newlyUnlocked = nil
        withAnimation(.easeOut(duration: 0.2)) { session = session?.retry() }
    }

    /// Practice EXIT returns to the tier picker; daily EXIT leaves the screen.
    private func exit() {
        Haptics.select()
        screens.forget(key)
        switch mode {
        case .practice:
            newlyUnlocked = nil
            withAnimation(.easeOut(duration: 0.2)) { session = nil }
        case .daily:
            onExit()
        }
    }

    // MARK: Tier picker

    private var tierPicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("CHOOSE YOUR EXAM")
                    .font(DexFont.retro(14))
                    .tracking(1.5)
                    .foregroundStyle(lcd.accent)
                Spacer(minLength: 8)
            }
            .padding(.bottom, 5)
            .overlay(alignment: .bottom) { lcd.accent.opacity(0.4).frame(height: 2) }

            VStack(spacing: 8) {
                ForEach(QuizTier.allCases) { tier in
                    tierRow(tier)
                }
            }

            Text("Ten questions, \(QuizSession.passMark) to pass. Passing a paper unlocks the next one.")
                .font(DexFont.mono(18))
                .foregroundStyle(lcd.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tierRow(_ tier: QuizTier) -> some View {
        let locked = !progress.unlocked(tier)
        let flavor = switch tier {
        case .novice: "The grapes everyone has heard of."
        case .enthusiast: "The full cellar."
        case .sommelier: "The back corner of the cellar."
        }

        return Button {
            begin(tier)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.displayName)
                        .font(DexFont.retro(13))
                        .tracking(1)
                        .foregroundStyle(locked ? lcd.disabledText : lcd.text)
                    Text(flavor)
                        .font(DexFont.mono(17))
                        .foregroundStyle(lcd.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(lcd.subtext)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(lcd.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(locked ? lcd.surfaceEdge.opacity(0.5) : lcd.accent.opacity(0.5), lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
    }

    /// The daily's done card: today's paper is sat, come back tomorrow.
    private var dailyDone: some View {
        VStack(spacing: 18) {
            Image(systemName: "flame.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(streak.current > 0 ? Dex.yellow : lcd.subtext)
                .shadow(color: Dex.yellow.opacity(streak.current > 0 ? 0.5 : 0), radius: 8)

            Text("PAPER COMPLETE")
                .font(DexFont.retro(16))
                .tracking(3)
                .foregroundStyle(lcd.text)

            Text(streak.current > 0
                ? "STREAK: \(streak.current) \(streak.current == 1 ? "DAY" : "DAYS"). COME BACK TOMORROW."
                : "TODAY'S PAPER IS DONE. A NEW ONE ARRIVES TOMORROW.")
                .font(DexFont.mono(18))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: { Haptics.select(); onExit() }) {
                Text("EXIT")
                    .font(DexFont.retro(12))
                    .tracking(1.5)
                    .foregroundStyle(lcd.subtext)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(lcd.surface))
                    .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 1))
            }
            .buttonStyle(DexPressStyle(scale: 0.97))
            .padding(.top, 6)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.heroWash))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 2)
        )
    }

    // MARK: Layout

    private func content(_ question: QuizQuestion, session: QuizSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header(question, session: session)
            prompt(question)
            options(question)
        }
    }

    /// Topic strip, sized to match the section headers in settings — at the old
    /// 11pt these read as captions rather than as headings.
    private func header(_ question: QuizQuestion, session: QuizSession) -> some View {
        HStack {
            Text(mode == .daily
                ? "DAILY · \(question.kind.topic)"
                : "\(session.tier.displayName) · \(question.kind.topic)")
                .font(DexFont.retro(14))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 8)
            Text("\(min(session.index + 1, session.length))/\(session.length)")
                .font(DexFont.mono(19))
                .foregroundStyle(lcd.subtext)
        }
        .padding(.bottom, 5)
        .overlay(alignment: .bottom) { lcd.accent.opacity(0.4).frame(height: 2) }
    }

    private func prompt(_ question: QuizQuestion) -> some View {
        Text(question.prompt)
            .font(DexFont.retro(15))
            .foregroundStyle(lcd.text)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func options(_ question: QuizQuestion) -> some View {
        VStack(spacing: 8) {
            ForEach(question.optionIDs, id: \.self) { id in
                optionRow(id: id, question: question)
            }
        }
    }

    /// Once answered, the right row goes green whether or not it was picked, and
    /// a wrong pick goes red. Showing only the user's own row would leave
    /// someone who guessed wrong without the answer.
    private func optionRow(id: String, question: QuizQuestion) -> some View {
        let name = db.entry(id: id)?.name ?? id
        let isAnswer = question.isCorrect(id)
        let isChoice = chosenID == id

        let tint: Color = {
            guard answered else { return lcd.surfaceEdge }
            if isAnswer { return Dex.green }
            return isChoice ? Dex.red500 : lcd.surfaceEdge.opacity(0.5)
        }()

        return Button {
            choose(id, in: question)
        } label: {
            HStack(spacing: 12) {
                Text(name.uppercased())
                    .font(DexFont.retro(13))
                    .foregroundStyle(answered && !isAnswer && !isChoice ? lcd.disabledText : lcd.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if answered, isAnswer {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Dex.green)
                } else if answered, isChoice {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Dex.red500)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 6).strokeBorder(tint, lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        .disabled(answered)
        // The result in words (AUDIT **L44**). Before this, right-or-wrong was
        // carried entirely by a glyph and a green/red border on a row that is
        // already `.disabled` — so VoiceOver read "Cabernet Sauvignon, dimmed"
        // for the correct answer and for every other option alike, and a
        // red/green pair carries nothing for a colour-blind reader either.
        //
        // One element rather than a label on the glyph: the row is one thing to
        // read, and a separate "checkmark" element after the name is exactly
        // the fragment a screen-reader user has to reassemble themselves.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(optionLabel(name: name, isAnswer: isAnswer, isChoice: isChoice))
    }

    /// What VoiceOver says for one option row — see `optionRow`.
    ///
    /// Unanswered it is just the name, because that is all the row is. Answered
    /// it names the outcome first: which one was right, and whether it was the
    /// one you picked. "Your answer, wrong" rather than "wrong", because the
    /// correct row is also announced after a wrong guess and the two must not
    /// be confusable.
    private func optionLabel(name: String, isAnswer: Bool, isChoice: Bool) -> String {
        guard answered else { return name }
        if isAnswer {
            return isChoice ? "\(name). Correct, your answer." : "\(name). Correct answer."
        }
        return isChoice ? "\(name). Wrong, your answer." : name
    }

    /// The reveal's modal shell: `DexAlert`'s scrim with the card scrollable,
    /// since the entry tile and its buttons outgrow a small phone's LCD. The
    /// answered rows stay visible behind the scrim, greens and reds intact.
    private func answerOverlay(_ question: QuizQuestion, session: QuizSession) -> some View {
        ZStack {
            // A power cut over the paper LCD reads wrong, so light mode dims
            // more gently — the same split DexAlert uses.
            Color.black.opacity(lcd.isLight ? 0.35 : 0.72)
                .contentShape(Rectangle())
            GeometryReader { geo in
                ScrollView {
                    reveal(question, session: session)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .frame(minHeight: geo.size.height, alignment: .center)
                }
            }
        }
        // Trap VoiceOver focus in the card rather than the scrimmed question,
        // per DexAlert's precedent.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .transition(.opacity)
    }

    /// The verdict, the entry itself, and the way into it.
    @ViewBuilder
    private func reveal(_ question: QuizQuestion, session: QuizSession) -> some View {
        let gotIt = chosenID.map(question.isCorrect) ?? false
        let answer = db.entry(id: question.answerID)
        let last = session.index == session.length - 1

        VStack(alignment: .leading, spacing: 12) {
            Text(gotIt ? "CORRECT" : "NOT QUITE")
                .font(DexFont.retro(14))
                .tracking(2)
                .foregroundStyle(gotIt ? Dex.green : Dex.yellow)

            if let answer {
                Text(answer.entryDescription)
                    .font(DexFont.mono(19))
                    .foregroundStyle(lcd.bodyText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                // The real tile, not a summary of one — the same row this entry
                // shows as in every list, so it is recognisably the same thing
                // and tapping it does what tapping it does everywhere else.
                EntryTileView(
                    entry: answer,
                    palette: db.palette,
                    locked: AccessStore.shared.isLocked(answer, in: db)
                ) {
                    onOpen(answer)
                }

                Button {
                    onOpen(answer)
                } label: {
                    label("LEARN MORE", fill: lcd.accent, ink: lcd.isLight ? .white : .black)
                }
                .buttonStyle(DexPressStyle(scale: 0.97))
            }

            Button(action: next) {
                label(last ? "SEE RESULTS" : "NEXT QUESTION", fill: Dex.yellow, ink: Dex.amber900)
            }
            .buttonStyle(DexPressStyle(scale: 0.97))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // A solid plate, not the hero wash: as a modal the card sits on the
        // scrim, and a tenth-opacity wash there is a hole, not a card.
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder((gotIt ? Dex.green : Dex.yellow).opacity(0.5), lineWidth: 2)
        )
        .transition(.opacity)
    }

    /// The end of the paper: score, verdict, and the ways out.
    private func results(_ session: QuizSession) -> some View {
        let tint: Color = session.passed ? Dex.green : Dex.red500

        return VStack(spacing: 18) {
            Image(systemName: session.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.5), radius: 8)

            Text("\(session.correct)/\(session.length)")
                .font(DexFont.retro(24))
                .foregroundStyle(lcd.text)

            Text(session.passed ? "PASS" : "FAIL")
                .font(DexFont.retro(16))
                .tracking(3)
                .foregroundStyle(tint)

            if let newlyUnlocked {
                Text("\(newlyUnlocked.displayName) UNLOCKED")
                    .font(DexFont.retro(14))
                    .tracking(2)
                    .foregroundStyle(Dex.yellow)
            }

            if mode == .daily {
                Text(streak.current > 0
                    ? "STREAK: \(streak.current) \(streak.current == 1 ? "DAY" : "DAYS")"
                    : "STREAK RESET — TOMORROW IS A FRESH PAPER")
                    .font(DexFont.mono(18))
                    .foregroundStyle(streak.current > 0 ? lcd.bodyText : lcd.subtext)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(session.passed
                    ? "WSET LEVEL 1 MATERIAL. SANTÉ!"
                    : "NOT QUITE — \(session.passMark)/\(session.length) PASSES. SWIRL AND RETRY.")
                    .font(DexFont.mono(18))
                    .foregroundStyle(lcd.subtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                if mode == .practice {
                    Button(action: retry) {
                        label("RETRY", fill: Dex.yellow, ink: Dex.amber900)
                    }
                    .buttonStyle(DexPressStyle(scale: 0.97))
                }

                Button(action: exit) {
                    Text(mode == .practice ? "BACK TO PAPERS" : "EXIT")
                        .font(DexFont.retro(12))
                        .tracking(1.5)
                        .foregroundStyle(lcd.subtext)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(lcd.surface))
                        .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 1))
                }
                .buttonStyle(DexPressStyle(scale: 0.97))
            }
            .padding(.top, 6)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.heroWash))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(0.5), lineWidth: 2)
        )
        .transition(.opacity)
    }

    private func label(_ text: String, fill: Color, ink: Color) -> some View {
        Text(text)
            .font(DexFont.retro(12))
            .tracking(1.5)
            .foregroundStyle(ink)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
    }
}
#endif
