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
struct DexSearchField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var fontSize: CGFloat
    /// Raises the keyboard as soon as the field exists.
    ///
    /// For a field that is *revealed* by a control rather than always on
    /// screen — the profile name, behind its pencil — where tapping the pencil
    /// and then having to tap the field it just produced is a wasted step.
    /// `@FocusState` cannot do this: `.focused()` has no effect on a
    /// `UIViewRepresentable`, which owns its own responder.
    var focusesOnAppear: Bool

    init(
        text: Binding<String>,
        placeholder: String = "INPUT SEARCH...",
        fontSize: CGFloat = DexSearchField.defaultFontSize,
        focusesOnAppear: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.fontSize = fontSize
        self.focusesOnAppear = focusesOnAppear
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.autocorrectionType = .no
        field.autocapitalizationType = .allCharacters
        field.spellCheckingType = .no
        field.returnKeyType = .search
        // A clear (×) button while editing, so a query need not be deleted
        // character by character (audit L34).
        field.clearButtonMode = .whileEditing
        field.backgroundColor = .clear
        field.font = uiFont
        applyColors(to: field)
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        // Deferred: the view is not in a window yet during `makeUIView`, and a
        // responder request from outside the hierarchy is simply dropped.
        if focusesOnAppear {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        }
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text {
            field.text = text
        }
        // The face too, not only the colours. `applyColors` rebuilds
        // `attributedPlaceholder` from `uiFont` on every update, so leaving
        // `field.font` to `makeUIView` alone lets the placeholder and the typed
        // text disagree about size. Guarded because this runs on every
        // keystroke, and assigning an equal font to a first responder throws
        // away marked text and the selection for nothing.
        let font = uiFont
        if field.font != font { field.font = font }
        // Re-apply colours on every update so toggling SCREEN MODE while a field
        // is mounted repaints it, instead of leaving stale, possibly illegible
        // colours from makeUIView (audit M13).
        applyColors(to: field)
    }

    /// Tint, text and placeholder colours from the current LCD mode. Typed text
    /// has to contrast with the well it sits in, which is white in light mode —
    /// the mint green vanished on it. Called from both make and update.
    private func applyColors(to field: UITextField) {
        let accent = UIColor(LcdMode.current.accent)
        field.tintColor = accent
        field.textColor = accent
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: accent.withAlphaComponent(0.45),
                .font: uiFont,
            ]
        )
    }

    /// The one nominal size the search chrome is authored at. Named once
    /// because `DexSearchBar` and `DexSearchBarButton` both have to spell it,
    /// and a live field that disagrees with the placeholder beside it is
    /// exactly the bug below.
    static let defaultFontSize: CGFloat = 26

    private var uiFont: UIFont {
        // Through the resolver, not the raw `fontSize` (AUDIT **M50**). This is
        // the app's only text-size axis and this `UIFont` was the one drawn
        // control in the app that ignored it: at the shipped SMALL step the
        // field drew at 26pt beside a `DexFont.mono(26)` placeholder drawing at
        // 22.1 — and the mismatch reverses sign at HUGE, where the field is the
        // *smaller* of the two.
        //
        // Not `fontSize * TextScale.current.factor` either: `nominalFloor` sits
        // between the nominal and the factor. It is a no-op at 20 and 26, which
        // is precisely why the hand-rolled form survives review — see the same
        // mistake caught once already at `DeviceChassis`'s marquee.
        let point = DexFont.resolvedSize(fontSize)
        return UIFont(name: DexFont.names.mono, size: point)
            ?? .monospacedSystemFont(ofSize: point, weight: .regular)
    }

    /// The drawn height of a field authored at `nominal`, never below the height
    /// the call site used to pin by hand.
    ///
    /// The three call sites each pinned their own constant, so scaling the font
    /// without them would have desynchronised all three — which is why M50 was
    /// deferred out of H11 rather than taken with it. `+ 8` is `34 - 26`, the
    /// slack `DexSearchBar` has always carried: VT323's line height is exactly
    /// 1.0 em, so a nominal-`n` field needs about `n` points and the rest is
    /// padding, which does not scale with type.
    ///
    /// The `atLeast:` floor is why `RatingPrompt`'s 40pt well does not *shrink*
    /// at SMALL. The field is the tap target there — the capsule behind it is
    /// not hit-testable — and trading a type bug for a touch-target one is not
    /// a fix.
    static func height(nominal: CGFloat, atLeast pinned: CGFloat) -> CGFloat {
        max(pinned, DexFont.resolvedSize(nominal) + 8)
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextFieldDelegate {
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

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
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
struct DexSearchBarShell<Content: View>: View {
    @ViewBuilder var content: () -> Content

    /// The capsule's drawn height: never less than the field it wraps, and
    /// never less than the 46 it has always been.
    ///
    /// The shipped 46 carries 12pt of air over a 34pt field. That air is *not*
    /// added back on top here, deliberately: at HUGE the field is 37.9pt and 46
    /// already contains it, so `field + 12` would grow a capsule that had no
    /// need to grow and change a layout that works. Taking the max instead
    /// makes this a provable no-op at every step that has ever shipped — the
    /// padding simply tightens from 12pt to 4.2pt as the type grows, which is
    /// what chrome holding larger text is supposed to do — and the capsule only
    /// starts growing past f = 1.462, which is where M50 said it would.
    static var shellHeight: CGFloat {
        max(46, DexSearchField.height(nominal: DexSearchField.defaultFontSize, atLeast: 34))
    }

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(lcd.accent)
            content()
        }
        .padding(.horizontal, 14)
        // Derived, not pinned (AUDIT **M49**). M50 recorded this literal as a
        // ceiling on the text axis — `26f + 8 ≤ 46` holds only to f = 1.462, so
        // the field inside would have grown out of its own capsule. The shell
        // is the field plus the 12pt of vertical air it has always carried, so
        // the two now move together and there is no ceiling left to hit.
        .frame(height: Self.shellHeight)
        .background(Capsule().fill(lcd.well))
        .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 2))
    }
}

/// A live search field in the standard shell.
struct DexSearchBar: View {
    @Binding var text: String
    var placeholder: String
    /// Raises the keyboard as the bar appears — see `DexSearchField`. Passed
    /// through rather than defaulted on: a list screen you reached to *browse*
    /// should not open with half of it under a keyboard. (AUDIT **L35**)
    var focusesOnAppear: Bool

    init(
        text: Binding<String>,
        placeholder: String = "INPUT SEARCH...",
        focusesOnAppear: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.focusesOnAppear = focusesOnAppear
    }

    var body: some View {
        DexSearchBarShell {
            DexSearchField(
                text: $text,
                placeholder: placeholder,
                focusesOnAppear: focusesOnAppear
            )
            // Derived, not pinned (AUDIT **M50**). Scaling the font and leaving
            // 34 alone looks right today — VT323 at HUGE is 29.9pt and still
            // fits — and breaks silently the moment the text axis passes
            // 34/26 = 1.308, which is exactly what M49 proposes.
            .frame(height: DexSearchField.height(nominal: DexSearchField.defaultFontSize, atLeast: 34))
        }
    }
}

/// A search bar that opens a screen rather than accepting typing.
///
/// Renders the placeholder with `DexSearchField`'s own face, size and colour, so
/// it is indistinguishable from the real thing until you tap it.
struct DexSearchBarButton: View {
    var placeholder: String
    var action: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    init(placeholder: String, action: @escaping () -> Void) {
        self.placeholder = placeholder
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            DexSearchBarShell {
                Text(placeholder)
                    .font(DexFont.mono(DexSearchField.defaultFontSize))
                    .foregroundStyle(lcd.accent.opacity(0.45))
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
    }
}

#endif
