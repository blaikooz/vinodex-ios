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
            // Hoisted out of `#expect`: `allSatisfy` is `rethrows`, and the macro
            // expands a `rethrows` call into something the compiler treats as
            // throwing, so inline it demands a `try` that has nothing to catch.
            let allNumeric = part.allSatisfy(\.isNumber)
            #expect(allNumeric, "non-numeric component '\(part)' in \(AppVersion.fallback)")
        }
    }

    /// Nothing in the bundle — Linux, and any build with no Info.plist — reports
    /// the constant.
    @Test("nothing bundled resolves to the fallback")
    func nothingBundled() {
        #expect(AppVersion.resolve(bundled: nil) == AppVersion.fallback)
        #expect(AppVersion.resolve(bundled: "") == AppVersion.fallback)
        #expect(AppVersion.resolve(bundled: "   ") == AppVersion.fallback)
    }

    /// **The regression this file exists for.** xtool 1.17 stamps
    /// `CFBundleShortVersionString = 1.0.0`, the guard only rejected `"1.0"`, and
    /// so every build reported `v1.0.0` on the back plate no matter what anyone
    /// set. The previous version of this test asserted the resolution logic
    /// against a copy of itself — including the same `== "1.0"` — so it agreed
    /// with the bug and passed.
    ///
    /// It also could not have caught it: `Bundle.main` on Linux carries no
    /// Info.plist, so the branch that mattered was never reached. Hence
    /// `resolve(bundled:)` taking the value as an argument.
    @Test("xtool's stamped placeholder does not win over the fallback")
    func placeholdersLose() {
        for placeholder in ["1.0", "1.0.0", "1"] {
            #expect(
                AppVersion.resolve(bundled: placeholder) == AppVersion.fallback,
                "\(placeholder) is a build-tool default and must not reach the back plate"
            )
        }
    }

    /// A version the build genuinely declares still wins — that is the whole
    /// point of reading the plist first, and it is what makes this file a no-op
    /// the day a signing pipeline starts stamping a real number.
    @Test("a real bundled version wins over the fallback")
    func realBundledWins() {
        #expect(AppVersion.resolve(bundled: "2.1.0") == "2.1.0")
        #expect(AppVersion.resolve(bundled: "0.4.2.1.2") == "0.4.2.1.2")
        // Trimmed, because a plist edited by hand picks up whitespace and the
        // back plate draws whatever it is given into a fixed-width plate.
        #expect(AppVersion.resolve(bundled: " 2.1.0\n") == "2.1.0")
    }

    /// `current` goes through `resolve`, so the property the UI actually reads is
    /// covered by everything above rather than only by the nil path Linux gives.
    @Test("current agrees with resolve on the real bundle")
    func currentMatchesResolve() {
        let bundled = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        #expect(AppVersion.current == AppVersion.resolve(bundled: bundled))
    }

    /// The tag pushed for a release is `v` + this constant, and nothing checks
    /// that mechanically — so at minimum the constant must be the thing a tag
    /// name can be built from.
    @Test("the fallback is usable as a tag name")
    func taggable() {
        let tag = "v" + AppVersion.fallback
        let bodyIsVersionish = tag.dropFirst().allSatisfy { $0.isNumber || $0 == "." }
        #expect(tag.hasPrefix("v"))
        #expect(!tag.contains(" "))
        #expect(bodyIsVersionish)
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
        // Hoisted for the same reason as `allSatisfy` above — `contains(where:)`
        // is `rethrows` and cannot sit inside `#expect` without a `try`.
        let fallbackHasSpace = AppVersion.fallback.contains(where: \.isWhitespace)
        let displayHasSpace = AppVersion.display.contains(where: \.isWhitespace)
        #expect(!fallbackHasSpace)
        #expect(!displayHasSpace)
    }
}
