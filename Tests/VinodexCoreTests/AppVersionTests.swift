import Testing
import Foundation
@testable import VinodexCore

/// The version string, and the shape the back plate depends on.
///
/// `AppVersion` had no coverage at all — which is how `fallback` sat at 0.4.1.5
/// while the sibling web app claimed 0.4.1.7 and nothing said so. The numbers
/// are deliberately separate now (see the note in `AppVersion.swift`), so what
/// is worth pinning is no longer "does it match the web" but "is it a version
/// at all, and does every screen get the same one".
///
/// Runs on Linux: `VinodexCore` is Foundation-only, and `Bundle.main` there
/// carries no `CFBundleShortVersionString`, so `current` exercises the
/// `fallback` path — which is the path every xtool build takes today anyway.
@Suite("App version")
struct AppVersionTests {
    /// Dot-separated numeric components, nothing else. The build strings here
    /// run to four and five parts, so the count is deliberately not pinned —
    /// but a stray `v`, a trailing dot or a "-beta" suffix would all reach the
    /// engraved nameplate verbatim, and none of them belong there.
    @Test("the version is dot-separated numbers")
    func versionShape() {
        let parts = AppVersion.fallback.split(separator: ".", omittingEmptySubsequences: false)
        #expect(parts.count >= 2, "\(AppVersion.fallback) is not a version")
        for part in parts {
            #expect(!part.isEmpty, "empty component in \(AppVersion.fallback)")
            #expect(part.allSatisfy(\.isNumber), "non-numeric component '\(part)' in \(AppVersion.fallback)")
        }
    }

    /// `current` prefers a plist value and falls back to the constant. There is
    /// no plist on Linux and none in an xtool build either, so the two must
    /// agree — if they ever stop, the back plate and the constant have drifted
    /// and only one of them is visible to a reader.
    @Test("current resolves to the fallback when nothing is bundled")
    func currentUsesFallback() {
        let bundled = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        if bundled == nil || bundled?.isEmpty == true || bundled == "1.0" {
            #expect(AppVersion.current == AppVersion.fallback)
        } else {
            #expect(AppVersion.current == bundled)
        }
    }

    /// The one thing the back plate renders. It draws `display` raw into a
    /// fixed-width engraved plate, so the `v` has to come from here and nowhere
    /// else — a second one added at the call site would read `vv0.4.2.1.2`.
    @Test("display is the version with a single leading v")
    func displayForm() {
        #expect(AppVersion.display == "v" + AppVersion.current)
        #expect(AppVersion.display.hasPrefix("v"))
        #expect(!AppVersion.display.hasPrefix("vv"))
    }

    @Test("nothing carries stray whitespace")
    func noWhitespace() {
        #expect(!AppVersion.fallback.contains(where: \.isWhitespace))
        #expect(!AppVersion.display.contains(where: \.isWhitespace))
    }
}
