#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// **The first thing after the BIOS** (0.8.9d, F1).
///
/// Spec §F1 opens with "Professor Vino intro", and 0.8.9c shipped both halves of
/// it as gated data — `firstLaunch` asks the question, `firstLaunchNamed`
/// answers it — with the note that Phase 3 would cost "a text field plus two
/// `fireOnce` calls". This is the text field.
///
/// ## Two pages, and the second one is not optional
///
/// SKIP and DONE both land on page two. That is `firstLaunchNamed`'s own
/// instruction — its 0.8.9c note says it fires "on submit **or** on skip, with
/// the fallback substituted", because that line carries the division of labour
/// every later line assumes ("You taste the world; I catalogue it"), and
/// suppressing it on skip would mean the player who skips never learns what he
/// is for. Skipping declines to be *named*, not to be introduced.
///
/// ## Somebody who already has a name never sees page one
///
/// `VinoName.storageKey` is `userDisplayName`, which the USER screen has offered
/// for several releases — 0.8.9c chose it over minting a second key precisely so
/// that "a player who named themselves in 0.7.x is greeted by name on first
/// launch after this batch rather than being asked again". `startPage` is where
/// that promise is kept: a resolvable stored name starts this card on the
/// greeting.
///
/// ## The keys are burnt at the end, not at the start
///
/// `FirstTimeTriggerStore.fireOnce` marks on the way out, which is right for a
/// queued remark and wrong for a two-page form: an app killed on page one would
/// have spent both lines on a question nobody answered. So this card reads its
/// copy through `VinoDialogue.line(for:)` and the host fires both triggers when
/// the card is *finished*. Phase 2's "a skipped intro is resumable by
/// construction" is thereby true of a quit as well as of a skip.
public struct VinoIntroCard: View {
    /// Called once the player is through both pages. The host writes the
    /// triggers and starts the walkthrough.
    let onFinish: () -> Void

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    @AppStorage(VinoName.storageKey) private var displayName = ""

    /// Live text, committed to `displayName` only on DONE — so backing out of
    /// the keyboard does not half-write a name.
    @State private var typed = ""
    @State private var greeting = false

    private var ask: VinoLine? { VinoDialogue.line(for: .firstLaunch) }
    private var named: VinoLine? { VinoDialogue.line(for: .firstLaunchNamed) }

    /// **64 to 84** (0.8.91, G1). The card is the first thing a new device shows
    /// after the BIOS and it is the one screen that is *only* him — no list
    /// behind it, no control it is annotating — so it is where the portrait can
    /// afford to be the picture rather than the icon. The panel widens with him
    /// (320 to 340) so the growth is the portrait's and not the card's margins'.
    private var portraitSize: CGFloat { 84 * UIScale.current.factor }

    public var body: some View {
        ZStack {
            // A scrim, unlike `VinoBubble` and like `DexAlert`: this one *is* a
            // modal. It asks a question, it has buttons, and there is nothing
            // behind it worth reading — the main menu it covers is the thing the
            // walkthrough is about to point at.
            Color.black.opacity(lcd.isLight ? 0.4 : 0.76)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                DexChromeGlyph(
                    (greeting ? named : ask)?.expression.artStem ?? VinoExpression.neutral.artStem,
                    symbol: "cpu",
                    size: portraitSize,
                    weight: .semibold,
                    tint: lcd.accent
                )

                if let chirp = (greeting ? named : ask)?.chirp {
                    Text(chirp.text)
                        .font(DexFont.retro(10))
                        .tracking(1)
                        .foregroundStyle(lcd.accent)
                }

                Text(line)
                    .font(DexFont.mono(20))
                    .foregroundStyle(lcd.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if greeting {
                    button("LET'S GO", accent: true) {
                        Haptics.screenTap()
                        onFinish()
                    }
                } else {
                    // The USER screen's own field, with its own placeholder, so
                    // the name is typed the same way in both places.
                    DexSearchField(
                        text: $typed,
                        placeholder: "YOUR NAME",
                        fontSize: 24,
                        focusesOnAppear: true
                    )
                    .frame(height: 34)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(lcd.panelGround))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                    )

                    HStack(spacing: 10) {
                        button("SKIP", accent: false) {
                            Haptics.select()
                            advance(saving: false)
                        }
                        button("DONE", accent: true) {
                            Haptics.screenTap()
                            advance(saving: true)
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 8).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 8).strokeBorder(lcd.accent.opacity(0.8), lineWidth: 2)
            )
            .padding(.horizontal, 16)
        }
        .onAppear {
            // See the type note: an existing name skips the ask entirely.
            if VinoName.clean(displayName) != nil { greeting = true }
        }
        .animation(DexMotion.overlay, value: greeting)
    }

    /// The sentence for the page we are on, with the name already resolved —
    /// the greeting reads `explorer` when the ask was skipped, which is what
    /// `VinoName.fallback` is for.
    private var line: String {
        let entry = greeting ? named : ask
        return entry?.rendered(name: displayName) ?? ""
    }

    /// DONE commits the typed name through `VinoName.clean`, which trims and
    /// caps it — the same reduction every other reader applies, done once here
    /// so nothing downstream has to cope with 40 characters of whitespace.
    private func advance(saving: Bool) {
        if saving, let cleaned = VinoName.clean(typed) {
            displayName = cleaned
        }
        greeting = true
    }

    private func button(_ text: String, accent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(DexFont.retro(11))
                .tracking(1.5)
                .foregroundStyle(accent ? (lcd.isLight ? .white : .black) : lcd.subtext)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(accent ? lcd.accent : lcd.surface))
                .overlay(
                    Capsule().strokeBorder(accent ? lcd.accent : lcd.surfaceEdge, lineWidth: 2)
                )
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
    }
}
#endif
