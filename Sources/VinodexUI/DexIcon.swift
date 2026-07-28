#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

/// Loads bundled icon PNGs by Iconify id.
///
/// No asset catalog is involved — `actool` is macOS-only — so images are read
/// from the resource bundle by path. `@MainActor` rather than a bare static
/// cache because Swift 6 strict concurrency rejects mutable global state.
@MainActor
public final class IconLoader {
    public static let shared = IconLoader()

    private var cache: [String: UIImage] = [:]

    private init() {}

    /// Returns the glyph for an Iconify id, or the manifest fallback.
    public func image(_ iconID: String) -> UIImage? {
        if let hit = cache[iconID] { return hit }

        let slug = IconManifest.slug(for: iconID)
        guard let url = DexResources.url(named: slug, ext: "png", subdirectory: "Resources/Icons"),
              let image = UIImage(contentsOfFile: url.path)
        else {
            return nil
        }

        // Rendered white so it can be tinted per entry at draw time.
        let template = image.withRenderingMode(.alwaysTemplate)
        cache[iconID] = template
        return template
    }
}

/// An entry's glyph, tinted and outlined.
public struct DexIcon: View {
    let iconID: String
    var size: CGFloat
    var color: Color
    var outlined: Bool

    public init(iconID: String, size: CGFloat = 30, color: Color = .white, outlined: Bool = true) {
        self.iconID = iconID
        self.size = size
        self.color = color
        self.outlined = outlined
    }

    public var body: some View {
        Group {
            if let image = IconLoader.shared.image(iconID) {
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(color)
            } else {
                // Visible on purpose: a missing glyph is a build problem worth
                // seeing rather than an invisible gap.
                Image(systemName: "questionmark.square.dashed")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Dex.red500)
            }
        }
        .frame(width: size, height: size)
        .modifier(PixelOutline(enabled: outlined))
    }
}

/// Reproduces the web app's 1px black icon outline.
///
/// `entryIconVisuals.tsx:41` stacks eight `drop-shadow(±0.5px ±0.5px 0 #000)`
/// filters. SwiftUI's `.shadow(radius: 0, x:, y:)` is the direct analogue and
/// composes the same way, so the eight offsets port across literally — no need
/// to bake the outline into the PNGs, which would have blocked runtime tinting.
/// The eight offsets are applied literally rather than folded in a loop. The
/// loop needed an `AnyView` per step to keep one return type, and eight nested
/// `AnyView`s per glyph — thousands across a list — defeat SwiftUI's structural
/// diffing entirely. Spelled out, the whole chain is one static type.
struct PixelOutline: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .shadow(color: .black, radius: 0, x: 0.5, y: 0)
                .shadow(color: .black, radius: 0, x: -0.5, y: 0)
                .shadow(color: .black, radius: 0, x: 0, y: 0.5)
                .shadow(color: .black, radius: 0, x: 0, y: -0.5)
                .shadow(color: .black, radius: 0, x: 0.5, y: 0.5)
                .shadow(color: .black, radius: 0, x: -0.5, y: 0.5)
                .shadow(color: .black, radius: 0, x: 0.5, y: -0.5)
                .shadow(color: .black, radius: 0, x: -0.5, y: -0.5)
        } else {
            content
        }
    }
}

public extension WineEntry {
    /// Icon tint for this entry — its authored colour, lightened enough to stay
    /// legible against the dark icon well.
    var iconTint: Color {
        Color(dexHex: color)
    }
}
#endif
