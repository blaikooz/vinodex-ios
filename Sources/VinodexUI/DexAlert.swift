#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// An in-LCD confirmation, styled like the rest of the screen.
///
/// A system `confirmationDialog` slides up from the bottom of the *device* and
/// looks like iOS, which breaks the handheld metaphor the chassis is built on —
/// the same reason the settings panel is an overlay rather than a `.sheet`.
/// This renders inside whatever view presents it, so it stays within the LCD.
public struct DexAlert: View {
    let title: String
    let message: String
    let confirmLabel: String
    /// Nil for an acknowledgement — a one-button notice does not need a
    /// "cancel" for something that is not a choice.
    var cancelLabel: String? = "CANCEL"
    let onConfirm: () -> Void
    let onCancel: () -> Void

    public init(
        title: String,
        message: String,
        confirmLabel: String,
        cancelLabel: String? = "CANCEL",
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmLabel = confirmLabel
        self.cancelLabel = cancelLabel
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            // Scrim doubles as a cancel target.
            Color.black.opacity(0.72)
                .contentShape(Rectangle())
                .onTapGesture { onCancel() }

            VStack(spacing: 14) {
                Text(title)
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(Dex.green)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(DexFont.mono(18))
                    .foregroundStyle(Dex.stone400)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if let cancelLabel {
                        button(
                            cancelLabel,
                            fill: Dex.stone800,
                            border: Dex.stone600,
                            text: Dex.stone200,
                            action: onCancel
                        )
                    }
                    button(
                        confirmLabel,
                        fill: cancelLabel == nil ? Dex.green : Dex.red600,
                        border: cancelLabel == nil ? Dex.green700 : Dex.red800,
                        text: cancelLabel == nil ? .black : .white,
                        action: onConfirm
                    )
                }
            }
            .padding(18)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 8).fill(Dex.stone900))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Dex.green.opacity(0.6), lineWidth: 2)
            )
            .padding(20)
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
            Haptics.tap()
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

/// The Vinodex Pro prompt, raised by a locked entry or a gated cosmetic.
///
/// One view for both so the paywall says the same thing wherever it appears —
/// and, more to the point, so UNLOCK *does* the same thing. It used to dismiss
/// and nothing else, with a comment explaining that there was no storefront yet;
/// that was defensible while the only entitlement was an all-or-nothing
/// developer switch, but it meant the button labelled UNLOCK was the one control
/// in the app that did not do what it said. It now grants the bundle it names.
///
/// There is still no payment step. When there is one, it goes between the tap
/// and `onUnlock` — the rest of this does not move.
public struct UpgradePrompt: View {
    let entitlement: Entitlement
    let onUnlock: () -> Void
    let onCancel: () -> Void

    public init(
        entitlement: Entitlement,
        onUnlock: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.entitlement = entitlement
        self.onUnlock = onUnlock
        self.onCancel = onCancel
    }

    public var body: some View {
        DexAlert(
            title: entitlement.title,
            message: entitlement.blurb,
            confirmLabel: "UNLOCK",
            cancelLabel: "NOT NOW",
            onConfirm: {
                Haptics.select()
                onUnlock()
            },
            onCancel: onCancel
        )
    }
}
#endif
