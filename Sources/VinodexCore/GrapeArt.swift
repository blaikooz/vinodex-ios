import Foundation

/// Resolves a grape entry to its bunch-sprite key — the 0.5.4 "grape icon
/// system". One identical bunch sprite, recoloured on two axes and flecked
/// on a third; the shape is never redrawn:
///
///   - **berry colour** from `grapeType` — white grapes are green fruit;
///   - **depth** from `grapeBodyClass` — a fuller wine is a darker bunch;
///   - **blend flecks** for the varieties whose skin colour is the story:
///     pink for the gris family, amber for orange/skin-contact styles;
///   - **the leaf is the rarity** — green, yellowing, or full autumn.
///
/// This type produces the *key*; which PNG a key resolves to lives in the
/// icon manifest's `grapeArt` table (generated, with fallbacks for combos
/// the sprite set does not cover). Keeping the key derivation pure and
/// data-driven is what makes it testable from Linux.
public enum GrapeArt {
    public enum Depth: String, CaseIterable { case light, medium, full }
    public enum Blend: String, CaseIterable { case none, pink, amber }

    /// `Light`/`Light-Medium` → light; `Medium-Full`/`Full` → full; the
    /// middle and anything unrecognised sit at medium.
    public static func depth(bodyClass: String) -> Depth {
        switch bodyClass {
        case "Light", "Light-Medium": .light
        case "Medium-Full", "Full": .full
        default: .medium
        }
    }

    /// Name-driven for the gris family — the skin colour is in the name
    /// (Gris, Grigio, Gewürztraminer) — and style-driven for amber, because
    /// skin contact is a winemaking choice rather than a variety.
    public static func blend(name: String, style: String, wineType: String?) -> Blend {
        let n = TextNormalize.label(name)
        if n.contains("gris") || n.contains("grigio") || n.contains("gewurztraminer") {
            return .pink
        }
        let s = TextNormalize.label(style + " " + (wineType ?? ""))
        if s.contains("orange") || s.contains("amber") || s.contains("skin contact") {
            return .amber
        }
        return .none
    }

    /// The leaf colour per rarity tier (0.6.2, A2) — code-driven, not baked
    /// into sprite variants. `GrapeSpriteLoader` recolours the base sprite's
    /// leaf to this at load time, which is how GODFORSAKEN got a leaf without
    /// anyone drawing one. Hex here rather than SwiftUI `Color` so the rule
    /// is testable from Linux.
    public static func leafHex(rarity: RarityLabel) -> String {
        switch rarity {
        case .common: "#A8E34B"       // lime green
        case .uncommon: "#3E9B2F"     // regular green
        case .rare: "#E8A23C"         // amber
        case .noble: "#9455D4"        // purple
        case .godforsaken: "#CFC63B"  // yellowing
        }
    }

    /// The manifest key: `<green|red|gold>-<depth>-<blend>` — no leaf
    /// component since 0.6.2; the leaf is recoloured in code per rarity.
    ///
    /// Gold berries (0.6.x) mark the sweet whites — Moscato, PX, Vidal — the
    /// grapes whose fruit genuinely hangs golden by picking time.
    public static func key(for grape: GrapeEntry) -> String {
        let color: String
        if grape.grapeType == .white {
            let s = TextNormalize.label(grape.grapeStyle + " " + (grape.wineType ?? ""))
            color = s.contains("sweet") ? "gold" : "green"
        } else {
            color = "red"
        }
        let d = depth(bodyClass: grape.grapeBodyClass)
        let b = blend(name: grape.common.name, style: grape.grapeStyle, wineType: grape.wineType)
        return "\(color)-\(d.rawValue)-\(b.rawValue)"
    }
}
