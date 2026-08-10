#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The stylised cards B1–B3 export (0.7.8, B).
///
/// ## Why these are a still frame and not `DeviceChassis`
///
/// B3 asks for the card to be "framed with the Vinodex device chassis", and the
/// tempting reading is to put `DeviceChassis` itself through `ImageRenderer`.
/// That was tried on paper and rejected, because rendering it off-screen is not
/// the same as displaying it, and it fails in ways that would ship silently:
///
/// - Its `body` opens `GeometryReader { geo in … geo.safeAreaInsets.top }`.
///   `ImageRenderer` supplies no safe-area insets, so the island strip collapses
///   to its minimum and the whole vertical layout differs from the device.
/// - `StretchedWordmark` measures itself in `onAppear` and stores the result in
///   `@State`. A one-shot render never runs `onAppear`, so the measurement stays
///   `.zero` and the wordmark draws unstretched.
/// - `MarqueeBanner`'s text is populated by `task`/`onChange` into `@State`, so
///   the marquee would export **blank**.
/// - `PulseGlow` animates `@State` with a repeating `withAnimation`; in a single
///   frame every lamp renders at its dim extreme.
/// - `Screensaver` and `MarqueeLampChooser` branch on live app state, so an
///   export could catch the chooser open.
///
/// Every one of those is a real defect in an image somebody posts. So the card
/// takes the *tokens* rather than the view: `ChassisLook` for the shell and its
/// parts, `LcdMode` for the panel, the real `ChamferedPanel` silhouette (made
/// public for this), and `ScanlineOverlay`. The result is deterministic, and it
/// still reads as the user's own device because every colour on it is theirs.
struct ShareCardFrame<Content: View>: View {
    let caption: String
    @ViewBuilder let content: () -> Content

    /// Resolved from `UserDefaults` rather than `@AppStorage`. The card is
    /// rendered off-screen from a call site, not mounted in a view tree, and a
    /// plain read is one less thing depending on the renderer's environment.
    private var build: DeviceBuild { DeviceBuild.active() }
    private var look: ChassisLook { ChassisLook(build: build) }
    private var lcd: LcdMode { LcdMode.current }

    var body: some View {
        ZStack {
            look.underlay

            VStack(spacing: 0) {
                screen
                bottomStrip
            }
            .padding(16)
            .background(
                ChamferedPanel(corner: 26, chamfer: 18)
                    .fill(look.body)
                    .overlay(
                        ChamferedPanel(corner: 26, chamfer: 18)
                            .strokeBorder(look.panelEdge, lineWidth: 2)
                    )
            )
            .padding(18)
        }
    }

    /// The LCD, with the same monochrome pass `DeviceChassis.innerBezel`
    /// applies — a card exported from an AMBER device should be amber, because
    /// the point of carrying the user's skin onto the card is that it is their
    /// device that shows up in somebody else's feed.
    private var screen: some View {
        ZStack {
            lcd.panelGround
            content()
                .padding(14)
            ScanlineOverlay()
                .opacity(DexMetrics.scanlineOpacity)
        }
        .grayscale(lcd.monochromeTint == nil ? 0 : 1)
        .colorMultiply(lcd.monochromeTint ?? .white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Dex.stone800, lineWidth: 3)
        )
    }

    /// The wordmark, the caption and the running version.
    ///
    /// `AppVersion.display` rather than a literal: this string leaves the
    /// device, and `AppVersion.placeholders` exists because xtool stamps a
    /// `1.0.0` that is not true. A card claiming a version the build never
    /// chose is exactly the mistake that denylist was written for.
    private var bottomStrip: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // `grill`, which is the ink the device's own bottom strip prints its
            // wordmark in — see `StretchedWordmark(ink: skin.grill)`. Not
            // `userMark`: that is a `SkinMark?`, an optional *emblem*, not a
            // colour, and it is the shell's badge rather than its lettering.
            Text(ShareCard.wordmark)
                .font(DexFont.retro(15))
                .tracking(3)
                .foregroundStyle(look.grill)

            Text(caption)
                .font(DexFont.mono(12))
                .foregroundStyle(look.grill.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 4)

            Text(AppVersion.display)
                .font(DexFont.mono(12))
                .foregroundStyle(look.grill.opacity(0.65))
        }
        .padding(.top, 12)
        .padding(.horizontal, 2)
    }
}

// MARK: - B1, an encyclopedia entry

/// One catalog entry as a card.
///
/// **A scan readout since 0.8.5 (G1).** Through 0.8.4 this was art, a name, an
/// origin and five lines of prose — which is a book jacket, and the thing being
/// shared is a *dex entry*. G1 asks for the entry's attributes, its country
/// flag, its rarity and its flavour profile, and the argument for all four is
/// the same one: a card that shows only what the entry is *called* is a card
/// nobody can read anything off. What a person posting this wants to say is
/// "look what I found and look what it is like".
///
/// The prose pays for it, dropping from five lines to two. That is the trade
/// and it is deliberate: the description is the one thing on the old card that
/// the *link* also carries, and two lines still set the scene.
///
/// **Everything here degrades.** A flavour has no rarity, a grape has no flag
/// where its country has no art, a region has no stat bars — so each block is a
/// `@ViewBuilder` that renders nothing rather than a placeholder, and the
/// layout closes up. That is why the stack is a `VStack` with a trailing
/// `Spacer` rather than a fixed grid: four categories with four different
/// amounts to say cannot share a template.
struct EntryShareCard: View {
    let entry: WineEntry

    private let db = WineDatabase.shared

    private var lcd: LcdMode { LcdMode.current }

    var body: some View {
        ShareCardFrame(caption: entry.category.rawValue) {
            VStack(alignment: .leading, spacing: 9) {
                header

                // Rarity and the headline attributes, on one wrapping row of
                // chips. Chips rather than a table because the set is ragged —
                // a grape brings colour, body and type, a region brings its
                // climate, a flavour brings its family — and a table would have
                // to draw empty cells for whichever the entry does not have.
                attributeChips

                statBars
                flavourProfile

                // Trimmed rather than scrolled: a card is a fixed rectangle and
                // an entry's prose is not. `lineLimit` does the cut so the
                // sentence ends where the renderer says it does.
                Text(entry.entryDescription)
                    .font(DexFont.mono(12))
                    .foregroundStyle(lcd.bodyText)
                    .lineSpacing(1)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Art on the left, name and origin on the right, with the flag beside the
    /// origin.
    ///
    /// The well was centred and 104pt through 0.8.4, which cost the card its
    /// whole top third for a picture that is also the first thing in the share
    /// sheet's own preview. Set beside the name it does the same work in half
    /// the height, and the name gets somewhere to be.
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            EntryIconWell(entry: entry, size: 82, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.name)
                    .font(DexFont.retro(19))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)

                if let origin = entry.origin, !origin.isEmpty {
                    HStack(spacing: 6) {
                        // The flag is the country's, and `FlagLoader` answers
                        // nil for a country with no art — so this asks the
                        // manifest first rather than drawing `FlagImage`'s
                        // stone fallback, which on a card reads as a missing
                        // image rather than as a country nobody drew.
                        if db.icons.flagSlug(for: origin) != nil {
                            FlagImage(country: origin)
                                .frame(width: 22, height: 15)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                                )
                        }
                        Text(origin.uppercased())
                            .font(DexFont.retro(11))
                            .tracking(1.5)
                            .foregroundStyle(lcd.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Rarity first, then whatever else this category carries.
    @ViewBuilder
    private var attributeChips: some View {
        let chips = attributes
        if !chips.isEmpty {
            // A wrapping row without a layout: at 360pt and 9pt type these fit
            // on two lines for every entry in the catalog, and `LazyVGrid` with
            // adaptive columns is the one arrangement in SwiftUI that wraps
            // without measuring. Three columns because the widest chip label in
            // the set is GODFORSAKEN.
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3),
                spacing: 5
            ) {
                ForEach(chips) { chip in
                    Text(chip.label)
                        .font(DexFont.retro(9))
                        .tracking(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(chip.text)
                        .background(RoundedRectangle(cornerRadius: 4).fill(chip.bg))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(chip.border, lineWidth: 1)
                        )
                }
            }
        }
    }

    /// The attribute set for this entry, in the order the detail screen shows
    /// them — rarity, then what the category has.
    ///
    /// Reads the generated palette rather than choosing colours here, so a chip
    /// on the card is the same colour as the same chip on the scan. A facet with
    /// no palette row falls back to the LCD's own surface, which is the
    /// unstyled-but-present state rather than a crash.
    private var attributes: [AttributeChip] {
        var out: [AttributeChip] = []

        func add(_ label: String, _ chip: Palette.Chip? = nil) {
            let trimmed = label.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            // Keyed by position, not by text: a grape whose body class and wine
            // type happen to read the same word would otherwise give `ForEach`
            // two rows with one id, which SwiftUI resolves by dropping one.
            out.append(
                AttributeChip(id: out.count, label: trimmed.uppercased(), palette: chip, lcd: lcd)
            )
        }

        if let rarity = entry.rarity {
            add(rarity.rawValue, db.palette.rarityChips[rarity.rawValue])
        }
        switch entry {
        case .grape(let g):
            add(g.grapeType.rawValue, db.palette.colorTypeChips[g.grapeType.rawValue])
            add(g.grapeBodyClass)
            if let wineType = g.wineType {
                add(wineType, db.palette.wineTypeChips[wineType])
            }
        case .region(let r):
            if let climate = entry.climate {
                add(climate.rawValue)
            }
            add(r.details.classification, db.palette.classificationChips[r.details.classification])
        case .style(let s):
            add(s.details.classification, db.palette.styleClassChips[s.details.classification])
            if let body = s.details.body {
                add(body)
            }
        case .flavor(let f):
            add(
                f.details.subclass.replacingOccurrences(of: "_", with: " "),
                db.palette.flavorSubclassChips[f.details.subclass]
            )
            add(f.details.classification, db.palette.flavorClassChips[f.details.classification])
        case .continent:
            break
        }
        return out
    }

    /// The five characteristic bars, for the one category that has them.
    ///
    /// Drawn at a third of the detail screen's height and with no numbers: at
    /// card size the *shape* of the five is the information — a tannic,
    /// full-bodied red reads as a staircase — and five labelled rows of digits
    /// would take the space the flavours need.
    @ViewBuilder
    private var statBars: some View {
        if case .grape(let g) = entry {
            VStack(spacing: 3) {
                ForEach(g.grapeCharacteristics.bars, id: \.label) { bar in
                    HStack(spacing: 6) {
                        Text(bar.label)
                            .font(DexFont.retro(8))
                            .tracking(0.8)
                            .foregroundStyle(lcd.subtext)
                            .frame(width: 62, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(lcd.well)
                                Capsule()
                                    .fill(lcd.accent)
                                    .frame(width: max(0, geo.size.width * bar.value / 5))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }

    /// The tasting notes, each in its own colour.
    ///
    /// `TastingNote.color` is authored per note in `shared/`, which is what
    /// makes this worth putting on a card at all: six chips in six colours say
    /// what a wine tastes like faster than six words do, and they are the same
    /// six colours the scan shows.
    @ViewBuilder
    private var flavourProfile: some View {
        let notes = Array(entry.tastingProfile.prefix(6))
        if !notes.isEmpty {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3),
                spacing: 5
            ) {
                ForEach(notes) { note in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(dexHex: note.color))
                            .frame(width: 7, height: 7)
                        Text(note.note.uppercased())
                            .font(DexFont.retro(8))
                            .tracking(0.6)
                            .foregroundStyle(lcd.bodyText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

/// One attribute chip's three colours, resolved once (0.8.5, G1).
///
/// The palette's own row where the generator has one, so a chip on the card is
/// the same colour as the same chip on the scan; the LCD's surface where it does
/// not, which is the unstyled-but-present state rather than a gap. Resolved into
/// `Color` here rather than carried as hex, because `Palette.Chip` is a Core
/// type that knows nothing about `LcdMode` and a neutral fallback would
/// otherwise have to be written as three hard-coded strings.
private struct AttributeChip: Identifiable {
    let id: Int
    let label: String
    let bg: Color
    let border: Color
    let text: Color

    init(id: Int, label: String, palette: Palette.Chip?, lcd: LcdMode) {
        self.id = id
        self.label = label
        if let palette {
            bg = Color(dexHex: palette.bg)
            border = Color(dexHex: palette.border)
            text = Color(dexHex: palette.text)
        } else {
            bg = lcd.surface
            border = lcd.surfaceEdge
            text = lcd.subtext
        }
    }
}

// MARK: - B2, the player's profile

/// The passport as a card: who you are, rank, completion, five counts, the streak.
///
/// **A stat card rather than a progress bar with numbers under it (0.8.5, G2).**
/// Through 0.8.4 this was anonymous — a rank, a percentage and four grey tiles —
/// which made it a screenshot of a progress meter rather than a thing with a
/// person's name on it. G2 asks for the profile photo and name, coloured stats
/// and glyphs, and the point of all three is the same: the card is the one image
/// this app produces that says *whose* collection this is.
///
/// **The photo and the name are read here, not passed in, and that is a
/// deviation worth stating.** `ShareCard.Profile` is a Core type on the rule
/// that "the numbers are the part that can be wrong" — a count printing one
/// short is a data bug and Core is where Linux can test it. A name and an avatar
/// are neither: the name is a `@AppStorage` string the user typed, and the
/// avatar is a `UIImage` off disk, which Core cannot hold at all. Putting either
/// into the model would have made it non-`Sendable` or non-`Equatable` for no
/// testable gain. So they are read the way `ShareCardFrame` already reads the
/// skin and the screen mode: off the same defaults the live device reads.
struct ProfileShareCard: View {
    let card: ShareCard.Profile

    /// The name the user gave themselves on the USER screen, or nothing.
    @AppStorage(UserProfile.displayNameKey) private var displayName = ""

    private var lcd: LcdMode { LcdMode.current }

    var body: some View {
        ShareCardFrame(caption: card.device) {
            VStack(alignment: .leading, spacing: 9) {
                identity

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(card.completionPercent)%")
                        .font(DexFont.retro(34))
                        .foregroundStyle(lcd.text)
                    Text("COLLECTED")
                        .font(DexFont.retro(10))
                        .tracking(1.5)
                        .foregroundStyle(lcd.subtext)
                    Spacer(minLength: 0)
                    Text("\(card.triedTotal)/\(card.collectible)")
                        .font(DexFont.mono(12))
                        .foregroundStyle(lcd.subtext)
                }

                bar

                // Five, not four: CONTINENTS has been carried on
                // `ShareCard.Profile` since 0.7.8 and drawn nowhere, which is
                // the smallest possible version of the gap G2 is about.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                    stat("GRAPES", "\(card.triedGrapes)/\(card.totalGrapes)",
                         symbol: EntryCategory.grapes.marqueeSymbol, tint: Color(dexHex: "#a855f7"))
                    stat("STYLES", "\(card.triedStyles)/\(card.totalStyles)",
                         symbol: EntryCategory.styles.marqueeSymbol, tint: Color(dexHex: "#f97316"))
                    stat("COUNTRIES", "\(card.countries)",
                         symbol: "flag.fill", tint: Dex.yellow)
                    stat("CONTINENTS", "\(card.continents)",
                         symbol: EntryCategory.continents.marqueeSymbol, tint: Dex.blue)
                    stat("STAMPS", "\(card.badgesEarned)/\(card.badgesTotal)",
                         symbol: "seal.fill", tint: Color(dexHex: "#10b981"))
                    stat("STREAK", card.streak > 0 ? "\(card.streak)" : "—",
                         symbol: DexGlyph.challenge, tint: Color(dexHex: "#ef4444"))
                }

                if card.bestStreak > 0 {
                    Text("BEST STREAK  \(card.bestStreak)")
                        .font(DexFont.retro(10))
                        .tracking(1)
                        .foregroundStyle(lcd.accent)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The avatar, the name and the rank.
    ///
    /// The photo is circular and ringed in the LCD's accent so it reads as a
    /// part of the readout rather than as a photograph dropped on it — the same
    /// treatment `ProfileAvatar` gives it on the USER screen. A player who has
    /// set no photo gets the figure glyph, and one who has set no name gets the
    /// rank promoted into the name's slot rather than an empty line, because a
    /// blank where a name goes reads as a bug and an unnamed cellar does not.
    private var identity: some View {
        HStack(spacing: 10) {
            Group {
                if let image = AvatarStore.shared.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        lcd.well
                        Image(systemName: "person.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(lcd.subtext)
                    }
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(lcd.accent.opacity(0.8), lineWidth: 2))

            VStack(alignment: .leading, spacing: 3) {
                let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                Text(name.isEmpty ? card.rank : name.uppercased())
                    .font(DexFont.retro(17))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if !name.isEmpty {
                    Text(card.rank)
                        .font(DexFont.retro(10))
                        .tracking(1.2)
                        .foregroundStyle(lcd.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(lcd.well)
                Capsule()
                    .fill(lcd.accent)
                    .frame(width: max(0, geo.size.width * card.completion))
            }
        }
        .frame(height: 10)
    }

    /// One stat tile: a glyph in its own colour, the value, the label.
    ///
    /// **The tints are `PassportScreen`'s, deliberately restated rather than
    /// shared.** GRAPES is the menu tile's purple, STYLES its orange, COUNTRIES
    /// and CONTINENTS the yellow and blue the passport already gives them — so a
    /// player who has just looked at their passport recognises the card as the
    /// same six facts. The two this card adds, STAMPS and STREAK, take the
    /// colours those subjects wear elsewhere in the app: the passport's green
    /// and the daily challenge's red. Restated because `PassportScreen`'s table
    /// is `private` and lives on a view, and hoisting a colour table out of a
    /// screen to serve one card is a bigger change than G2 asks for — flagged
    /// here so the next person to move one moves both.
    private func stat(_ label: String, _ value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(DexFont.retro(14))
                    .foregroundStyle(lcd.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Text(label)
                .font(DexFont.retro(8))
                .tracking(0.8)
                .foregroundStyle(lcd.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 5).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(tint.opacity(0.45), lineWidth: 1)
        )
    }
}

// MARK: - B3, a passport milestone

/// "SOMMELIER UNLOCKED", "42/171 GRAPES COLLECTED".
///
/// ## The card carries the stamp (0.8.8, F1)
///
/// Every stamp has had drawn art since 0.8.7's A1 emptied
/// `undrawnStampStems` — a whole franked object, perforation and denomination
/// and ink, which is what the collection tile shows, what the back plate holds
/// and what `StampUnlockedPrompt` presses onto the screen when you earn one.
/// The share card was the one surface that did not show it. It drew
/// `stamp.fallbackSymbol` at 62pt in `lcd.accent` — the field whose own doc
/// comment calls it "an SF Symbol standing in until the drawn glyph exists" —
/// so the picture a player sent to somebody else was the placeholder, in the
/// screen's colour rather than the stamp's, for an object they had just been
/// shown twice in its real form.
///
/// **`BackPlateStampView`, not a fourth drawing of a stamp.** That view already
/// resolves art-or-fallback, wears `.worn(id:)` and carries its contact shadow,
/// and it is what both other surfaces call. Passing the stamp itself rather
/// than a symbol name is what makes `stamp.colorHex`, `stamp.denomination` and
/// `stamp.artStem` reach this card at all — three fields the share path had
/// never consulted.
///
/// **The symbol parameter stays** and is not merely vestigial: `stamp` is
/// optional because `ShareCard.Achievement` is a passport milestone in general,
/// not a stamp — `.collected` builds "42/171 GRAPES COLLECTED", which has no
/// stamp behind it and would have nothing to draw. A milestone with no stamp
/// keeps the symbol it always had.
///
/// Sized 168x152 against `StampFrame`'s 1.1 aspect, which is what the
/// collection tile (128x116) and the unlock prompt (132x120) use. Larger than
/// both because this render is 3x into 1080x1350 and the stamp is the subject
/// here rather than one tile of eight.
struct AchievementShareCard: View {
    let achievement: ShareCard.Achievement
    var symbol: String = "rosette"
    /// The stamp this milestone is, when it is one.
    var stamp: BackPlateStamp?

    private var lcd: LcdMode { LcdMode.current }

    var body: some View {
        ShareCardFrame(caption: "PASSPORT") {
            VStack(spacing: 16) {
                Spacer(minLength: 0)

                if let stamp {
                    BackPlateStampView(stamp: stamp, width: 168, height: 152)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 62, weight: .semibold))
                        .foregroundStyle(lcd.accent)
                }

                Text(achievement.headline)
                    .font(DexFont.retro(22))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)

                Text(achievement.caption)
                    .font(DexFont.mono(14))
                    .foregroundStyle(lcd.subtext)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
#endif
