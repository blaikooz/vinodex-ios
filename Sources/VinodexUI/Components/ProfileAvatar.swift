#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import Observation
import UIKit

/// The user's own picture, chosen from their photo library.
///
/// Stored as a file rather than in `UserDefaults` like the display name is. A
/// name is a few dozen bytes and belongs in the defaults database; an image is
/// not, and `UserDefaults` is read into memory wholesale at launch — parking a
/// photo there taxes every read of every unrelated setting for the life of the
/// process.
///
/// Whatever the picker hands over is downscaled before it is written. The
/// picker returns the *original*: a modern phone camera produces a 12-megapixel
/// HEIC of several megabytes, and this is drawn at 96 points. 512px on the long
/// edge is still twice what a 3x display needs for that, and lands in tens of
/// kilobytes.
///
/// Unlike `ScreenStateStore` this **is** persistent — an avatar is a setting,
/// not session state, and having to re-pick it on every cold launch would make
/// the feature pointless.
@MainActor
@Observable
final class AvatarStore {
    static let shared = AvatarStore()

    private(set) var image: UIImage?

    /// Long-edge ceiling and JPEG quality for what gets written.
    private static let maxEdge: CGFloat = 512
    private static let quality: CGFloat = 0.85

    private let url: URL

    /// `directory` is injectable so this can be pointed somewhere disposable in
    /// a preview or a test rather than at the real Application Support folder.
    init(directory: URL? = nil) {
        let base = directory
            ?? (try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        url = base.appendingPathComponent("avatar.jpg")
        if let data = try? Data(contentsOf: url) {
            image = UIImage(data: data)
        }
    }

    var hasImage: Bool { image != nil }

    /// The stored bytes, for `SavedDataArchive.avatarJPEG`. Read from disk
    /// rather than re-encoded from `image`, so a backup round-trips the exact
    /// file rather than a second-generation JPEG.
    var storedJPEG: Data? { try? Data(contentsOf: url) }

    /// Writes an imported avatar and adopts it. Distinct from `adopt(_:)`,
    /// which downscales and re-encodes: these bytes already came out of
    /// `adopt`, so doing it again would cost a generation of quality for
    /// nothing.
    func restore(_ jpeg: Data) {
        guard let picked = UIImage(data: jpeg) else { return }
        try? jpeg.write(to: url, options: .atomic)
        image = picked
    }

    /// Re-reads the file after a restore wrote it behind this store's back —
    /// see `BookmarkStore.reload()`. Unlike the five defaults-backed stores,
    /// this one's state lives in Application Support, so `reload` reaches for
    /// the file rather than for `UserDefaults`.
    func reload() {
        image = (try? Data(contentsOf: url)).flatMap(UIImage.init(data:))
    }

    /// Takes the picker's payload. Silently does nothing if the data is not a
    /// decodable image — the picker can hand back a file it cannot render (an
    /// iCloud placeholder that failed to download), and the honest response to
    /// that is to leave the existing avatar alone rather than to blank it.
    func adopt(_ data: Data) {
        guard let picked = UIImage(data: data) else { return }
        let scaled = Self.downscaled(picked)
        guard let jpeg = scaled.jpegData(compressionQuality: Self.quality) else { return }
        try? jpeg.write(to: url, options: .atomic)
        image = scaled
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
        image = nil
    }

    /// Aspect-preserving, and a no-op for anything already small enough — a
    /// re-encode of an in-budget image costs quality for nothing.
    ///
    /// `format.scale = 1` because the renderer otherwise multiplies by the
    /// screen scale and produces a 1536px image from a 512pt request, which is
    /// the whole point of the exercise undone.
    private static func downscaled(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxEdge, longest > 0 else { return image }
        let factor = maxEdge / longest
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
#endif
