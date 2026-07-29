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
/// Wraps a header tile in a button when it has somewhere to go, and leaves it
/// untouched when it does not — so an inert tile has no press animation and no
/// hit target suggesting otherwise.
private struct TileLink: ViewModifier {
    let destination: DexRoute?
    let onOpen: (DexRoute) -> Void

    func body(content: Content) -> some View {
        if let destination {
            Button {
                Haptics.select()
                onOpen(destination)
            } label: {
                // A rounded outline around the whole tile rather than a
                // floating arrow in its corner. The arrow read as a separate
                // control sitting on the tile; an outline says the tile itself
                // is the target, which is what it is.
                content
                    .padding(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(LcdMode.current.accent.opacity(0.55), lineWidth: 2)
                    )
            }
            .buttonStyle(DexPressStyle(scale: 0.95))
        } else {
            content
        }
    }
}

public struct EntryDetailScreen: View {
    let entry: WineEntry
    let onSelectRelated: (WineEntry) -> Void
    /// Cross-links from the header tiles go to a filtered list rather than a
    /// single entry, so they need a route rather than a `WineEntry`.
    var onOpenRoute: (DexRoute) -> Void = { _ in }

    private let db = WineDatabase.shared
    @State private var bookmarks = BookmarkStore.shared
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue

    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    /// The web app caps linked lists at 8 rows.
    private static let linkedRowLimit = 8

    public init(
        entry: WineEntry,
        onSelectRelated: @escaping (WineEntry) -> Void,
        onOpenRoute: @escaping (DexRoute) -> Void = { _ in }
    ) {
        self.entry = entry
        self.onSelectRelated = onSelectRelated
        self.onOpenRoute = onOpenRoute
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
        .background(lcd.page)
        // Following a cross-link swaps the entry but keeps the same ScrollView,
        // so the new entry opened at the previous one's scroll offset — halfway
        // down a screen you had never seen. Keying on the id gives each entry a
        // fresh scroll view, which starts at the top.
        .id(entry.id)
    }

    // MARK: Hero

    /// Centred icon above a centred wordmark, on a faintly gridded green panel.
    private var hero: some View {
        VStack(spacing: 14) {
            EntryIconWell(entry: entry, size: 80, cornerRadius: 12)

            Text(entry.name.uppercased())
                .font(DexFont.retro(21))
                .foregroundStyle(lcd.text)
                .shadow(color: Color(dexHex: "#006400").opacity(0.8), radius: 0, x: 4, y: 4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            bookmarkButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            ZStack {
                lcd.heroWash
                DexGridBackground(spacing: 34, color: Color(dexHex: "#14532d"), opacity: 0.5)
            }
        )
        .overlay(alignment: .bottom) {
            lcd.accent.frame(height: 4)
        }
        .padding(.horizontal, -14)
        .padding(.bottom, 16)
    }

    /// Saved state lives on the entry screen rather than the list, so it is one
    /// tap from what you are reading and cannot be triggered by a mis-scroll.
    private var bookmarkButton: some View {
        let saved = bookmarks.contains(entry.id)
        return Button {
            Haptics.select()
            bookmarks.toggle(entry.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: saved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14, weight: .bold))
                Text(saved ? "SAVED" : "SAVE")
                    .font(DexFont.retro(10))
                    .tracking(2)
            }
            .foregroundStyle(saved ? .white : lcd.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(saved ? lcd.accent : lcd.buttonWell))
            .overlay(Capsule().strokeBorder(lcd.accent, lineWidth: 2))
        }
        .buttonStyle(DexPressStyle(scale: 0.94))
    }

    private var infoSection: some View {
        section("INFO", symbol: "book") {
            Text(entry.entryDescription)
                .font(DexFont.mono(18))
                .foregroundStyle(lcd.bodyText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)
                .padding(.vertical, 10)
                .background(alignment: .leading) {
                    // The reference marks body copy with a left accent rule.
                    lcd.accent.frame(width: 4)
                }
                .background(lcd.accent.opacity(0.06))
        }
    }

    // MARK: Three-tile header row

    @ViewBuilder
    private var headerTiles: some View {
        Group {
            switch entry {
            case .grape(let g):
                HStack(alignment: .top, spacing: 8) {
                    tile(label: "COLOR",
                         chip: chip(g.grapeType.rawValue.uppercased(), .colorType),
                         destination: .list(category: .grapes, filter: .type(g.grapeType.rawValue))) { tint in
                        DexIcon(iconID: db.icons.colorIcon(g.grapeType.rawValue.uppercased()), size: 32, color: tint)
                    }
                    tile(label: "TYPE",
                         chip: chip(EntryDisplay.grapeBodyLabel(g), .wineType, key: g.grapeStyle),
                         destination: .list(category: .grapes, filter: .type(g.grapeStyle))) { tint in
                        DexIcon(iconID: db.icons.bodyIcon(g.grapeBodyClass), size: 32, color: tint)
                    }
                    tile(label: "ORIGIN",
                         chip: chip(g.details.origin.uppercased(), .country, key: g.details.origin),
                         destination: .country(name: g.details.origin)) { _ in
                        FlagSwatch(country: g.details.origin)
                    }
                }

            case .region(let r):
                HStack(alignment: .top, spacing: 8) {
                    let keyGrape = r.details.notableGrapes.first
                    let keyGrapeEntry = keyGrape.flatMap { db.entry(named: $0) }
                    tile(label: "KEY GRAPE",
                         chip: chip((keyGrape ?? "N/A").uppercased(), .wineType, key: keyGrape ?? ""),
                         destination: keyGrapeEntry.map { .detail(entryID: $0.id) }) { _ in
                        keyGrapeIcon(keyGrape)
                    }
                    tile(label: "CLIMATE",
                         chip: chip((r.climate?.rawValue ?? "N/A").uppercased(), .climate, key: r.climate?.rawValue ?? ""),
                         destination: r.climate.map { .list(category: .regions, filter: .climate($0)) }) { tint in
                        DexIcon(iconID: db.icons.climateIcon(r.climate), size: 32, color: tint)
                    }
                    tile(label: "COUNTRY",
                         chip: chip(r.details.origin.uppercased(), .country, key: r.details.origin),
                         destination: .country(name: r.details.origin)) { _ in
                        FlagSwatch(country: r.details.origin)
                    }
                }

            case .style(let s):
                let cls = EntryDisplay.styleClass(name: s.common.name, classification: s.details.classification)
                let color = EntryDisplay.colorType(name: s.common.name)
                HStack(alignment: .top, spacing: 8) {
                    tile(label: "COLOR",
                         chip: chip(color.rawValue, .colorType, key: color.rawValue),
                         destination: .list(category: .grapes, filter: .type(color.rawValue))) { tint in
                        DexIcon(iconID: db.icons.colorIcon(color.rawValue), size: 32, color: tint)
                    }
                    tile(label: "CLASS",
                         chip: chip(cls.rawValue, .styleClass, key: cls.rawValue),
                         destination: .list(category: .styles, filter: .system(s.details.classification))) { tint in
                        DexIcon(iconID: db.iconID(for: entry), size: 32, color: tint)
                    }
                    if s.details.origin.lowercased() != "various" {
                        tile(label: "ORIGIN",
                             chip: chip(s.details.origin.uppercased(), .country, key: s.details.origin),
                             destination: .country(name: s.details.origin)) { _ in
                            FlagSwatch(country: s.details.origin)
                        }
                    }
                }

            case .flavor(let f):
                // Both tiles used to draw `db.iconID(for: entry)` — the entry's
                // own glyph — so CLASS and SUBCLASS were always the same picture
                // as each other and as the hero above them, and it changed with
                // whichever note you had opened. Each taxonomy level now owns a
                // glyph of its own; see `flavorClassIcons` in the manifest.
                HStack(alignment: .top, spacing: 8) {
                    tile(label: "CLASS",
                         chip: chip(f.details.classification, .flavorClass, key: f.details.classification),
                         destination: .list(category: .flavors, filter: .tasting(f.details.classification))) { tint in
                        DexIcon(iconID: db.icons.flavorClassIcon(f.details.classification), size: 32, color: tint)
                    }
                    tile(
                        label: "SUBCLASS",
                        chip: chip(EntryDisplay.humanize(f.details.subclass).uppercased(), .flavorSubclass, key: f.details.subclass)
                    ) { tint in
                        DexIcon(iconID: db.icons.flavorSubclassIcon(f.details.subclass), size: 32, color: tint)
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
            lcd.accent.frame(height: 4)
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
    /// `destination` makes the tile a cross-link. Nil leaves it inert rather
    /// than tappable-but-dead.
    private func tile<C: View>(
        label: String,
        chip: TileChip,
        destination: DexRoute? = nil,
        @ViewBuilder icon: (Color) -> C
    ) -> some View {
        let tint = Color(dexHex: db.palette.resolve(chip).text)
        return VStack(spacing: 5) {
            Text(label)
                .font(DexFont.retro(8))
                .foregroundStyle(lcd.accent)
            icon(tint)
                .frame(height: 34)
            // Wrap rather than shrink. `minimumScaleFactor` let each tile pick
            // its own effective size, so the three sat at three different
            // scales — the row read as inconsistent even though every label
            // was nominally 11pt. Chip labels carry soft hyphens (see
            // `EntryDisplay.hyphenated`), so even a single long word has
            // somewhere legal to break, at any screen width.
            ChipView(label: chip.label, chip: db.palette.resolve(chip))
                .lineLimit(3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .modifier(TileLink(destination: destination, onOpen: onOpenRoute))
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
            // Directly under the system that governs them, rather than at the
            // bottom of the screen below the grape list: the appellations *are*
            // that system's denominations, and reading them a section apart made
            // them look like an unrelated tag cloud.
            if let appellations = r.details.appellations, !appellations.isEmpty {
                chipSection("APPELLATIONS", symbol: "shield", names: appellations)
            }
            // Climate and soil are always shown for regions, even without data:
            // climate falls back to "Unknown Climate" and soils to a
            // climate-keyed triplet.
            climateSection(r)
            soilSection(r)
            linkedSection("NOTABLE GRAPES", symbol: "list.bullet", names: r.details.notableGrapes)

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

    /// Style sections vary by classification: METHOD shows KEY GRAPES, every
    /// other class shows NOTABLE GRAPES, and all of them show KEY REGIONS.
    ///
    /// TYPE used to show no grape list at all. That was faithful to the web app,
    /// which is where the omission comes from — but TYPE styles ("Full-Bodied
    /// Red", "Aromatic White") *do* carry `notableGrapes`, and they are the
    /// entries where the list matters most: a class defined by how the wine
    /// tastes rather than by where it is from is only useful once you know which
    /// grapes make it. The data was already there and simply was not drawn.
    ///
    /// BLEND is deliberately still excluded: its `notableGrapes` are the
    /// components of the blend, already named in the entry's own description,
    /// and listing them again as "notable" reads as a duplicate.
    @ViewBuilder
    private func styleRelatedSections(_ s: StyleEntry) -> some View {
        let cls = EntryDisplay.styleClass(name: s.common.name, classification: s.details.classification)

        switch cls {
        case .method:
            linkedSection("KEY GRAPES", symbol: "list.bullet", names: s.details.notableGrapes, limit: 6)
        case .style, .origin, .type:
            linkedSection("NOTABLE GRAPES", symbol: "list.bullet", names: s.details.notableGrapes, limit: 6)
        case .blend:
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
                            .foregroundStyle(lcd.text)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(lcd.surface)
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
            .background(lcd.surface)
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
                    // NOBLE is a crown on its own, not a crown capping three
                    // stars — the stars implied it was simply one rank above
                    // RARE rather than a different kind of thing.
                    if g.rarity == .noble {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Dex.yellow)
                    } else {
                        let filled = rarityRank(g.rarity)
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: index < filled ? "star.fill" : "star")
                                .font(.system(size: 11))
                                .foregroundStyle(index < filled ? Dex.yellow : Dex.stone700)
                        }
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

    /// The abbreviation in the chip, the spelled-out name beside it — the
    /// treatment `CountryScreen`'s APPELLATION SYSTEMS section already uses.
    ///
    /// The chip used to carry the full name. That made a chip five words wide
    /// which then wrapped to three lines, and it hid the abbreviation the bottle
    /// label actually prints — which is the thing worth recognising.
    private func systemSection(_ r: RegionEntry) -> some View {
        section("APPELLATION SYSTEM", symbol: "shield") {
            HStack(alignment: .top, spacing: 8) {
                // Keyed by the abbreviation either way: the palette tables are
                // indexed by `classification`, through the same table the list
                // tile uses, so an appellation is one colour everywhere.
                ChipView(
                    label: r.details.classification,
                    chip: db.palette.resolve(
                        chip(r.details.classification, .classification, key: r.details.classification)
                    )
                )
                Text(EntryDisplay.appellationName(
                    classification: r.details.classification,
                    country: r.details.origin
                ))
                .font(DexFont.mono(17))
                .foregroundStyle(Dex.stone400)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let state = r.details.state {
                    Text(state.uppercased())
                        .font(DexFont.mono(19))
                        .foregroundStyle(lcd.subtext)
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
                .foregroundStyle(lcd.bodyText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)
                .padding(.vertical, 8)
                .background(alignment: .leading) {
                    lcd.accent.frame(width: 4)
                }
                .background(lcd.accent.opacity(0.06))
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
                    .foregroundStyle(lcd.accent)
                Text(title)
                    .font(DexFont.retro(10))
                    .tracking(1.5)
                    .foregroundStyle(lcd.accent)
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

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

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
                    // Not `.white`: this row's ground is `lcd.surface`, which is
                    // white in light mode — the label was white-on-white and
                    // vanished. This is the row FLAVOR PROFILE, NOTABLE GRAPES
                    // and every other linked list is built from.
                    .foregroundStyle(resolved ? lcd.text : lcd.disabledText)
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
            .background(lcd.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(resolved ? Dex.stone700 : Dex.stone800, lineWidth: 1)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        .disabled(!resolved)
    }
}

/// Flag swatch used in the three-tile header row, and — larger — as the hero of
/// the country and state screens.
///
/// The size is a parameter rather than something the caller wraps in a `.frame`.
/// It used to be hard-coded at 52x32, and every call site that wanted a
/// different size put an outer frame around it: an outer frame does not resize
/// fixed content, so the country hero's `.frame(width: 96, height: 60)` was
/// simply centring a 52x32 flag in a 96x60 box, and the STATES rows' 40x26 box
/// was smaller than the flag it nominally sized.
public struct FlagSwatch: View {
    let country: String
    var width: CGFloat
    var height: CGFloat

    public init(country: String, width: CGFloat = 52, height: CGFloat = 32) {
        self.country = country
        self.width = width
        self.height = height
    }

    /// Scaled off the swatch so a hero-sized flag does not carry the same 3pt
    /// radius and 2pt border a row-sized one does.
    private var corner: CGFloat { max(width * 0.06, 3) }
    private var border: CGFloat { max(width * 0.04, 2) }

    public var body: some View {
        FlagImage(country: country)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(.white, lineWidth: border)
            )
    }
}
#endif
