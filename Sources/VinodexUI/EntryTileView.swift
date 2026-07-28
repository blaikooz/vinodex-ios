#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// A row in the encyclopedia list.
///
/// The icon slot is a placeholder colour block until the ~30 game-icons are
/// rasterised — deliberately obvious rather than an SF Symbol stand-in, so it
/// cannot be mistaken for finished work.
public struct EntryTileView: View {
    let entry: WineEntry
    let palette: Palette
    let action: () -> Void

    public init(entry: WineEntry, palette: Palette, action: @escaping () -> Void) {
        self.entry = entry
        self.palette = palette
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 12) {
                iconSlot

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.name.uppercased())
                        .font(DexFont.retro(13))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    FlowLayout(spacing: 5) {
                        ForEach(entry.tileChips) { chip in
                            ChipView(label: chip.label, chip: palette.resolve(chip))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Dex.stone600)
            }
            .padding(8)
            .frame(minHeight: 72)
            .background(Dex.stone900)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Dex.stone700, lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
    }

    private var iconSlot: some View {
        EntryIconWell(entry: entry, size: 48, cornerRadius: 8)
    }
}

public extension Palette {
    /// Resolves a tile chip against the generated colour tables, falling back to
    /// a neutral chip when a key is absent.
    func resolve(_ chip: TileChip) -> Chip {
        let fallback = Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
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
        }
    }
}
#endif
