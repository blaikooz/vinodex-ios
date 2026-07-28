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
    /// Free-tier gating. A locked row still renders and is still tappable —
    /// tapping it is how the upgrade prompt is reached — it just reads as
    /// unavailable.
    var locked: Bool = false
    /// Off in the saved list, where the row's top-right corner belongs to the
    /// remove button.
    var showsChevron: Bool = true
    let action: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    public init(
        entry: WineEntry,
        palette: Palette,
        locked: Bool = false,
        showsChevron: Bool = true,
        action: @escaping () -> Void
    ) {
        self.entry = entry
        self.palette = palette
        self.locked = locked
        self.showsChevron = showsChevron
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
                        .foregroundStyle(lcd.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    FlowLayout(spacing: 5) {
                        ForEach(entry.tileChips) { chip in
                            ChipView(label: chip.label, chip: palette.resolve(chip))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Dex.yellow)
                } else if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Dex.stone600)
                } else {
                    Color.clear.frame(width: 34)
                }
            }
            .padding(8)
            .frame(minHeight: 72)
            // Desaturated rather than dimmed to near-invisible: a locked row
            // still has to be readable, because seeing what is behind the
            // paywall is the entire point of showing it.
            .saturation(locked ? 0.15 : 1)
            .opacity(locked ? 0.55 : 1)
            .background(lcd.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(locked ? lcd.surfaceEdge.opacity(0.6) : lcd.surfaceEdge, lineWidth: 2)
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
        case .classification:
            return classificationChips[chip.key]
                ?? namedChips["SYSTEM"]
                ?? fallback
        }
    }
}
#endif
