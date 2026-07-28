#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The detail readout, styled to match the web app's terminal presentation:
/// black ground, green rules, underlined section headers, and full-width linked
/// rows rather than chip clouds.
///
/// Sections are driven by the entry variant rather than a pile of optional
/// checks — `if case .grape(let g)` gives the compiler the same guarantees the
/// TypeScript type guards gave the web app.
public struct EntryDetailScreen: View {
    let entry: WineEntry
    let onSelectRelated: (WineEntry) -> Void

    private let db = WineDatabase.shared

    /// The web app caps linked lists at 8 rows.
    private static let linkedRowLimit = 8

    public init(entry: WineEntry, onSelectRelated: @escaping (WineEntry) -> Void) {
        self.entry = entry
        self.onSelectRelated = onSelectRelated
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                headerTiles
                // Flavours were skipped while their blurb was a bare template
                // sentence. It now names the grapes the flavour derives from,
                // which is worth showing.
                if !entry.entryDescription.isEmpty {
                    infoSection
                }
                categorySections
            }
            .padding(.horizontal, 14)
            // Generous tail so the last section clears the footer, matching pb-20.
            .padding(.bottom, 72)
        }
        .background(Color.black)
    }

    // MARK: Hero

    /// Centred icon above a centred wordmark, on a faintly gridded green panel.
    private var hero: some View {
        VStack(spacing: 14) {
            EntryIconWell(entry: entry, size: 80, cornerRadius: 12)

            Text(entry.name.uppercased())
                .font(DexFont.retro(21))
                .foregroundStyle(.white)
                .shadow(color: Color(dexHex: "#006400").opacity(0.8), radius: 0, x: 4, y: 4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            ZStack {
                Color(dexHex: "#14532d").opacity(0.1)
                DexGridBackground(spacing: 34, color: Color(dexHex: "#14532d"), opacity: 0.5)
            }
        )
        .overlay(alignment: .bottom) {
            Color(dexHex: "#166534").frame(height: 4)
        }
        .padding(.horizontal, -14)
        .padding(.bottom, 16)
    }

    private var infoSection: some View {
        section("INFO", symbol: "book") {
            Text(entry.entryDescription)
                .font(DexFont.mono(21))
                .foregroundStyle(Color(dexHex: "#bbf7d0"))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)
                .padding(.vertical, 10)
                .background(alignment: .leading) {
                    // The reference marks body copy with a left accent rule.
                    Color(dexHex: "#15803d").frame(width: 4)
                }
                .background(Color(dexHex: "#14532d").opacity(0.08))
        }
    }

    // MARK: Three-tile header row

    @ViewBuilder
    private var headerTiles: some View {
        Group {
            switch entry {
            case .grape(let g):
                HStack(alignment: .top, spacing: 8) {
                    tile(label: "COLOR", chip: chip(g.grapeType.rawValue.uppercased(), .colorType)) { tint in
                        DexIcon(iconID: db.icons.colorIcon(g.grapeType.rawValue.uppercased()), size: 32, color: tint)
                    }
                    tile(label: "TYPE", chip: chip(EntryDisplay.grapeBodyLabel(g), .wineType, key: g.grapeStyle)) { tint in
                        DexIcon(iconID: db.icons.bodyIcon(g.grapeBodyClass), size: 32, color: tint)
                    }
                    tile(label: "ORIGIN", chip: chip(g.details.origin.uppercased(), .country, key: g.details.origin)) { _ in
                        FlagSwatch(country: g.details.origin)
                    }
                }

            case .region(let r):
                HStack(alignment: .top, spacing: 8) {
                    let keyGrape = r.details.notableGrapes.first
                    tile(label: "KEY GRAPE", chip: chip((keyGrape ?? "N/A").uppercased(), .wineType, key: keyGrape ?? "")) { _ in
                        keyGrapeIcon(keyGrape)
                    }
                    tile(label: "CLIMATE", chip: chip((r.climate?.rawValue ?? "N/A").uppercased(), .climate, key: r.climate?.rawValue ?? "")) { tint in
                        DexIcon(iconID: db.icons.climateIcon(r.climate), size: 32, color: tint)
                    }
                    tile(label: "COUNTRY", chip: chip(r.details.origin.uppercased(), .country, key: r.details.origin)) { _ in
                        FlagSwatch(country: r.details.origin)
                    }
                }

            case .style(let s):
                let cls = EntryDisplay.styleClass(name: s.common.name, classification: s.details.classification)
                let color = EntryDisplay.colorType(name: s.common.name)
                HStack(alignment: .top, spacing: 8) {
                    tile(label: "COLOR", chip: chip(color.rawValue, .colorType, key: color.rawValue)) { tint in
                        DexIcon(iconID: db.icons.colorIcon(color.rawValue), size: 32, color: tint)
                    }
                    tile(label: "CLASS", chip: chip(cls.rawValue, .styleClass, key: cls.rawValue)) { tint in
                        DexIcon(iconID: db.iconID(for: entry), size: 32, color: tint)
                    }
                    if s.details.origin.lowercased() != "various" {
                        tile(label: "ORIGIN", chip: chip(s.details.origin.uppercased(), .country, key: s.details.origin)) { _ in
                            FlagSwatch(country: s.details.origin)
                        }
                    }
                }

            case .flavor(let f):
                HStack(alignment: .top, spacing: 8) {
                    tile(label: "CLASS", chip: chip(f.details.classification, .flavorClass, key: f.details.classification)) { _ in
                        DexIcon(iconID: db.iconID(for: entry), size: 32, color: Color(dexHex: entry.color))
                    }
                    tile(
                        label: "SUBCLASS",
                        chip: chip(EntryDisplay.humanize(f.details.subclass).uppercased(), .flavorSubclass, key: f.details.subclass)
                    ) { tint in
                        DexIcon(iconID: db.iconID(for: entry), size: 32, color: tint)
                    }
                }

            case .continent:
                // Continents never reach this screen — they open
                // ContinentScreen instead (see WineEntry.destination) — but
                // the switch must stay exhaustive.
                EmptyView()
            }
        }
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Color(dexHex: "#166534").frame(height: 4)
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func keyGrapeIcon(_ name: String?) -> some View {
        if let name, let target = db.entry(named: name) {
            Button {
                Haptics.select()
                onSelectRelated(target)
            } label: {
                EntryIconWell(entry: target, size: 34, cornerRadius: 6)
            }
            .buttonStyle(DexPressStyle(scale: 0.9))
        } else {
            DexIcon(iconID: db.icons.fallback, size: 32, color: Dex.stone600)
        }
    }

    private func chip(_ label: String, _ table: TileChip.Table, key: String? = nil) -> TileChip {
        TileChip(label: label, key: key ?? label, table: table)
    }

    /// The icon builder is handed the resolved chip's colour so the glyph and
    /// its chip read as one unit. They were all flat `stone200`, which made the
    /// row look inert next to the coloured chips directly beneath it.
    private func tile<C: View>(
        label: String,
        chip: TileChip,
        @ViewBuilder icon: (Color) -> C
    ) -> some View {
        let tint = Color(dexHex: db.palette.resolve(chip).text)
        return VStack(spacing: 5) {
            Text(label)
                .font(DexFont.retro(8))
                .foregroundStyle(Dex.green)
            icon(tint)
                .frame(height: 34)
            // Two lines before shrinking: at a third of the screen, names like
            // CABERNET SAUVIGNON and GRÜNER VELTLINER were being scaled to
            // 55% and still clipped. Wrapping keeps them readable.
            ChipView(label: chip.label, chip: db.palette.resolve(chip))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: Category sections

    @ViewBuilder
    private var categorySections: some View {
        switch entry {
        case .grape(let g):
            statsSection(g)
            raritySection(g)
            // The reference titles the grape notes section FLAVOR PROFILE.
            flavorProfileSection(entry.tastingProfile)
            if !g.grapeAlternateNames.isEmpty {
                chipSection("ALSO KNOWN AS", symbol: "character.book.closed", names: g.grapeAlternateNames)
            }
            linkedSection("NOTABLE REGIONS", symbol: "mappin.and.ellipse", names: g.grapeNotableRegions)

        case .region(let r):
            systemSection(r)
            // Climate and soil are always shown for regions, even without data:
            // climate falls back to "Unknown Climate" and soils to a
            // climate-keyed triplet.
            climateSection(r)
            soilSection(r)
            linkedSection("NOTABLE GRAPES", symbol: "list.bullet", names: r.details.notableGrapes)
            if let appellations = r.details.appellations, !appellations.isEmpty {
                chipSection("APPELLATIONS", symbol: "shield", names: appellations)
            }

        case .style(let s):
            styleRelatedSections(s)

        case .flavor:
            // Flavours deliberately have no INFO block in the reference; their
            // grape list is titled NOTABLE GRAPES.
            linkedSection("NOTABLE GRAPES", symbol: "list.bullet", names: entry.notableGrapes, limit: 8)

        case .continent:
            // Continents never reach this screen — see WineEntry.destination.
            EmptyView()
        }
    }

    /// Style sections vary by classification, matching the reference exactly:
    /// METHOD shows KEY GRAPES, STYLE and ORIGIN show NOTABLE GRAPES, and every
    /// class shows KEY REGIONS.
    ///
    /// Note TYPE and BLEND therefore show no grape list at all — that is what
    /// the web app does, and it is almost certainly an oversight there, since
    /// those styles do carry `notableGrapes`.
    @ViewBuilder
    private func styleRelatedSections(_ s: StyleEntry) -> some View {
        let cls = EntryDisplay.styleClass(name: s.common.name, classification: s.details.classification)

        switch cls {
        case .method:
            linkedSection("KEY GRAPES", symbol: "list.bullet", names: s.details.notableGrapes, limit: 6)
        case .style, .origin:
            linkedSection("NOTABLE GRAPES", symbol: "list.bullet", names: s.details.notableGrapes, limit: 6)
        case .type, .blend:
            EmptyView()
        }

        linkedSection("KEY REGIONS", symbol: "mappin.and.ellipse", names: s.details.keyRegions, limit: 6)
    }

    /// A single large chip carrying the climate's display name and colours.
    private func climateSection(_ r: RegionEntry) -> some View {
        let meta = r.climate.flatMap { db.palette.climates[$0.rawValue] }
        let colors = meta?.colors ?? db.palette.namedChips["CLIMATE"]
            ?? Palette.Chip(bg: "#14532d", border: "#22c55e", text: "#86efac")

        return section("CLIMATE", symbol: "wind") {
            HStack(spacing: 10) {
                DexIcon(iconID: db.icons.climateIcon(r.climate), size: 26, color: Color(dexHex: colors.border))
                Text((meta?.name ?? "Unknown Climate").uppercased())
                    .font(DexFont.mono(22))
                    .tracking(1.5)
                    .foregroundStyle(Color(dexHex: colors.text))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(dexHex: colors.bg))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(dexHex: colors.border), lineWidth: 1)
            )
        }
    }

    /// A grid of soil buttons. Regions without an explicit soil type fall back
    /// to a climate-keyed triplet rather than showing nothing.
    private func soilSection(_ r: RegionEntry) -> some View {
        let soils = db.icons.soils(soilType: r.details.soilType, climate: r.climate)

        return section("SOIL COMPOSITION", symbol: "mountain.2") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                spacing: 10
            ) {
                ForEach(soils, id: \.self) { soil in
                    let visual = db.icons.soilIcon(soil)
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(dexHex: "#0b0f19"))
                            .frame(width: 46, height: 46)
                            .overlay(
                                DexIcon(iconID: visual.icon, size: 24, color: Color(dexHex: visual.color))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color(dexHex: visual.color), lineWidth: 2)
                            )
                        Text(soil.uppercased())
                            .font(DexFont.retro(9))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Dex.stone900)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Dex.stone800, lineWidth: 2)
                    )
                }
            }
        }
    }

    /// Per-stat bar colours, matching the reference exactly.
    private static let statColors: [String: String] = [
        "BODY": "#22c55e",
        "ACID": "#eab308",
        "TANNIN": "#ef4444",
        "AROMATICS": "#c084fc",
        "COLOR": "#f59e0b",
    ]

    private func statsSection(_ g: GrapeEntry) -> some View {
        section("CHARACTERISTICS", symbol: "waveform.path.ecg") {
            VStack(spacing: 14) {
                ForEach(g.grapeCharacteristics.bars, id: \.label) { bar in
                    StatBar(
                        label: bar.label,
                        value: bar.value,
                        fill: Color(dexHex: Self.statColors[bar.label] ?? "#22c55e")
                    )
                }
            }
            .padding(12)
            .background(Dex.stone900)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Dex.stone800, lineWidth: 1))
        }
    }

    private func raritySection(_ g: GrapeEntry) -> some View {
        section("RARITY", symbol: "star") {
            HStack(spacing: 8) {
                ChipView(
                    label: g.rarity.rawValue,
                    chip: db.palette.rarityChips[g.rarity.rawValue]
                        ?? Palette.Chip(bg: "#3f3f46", border: "#52525b", text: "#e4e4e7")
                )
                Spacer()
                HStack(spacing: 4) {
                    let filled = rarityRank(g.rarity)
                    ForEach(0..<4, id: \.self) { index in
                        // The top tier takes a crown rather than a fourth
                        // star, so NOBLE reads as its own thing at a glance
                        // instead of "one more star than RARE".
                        let isCrown = g.rarity == .noble && index == 3
                        Image(systemName: isCrown ? "crown.fill" : (index < filled ? "star.fill" : "star"))
                            .font(.system(size: 11))
                            .foregroundStyle(index < filled ? Dex.yellow : Dex.stone700)
                    }
                }
            }
        }
    }

    private func rarityRank(_ rarity: RarityLabel) -> Int {
        switch rarity {
        case .common: 1
        case .uncommon: 2
        case .rare: 3
        case .noble: 4
        }
    }

    private func systemSection(_ r: RegionEntry) -> some View {
        section("APPELLATION SYSTEM", symbol: "shield") {
            HStack(alignment: .top) {
                // Spelled out here, but still keyed by the abbreviation: the
                // palette tables are indexed by `classification`.
                ChipView(
                    label: EntryDisplay.appellationName(
                        classification: r.details.classification,
                        country: r.details.origin
                    ),
                    chip: db.palette.classificationChips[r.details.classification]
                        ?? db.palette.namedChips["SYSTEM"]
                        ?? Palette.Chip(bg: "#1f2937", border: "#4b5563", text: "#e5e7eb")
                )
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let state = r.details.state {
                    Text(state.uppercased())
                        .font(DexFont.mono(19))
                        .foregroundStyle(Dex.stone400)
                }
            }
        }
    }

    @ViewBuilder
    private func flavorProfileSection(_ notes: [TastingNote]) -> some View {
        if !notes.isEmpty {
            section("FLAVOR PROFILE", symbol: "drop") {
                VStack(spacing: 8) {
                    ForEach(notes) { note in
                        tastingRow(note)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tastingRow(_ note: TastingNote) -> some View {
        let target = db.entry(named: note.note, category: .flavors)
        LinkedRow(
            title: note.note,
            entry: target,
            fallbackColor: Color(dexHex: note.color),
            resolved: target != nil
        ) {
            if let target {
                Haptics.select()
                onSelectRelated(target)
            }
        }
    }

    private func textSection(_ title: String, symbol: String, body: String) -> some View {
        section(title, symbol: symbol) {
            Text(body)
                .font(DexFont.mono(20))
                .foregroundStyle(Color(dexHex: "#bbf7d0"))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)
                .padding(.vertical, 8)
                .background(alignment: .leading) {
                    Color(dexHex: "#15803d").frame(width: 4)
                }
                .background(Color(dexHex: "#14532d").opacity(0.08))
        }
    }

    /// Full-width rows, as the reference renders related entries — chips are
    /// reserved for short metadata like appellations.
    @ViewBuilder
    private func linkedSection(
        _ title: String,
        symbol: String,
        names: [String],
        limit: Int = linkedRowLimit
    ) -> some View {
        if !names.isEmpty {
            section(title, symbol: symbol) {
                VStack(spacing: 8) {
                    ForEach(names.prefix(limit), id: \.self) { name in
                        linkedRow(name)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func linkedRow(_ name: String) -> some View {
        let target = db.entry(named: name)
        LinkedRow(
            title: name,
            entry: target,
            fallbackColor: Dex.stone800,
            resolved: target != nil
        ) {
            if let target {
                Haptics.select()
                onSelectRelated(target)
            }
        }
    }

    @ViewBuilder
    private func chipSection(_ title: String, symbol: String, names: [String]) -> some View {
        if !names.isEmpty {
            section(title, symbol: symbol) {
                FlowLayout(spacing: 6) {
                    ForEach(names, id: \.self) { name in
                        ChipView(
                            label: name.uppercased(),
                            chip: Palette.Chip(bg: "#052e16", border: "#15803d", text: "#bbf7d0")
                        )
                    }
                }
            }
        }
    }

    /// Section header: symbol plus label over a green rule — the reference's
    /// `border-b-2 border-green-800` treatment, not a boxed card.
    private func section<C: View>(
        _ title: String,
        symbol: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Dex.green500)
                Text(title)
                    .font(DexFont.retro(10))
                    .tracking(1.5)
                    .foregroundStyle(Dex.green500)
                Spacer()
            }
            .padding(.bottom, 5)
            .overlay(alignment: .bottom) {
                Color(dexHex: "#166534").frame(height: 2)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 22)
    }
}

/// A related-entry row. Unresolved names render greyed and inert, mirroring
/// `isLinkable` in the web app — the common case at starter scale.
struct LinkedRow: View {
    let title: String
    /// Nil when the name has no entry in the current selection.
    let entry: WineEntry?
    let fallbackColor: Color
    let resolved: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Group {
                    if let entry {
                        EntryIconWell(entry: entry, size: 38, cornerRadius: 6)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(fallbackColor)
                            .frame(width: 38, height: 38)
                            .overlay(
                                DexIcon(
                                    iconID: WineDatabase.shared.icons.fallback,
                                    size: 22,
                                    color: Dex.stone600
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.black.opacity(0.25), lineWidth: 1)
                            )
                    }
                }

                Text(title.uppercased())
                    .font(DexFont.retro(11))
                    .foregroundStyle(resolved ? .white : Dex.stone600)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                if resolved {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Dex.stone600)
                }
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Dex.stone900)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(resolved ? Dex.stone700 : Dex.stone800, lineWidth: 1)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        .disabled(!resolved)
    }
}

/// Flag swatch used in the three-tile header row.
public struct FlagSwatch: View {
    let country: String

    public init(country: String) { self.country = country }

    public var body: some View {
        FlagImage(country: country)
            .frame(width: 52, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(.white, lineWidth: 2)
            )
    }
}
#endif
