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

public protocol UITextFieldDelegate: AnyObject {}
public protocol UIApplicationDelegate: AnyObject {}

// MARK: - View controllers
//
// `NSViewControllerRepresentable` constrains its `NSViewControllerType` to
// `NSViewController`, so these have to be real subclasses rather than empty
// stubs — the same reason `UITextField` is a genuine `NSView` subclass above
// and not an `NSTextField` alias. Only the members the app actually touches
// are declared; anything else is a spelling this harness has never needed.

public protocol UIImagePickerControllerDelegate: AnyObject {}
public protocol UINavigationControllerDelegate: AnyObject {}
public protocol UIActivityItemSource: AnyObject {}

public final class UIImagePickerController: NSViewController {
    public enum SourceType { case camera, photoLibrary, savedPhotosAlbum }
    public struct InfoKey: Hashable, Sendable {
        public static let originalImage = InfoKey(raw: "originalImage")
        public static let editedImage = InfoKey(raw: "editedImage")
        let raw: String
    }
    public var sourceType: SourceType = .photoLibrary
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
