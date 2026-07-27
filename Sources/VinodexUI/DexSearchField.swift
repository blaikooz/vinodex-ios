#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// The retro search input, with a blinking green block instead of the system caret.
///
/// The web app fakes this by measuring caret pixel offset with a hidden `<span>`
/// and `getBoundingClientRect` (`EncyclopediaList.tsx:41`). SwiftUI's `TextField`
/// exposes no caret position at all, but UIKit does — `caretRect(for:)` gives it
/// directly, including for mid-string taps. So the native version is both simpler
/// and more accurate than the one it replaces.
public struct DexSearchField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var fontSize: CGFloat

    public init(text: Binding<String>, placeholder: String = "INPUT SEARCH...", fontSize: CGFloat = 26) {
        self._text = text
        self.placeholder = placeholder
        self.fontSize = fontSize
    }

    public func makeUIView(context: Context) -> BlockCaretTextField {
        let field = BlockCaretTextField()
        field.delegate = context.coordinator
        field.autocorrectionType = .no
        field.autocapitalizationType = .allCharacters
        field.spellCheckingType = .no
        field.returnKeyType = .search
        field.clearButtonMode = .never
        field.backgroundColor = .clear
        // Hides the system caret; the block is drawn as a subview instead.
        field.tintColor = .clear
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

    public func updateUIView(_ field: BlockCaretTextField, context: Context) {
        if field.text != text {
            field.text = text
        }
        field.caretColor = UIColor(Dex.green500)
        field.refreshCaret()
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
            text.wrappedValue = field.text ?? ""
            (field as? BlockCaretTextField)?.refreshCaret()
        }

        public func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            return true
        }
    }
}

/// A text field that draws its own blinking block caret.
public final class BlockCaretTextField: UITextField {
    private let block = UIView()

    public var caretColor: UIColor = .green {
        didSet { block.backgroundColor = caretColor }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func configure() {
        block.backgroundColor = caretColor
        block.isUserInteractionEnabled = false
        addSubview(block)
        startBlinking()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshCaret),
            name: UITextField.textDidChangeNotification,
            object: self
        )
    }

    private func startBlinking() {
        // step-end easing, matching the CSS `blink 1s step-end infinite`.
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [1, 1, 0, 0]
        animation.keyTimes = [0, 0.5, 0.5, 1]
        animation.duration = 1
        animation.repeatCount = .infinity
        animation.calculationMode = .discrete
        block.layer.add(animation, forKey: "blink")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        refreshCaret()
    }

    /// Positions the block at the true caret rect, so mid-string taps land
    /// correctly — the case the web app's width-measuring hack existed to handle.
    @objc public func refreshCaret() {
        guard let position = selectedTextRange?.start else {
            block.isHidden = true
            return
        }
        block.isHidden = false
        let rect = caretRect(for: position)
        guard rect.height.isFinite, rect.minX.isFinite else {
            block.isHidden = true
            return
        }
        let width = max(font?.pointSize ?? 20, 18) * 0.42
        block.frame = CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height)
    }

    public override func caretRect(for position: UITextPosition) -> CGRect {
        super.caretRect(for: position)
    }
}
#endif
