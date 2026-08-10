#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
#if canImport(LinkPresentation)
import LinkPresentation
#endif

/// Turning a card view into an image, and an image into a share sheet
/// (0.7.8, B). One mechanism, used by all three card kinds.
///
/// **Why this is one helper rather than three renderers.** B1, B2 and B3 all
/// want the same two steps — lay out a fixed-size SwiftUI view off-screen,
/// hand the resulting `UIImage` to the system share sheet — and differ only in
/// what is drawn. So the difference lives in `ShareCardBody`'s cases and this
/// file is written once. B4 is the reason that matters: three renderers with no
/// buttons on them would have been the failure mode.
@MainActor
public enum ShareCardRenderer {
    /// The card's layout size in points. 4:5, the portrait aspect every social
    /// surface crops least aggressively.
    public static let size = CGSize(width: 360, height: 450)

    /// **Fixed at 3, deliberately not `UIScreen.main.scale`.**
    ///
    /// This image leaves the device. Rendering at 1× produces a 360-point-wide
    /// PNG that Messages upscales into mush on any retina display, which is the
    /// obvious bug; but taking the *screen's* scale is the subtler one, because
    /// then the same card exports 1080px wide from a Pro and 720px from an SE
    /// and the product looks inconsistent for reasons the user cannot see. The
    /// export is not a screen render, so it should not inherit a screen's
    /// scale. 3 gives a 1080×1350 image — the size Instagram and Messages both
    /// want — from every device.
    public static let scale: CGFloat = 3

    /// Renders a card to a PNG-ready image, or nil if the renderer declines.
    ///
    /// `ImageRenderer` is `@MainActor`, hence the isolation on the whole type.
    /// An explicit `.frame` is required: the card views size themselves to the
    /// device otherwise, and `ImageRenderer` supplies no proposed size.
    public static func image<Content: View>(@ViewBuilder _ content: () -> Content) -> UIImage? {
        let renderer = ImageRenderer(
            content: content()
                .frame(width: size.width, height: size.height)
                // The app pins `.dynamicTypeSize(.large)` at the root so a
                // screen's layout cannot be pulled apart by a text setting.
                // An exported image has to pin it too — it is not inside the
                // root's environment, and a card that reflows at the reader's
                // accessibility size would export differently for each user.
                .dynamicTypeSize(.large)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = scale
        // Opaque: the cards are a device on a background, and a transparent PNG
        // dropped into a dark chat client shows whatever is behind it.
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// A shared image that the share sheet can show a preview of (0.8.2,
/// coordinator 3).
///
/// **The question was whether this toolchain can do it at all, and it can.**
/// The share sheet's header — the thumbnail and title above the row of apps —
/// is not drawn from the activity items. It comes from `LinkPresentation`: iOS
/// asks each item source for an `LPLinkMetadata` and draws the header from
/// that, and an item that is a bare `UIImage` supplies none. So `[image]`, the
/// payload this file passed for three releases, produced a sheet with an empty
/// header and no indication of what was about to be sent.
///
/// `LinkPresentation` is an ordinary iOS SDK framework with a Swift overlay, so
/// `import` is the whole of the integration — no linker settings, no
/// `.framework` in `Package.swift`. `OCRService` already imports `Vision` on
/// the same basis, which is what made this worth trying rather than assuming.
/// Guarded by `canImport` anyway, so the file still compiles if a future
/// toolchain drops the overlay, and the sheet degrades to exactly what it
/// showed before.
///
/// `NSItemProvider(object:)` copies the image, so the metadata's thumbnail and
/// the shared item are the same picture without the card being rendered twice —
/// which matters, because `ShareCardRenderer` is 1080×1350 of main-actor work.
///
/// **The title is the payload's, not a constant.** A sheet headed "Vinodex"
/// three times over says less than "Nebbiolo", "Cellar Profile" and the name of
/// a badge, and the caller is the only thing that knows which it is.
final class ShareCardItemSource: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    /// Returned before the sheet is built, so it must be cheap and the right
    /// *type* rather than the right value — the sheet decides which activities
    /// to offer from this. An empty `UIImage` is the documented placeholder.
    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        UIImage()
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        image
    }

    /// The subject line for activities that have one — Mail, mostly. Free, and
    /// the alternative is a mail draft titled with the filename.
    func activityViewController(
        _ controller: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        title
    }

    #if canImport(LinkPresentation)
    func activityViewControllerLinkMetadata(
        _ controller: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
    #endif
}

/// `UIActivityViewController` in a SwiftUI wrapper.
///
/// A representable rather than SwiftUI's `ShareLink` for one reason: the image
/// does not exist until the user asks for it. `ShareLink` takes its payload up
/// front, so the label on every entry row would have to render its card
/// eagerly — 1080×1350 of `ImageRenderer` work per entry, on the main actor,
/// for a button most people never press.
///
/// Modelled on `CameraCapture` in `OCRService.swift`, the app's other
/// representable, down to the coordinator-free shape — this one has no delegate
/// to keep, only a completion.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// What a screen hands to `.shareCard(_:)`.
///
/// An enum rather than a bare `[Any]` so a call site cannot accidentally share
/// the wrong thing, and so the copy-to-clipboard affordance in C1 can travel
/// beside the text it copies.
enum SharePayload: Identifiable {
    /// An image card (B1–B3), with the name the share sheet's header shows
    /// (0.8.2). The title is not decoration: without an item source supplying
    /// it there is no header at all.
    case image(UIImage, title: String)
    /// A result string (C1) — shared as text, and separately copyable.
    case text(String)

    var id: String {
        switch self {
        case .image(_, let title): "image:" + title
        case .text(let string): string
        }
    }

    var items: [Any] {
        switch self {
        // The item source rather than the bare image — see
        // `ShareCardItemSource`. `UIActivityViewController` accepts either, and
        // the difference is entirely the preview.
        case .image(let image, let title): [ShareCardItemSource(image: image, title: title)]
        case .text(let string): [string]
        }
    }
}

extension View {
    /// Presents the share sheet for a payload, clearing it when dismissed.
    func shareCard(_ payload: Binding<SharePayload?>) -> some View {
        sheet(item: payload) { item in
            ShareSheet(items: item.items) { payload.wrappedValue = nil }
        }
    }
}
#endif
