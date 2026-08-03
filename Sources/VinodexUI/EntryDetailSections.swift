#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The stack of readout sections below an entry's hero and header tiles —
/// rarity and stats for a grape, appellation system and soil for a region, and
/// the linked-entry lists every category ends with.
///
/// Split out of `EntryDetailScreen` (AUDIT **M30**), which was a single
/// ~930-line `View`. The audit filed that file under "each bundle 8+ types with
/// clean seams" and was wrong about it — there are four top-level types, and
/// have been since the audit ran. The real seam is this one: everything below
/// reaches for exactly four things from the screen around it, which is why it
/// can move without any of them becoming shared mutable state.
///
/// `expandedSections` came with the cluster. It was `@State` on the parent
/// while only these builders ever read or wrote it; here it sits with the code
/// that uses it, and its identity is stable because this view occupies one
/// fixed position in the parent's stack.
struct EntryDetailSections: View {
    let entry: WineEntry
    let db: WineDatabase
    let lcd: LcdMode
    let onSelectRelated: (WineEntry) -> Void

    /// Which `linkedSection` titles are expanded (0.6.2, C2). Keyed by title
    /// rather than by index so reordering the sections cannot silently expand
    /// a different one.
    @State private var expandedSections: Set<String> = []

    /// Rows beyond this are dropped rather than scrolled — see `linkedSection`.
    private static let linkedRowLimit = 8


    @ViewBuilder
    var body: some View {
        switch entry {
        case .grape(let g):
            // Rarity leads (v0.5.6): it is the one-glance fact, and it was
            // buried under five stat bars.
            raritySection(g)
            statsSection(g)
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
            linkedSection("KEY GRAPES", symbol: "list.bullet", names: s.details.notableGrapes, expandable: true)
        case .style, .origin, .type:
            linkedSection("NOTABLE GRAPES", symbol: "list.bullet", names: s.details.notableGrapes, expandable: true)
        case .blend:
            EmptyView()
        }

        linkedSection("KEY REGIONS", symbol: "mappin.and.ellipse", names: s.details.keyRegions, expandable: true)
    }

    /// A single large chip carrying the climate's display name and colours.
    private func climateSection(_ r: RegionEntry) -> some View {
        let meta = r.climate.flatMap { db.palette.climates[$0.rawValue] }
        let colors = meta?.colors ?? db.palette.namedChips["CLIMATE"]
            ?? Palette.Chip(bg: "#14532d", border: "#22c55e", text: "#86efac")

        return DexSection("CLIMATE", symbol: "wind") {
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

        return DexSection("SOIL COMPOSITION", symbol: "mountain.2") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                spacing: 10
            ) {
                ForEach(soils, id: \.self) { soil in
                    let visual = db.icons.soilIcon(soil)
                    VStack(spacing: 8) {
                        // Sized up (0.6.x): at 46/24 the drawn soil art was
                        // mostly margin — the square is the tile's whole point.
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(dexHex: "#0b0f19"))
                            .frame(width: 68, height: 68)
                            .overlay(
                                DexIcon(iconID: visual.icon, size: 52, color: Color(dexHex: visual.color))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color(dexHex: visual.color), lineWidth: 2)
                            )
                        Text(soil.uppercased())
                            .font(DexFont.retro(10))
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

    /// Per-stat bar colours, matching the reference exactly. Tokens rather than
    /// inline hexes (AUDIT **L33**) — see `Dex.statBody` and friends. Still
    /// keyed on the authored bar label, because that is what the data carries;
    /// the fallback below is `Dex.statBody` for the same reason it always was.
    private static let statColors: [String: Color] = [
        "BODY": Dex.statBody,
        "ACID": Dex.statAcid,
        "TANNIN": Dex.statTannin,
        "AROMATICS": Dex.statAromatics,
        "COLOR": Dex.statColor,
    ]

    private func statsSection(_ g: GrapeEntry) -> some View {
        DexSection("CHARACTERISTICS", symbol: "waveform.path.ecg") {
            VStack(spacing: 14) {
                ForEach(g.grapeCharacteristics.bars, id: \.label) { bar in
                    StatBar(
                        label: bar.label,
                        value: bar.value,
                        fill: Self.statColors[bar.label] ?? Dex.statBody
                    )
                }
            }
            .padding(12)
            .background(lcd.surface)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Dex.stone800, lineWidth: 1))
        }
    }

    /// The rarity readout, at display size rather than row size. The chip and
    /// the stars were list-row furniture (11pt chip, 11pt stars) on a screen
    /// where rarity is one of the two things a collector opens the scan for —
    /// it read as a footnote next to the CHARACTERISTICS bars above it.
    private func raritySection(_ g: GrapeEntry) -> some View {
        let chip = db.palette.rarityChips[g.rarity.rawValue]
            ?? Palette.Chip(bg: "#3f3f46", border: "#52525b", text: "#e4e4e7")

        return DexSection("RARITY", symbol: "star") {
            HStack(spacing: 8) {
                Text(g.rarity.rawValue)
                    .font(DexFont.retro(16))
                    .tracking(1.5)
                    .foregroundStyle(Color(dexHex: chip.text))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6).fill(Color(dexHex: chip.bg))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(dexHex: chip.border), lineWidth: 2)
                    )
                Spacer()
                HStack(spacing: 7) {
                    // NOBLE is a crown on its own, not a crown capping three
                    // stars — the stars implied it was simply one rank above
                    // RARE rather than a different kind of thing. GODFORSAKEN
                    // (0.6.2, A1) sits above even that. Its emblem is a
                    // cursed-gold skull (0.6.4, D3, was a flame) — a drawn
                    // glyph via the icon pipeline, since SF Symbols carries no
                    // skull at the iOS 17 target; the id ships in the
                    // manifest's rasterisation list.
                    if g.rarity == .godforsaken {
                        DexIcon(
                            iconID: "game-icons:death-skull",
                            size: 28,
                            color: Color(dexHex: "#ca8a04"),
                            outlined: false
                        )
                        .shadow(color: Color(dexHex: "#ca8a04").opacity(0.6), radius: 4)
                    } else if g.rarity == .noble {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Dex.yellow)
                            .shadow(color: Dex.yellow.opacity(0.55), radius: 4)
                    } else {
                        let filled = rarityRank(g.rarity)
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: index < filled ? "star.fill" : "star")
                                .font(.system(size: 20))
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
        // Never reaches the star row — godforsaken has its own emblem — but
        // the ladder should still rank it truthfully.
        case .godforsaken: 5
        }
    }

    /// The abbreviation in the chip, the spelled-out name beside it — the
    /// treatment `CountryScreen`'s APPELLATION SYSTEMS section already uses.
    ///
    /// The chip used to carry the full name. That made a chip five words wide
    /// which then wrapped to three lines, and it hid the abbreviation the bottle
    /// label actually prints — which is the thing worth recognising.
    private func systemSection(_ r: RegionEntry) -> some View {
        DexSection("APPELLATION SYSTEM", symbol: "shield") {
            HStack(alignment: .top, spacing: 8) {
                // Keyed by the abbreviation either way: the palette tables are
                // indexed by `classification`, through the same table the list
                // tile uses, so an appellation is one colour everywhere.
                ChipView(
                    label: r.details.classification,
                    // Spelled out rather than through the parent screen's
                    // two-line `chip(_:_:key:)` shorthand, which exists for the
                    // header-tile row's dozen call sites and is the only thing
                    // this file would otherwise have needed from it.
                    chip: db.palette.resolve(
                        TileChip(
                            label: r.details.classification,
                            key: r.details.classification,
                            table: .classification
                        )
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
            DexSection("FLAVOR PROFILE", symbol: "drop") {
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
            db: db,
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

    /// Full-width rows, as the reference renders related entries — chips are
    /// reserved for short metadata like appellations.
    @ViewBuilder
    private func linkedSection(
        _ title: String,
        symbol: String,
        names: [String],
        limit: Int = linkedRowLimit,
        expandable: Bool = false
    ) -> some View {
        if !names.isEmpty {
            DexSection(title, symbol: symbol) {
                VStack(spacing: 8) {
                    // Expandable sections (0.6.2, C2) show three and offer
                    // the rest behind a tab; capped ones keep the hard limit.
                    let expanded = expandedSections.contains(title)
                    let shown = expandable
                        ? (expanded ? names : Array(names.prefix(3)))
                        : Array(names.prefix(limit))
                    ForEach(shown, id: \.self) { name in
                        linkedRow(name)
                    }
                    if expandable && names.count > 3 {
                        Button {
                            Haptics.select()
                            withAnimation(.easeOut(duration: 0.2)) {
                                if expanded {
                                    expandedSections.remove(title)
                                } else {
                                    expandedSections.insert(title)
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .bold))
                                Text(expanded ? "SHOW FEWER" : "EXPAND ALL (\(names.count))")
                                    .font(DexFont.retro(10))
                                    .tracking(1)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(lcd.accent)
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(lcd.well))
                            .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 2))
                        }
                        .buttonStyle(DexPressStyle(scale: 0.98))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func linkedRow(_ name: String) -> some View {
        let target = db.entry(named: name)
        LinkedRow(
            db: db,
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
            DexSection(title, symbol: symbol) {
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
}
#endif
