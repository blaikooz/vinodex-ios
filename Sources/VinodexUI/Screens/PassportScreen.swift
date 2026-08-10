#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The passport: what the tried shelf adds up to, plus the stamps.
///
/// A dumb renderer over `Passport.compute` — every number on this screen is
/// produced (and tested) in Core. The screen owns nothing but layout.
public struct PassportScreen: View {
    @State private var bookmarks = BookmarkStore.shared
    @State private var streak = StreakStore.shared
    @State private var progress = QuizProgress.shared
    /// The database this screen reads. Defaulted so no call site changes, but
    /// injectable, which is the whole of **M27**: a screen that hard-reads
    /// `WineDatabase.shared` cannot be put in front of a fixture.
    private let db: WineDatabase

    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }

    /// Opens the stamp collection (0.8.6, C3). Optional, and the button is
    /// withheld rather than dead when it is nil — the same rule the chassis
    /// lamps follow, and what keeps `PassportScreen()` a valid call for the demo
    /// reel and for previews.
    private let onStampCollection: (() -> Void)?

    /// Opens one of the YOU MIGHT LIKE rows (0.8.9b, C1). Optional on the same
    /// rule as `onStampCollection`: with no way to open a recommendation the
    /// section is withheld rather than drawn dead, so `PassportScreen()` stays a
    /// valid call for previews and the demo reel.
    private let onSelectEntry: ((WineEntry) -> Void)?

    public init(
        db: WineDatabase = .shared,
        onStampCollection: (() -> Void)? = nil,
        onSelectEntry: ((WineEntry) -> Void)? = nil
    ) {
        self.db = db
        self.onStampCollection = onStampCollection
        self.onSelectEntry = onSelectEntry
    }

    /// The unlock queue (0.7.1, D2) and the one being shown.
    @State private var unlockQueue: [BackPlateStamp] = []
    @State private var showingUnlock: BackPlateStamp?
    /// The rung crossed since this ledger was last asked (0.8.7, D1). One at
    /// most — see `PassportProgress.announceTier`.
    @State private var pendingRank: PassportTier?
    /// Professor Vino's queue (0.8.9c). This screen holds him quiet while a
    /// celebration is up and is the backstop for `firstStamp`.
    @State private var vino = VinoPresenter.shared
    @State private var passportProgress = PassportProgress.shared
    /// The rendered card waiting on the share sheet (0.7.8, B2/B3/B4).
    @State private var sharePayload: SharePayload?

    /// What the profile card calls the player's device.
    ///
    /// **There is no "favourite device" in this app.** B2's phrase has no
    /// counterpart in the code — nothing is favourited, and grepping for it
    /// finds nothing. The nearest true fact is the device they are *running*,
    /// which is what the DEVICE row in Settings already reports: a fitted
    /// workshop build by name, or the shell otherwise. That is what the card
    /// says, rather than inventing a favouriting mechanic to satisfy a word.
    private var deviceName: String {
        let build = DeviceBuild.active()
        if let fitted = CustomDeviceStore.shared.matching(build) { return fitted.name }
        return ChassisSkin(rawValue: build.shell)?.displayName ?? ChassisSkin.classic.displayName
    }

    private func shareProfile(_ passport: Passport) {
        Haptics.select()
        let card = ShareCard.profile(
            from: passport,
            streak: streak.current,
            bestStreak: streak.best,
            device: deviceName
        )
        if let image = ShareCardRenderer.image({ ProfileShareCard(card: card) }) {
            sharePayload = .image(image, title: "Cellar Profile")
        }
    }

    private var passport: Passport {
        Passport.compute(
            tried: bookmarks.ids(on: .tried),
            in: db,
            bestStreak: streak.best,
            highestTier: progress.highestUnlocked,
            triedDays: bookmarks.triedDayLog
        )
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    public var body: some View {
        let passport = passport

        ZStack {
            DexScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    rankCard(passport)

                    // **STAMPS first (0.8.6, C2), and now only the way in
                    // (0.8.7, B1).**
                    //
                    // C2 moved this section above the counters and C3 gave it a
                    // collection screen; what it left behind was the eight-tile
                    // grid, so the same eight stamps were drawn twice in two
                    // sizes one tap apart — a symbol and two words here, the
                    // franked object over there. The item removes the duplicate,
                    // and it is the grid that goes rather than the page: a tile
                    // that shrinks a drawing to a lock glyph is the thing C3
                    // was written to stop doing.
                    //
                    // What is left is one row saying how many of the series you
                    // hold and opening the place where they are objects.
                    DexSection("STAMPS", rank: .screen) {
                        stampsButton(passport)
                    }

                    DexSection("TASTINGS", rank: .screen) {
                        LazyVGrid(columns: columns, spacing: 8) {
                            // **The drawn marquee glyphs (0.8.6, C5).** These
                            // four tiles carried the SF Symbols the marquee's own
                            // `marqueeSymbol` table names, which was right when
                            // there was nothing else; 0.8.4's A drew a dot-matrix
                            // face for every one of them. `DexChromeGlyph` falls
                            // back to the same symbol when a stem misses, so the
                            // pair passed here is the picture and its stand-in
                            // rather than a replacement.
                            //
                            // COUNTRIES takes `marquee-countryscan` — the country
                            // page's own face — because that is what the row
                            // counts. It is not `EntryCategory`, which has no
                            // countries case; the other three are.
                            statTile(
                                art: EntryCategory.grapes.marqueeArt,
                                symbol: EntryCategory.grapes.marqueeSymbol,
                                tint: Color(dexHex: "#a855f7"),
                                value: "\(passport.triedGrapes)/\(passport.totalGrapes)",
                                label: "GRAPES"
                            )
                            statTile(
                                art: EntryCategory.styles.marqueeArt,
                                symbol: EntryCategory.styles.marqueeSymbol,
                                tint: Color(dexHex: "#f97316"),
                                value: "\(passport.triedStyles)/\(passport.totalStyles)",
                                label: "STYLES"
                            )
                            statTile(
                                art: DexRoute.country(name: "").marqueeArt,
                                symbol: "flag.fill",
                                tint: Dex.yellow,
                                value: "\(passport.countries)",
                                label: "COUNTRIES"
                            )
                            statTile(
                                art: EntryCategory.continents.marqueeArt,
                                symbol: EntryCategory.continents.marqueeSymbol,
                                tint: Dex.blue,
                                value: "\(passport.continents.count)/6",
                                label: "CONTINENTS"
                            )
                        }
                    }

                    // Directly under the counters (0.8.9b, C1). The section
                    // above says "12 of 80"; the obvious next thought is "which
                    // of the other 68", and this answers it. Everything below is
                    // a record of what you have done, which is the wrong
                    // neighbourhood for a suggestion.
                    recommendations

                    DexSection("BY COLOUR", rank: .screen) {
                        VStack(spacing: 10) {
                            progressRow(
                                label: "RED",
                                done: passport.byColor[.red] ?? 0,
                                total: passport.colorTotals[.red] ?? 0,
                                fill: Dex.red500
                            )
                            progressRow(
                                label: "WHITE",
                                done: passport.byColor[.white] ?? 0,
                                total: passport.colorTotals[.white] ?? 0,
                                fill: Color(dexHex: "#d6d3d1")
                            )
                        }
                    }

                    DexSection("BY RARITY", rank: .screen) {
                        VStack(spacing: 10) {
                            ForEach(RarityLabel.allCases, id: \.self) { rarity in
                                progressRow(
                                    label: rarity.rawValue,
                                    done: passport.byRarity[rarity] ?? 0,
                                    total: passport.rarityTotals[rarity] ?? 0,
                                    fill: rarityTint(rarity)
                                )
                            }
                        }
                    }

                    DexSection("ACTIVITY", rank: .screen) {
                        activityGraph(passport.activity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentMargins(12, for: .scrollContent)

            // One celebration at a time, stamps before the ladder (0.8.7, D1).
            // A tasting can earn both — a tenth entry that is also a rung — and
            // the rank is the larger event, so it is the one left on screen when
            // the stamps have been cleared.
            if let stamp = showingUnlock {
                StampUnlockedPrompt(stamp: stamp) { advanceUnlockQueue() }
            } else if let tier = pendingRank {
                RankUnlockedPrompt(tier: tier) { pendingRank = nil }
            }
        }
        .shareCard($sharePayload)
        .animation(DexMotion.overlay, value: showingUnlock?.id)
        .animation(DexMotion.overlay, value: pendingRank)
        // **This screen's hold on Professor Vino** (0.8.9c, D1), for
        // `EntryDetailScreen`'s reason and one of its own: `firstPassport` fires
        // on *arriving here*, and the backstop below can raise a stamp
        // celebration on the same arrival. Without the hold, the two land
        // together on the one screen guaranteed to have both.
        .onChange(of: passportPromptIsUp, initial: true) { _, up in
            vino.setSuspended(up, by: Self.vinoHold)
        }
        .onDisappear { vino.setSuspended(false, by: Self.vinoHold) }
        // The backstop (0.7.1, D2). Unlocks are announced at the moment they
        // happen — see `EntryDetailScreen` — but three of the six badges can be
        // earned somewhere that has no passport in front of it (the quiz's top
        // tier, a seventh streak day). Opening the passport catches anything
        // those missed, which is also the natural place to find out.
        .task {
            let current = passport
            passportProgress.seed(with: current)
            // The ladder's own seed, on its own flag (0.8.7, D1). It has to be a
            // second call rather than a line inside the first: `seededKey` is
            // already true on every install, so a ladder folded into it would
            // never be seeded and this screen would open on a celebration for a
            // rank the user has held since 0.7.1. See `PassportProgress`.
            passportProgress.seedTier(with: current)
            unlockQueue = passportProgress.announce(current)
            pendingRank = passportProgress.announceTier(current)
            // The backstop catches stamps earned where no passport was open, so
            // it is also the backstop for `firstStamp` (0.8.9c, E2) - a player
            // whose first badge came from a quiz tier or a streak day meets it
            // here rather than never.
            if !unlockQueue.isEmpty { vino.fireOnce(.firstStamp) }
            advanceUnlockQueue()
        }
    }

    /// One at a time, in catalog order: two stamps arriving together is
    /// possible (a tenth entry that is also a region's last grape), and two
    /// overlapping celebrations would be one unreadable pile.
    /// This screen's key in `VinoPresenter.suspensions`.
    private static let vinoHold = "passportPrompt"

    private var passportPromptIsUp: Bool {
        showingUnlock != nil || pendingRank != nil
    }

    private func advanceUnlockQueue() {
        guard !unlockQueue.isEmpty else {
            showingUnlock = nil
            return
        }
        showingUnlock = unlockQueue.removeFirst()
    }

    // MARK: Rank (D4)

    /// The rank card: where you are on the ladder, and how far to the next
    /// rung.
    ///
    /// Above everything else on the screen, because it is the one line that
    /// answers "how am I doing" — the six sections below it answer "at what".
    /// Before the first rung it shows the climb rather than a placeholder rank:
    /// there is deliberately nothing below APPRENTICE to be called.
    ///
    /// **The first rung is APPRENTICE at five, not MASTER at twenty-five**
    /// (0.8.9b). D4's "the ladder begins with VINODEX MASTER" was the rule when
    /// this card was written; the user has since put a rung underneath it, and
    /// the unranked line below reads its threshold from the ladder rather than
    /// spelling a number that would go stale the next time one moves.
    /// The unranked line, with the bottom rung's cost read from the ladder
    /// rather than written out. The old copy said "Twenty-five entries" and was
    /// wrong the moment APPRENTICE landed at five; this cannot go stale.
    private var unrankedBlurb: String {
        guard let first = PassportTier.ladder.first else { return "" }
        return "\(first.threshold) entries earns your first rank."
    }

    private func rankCard(_ passport: Passport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // The drawn shield, one per rung (0.8.9a, A4). UNRANKED keeps
                // the hollow seal it always had and gains no badge, because a
                // numbered shield is a thing you have earned and the whole
                // point of the empty state is that you have not.
                if let tier = passport.tier {
                    DexChromeGlyph(tier.glyph.artStem, symbol: "seal.fill", size: 30, tint: Dex.yellow)
                        .shadow(color: Dex.yellow.opacity(0.45), radius: 7)
                } else {
                    Image(systemName: "seal")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(lcd.disabledText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(passport.tier?.displayName ?? "UNRANKED")
                        .font(DexFont.retro(15))
                        .tracking(1)
                        .foregroundStyle(passport.tier == nil ? lcd.subtext : lcd.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(passport.tier?.blurb ?? unrankedBlurb)
                        .font(DexFont.mono(14))
                        .foregroundStyle(lcd.subtext)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)

                // The profile's share affordance (0.7.8, B4). On the rank card
                // because that is the line the card leads with.
                Button { shareProfile(passport) } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(lcd.accent)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.buttonWell))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(lcd.accent, lineWidth: 2)
                        )
                }
                .buttonStyle(DexPressStyle(scale: 0.94))
                .accessibilityLabel("Share your passport")
            }

            if let next = passport.nextTier {
                VStack(alignment: .leading, spacing: 5) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(lcd.well)
                            Capsule()
                                .fill(Dex.yellow)
                                .frame(
                                    width: max(geo.size.width * passport.towardNext, 0)
                                )
                        }
                    }
                    .frame(height: 10)
                    .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 1))

                    Text("\(passport.triedTotal)/\(next.threshold) TO \(next.displayName)")
                        .font(DexFont.mono(14))
                        .foregroundStyle(lcd.subtext)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            } else {
                Text("THE LADDER IS FINISHED.")
                    .font(DexFont.mono(14))
                    .foregroundStyle(Dex.yellow)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    (passport.tier == nil ? lcd.surfaceEdge : Dex.yellow).opacity(0.55),
                    lineWidth: 2
                )
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: Activity (D1)

    /// Entries collected per day for the last month.
    ///
    /// A `Canvas`, following `DataWave` in the settings panel: thirty columns
    /// is thirty subviews otherwise, and they are rectangles with no behaviour.
    ///
    /// **Scaled to the busiest day, with a floor of three.** Scaling to the
    /// maximum alone means a month whose best day was one entry draws a
    /// full-height bar for it, which reads as a heroic session. A floor of
    /// three keeps a quiet month looking quiet, and any real streak of activity
    /// outgrows it immediately.
    ///
    /// The empty state says why it is empty rather than drawing thirty zeroes,
    /// because for every existing user it *will* be empty on the day they
    /// update: nothing recorded a date before 0.7.1 and back-filling would have
    /// meant inventing one. See `BookmarkStore.triedDay(for:)`.
    private func activityGraph(_ days: [PassportActivityDay]) -> some View {
        let peak = max(days.map(\.count).max() ?? 0, 3)
        let total = days.reduce(0) { $0 + $1.count }

        return VStack(alignment: .leading, spacing: 8) {
            Canvas(opaque: false) { context, size in
                guard !days.isEmpty else { return }
                let slot = size.width / CGFloat(days.count)
                let bar = max(slot - 2, 1)
                for (i, day) in days.enumerated() {
                    let h = day.count == 0
                        ? 2
                        : max(size.height * CGFloat(day.count) / CGFloat(peak), 3)
                    let rect = CGRect(
                        x: CGFloat(i) * slot + (slot - bar) / 2,
                        y: size.height - h,
                        width: bar,
                        height: h
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: min(bar / 2, 2)),
                        with: .color(day.count == 0 ? lcd.surfaceEdge : lcd.accent)
                    )
                }
            }
            .frame(height: 64)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.well))
            .overlay(
                RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
            )
            .accessibilityLabel(
                "Activity, last \(days.count) days: \(total) entr\(total == 1 ? "y" : "ies") collected"
            )

            HStack {
                Text("\(days.count) DAYS AGO")
                Spacer()
                Text(total == 0 ? "NOTHING LOGGED YET" : "\(total) THIS MONTH")
                Spacer()
                Text("TODAY")
            }
            .font(DexFont.mono(13))
            .foregroundStyle(lcd.subtext)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    private func rarityTint(_ rarity: RarityLabel) -> Color {
        switch rarity {
        case .common: Dex.green500
        case .uncommon: Dex.blue
        case .rare: Color(dexHex: "#a855f7")
        case .noble: Dex.yellow
        // Cursed gold — the tier above nobility (0.6.2, A1).
        case .godforsaken: Color(dexHex: "#ca8a04")
        }
    }

    // MARK: Furniture

    // MARK: You might like (0.8.9b, C1)

    /// Untried grapes and styles that score well against the palate profile.
    ///
    /// **Withheld rather than empty.** Three things can make this nothing —
    /// no way to open a row, a profile too thin to be worth guessing from, or a
    /// palate whose good matches are all already drunk — and in every one of
    /// them the honest rendering is no section at all. A YOU MIGHT LIKE header
    /// over an empty box invites the reader to conclude the app has nothing for
    /// them, which is a stronger claim than "not yet".
    ///
    /// The scoring, the floor, the cap and the ordering are all in
    /// `PalateProfile` and tested there; this is layout, like the rest of the
    /// screen.
    @ViewBuilder
    private var recommendations: some View {
        if let onSelectEntry {
            let index = DiscoveryIndex(tried: bookmarks.ids(on: .tried), in: db)
            let picks = PalateProfile(index: index).recommendations(index: index)
            if !picks.isEmpty {
                DexSection("YOU MIGHT LIKE", rank: .screen) {
                    VStack(spacing: 6) {
                        ForEach(picks) { pick in
                            LinkedRow(
                                db: db,
                                title: pick.name,
                                entry: pick,
                                fallbackColor: Dex.stone800,
                                resolved: true
                            ) {
                                Haptics.select()
                                onSelectEntry(pick)
                            }
                        }
                    }
                }
            }
        }
    }

    // This screen's private `section(_:content:)` — its own heading, at
    // `retro(14)` and tracking 1.5 over a rule from `lcd.accent.opacity(0.45)` —
    // is gone. It was one of the six copies AUDIT **M28** collapsed into
    // `DexSection`, which draws that treatment as `rank: .screen`; see the
    // inventory in `DexSection`'s own doc comment.

    /// The way into the collection (0.8.6, C3), and since 0.8.7's B1 the whole
    /// of the STAMPS section rather than a control sitting under the eight-tile
    /// grid: the grid is gone and this opens the page where the stamps are
    /// objects rather than ticks. Full width, in the panel's own button idiom —
    /// the same well, edge and press the rank card's share affordance uses.
    @ViewBuilder
    private func stampsButton(_ passport: Passport) -> some View {
        if let onStampCollection {
            let earned = passport.badges.filter(\.earned).count
            Button {
                Haptics.select()
                onStampCollection()
            } label: {
                HStack(spacing: 10) {
                    DexChromeGlyph(
                        UIGlyph.stamp.artStem,
                        symbol: DexRoute.stampCollection.marqueeSymbol,
                        size: 16
                    )
                    Text("STAMP COLLECTION")
                        .font(DexFont.retro(12))
                        .tracking(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                    Text("\(earned)/\(passport.badges.count)")
                        .font(DexFont.mono(15))
                }
                .foregroundStyle(lcd.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(lcd.buttonWell))
                .overlay(
                    RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.accent, lineWidth: 2)
                )
            }
            .buttonStyle(DexPressStyle(scale: 0.97))
            .accessibilityLabel("Stamp collection, \(earned) of \(passport.badges.count) earned")
        }
    }

    /// The DATA panel's stat tile, at passport duty.
    ///
    /// `art` is the drawn marquee face (0.8.6, C5) and `symbol` the stand-in
    /// `DexChromeGlyph` prints when the stem misses — the pair every drawn-art
    /// surface in this app is called with.
    ///
    /// ## Why the drawn face takes the tile's colour (0.8.7, B2)
    ///
    /// C5 gave these four tiles the marquee drop and left them looking like four
    /// of the same thing. `DexChromeGlyph` renders art in the art's own colours
    /// unless `flatten` is passed, and the marquee faces are one drop drawn for
    /// one lit panel — so the four glyphs arrived here in a single ink while
    /// every other part of the tile was already saying which row it was: the
    /// border is `tint`, and `tint` is a different colour per row.
    ///
    /// **The right ink here is not the one 0.8.4's A2 chose**, and this is the
    /// place to say why, because the expression is tempting to copy. A2 gave the
    /// *marquee* glyph `ink` / `skin.marqueeShadow` — the same expression the
    /// letters beside it read — on the argument that a glyph and the title next
    /// to it are one legend cut into one lit panel, so they must be the same
    /// material. That argument holds there and points somewhere else here. This
    /// is not a legend beside a title; it is a row's mark beside that row's
    /// numbers, on a surface where colour already carries which row you are
    /// looking at. Reading `lcd.text` would make the four identical again, one
    /// register brighter; reading `lcd.accent` would make them identical *and*
    /// the same colour as the section heading above them.
    ///
    /// So it is `tint` — the colour the tile has been drawing its own border in
    /// since the section shipped. The tile now has one colour rather than a
    /// colour and a glyph that ignored it, which is A2's actual principle
    /// applied to this surface: the mark is the same material as what it marks.
    ///
    /// The SF Symbol stand-in already took `tint` and always has, so this only
    /// closes the gap the drawn branch opened.
    private func statTile(
        art: String?,
        symbol: String,
        tint: Color,
        value: String,
        label: String
    ) -> some View {
        HStack(spacing: 10) {
            // `art ?? ""` because `DexChromeGlyph` takes a stem rather than an
            // optional: an empty stem resolves in no directory, which is exactly
            // the fallback a nil art wants, and it keeps the nil-handling in one
            // expression rather than in a second initialiser. `smoothing` for the
            // reason that flag exists — these are antialiased dots, not a grid.
            DexChromeGlyph(
                art ?? "",
                symbol: symbol,
                size: 22,
                weight: .semibold,
                tint: tint,
                flatten: tint,
                smoothing: true
            )
            .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(DexFont.retro(15))
                    .foregroundStyle(lcd.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(DexFont.mono(15))
                    .foregroundStyle(lcd.subtext)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(0.45), lineWidth: 1)
        )
    }

    /// A labelled progress bar with the honest fraction at its end — the bar
    /// gives the shape, the numbers give the truth.
    private func progressRow(label: String, done: Int, total: Int, fill: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(DexFont.mono(17))
                .foregroundStyle(lcd.text)
                .frame(width: 92, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(lcd.well)
                    if total > 0, done > 0 {
                        Capsule()
                            .fill(fill)
                            .frame(width: max(geo.size.width * CGFloat(done) / CGFloat(total), 8))
                    }
                }
            }
            .frame(height: 10)
            .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 1))

            Text("\(done)/\(total)")
                .font(DexFont.mono(16))
                .foregroundStyle(lcd.subtext)
                .frame(width: 52, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

}

// The eight-tile badge grid and its three helpers — `badgeTile`, `badgeFace`,
// `badgeSymbol`, `badgeTint` — were deleted here in 0.8.7 (B1) along with the
// section that drew them. `shareBadge` went with them and reappears in
// `StampCollectionScreen`, which is where an earned stamp now is.
//
// The two lookup tables did *not* survive as tables. `badgeSymbol` and
// `badgeTint` were a second opinion about every stamp's symbol and colour,
// beside `StampCatalog`'s `fallbackSymbol` and `colorHex` — and they disagreed
// on two of the eight (FIRST SIP was a drop here and a wineglass there, REGION
// COMPLETE a filled map and a pin). The collection reads the catalog, which is
// the record that also feeds the plate, the drawn stamp and the share card.
#endif
