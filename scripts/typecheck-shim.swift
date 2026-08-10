// UIKit stand-ins, so VinodexUI can be type-checked against the macOS SDK.
//
// See scripts/typecheck-ios-surface.sh for what this is for. Everything here is
// `public` on purpose: a `public` property in the app whose type resolves to an
// internal typealias is itself an error, and that error is a declaration-level
// one, which suppresses function-body checking everywhere. Same reason the file
// must stay at zero diagnostics — see the script's header.
//
// Nothing here has to *behave*. It has to have the right shape.

import AppKit
import CoreImage
import CoreText
import Foundation
import QuartzCore
import SceneKit
import SwiftUI

// MARK: - Straight aliases

public typealias UIColor = NSColor
public typealias UIImage = NSImage
public typealias UIFont = NSFont
public typealias UIScreen = NSScreen
public typealias UIWindow = NSWindow
public typealias UITraitCollection = NSAppearance
public typealias UIViewRepresentable = NSViewRepresentable
public typealias UIViewControllerRepresentable = NSViewControllerRepresentable

// MARK: - Types with no AppKit counterpart

@MainActor public protocol UITextFieldDelegate: AnyObject {}
@MainActor public protocol UIApplicationDelegate: AnyObject {}

// MARK: - View controllers
//
// `NSViewControllerRepresentable` constrains its `NSViewControllerType` to
// `NSViewController`, so these have to be real subclasses rather than empty
// stubs — the same reason `UITextField` is a genuine `NSView` subclass above
// and not an `NSTextField` alias. Only the members the app actually touches
// are declared; anything else is a spelling this harness has never needed.

// `@MainActor` on all three because UIKit annotates them, and the whole value
// of this harness is reproducing CI's isolation diagnostics exactly. Leaving
// them bare invents errors the real SDK would not raise: a delegate method that
// is MainActor-isolated on iOS reads its `View`'s statics quite legally, and an
// unannotated protocol here would report that as a cross-actor reference.
@MainActor public protocol UIImagePickerControllerDelegate: AnyObject {}
@MainActor public protocol UINavigationControllerDelegate: AnyObject {}
@MainActor public protocol UIActivityItemSource: AnyObject {}

public final class UIImagePickerController: NSViewController {
    public enum SourceType { case camera, photoLibrary, savedPhotosAlbum }
    public struct InfoKey: Hashable, Sendable {
        public static let originalImage = InfoKey(raw: "originalImage")
        public static let editedImage = InfoKey(raw: "editedImage")
        let raw: String
    }
    public enum CameraCaptureMode { case photo, video }
    public var sourceType: SourceType = .photoLibrary
    public var cameraCaptureMode: CameraCaptureMode = .photo
    public var allowsEditing = false
    public var mediaTypes: [String] = []
    public weak var delegate: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)?
    public static func isSourceTypeAvailable(_ type: SourceType) -> Bool { true }
}

public enum UIActivity {
    public struct ActivityType: Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
    }
}

// MARK: - MessageUI

/// The in-app mail composer, for `SupportScreen`. Only the members the app
/// touches. `canSendMail()` answers false — the harness checks call sites,
/// it never presents one.
public enum MFMailComposeResult: Int { case cancelled, saved, sent, failed }

/// **Deliberately not `@MainActor`, unlike the delegate protocols above.**
/// MessageUI predates the isolation annotations, so the real requirement is
/// nonisolated — and `SupportScreen`'s whole `@preconcurrency` conformance
/// exists to bridge exactly that. Annotating it here would make the app's
/// bridge look unnecessary and report an error CI does not raise.
public protocol MFMailComposeViewControllerDelegate: AnyObject {
    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: (any Error)?
    )
}

public final class MFMailComposeViewController: NSViewController {
    public static func canSendMail() -> Bool { false }
    public weak var mailComposeDelegate: (any MFMailComposeViewControllerDelegate)?
    public func setToRecipients(_ recipients: [String]?) {}
    public func setSubject(_ subject: String) {}
}

public extension NSViewController {
    /// `UIViewController.dismiss(animated:completion:)`. The pickers all
    /// dismiss through SwiftUI bindings; the mail composer's delegate is the
    /// one caller of the UIKit spelling.
    func dismiss(animated: Bool, completion: (() -> Void)? = nil) {}
}

public final class UIActivityViewController: NSViewController {
    public var completionWithItemsHandler: ((UIActivity.ActivityType?, Bool, [Any]?, Error?) -> Void)?
    public var excludedActivityTypes: [UIActivity.ActivityType]?
    public init(activityItems: [Any], applicationActivities: [Any]?) {
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("unused") }
}

public final class UIApplication: @unchecked Sendable {
    public static let shared = UIApplication()
    public var isIdleTimerDisabled = false
    /// The Settings deep link, for the notifications row that can only be
    /// fixed outside the app.
    public static let openSettingsURLString = "app-settings:"
    @discardableResult public func open(_ url: URL) -> Bool { true }
    /// `SupportScreen`'s mailto: fallback probes this before offering the row.
    public func canOpenURL(_ url: URL) -> Bool { false }
    public var connectedScenes: Set<UIScene> { [] }
}

/// The BIOS corner's battery readout.
public final class UIDevice: @unchecked Sendable {
    public static let current = UIDevice()
    public var isBatteryMonitoringEnabled = false
    /// `-1` is UIKit's "unknown", which is the value the simulator reports and
    /// the one `BiosChrome.battery(level:)` has to cope with anyway.
    public var batteryLevel: Float = -1
}

public final class UIPasteboard: @unchecked Sendable {
    public static let general = UIPasteboard()
    public var string: String?
}

/// Touch plumbing for `IdleTouchWatcher`, which subclasses the recogniser so it
/// can see *any* touch — see F2. Only the members it overrides are declared.
public class UITouch: NSObject {}
public class UIEvent: NSObject {}

/// `@MainActor` because UIKit marks it so. Without that, `IdleTouchWatcher`'s
/// `touchesBegan` override reads as nonisolated and every `IdleMonitor.shared`
/// touch inside it reports as a cross-actor reference — three errors the real
/// SDK does not raise. Same trap as the delegate protocols above.
@MainActor
open class UIGestureRecognizer: NSObject {
    public enum State { case possible, began, changed, ended, cancelled, failed, recognized }
    /// `.failed` is the only value the app sets — the watcher observes touches
    /// and never claims one, so it fails itself immediately and lets the touch
    /// through to whatever is underneath.
    public var state: State = .possible
    public var cancelsTouchesInView = true
    public var delaysTouchesBegan = false
    public var delaysTouchesEnded = false
    public override init() { super.init() }
    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {}
    open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {}
    open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {}
    open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {}
}

public extension NSWindow {
    func addGestureRecognizer(_ recognizer: UIGestureRecognizer) {}
}

/// Scene stubs, for `IdleMonitor`'s walk to the key window. `NSObject` rather
/// than a bare class so `Set<UIScene>` gets its `Hashable` by identity, which
/// is what UIKit's own `connectedScenes` relies on.
public class UIScene: NSObject {}

public final class UIWindowScene: UIScene {
    /// `UIWindow` is `NSWindow` here, and `NSWindow.isKeyWindow` already exists
    /// with the same spelling — so the caller's `first { $0.isKeyWindow }`
    /// needs nothing further.
    public var windows: [UIWindow] { [] }
}

public final class UISelectionFeedbackGenerator {
    public init() {}
    public func prepare() {}
    public func selectionChanged() {}
}

public final class UIImpactFeedbackGenerator {
    public enum FeedbackStyle { case light, medium, heavy, soft, rigid }
    public init(style: FeedbackStyle = .medium) {}
    public func prepare() {}
    public func impactOccurred() {}
}

public final class UINotificationFeedbackGenerator {
    public enum FeedbackType { case success, warning, error }
    public init() {}
    public func prepare() {}
    public func notificationOccurred(_ type: FeedbackType) {}
}

public struct UIInterfaceOrientationMask: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let portrait = UIInterfaceOrientationMask(rawValue: 1)
    public static let all = UIInterfaceOrientationMask(rawValue: 2)
}

@propertyWrapper public struct UIApplicationDelegateAdaptor<T: AnyObject> {
    public var wrappedValue: T
    public init(_ type: T.Type) { wrappedValue = unsafeBitCast(0, to: T.self) }
}

/// Not an `NSTextField` alias — the two share almost no API, and aliasing them
/// produced 22 bogus errors that drowned out the real ones. An `NSView`
/// subclass, since `NSViewRepresentable.NSViewType` requires it.
public enum ShimTextOption { case no, allCharacters, search, whileEditing, editingChanged, none }

public final class UITextField: NSView {
    public var text: String?
    public var selectedTextRange: Any?
    public weak var delegate: UITextFieldDelegate?
    public var autocorrectionType = ShimTextOption.no
    public var autocapitalizationType = ShimTextOption.no
    public var spellCheckingType = ShimTextOption.no
    public var returnKeyType = ShimTextOption.no
    public var clearButtonMode = ShimTextOption.no
    public var borderStyle = ShimTextOption.none
    public var tintColor: NSColor?
    public var textColor: NSColor?
    public var font: NSFont?
    public var backgroundColor: NSColor?
    public var attributedPlaceholder: NSAttributedString?
    public var placeholder: String?
    public func addTarget(_ target: Any?, action: Selector, for event: ShimTextOption) {}
}

public final class UIGraphicsImageRendererFormat {
    public var scale: CGFloat = 1
    public var opaque = false
    public init() {}
    public static func preferred() -> UIGraphicsImageRendererFormat { .init() }
    public static func `default`() -> UIGraphicsImageRendererFormat { .init() }
}

public final class UIGraphicsImageRenderer {
    public init(size: CGSize, format: UIGraphicsImageRendererFormat = .init()) {}
    public func image(actions: (Any) -> Void) -> UIImage { NSImage() }
}

/// `CADisplayLink.init(target:selector:)` is macOS-unavailable and cannot be
/// extended around, so the script renames the type in its copy of the tree.
public final class ShimDisplayLink {
    public init(target: Any, selector: Selector) {}
    public var preferredFrameRateRange = CAFrameRateRange.default
    public var isPaused = false
    public var timestamp: CFTimeInterval { 0 }
    public var duration: CFTimeInterval { 0 }
    public func add(to runloop: RunLoop, forMode mode: RunLoop.Mode) {}
    public func invalidate() {}
}

// MARK: - Members UIKit has and AppKit spells differently

public enum ShimOrientation { case up, down, left, right }

public extension NSImage {
    convenience init(cgImage: CGImage) { self.init(cgImage: cgImage, size: .zero) }
    convenience init(cgImage: CGImage, scale: CGFloat, orientation: ShimOrientation) {
        self.init(cgImage: cgImage, size: .zero)
    }
    convenience init?(data: Data, scale: CGFloat) { self.init(data: data) }

    enum ShimRenderingMode { case alwaysTemplate, alwaysOriginal, automatic }
    func withRenderingMode(_ mode: ShimRenderingMode) -> NSImage { self }

    var scale: CGFloat { 1 }
    func jpegData(compressionQuality: CGFloat) -> Data? { nil }
    func pngData() -> Data? { nil }
    func draw(in rect: CGRect) { draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1) }

    /// `NSImage` spells this as a three-argument method, `UIImage` as a
    /// property; the script rewrites `.cgImage` to `.shimCGImage` so the two do
    /// not collide.
    var shimCGImage: CGImage? { cgImage(forProposedRect: nil, context: nil, hints: nil) }
}

public extension Image {
    init(uiImage: NSImage) { self.init(nsImage: uiImage) }
}

public extension NSColor {
    /// `UIColor.getRed(_:green:blue:alpha:)` returns `Bool` — it reports whether
    /// the colour could be expressed in RGB. `NSColor`'s returns `Void` and
    /// traps instead. The script rewrites `.getRed(` to `.shimGetRed(` so a
    /// `guard` on the result type-checks here the way it compiles on iOS;
    /// same collision, same remedy as `.cgImage` above.
    func shimGetRed(
        _ red: UnsafeMutablePointer<CGFloat>?,
        green: UnsafeMutablePointer<CGFloat>?,
        blue: UnsafeMutablePointer<CGFloat>?,
        alpha: UnsafeMutablePointer<CGFloat>?
    ) -> Bool {
        getRed(red, green: green, blue: blue, alpha: alpha)
        return true
    }
}

public extension NSAppearance {
    var displayScale: CGFloat { 2 }
}

public extension SCNView {
    var isUserInteractionEnabled: Bool { get { true } set { _ = newValue } }
}

public extension CIImage {
    convenience init?(image: NSImage) { self.init(color: .black) }
}

/// SwiftPM generates this; a bare `swiftc` invocation does not.
public extension Bundle {
    static var module: Bundle { .main }
}
