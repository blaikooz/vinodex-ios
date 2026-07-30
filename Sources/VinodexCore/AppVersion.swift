import Foundation

/// The running build's version, for anywhere in the UI that states it.
///
/// The back plate carried a hardcoded `"v0.3.5"` string, which had been wrong
/// for several releases — a literal nobody remembers to edit is a literal that
/// silently lies, and the back plate is the one screen whose whole job is to
/// state what this thing is.
///
/// Reads `CFBundleShortVersionString` first so a real plist value always wins,
/// with `fallback` behind it. Keeping both means the constant below is the
/// *only* place to bump, and the moment the build pipeline does start stamping a
/// version, this starts reporting it without another change.
///
/// **xtool does generate a version, and it is a lie.** The comment here used to
/// say `xtool.yml` declares no version and nothing generates an Info.plist with
/// one, so the fallback was always what a build got. Untrue: xtool 1.17 writes
/// `CFBundleShortVersionString = 1.0.0` and `CFBundleVersion = 1` into the
/// bundle unconditionally, and the guard below only rejected the literal
/// `"1.0"`. So `current` returned `"1.0.0"` and the back plate read `v1.0.0` on
/// every build ever shipped — the identical silent lie the hardcoded `"v0.3.5"`
/// string was deleted for, arrived at from the opposite direction.
///
/// Hence `placeholders`. There is no `xtool.yml` key to override the stamped
/// value (checked against xtool 1.17.0), so recognising it is the only lever
/// available, and a version the build did not choose is worth less than the
/// constant a human did.
///
/// **This number is the iOS app's own.** `vinodex-web` used to mirror it — the
/// two apps were one repo shipping one product, and a build claiming a
/// different version from its sibling was worse than no version at all. The
/// repos split on 2026-07-29 and both halves of that stopped being true: they
/// release on different clocks (a Vercel push is live in a minute, an App Store
/// build waits on review), and the feature sets diverged on purpose — the web
/// has no paywall, no `tiers.json`, no haptics, and a whole splash/website
/// branch with no counterpart here.
///
/// The mirroring had in fact already failed: this constant sat at 0.4.1.5 while
/// the web's `appVersion.ts` claimed 0.4.1.7. So the numbers are separate now.
/// The web restarted at 0.1.0 and counts on its own; that is not this file's
/// business, and neither is this number the web's.
///
/// **Three components from 0.4.3 onward.** The numbers had been growing a joint
/// per release — 0.4.1 begat 0.4.1.5, then 0.4.1.7, 0.4.2.1, 0.4.2.1.1, and
/// three branches open at once each claimed a different fourth or fifth level
/// for the same work. A scheme where the next number is not obvious is a scheme
/// that gets one per branch, and none of those extra digits ever meant anything
/// a reader could name.
///
/// 0.4.3 is the three branches landing together, and it is also the last version
/// that has to be explained. From here: patch for fixes, minor for features,
/// nothing deeper. It is what `CFBundleShortVersionString` will accept when
/// signing eventually matters — Apple takes at most three integers, so the old
/// five-part strings could never have been stamped into a real bundle anyway.
public enum AppVersion {
    /// Bump with the batch. This is the single source of truth until the build
    /// stamps one into the bundle.
    static let fallback = "0.5.0"

    /// Versions no build deliberately chose.
    ///
    /// `1.0.0` and `1` are what xtool stamps when nothing declares a version;
    /// `1.0` is Xcode's own template default, kept because a future Xcode project
    /// would reintroduce it. A bundled value in this set means "the build tool
    /// filled the blank in", not "this is release 1.0.0".
    ///
    /// A denylist is a liability — the day the app genuinely ships 1.0.0 this
    /// file has to change or the release reports the fallback instead. That is
    /// the smaller of the two liabilities, it fails loudly in the test below
    /// rather than silently on the back plate, and there is a note in
    /// `KNOWN-ISSUES.md` pointing here.
    static let placeholders: Set<String> = ["1.0", "1.0.0", "1"]

    /// The version to report given whatever the bundle carries.
    ///
    /// Split out from `current` purely so it is reachable from a test:
    /// `Bundle.main` on Linux carries no Info.plist at all, so a test that goes
    /// through `current` can only ever exercise the nil path — which is exactly
    /// how the `1.0.0` bug survived having a test suite written about it.
    static func resolve(bundled: String?) -> String {
        guard let bundled else { return fallback }
        let trimmed = bundled.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !placeholders.contains(trimmed) else { return fallback }
        return trimmed
    }

    /// Bare version, no prefix — e.g. `0.4.3`.
    public static var current: String {
        resolve(bundled: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }

    /// Display form, e.g. `v0.4.3`.
    public static var display: String { "v" + current }
}
