#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// A WSET Level 1-style question: one fact, four candidates, one right.
///
/// The reveal is the point. Every option is a real grape, so answering does not
/// end at a tick or a cross — the correct entry appears as the tile it appears
/// as everywhere else in the app, with its own page one tap away. A question you
/// got wrong is the best possible moment to be offered the reading, and a
/// question you got right is the moment you are most likely to take it.
///
/// Questions come from `TastingQuiz`, which builds them out of the shipped data
/// rather than from an authored bank — see the reasoning there.
public struct TastingQuizScreen: View {
    let onOpen: (WineEntry) -> Void

    /// Which question we are on. Advances per NEXT, and survives the trip into
    /// an entry so LEARN MORE does not cost you the question you just answered.
    @State private var seed: Int?
    @State private var chosenID: String?
    /// Right answers and questions asked this session, shown as a running score.
    @State private var correct = 0
    @State private var asked = 0
    @State private var screens = ScreenStateStore.shared

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    private let db = WineDatabase.shared

    public init(onOpen: @escaping (WineEntry) -> Void) {
        self.onOpen = onOpen
    }

    private var question: QuizQuestion? {
        guard let seed else { return nil }
        return TastingQuiz.question(seed: seed, in: db)
    }

    private var answered: Bool { chosenID != nil }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            if let question {
                content(question)
            } else {
                Text("NO QUESTIONS AVAILABLE")
                    .font(DexFont.retro(12))
                    .foregroundStyle(Dex.stone400)
            }
        }
        .onAppear(perform: restore)
        .onChange(of: chosenID) { _, _ in persist() }
        .onChange(of: seed) { _, _ in persist() }
    }

    // MARK: State

    private var key: String { ScreenStateStore.wsetQuiz }

    private func restore() {
        if let held = screens.number("seed", for: key) {
            seed = Int(held)
            chosenID = screens.value("chosen", for: key)
            correct = Int(screens.number("correct", for: key) ?? 0)
            asked = Int(screens.number("asked", for: key) ?? 0)
        } else if seed == nil {
            // Seeded off the reveal cursor so two tools opened back to back do
            // not both start from zero and ask about the same grape.
            seed = RevealCursor.shared.value &+ DailyPick.dayIndex()
        }
    }

    private func persist() {
        screens.setNumber(Double(seed ?? 0), "seed", for: key)
        screens.setValue(chosenID, "chosen", for: key)
        screens.setNumber(Double(correct), "correct", for: key)
        screens.setNumber(Double(asked), "asked", for: key)
    }

    private func choose(_ id: String, in question: QuizQuestion) {
        guard chosenID == nil else { return }
        asked += 1
        if question.isCorrect(id) {
            correct += 1
            Haptics.tap()
        } else {
            Haptics.select()
        }
        withAnimation(.easeOut(duration: 0.25)) { chosenID = id }
    }

    private func next() {
        Haptics.tap()
        withAnimation(.easeOut(duration: 0.2)) {
            chosenID = nil
            seed = (seed ?? 0) &+ 1
        }
    }

    // MARK: Layout

    private func content(_ question: QuizQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(question)
                prompt(question)
                options(question)

                if answered {
                    reveal(question)
                }
            }
            .padding(14)
        }
    }

    private func header(_ question: QuizQuestion) -> some View {
        HStack {
            Text(question.kind.topic)
                .font(DexFont.retro(11))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)
            Spacer(minLength: 8)
            if asked > 0 {
                Text("\(correct)/\(asked)")
                    .font(DexFont.mono(19))
                    .foregroundStyle(lcd.subtext)
            }
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
    }

    /// The verdict, the entry itself, and the way into it.
    @ViewBuilder
    private func reveal(_ question: QuizQuestion) -> some View {
        let gotIt = chosenID.map(question.isCorrect) ?? false
        let answer = db.entry(id: question.answerID)

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
                label("NEXT QUESTION", fill: Dex.yellow, ink: Dex.amber900)
            }
            .buttonStyle(DexPressStyle(scale: 0.97))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.heroWash))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder((gotIt ? Dex.green : Dex.yellow).opacity(0.5), lineWidth: 2)
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
