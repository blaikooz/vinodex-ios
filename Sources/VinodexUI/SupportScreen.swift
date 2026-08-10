#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import MessageUI
import VinodexCore

/// **The contact screen** (0.8.91, F1).
///
/// One short paragraph and one button. §F1 asks for a "brief contact screen",
/// and brief is the requirement rather than the starting point: a support page
/// is where an app is tempted to put an FAQ, a version readout, a diagnostics
/// dump and a link to a website that does not exist. The version already has a
/// page (FIRMWARE), the diagnostics already have one (SETTINGS > DEV), and this
/// build has no website. What is left is the address.
///
/// ## Two ways to open a composer, and the second one is not a fallback
///
/// `MFMailComposeViewController` is the in-app composer and is the right answer
/// when the system Mail app has an account: the message is written without
/// leaving Vinodex, and the sheet reports whether it was sent. It is also
/// unavailable on a surprising number of real devices — `canSendMail()` returns
/// false whenever Mail has no configured account, which is now common, and it
/// knows nothing about Gmail or Outlook being installed.
///
/// So `mailto:` is the other arm rather than a degraded one: it hands the
/// address to whatever the user actually reads mail in. Both open a composer
/// pre-addressed and pre-subjected, which is what the item asks for; only the
/// first one is in-app.
///
/// The subject carries the installed firmware, because the first question anyone
/// answering this mail will ask is which build it came from, and
/// `AppVersion.current` is the one place that knows.
public struct SupportScreen: View {
    public init() {}

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    @State private var composing = false
    @State private var failedToOpen = false

    public var body: some View {
        ZStack {
            DexScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heading

                    Text(SupportContact.blurb)
                        .font(DexFont.mono(19))
                        .foregroundStyle(lcd.bodyText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(lcd.surfaceEdge, lineWidth: 2)
                        )

                    mailButton

                    Text(SupportContact.address)
                        .font(DexFont.mono(17))
                        .foregroundStyle(lcd.subtext)
                        .frame(maxWidth: .infinity, alignment: .center)
                        // Selectable so the address is reachable on a device
                        // with no mail client at all — the one case both arms
                        // above have nothing to offer.
                        .textSelection(.enabled)
                }
                .padding(16)
            }

            if failedToOpen {
                DexAlert(
                    title: "NO MAIL APP",
                    message: "Nothing on this device could open a message. "
                        + "The address is \(SupportContact.address).",
                    confirmLabel: "OK",
                    cancelLabel: nil,
                    onConfirm: { failedToOpen = false },
                    onCancel: { failedToOpen = false }
                )
            }
        }
        .sheet(isPresented: $composing) {
            MailComposer(
                to: SupportContact.address,
                subject: SupportContact.subject(version: AppVersion.display)
            )
        }
        .animation(DexMotion.overlay, value: failedToOpen)
    }

    private var heading: some View {
        HStack(spacing: 12) {
            // §F1's `sealicon` — `UIGlyph.seal`, which has been in the bundle
            // since the 0.8.9a glyph drop with no call site. This is the screen
            // its `unwired` entry was waiting for.
            DexChromeGlyph(
                UIGlyph.seal.artStem,
                symbol: "checkmark.seal.fill",
                size: 40,
                weight: .bold,
                tint: lcd.accent
            )

            Text("GET IN TOUCH")
                .font(DexFont.retro(14))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)

            Spacer(minLength: 0)
        }
    }

    private var mailButton: some View {
        Button {
            Haptics.screenTap()
            send()
        } label: {
            HStack(spacing: 12) {
                // §F1's `mailicon` — `UIGlyph.mail`, unwired until now for the
                // same reason the seal was.
                DexChromeGlyph(
                    UIGlyph.mail.artStem,
                    symbol: "envelope.fill",
                    size: 26,
                    weight: .bold,
                    tint: lcd.isLight ? .white : .black
                )

                Text("SEND A MESSAGE")
                    .font(DexFont.retro(12))
                    .tracking(1.5)
                    // Never white on mint — see the note in `ChipFilterScreen`.
                    .foregroundStyle(lcd.isLight ? .white : .black)
            }
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(lcd.accent))
            .overlay(Capsule().strokeBorder(lcd.accent, lineWidth: 2))
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
        .accessibilityLabel("Send a message to \(SupportContact.address)")
    }

    private func send() {
        if MFMailComposeViewController.canSendMail() {
            composing = true
            return
        }
        // `canOpenURL` rather than the completion handler, matching the one
        // other external open in this app (`SettingsPanel`'s route to iOS
        // Settings). `mailto:` is a system scheme, so it needs no
        // `LSApplicationQueriesSchemes` entry, and asking first keeps the whole
        // decision on one actor instead of writing state from a callback.
        guard let url = SupportContact.mailtoURL(version: AppVersion.display),
              UIApplication.shared.canOpenURL(url)
        else {
            failedToOpen = true
            return
        }
        UIApplication.shared.open(url)
    }
}

/// The in-app composer, wrapped.
///
/// Dismissal is the coordinator's job and not the caller's: `MFMailCompose`
/// does not dismiss itself, so a sheet that only flipped its binding on the
/// delegate callback would leave a composer nobody could close if the callback
/// were ever missed. `dismiss(animated:)` on the controller is the one that
/// always works, and the binding follows through SwiftUI's own sheet lifecycle.
private struct MailComposer: UIViewControllerRepresentable {
    let to: String
    let subject: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([to])
        controller.setSubject(subject)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    /// `@preconcurrency` on the conformance, and it is the whole of the
    /// concurrency story here.
    ///
    /// `dismiss(animated:)` is `@MainActor`; `MFMailComposeViewControllerDelegate`'s
    /// callback is not annotated at all, because MessageUI predates the
    /// annotations. So a plain witness cannot call `dismiss` (a main-actor call
    /// from a nonisolated context) and a `@MainActor` witness cannot satisfy a
    /// nonisolated requirement -- Swift 6 rejects both, which is what the first
    /// build here found.
    ///
    /// `@preconcurrency` is the sanctioned answer: it lets the isolated witness
    /// satisfy the un-annotated requirement and inserts a runtime check that the
    /// call really did arrive on the main actor. UIKit always delivers it there,
    /// so the check is a statement of a fact the compiler cannot see rather than
    /// a suppression of one it can.
    final class Coordinator: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
        @MainActor
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
        }
    }
}
#endif
