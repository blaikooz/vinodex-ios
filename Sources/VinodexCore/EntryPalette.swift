import Foundation

/// Colour rules ported from the web app's `chipColors.ts` and
/// `entryIconVisuals.tsx` — in hex rather than as SwiftUI `Color`s.
///
/// Hex for the same reason `GrapeArt.leafHex(rarity:)` is hex: the rule is the
/// testable part, and `Color` is not available where the tests run. These three
/// functions spent their whole lives in `VinodexUI`, which compiles to nothing
/// off-device and is reachable by no check this project runs — so a twelve-branch
/// keyword ladder over twenty-four literal spellings had exactly zero coverage.
/// The UI wraps the result in `Color(dexHex:)` at the point of use. (AUDIT **M29**)
///
/// **Every hex here is lowercase, deliberately.** The ladder's literals used to
/// be uppercase while every value in `palette.json` is lowercase, and the two
/// paths return the *same colour* for bright red — `#dc143c` — so any consumer
/// comparing strings would have reported a mismatch between two answers that
/// agree. `Color(dexHex:)` parses case-insensitively, so nothing renders
/// differently; the point is that a hex leaving here can be compared.
public enum EntryPalette {
    /// The neutral chip a missing key falls back to.
    static let fallbackChip = Palette.Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")

    /// `normalizeStyleKey` — maps an authored style string onto a
    /// `Palette.styleTones` key, or nil when no rule matches.
    ///
    /// Split from the table lookup on purpose: this half needs no `Palette` at
    /// all, so a test can pin the ladder without a fixture, and a separate test
    /// can pin that every key it emits exists in the generated table.
    ///
    /// The `rosé` key keeps its diacritic while the matcher runs on
    /// diacritic-folded text. That is correct — the key is a literal looked up
    /// in `palette.json`, which spells it `rosé` — and "tidying" it to `rose`
    /// breaks the lookup silently.
    public static func styleToneKey(for style: String) -> String? {
        let t = TextNormalize.label(style)
        guard !t.isEmpty else { return nil }

        func has(_ needles: [String]) -> Bool { needles.contains { t.contains($0) } }

        if has(["full-body red", "full body red", "full-bodied red", "full bodied red"]) {
            return "full-bodied red"
        } else if t.contains("bright red") {
            return "bright red"
        } else if has(["light-body red", "light body red", "light-bodied red", "light bodied red"]) {
            return "light-bodied red"
        } else if t.contains("dark red") {
            return "dark red"
        } else if has(["medium-body red", "medium body red", "medium-bodied red", "medium bodied red"]) {
            return "medium-bodied red"
        } else if has(["pink", "rose"]) {
            return "rosé"
        } else if has(["light-body white", "light body white", "light-bodied white", "light bodied white"]) {
            return "light-bodied white"
        } else if t.contains("aromatic white") {
            return "aromatic white"
        } else if has(["high-acid white", "high acid white"]) {
            return "high-acid white"
        } else if has(["full-body white", "full body white", "full-bodied white", "full bodied white"]) {
            return "full-bodied white"
        } else if t.contains("sweet white") {
            return "sweet white"
        } else if has(["medium-body white", "medium body white", "medium-bodied white", "medium bodied white"]) {
            return "medium-bodied white"
        }
        return nil
    }

    /// Every key `styleToneKey(for:)` can return. Exists so a test can prove the
    /// ladder and the generated `styleTones` table have not drifted apart —
    /// which is the failure this move exists to make visible.
    public static let styleToneKeys = [
        "full-bodied red", "bright red", "light-bodied red", "dark red", "medium-bodied red",
        "rosé", "light-bodied white", "aromatic white", "high-acid white", "full-bodied white",
        "sweet white", "medium-bodied white",
    ]

    /// The fallback ladder for a style the tone table does not name: colour
    /// keyword first, then body level. `getGrapeIconColor`'s second half.
    public static func grapeWellFallbackHex(style: String, body: String) -> String {
        let type = TextNormalize.label(style)
        let bodyLevel = TextNormalize.label(body)
        guard !type.isEmpty else { return "#78716c" }

        if type.contains("red") || type.contains("bold") {
            if bodyLevel.contains("light") { return "#dc143c" }
            if bodyLevel.contains("full") { return "#4a0e0e" }
            return "#8b0000"
        }
        if type.contains("white") || type.contains("aromatic") {
            if bodyLevel.contains("light") { return "#fafad2" }
            if bodyLevel.contains("full") { return "#b8860b" }
            return "#daa520"
        }
        if type.contains("rose") { return "#db7093" }
        if type.contains("sweet") { return "#cd853f" }
        return "#78716c"
    }
}

public extension Palette {
    /// Resolves a tile chip against the generated colour tables, falling back to
    /// a neutral chip when a key is absent.
    ///
    /// Moved here from `EntryTileView` by **M29** — it was pure Core-type table
    /// lookup living in the one module nothing can test.
    func resolve(_ chip: TileChip) -> Chip {
        let fallback = EntryPalette.fallbackChip
        switch chip.table {
        case .country: return countryChips[chip.key] ?? fallback
        case .wineType: return wineTypeChips[chip.key] ?? fallback
        case .climate: return climates[chip.key]?.colors ?? fallback
        case .styleClass: return styleClassChips[chip.key] ?? fallback
        case .colorType: return colorTypeChips[chip.key] ?? fallback
        case .flavorClass: return flavorClassChips[chip.key] ?? fallback
        case .flavorSubclass: return flavorSubclassChips[chip.key] ?? fallback
        case .rarity: return rarityChips[chip.key] ?? fallback
        case .named: return namedChips[chip.key] ?? fallback
        case .classification:
            return classificationChips[chip.key]
                ?? namedChips["SYSTEM"]
                ?? fallback
        }
    }

    /// The style tone's primary hex for an authored style string, or nil.
    func styleToneHex(for style: String) -> String? {
        EntryPalette.styleToneKey(for: style).flatMap { styleTones[$0]?.primary }
    }

    /// `getGrapeIconColor`: the generated style-tone palette first, then the
    /// colour/body keyword ladder. The order is the whole rule — a tone, when
    /// one matches, always wins over a keyword guess.
    func grapeWellHex(style: String, body: String) -> String {
        styleToneHex(for: style) ?? EntryPalette.grapeWellFallbackHex(style: style, body: body)
    }
}
