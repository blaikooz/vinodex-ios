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
        // Typed text has to contrast with the well it sits in, which is
        // white in light mode — the mint green vanished on it.
        field.tintColor = UIColor(LcdMode.current.accent)
        field.textColor = UIColor(LcdMode.current.accent)
        field.font = uiFont
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor(LcdMode.current.accent).withAlphaComponent(0.45),
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

/// The capsule shell every search affordance in the app wears.
///
/// Extracted because there were two hand-rolled copies that had drifted: the
/// list screens' bar tinted its glyph `green500` while the globe's tinted it
/// `lcd.accent`, they used 12pt and 14pt of inner padding, and the globe's
/// carried a trailing chevron the others did not. Read side by side they looked
/// like two different controls, which is exactly what a search bar must not be.
///
/// The shell is the shared part; what sits in it is not. `DexSearchBar` takes a
/// binding and accepts typing; `DexSearchBarButton` looks identical and opens a
/// screen instead, which is what the globe needs — results laid over a spinning
/// sphere read as a rendering glitch.
public struct DexSearchBarShell<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(lcd.accent)
            content()
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Capsule().fill(lcd.well))
        .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 2))
    }
}

/// A live search field in the standard shell.
public struct DexSearchBar: View {
    @Binding var text: String
    var placeholder: String

    public init(text: Binding<String>, placeholder: String = "INPUT SEARCH...") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        DexSearchBarShell {
            DexSearchField(text: $text, placeholder: placeholder)
                .frame(height: 34)
        }
    }
}

/// A search bar that opens a screen rather than accepting typing.
///
/// Renders the placeholder with `DexSearchField`'s own face, size and colour, so
/// it is indistinguishable from the real thing until you tap it.
public struct DexSearchBarButton: View {
    var placeholder: String
    var action: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(placeholder: String, action: @escaping () -> Void) {
        self.placeholder = placeholder
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            DexSearchBarShell {
                Text(placeholder)
                    .font(DexFont.mono(26))
                    .foregroundStyle(lcd.accent.opacity(0.45))
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
    }
}

#endif
