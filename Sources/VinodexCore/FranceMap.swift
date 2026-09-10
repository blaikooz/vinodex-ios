import Foundation

/// **The France region map** (0.9.55) — a test, not a shipping feature.
///
/// A second, richer view of one country: fourteen wine regions painted onto a
/// projected France, tapped by colour rather than by button. It does **not**
/// supersede the hand-drawn outline system — `CountryOutlineMap` and the
/// `mapPosition` dots are untouched, and this map is reached *through* that
/// outline rather than in place of it.
///
/// **Why the fourteen names here are not ids.** `southwest`, `rhone` and the
/// rest are art stems: names for painted areas, chosen by the renderer that
/// drew them. Four catalog regions live behind `southwest` alone. Letting a
/// stem become an id would quietly assert that the map's grouping is the
/// catalog's grouping, which it is not, so the two are joined only through
/// `regionIDs(for:)` and never conflated.
///
/// This type is the *pure* half — decoding, the colour table, the stem/id
/// join — so it can be tested on a machine with no simulator. The pixel
/// sampling that turns a tap into a stem lives in `FranceMapView`.
public struct FranceMap: Sendable {
    /// One painted region.
    public struct Region: Sendable, Identifiable, Equatable {
        /// The art stem — `bordeaux`, `southwest`. Never a catalog id.
        public let id: String
        /// The exact fill colour on the base map, as `(r, g, b)`.
        ///
        /// Exact, not approximate: the map is exported nearest-neighbour from
        /// flat fills, so every pixel of a region is bit-identical and a hit
        /// is an equality test rather than a distance one.
        public let fill: RGB
        /// Where to draw the marker, as a fraction of the base canvas. The
        /// renderer computes it as the pole of inaccessibility — the point
        /// furthest inside the shape — so it lands in the visual middle of a
        /// crescent rather than off it.
        public let button: (x: Double, y: Double)
        /// Where this region's *detail* drawing belongs on the base map, as
        /// fractions of the base canvas: `(x, y)` of its top-left and its
        /// `(w, h)`.
        ///
        /// The renderer publishes each detail map's projected bounds; run
        /// through the base projection they say exactly which patch of France
        /// that drawing is a close-up of. That is what lets the chosen region
        /// lift off the map in place, rather than the selection being legible
        /// only in a panel somewhere else on the screen.
        public let detailFrame: (x: Double, y: Double, w: Double, h: Double)

        public static func == (a: Region, b: Region) -> Bool { a.id == b.id }
    }

    public struct RGB: Hashable, Sendable {
        public let r: Int, g: Int, b: Int
        public init(r: Int, g: Int, b: Int) { self.r = r; self.g = g; self.b = b }

        /// Decodes `#RRGGBB`. Nil on anything else — a malformed manifest
        /// should surface as a missing region, not as a black one.
        public init?(hex: String) {
            var s = Substring(hex)
            if s.hasPrefix("#") { s = s.dropFirst() }
            guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
            self.init(r: (v >> 16) & 0xFF, g: (v >> 8) & 0xFF, b: v & 0xFF)
        }
    }

    public let regions: [Region]
    /// Colour to stem, for the hit test's first pass.
    public let byFill: [RGB: String]
    /// Stem to the catalog regions inside it, in catalog order.
    public let byStem: [String: [String]]
    /// The base map's logical size, before the 5x export.
    public let canvas: (w: Int, h: Int)

    /// Names for the fourteen areas. The stems are lowercase art names and
    /// the app writes region names in the catalog's own register, so the map
    /// carries a display name rather than up-casing a file stem — "rhone"
    /// would otherwise render as RHONE, missing the circumflex the catalog
    /// spells correctly two lines below it.
    public static let displayNames: [String: String] = [
        "alsace": "ALSACE", "beaujolais": "BEAUJOLAIS", "bordeaux": "BORDEAUX",
        "burgundy": "BURGUNDY", "champagne": "CHAMPAGNE", "corsica": "CORSICA",
        "jura": "JURA", "languedoc": "LANGUEDOC", "loire": "LOIRE",
        "provence": "PROVENCE", "rhone": "RHÔNE", "roussillon": "ROUSSILLON",
        "savoie": "SAVOIE", "southwest": "SOUTH WEST",
    ]

    public func displayName(_ stem: String) -> String {
        Self.displayNames[stem] ?? stem.uppercased()
    }

    /// The catalog regions behind a painted area. Empty means the map shows
    /// ground the catalog does not cover — worth reporting rather than
    /// rendering as a dead tap.
    public func regionIDs(for stem: String) -> [String] { byStem[stem] ?? [] }

    /// Builds from the two JSON files installed beside the art.
    ///
    /// Throwing rather than optional-returning: every failure here means the
    /// bundle is missing something it was built with, and a map that silently
    /// renders empty is the class of bug `PixelArtLoader`'s notes catalogue.
    public init(manifest: Data, index: Data) throws {
        let man = try JSONDecoder().decode(Manifest.self, from: manifest)
        let idx = try JSONDecoder().decode(Index.self, from: index)

        // The base canvas in projected units, so a region's projected bounds
        // can be expressed as fractions of it. `+ 2` is the renderer's own
        // two-pixel margin, quoted in the manifest's projection note.
        let pr = man.projection
        let cw = Double(man.base.canvas.first ?? 1)
        let ch = Double(man.base.canvas.last ?? 1)
        func frac(_ px: Double, _ py: Double) -> (Double, Double) {
            (((px - pr.origin[0]) * pr.scale + 2) / cw,
             ((py - pr.origin[1]) * pr.scale + 2) / ch)
        }

        var regions: [Region] = []
        var byFill: [RGB: String] = [:]
        for (stem, entry) in man.regions.sorted(by: { $0.key < $1.key }) {
            guard let rgb = RGB(hex: entry.fill), entry.button.count == 2 else { continue }
            var frame = (x: 0.0, y: 0.0, w: 0.0, h: 0.0)
            if let b = entry.detail?.bounds_projected, b.count == 2,
               b[0].count == 2, b[1].count == 2 {
                let (x0, y0) = frac(b[0][0], b[0][1])
                let (x1, y1) = frac(b[1][0], b[1][1])
                frame = (min(x0, x1), min(y0, y1), abs(x1 - x0), abs(y1 - y0))
            }
            regions.append(Region(id: stem, fill: rgb,
                                  button: (entry.button[0], entry.button[1]),
                                  detailFrame: frame))
            byFill[rgb] = stem
        }
        self.regions = regions
        self.byFill = byFill
        self.byStem = idx.byStem
        self.canvas = (man.base.canvas.first ?? 0, man.base.canvas.last ?? 0)
    }

    // The manifest carries more than this needs — the projection, the
    // départements behind each area, the marker-clearance proof. Decoding
    // only what is used keeps the app from depending on fields the renderer
    // is free to change.
    private struct Manifest: Decodable {
        struct Base: Decodable { let canvas: [Int] }
        struct Projection: Decodable { let origin: [Double]; let scale: Double }
        struct Detail: Decodable { let bounds_projected: [[Double]] }
        struct Entry: Decodable {
            let fill: String
            let button: [Double]
            let detail: Detail?
        }
        let base: Base
        let projection: Projection
        let regions: [String: Entry]
    }

    private struct Index: Decodable {
        let byStem: [String: [String]]
    }
}
