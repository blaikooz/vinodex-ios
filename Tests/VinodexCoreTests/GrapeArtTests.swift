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

    @Test("the leaf marks rarity, the two lower tiers sharing green")
    func leaves() {
        #expect(GrapeArt.leaf(rarity: .common) == .common)
        #expect(GrapeArt.leaf(rarity: .uncommon) == .common)
        #expect(GrapeArt.leaf(rarity: .rare) == .rare)
        #expect(GrapeArt.leaf(rarity: .noble) == .noble)
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

    /// The generator fills the whole 2x3x3x3 grid with fallbacks, so a key
    /// no current grape produces still resolves when a future one does.
    @Test("the manifest grid is exhaustive over every derivable key")
    func gridIsExhaustive() {
        for color in ["green", "red"] {
            for depth in GrapeArt.Depth.allCases {
                for blend in GrapeArt.Blend.allCases {
                    for leaf in GrapeArt.Leaf.allCases {
                        let key = "\(color)-\(depth.rawValue)-\(blend.rawValue)-\(leaf.rawValue)"
                        #expect(db.icons.grapeArtStem(forKey: key) != nil, "no stem for \(key)")
                    }
                }
            }
        }
    }
}
