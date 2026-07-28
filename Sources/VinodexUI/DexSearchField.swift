#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// The retro search input.
///
/// This used to draw a blinking green block in place of the system caret, ported
/// from the web app's hidden-`<span>` measuring trick. It was accurate and it
/// worked, but it earned nothing on a device where the real caret is already
/// visible and correctly placed — so it is gone, along with the layout,
/// blink-animation and caret-measuring code that kept it in position.
public struct DexSearchField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var fontSize: CGFloat

    public init(text: Binding<String>, placeholder: String = "INPUT SEARCH...", fontSize: CGFloat = 26) {
        self._text = text
        self.placeholder = placeholder
        self.fontSize = fontSize
    }

    public func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.autocorrectionType = .no
        field.autocapitalizationType = .allCharacters
        field.spellCheckingType = .no
        field.returnKeyType = .search
        field.clearButtonMode = .never
        field.backgroundColor = .clear
        field.tintColor = UIColor(Dex.green500)
        field.textColor = UIColor(Dex.green500)
        field.font = uiFont
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor(Dex.green500).withAlphaComponent(0.35),
                .font: uiFont,
            ]
        )
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    public func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text {
            field.text = text
        }
    }

    private var uiFont: UIFont {
        UIFont(name: DexFont.names.mono, size: fontSize)
            ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    public func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    public final class Coordinator: NSObject, UITextFieldDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func editingChanged(_ field: UITextField) {
            // `.allCharacters` only shifts the keyboard — it does not touch
            // pasted text or an autocorrect substitution, so those arrived
            // lower-case in a field where everything else is caps.
            let upper = (field.text ?? "").uppercased()
            if field.text != upper {
                // Preserve the caret: reassigning `text` sends it to the end.
                let selection = field.selectedTextRange
                field.text = upper
                field.selectedTextRange = selection
            }
            text.wrappedValue = upper
        }

        public func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            return true
        }
    }
}

#endif
