import Foundation

/// **The wine countries, as an index over the whole sphere** (0.9.55).
///
/// The same contract the flat region maps use, one tier up: an equirectangular
/// raster where each cell carries a country's id rather than a colour, so a
/// tap resolves to an integer no colour pipeline can perturb. 2048x1024 for
/// thirty countries, and `0` is everywhere else — ocean, ice, and the hundred
/// and sixty countries that do not make wine.
///
/// This type is the pure half — the table and the lookup — so it tests on a
/// machine with no simulator. Turning a finger on a sphere into the lat/lon
/// this wants is `GlobeModel`'s job, and it does it with SceneKit's own
/// hit test rather than a second projection of its own.
public struct GlobeIndex: Sendable {
    public struct Country: Sendable, Identifiable, Equatable {
        /// The index byte this country carries in the raster.
        public let id: Int
        /// The catalog's spelling — "New Zealand", "United States of America".
        public let admin: String
        /// What the HUD shows, already up-cased by the renderer.
        public let label: String
        /// How many regions its painted map holds, or 0 where there is none.
        /// This is what decides whether a second tap can go anywhere.
        public let mapped: Int

        /// Whether tapping again opens a region map. Seven countries qualify;
        /// the other twenty-three are named on the globe and stop there.
        public var isMapped: Bool { mapped > 0 }
    }

    public let countries: [Country]
    private let byID: [Int: Country]

    public init(meta: Data) throws {
        let decoded = try JSONDecoder().decode(Meta.self, from: meta)
        let list = decoded.countries.map {
            Country(id: $0.idx, admin: $0.admin, label: $0.label, mapped: $0.mapped)
        }
        self.countries = list.sorted { $0.id < $1.id }
        self.byID = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    public func country(id: Int) -> Country? { byID[id] }

    /// Where a coordinate falls in the raster, as `(x, y)` cells.
    ///
    /// Plain equirectangular — the globe texture is wrapped that way, so this
    /// is the mapping SceneKit itself already used to put the picture on the
    /// sphere rather than a second opinion about where things are.
    public static func cell(lon: Double, lat: Double, width: Int, height: Int) -> (x: Int, y: Int) {
        let u = (lon + 180) / 360
        let v = (90 - lat) / 180
        let x = min(width - 1, max(0, Int(u * Double(width))))
        let y = min(height - 1, max(0, Int(v * Double(height))))
        return (x, y)
    }

    private struct Meta: Decodable {
        struct Entry: Decodable {
            let idx: Int
            let admin: String
            let label: String
            let mapped: Int
        }
        let countries: [Entry]
    }
}
