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

    /// Stamps earned by the tap that is currently being handled, waiting for
    /// the rating prompt to close (0.7.1, D2).
    @State private var pendingUnlocks: [BackPlateStamp] = []
    @State private var showingUnlock: BackPlateStamp?
    /// The rung the same tap crossed, if any (0.8.7, D1). Shown after the
    /// stamps, which is why it is not in that queue: the queue is a list of one
    /// kind of thing and this is the other kind.
    @State private var pendingRank: PassportTier?
    @State private var bookmarks = BookmarkStore.shared
    /// Raised when TRIED turns on, and again from MY RATING's EDIT.
    @State private var showingRating = false
    /// Which expandable sections are open (0.6.2, C2). Session-local:
    /// an expanded list is browsing state, not an answer.
    @State private var expandedSections: Set<String> = []
    /// Scroll position outlives the view — see `ScreenStateStore`.
    @State private var screens = ScreenStateStore.shared
    /// The bundle a tap just ran into, raising `UpgradePrompt` (0.7.5, E1).
    /// Only LINEAGE reaches it from here — every *entry* paywall is handled a
    /// level up in `RootView.open(_:)`, which is why this screen had none.
    @State private var lockedBundle: Entitlement?
    @State private var access = AccessStore.shared
    /// The rendered card waiting on the share sheet (0.7.8, B1/B4).
    @State private var sharePayload: SharePayload?
    /// Professor Vino's queue (0.8.9c, E2). Three of the fifteen triggers fire
    /// on this screen — `firstTried`, `firstInsight` and `firstStamp` — because
    /// this is where a tasting is recorded and where the panel it deepens is
    /// drawn. The fourth thing this screen owes him is silence while its own
    /// celebrations are up; see `entryPromptIsUp`.
    @State private var vino = VinoPresenter.shared
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue

    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    private var screenKey: String { ScreenStateStore.detail(entry.id) }

    /// This screen's key in `VinoPresenter.suspensions`.
    private static let vinoHold = "entryPrompt"

    /// Whether one of this screen's four prompts is on top. See the
    /// `onChange` that publishes it.
    private var entryPromptIsUp: Bool {
        showingRating || showingUnlock != nil || pendingRank != nil || lockedBundle != nil
    }

    /// Coarser than the other screens': the category sections are built by a
    /// `@ViewBuilder` switch over the entry variant, so they share one anchor
    /// rather than each carrying its own. Landing at the top of the readout's
    /// body still beats landing at the top of the page.
    private enum Anchor {
        static let hero = "hero"
        static let tiles = "tiles"
        static let info = "info"
        static let insight = "insight"
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
                // The walkthrough's fourth step lights this panel *after* the
                // tried tap changed it (0.8.9d, G2), which is why that step has
                // nothing to do but be read. See `CoachmarkAction.acknowledged`.
                insightSection.id(Anchor.insight).coachmarkTarget(.insightPanel)
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
        .shareCard($sharePayload)
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
                        showNextUnlock()
                    },
                    onSkip: {
                        showingRating = false
                        showNextUnlock()
                    }
                )
            } else if let stamp = showingUnlock {
                StampUnlockedPrompt(stamp: stamp) { showNextUnlock() }
            } else if let tier = pendingRank {
                // After the stamps, before the paywall (0.8.7, D1). One tasting
                // can produce a rating prompt, two stamps and a rung, and this
                // ladder is what keeps them one at a time; the rank goes last of
                // the celebrations because it is the biggest, and a paywall is
                // not a celebration.
                RankUnlockedPrompt(tier: tier) { pendingRank = nil }
            } else if let bundle = lockedBundle {
                UpgradePrompt(
                    entitlement: bundle,
                    onUnlock: {
                        lockedBundle = nil
                        // Through the provider, like every other unlock since
                        // 0.7.5 (B2) — and it continues where the tap was going
                        // (0.7.3, C1), which for a door is the whole point:
                        // "unlocked!" beside a button you now have to find again
                        // is a half-finished unlock. Gated on the outcome, so a
                        // cancelled purchase opens nothing.
                        Task {
                            let outcome = await access.purchase(bundle)
                            if outcome.entitlement == .lineage {
                                onOpenRoute(.lineage(entryID: entry.id))
                            }
                        }
                    },
                    onCancel: { lockedBundle = nil }
                )
            }
        }
        .animation(DexMotion.overlay, value: showingRating)
        .animation(DexMotion.overlay, value: showingUnlock?.id)
        .animation(DexMotion.overlay, value: pendingRank)
        .animation(DexMotion.overlay, value: lockedBundle)
        // **This screen's own hold on Professor Vino** (0.8.9c, D1).
        //
        // `RootView` suspends him for the chrome overlays it owns, but the four
        // prompts above are raised in here and it cannot see them — and this is
        // precisely the screen where `firstTried` and `firstStamp` fire. Without
        // this, marking a wine TRIED puts a speech bubble across the bottom of
        // the stamp celebration it is congratulating.
        //
        // Keyed by reason so the two hosts cannot release each other's hold; see
        // `VinoPresenter.suspensions`.
        .onChange(of: entryPromptIsUp, initial: true) { _, up in
            vino.setSuspended(up, by: Self.vinoHold)
        }
        // Leaving with a prompt open would otherwise wedge the queue for the
        // rest of the session - the hold is on a store that outlives this view.
        .onDisappear { vino.setSuspended(false, by: Self.vinoHold) }
        // **The first time INSIGHT actually says something** (0.8.9c, E2).
        //
        // Keyed on the tried count rather than on appearance, because the line
        // is about unlocking: the panel goes from teaser to derived lines on the
        // TRIED tap, and that is the moment worth remarking on. Re-runs when the
        // count moves, which is exactly when the depth can change.
        //
        // `lines` rather than `isEmpty` - `InsightPanel.isEmpty` is false in the
        // teaser state too, so keying on it would fire "INSIGHT unlocked" on the
        // first grape a brand-new player opened, before anything was unlocked.
        .task(id: bookmarks.count(on: .tried)) {
            guard !insightPanel.lines.isEmpty else { return }
            vino.fireOnce(.firstInsight)
        }
        // **Seed both ledgers before this page's own TRIED pill can be pressed**
        // (0.8.7, D1). Seeding has lived only in the passport screen's `task`
        // since 0.7.1, which leaves a returning player who updates and taps
        // TRIED without opening the passport announcing against an unseeded
        // ledger — a stale stamp today, and a stale *rank* once D1 lands, on the
        // first tap after updating. `seedIfNeeded` short-circuits on a flag
        // before computing anything, so this costs nothing for the rest of the
        // install's life. Not keyed on the entry: it is a once-ever job.
        .task {
            PassportProgress.shared.seedIfNeeded(
                Passport.compute(
                    tried: bookmarks.ids(on: .tried),
                    in: db,
                    bestStreak: StreakStore.shared.best,
                    highestTier: QuizProgress.shared.highestUnlocked,
                    triedDays: bookmarks.triedDayLog
                )
            )
        }
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

                // **Inset back off the bezel** (0.7.1, A4). The hero's
                // `.padding(.horizontal, -14)` below cancels the scroll
                // content margin so the wash goes full-bleed, which is
                // deliberate and correct — but the title rode along with it
                // and had *zero* horizontal inset, so its line box was the
                // whole LCD and the hard 4pt shadow sat against the moulding.
                // At the HUGE step the retro face fits thirteen characters
                // across, so GEWURZTRAMINER and NIEDEROSTERREICH broke
                // mid-glyph — Press Start 2P has no hyphenation and these
                // titles, unlike the tile chips, were not going through
                // `EntryDisplay.hyphenated`. Both halves are fixed: the inset
                // comes back, and a legal break point exists.
            Text(EntryDisplay.hyphenated(entry.name.uppercased()))
                .font(DexFont.retro(21))
                .foregroundStyle(lcd.text)
                .shadow(color: lcd.accent.opacity(0.55), radius: 0, x: 4, y: 4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)

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
                    if added {
                        // **The walkthrough's third step** (0.8.9d, G2), and one
                        // of its two doors — the label reader's confirm is the
                        // other. The step advances on the *write*, not on the
                        // screen, which is what lets a player with a bottle in
                        // hand satisfy it through the scanner without the
                        // sequence needing a branch. See `CoachmarkWalkthrough`.
                        //
                        // Inside `if added` because un-marking is not a tasting.
                        CoachmarkEngine.shared.report(.markedTried)
                        showingRating = true
                        // The ladder moves on `triedTotal` and `triedTotal`
                        // moves here and nowhere else, so this is the only live
                        // moment a rung can be crossed (0.8.7, D1). Recorded at
                        // the tap, like the stamps, never in a view body.
                        pendingRank = PassportProgress.shared.announceTier(
                            Passport.compute(
                                tried: bookmarks.ids(on: .tried),
                                in: db,
                                bestStreak: StreakStore.shared.best,
                                highestTier: QuizProgress.shared.highestUnlocked,
                                triedDays: bookmarks.triedDayLog
                            )
                        )
                        // **The one moment a passport badge can be earned by
                        // tasting** (0.7.1, D2). Recorded here, at the tap,
                        // never in a view body — `TastingQuizScreen` carries
                        // the same warning for `QuizProgress.recordPass`, and
                        // for the same reason: `announce` marks what it
                        // returns, so a second call in a re-render would
                        // swallow the celebration rather than repeat it.
                        //
                        // Queued behind the rating prompt rather than shown
                        // over it. Two modal cards stacked on one tap is a
                        // pile; the star form asked a question and gets its
                        // answer first.
                        pendingUnlocks = PassportProgress.shared.announce(
                            Passport.compute(
                                tried: bookmarks.ids(on: .tried),
                                in: db,
                                bestStreak: StreakStore.shared.best,
                                highestTier: QuizProgress.shared.highestUnlocked,
                                triedDays: bookmarks.triedDayLog
                            )
                        )
                        // **The first tasting, and the first stamp** (0.8.9c,
                        // E2). Fired at the tap for the same reason `announce`
                        // is: this is the one live moment either becomes true,
                        // and a view body would re-fire on every render.
                        //
                        // Both bubbles wait behind the rating prompt and the
                        // celebrations, which hold the presenter — see
                        // `entryPromptIsUp`. That ordering is the point: the
                        // stamp card is the event and his remark is about it.
                        vino.fireOnce(.firstTried)
                        if !pendingUnlocks.isEmpty { vino.fireOnce(.firstStamp) }
                    }
                }
                // The pill the spotlight cuts out (0.8.9d, G2).
                .coachmarkTarget(.triedControl)
            }

            // **Every entry, tastable or not** (0.7.8, B4). The three pills
            // above are shelf state and two of them are conditional; this one
            // is an export and applies to anything with a page.
            shareCapsule
        }
    }

    /// SHARE, as a glyph without a word.
    ///
    /// A fourth *labelled* pill does not fit: SAVE/WANT/TRIED already run the
    /// width of the LCD at `minimumScaleFactor(0.7)`, and adding SHARE shrank
    /// all four toward illegibility. The share glyph is the one system symbol
    /// a phone user reads without a caption, so this pill drops the caption
    /// rather than the button — which is the half B4 actually asks for.
    private var shareCapsule: some View {
        Button {
            Haptics.select()
            if let image = ShareCardRenderer.image({ EntryShareCard(entry: entry) }) {
                sharePayload = .image(image, title: entry.name)
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(lcd.accent)
                .frame(width: 20, height: 20)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(lcd.buttonWell))
                .overlay(Capsule().strokeBorder(lcd.accent, lineWidth: 2))
        }
        .buttonStyle(DexPressStyle(scale: 0.94))
        .accessibilityLabel("Share \(entry.name)")
    }

    /// One stamp at a time, in catalog order. Two can genuinely land together
    /// — a tenth entry that is also a region's last grape — and overlapping
    /// celebrations would be one unreadable pile.
    private func showNextUnlock() {
        guard !pendingUnlocks.isEmpty else {
            showingUnlock = nil
            return
        }
        showingUnlock = pendingUnlocks.removeFirst()
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

    // MARK: INSIGHT (0.8.9b, B2)

    /// What your tried shelf has to say about this entry.
    ///
    /// **INSIGHT is the word, on screen and in the code.** The concept did not
    /// exist anywhere in the tree before this batch, so the name was a free
    /// choice — and the same batch fixed `ToolIntro`'s "the written paper",
    /// a string that drifted from the identifier beside it and survived a whole
    /// rename because nothing held the two together. Choosing a prettier
    /// synonym for the header while the type stayed `InsightService` would be
    /// starting that fault deliberately. Phase 2's dialogue is written against
    /// this word.
    ///
    /// Every sentence here is derived in Core and tested there; this draws
    /// them. The panel deepens with the tried count — see `InsightDepth` — and
    /// says so, because a section that quietly grows new lines reads as
    /// inconsistency rather than as progress.
    ///
    /// An SF Symbol rather than one of `UIGlyph.unwired`'s parked candidates:
    /// new UI chrome is SF Symbols by house convention, and none of the parked
    /// pictures depicts a derived readout — `heart` and `star` say favourite,
    /// `seal` says verified. See the note on `UIGlyph.unwired`.
    /// Reads `bookmarks`, which is `@Observable`, so a TRIED tap two rows below
    /// rebuilds this panel in the same frame. That is the whole of Phase 1's
    /// "updates live" criterion on this screen.
    ///
    /// A computed property since 0.8.9c so the view and the `firstInsight`
    /// trigger read the same panel rather than each deciding for itself what
    /// counts as unlocked.
    private var insightPanel: InsightPanel {
        let index = DiscoveryIndex(tried: bookmarks.ids(on: .tried), in: db)
        return InsightService.panel(
            for: entry,
            index: index,
            profile: PalateProfile(index: index),
            in: db,
            triedDays: bookmarks.triedDayLog
        )
    }

    @ViewBuilder
    private var insightSection: some View {
        let panel = insightPanel
        if !panel.isEmpty {
            section("INSIGHT", symbol: "lightbulb.fill") {
                // INFO's own plate treatment — left accent rule over a faint
                // accent wash — and INFO's 18pt body (0.8.92, item 9). The
                // panel was a bare column of 16pt lines under an 18pt INFO
                // section on the same screen; derived prose and authored prose
                // are the same register to a reader, so they dress the same.
                VStack(alignment: .leading, spacing: 10) {
                    if let teaser = panel.teaser {
                        Text(teaser)
                            .font(DexFont.mono(17))
                            .foregroundStyle(lcd.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(panel.lines) { line in
                        HStack(alignment: .top, spacing: 8) {
                            // A bullet rather than a glyph per line: seven kinds
                            // would be seven pictures to draw and to keep in a
                            // roster, and the sentences already say which is
                            // which.
                            Text("\u{25B8}")
                                .font(DexFont.mono(17))
                                .foregroundStyle(lcd.accent)
                            Text(line.text)
                                .font(DexFont.mono(18))
                                .foregroundStyle(lcd.bodyText)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if panel.nextDepth != nil, panel.toNextDepth > 0 {
                        Text(
                            panel.toNextDepth == 1
                                ? "1 MORE TASTING DEEPENS THIS PANEL."
                                : "\(panel.toNextDepth) MORE TASTINGS DEEPEN THIS PANEL."
                        )
                        .font(DexFont.retro(10))
                        .tracking(1)
                        .foregroundStyle(lcd.subtext)
                        .padding(.top, 2)
                        // The depth is deliberately not named on screen —
                        // "SHALLOW" is a worse word than a count of what it
                        // costs — so the spoken version says the same thing.
                        .accessibilityLabel(
                            "\(panel.toNextDepth) more tastings unlock more insight"
                        )
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 10)
                .padding(.vertical, 10)
                .background(alignment: .leading) {
                    lcd.accent.frame(width: 4)
                }
                .background(lcd.accent.opacity(0.06))
            }
            .padding(.bottom, 18)
        }
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
            // **Two rows, not one** (0.7.0, A1): COLOR and TYPE share the top
            // row, ORIGIN takes a full-width bar under them.
            //
            // Three abreast gave the country a third of the LCD's width, and a
            // country name is the longest string in the row by a wide margin —
            // UNITED STATES, SOUTH AFRICA and NEW ZEALAND all had to wrap or
            // shrink to fit, while COLOR and TYPE (one short word each) sat in
            // thirds they did not need. This is the same move the *region* tiles
            // made two batches earlier for the same reason and in the same
            // shape: the long string rides alone on a bar, the two short ones
            // pair up. See `keyGrapeBar`'s note directly below.
            // **0.8.0 (G) finishes the move A1 started.** A1 split the row two
            // over one for width; G is about *weight*. COLOR and TYPE are one
            // short word each and were carrying a 54pt icon band and an 11pt
            // label apiece — the same tile a region's CLIMATE gets, on a screen
            // whose subject is the grape below them. They go `compact`.
            //
            // ORIGIN stops being a tile at all and becomes the bar the *region*
            // card gives KEY GRAPE, which is the comparison the ask makes and the
            // reason `attributeBar` was extracted rather than a second bar
            // written: one flat row, the well at the left, the label over the
            // value, a chevron when it leads somewhere. A country is exactly what
            // that treatment is for — a long string that wants a whole line and
            // an object (the flag) rather than a glyph.
            // **COLOR and TYPE stop being boxed tiles (0.8.92, item 7).**
            // 0.8.0's G made them `compact`; item 7 finishes the thought: they
            // take ORIGIN's own container shape — an object on the left, the
            // field name over its value — at half its width, two abreast. The
            // object is the chip's colour as a round well with the icon in it,
            // so the row keeps the palette identity the boxed plate carried
            // without the grey slab `attributeBar`'s note argues against.
            case .grape(let g):
                VStack(spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        attributeChip(label: "COLOR",
                             chip: chip(g.grapeType.rawValue.uppercased(), .colorType),
                             destination: .list(category: .grapes, filter: .type(g.grapeType.rawValue))) { tint in
                            DexIcon(iconID: db.icons.colorIcon(g.grapeType.rawValue.uppercased()), size: 26, color: tint)
                        }
                        attributeChip(label: "TYPE",
                             chip: chip(EntryDisplay.grapeBodyLabel(g), .wineType, key: g.grapeStyle),
                             destination: .list(category: .grapes, filter: .type(g.grapeStyle))) { tint in
                            DexIcon(iconID: db.icons.bodyIcon(g.grapeBodyClass), size: 26, color: tint)
                        }
                    }
                    attributeBar(
                        label: "ORIGIN",
                        chip: chip(g.details.origin.uppercased(), .country, key: g.details.origin),
                        destination: g.details.origin.isEmpty ? nil : .country(name: g.details.origin)
                    ) {
                        // 52 x 32 is `FlagSwatch`'s own default and is what the
                        // tile drew, so the flag itself is unchanged — the bar is
                        // slimmer than the tile it replaces because it has no
                        // 54pt icon band and no boxed plate, not because the flag
                        // shrank. Against `keyGrapeBar`'s 56pt square well a
                        // 52-wide rectangle sits a touch shorter, which is the
                        // right relationship: a grape's portrait is the region
                        // card's headline, a country's flag is a grape's footnote.
                        FlagSwatch(country: g.details.origin)
                    }
                }

            // **CLIMATE leaves the header (0.8.93, item 4).** It was half of a
            // two-tile row; the climate section further down the page is the
            // richer answer and is tappable now (item 1), so the header stops
            // repeating it. COUNTRY takes the full-width origin treatment the
            // grape card taught — same bar, same flag well — which makes the
            // region header keyGrapeBar over country bar, two bars, no tiles.
            case .region(let r):
                VStack(spacing: 10) {
                    let keyGrape = r.details.notableGrapes.first
                    let keyGrapeEntry = keyGrape.flatMap { db.entry(named: $0) }
                    keyGrapeBar(name: keyGrape, entry: keyGrapeEntry)
                    attributeBar(
                        label: "COUNTRY",
                        chip: chip(r.details.origin.uppercased(), .country, key: r.details.origin),
                        destination: .country(name: r.details.origin)
                    ) {
                        // `FlagSwatch`'s own 52 x 32 default, exactly as the
                        // grape and style bars draw it.
                        FlagSwatch(country: r.details.origin)
                    }
                }

            // **ORIGIN comes out of the row (0.8.3, G)**, exactly as the grape
            // card's did in 0.8.0's G2, and for the same two reasons. The first
            // is width: a country name is the longest string in this row by a
            // distance — SOUTH AFRICA and NEW ZEALAND against COLOR's one word
            // and CLASS's one — and three abreast it wrapped while its
            // neighbours sat in thirds they did not need. The second is weight:
            // a style's origin is a footnote next to what colour it is and what
            // class it belongs to, and it was carrying a 54pt icon band to say
            // so.
            //
            // **A third caller of `attributeBar`, not a third bar.** G2
            // extracted that function from `keyGrapeBar` precisely so the next
            // one of these would be a call rather than a copy, and it factored
            // without a change: the same flag well, the same label-over-value,
            // the same chevron. The one thing this caller does that neither
            // other does is *not appear* — a style whose origin is "various"
            // has no country to name, which is why the bar is inside the
            // conditional the tile was.
            // **COLOR and CLASS wear the grape card's attribute chips
            // (0.8.93, item 5)** — the half-width circular-well containers
            // item 7 built one release ago, so the three scan cards stop
            // disagreeing about what a short attribute looks like.
            case .style(let s):
                let cls = EntryDisplay.styleClass(name: s.common.name, classification: s.details.classification)
                let color = EntryDisplay.colorType(name: s.common.name)
                VStack(spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        // **Styles, not grapes (0.8.8, C1).** This chip pushes
                        // `.styleColor`, not the grape-type filter it wore from
                        // 0.6.2 — see `EntryFilter.styleColor`.
                        attributeChip(label: "COLOR",
                             chip: chip(color.rawValue, .colorType, key: color.rawValue),
                             destination: .list(category: .styles, filter: .styleColor(color))) { tint in
                            DexIcon(iconID: db.icons.colorIcon(color.rawValue), size: 26, color: tint)
                        }
                        attributeChip(label: "CLASS",
                             // The *inferred* class, not the raw classification
                             // field (0.6.x): filtering on the raw "STYLE" string
                             // opened a stale near-everything list, where the chip
                             // plainly names ORIGIN/TYPE/METHOD/BLEND.
                             chip: chip(cls.rawValue, .styleClass, key: cls.rawValue),
                             destination: .list(category: .styles, filter: .system(cls.rawValue))) { tint in
                            // The class's own glyph (v0.5.8, B2), at the well's
                            // scale. 30 rather than item 7's 26: the blend art
                            // carries transparent margins that eat the gain —
                            // the same measurement that pushed the old tile to
                            // 54 — so the class art runs to the well's edge.
                            DexIcon(iconID: db.icons.styleClassIcons[cls.rawValue] ?? db.icons.fallback, size: 30, color: tint)
                        }
                    }
                    if s.details.origin.lowercased() != "various" {
                        attributeBar(
                            label: "ORIGIN",
                            chip: chip(s.details.origin.uppercased(), .country, key: s.details.origin),
                            destination: .country(name: s.details.origin)
                        ) {
                            // `FlagSwatch`'s own 52 × 32 default, which is what the
                            // tile drew and what the grape card's bar draws. The bar
                            // is slimmer than the tile it replaces because it has no
                            // icon band and no boxed plate, not because the flag
                            // shrank.
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
                // **FLAVOR and FAMILY, not CLASS and SUBCLASS (0.8.1, F2)**, and
                // at 48pt rather than 32 (F1). The band is 54 and was sized for
                // the style class glyph, so both of these sat with a third of
                // their tile empty above and below — the two taxonomy glyphs
                // were the smallest pictures on a screen that is mostly
                // pictures. `db.icons` keys and the filter routes keep the old
                // words: those are identifiers, and one of them is a stored
                // search key.
                // The grape card's attribute chips here too (0.8.93, item 5).
                // F1's 48pt argument — the taxonomy glyphs were the smallest
                // pictures on a screen of pictures — carries into the well:
                // 30, the largest the 44pt circle seats with a rim of air.
                HStack(alignment: .top, spacing: 8) {
                    attributeChip(label: "FLAVOR",
                         chip: chip(f.details.classification, .flavorClass, key: f.details.classification),
                         destination: .list(category: .flavors, filter: .tasting(f.details.classification))) { tint in
                        DexIcon(iconID: db.icons.flavorClassIcon(f.details.classification), size: 30, color: tint)
                    }
                    attributeChip(
                        label: "FAMILY",
                        chip: chip(EntryDisplay.humanize(f.details.subclass).uppercased(), .flavorSubclass, key: f.details.subclass),
                        // A cross-link like FLAVOR above it: tapping runs a
                        // filter search over the family's own flavours.
                        destination: .list(category: .flavors, filter: .flavorSubclass(f.details.subclass))
                    ) { tint in
                        DexIcon(iconID: db.icons.flavorSubclassIcon(f.details.subclass), size: 30, color: tint)
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
    ///
    /// **A caller of `attributeBar` since 0.8.0 (G2).** The grape card's ORIGIN
    /// asks for "the treatment region cards use for KEY GRAPE", and the only
    /// honest way to give it that is to have one bar with two callers rather than
    /// two bars that look alike until somebody tunes one of them.
    @ViewBuilder
    private func keyGrapeBar(name: String?, entry keyGrapeEntry: WineEntry?) -> some View {
        attributeBar(
            label: "KEY GRAPE",
            chip: chip((name ?? "N/A").uppercased(), .wineType, key: name ?? ""),
            destination: keyGrapeEntry.map { .detail(entryID: $0.id) }
        ) {
            // 56, up from 34 (0.6.4, D2): at row-icon size the bunch sprite
            // read as a chip decoration; the bar is the region's headline
            // fact, so its hero earns hero scale.
            if let keyGrapeEntry {
                EntryIconWell(entry: keyGrapeEntry, size: 56, cornerRadius: 8)
            } else {
                DexIcon(iconID: db.icons.fallback, size: 44, color: Dex.stone600)
            }
        }
    }

    /// One headline fact as a full-width flat bar: an object on the left, the
    /// field name over its value, and a chevron when it leads somewhere.
    ///
    /// Extracted from `keyGrapeBar` in 0.8.0 (G2), unchanged in look. The
    /// argument for the shape is the one 0.6.x made and it applies to both
    /// callers: the value here is the longest string in its row — a grape name, a
    /// country name — and three abreast it wrapped to three lines, while the
    /// short fields beside it sat in thirds they did not need.
    ///
    /// **No box, still** (0.6.2, C3): the well and the chip-coloured value carry
    /// the bar. A filled plate behind them read as a grey slab under the hero.
    @ViewBuilder
    private func attributeBar<Leading: View>(
        label: String,
        chip chipData: TileChip,
        destination: DexRoute?,
        @ViewBuilder leading: () -> Leading
    ) -> some View {
        let resolved = db.palette.resolve(chipData)
        HStack(spacing: 10) {
            leading()
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(DexFont.retro(10))
                    .foregroundStyle(lcd.accent)
                Text(chipData.label)
                    .font(DexFont.retro(13))
                    .foregroundStyle(chipValueInk(resolved))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 4)
            if destination != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(lcd.subtext)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TileLink(destination: destination, onOpen: onOpenRoute))
    }

    /// One *short* attribute in `attributeBar`'s shape at half its width
    /// (0.8.92, item 7): the chip's colour as a round well holding the icon,
    /// the field name over its value beside it. Two of these share ORIGIN's
    /// line; the well keeps the chip's own dark ground in every mode, so the
    /// icon's pale ink stays legible where the bare value ink would not — see
    /// `chipValueInk` for the text's half of that bargain.
    @ViewBuilder
    private func attributeChip<Leading: View>(
        label: String,
        chip chipData: TileChip,
        destination: DexRoute?,
        @ViewBuilder icon: (Color) -> Leading
    ) -> some View {
        let resolved = db.palette.resolve(chipData)
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color(dexHex: resolved.bg))
                Circle().strokeBorder(Color(dexHex: resolved.border), lineWidth: 1)
                icon(Color(dexHex: resolved.text))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(DexFont.retro(10))
                    .foregroundStyle(lcd.accent)
                Text(chipData.label)
                    .font(DexFont.retro(13))
                    .foregroundStyle(chipValueInk(resolved))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TileLink(destination: destination, onOpen: onOpenRoute))
    }

    /// The unboxed value's ink (0.8.92, item 8). The palette's `text` colours
    /// are pale by design — they were drawn to sit on each chip's dark `bg` —
    /// and `attributeBar` prints them on the bare page, which on the three
    /// light modes (LIGHT, VINTAGE, WINE.OS) put a near-white country name on
    /// near-white paper. On a light ground the chip's *background* colour is
    /// the readable half of the same pair, and it keeps the per-country hue
    /// that a flat `lcd.text` would erase.
    private func chipValueInk(_ resolved: Palette.Chip) -> Color {
        Color(dexHex: lcd.isLight ? resolved.bg : resolved.text)
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

    // `tile(label:chip:destination:compact:icon:)` retired in 0.8.93 (items 4
    // and 5). It was the boxed header plate from 0.6.4's C1; 0.8.92's item 7
    // replaced its grape callers with `attributeChip`, item 5 converted the
    // style and flavor pairs, and item 4 dissolved the region row into a
    // second `attributeBar` — so the last caller left and the plate went with
    // it. Its one idea worth keeping — the icon tinted to the chip so the two
    // read as one unit — lives on in the chip's circular well.

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
            lineageSection(g)
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
    ///
    /// **A button since 0.8.93 (item 1).** The header's CLIMATE tile carried
    /// this destination until item 4 retired it, so this section inherits the
    /// tap: the regions sharing the climate, as a filtered list. The chevron
    /// is the affordance, exactly as `attributeBar` draws it, and a region
    /// with no climate stays inert rather than tappable-but-dead.
    private func climateSection(_ r: RegionEntry) -> some View {
        let meta = r.climate.flatMap { db.palette.climates[$0.rawValue] }
        let colors = meta?.colors ?? db.palette.namedChips["CLIMATE"]
            ?? Palette.Chip(bg: "#14532d", border: "#22c55e", text: "#86efac")
        let destination = r.climate.map {
            DexRoute.list(category: .regions, filter: .climate($0))
        }

        return section("CLIMATE", symbol: "wind") {
            HStack(spacing: 10) {
                DexIcon(iconID: db.icons.climateIcon(r.climate), size: 30, color: Color(dexHex: colors.border))
                Text((meta?.name ?? "Unknown Climate").uppercased())
                    .font(DexFont.mono(22))
                    .tracking(1.5)
                    .foregroundStyle(Color(dexHex: colors.text))
                Spacer()
                if destination != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(dexHex: colors.text).opacity(0.7))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(dexHex: colors.bg))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(dexHex: colors.border), lineWidth: 1)
            )
            .modifier(TileLink(destination: destination, onOpen: onOpenRoute))
        }
    }

    /// A grid of soil buttons. Regions without an explicit soil type fall back
    /// to a climate-keyed triplet rather than showing nothing.
    ///
    /// **Actual buttons since 0.8.93 (item 2).** Each tile opens GEOLOGY SCAN
    /// — the regions grown on that soil, through `EntryFilter.soil`, which has
    /// existed as a route since the chip era and had no door on this page. The
    /// tiles were already drawn as pressable squares; the tap is what they
    /// were promising.
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
                    .modifier(TileLink(
                        destination: .list(category: .regions, filter: .soil(soil)),
                        onOpen: onOpenRoute
                    ))
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

    /// The door into the pedigree tree (0.7.5, E1).
    ///
    /// **It is not drawn at all when the grape has no relatives**, which is 56
    /// of the 177 (0.8.2; it was 102 when this was written). That is the
    /// decision this feature turned on. The alternatives were a section that
    /// opens an empty tree — three grapes in five, at the time — and the fastest
    /// way to teach somebody that a button does nothing, or a greyed row saying
    /// NO LINEAGE DATA on those 102, which is a paywall-shaped reminder of an
    /// absence on every second grape you open. Neither is worth the
    /// discoverability. The 121 grapes that *do* have a tree carry it, and the
    /// shop entry is where somebody finds out the feature exists.
    ///
    /// **One exception since 0.7.9 (C2), and it is the exception the paragraph
    /// above leaves room for.** The objection to NO LINEAGE DATA was that it
    /// reports an absence of *authoring*, which is a fact about the project
    /// rather than about the grape. `GrapeLineage.parentageUnknown` is the
    /// opposite: an authored claim that the parentage is genuinely
    /// undetermined, made deliberately, one grape at a time. That is a fact
    /// about the wine and worth a line — it is the difference between Zinfandel,
    /// whose parents nobody has established, and a grape a data batch has not
    /// reached yet. It draws as a statement rather than a button, because there
    /// is nowhere to go.
    ///
    /// **0.8.2 is when that branch acquired users.** It shipped in 0.7.9 against
    /// a catalog that set the flag nowhere, and stayed unreachable through
    /// 0.8.0 and 0.8.1. Sommbot's pass sets it on 74 grapes, and the split
    /// between the two panels below is now the interesting number: 42 grapes
    /// state an absence *and* have no edges, so they take the flat panel, while
    /// 14 more — Nebbiolo, Zinfandel, Palomino, Gouais Blanc among them — state
    /// the same absence but are named by somebody else's cross, so they take the
    /// button and carry the unrecorded tile inside the tree instead. The `if`
    /// below is what routes those two apart, and it had never once been
    /// exercised with real data before this batch.
    ///
    /// The counts on the button are the pitch. "2 PARENTS · 6 OFFSPRING" says
    /// what is behind the door, which a bare LINEAGE does not, and it is honest
    /// about a thin tree as well as a rich one.
    ///
    /// The gate is here rather than on the route, exactly as the workshop's is
    /// on the CUSTOMIZE button rather than on `.deviceWorkshop` — routes in this
    /// app are destinations, not gates.
    @ViewBuilder
    private func lineageSection(_ g: GrapeEntry) -> some View {
        let family = db.lineage.relatives(of: g.id)
        if !family.isEmpty {
            section("LINEAGE", symbol: "arrow.triangle.branch") {
                Button {
                    Haptics.select()
                    if access.isUnlocked(.lineage) {
                        onOpenRoute(.lineage(entryID: g.id))
                    } else {
                        lockedBundle = .lineage
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: access.isUnlocked(.lineage) ? "arrow.triangle.branch" : "lock.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(lcd.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FAMILY TREE")
                                .font(DexFont.retro(11))
                                .foregroundStyle(lcd.text)
                            Text(Self.lineageTeaser(family))
                                .font(DexFont.retro(10))
                                .tracking(0.8)
                                .foregroundStyle(lcd.subtext)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Dex.stone600)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(lcd.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(lcd.accent.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(DexPressStyle(scale: 0.98))
            }
        } else if db.lineage.parentageIsUnknown(g.id) {
            section("LINEAGE", symbol: "arrow.triangle.branch") {
                HStack(spacing: 10) {
                    Image(systemName: "circle.slash")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(lcd.subtext)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PARENTAGE UNRECORDED")
                            .font(DexFont.retro(11))
                            .foregroundStyle(lcd.subtext)
                        Text("NO ESTABLISHED CROSS FOR THIS VARIETY")
                            .font(DexFont.retro(10))
                            .tracking(0.8)
                            .foregroundStyle(Dex.stone600)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(lcd.well)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            lcd.surfaceEdge,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                )
            }
        }
    }

    /// "2 PARENTS · 6 OFFSPRING · 3 MUTATIONS" — only the non-empty parts, and
    /// half-siblings last because they are the largest number and the least
    /// surprising one.
    private static func lineageTeaser(_ family: GrapeRelatives) -> String {
        var parts: [String] = []
        if !family.parents.isEmpty {
            parts.append("\(family.parents.count) PARENT\(family.parents.count == 1 ? "" : "S")")
        }
        if family.mutationOf != nil { parts.append("A MUTATION") }
        if !family.offspring.isEmpty { parts.append("\(family.offspring.count) OFFSPRING") }
        if !family.mutations.isEmpty { parts.append("\(family.mutations.count) MUTATIONS") }
        if !family.siblings.isEmpty { parts.append("\(family.siblings.count) HALF-SIBLINGS") }
        if !family.related.isEmpty { parts.append("\(family.related.count) RELATED") }
        return parts.joined(separator: " · ")
    }

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
    ///
    /// **A button since 0.8.93 (item 3): the chip-and-name pair sits in a
    /// container** — the surface plate every settings row wears — and tapping
    /// it opens the regions governed by the same system, the `.system` filter
    /// the style CLASS chip already pushes for styles. The abbreviation is a
    /// bottle-label fact; where else it applies is the natural question, and
    /// the container is what says the question can be asked.
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
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(lcd.subtext)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
            )
            .modifier(TileLink(
                destination: .list(category: .regions, filter: .system(r.details.classification)),
                onOpen: onOpenRoute
            ))
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
