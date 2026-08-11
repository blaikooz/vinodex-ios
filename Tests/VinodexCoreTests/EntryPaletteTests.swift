import Testing
import Foundation
@testable import VinodexCore

/// AUDIT **M29**: these rules used to live in `VinodexUI`, which compiles to
/// nothing off-device and is reachable by no check this project runs — so a
/// twelve-branch keyword ladder over twenty-four literal spellings, and the
/// chip-table lookup behind every tile in the app, had zero coverage between
/// them. Moving them to Core was the item; this file is the reason it was worth
/// doing.
@Suite("Entry palette")
struct EntryPaletteTests {
    let db = WineDatabase.shared

    // MARK: - The style-tone ladder

    /// The ladder folds case, diacritics and the -Body/-Bodied spelling drift
    /// the authored data actually contains.
    @Test("the ladder folds the spellings the data really uses")
    func ladderFoldsSpellings() {
        for spelling in ["Full-Body Red", "full body red", "Full-Bodied Red", "FULL BODIED RED"] {
            #expect(EntryPalette.styleToneKey(for: spelling) == "full-bodied red", "\(spelling)")
        }
        // Both spellings of the same colour resolve to the accented key, which
        // is how `palette.json` spells it. De-accenting the key would break the
        // lookup while still compiling.
        #expect(EntryPalette.styleToneKey(for: "Rosé") == "rosé")
        #expect(EntryPalette.styleToneKey(for: "pink") == "rosé")
        #expect(EntryPalette.styleToneKey(for: "") == nil)
        #expect(EntryPalette.styleToneKey(for: "Sparkling Red") == nil)
    }

    /// The drift guard, and the whole argument for this rule living in Core: the
    /// ladder is hand-written and `styleTones` is generated, so nothing but a
    /// test can notice them parting company.
    @Test("every key the ladder can emit exists in the generated table")
    func ladderKeysExist() {
        for key in EntryPalette.styleToneKeys {
            #expect(db.palette.styleTones[key] != nil, "palette.json has no styleTone \"\(key)\"")
        }
    }

    /// The other direction: a generator that starts emitting a new style
    /// spelling would silently drop every grape wearing it onto the keyword
    /// fallback. `Sparkling Red` and `Madeira` (0.8.9x) are the authored styles
    /// that legitimately fall through today — they are the reason it exists.
    @Test("every authored grape style resolves, or is the known exception")
    func authoredStylesResolve() {
        for entry in db.entries {
            guard case .grape(let g) = entry else { continue }
            let style = g.grapeStyle.isEmpty ? (g.wineType ?? "") : g.grapeStyle
            #expect(
                EntryPalette.styleToneKey(for: style) != nil
                    || ["Sparkling Red", "Madeira"].contains(style),
                "\(g.common.name): style \"\(style)\" matches no tone key"
            )
        }
    }

    // MARK: - The fallback ladder

    @Test("the fallback ladder reads colour first, then body")
    func fallbackLadder() {
        #expect(EntryPalette.grapeWellFallbackHex(style: "Sparkling Red", body: "Medium") == "#8b0000")
        #expect(EntryPalette.grapeWellFallbackHex(style: "Sparkling Red", body: "Light") == "#dc143c")
        #expect(EntryPalette.grapeWellFallbackHex(style: "Bold Red", body: "Full") == "#4a0e0e")
        #expect(EntryPalette.grapeWellFallbackHex(style: "Aromatic", body: "Light") == "#fafad2")
        #expect(EntryPalette.grapeWellFallbackHex(style: "Aromatic", body: "Full") == "#b8860b")
        #expect(EntryPalette.grapeWellFallbackHex(style: "Rosé", body: "Medium") == "#db7093")
        #expect(EntryPalette.grapeWellFallbackHex(style: "Sweet", body: "Medium") == "#cd853f")
        #expect(EntryPalette.grapeWellFallbackHex(style: "", body: "Full") == "#78716c")
        #expect(EntryPalette.grapeWellFallbackHex(style: "Unheard-Of", body: "Full") == "#78716c")
    }

    /// Every literal the ladder can return is lowercase `#rrggbb`. Not cosmetic:
    /// the ladder's uppercase `#DC143C` and the tone table's `#dc143c` are the
    /// same colour, so a consumer comparing strings would have reported the two
    /// paths as disagreeing when they agree exactly.
    @Test("the ladder returns comparable lowercase hex")
    func ladderHexIsNormalised() {
        let colours = ["Sparkling Red", "Bold Red", "Aromatic", "Rosé", "Sweet", "", "Unheard-Of"]
            .flatMap { style in
                ["Light", "Medium", "Full"].map { EntryPalette.grapeWellFallbackHex(style: style, body: $0) }
            }
        for hex in Set(colours) {
            #expect(hex.count == 7 && hex.hasPrefix("#"), "\(hex)")
            #expect(hex == hex.lowercased(), "\(hex) is not lowercase")
            #expect(UInt32(hex.dropFirst(), radix: 16) != nil, "\(hex) is not hex")
        }
    }

    // MARK: - The two halves, wired together

    /// The one assertion that proves the order. A tone match must beat the
    /// keyword guess: `Full-Body Red` + `Full` is `#5a0f18` from the generated
    /// table, not `#4a0e0e` from the ladder — two different colours, so a
    /// reversed `??` would be visible here and nowhere else.
    @Test("a matching tone beats the keyword fallback")
    func toneWinsOverFallback() {
        #expect(db.palette.grapeWellHex(style: "Full-Body Red", body: "Full") == "#5a0f18")
        #expect(EntryPalette.grapeWellFallbackHex(style: "Full-Body Red", body: "Full") == "#4a0e0e")
        // And the fallback really is reached when no tone matches.
        #expect(db.palette.grapeWellHex(style: "Sparkling Red", body: "Medium") == "#8b0000")
    }

    // MARK: - Chip resolution

    @Test("an unknown key falls back to the neutral chip")
    func resolveFallsBack() {
        let chip = db.palette.resolve(TileChip(label: "x", key: "NOT_A_KEY", table: .country))
        #expect(chip.bg == EntryPalette.fallbackChip.bg)
        #expect(chip.border == EntryPalette.fallbackChip.border)
        #expect(chip.text == EntryPalette.fallbackChip.text)
    }

    /// `.classification` is the only two-step case: an unknown key falls to the
    /// SYSTEM named chip *before* the neutral one. Pinned against a fixture
    /// rather than the shipped data so the ordering is asserted directly.
    @Test("an unknown classification falls to SYSTEM, not to neutral")
    func classificationFallsToSystem() throws {
        let system = Palette.Chip(bg: "#000001", border: "#000002", text: "#000003")
        let fixture = try Self.paletteFixture(namedChips: ["SYSTEM": system])
        let resolved = fixture.resolve(TileChip(label: "x", key: "NOT_A_KEY", table: .classification))
        #expect(resolved.bg == system.bg, "fell through SYSTEM to the neutral chip")

        // With no SYSTEM chip either, it does reach the neutral one.
        let bare = try Self.paletteFixture(namedChips: [:])
        #expect(bare.resolve(TileChip(label: "x", key: "NOT_A_KEY", table: .classification)).bg
                == EntryPalette.fallbackChip.bg)
    }

    /// A `Palette` with every table empty but `namedChips`. Decoded from JSON
    /// rather than built with the memberwise init: fourteen fields is a lot of
    /// noise, and adding a `public init` to `Palette` just for a test would be
    /// worse.
    private static func paletteFixture(namedChips: [String: Palette.Chip]) throws -> Palette {
        var tables: [String: Any] = [:]
        for key in ["countryChips", "classificationChips", "wineTypeChips", "rarityChips",
                    "colorTypeChips", "styleClassChips", "flavorClassChips", "flavorSubclassChips",
                    "namedChips", "styleTones", "climates", "regionClassificationIconColors",
                    "flavorSubclassIconColors", "continentCountries", "styleColorTypes"] {
            tables[key] = [String: String]()
        }
        tables["namedChips"] = namedChips.mapValues { ["bg": $0.bg, "border": $0.border, "text": $0.text] }
        let data = try JSONSerialization.data(withJSONObject: tables)
        return try JSONDecoder().decode(Palette.self, from: data)
    }
}
