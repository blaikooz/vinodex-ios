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
        /// The byte this region carries in `<country>-index.png`, which is
        /// what the hit test reads. Per-country by construction: ids run 1..N
        /// within a country and mean nothing across two.
        public let index: Int
        /// The region's colour on the base map.
        ///
        /// **Presentation only.** Nothing resolves by it. The fills repeat
        /// across countries on purpose — 85 regions share 35 colours, because
        /// two regions that never appear on screen together are free to look
        /// alike — so a global colour table would collapse them and
        /// mis-resolve roughly every other tap, silently. The palette can now
        /// change without re-slicing anything.
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
        /// The renderer publishes each detail drawing's `source_bbox` in
        /// canvas cells — exactly which patch of the country it is a close-up
        /// of. That is what lets the chosen region lift off the map in place,
        /// rather than the selection being legible only in a panel elsewhere
        /// on the screen.
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
    /// Index byte to stem — what the hit test resolves through.
    public let byIndex: [Int: String]
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

    /// Turns a canvas cell back into a real coordinate, for the HUD readout.
    ///
    /// **The manifest's own projection, never a reimplementation** — contract
    /// 2 of the drop's audit. The renderer publishes `origin`, `scale` and
    /// the longitude `x_factor` precisely so the app does not carry a second
    /// set of constants that can drift from the first without anything
    /// saying so. This inverts the note the manifest itself prints:
    /// `canvas_x = (lon*x_factor - origin[0])*scale + 2`.
    public func coordinate(atCanvas x: Double, _ y: Double) -> (lon: Double, lat: Double) {
        let lon = ((x - 2) / projScale + projOrigin.0) / projXFactor
        let lat = -((y - 2) / projScale + projOrigin.1)
        return (lon, lat)
    }

    /// The same projection the other way — a coordinate to a canvas cell.
    ///
    /// The globe needs this one: to lay a country's painted regions onto the
    /// sphere, each vertex of the patch knows its own longitude and latitude
    /// and has to find the texel that belongs there. It is the manifest's
    /// printed formula applied forwards, so the two directions cannot drift
    /// apart the way a second hand-written constant would.
    public func canvas(atLon lon: Double, lat: Double) -> (x: Double, y: Double) {
        let x = (lon * projXFactor - projOrigin.0) * projScale + 2
        let y = (-lat - projOrigin.1) * projScale + 2
        return (x, y)
    }

    /// The whole canvas's extent in degrees — sea, shelf and neighbours
    /// included, not just the country. The globe draws the backdrop over this,
    /// which is what keeps its own coarse country fill from showing around a
    /// finer painted coastline.
    public var canvasBounds: (west: Double, east: Double, south: Double, north: Double) {
        let topLeft = coordinate(atCanvas: 0, 0)
        let bottomRight = coordinate(atCanvas: Double(canvas.w), Double(canvas.h))
        return (west: topLeft.lon, east: bottomRight.lon,
                south: bottomRight.lat, north: topLeft.lat)
    }

    /// The country's own extent in degrees, from `subject_rect` — the corners
    /// of the painted country rather than of the whole canvas, which is
    /// mostly sea and neighbours.
    public var subjectBounds: (west: Double, east: Double, south: Double, north: Double) {
        let x0 = subjectRect.x * Double(canvas.w), x1 = (subjectRect.x + subjectRect.w) * Double(canvas.w)
        let y0 = subjectRect.y * Double(canvas.h), y1 = (subjectRect.y + subjectRect.h) * Double(canvas.h)
        let topLeft = coordinate(atCanvas: x0, y0)
        let bottomRight = coordinate(atCanvas: x1, y1)
        return (west: topLeft.lon, east: bottomRight.lon,
                south: bottomRight.lat, north: topLeft.lat)
    }

    private let projOrigin: (Double, Double)
    private let projScale: Double
    private let projXFactor: Double

    /// Names for all 85 painted areas across the seven countries.
    ///
    /// The stems are lowercase art names and the app writes region names in
    /// the catalog's own register, so the map carries a display name rather
    /// than up-casing a file stem — "rhone" would otherwise render as RHONE,
    /// "dao" as DAO and "hawkesbay" as HAWKESBAY, each missing what the
    /// catalog spells correctly two lines below it. The table covers every
    /// stem rather than only the awkward ones: a half-table invites the next
    /// name to be added to the wrong half.
    public static let displayNames: [String: String] = [
        "abruzzo": "ABRUZZO",
        "aconcagua": "ACONCAGUA",
        "alentejo": "ALENTEJO",
        "algarve": "ALGARVE",
        "alsace": "ALSACE",
        "altoadige": "ALTO ADIGE",
        "andalucia": "ANDALUCIA",
        "aragon": "ARAGON",
        "auckland": "AUCKLAND",
        "bairrada": "BAIRRADA",
        "baleares": "BALEARES",
        "basilicata": "BASILICATA",
        "basque": "BASQUE",
        "beaujolais": "BEAUJOLAIS",
        "beirainterior": "BEIRA INTERIOR",
        "bierzo": "BIERZO",
        "biobio": "BÍO BÍO",
        "bordeaux": "BORDEAUX",
        "burgundy": "BURGUNDY",
        "calabria": "CALABRIA",
        "campania": "CAMPANIA",
        "canterbury": "CANTERBURY",
        "catalonia": "CATALONIA",
        "catamarca": "CATAMARCA",
        "centralotago": "CENTRAL OTAGO",
        "champagne": "CHAMPAGNE",
        "coquimbo": "COQUIMBO",
        "cordoba": "CORDOBA",
        "corsica": "CORSICA",
        "dao": "DÃO",
        "douro": "DOURO",
        "emiliaromagna": "EMILIA-ROMAGNA",
        "extremadura": "EXTREMADURA",
        "friuli": "FRIULI",
        "galicia": "GALICIA",
        "gisborne": "GISBORNE",
        "hawkesbay": "HAWKE'S BAY",
        "itata": "ITATA",
        "jerez": "JEREZ",
        "jura": "JURA",
        "lamancha": "LA MANCHA",
        "languedoc": "LANGUEDOC",
        "lazio": "LAZIO",
        "levante": "LEVANTE",
        "liguria": "LIGURIA",
        "lisboa": "LISBOA",
        "loire": "LOIRE",
        "lombardy": "LOMBARDY",
        "madrid": "MADRID",
        "maipo": "MAIPO",
        "malleco": "MALLECO",
        "marche": "MARCHE",
        "marlborough": "MARLBOROUGH",
        "maule": "MAULE",
        "mendoza": "MENDOZA",
        "molise": "MOLISE",
        "navarra": "NAVARRA",
        "nelson": "NELSON",
        "northland": "NORTHLAND",
        "patagonia": "PATAGONIA",
        "piedmont": "PIEDMONT",
        "provence": "PROVENCE",
        "puglia": "PUGLIA",
        "rapel": "RAPEL",
        "rhone": "RHÔNE",
        "riberadelduero": "RIBERA DEL DUERO",
        "rioja": "RIOJA",
        "roussillon": "ROUSSILLON",
        "ruedatoro": "RUEDA & TORO",
        "salta": "SALTA",
        "sanjuan": "SAN JUAN",
        "sardinia": "SARDINIA",
        "savoie": "SAVOIE",
        "setubal": "SETUBAL",
        "sicily": "SICILY",
        "southwest": "SOUTH WEST",
        "tejo": "TEJO",
        "trentino": "TRENTINO",
        "tuscany": "TUSCANY",
        "umbria": "UMBRIA",
        "valledaosta": "VALLE D'AOSTA",
        "veneto": "VENETO",
        "vinhoverde": "VINHO VERDE",
        "waikatobop": "WAIKATO & BOP",
        "wairarapa": "WAIRARAPA",
    ]

    /// The countries with a painted map, by the resource-directory name.
    ///
    /// A roster rather than a probe of the bundle: a country that is *meant*
    /// to have a map and does not should surface as a missing file, not as a
    /// country that quietly falls back to the outline. Adding a third is a
    /// render, an install, and a line here.
    public static let mapped: [String] = [
        "france", "italy", "spain", "portugal", "argentina", "chile", "newzealand",
    ]

    /// The map key for a catalog country name, or nil where there is none.
    /// Matching folds accents, case and spaces, because the catalog spells
    /// countries the way a label does and the resource directory the way a
    /// filename does — "New Zealand" has to find `newzealand`.
    public static func key(forCountry name: String) -> String? {
        let folded = name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: " ", with: "")
        return mapped.first { $0 == folded }
    }

    public func displayName(_ stem: String) -> String {
        Self.displayNames[stem] ?? stem.uppercased()
    }

    /// The catalog regions behind a painted area. Empty means the map shows
    /// ground the catalog does not cover — worth reporting rather than
    /// rendering as a dead tap.
    public func regionIDs(for stem: String) -> [String] { byStem[stem] ?? [] }

    /// **Which of a painted region's entries IS the region**, rather than
    /// something inside it.
    ///
    /// A painted area can carry several catalog entries: Veneto carries Veneto
    /// *and* Valpolicella, Sicily carries Sicily *and* Etna. Listing them
    /// together answers a question the tap did not ask — you pointed at Veneto.
    ///
    /// Exact name first, then one that *contains* the region's name. The
    /// contains step is not decoration: `southwest` displays as "SOUTH WEST"
    /// and its entry is named "South West France", so exact-match fails and a
    /// first-mapped fallback picks Gaillac — an appellation inside it, which is
    /// precisely the bug this prevents. Eleven of the eighty-five painted
    /// regions have no entry named after them at all; there the first mapped
    /// entry is the honest answer.
    ///
    /// Takes the names rather than the entries so it can be tested without a
    /// database: the caller resolves ids, this decides which one is the region.
    public func primaryEntryID(for stem: String, names: [(id: String, name: String)]) -> String? {
        func fold(_ value: String) -> String {
            value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        }
        let want = fold(displayName(stem))
        return names.first { fold($0.name) == want }?.id
            ?? names.first { fold($0.name).contains(want) }?.id
            ?? names.first?.id
    }

    /// Builds from the two JSON files installed beside the art.
    ///
    /// Throwing rather than optional-returning: every failure here means the
    /// bundle is missing something it was built with, and a map that silently
    /// renders empty is the class of bug `PixelArtLoader`'s notes catalogue.
    public init(manifest: Data, index: Data) throws {
        let man = try JSONDecoder().decode(Manifest.self, from: manifest)
        let idx = try JSONDecoder().decode(Index.self, from: index)

        let cw = Double(man.base.canvas.first ?? 1)
        let ch = Double(man.base.canvas.last ?? 1)

        var regions: [Region] = []
        var byIndex: [Int: String] = [:]
        for (stem, entry) in man.regions.sorted(by: { $0.key < $1.key }) {
            guard let rgb = RGB(hex: entry.fill), entry.button.count == 2 else { continue }
            // Straight from the manifest's `source_bbox`, which is already
            // in canvas cells — contract 3 of the drop's audit: compute
            // nothing the manifest computed. The previous cut re-derived this
            // through the projection, which is exactly the drift that
            // contract exists to stop.
            var frame = (x: 0.0, y: 0.0, w: 0.0, h: 0.0)
            if let b = entry.detail?.source_bbox, b.count == 4 {
                frame = (Double(b[0]) / cw, Double(b[1]) / ch,
                         Double(b[2] - b[0]) / cw, Double(b[3] - b[1]) / ch)
            }
            regions.append(Region(id: stem, index: entry.id, fill: rgb,
                                  button: (entry.button[0], entry.button[1]),
                                  detailFrame: frame))
            byIndex[entry.id] = stem
        }
        self.regions = regions
        self.byIndex = byIndex
        self.byStem = idx.byStem
        // `?? 1`, matching `cw`/`ch` above. At zero an empty `canvas` array
        // divides through `patchGeometry`'s UVs and yields a NaN mesh rather
        // than a load that fails — a silently garbage map instead of no map.
        self.canvas = (man.base.canvas.first ?? 1, man.base.canvas.last ?? 1)
        let pr = man.projection
        self.projOrigin = (pr.origin.first ?? 0, pr.origin.last ?? 0)
        self.projScale = pr.scale
        self.projXFactor = pr.x_factor
        let r = man.base.subject_rect
        self.subjectRect = r.count == 4 ? (r[0], r[1], r[2], r[3]) : (0, 0, 1, 1)
    }

    // The manifest carries more than this needs — the projection, the
    // départements behind each area, the marker-clearance proof. Decoding
    // only what is used keeps the app from depending on fields the renderer
    // is free to change.
    private struct Manifest: Decodable {
        struct Base: Decodable { let canvas: [Int]; let subject_rect: [Double] }
        struct Detail: Decodable { let source_bbox: [Int] }
        struct Entry: Decodable {
            let id: Int
            let fill: String
            let button: [Double]
            let detail: Detail?
        }
        struct Projection: Decodable {
            let origin: [Double]
            let scale: Double
            let x_factor: Double
        }
        let base: Base
        let projection: Projection
        let regions: [String: Entry]
    }

    private struct Index: Decodable {
        let byStem: [String: [String]]
    }
}
