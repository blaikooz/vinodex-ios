#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// THE WINE EXAM (0.7.5, D) — the authored bank's screen.
///
/// ## What this replaced, and what it did not
///
/// This is `DexRoute.wsetQuiz`, which has been titled WINE EXAM since 0.5.9.
/// D1 asks to expand the Wine Exam into a full educational system, so it is the
/// same door with a different room behind it: the same tier ladder, the same
/// completion stars, the same `quizTierUnlocked` on disk, the same passport
/// badge. What changed is where the questions come from — 407 authored ones
/// across sixteen categories and seven formats, instead of three shapes
/// generated from the catalog — and that every answer is now followed by an
/// explanation.
///
/// `TastingQuizScreen` keeps the daily challenge. See `Exam.swift` for why that
/// split is deliberate rather than leftover.
///
/// ## The seven formats are a `switch`, not a list of ifs
///
/// `card(_:)` switches over `ExamQuestion.Payload` and the switch is exhaustive,
/// so an eighth format cannot be authored without this file refusing to compile.
/// That is the only gate D5 can have: `VinodexUI` is invisible to the Linux
/// tests, so "all seven formats have an answering UI" is proved by the clean
/// xtool build or not at all.
///
/// ## Answering is tap-only, including the two that look like drags
///
/// Matching and ordering are the formats a desktop would do with drag and drop.
/// They do not here. The LCD is about 2.5 inches wide, and 0.7.2's A2 is the
/// standing lesson about what happens when a new drag gesture joins the stamp
/// drag and the globe pan in arbitration — two batches of a dead control that
/// no Linux gate could see. Matching is *select a left, then tap its right*;
/// ordering is *tap the items in order, tap again to unset*. Both are
/// unambiguous at this size and neither negotiates with anything.
public struct WineExamScreen: View {
    let onOpen: (WineEntry) -> Void
    let onExit: () -> Void

    @State private var run: ExamRun?
    /// The tier whose locked row was tapped; drives the explain alert.
    @State private var lockedTier: QuizTier?
    /// Set at the moment a pass opens a new rung, so the results card can say
    /// so. State rather than recomputed: recording must fire once per
    /// completion, never once per render.
    @State private var newlyUnlocked: QuizTier?
    /// Draft answers for the multi-tap formats, held in view state rather than
    /// in `ExamRun` while they are still being built.
    @State private var picks: Set<Int> = []
    @State private var pairing: [Int: Int] = [:]
    @State private var pendingLeft: Int?
    @State private var sequence: [Int] = []
    @State private var showingStats = false

    @State private var screens = ScreenStateStore.shared
    @State private var progress = QuizProgress.shared
    @State private var records = ExamRecordStore.shared

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    private let db = WineDatabase.shared
    private let catalog = ExamCatalog.shared

    public init(onOpen: @escaping (WineEntry) -> Void, onExit: @escaping () -> Void = {}) {
        self.onOpen = onOpen
        self.onExit = onExit
    }

    // MARK: - The paper

    /// Re-derived from the run's seed rather than stored. `ExamPaper.assemble`
    /// is pure, so this is the same ten questions in the same order with the
    /// same shuffles every time — which is what lets the session state be one
    /// integer instead of a few kilobytes of question text.
    private var paper: [ExamPrompt] {
        guard let run else { return [] }
        guard case .success(let prompts) = ExamPaper.assemble(
            tier: run.tier, length: run.length, seed: run.seed, in: catalog
        ) else { return [] }
        return prompts
    }

    private var prompt: ExamPrompt? {
        guard let run, !run.isComplete else { return nil }
        let paper = self.paper
        return paper.indices.contains(run.index) ? paper[run.index] : nil
    }

    public var body: some View {
        ZStack {
            DexScreenBackground()
            GeometryReader { geo in
                let grow = CGFloat(PageRoom.growth(pageHeight: Double(geo.size.height)))
                ScrollView {
                    Group {
                        if let run, run.isComplete {
                            results(run)
                        } else if let run, let prompt {
                            question(prompt, run: run, grow: grow)
                        } else if run != nil {
                            // A run whose paper will not assemble. Only reachable
                            // if the bank failed to load between start and now.
                            failure(.emptyBank(tier: run?.tier ?? .beginner))
                        } else if showingStats {
                            statsPanel(grow: grow)
                        } else {
                            picker(grow: grow)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
        .onAppear(perform: restore)
        .onChange(of: run) { _, _ in persist() }
        .overlay {
            if let run, run.submitted, !run.isComplete, let prompt {
                reveal(prompt, run: run)
            }
        }
        .animation(.easeOut(duration: 0.2), value: run?.submitted)
        .overlay {
            if let lockedTier, let previous = previousRung(of: lockedTier) {
                DexAlert(
                    title: "\(lockedTier.displayName) IS LOCKED",
                    message: "Pass \(previous.displayName) — \(ExamPaper.passMark) of \(ExamPaper.length) — to unlock it.",
                    confirmLabel: "OK",
                    cancelLabel: nil,
                    onConfirm: { self.lockedTier = nil },
                    onCancel: { self.lockedTier = nil }
                )
            }
        }
        .animation(DexMotion.overlay, value: lockedTier)
    }

    private func previousRung(of tier: QuizTier) -> QuizTier? {
        QuizTier.allCases.first { $0.next == tier }
    }

    // MARK: - Session state

    private var key: String { ScreenStateStore.wsetQuiz }

    private func restore() {
        if let held = screens.decoded(ExamRun.self, "exam", for: key) { run = held }
    }

    private func persist() {
        screens.encode(run, "exam", for: key)
    }

    private func begin(_ rung: QuizTier) {
        guard progress.unlocked(rung) else {
            Haptics.select()
            lockedTier = rung
            return
        }
        Haptics.screenTap()
        newlyUnlocked = nil
        clearDrafts()
        withAnimation(.easeOut(duration: 0.2)) {
            // Seeded off the reveal cursor and the day, as the quiz was: two
            // runs started back to back must not open on the same paper.
            run = ExamRun(
                seed: RevealCursor.shared.value &+ DailyPick.dayIndex(),
                tier: rung.examTier
            )
        }
    }

    private func clearDrafts() {
        picks = []
        pairing = [:]
        pendingLeft = nil
        sequence = []
    }

    /// Grades the current question. **The one place a mark is recorded** — in a
    /// handler, never in a view body, where a re-render would double-fire it.
    private func submit(_ prompt: ExamPrompt) {
        guard var current = run, !current.submitted, current.answer != nil else { return }
        let right = current.submit(prompt)
        Haptics.answer(correct: right)
        withAnimation(.easeOut(duration: 0.25)) { run = current }
    }

    private func next() {
        guard var current = run else { return }
        Haptics.screenTap()
        current.advance()
        clearDrafts()
        // The one moment a paper completes. `record` writes the history, the
        // streak *and* the ladder unlock — see `ExamRecordStore`.
        if current.isComplete {
            newlyUnlocked = records.record(current)
        }
        withAnimation(.easeOut(duration: 0.2)) { run = current }
    }

    private func retry() {
        Haptics.screenTap()
        newlyUnlocked = nil
        clearDrafts()
        withAnimation(.easeOut(duration: 0.2)) { run = run?.retry() }
    }

    /// Leaves the paper for the picker. The run is forgotten, so an abandoned
    /// paper is abandoned rather than lying in wait.
    ///
    /// `showingStats` is cleared here too: without it, somebody who looked at
    /// their statistics, sat a paper and came back would land on the statistics
    /// panel instead of the picker, because the flag would still be set from
    /// before the paper started.
    private func exit() {
        Haptics.select()
        screens.forget(key)
        newlyUnlocked = nil
        showingStats = false
        clearDrafts()
        withAnimation(.easeOut(duration: 0.2)) { run = nil }
    }

    // MARK: - Picker

    private func picker(grow: CGFloat) -> some View {
        let stats = records.stats
        return VStack(alignment: .leading, spacing: 16 + 8 * grow) {
            heading("CHOOSE YOUR EXAM", grow: grow)

            if catalog.isEmpty {
                failure(.emptyBank(tier: .beginner))
            } else {
                VStack(spacing: 8 + 4 * grow) {
                    ForEach(QuizTier.allCases) { rung in
                        pickerRow(rung, grow: grow)
                    }
                }

                Text("\(ExamPaper.length) questions across \(ExamCategory.allCases.count) subjects, "
                    + "\(ExamPaper.passMark) to pass. Passing a paper unlocks the next one.")
                    .font(DexFont.mono(18 + 4 * grow))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)

                if stats.papers > 0 {
                    Button {
                        Haptics.select()
                        withAnimation(DexMotion.overlay) { showingStats = true }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 14, weight: .bold))
                            Text("STATISTICS")
                                .font(DexFont.retro(12))
                                .tracking(1.5)
                            Spacer(minLength: 8)
                            Text("\(stats.papers) \(stats.papers == 1 ? "PAPER" : "PAPERS")")
                                .font(DexFont.mono(17))
                        }
                        .foregroundStyle(lcd.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                        )
                    }
                    .buttonStyle(DexPressStyle(scale: 0.98))
                }
            }
        }
    }

    private func pickerRow(_ rung: QuizTier, grow: CGFloat) -> some View {
        let locked = !progress.unlocked(rung)
        let passed = progress.isCompleted(rung)
        let best = records.stats.bestByTier[rung.examTier]
        let flavor = switch rung {
        case .novice: "The foundations, across every subject."
        case .enthusiast: "The working knowledge of a serious drinker."
        case .sommelier: "Law, blending percentages and the back corner."
        }

        return Button {
            begin(rung)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        if passed {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Dex.yellow)
                                .shadow(color: Dex.yellow.opacity(0.5), radius: 3)
                                .accessibilityLabel("Completed")
                        }
                        Text(rung.displayName)
                            .font(DexFont.retro(13 + 5 * grow))
                            .tracking(1)
                            .foregroundStyle(locked ? lcd.disabledText : lcd.text)
                    }
                    Text(flavor)
                        .font(DexFont.mono(17 + 4 * grow))
                        .foregroundStyle(lcd.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                    if let best, !locked {
                        Text("BEST \(Int((best * 100).rounded()))%")
                            .font(DexFont.mono(16))
                            .foregroundStyle(lcd.accent)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: locked ? "lock.fill" : "chevron.right")
                    .font(.system(size: locked ? 16 : 15, weight: .bold))
                    .foregroundStyle(locked ? lcd.subtext : lcd.accent)
            }
            .padding(.horizontal, 14 + 5 * grow)
            .padding(.vertical, 16 + 8 * grow)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(locked ? lcd.surfaceEdge.opacity(0.5) : lcd.accent.opacity(0.5), lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
    }

    // MARK: - Statistics (D6)

    private func statsPanel(grow: CGFloat) -> some View {
        let stats = records.stats
        return VStack(alignment: .leading, spacing: 14 + 6 * grow) {
            heading("STATISTICS", grow: grow)

            VStack(spacing: 8) {
                statRow("PAPERS SAT", "\(stats.papers)")
                statRow("PASSED", "\(stats.passes)")
                statRow("ACCURACY", "\(Int((stats.accuracy * 100).rounded()))%")
                statRow("PASS STREAK", "\(stats.passStreak)")
                statRow("BEST STREAK", "\(stats.bestPassStreak)")
                statRow("FULL MARKS", "\(stats.perfectPapers)")
            }

            // The useful half. A study tool that only tells you your score is a
            // scoreboard; the subject you keep dropping is the thing you came
            // for.
            if let weakest = stats.weakest() {
                subheading("STUDY THIS")
                studyRow(weakest.category, tally: weakest.tally, tint: Dex.yellow)
            }
            if let strongest = stats.strongest(), strongest.category != stats.weakest()?.category {
                subheading("STRONGEST")
                studyRow(strongest.category, tally: strongest.tally, tint: Dex.green)
            }

            Button {
                Haptics.select()
                withAnimation(DexMotion.overlay) { showingStats = false }
            } label: {
                Text("BACK TO EXAMS")
                    .font(DexFont.retro(12))
                    .tracking(1.5)
                    .foregroundStyle(lcd.subtext)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(lcd.surface))
                    .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 1))
            }
            .buttonStyle(DexPressStyle(scale: 0.97))
            .padding(.top, 4)
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(DexFont.mono(18))
                .foregroundStyle(lcd.subtext)
            Spacer(minLength: 8)
            Text(value)
                .font(DexFont.retro(13))
                .foregroundStyle(lcd.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 5).fill(lcd.surface))
    }

    private func studyRow(_ category: ExamCategory, tally: ExamCategoryTally, tint: Color) -> some View {
        HStack {
            Text(catalog.label(for: category).uppercased())
                .font(DexFont.retro(12))
                .tracking(1)
                .foregroundStyle(lcd.text)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            Text("\(tally.right)/\(tally.asked)")
                .font(DexFont.mono(18))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 5).fill(lcd.surface))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(tint.opacity(0.5), lineWidth: 2))
    }

    // MARK: - The question

    private func question(_ prompt: ExamPrompt, run: ExamRun, grow: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16 + 8 * grow) {
            header(prompt, run: run, grow: grow)

            Text(prompt.question.prompt)
                .font(DexFont.retro(15 + 6 * grow))
                .foregroundStyle(lcd.text)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            card(prompt, run: run, grow: grow)
        }
    }

    private func header(_ prompt: ExamPrompt, run: ExamRun, grow: CGFloat) -> some View {
        HStack {
            Text("\(run.tier.ladder.displayName) · \(catalog.label(for: prompt.question.category).uppercased())")
                .font(DexFont.retro(14 + 4 * grow))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 8)
            Text("\(min(run.index + 1, run.length))/\(run.length)")
                .font(DexFont.mono(19 + 5 * grow))
                .foregroundStyle(lcd.subtext)
        }
        .padding(.bottom, 5)
        .overlay(alignment: .bottom) { lcd.accent.opacity(0.4).frame(height: 2) }
    }

    /// **The exhaustive switch — D5's only real gate.** Seven arms, one per
    /// format. Adding an eighth `ExamQuestion.Payload` case fails to compile
    /// here, which is the closest this project can get to a test over a screen
    /// no Linux CI can build.
    @ViewBuilder
    private func card(_ prompt: ExamPrompt, run: ExamRun, grow: CGFloat) -> some View {
        switch prompt.question.payload {
        case .multipleChoice:
            optionList(prompt, grow: grow)
        case .trueFalse:
            trueFalseCard(prompt, grow: grow)
        case .selectAll:
            selectAllCard(prompt, grow: grow)
        case .matching:
            matchingCard(prompt, grow: grow)
        case .ordering(_, let axis):
            orderingCard(prompt, axis: axis, grow: grow)
        case .imageIdentification(let image, _, _):
            VStack(spacing: 14) {
                examImage(image)
                optionList(prompt, grow: grow)
            }
        case .aromaIdentification(let noteKeys, _, _):
            VStack(spacing: 14) {
                aromaGlyphs(noteKeys)
                optionList(prompt, grow: grow)
            }
        }
    }

    // MARK: Single-answer formats

    /// One tap commits, which is how the exam's option rows have always
    /// behaved — and why the multi-tap formats below need an explicit SUBMIT.
    private func optionList(_ prompt: ExamPrompt, grow: CGFloat) -> some View {
        VStack(spacing: 8 + 4 * grow) {
            ForEach(Array(prompt.presentedOptions.enumerated()), id: \.offset) { slot, text in
                Button {
                    guard var current = run, !current.submitted else { return }
                    current.draft(.choice(slot))
                    run = current
                    submit(prompt)
                } label: {
                    optionLabel(text, slot: slot, prompt: prompt, grow: grow)
                }
                .buttonStyle(DexPressStyle(scale: 0.98))
                .disabled(run?.submitted ?? false)
            }
        }
    }

    private func trueFalseCard(_ prompt: ExamPrompt, grow: CGFloat) -> some View {
        // TRUE always above FALSE. There is nothing to shuffle here and
        // shuffling it would only make the candidate re-read the buttons — see
        // `ExamPrompt`.
        VStack(spacing: 8 + 4 * grow) {
            ForEach([true, false], id: \.self) { value in
                let chosen = run?.answer == .truth(value)
                let correct = { if case .trueFalse(let a) = prompt.question.payload { a == value } else { false } }()
                Button {
                    guard var current = run, !current.submitted else { return }
                    current.draft(.truth(value))
                    run = current
                    submit(prompt)
                } label: {
                    HStack(spacing: 12) {
                        Text(value ? "TRUE" : "FALSE")
                            .font(DexFont.retro(15 + 5 * grow))
                            .tracking(2)
                            .foregroundStyle(lcd.text)
                        Spacer(minLength: 8)
                        verdictMark(isAnswer: correct, isChoice: chosen)
                    }
                    .padding(.horizontal, 14 + 5 * grow)
                    .padding(.vertical, 18 + 8 * grow)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(rowTint(isAnswer: correct, isChoice: chosen), lineWidth: 2)
                    )
                }
                .buttonStyle(DexPressStyle(scale: 0.98))
                .disabled(run?.submitted ?? false)
            }
        }
    }

    // MARK: Multi-tap formats

    /// Toggle any number of options, then SUBMIT. Graded all-or-nothing — see
    /// `ExamPrompt.isCorrect` for why there is no partial credit — but the
    /// reveal still marks each option individually, so nothing is hidden.
    private func selectAllCard(_ prompt: ExamPrompt, grow: CGFloat) -> some View {
        VStack(spacing: 8 + 4 * grow) {
            Text("SELECT EVERY CORRECT ANSWER")
                .font(DexFont.mono(17))
                .foregroundStyle(lcd.subtext)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Array(prompt.presentedOptions.enumerated()), id: \.offset) { slot, text in
                let ticked = picks.contains(slot)
                Button {
                    guard var current = run, !current.submitted else { return }
                    Haptics.select()
                    if ticked { picks.remove(slot) } else { picks.insert(slot) }
                    current.draft(.selection(picks))
                    run = current
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: ticked ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ticked ? lcd.accent : lcd.subtext)
                        Text(text)
                            .font(DexFont.retro(13 + 4 * grow))
                            .foregroundStyle(lcd.text)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 14 + 4 * grow)
                    .padding(.vertical, 14 + 6 * grow)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(ticked ? lcd.accent : lcd.surfaceEdge, lineWidth: 2)
                    )
                }
                .buttonStyle(DexPressStyle(scale: 0.98))
                .disabled(run?.submitted ?? false)
            }

            submitButton(enabled: !picks.isEmpty, prompt: prompt)
        }
    }

    /// Tap a left row to arm it, then tap the right chip it belongs to. Tapping
    /// an armed row again disarms it; assigning a right that is already taken
    /// moves it, which is the behaviour that makes a four-pair puzzle solvable
    /// without an undo button.
    private func matchingCard(_ prompt: ExamPrompt, grow: CGFloat) -> some View {
        let lefts = prompt.matchingLeft
        let rights = prompt.matchingRight
        return VStack(alignment: .leading, spacing: 10 + 4 * grow) {
            Text(pendingLeft == nil
                ? "TAP A ROW, THEN ITS MATCH"
                : "NOW TAP ITS MATCH BELOW")
                .font(DexFont.mono(17))
                .foregroundStyle(pendingLeft == nil ? lcd.subtext : lcd.accent)

            VStack(spacing: 6) {
                ForEach(Array(lefts.enumerated()), id: \.offset) { i, left in
                    let armed = pendingLeft == i
                    let assigned = pairing[i].flatMap { rights.indices.contains($0) ? rights[$0] : nil }
                    Button {
                        guard !(run?.submitted ?? false) else { return }
                        Haptics.select()
                        pendingLeft = armed ? nil : i
                    } label: {
                        HStack(spacing: 10) {
                            Text(left)
                                .font(DexFont.retro(12 + 3 * grow))
                                .foregroundStyle(lcd.text)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 6)
                            Text(assigned ?? "—")
                                .font(DexFont.mono(17))
                                .foregroundStyle(assigned == nil ? lcd.disabledText : lcd.accent)
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(armed ? lcd.accent : lcd.surfaceEdge, lineWidth: 2)
                        )
                    }
                    .buttonStyle(DexPressStyle(scale: 0.99))
                    .disabled(run?.submitted ?? false)
                }
            }

            DexFlowRow(spacing: 6) {
                ForEach(Array(rights.enumerated()), id: \.offset) { slot, right in
                    let taken = pairing.values.contains(slot)
                    Button {
                        guard var current = run, !current.submitted, let left = pendingLeft else { return }
                        Haptics.select()
                        // One right per left, both ways: assigning a taken right
                        // takes it off whoever had it.
                        for (k, v) in pairing where v == slot { pairing.removeValue(forKey: k) }
                        pairing[left] = slot
                        pendingLeft = nil
                        current.draft(.pairing(pairing))
                        run = current
                    } label: {
                        Text(right)
                            .font(DexFont.mono(17))
                            .foregroundStyle(taken ? lcd.disabledText : lcd.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(lcd.surface))
                            .overlay(Capsule().strokeBorder(
                                taken ? lcd.surfaceEdge.opacity(0.4) : lcd.accent.opacity(0.6),
                                lineWidth: 1
                            ))
                    }
                    .buttonStyle(DexPressStyle(scale: 0.97))
                    .disabled((run?.submitted ?? false) || pendingLeft == nil)
                }
            }

            submitButton(enabled: pairing.count == lefts.count, prompt: prompt)
        }
    }

    /// Tap the items in order; the position is stamped on the row as you go, and
    /// tapping a stamped row takes it back out (and renumbers everything after
    /// it). No drag, for the reason in the type comment.
    private func orderingCard(_ prompt: ExamPrompt, axis: ExamOrderAxis, grow: CGFloat) -> some View {
        let items = prompt.presentedOptions
        return VStack(alignment: .leading, spacing: 10 + 4 * grow) {
            // The axis caption. Without it the items alone never say which way
            // to sort, and half the candidates would answer the reverse.
            HStack(spacing: 8) {
                Text(axis.from.uppercased())
                    .font(DexFont.mono(16))
                    .foregroundStyle(lcd.accent)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(lcd.subtext)
                Text(axis.to.uppercased())
                    .font(DexFont.mono(16))
                    .foregroundStyle(lcd.accent)
                Spacer(minLength: 4)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Text("TAP IN ORDER")
                .font(DexFont.mono(17))
                .foregroundStyle(lcd.subtext)

            VStack(spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { slot, text in
                    let position = sequence.firstIndex(of: slot)
                    Button {
                        guard var current = run, !current.submitted else { return }
                        Haptics.select()
                        if let position {
                            sequence.remove(at: position)
                        } else {
                            sequence.append(slot)
                        }
                        current.draft(.sequence(sequence))
                        run = current
                    } label: {
                        HStack(spacing: 12) {
                            Text(position.map { "\($0 + 1)" } ?? "·")
                                .font(DexFont.retro(13))
                                .foregroundStyle(position == nil ? lcd.disabledText : (lcd.isLight ? .white : .black))
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(position == nil ? lcd.surfaceEdge.opacity(0.3) : lcd.accent))
                            Text(text)
                                .font(DexFont.retro(12 + 3 * grow))
                                .foregroundStyle(lcd.text)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 6)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(position == nil ? lcd.surfaceEdge : lcd.accent, lineWidth: 2)
                        )
                    }
                    .buttonStyle(DexPressStyle(scale: 0.99))
                    .disabled(run?.submitted ?? false)
                }
            }

            submitButton(enabled: sequence.count == items.count, prompt: prompt)
        }
    }

    private func submitButton(enabled: Bool, prompt: ExamPrompt) -> some View {
        Button {
            guard enabled else { return }
            submit(prompt)
        } label: {
            Text("SUBMIT")
                .font(DexFont.retro(12))
                .tracking(1.5)
                .foregroundStyle(enabled ? Dex.amber900 : lcd.disabledText)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(enabled ? Dex.yellow : lcd.surface))
                .overlay(Capsule().strokeBorder(
                    enabled ? .white.opacity(0.3) : lcd.surfaceEdge,
                    lineWidth: 1
                ))
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
        .disabled(!enabled || (run?.submitted ?? false))
        .padding(.top, 4)
    }

    // MARK: Asset-backed formats

    /// The country outline, through the same `countryShapeIcons` table the
    /// region rows use — so a question can only ever name art the app ships. If
    /// the key ever stops resolving, `DexIcon` draws its visible red
    /// placeholder rather than an empty box, which is a build problem worth
    /// seeing.
    private func examImage(_ image: ExamImageRef) -> some View {
        let iconID: String? = switch image.kind {
        case .countryOutline: db.icons.countryShapeIcons[image.key]
        case .entryIcon: db.icons.byEntry[image.key]
        }
        return Group {
            if let iconID {
                DexIcon(iconID: iconID, size: 128, color: lcd.text, outlined: false)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(lcd.disabledText)
                    .frame(height: 128)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.heroWash))
    }

    /// The three notes as their flavour portraits — the exam's one nod to the
    /// fact that this app is a picture book. `noteKeys` are `flavorArt` keys, so
    /// every one of them is guaranteed art; the names are deliberately **not**
    /// printed beside them, because printing them would answer the question.
    private func aromaGlyphs(_ noteKeys: [String]) -> some View {
        HStack(spacing: 12) {
            ForEach(noteKeys, id: \.self) { key in
                if let stem = db.icons.flavorArt?[key] {
                    DexIcon(iconID: "art:\(stem)", size: 62, outlined: false)
                } else {
                    Image(systemName: "questionmark.square.dashed")
                        .font(.system(size: 34))
                        .foregroundStyle(Dex.red500)
                        .frame(width: 62, height: 62)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.heroWash))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Three aromas to identify")
    }

    // MARK: - Shared row chrome

    private func rowTint(isAnswer: Bool, isChoice: Bool) -> Color {
        guard run?.submitted ?? false else { return isChoice ? lcd.accent : lcd.surfaceEdge }
        if isAnswer { return Dex.green }
        return isChoice ? Dex.red500 : lcd.surfaceEdge.opacity(0.5)
    }

    @ViewBuilder
    private func verdictMark(isAnswer: Bool, isChoice: Bool) -> some View {
        if run?.submitted ?? false, isAnswer {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Dex.green)
        } else if run?.submitted ?? false, isChoice {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Dex.red500)
        }
    }

    private func optionLabel(_ text: String, slot: Int, prompt: ExamPrompt, grow: CGFloat) -> some View {
        let isAnswer = prompt.isCorrectSlot(slot)
        let isChoice = run?.answer == .choice(slot)
        let dimmed = (run?.submitted ?? false) && !isAnswer && !isChoice
        return HStack(spacing: 12) {
            Text(text)
                .font(DexFont.retro(13 + 4 * grow))
                .foregroundStyle(dimmed ? lcd.disabledText : lcd.text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            verdictMark(isAnswer: isAnswer, isChoice: isChoice)
        }
        .padding(.horizontal, 14 + 4 * grow)
        .padding(.vertical, 15 + 7 * grow)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(rowTint(isAnswer: isAnswer, isChoice: isChoice), lineWidth: 2)
        )
    }

    // MARK: - D7, the reveal

    /// **The explanation is the feature, not the footnote.**
    ///
    /// D7 asks for it as a learning moment after answering rather than buried in
    /// a results screen, and this is that moment: the verdict, then the
    /// explanation, then the source where the claim needed one, then the catalog
    /// entries the question was anchored to as the same tiles they are
    /// everywhere else — so a question you got wrong ends one tap from the page
    /// that would have told you.
    ///
    /// Same modal shell the quiz's reveal used: `DexAlert`'s scrim with the card
    /// scrollable, because an explanation plus three entry tiles outgrows a small
    /// phone's LCD. No scrim-tap dismissal — the only way on is NEXT.
    private func reveal(_ prompt: ExamPrompt, run: ExamRun) -> some View {
        let right = run.marks.last ?? false
        let last = run.index == run.length - 1
        let refs = prompt.question.entryRefs.compactMap { db.entry(id: $0) }

        return ZStack {
            Color.black.opacity(lcd.isLight ? 0.35 : 0.72)
                .contentShape(Rectangle())
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(right ? "CORRECT" : "NOT QUITE")
                            .font(DexFont.retro(14))
                            .tracking(2)
                            .foregroundStyle(right ? Dex.green : Dex.yellow)

                        // The answer restated in words for the formats where the
                        // rows behind the scrim cannot show it — matching and
                        // ordering are graded as a whole, so a green border on
                        // nothing in particular would be no help at all.
                        if let stated = correctAnswerText(prompt) {
                            Text(stated)
                                .font(DexFont.mono(18))
                                .foregroundStyle(lcd.text)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(prompt.question.explanation)
                            .font(DexFont.mono(19))
                            .foregroundStyle(lcd.bodyText)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)

                        if let source = prompt.question.source {
                            Text("SOURCE: \(source)")
                                .font(DexFont.mono(16))
                                .foregroundStyle(lcd.subtext)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !refs.isEmpty {
                            Text("IN THE CATALOG")
                                .font(DexFont.retro(11))
                                .tracking(1.5)
                                .foregroundStyle(lcd.accent)
                                .padding(.top, 2)
                            // Capped at three. The reveal is a moment, not a
                            // reading list, and one question anchors as many as
                            // five entries.
                            ForEach(refs.prefix(3), id: \.id) { entry in
                                EntryTileView(
                                    entry: entry,
                                    palette: db.palette,
                                    locked: AccessStore.shared.isLocked(entry, in: db)
                                ) {
                                    onOpen(entry)
                                }
                            }
                        }

                        Button(action: next) {
                            capsuleLabel(last ? "SEE RESULTS" : "NEXT QUESTION", fill: Dex.yellow, ink: Dex.amber900)
                        }
                        .buttonStyle(DexPressStyle(scale: 0.97))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder((right ? Dex.green : Dex.yellow).opacity(0.5), lineWidth: 2)
                    )
                    .padding(16)
                    .frame(minHeight: geo.size.height, alignment: .center)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .transition(.opacity)
    }

    /// The correct answer in words, for the two formats whose rows cannot carry
    /// it. `nil` where the rows already say it in green.
    private func correctAnswerText(_ prompt: ExamPrompt) -> String? {
        switch prompt.question.payload {
        case .multipleChoice, .trueFalse, .selectAll, .aromaIdentification, .imageIdentification:
            return nil
        case .matching(let pairs):
            return pairs.map { "\($0.left) → \($0.right)" }.joined(separator: "\n")
        case .ordering(let items, let axis):
            return "\(axis.from.uppercased()) → \(axis.to.uppercased())\n"
                + items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        }
    }

    // MARK: - Results

    private func results(_ run: ExamRun) -> some View {
        let tint: Color = run.passed ? Dex.green : Dex.red500
        let stats = records.stats

        return VStack(spacing: 18) {
            Image(systemName: run.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.5), radius: 8)

            Text("\(run.correct)/\(run.length)")
                .font(DexFont.retro(24))
                .foregroundStyle(lcd.text)

            Text(run.passed ? "PASS" : "FAIL")
                .font(DexFont.retro(16))
                .tracking(3)
                .foregroundStyle(tint)

            if let newlyUnlocked {
                Text("\(newlyUnlocked.displayName) UNLOCKED")
                    .font(DexFont.retro(14))
                    .tracking(2)
                    .foregroundStyle(Dex.yellow)
            }

            if run.correct == run.length {
                Text("FULL MARKS")
                    .font(DexFont.retro(13))
                    .tracking(2)
                    .foregroundStyle(Dex.yellow)
            } else if stats.passStreak > 1 {
                Text("\(stats.passStreak) PAPERS PASSED IN A ROW")
                    .font(DexFont.mono(18))
                    .foregroundStyle(lcd.bodyText)
            }

            Text(run.passed
                ? "SANTÉ. THE NEXT PAPER IS WAITING."
                : "\(run.passMark)/\(run.length) PASSES. SWIRL AND RETRY.")
                .font(DexFont.mono(18))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button(action: retry) {
                    capsuleLabel("RETRY", fill: Dex.yellow, ink: Dex.amber900)
                }
                .buttonStyle(DexPressStyle(scale: 0.97))

                Button(action: exit) {
                    Text("BACK TO EXAMS")
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
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(0.5), lineWidth: 2))
        .transition(.opacity)
    }

    // MARK: - Chrome

    /// The bank failed to load, or cannot furnish this paper. Said plainly
    /// rather than shown as an empty question — `ExamCatalog.unavailable` is a
    /// distress signal, and a screen that renders it as a blank paper is worse
    /// than one that says the data is missing.
    private func failure(_ why: ExamAssemblyFailure) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Dex.yellow)
            Text(why.message)
                .font(DexFont.mono(18))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: { Haptics.select(); onExit() }) {
                capsuleLabel("EXIT", fill: lcd.surface, ink: lcd.subtext)
            }
            .buttonStyle(DexPressStyle(scale: 0.97))
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.heroWash))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 2))
    }

    private func heading(_ text: String, grow: CGFloat) -> some View {
        HStack {
            Text(text)
                .font(DexFont.retro(14 + 4 * grow))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)
            Spacer(minLength: 8)
        }
        .padding(.bottom, 5)
        .overlay(alignment: .bottom) { lcd.accent.opacity(0.4).frame(height: 2) }
    }

    private func subheading(_ text: String) -> some View {
        Text(text)
            .font(DexFont.retro(11))
            .tracking(1.5)
            .foregroundStyle(lcd.accent)
            .padding(.top, 4)
    }

    private func capsuleLabel(_ text: String, fill: Color, ink: Color) -> some View {
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

/// A wrapping row of chips.
///
/// The matching question's right column is four free-text answers of wildly
/// different lengths — "Chardonnay" beside "Grapes dried after picking" — and
/// neither an `HStack` (which squeezes them all onto one line) nor a `VStack`
/// (which wastes the LCD's width on the short ones) fits. SwiftUI has no
/// built-in flow layout under the iOS 17 floor, so this is one, in the twenty
/// lines the `Layout` protocol takes.
struct DexFlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
#endif
