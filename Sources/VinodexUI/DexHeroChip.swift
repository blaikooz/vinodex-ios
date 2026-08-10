#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// A filter chip in its own colours (0.6.9, J1).
///
/// The filter rows used to draw a monochrome capsule: `lcd.surface` with the
/// screen mode's `surfaceEdge`, going solid `lcd.accent` when lit. Three dozen
/// of those in six rows is a wall of identical grey lozenges — you could see
/// *how many* were on but not, at a glance, *which*, and the chips were the only
/// coloured vocabulary in the app rendered without its colours. Every value a
/// chip names already has a palette entry, because the same value is drawn in
/// those colours the moment it appears on an entry row.
///
/// So this is the entry tile's chip, promoted to a control: the value's own
/// `bg` / `border` / `text` in a rounded rectangle, at a size you can hit. It is
/// deliberately the same shape and the same table as `ChipView` — a lit RED chip
/// and the RED chip on a Cabernet row are the same red, which is what makes the
/// filter legible as a *statement about the list* rather than as a set of
/// switches that happen to change it.
///
/// Three states, and they are carried by weight rather than by hue, so the
/// colour stays free to say what the value is:
///
/// - **off** — the chip's fill at a low opacity, hairline rim, ink at ease.
/// - **on** — full fill, a 3pt rim, and a check. The same "filled means chosen"
///   grammar the scanner's answer chips and flavour tiles already use.
/// - **dead** — costed to zero results. Dimmed rather than disabled: a chip that
///   leads nowhere is a fact about the data worth being able to see and tap.
struct DexHeroChip: View {
    let label: String
    let chip: Palette.Chip
    let isOn: Bool
    /// Costed to zero. Never true at the same time as `isOn` — turning a lit
    /// chip off can only widen the result set.
    var isDead: Bool = false
    let action: () -> Void

    /// Rounded rectangle, not a capsule (J1). A capsule's radius is half its
    /// height, which at this size swallows the short labels (RED, DOC) into
    /// lozenges; a fixed 8 keeps every chip the same *shape* whatever its width,
    /// which is what makes a wrapped row read as one set of parts.
    private static let corner: CGFloat = 8

    private var ink: Color { Color(dexHex: chip.text) }
    private var fill: Color { Color(dexHex: chip.bg) }
    private var rim: Color { Color(dexHex: chip.border) }

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(DexFont.retro(11))
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .heavy))
                }
            }
            .foregroundStyle(ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Self.corner)
                    .fill(fill.opacity(isOn ? 1 : 0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Self.corner)
                    .strokeBorder(rim.opacity(isDead ? 0.35 : 1), lineWidth: isOn ? 3 : 1)
            )
            // Lit chips carry the same drop the moulded caps do, at a fraction
            // of it: enough to lift a chosen chip off the row, not enough to
            // make a row of them look embossed.
            .shadow(color: rim.opacity(isOn ? 0.5 : 0), radius: 4, y: 1)
            .opacity(isDead ? 0.45 : 1)
        }
        .buttonStyle(DexPressStyle(scale: 0.94))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

public extension Palette {
    /// The colours a filter chip wears (0.6.9, J1).
    ///
    /// Five of the six facets resolve straight into a generated table, which is
    /// the whole reason J1 is cheap: the values a chip names are the same values
    /// entry rows already draw, so the chip and the row cannot disagree. The two
    /// that have no table of their own are spelled out here rather than left
    /// neutral, because "coloured" with two grey rows in the middle of it is not
    /// what the instruction asks for:
    ///
    /// - **TYPE** — the categories have a display order and a listing screen but
    ///   no palette entry; the generator has never had a reason to emit one.
    ///   These are the LCD-safe registers each category already reads as
    ///   elsewhere (leaf green for varieties, earth for regions, wine red for
    ///   styles, aroma violet for flavours, sea blue for continents and the
    ///   pseudo-category).
    /// - **BODY** — the same three weights the scanner's own body step uses,
    ///   graded light to full. That table lived privately in `ScannerScreen`;
    ///   it lives here now so the scanner's answer chip and the filter's body
    ///   chip are the one colour by construction.
    func filterChip(_ option: ChipOption) -> Chip {
        let fallback = Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
        switch option.facet {
        case .category:
            return Self.categoryChips[option.value] ?? fallback
        case .color:
            return colorTypeChips[option.value.uppercased()] ?? fallback
        case .body:
            return Self.bodyChips[option.value] ?? fallback
        // **`wineTypeChips`, which is what that table has always been for**
        // (0.8.8, C1). The generator has emitted a colour per grape style since
        // the palette shipped — it is what a grape's own TYPE tile reads,
        // through `EntryTileView`'s `.wineType` arm — and until C1 there was no
        // chip row keyed by those ten names for it to also serve. Keyed by the
        // catalog's spelling, which is exactly what `ChipOption.value` carries
        // here (see `ChipFilter.options`), so a chip and the tile it filters to
        // are the same colour by construction, as BODY and the three 0.7.0
        // facets below both are.
        //
        // 0.6.9's I1 is the reason this deserves the sentence: the grape colour
        // chip read `wineTypeChips` with a `grapeType` key, missed on all 146
        // grapes and fell through to a neutral — a chip that says RED and is
        // grey reads as a styling choice rather than as a miss.
        case .grapeStyle:
            return wineTypeChips[option.value] ?? fallback
        case .rarity:
            return rarityChips[option.value] ?? fallback
        case .climate:
            return climates[option.value]?.colors ?? fallback
        case .country:
            return chip(country: option.value) ?? fallback
        // The three 0.7.0 (H2/H3) facets all read palettes the generator
        // already emits and the detail screens already draw, so a chip and the
        // tile it filters to are the same colour by construction — the same
        // argument the BODY note above makes for the scanner.
        case .styleClass:
            return styleClassChips[option.value] ?? fallback
        // Same table the style's own tile chip reads, keyed by the same
        // `StyleColorType` rawValue — 0.8.0's K is the reason that sentence is
        // worth writing down (0.8.1, D).
        case .styleColor:
            return colorTypeChips[option.value] ?? fallback
        case .flavorClass:
            return flavorClassChips[option.value] ?? fallback
        case .flavorSubclass:
            return flavorSubclassChips[option.value] ?? fallback
        }
    }

    /// See `filterChip(_:)`. Keyed by `EntryCategory.rawValue`, plus
    /// `ChipFilter.countriesCategoryValue`.
    static let categoryChips: [String: Chip] = [
        "GRAPES": Chip(bg: "#14300f", border: "#4d7c0f", text: "#d9f99d"),
        "REGIONS": Chip(bg: "#2b1c07", border: "#a16207", text: "#fde68a"),
        "STYLES": Chip(bg: "#3b0f0f", border: "#9f1239", text: "#fecdd3"),
        "FLAVORS": Chip(bg: "#2a1140", border: "#7c3aed", text: "#e9d5ff"),
        "CONTINENTS": Chip(bg: "#0b1f3a", border: "#2563eb", text: "#dbeafe"),
        "COUNTRIES": Chip(bg: "#08282a", border: "#0d9488", text: "#ccfbf1"),
    ]

    /// See `filterChip(_:)`. Keyed by `GrapeBody.rawValue`.
    static let bodyChips: [String: Chip] = [
        "Light": Chip(bg: "#1a2e05", border: "#65a30d", text: "#d9f99d"),
        "Medium": Chip(bg: "#451a03", border: "#d97706", text: "#fde68a"),
        "Full": Chip(bg: "#3b0f0f", border: "#8b0000", text: "#fecdd3"),
    ]
}
#endif
