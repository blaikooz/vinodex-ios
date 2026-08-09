import Foundation

/// One shipped release, as the device describes itself (0.7.3, F3).
///
/// Decoded from the generated `firmware.json`, which comes from
/// `shared/data/firmware.ts`. The generator gates the shape — three-integer
/// versions, newest-first ordering, ASCII, an uppercase headline of 24
/// characters or fewer, at least one note — so nothing here has to re-validate
/// it at runtime on a device where failing is not useful.
public struct FirmwareRelease: Codable, Sendable, Hashable, Identifiable {
    /// Three dot-separated integers, the scheme since 0.4.3.
    public let version: String
    /// ISO `YYYY-MM-DD`.
    public let date: String
    /// The panel's per-release heading. Uppercase ASCII, short enough for the
    /// retro face.
    public let headline: String
    /// One line each, in reading order.
    public let notes: [String]

    /// The version, which is unique by construction — the generator rejects a
    /// duplicate outright.
    public var id: String { version }

    public init(version: String, date: String, headline: String, notes: [String]) {
        self.version = version
        self.date = date
        self.headline = headline
        self.notes = notes
    }
}

/// The firmware version and changelog, read once from the bundle (0.7.3, F3).
///
/// **This is the app's version source of truth.** Before 0.7.3 the authored
/// number was `AppVersion.fallback`, a Swift literal, and the changelog was the
/// forty lines of doc comment sitting above it. F3 asks for one data source that
/// both the boot POST (A1) and the FIRMWARE HISTORY panel (A3) read, and this
/// project keeps its data in `shared/`, so the number moved there and this type
/// is what reads it back.
///
/// **What did *not* move is `AppVersion`'s job.** It still owns the resolution
/// rule — a version the bundle genuinely declares beats the authored one, and
/// xtool's stamped `1.0.0` placeholder beats neither — and it is still the only
/// thing the UI asks for a version string. It simply stopped *restating* the
/// number: `AppVersion.fallback` reads `FirmwareCatalog.shared.version` now. One
/// source, one resolver, and bumping a release is editing the head of
/// `shared/data/firmware.ts` and running `npm run generate`.
///
/// **Deliberately independent of `WineDatabase`.** Both decode from
/// `Bundle.module`, and it would have been fewer lines to hang this off the
/// database singleton — but the boot screen states a version while the catalog
/// is still decoding on a background thread, and a catalog that fails to load is
/// exactly when you most want the device to still be able to say what it is.
/// The two failures stay unrelated.
public struct FirmwareCatalog: Codable, Sendable {
    /// What this build reports. The generator guarantees it is the head of
    /// `releases`.
    public let version: String
    /// Newest first.
    public let releases: [FirmwareRelease]

    public init(version: String, releases: [FirmwareRelease]) {
        self.version = version
        self.releases = releases
    }

    /// The bundled catalog, decoded once.
    public static let shared: FirmwareCatalog = load()

    /// What a build reports when `firmware.json` is missing or will not decode.
    ///
    /// **Not a fallback version — a distress signal.** The whole argument of
    /// `AppVersion.swift` is that a number nobody chose is worth less than
    /// nothing, because it lies quietly; a plausible-looking constant here would
    /// be that same lie with a new hiding place. `0.0.0` is a version no batch
    /// can ever legitimately produce, it satisfies the three-component rule so
    /// the shape tests still exercise real logic, and
    /// `FirmwareTests.catalogLoads` fails on it — so a broken pipeline stops the
    /// Linux gate rather than shipping.
    public static let unavailable = FirmwareCatalog(version: "0.0.0", releases: [])

    /// The release matching a version string, if the changelog knows it.
    public func release(_ version: String) -> FirmwareRelease? {
        releases.first { $0.version == version }
    }

    /// The current build's own release notes — what the boot screen and the top
    /// of the history panel describe.
    public var current: FirmwareRelease? { release(version) }

    private static func load() -> FirmwareCatalog {
        guard
            let url = Bundle.module.url(forResource: "firmware", withExtension: "json", subdirectory: "Resources")
                ?? Bundle.module.url(forResource: "firmware", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(FirmwareCatalog.self, from: data)
        else {
            return unavailable
        }
        return decoded
    }
}
