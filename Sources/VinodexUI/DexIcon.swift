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

    private init() {
        let scale = Int(UITraitCollection.current.displayScale.rounded())
        preferredScale = (1...3).contains(scale) ? scale : 3
    }

    /// The device's pixel density, clamped to the scales the pipeline emits.
    /// Resolved once, in the `@MainActor` init: display scale does not change
    /// under a running iPhone app, and the cache below is keyed by icon id
    /// alone on that assumption. `UITraitCollection.current` rather than
    /// `UIScreen.main` (deprecated path); a zero/unspecified reading falls
    /// back to 3x, which every shipped icon has and which downscales far
    /// better than 1x upscales.
    private let preferredScale: Int

    /// Returns the glyph for an Iconify id, or the manifest fallback.
    ///
    /// Picks the density-matched `@2x`/`@3x` variant (0.6.3, item 2 — AUDIT
    /// H6): every glyph used to load the 64px `@1x` and upscale, visibly soft
    /// app-wide, while the hi-res variants shipped as dead payload. Loaded via
    /// `UIImage(data:scale:)` so the point size stays what it always was.
    public func image(_ iconID: String) -> UIImage? {
        if let hit = cache[iconID] { return hit }

        let slug = IconManifest.slug(for: iconID)
        guard let image = load(slug: slug) else { return nil }

        // Rendered white so it can be tinted per entry at draw time.
        let template = image.withRenderingMode(.alwaysTemplate)
        cache[iconID] = template
        return template
    }

    /// The best variant at or below the device scale — a missing `@3x` walks
    /// down to `@2x` and then to the bare `@1x` name, so an icon that shipped
    /// without variants keeps working exactly as before.
    private func load(slug: String) -> UIImage? {
        for scale in stride(from: preferredScale, through: 1, by: -1) {
            let name = scale == 1 ? slug : "\(slug)@\(scale)x"
            guard let url = DexResources.url(named: name, ext: "png", subdirectory: "Resources/Icons"),
                  let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data, scale: CGFloat(scale))
            else { continue }
            return image
        }
        return nil
    }
}

/// An entry's glyph, tinted and outlined — or, for `art:` ids, the
/// full-colour pixel art drawn as-is.
///
/// The `art:` namespace (v0.5.7, B1) routes an icon id at a bundled PNG in
/// `Resources/ClassArt` instead of a rasterised Iconify glyph: `art:soil-chalk`
/// loads `soil-chalk.png`. Handled here, at the one place every icon id passes
/// through, so the taxonomy tables could move to drawn art without touching a
/// single call site. The art ships its own colours and outline, so `color` and
/// `PixelOutline` do not apply to it.
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

    private var artStem: String? {
        iconID.hasPrefix("art:") ? String(iconID.dropFirst(4)) : nil
    }

    public var body: some View {
        let art = artStem.flatMap { PixelArtLoader.shared.image($0) }
        Group {
            // `.interpolation(.none)` on both real branches (0.6.3, item 2 —
            // AUDIT L28): FlagImage and LogoMark already set it, and these were
            // the only pixel surfaces left sampling linearly — which read as
            // blur, not smoothing, at LCD sizes.
            if let art {
                Image(uiImage: art)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if artStem == nil, let image = IconLoader.shared.image(iconID) {
                Image(uiImage: image)
                    .interpolation(.none)
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
        .modifier(PixelOutline(enabled: outlined && art == nil))
    }
}

/// Reproduces the web app's black icon outline.
///
/// `entryIconVisuals.tsx:41` stacks eight `drop-shadow` filters. SwiftUI's
/// `.shadow(radius: 0, x:, y:)` is the direct analogue and composes the same
/// way, so the eight offsets port across literally — no need to bake the
/// outline into the PNGs, which would have blocked runtime tinting.
/// The offsets run at a full point (0.6.x — they were 0.5): half-pixel
/// shadows anti-alias into a grey fuzz ring rather than a black line, which
/// was most of why the outlines read as weak.
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
                .shadow(color: .black, radius: 0, x: 1, y: 0)
                .shadow(color: .black, radius: 0, x: -1, y: 0)
                .shadow(color: .black, radius: 0, x: 0, y: 1)
                .shadow(color: .black, radius: 0, x: 0, y: -1)
                .shadow(color: .black, radius: 0, x: 1, y: 1)
                .shadow(color: .black, radius: 0, x: -1, y: 1)
                .shadow(color: .black, radius: 0, x: 1, y: -1)
                .shadow(color: .black, radius: 0, x: -1, y: -1)
        } else {
            content
        }
    }
}

#endif
