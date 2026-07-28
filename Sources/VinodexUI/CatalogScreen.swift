#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// Debug catalog: every component in every state, on one screen.
///
/// This exists because there is no Simulator and no Previews on Windows. One
/// `xtool dev` cycle costs ~20s, so batching dozens of visual states into a
/// single deploy is the difference between a workable loop and an unworkable
/// one. Every later phase should add its components here rather than checking
/// them one at a time.
public struct CatalogScreen: View {
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    let db: WineDatabase
    /// The settings panel renders the icon sheet separately, at the very
    /// bottom — it is the longest block here and buried everything after it.
    var showsIcons: Bool = true

    public init(db: WineDatabase = .shared, showsIcons: Bool = true) {
        self.db = db
        self.showsIcons = showsIcons
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsIcons { IconSheet(db: db) }
            fontSpecimens
            chipGallery
            statBars
            entrySummary
        }
    }

    /// Every rasterised glyph on one sheet. Split out so it can be placed last.
    public struct IconSheet: View {
        @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
        private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

        let db: WineDatabase

        public init(db: WineDatabase = .shared) { self.db = db }

        public var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("ICONS (\(db.icons.unique.count))")
                    .font(DexFont.retro(11))
                    .foregroundStyle(lcd.accent)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                    ForEach(db.icons.unique, id: \.self) { iconID in
                        VStack(spacing: 3) {
                            DexIcon(iconID: iconID, size: 28, color: lcd.text)
                            Text(iconID.split(separator: ":").last.map(String.init) ?? iconID)
                                .font(.system(size: 7))
                                .foregroundStyle(lcd.subtext)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(lcd.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(lcd.surfaceEdge, lineWidth: 2)
            )
        }
    }

    /// Still used by `entrySummary`; the diagnostics rows moved out.
    private func label(_ text: String, ok: Bool) -> some View {
        HStack(spacing: 6) {
            Text(ok ? "OK" : "!!")
                .font(DexFont.retro(9))
                .foregroundStyle(ok ? Dex.green : Dex.red500)
            Text(text)
                .font(DexFont.mono(18))
                .foregroundStyle(lcd.text)
        }
    }

    // MARK: Fonts

    private var fontSpecimens: some View {
        section("FONTS") {
            VStack(alignment: .leading, spacing: 8) {
                Text("PRESS START 2P 12")
                    .font(DexFont.retro(12))
                    .foregroundStyle(lcd.text)
                Text("VT323 22 — 0123456789 the quick brown fox")
                    .font(DexFont.mono(22))
                    .foregroundStyle(lcd.text)
                // A real Press Start 2P glyph is unmistakably blocky; if this row
                // looks like ordinary bold monospace, registration silently failed.
                Text("ABCDEFGHIJ")
                    .font(DexFont.retro(16))
                    .foregroundStyle(Dex.yellow)
            }
        }
    }

    // MARK: Chips

    private var chipGallery: some View {
        VStack(alignment: .leading, spacing: 14) {
            chipRow("RARITY", db.palette.rarityChips)
            chipRow("CLIMATE", Dictionary(uniqueKeysWithValues: db.palette.climates.map { ($0.key, $0.value.colors) }))
            chipRow("STYLE CLASS", db.palette.styleClassChips)
            chipRow("FLAVOR CLASS", db.palette.flavorClassChips)
            chipRow("COLOR TYPE", db.palette.colorTypeChips)
            chipRow("COUNTRY", db.palette.countryChips)
            chipRow("SUBCLASS", db.palette.flavorSubclassChips)
        }
    }

    private func chipRow(_ title: String, _ chips: [String: Palette.Chip]) -> some View {
        section("\(title) (\(chips.count))") {
            FlowLayout(spacing: 6) {
                ForEach(chips.keys.sorted(), id: \.self) { key in
                    if let chip = chips[key] {
                        ChipView(label: key, chip: chip)
                    }
                }
            }
        }
    }

    // MARK: Stat bars

    private var statBars: some View {
        section("STAT BARS 0-5") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<6, id: \.self) { value in
                    StatBar(label: "LEVEL \(value)", value: Double(value))
                }
            }
        }
    }

    // MARK: Entries

    private var entrySummary: some View {
        section("ENTRIES BY CATEGORY") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(EntryCategory.allCases, id: \.self) { category in
                    let items = db.entries(in: category)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(category.listTitle) — \(items.count)")
                            .font(DexFont.retro(10))
                            .foregroundStyle(lcd.accent)
                        Text(items.prefix(6).map(\.name).joined(separator: ", "))
                            .font(DexFont.mono(17))
                            .foregroundStyle(lcd.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("GLOBE MARKERS")
                    .font(DexFont.retro(10))
                    .foregroundStyle(lcd.accent)
                ForEach(Continent.allCases) { continent in
                    let regions = db.regions(in: continent)
                    label(
                        "\(continent.rawValue): \(regions.map(\.name).joined(separator: ", "))",
                        ok: !regions.isEmpty
                    )
                }
            }
        }
    }

    // MARK: Chrome

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DexFont.retro(11))
                .foregroundStyle(lcd.accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(lcd.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(lcd.surfaceEdge, lineWidth: 2)
        )
    }
}

// MARK: - Shared components

/// The tag pill used across tiles and detail sections.
public struct ChipView: View {
    let label: String
    let chip: Palette.Chip

    public init(label: String, chip: Palette.Chip) {
        self.label = label
        self.chip = chip
    }

    public var body: some View {
        // Soft-hyphenated so a long single word (MEDITERRANEAN) can break
        // across two lines in a narrow tile instead of shrinking to fit.
        Text(
            EntryDisplay.hyphenated(
                label.replacingOccurrences(of: "_", with: " ").uppercased()
            )
        )
            .font(DexFont.retro(11))
            .foregroundStyle(Color(dexHex: chip.text))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4).fill(Color(dexHex: chip.bg))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(dexHex: chip.border), lineWidth: 1)
            )
    }
}

/// A 0–5 characteristic bar for grape stats.
///
/// Matches the reference: a fixed-width label, then five thin segments where
/// unfilled ones are empty rather than greyed, each stat carrying its own
/// colour (body green, acid yellow, tannin red, aromatics purple, colour amber).
public struct StatBar: View {
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    let label: String
    let value: Double
    var maximum: Double = 5
    var fill: Color = Dex.green

    public init(label: String, value: Double, maximum: Double = 5, fill: Color = Dex.green) {
        self.label = label
        self.value = value
        self.maximum = maximum
        self.fill = fill
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(DexFont.mono(19))
                .foregroundStyle(lcd.text)
                .tracking(1.5)
                .frame(width: 96, alignment: .leading)

            HStack(spacing: 2) {
                ForEach(0..<Int(maximum), id: \.self) { index in
                    Rectangle()
                        .fill(Double(index) < value ? fill : .clear)
                        .frame(height: 8)
                }
            }
            .background(Dex.stone800)
        }
    }
}

/// Minimal wrapping layout — SwiftUI has no flow container and the chip
/// galleries need one.
public struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    public init(spacing: CGFloat = 6) { self.spacing = spacing }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
#endif
