#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The unlock-code console (0.7.3, A4).
///
/// Type a code, get told plainly whether it worked. Valid codes grant through
/// `AccessStore` — the same store a purchase writes to (F1) — so an unlock here
/// and an unlock in the shopfront are indistinguishable to every gate in the
/// app, which is the point rather than a convenience.
///
/// **What it does not do is list the codes.** A console that shows you the
/// answers is a settings panel with extra steps. What it does show is how many
/// have been found, so there is something to complete and a reason to come back.
public struct CheatConsoleScreen: View {
    /// The outcome of the last submission. Nil before the first one.
    private enum Verdict: Equatable {
        case accepted(String)
        /// Already owned. Distinct from `accepted` because "OK" for something
        /// you unlocked last week reads as though nothing happened.
        case already(String)
        case rejected
    }

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    @State private var access = AccessStore.shared
    @State private var typed = ""
    @State private var verdict: Verdict?

    public init() {}

    /// How many of the table's codes have already been entered.
    ///
    /// Counted through the entitlement store rather than kept as its own tally —
    /// there is one source of truth for what is owned, and a second counter
    /// beside it would be the parallel store F1 forbids, in miniature.
    private var found: Int {
        CheatCodes.all.filter { access.granted.contains($0.grants) }.count
    }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    prompt
                    if let verdict {
                        readout(verdict)
                    }
                    progress
                    Text(
                        "Codes are found, not listed. They unlock cosmetics, "
                            + "hidden features and the odd thing nobody asked for."
                    )
                    .font(DexFont.mono(16))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
            }
        }
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ENTER CODE")
                .font(DexFont.retro(14))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)
                .padding(.bottom, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { lcd.accent.opacity(0.45).frame(height: 2) }

            HStack(spacing: 10) {
                Text(">")
                    .font(DexFont.mono(24))
                    .foregroundStyle(lcd.accent)
                // The app's own field: it already uppercases, and already has
                // autocorrect and spellcheck off, which is exactly what a
                // password-shaped string needs and what a stock `TextField`
                // would fight.
                DexSearchField(
                    text: $typed,
                    placeholder: "..........",
                    fontSize: 24,
                    focusesOnAppear: true
                )
                .frame(height: 34)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
            )

            Button {
                submit()
            } label: {
                Text("SUBMIT")
                    .font(DexFont.retro(11))
                    .tracking(1)
                    .foregroundStyle(typed.isEmpty ? lcd.subtext : lcd.onAccent)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(typed.isEmpty ? lcd.surface : lcd.accent)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                typed.isEmpty ? lcd.surfaceEdge : lcd.accent,
                                lineWidth: 2
                            )
                    )
            }
            .buttonStyle(DexPressStyle(scale: 0.98))
            .disabled(typed.isEmpty)
        }
    }

    /// Clear feedback, which A4 asks for by name — and the reason there are
    /// three verdicts rather than two.
    private func readout(_ verdict: Verdict) -> some View {
        let (symbol, tint, title, detail): (String, Color, String, String) = {
            switch verdict {
            case .accepted(let reveal):
                return ("checkmark.seal.fill", lcd.accent, "ACCEPTED", reveal)
            case .already(let reveal):
                return ("checkmark.circle", lcd.subtext, "ALREADY UNLOCKED", reveal)
            case .rejected:
                return ("xmark.octagon.fill", Dex.red500, "INVALID CODE", "Nothing unlocked.")
            }
        }()

        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(tint)
                Text(detail)
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(0.6), lineWidth: 2)
        )
        .transition(.opacity)
        // Announced, not just drawn: this is the one screen whose entire output
        // is a single line of feedback, and a VoiceOver user submitting a code
        // would otherwise get silence either way.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
    }

    private var progress: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(lcd.subtext)
            Text("\(found) OF \(CheatCodes.all.count) FOUND")
                .font(DexFont.retro(10))
                .tracking(1)
                .foregroundStyle(lcd.subtext)
            Spacer(minLength: 0)
        }
    }

    private func submit() {
        guard let code = CheatCodes.match(typed) else {
            Haptics.select()
            withAnimation(DexMotion.overlay) { verdict = .rejected }
            typed = ""
            return
        }

        // `granted`, not `isUnlocked`: with the paywall off the latter answers
        // true for everything, which would report every first-time code as
        // already unlocked.
        let alreadyOwned = access.granted.contains(code.grants)
        access.grant(code.grants)
        Haptics.select()
        withAnimation(DexMotion.overlay) {
            verdict = alreadyOwned ? .already(code.reveal) : .accepted(code.reveal)
        }
        typed = ""
    }
}
#endif
