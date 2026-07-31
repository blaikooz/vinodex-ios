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
    /// Raised when TRIED turns on, and again from MY RATING's EDIT.
    @State private var showingRating = false
    /// Which expandable sections are open (0.6.2, C2). Session-local:
    /// an expanded list is browsing state, not an answer.
    @State private var expandedSections: Set<String> = []
    /// Scroll position outlives the view — see `ScreenStateStore`.
    @State private var screens = ScreenStateStore.shared
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue

    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    private var screenKey: String { ScreenStateStore.detail(entry.id) }

    /// Coarser than the other screens': the category sections are built by a
    /// `@ViewBuilder` switch over the entry variant, so they share one anchor
    /// rather than each carrying its own. Landing at the top of the readout's
    /// body still beats landing at the top of the page.
    private enum Anchor {
        static let hero = "hero"
        static let tiles = "tiles"
        static let info = "info"
        static let sections = "sections"
    }

    private var anchorBinding: Binding<String?> {
        Binding(
            get: { screens.anchor(for: screenKey) },
            set: { screens.setAnchor($0, for: screenKey) }
        )
    }

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
                hero.id(Anchor.hero)
                headerTiles.id(Anchor.tiles)
                // Flavours were skipped while their blurb was a bare template
                // sentence. It now names the grapes the flavour derives from,
                // which is worth showing.
                if !entry.entryDescription.isEmpty {
                    infoSection.id(Anchor.info)
                }
                if entry.isTastable, bookmarks.contains(entry.id, on: .tried) {
                    myTasting
                }
                // Wrapped in a real container before being identified: the
                // builder returns a tuple of sections, and putting `.id()`
                // straight on that would collapse N stack children into one
                // view. The zero spacing and matching alignment make the extra
                // stack invisible.
                VStack(alignment: .leading, spacing: 0) {
                    categorySections
                }
                .id(Anchor.sections)
            }
            .scrollTargetLayout()
        }
        // Content margins rather than padding around the target layout — see
        // the note in `EncyclopediaListScreen`. The generous tail keeps the
        // last section clear of the footer, matching pb-20.
        .contentMargins(.horizontal, 14, for: .scrollContent)
        .contentMargins(.bottom, 72, for: .scrollContent)
        // Restores where this entry was left, and starts a never-seen entry at
        // the top — the stored anchor is keyed per entry id, so a cross-link to
        // a new entry has none. See `ScreenStateStore`.
        .scrollPosition(id: anchorBinding)
        .background(lcd.page)
        // Following a cross-link swaps the entry but keeps the same ScrollView,
        // so the new entry opened at the previous one's scroll offset — halfway
        // down a screen you had never seen. Keying on the id gives each entry a
        // fresh scroll view, which starts at the top.
        .id(entry.id)
        .overlay {
            if showingRating {
                RatingPrompt(
                    entryName: entry.name,
                    initial: bookmarks.rating(for: entry.id),
                    onSave: { stars, note in
                        bookmarks.setRating(
                            TriedRating(rating: stars, note: note, day: DailyPick.dayIndex()),
                            for: entry.id
                        )
                        showingRating = false
                    },
                    onSkip: { showingRating = false }
                )
            }
        }
        .animation(.easeOut(duration: 0.15), value: showingRating)
        // The recent trail (0.6.3, item 3). Keyed on the id so a cross-link —
        // which swaps the entry without tearing this view down — records the
        // new entry too; a bare `.onAppear` would have credited only the first
        // one of a chain. Coming *back* here re-fires it, which is correct: a
        // return visit is still the most recent thing you looked at.
        .task(id: entry.id) { RecentlyViewedStore.shared.record(entry.id) }
    }

    /// The journal line for a tried entry: your stars, your note, and the way
    /// to change them. Five interactive-sized stars, deliberately unlike the
    /// rarity row's three small read-only ones — two star rows on one screen
    /// must not read as the same instrument.
    private var myTasting: some View {
        section("MY RATING", symbol: "star.fill") {
            let rating = bookmarks.rating(for: entry.id)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= (rating?.rating ?? 0) ? "star.fill" : "star")
                            .font(.system(size: 18))
                            .foregroundStyle(star <= (rating?.rating ?? 0) ? Dex.yellow : lcd.disabledText)
                    }
                    Spacer(minLength: 8)
                    Button {
                        Haptics.select()
                        showingRating = true
                    } label: {
                        HStack(spacing: 6) {
                            // The edit pencil — the same glyph the profile's
                            // name row wears, so "change this" is one symbol
                            // everywhere.
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 13, weight: .bold))
                            Text(rating == nil ? "RATE" : "EDIT")
                                .font(DexFont.retro(10))
                                .tracking(1.5)
                        }
                        .foregroundStyle(lcd.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(lcd.buttonWell))
                        .overlay(Capsule().strokeBorder(lcd.accent, lineWidth: 2))
                    }
                    .buttonStyle(DexPressStyle(scale: 0.94))
                    .accessibilityLabel(rating == nil ? "Rate this entry" : "Edit your rating")
                }

                if let note = rating?.note, !note.isEmpty {
                    Text(note)
                        .font(DexFont.mono(18))
                        .foregroundStyle(lcd.bodyText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Hero

    /// Centred icon above a centred wordmark, on a faintly gridded green panel.
    ///
    /// The well is the scan's portrait now (v0.5.6) — nearly double its old
    /// 80pt, because the pixel art earns the space. Regions show the drawn
    /// country outline over the flag here too (v0.5.8, D1): 0.5.7 dropped the
    /// hero glyph while the glyph was still a borrowed badge, but the outline
    /// art *is* the place, so the hero wants it back — and it carries the
    /// region's red location dot (v0.5.9, C1), same as the country scan page.
    private var hero: some View {
        VStack(spacing: 14) {
            EntryIconWell(entry: entry, size: DexMetrics.heroWell, cornerRadius: 20, showsRegionDot: true)

            Text(entry.name.uppercased())
                .font(DexFont.retro(21))
                .foregroundStyle(lcd.text)
                .shadow(color: lcd.accent.opacity(0.55), radius: 0, x: 4, y: 4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            bookmarkButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            ZStack {
                lcd.heroWash
                DexGridBackground(spacing: 34, color: lcd.heroGrid, opacity: 0.5)
            }
        )
        .overlay(alignment: .bottom) {
            lcd.accent.frame(height: 4)
        }
        .padding(.horizontal, -14)
        .padding(.bottom, 16)
    }

    /// Shelf state lives on the entry screen rather than the list, so it is one
    /// tap from what you are reading and cannot be triggered by a mis-scroll.
    ///
    /// SAVE is universal; WANT and TRIED appear only on things you can drink a
    /// glass of (`isTastable`). Marking TRIED raises the rating prompt — the
    /// moment you say you drank it is the moment the note is freshest.
    private var bookmarkButton: some View {
        HStack(spacing: 8) {
            shelfCapsule(
                active: bookmarks.contains(entry.id),
                activeLabel: "SAVED", label: "SAVE",
                activeSymbol: "bookmark.fill", symbol: "bookmark"
            ) {
                Haptics.select()
                bookmarks.toggle(entry.id)
            }

            if entry.isTastable {
                shelfCapsule(
                    active: bookmarks.contains(entry.id, on: .wantToTry),
                    activeLabel: "WANTED", label: "WANT",
                    activeSymbol: "plus.circle.fill", symbol: "plus.circle"
                ) {
                    Haptics.select()
                    bookmarks.toggle(entry.id, on: .wantToTry)
                }

                shelfCapsule(
                    active: bookmarks.contains(entry.id, on: .tried),
                    activeLabel: "TRIED", label: "TRIED",
                    activeSymbol: "checkmark.circle.fill", symbol: "checkmark.circle"
                ) {
                    Haptics.select()
                    let added = bookmarks.toggle(entry.id, on: .tried)
                    if added { showingRating = true }
                }
            }
        }
    }

    private func shelfCapsule(
        active: Bool,
        activeLabel: String,
        label: String,
        activeSymbol: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: active ? activeSymbol : symbol)
                    .font(.system(size: 14, weight: .bold))
                Text(active ? activeLabel : label)
                    .font(DexFont.retro(10))
                    .tracking(1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            // `onAccent`, not white: white on the dark theme's mint accent is
            // the contrast failure the chip screen documents.
            .foregroundStyle(active ? lcd.onAccent : lcd.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(active ? lcd.accent : lcd.buttonWell))
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
                // KEY GRAPE rides alone on a full-width bar (0.6.x): grape
                // names are the longest strings in this row by far, and three
                // abreast they wrapped to three lines. Climate and country
                // keep the two-tile row below.
                VStack(spacing: 10) {
                    let keyGrape = r.details.notableGrapes.first
                    let keyGrapeEntry = keyGrape.flatMap { db.entry(named: $0) }
                    keyGrapeBar(name: keyGrape, entry: keyGrapeEntry)
                    HStack(alignment: .top, spacing: 8) {
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
                         // The *inferred* class, not the raw classification
                         // field (0.6.x): filtering on the raw "STYLE" string
                         // opened a stale near-everything list, where the chip
                         // plainly names ORIGIN/TYPE/METHOD/BLEND.
                         chip: chip(cls.rawValue, .styleClass, key: cls.rawValue),
                         destination: .list(category: .styles, filter: .system(cls.rawValue))) { tint in
                        // The class's own glyph (v0.5.8, B2) — this drew the
                        // entry's generic glyph, which left the drawn
                        // styleclass art with no place to render at all: in
                        // rows the style portrait covers the glyph, so this
                        // tile is where the class icon lives. Drawn at 40
                        // (0.6.x): at 32 the blend art's transparent margins
                        // left it reading smaller than its siblings.
                        DexIcon(iconID: db.icons.styleClassIcons[cls.rawValue] ?? db.icons.fallback, size: 40, color: tint)
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
                        chip: chip(EntryDisplay.humanize(f.details.subclass).uppercased(), .flavorSubclass, key: f.details.subclass),
                        // A cross-link like CLASS above it: tapping runs a
                        // filter search over the subclass's own flavours.
                        destination: .list(category: .flavors, filter: .flavorSubclass(f.details.subclass))
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

    /// KEY GRAPE as a full-width flat bar (0.6.x) — see the region header
    /// note. Same chip palette as the old tile, but the name gets a whole
    /// line, so "Cabernet Sauvignon" no longer wraps to three.
    @ViewBuilder
    private func keyGrapeBar(name: String?, entry keyGrapeEntry: WineEntry?) -> some View {
        let chipData = chip((name ?? "N/A").uppercased(), .wineType, key: name ?? "")
        let resolved = db.palette.resolve(chipData)
        HStack(spacing: 10) {
            // 56, up from 34 (0.6.4, D2): at row-icon size the bunch sprite
            // read as a chip decoration; the bar is the region's headline
            // fact, so its hero earns hero scale.
            if let keyGrapeEntry {
                EntryIconWell(entry: keyGrapeEntry, size: 56, cornerRadius: 8)
            } else {
                DexIcon(iconID: db.icons.fallback, size: 44, color: Dex.stone600)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("KEY GRAPE")
                    .font(DexFont.retro(8))
                    .foregroundStyle(lcd.accent)
                Text(chipData.label)
                    .font(DexFont.retro(13))
                    .foregroundStyle(Color(dexHex: resolved.text))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 4)
            if keyGrapeEntry != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(lcd.subtext)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        // No box (0.6.2, C3): the icon well and chip-coloured name carry the
        // bar; a filled plate behind them read as a grey slab over the hero.
        .modifier(TileLink(
            destination: keyGrapeEntry.map { .detail(entryID: $0.id) },
            onOpen: onOpenRoute
        ))
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
    ///
    /// Icon and label share **one** coloured chip (0.6.4, C1): the icon used
    /// to float bare above a text-only `ChipView`, so each tile read as two
    /// parts — a loose glyph and a pill. The glyph keeps its position, above
    /// the text, but the chip's fill and border now wrap the pair.
    private func tile<C: View>(
        label: String,
        chip: TileChip,
        destination: DexRoute? = nil,
        @ViewBuilder icon: (Color) -> C
    ) -> some View {
        let resolved = db.palette.resolve(chip)
        let tint = Color(dexHex: resolved.text)
        return VStack(spacing: 5) {
            Text(label)
                .font(DexFont.retro(8))
                .foregroundStyle(lcd.accent)
            VStack(spacing: 6) {
                icon(tint)
                    .frame(height: 40)
                // Wrap rather than shrink. `minimumScaleFactor` let each tile
                // pick its own effective size, so the three sat at three
                // different scales — the row read as inconsistent even though
                // every label was nominally 11pt. Chip labels carry soft
                // hyphens (see `EntryDisplay.hyphenated`), so even a single
                // long word has somewhere legal to break, at any screen width.
                Text(
                    EntryDisplay.hyphenated(
                        chip.label.replacingOccurrences(of: "_", with: " ").uppercased()
                    )
                )
                    .font(DexFont.retro(11))
                    .foregroundStyle(tint)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6).fill(Color(dexHex: resolved.bg))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(dexHex: resolved.border), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .modifier(TileLink(destination: destination, onOpen: onOpenRoute))
    }

    // MARK: Category sections

    @ViewBuilder
    private var categorySections: some View {
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

    /// The rarity readout, at display size rather than row size. The chip and
    /// the stars were list-row furniture (11pt chip, 11pt stars) on a screen
    /// where rarity is one of the two things a collector opens the scan for —
    /// it read as a footnote next to the CHARACTERISTICS bars above it.
    private func raritySection(_ g: GrapeEntry) -> some View {
        let chip = db.palette.rarityChips[g.rarity.rawValue]
            ?? Palette.Chip(bg: "#3f3f46", border: "#52525b", text: "#e4e4e7")

        return section("RARITY", symbol: "star") {
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
            section(title, symbol: symbol) {
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
