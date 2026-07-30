import Foundation

/// The running build's version, for anywhere in the UI that states it.
///
/// The back plate carried a hardcoded `"v0.3.5"` string, which had been wrong
/// for several releases — a literal nobody remembers to edit is a literal that
/// silently lies, and the back plate is the one screen whose whole job is to
/// state what this thing is.
///
/// Reads `CFBundleShortVersionString` first so a real plist value always wins;
/// `fallback` is what an xtool build actually gets today, since `xtool.yml`
/// declares no version and nothing generates an Info.plist with one. Keeping
/// both means the constant below is the *only* place to bump, and the moment
/// the build pipeline does start stamping a version, this starts reporting it
/// without another change.
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
public enum AppVersion {
    /// Bump with the batch. This is the single source of truth until the build
    /// stamps one into the bundle.
    static let fallback = "0.4.2.1.2"

    /// Bare version, no prefix — e.g. `0.4.2.1.2`.
    public static var current: String {
        let bundled = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let bundled, !bundled.isEmpty, bundled != "1.0" else { return fallback }
        return bundled
    }

    /// Display form, e.g. `v0.4.2.1.2`.
    public static var display: String { "v" + current }
}
