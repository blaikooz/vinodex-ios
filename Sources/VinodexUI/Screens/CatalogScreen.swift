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
struct CatalogScreen: View {
    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }

    let db: WineDatabase
    /// The settings panel renders the icon sheet separately, at the very
    /// bottom — it is the longest block here and buried everything after it.
    var showsIcons: Bool = true

    init(db: WineDatabase = .shared, showsIcons: Bool = true) {
        self.db = db
        self.showsIcons = showsIcons
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsIcons { IconSheet(db: db) }
            fontSpecimens
            chipGallery
            statBars
            entrySummary
        }
    }

    /// Every rasterised glyph on one sheet. Split out so it can be placed last.
    struct IconSheet: View {
        /// The eight stored settings, as one model (arch **A17**).
        var settings: AppSettings = .shared
        private var lcd: LcdMode { settings.lcdMode }

        let db: WineDatabase

        init(db: WineDatabase = .shared) { self.db = db }

        var body: some View {
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
                .font(DexFont.retro(10))
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
struct ChipView: View {
    let label: String
    let chip: Palette.Chip

    init(label: String, chip: Palette.Chip) {
        self.label = label
        self.chip = chip
    }

    var body: some View {
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
struct StatBar: View {
    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }

    let label: String
    let value: Double
    var maximum: Double = 5
    var fill: Color = Dex.green

    init(label: String, value: Double, maximum: Double = 5, fill: Color = Dex.green) {
        self.label = label
        self.value = value
        self.maximum = maximum
        self.fill = fill
    }

    /// Nominal type size for the label, and the well it sits in at that size.
    ///
    /// 96 was a literal, and it was the tightest ceiling on the whole text axis
    /// (AUDIT **M49**): VT323's advance is exactly 0.4 em, so AROMATICS — nine
    /// characters at `mono(19)` with 1.5 tracking — wants `9 × (7.6f + 1.5)`
    /// points, which passes 96 at **f = 1.206**. That is why `TextScale` stopped
    /// at 1.15. The well derives from the same resolver the font does now, so
    /// the two move together and the ceiling is gone.
    static let labelSize: Double = 19
    static let labelTracking: Double = 1.5
    /// AROMATICS, the longest label any caller passes (`GrapeCharacteristics.bars`
    /// tops out there; `CatalogScreen`'s "LEVEL n" is seven).
    static let longestLabel = 9
    /// What shipped, and the floor this must not fall below. Deriving downward
    /// as well as upward would silently re-lay the stat rows at SMALL and
    /// LARGE, where the well is already generous — the same `atLeast:`
    /// reasoning as `DexSearchField.height`. Only HUGE exceeds it — 102.4pt
    /// against 96 — which is exactly the ceiling that used to cap the axis.
    static let pinnedLabelWidth: Double = 96

    /// The drawn width of the label well. Pinned by `TypeScaleTests`.
    static var labelWidth: CGFloat {
        CGFloat(max(
            pinnedLabelWidth,
            TypeScale.monoRunWidth(
                characters: longestLabel,
                nominal: labelSize,
                tracking: labelTracking,
                step: TextScale.current
            )
        ))
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(DexFont.mono(CGFloat(Self.labelSize)))
                .foregroundStyle(lcd.text)
                .tracking(1.5)
                // Derived from the type, not pinned beside it. `lineLimit` and
                // `minimumScaleFactor` are the backstop for a label longer than
                // any shipped today — without them an over-long stat name is
                // silently truncated by the frame rather than shrunk.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: Self.labelWidth, alignment: .leading)

            HStack(spacing: 2) {
                // `0..<Int(maximum)` traps on a negative, NaN, infinite or
                // out-of-Int-range maximum — latent while every caller takes
                // the default 5, but both the property and the init are
                // public. `Int(exactly:)` refuses all of those with nil, so a
                // hostile value degrades to an empty bar instead (auditS L8).
                let segments = max(0, Int(exactly: maximum.rounded()) ?? 0)
                ForEach(0..<segments, id: \.self) { index in
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
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    init(spacing: CGFloat = 6) { self.spacing = spacing }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            var size = view.sizeThatFits(.unspecified)
            // Clamped here too, or the measured height disagrees with the
            // placed one for exactly the over-wide chip `placeSubviews` now
            // shrinks — see the note there.
            size.width = min(size.width, maxWidth)
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

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            var size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            // A chip wider than the whole container cannot be broken onto a
            // row of its own — it *is* the row — so it was placed at its
            // natural width and ran off the edge, where `DeviceChassis`'s
            // clip made it invisible rather than obviously wrong (AUDIT
            // **M49**). Proposing the container width instead makes the chip
            // shrink or wrap in the only direction there is room to. This is
            // reachable today at a large text step: chip labels are unbounded
            // strings from the data.
            size.width = min(size.width, bounds.width)
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
#endif
