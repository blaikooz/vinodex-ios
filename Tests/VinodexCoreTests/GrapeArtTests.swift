import Testing
@testable import VinodexCore

/// The 0.5.4 grape icon system: one bunch sprite, recoloured by grape fields.
/// `GrapeArt` derives the key; the generated `grapeArt` manifest table maps
/// keys to shipped stems. These pin both halves — the derivation rules, and
/// that every key the dataset can produce actually resolves.
@Suite("Grape art")
struct GrapeArtTests {
    let db = WineDatabase.shared

    @Test("depth bands collapse five body classes to three")
    func depths() {
        #expect(GrapeArt.depth(bodyClass: "Light") == .light)
        #expect(GrapeArt.depth(bodyClass: "Light-Medium") == .light)
        #expect(GrapeArt.depth(bodyClass: "Medium") == .medium)
        #expect(GrapeArt.depth(bodyClass: "Medium-Full") == .full)
        #expect(GrapeArt.depth(bodyClass: "Full") == .full)
        // Unknown classes sit in the middle rather than failing loud — a new
        // body class must not blank every grape icon.
        #expect(GrapeArt.depth(bodyClass: "Unheard-Of") == .medium)
    }

    @Test("the gris family flecks pink, by name, diacritics folded")
    func pinkBlend() {
        #expect(GrapeArt.blend(name: "Pinot Gris", style: "Aromatic White", wineType: nil) == .pink)
        #expect(GrapeArt.blend(name: "Pinot Grigio", style: "Light-Bodied White", wineType: nil) == .pink)
        #expect(GrapeArt.blend(name: "Gewürztraminer", style: "Aromatic White", wineType: nil) == .pink)
        #expect(GrapeArt.blend(name: "Chardonnay", style: "Full-Bodied White", wineType: nil) == .none)
    }

    @Test("amber comes from the style, not the name")
    func amberBlend() {
        #expect(GrapeArt.blend(name: "Rkatsiteli", style: "Orange Wine", wineType: nil) == .amber)
        #expect(GrapeArt.blend(name: "Rkatsiteli", style: "White", wineType: "Amber") == .amber)
        #expect(GrapeArt.blend(name: "Orange Muscat", style: "Sweet White", wineType: nil) == .none,
                "orange in the *name* is a muscat, not a skin-contact style")
    }

    /// The 0.6.2 code-driven leaf palette: every tier has a colour of its
    /// own, and no two share one — a merge here would silently erase a tier's
    /// identity on every list in the app.
    @Test("every rarity tier has its own leaf colour")
    func leaves() {
        let hexes = RarityLabel.allCases.map { GrapeArt.leafHex(rarity: $0) }
        #expect(Set(hexes).count == RarityLabel.allCases.count, "leaf colours collide: \(hexes)")
        for hex in hexes {
            #expect(hex.hasPrefix("#") && hex.count == 7, "malformed leaf hex \(hex)")
        }
    }

    @Test("sweet whites carry gold berries, other whites green")
    func goldBerries() throws {
        let moscato = try #require(db.entry(named: "Moscato"))
        guard case .grape(let g) = moscato else {
            Issue.record("Moscato is not a grape entry")
            return
        }
        #expect(GrapeArt.key(for: g).hasPrefix("gold-"))

        let chardonnay = try #require(db.entry(named: "Chardonnay"))
        guard case .grape(let c) = chardonnay else {
            Issue.record("Chardonnay is not a grape entry")
            return
        }
        #expect(GrapeArt.key(for: c).hasPrefix("green-"))
    }

    @Test("every grape in the database resolves to shipped art")
    func everyGrapeResolves() {
        let grapes = db.entries(in: .grapes)
        #expect(!grapes.isEmpty)
        for entry in grapes {
            guard case .grape(let g) = entry else { continue }
            let key = GrapeArt.key(for: g)
            #expect(db.icons.grapeArtStem(forKey: key) != nil, "\(g.common.name) key \(key) has no art")
        }
    }

    /// The generator fills the whole 3x3x3 grid with fallbacks, so a key no
    /// current grape produces still resolves when a future one does. No leaf
    /// axis since 0.6.2 — the leaf is recoloured in code per rarity.
    @Test("the manifest grid is exhaustive over every derivable key")
    func gridIsExhaustive() {
        for color in ["green", "red", "gold"] {
            for depth in GrapeArt.Depth.allCases {
                for blend in GrapeArt.Blend.allCases {
                    let key = "\(color)-\(depth.rawValue)-\(blend.rawValue)"
                    #expect(db.icons.grapeArtStem(forKey: key) != nil, "no stem for \(key)")
                }
            }
        }
    }
}
