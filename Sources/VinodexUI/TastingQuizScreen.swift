#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// THE DAILY CHALLENGE — one five-question paper per local day.
///
/// Everyone gets the same paper, there is no retry (the retry would be the
/// identical paper), and passing keeps the streak alive.
///
/// **This screen used to be both papers, and 0.7.5 (D) took one of them away.**
/// Its `.practice` mode was the WINE EXAM, and the Wine Exam is now the authored
/// bank — 407 questions, sixteen subjects, seven formats, an explanation on
/// every one. See `WineExamScreen`. What went with the practice mode was the
/// tier picker, the ladder unlock and RETRY, all of which the exam now owns; the
/// `QuizMode` enum went with them, because a two-case enum with one case left is
/// a parameter every call site has to pass and no call site can vary.
///
/// **What did *not* move, and why this is not leftover.** The daily is generated
/// from the catalog by `TastingQuiz` and stays that way. An authored bank is
/// finite and a daily is not: 407 questions at five a day is under three months
/// before the repeats start, and a paper that must be the same for everyone,
/// every day, forever is exactly the case a generator answers and a bank cannot.
/// The generated paper also cannot contradict an entry, which matters more here
/// than on the exam, where every claim was authored against a source.
///
/// The reveal is the point. Every option is a real entry, so answering does not
/// end at a tick or a cross — the correct entry appears as the tile it appears
/// as everywhere else in the app, with its own page one tap away. A question you
/// got wrong is the best possible moment to be offered the reading, and a
/// question you got right is the moment you are most likely to take it.
public struct TastingQuizScreen: View {
    let onOpen: (WineEntry) -> Void
    let onExit: () -> Void

    @State private var session: QuizSession?
    @State private var screens = ScreenStateStore.shared
    @State private var streak = StreakStore.shared

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    private let db = WineDatabase.shared

    public init(
        onOpen: @escaping (WineEntry) -> Void,
        onExit: @escaping () -> Void = {}
    ) {
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
                // **Larger where there is room** (0.7.0, J3), on the same
                // measured-slack rule as the moon dial and the daily reveal —
                // see `PageRoom`. This page is the least constrained of the
                // three because it already scrolls when it has to, but it runs
                // the same helper rather than a second idea of "bigger": three
                // pages growing by three different rules is how the type scale
                // drifted apart in the first place.
                let grow = CGFloat(PageRoom.growth(pageHeight: Double(geo.size.height)))
                ScrollView {
                    Group {
                        if let session, session.isComplete {
                            results(session)
                        } else if let session, let question {
                            content(question, session: session, grow: grow)
                        } else {
                            dailyDone
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
    }

    // MARK: State

    private var key: String { ScreenStateStore.dailyChallenge }

    private func restore() {
        if let held = screens.decoded(QuizSession.self, "session", for: key) {
            session = held
            return
        }
        guard session == nil else { return }
        // One sitting per day — a done day shows the done card instead.
        if !streak.isTodayDone() {
            session = DailyChallenge.session()
        }
    }

    private func persist() {
        screens.encode(session, "session", for: key)
    }

    private func choose(_ id: String, in question: QuizQuestion) {
        guard var current = session, !current.answered else { return }
        // One voice per answer (0.6.9, G1). This used to pair the result sting
        // with `screenTap()`/`select()`, both of which play Warm Ping since
        // 0.6.8 (J1) — so every answer fired two authored sounds at once. See
        // `Haptics.answer(correct:)`; the haptic split it carried is preserved
        // inside it.
        Haptics.answer(correct: question.isCorrect(id))
        current.choose(id, in: question)
        withAnimation(.easeOut(duration: 0.25)) { session = current }
    }

    private func next() {
        guard var current = session else { return }
        Haptics.screenTap()
        current.advance()

        // The one moment a paper completes — the streak records exactly here,
        // never in a view body where re-renders would double-fire it.
        if current.isComplete {
            StreakStore.shared.record(passed: current.passed)
        }
        withAnimation(.easeOut(duration: 0.2)) { session = current }
    }

    private func exit() {
        Haptics.select()
        screens.forget(key)
        onExit()
    }

    /// The daily's done card: today's paper is sat, come back tomorrow.
    private var dailyDone: some View {
        VStack(spacing: 18) {
            Image(systemName: DexGlyph.challenge)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(streak.current > 0 ? Dex.yellow : lcd.subtext)
                .shadow(color: Dex.yellow.opacity(streak.current > 0 ? 0.5 : 0), radius: 8)

            // "PAPER COMPLETE" through 0.6.6. The screen's own vocabulary is
            // "paper" throughout — it is a WSET-shaped app — but the *user*
            // never sees that word anywhere else: the tile says DAILY
            // CHALLENGE, the marquee says DAILY CHALLENGE, and the completion
            // card said something else entirely. (0.6.7, A1)
            Text("DAILY CHALLENGE COMPLETED.")
                .font(DexFont.retro(13))
                .tracking(2)
                .foregroundStyle(lcd.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

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

    private func content(_ question: QuizQuestion, session: QuizSession, grow: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16 + 8 * grow) {
            header(question, session: session, grow: grow)
            prompt(question, grow: grow)
            options(question, grow: grow)
        }
    }

    /// Topic strip, sized to match the section headers in settings — at the old
    /// 11pt these read as captions rather than as headings.
    private func header(_ question: QuizQuestion, session: QuizSession, grow: CGFloat) -> some View {
        HStack {
            Text("DAILY · \(question.kind.topic)")
                .font(DexFont.retro(14 + 4 * grow))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 8)
            Text("\(min(session.index + 1, session.length))/\(session.length)")
                .font(DexFont.mono(19 + 5 * grow))
                .foregroundStyle(lcd.subtext)
        }
        .padding(.bottom, 5)
        .overlay(alignment: .bottom) { lcd.accent.opacity(0.4).frame(height: 2) }
    }

    private func prompt(_ question: QuizQuestion, grow: CGFloat) -> some View {
        Text(question.prompt)
            .font(DexFont.retro(15 + 6 * grow))
            .foregroundStyle(lcd.text)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func options(_ question: QuizQuestion, grow: CGFloat) -> some View {
        VStack(spacing: 8 + 4 * grow) {
            ForEach(question.optionIDs, id: \.self) { id in
                optionRow(id: id, question: question, grow: grow)
            }
        }
    }

    /// Once answered, the right row goes green whether or not it was picked, and
    /// a wrong pick goes red. Showing only the user's own row would leave
    /// someone who guessed wrong without the answer.
    private func optionRow(id: String, question: QuizQuestion, grow: CGFloat) -> some View {
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
                    .font(DexFont.retro(13 + 5 * grow))
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
            .padding(.horizontal, 14 + 5 * grow)
            .padding(.vertical, 16 + 8 * grow)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 6).strokeBorder(tint, lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        .disabled(answered)
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

            Text(streak.current > 0
                ? "STREAK: \(streak.current) \(streak.current == 1 ? "DAY" : "DAYS")"
                : "STREAK RESET — TOMORROW IS A FRESH PAPER")
                .font(DexFont.mono(18))
                .foregroundStyle(streak.current > 0 ? lcd.bodyText : lcd.subtext)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button(action: exit) {
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
