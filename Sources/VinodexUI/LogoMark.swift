#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

// MARK: - LogoMark

// The wordmark.

/// The pixel-V wordmark, bundled from the web app's logo.
public struct LogoMark: View {
    public init() {}

    public var body: some View {
        if let url = DexResources.url(named: "vinodex-logo", ext: "png", subdirectory: "Logo"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Text("V")
                .font(DexFont.retro(16))
                .foregroundStyle(.white)
        }
    }
}

#endif
