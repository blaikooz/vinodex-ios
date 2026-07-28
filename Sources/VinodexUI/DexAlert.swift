#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

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
    let onConfirm: () -> Void
    let onCancel: () -> Void

    public init(
        title: String,
        message: String,
        confirmLabel: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmLabel = confirmLabel
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
                    button(
                        "CANCEL",
                        fill: Dex.stone800,
                        border: Dex.stone600,
                        text: Dex.stone200,
                        action: onCancel
                    )
                    button(
                        confirmLabel,
                        fill: Dex.red600,
                        border: Dex.red800,
                        text: .white,
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
#endif
