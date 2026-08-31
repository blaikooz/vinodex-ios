#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// Professor Vino's own page (0.8.93, item 9).
///
/// **What this is now, and what it is for later.** The item replaces WHAT'S
/// THAT…? on the tools shelf with a screen about the professor — for the
/// moment a working diagram of him: who he is, his six faces, the switch that
/// silences him (moved here from SETTINGS > DEVICE), and the dev-facing
/// ledger of which first-time tips have fired. The stated destination is a
/// place to *interact* with him directly; when that arrives it lands here,
/// and the diagram sections become the appendix rather than the page.
///
/// **The silence switch moved, not copied.** It lived in SETTINGS > DEVICE
/// from 0.8.9d; a page named after him is plainly where "how much does he
/// volunteer" belongs, and two switches over one stored key is the
/// two-writers fault the store's own notes warn about.
///
/// **The ledger is deliberately frank.** It prints trigger identifiers and
/// fired-states — engineering vocabulary on an LCD that usually speaks copy —
/// because its audience today is the person testing him. FRESH-profile loads
/// (0.8.92) plus this readout are how the first-run experience gets exercised
/// without wiping a real device.
public struct ProfVinoScreen: View {
    @State private var triggers = FirstTimeTriggerStore.shared
    @State private var confirmingReset = false
    @AppStorage(VinoName.storageKey) private var displayName = ""
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init() {}

    private var vinoOn: Bool { !triggers.isSilenced }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    silenceRow
                    facesSection
                    dutiesSection
                    // The dev-facing ledger and the "later firmware" note both
                    // came off the page in 0.9.4 with the rest of the
                    // developer surface: trigger identifiers are engineering
                    // vocabulary the first version build has no reader for,
                    // and a roadmap line is a COMING SOON in prose. The
                    // sections stand below, dormant, for a dev build.
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if confirmingReset {
                DexAlert(
                    title: "RESET HIS TIPS?",
                    message: "Every first-time tip is marked unsaid, so Professor Vino introduces things again as you reach them. Nothing else is touched.",
                    confirmLabel: "RESET",
                    onConfirm: {
                        confirmingReset = false
                        triggers.reset()
                    },
                    onCancel: { confirmingReset = false }
                )
            }
        }
        .animation(DexMotion.overlay, value: confirmingReset)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 10) {
            // The tile's face at full size — K2 rule 1, the page wears the
            // picture on the control that opened it.
            DexChromeGlyph(
                VinoExpression.neutral.artStem,
                symbol: "graduationcap.fill",
                size: 96,
                tint: lcd.accent
            )
            Text("PROF. VINO")
                .font(DexFont.retro(20))
                .tracking(1)
                .foregroundStyle(lcd.text)
            Text(displayName.isEmpty
                ? "The resident wine professor. He introduces himself on a fresh device, asks your name, and says one useful thing the first time you try something new."
                : "The resident wine professor. He calls you \(displayName), and says one useful thing the first time you try something new.")
                .font(DexFont.mono(18))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: The switch (from SETTINGS > DEVICE, 0.8.9d -> here, 0.8.93)

    private var silenceRow: some View {
        HStack(spacing: 12) {
            DexChromeGlyph(
                "bubble.left.fill",
                symbol: "bubble.left.fill",
                size: DexMetrics.rowGlyph,
                weight: .bold,
                tint: vinoOn ? lcd.accent : lcd.subtext
            )
            .frame(width: DexMetrics.rowGlyphGutter)
            VStack(alignment: .leading, spacing: 4) {
                Text("PROFESSOR VINO")
                    .font(DexFont.retro(13))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                Text(vinoOn
                    ? "One tip, once, the first time you try something new."
                    : "Quiet. He still guides the tutorial when you ask for it.")
                    .font(DexFont.mono(17))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            DexToggle(isOn: vinoOn, tint: Dex.green) {
                Haptics.select()
                triggers.setSilenced(vinoOn)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
        )
    }

    // MARK: Faces

    private var facesSection: some View {
        section("HIS FACES", symbol: "face.smiling") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(VinoExpression.allCases, id: \.self) { expression in
                    VStack(spacing: 6) {
                        DexChromeGlyph(
                            expression.artStem,
                            symbol: "person.crop.circle",
                            size: 52,
                            tint: lcd.subtext
                        )
                        Text(expression.rawValue.uppercased())
                            .font(DexFont.retro(10))
                            .tracking(0.5)
                            .foregroundStyle(lcd.subtext)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: What he does

    private var dutiesSection: some View {
        section("WHAT HE DOES", symbol: "list.bullet") {
            VStack(alignment: .leading, spacing: 8) {
                bullet("Greets a fresh device, and asks what to call you.")
                bullet("Narrates the TUTORIAL, one lit control at a time.")
                bullet("Says one useful thing the first time you open each kind of page or tool — the ledger below is his memory of what he has already said.")
                bullet("Offers a first guided tasting at the end of the tour.")
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{25B8}")
                .font(DexFont.mono(17))
                .foregroundStyle(lcd.accent)
            Text(text)
                .font(DexFont.mono(17))
                .foregroundStyle(lcd.bodyText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: The ledger (dev-facing, and says so)

    private var ledgerSection: some View {
        section("HIS LEDGER", symbol: "checklist") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Which first-time tips have been spent. A diagnostic readout for now — reset it to hear him again, or load the FRESH profile for the whole first run.")
                    .font(DexFont.mono(16))
                    .foregroundStyle(lcd.subtext)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                ForEach(FirstTimeTrigger.allCases, id: \.self) { trigger in
                    let fired = triggers.hasFired(trigger)
                    HStack(spacing: 8) {
                        Image(systemName: fired ? "checkmark.circle.fill" : "circle.dashed")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(fired ? Dex.green : lcd.subtext)
                        Text(trigger.rawValue)
                            .font(DexFont.mono(16))
                            .foregroundStyle(fired ? lcd.text : lcd.subtext)
                        Spacer(minLength: 0)
                        Text(fired ? "SAID" : "WAITING")
                            .font(DexFont.retro(10))
                            .tracking(1)
                            .foregroundStyle(fired ? Dex.green : lcd.subtext)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 5).fill(lcd.surface))
                }

                Button {
                    Haptics.select()
                    confirmingReset = true
                } label: {
                    Text("RESET HIS TIPS")
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .foregroundStyle(lcd.accent)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(lcd.accent.opacity(0.6), lineWidth: 2)
                        )
                }
                .buttonStyle(DexPressStyle(scale: 0.98))
                .padding(.top, 6)
            }
        }
    }

    private var roadmapNote: some View {
        Text("Talking to the professor directly lands on this page in a later firmware.")
            .font(DexFont.mono(16))
            .foregroundStyle(lcd.subtext)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The detail screens' section header — symbol and label over a rule.
    private func section<C: View>(
        _ title: String,
        symbol: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(lcd.accent)
                Text(title)
                    .font(DexFont.retro(10))
                    .tracking(1.5)
                    .foregroundStyle(lcd.accent)
                Spacer()
            }
            .padding(.bottom, 5)
            .overlay(alignment: .bottom) {
                lcd.accent.opacity(0.5).frame(height: 2)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
