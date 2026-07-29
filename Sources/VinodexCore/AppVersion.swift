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
public enum AppVersion {
    /// Bump with the batch. This is the single source of truth until the build
    /// stamps one into the bundle.
    static let fallback = "0.4.1.5"

    /// Bare version, no prefix — e.g. `0.4.1.5`.
    public static var current: String {
        let bundled = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let bundled, !bundled.isEmpty, bundled != "1.0" else { return fallback }
        return bundled
    }

    /// Display form, e.g. `v0.4.1.5`.
    public static var display: String { "v" + current }
}
