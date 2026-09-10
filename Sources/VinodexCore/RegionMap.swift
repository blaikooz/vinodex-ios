import Foundation

/// **A country's painted region map** (0.9.55) — a test, not a shipping feature.
///
/// A second, richer view of a country: its wine regions painted onto a
/// projected outline over a backdrop of sea and neighbours, tapped by colour
/// rather than by button. France and Italy have one; everywhere else keeps the
/// hand-drawn outline and its `mapPosition` dots, which this does **not**
/// supersede — `CountryOutlineMap` is untouched and still draws every country
/// including these two.
///
/// **Why the names here are not ids.** `southwest`, `rhone`, `tuscany` and the
/// rest are art stems: names for painted areas, chosen by the renderer that
/// drew them. Four catalog regions live behind `southwest` alone, and Italy's
/// Valpolicella and Etna sit inside `veneto` and `sicily` rather than beside
/// them. Letting a stem become an id would quietly assert that the map's
/// grouping is the catalog's grouping, which it is not, so the two are joined
/// only through `regionIDs(for:)` and never conflated.
///
/// This type is the *pure* half — decoding, the colour table, the stem/id
/// join — so it can be tested on a machine with no simulator. The pixel
/// sampling that turns a tap into a stem lives in `RegionMapView`.
public struct RegionMap: Sendable {
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
    /// Where the country itself sits on the canvas, as `(x, y, w, h)`
    /// fractions — the manifest calls it `subject_rect`.
    ///
    /// The canvas is mostly world: sea, shelf and the neighbours, reaching
    /// well past the border, with the country occupying about a third of it.
    /// **Scale the layers so this rect fills the width the country should
    /// have and let the backdrop bleed off under a clip** — aspect-fitting
    /// the whole canvas instead would shrink the country to a third of the
    /// screen and take every tap target down with it.
    public let subjectRect: (x: Double, y: Double, w: Double, h: Double)

    /// Names for the fourteen areas. The stems are lowercase art names and
    /// the app writes region names in the catalog's own register, so the map
    /// carries a display name rather than up-casing a file stem — "rhone"
    /// would otherwise render as RHONE, missing the circumflex the catalog
    /// spells correctly two lines below it.
    public static let displayNames: [String: String] = [
        // France
        "alsace": "ALSACE", "beaujolais": "BEAUJOLAIS", "bordeaux": "BORDEAUX",
        "burgundy": "BURGUNDY", "champagne": "CHAMPAGNE", "corsica": "CORSICA",
        "jura": "JURA", "languedoc": "LANGUEDOC", "loire": "LOIRE",
        "provence": "PROVENCE", "rhone": "RHÔNE", "roussillon": "ROUSSILLON",
        "savoie": "SAVOIE", "southwest": "SOUTH WEST",
        // Italy. Most would survive being up-cased; the three that would not
        // are why the table covers all of them rather than the exceptions —
        // a half-table invites the next name to be added to the wrong half.
        "abruzzo": "ABRUZZO", "altoadige": "ALTO ADIGE", "basilicata": "BASILICATA",
        "calabria": "CALABRIA", "campania": "CAMPANIA",
        "emiliaromagna": "EMILIA-ROMAGNA", "friuli": "FRIULI", "lazio": "LAZIO",
        "liguria": "LIGURIA", "lombardy": "LOMBARDY", "marche": "MARCHE",
        "molise": "MOLISE", "piedmont": "PIEDMONT", "puglia": "PUGLIA",
        "sardinia": "SARDINIA", "sicily": "SICILY", "trentino": "TRENTINO",
        "tuscany": "TUSCANY", "umbria": "UMBRIA", "valledaosta": "VALLE D'AOSTA",
        "veneto": "VENETO",
    ]

    /// The countries with a painted map, by the resource-directory name.
    ///
    /// A roster rather than a probe of the bundle: a country that is *meant*
    /// to have a map and does not should surface as a missing file, not as a
    /// country that quietly falls back to the outline. Adding a third is a
    /// render, an install, and a line here.
    public static let mapped: [String] = ["france", "italy"]

    /// The map key for a catalog country name, or nil where there is none.
    /// Matching is case- and accent-insensitive because the catalog spells
    /// countries the way a label does, not the way a filename does.
    public static func key(forCountry name: String) -> String? {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                  locale: nil)
        return mapped.first { $0 == folded }
    }

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
        let r = man.base.subject_rect
        self.subjectRect = r.count == 4 ? (r[0], r[1], r[2], r[3]) : (0, 0, 1, 1)
    }

    // The manifest carries more than this needs — the projection, the
    // départements behind each area, the marker-clearance proof. Decoding
    // only what is used keeps the app from depending on fields the renderer
    // is free to change.
    private struct Manifest: Decodable {
        struct Base: Decodable { let canvas: [Int]; let subject_rect: [Double] }
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
