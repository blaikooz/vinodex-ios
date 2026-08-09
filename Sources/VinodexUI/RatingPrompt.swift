#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The tasting journal's entry form: five stars and one line, raised at the
/// moment TRIED turns on — when the glass is still in memory.
///
/// An in-LCD overlay following `DexAlert`'s conventions (scrim, 320pt card,
/// modal accessibility), but its own view: `DexAlert` is a title and a message
/// with buttons, and wedging a star row and a text field into it would turn a
/// deliberately dumb component into a form engine.
///
/// SKIP is a first-class exit. A rating you were forced to give is noise in
/// the journal, and the entry stays tried either way.
public struct RatingPrompt: View {
    let entryName: String
    let initial: TriedRating?
    let onSave: (Int, String) -> Void
    let onSkip: () -> Void

    @State private var stars: Int
    @State private var note: String

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(
        entryName: String,
        initial: TriedRating?,
        onSave: @escaping (Int, String) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.entryName = entryName
        self.initial = initial
        self.onSave = onSave
        self.onSkip = onSkip
        _stars = State(initialValue: initial?.rating ?? 0)
        _note = State(initialValue: initial?.note ?? "")
    }

    public var body: some View {
        ZStack {
            // Scrim doubles as SKIP — dismissing an optional form must never
            // cost the tried mark it rode in on.
            Color.black.opacity(lcd.isLight ? 0.35 : 0.72)
                .contentShape(Rectangle())
                .onTapGesture { onSkip() }

            VStack(spacing: 14) {
                Text("HOW WAS IT?")
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(lcd.accent)

                Text(entryName.uppercased())
                    .font(DexFont.mono(20))
                    .foregroundStyle(lcd.subtext)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            Haptics.select()
                            stars = star
                        } label: {
                            Image(systemName: star <= stars ? "star.fill" : "star")
                                .font(.system(size: 24))
                                .foregroundStyle(star <= stars ? Dex.yellow : lcd.disabledText)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(DexPressStyle(scale: 0.9))
                    }
                }

                DexSearchField(text: $note, placeholder: "ONE-LINE NOTE…", fontSize: 20)
                    .frame(height: 40)
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 6).fill(lcd.well))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                    )

                HStack(spacing: 10) {
                    button(
                        "SKIP",
                        fill: lcd.isLight ? lcd.page : Dex.stone800,
                        border: lcd.isLight ? lcd.surfaceEdge : Dex.stone600,
                        text: lcd.isLight ? lcd.subtext : Dex.stone200,
                        action: onSkip
                    )
                    button(
                        "SAVE",
                        fill: stars > 0 ? lcd.accent : lcd.surface,
                        border: stars > 0 ? lcd.accent : lcd.surfaceEdge,
                        text: stars > 0 ? lcd.onAccent : lcd.disabledText
                    ) {
                        guard stars > 0 else { return }
                        onSave(stars, note)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 8).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(lcd.accent.opacity(0.6), lineWidth: 2)
            )
            .padding(20)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
    }

    private func button(
        _ label: String,
        fill: Color,
        border: Color,
        text: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.screenTap()
            action()
        } label: {
            Text(label)
                .font(DexFont.retro(10))
                .tracking(1)
                .foregroundStyle(text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 6).fill(fill))
                .overlay(
                    RoundedRectangle(cornerRadius: 6).strokeBorder(border, lineWidth: 2)
                )
        }
        .buttonStyle(DexPressStyle(scale: 0.96))
    }
}
#endif
