import Foundation

/// Glyphs that more than one screen has to agree on.
///
/// **Why this exists (0.7.0, D1; still true at 0.7.1, E1).** The streak flame was the literal
/// `"flame.fill"` typed out in five places — the TOOLS tile, the saved-entries
/// streak row, the passport badge, the quiz result and the back-plate stamp's
/// fallback — with the marquee showing a `calendar` instead. D1 asks for a
/// different fire icon *everywhere it is used*, and the only way to make
/// "everywhere" checkable is for there to be one place. A new surface that wants
/// the flame reads this and is correct by default.
///
/// In Core rather than VinodexUI because `BackPlateStamps` and `DexRoute` both
/// need it and neither can see the UI module.
public enum DexGlyph {
    /// The daily challenge, and the streak it keeps.
    ///
    /// **No longer a fire (0.7.1, E1/E2.)** 0.7.0's D1 asked for "a different
    /// fire icon" and got one; E1 asks for the fire to stop being fire at all.
    /// `target` is the challenge itself rather than the reward for keeping one
    /// — a daily paper you either hit or miss — and unlike the flame it does
    /// not have to compete with `lucide:flame`, which the *catalog* uses for
    /// thirty-one spicy and volcanic entries. Two unrelated fires on one screen
    /// was the real defect behind E2's "no stray fire icons left".
    ///
    /// Concentric rings read at every size this appears at: the 10pt streak
    /// row in the profile, the 13pt tools tile, the marquee glyph and the 56pt
    /// hero on the daily-done card. SF Symbols 2 / iOS 14, well under the iOS 17
    /// floor — see KNOWN-ISSUES on symbols that render blank rather than
    /// failing to compile.
    ///
    /// Renamed from `streakFlame`: the constant said what it drew instead of
    /// what it meant, which is exactly why the next change to it had to touch
    /// six files.
    public static let challenge = "target"

    /// Search, everywhere in the app (0.7.1, A2).
    ///
    /// A2 asks for one magnifying glass and no other search iconography. Before
    /// this there were four glyphs doing the job: the plain magnifier in the
    /// search-bar shell, `line.3.horizontal.decrease` on the main menu's round
    /// button, `line.3.horizontal.decrease.circle.fill` on the filter screen's
    /// marquee and summary card, and `sparkle.magnifyingglass` on the scanner.
    /// The bars are a *filter* glyph, and the screen they opened is the app's
    /// search — so the button and the magnifier disagreed about what the button
    /// was for.
    ///
    /// The bars survive in exactly one role, and it is not search: the chip
    /// dropdown's disclosure (`slider.horizontal.3`) and the "a filter is
    /// narrowing this list" banner, which are statements about a list rather
    /// than a way in.
    public static let search = "magnifyingglass"

    /// The main menu itself (0.7.2, A3).
    ///
    /// The marquee reads MENU on the main screen and had no glyph beside it,
    /// because 0.7.0's K1 removed the hardcoded wine glass on the grounds that
    /// the main screen is the one page with no route and therefore no page to be
    /// accurate to. That reasoning holds for a glyph taken off the *route table*
    /// and not for a glyph naming the screen: MENU is as much a place as
    /// SETTINGS is, and it was the only panel in the app showing a bare word.
    ///
    /// Four squares, because that is literally what is on the screen behind it —
    /// GRAPES, REGIONS, STYLES, FLAVORS, the four category tiles. It collides
    /// with no route (`ChromeTests` gates that table for uniqueness, and this
    /// symbol appears nowhere in it) and it is SF Symbols 1 / iOS 13, well under
    /// the iOS 17 floor.
    public static let menu = "square.grid.2x2.fill"

    /// Pinning, wherever the app talks about it (0.7.2, A6).
    ///
    /// A6 gave the marquee a PINS title and this glyph for as long as the drawer
    /// was open, so the panel named the thing in front of it rather than the
    /// screen behind. **The drawer and that title are gone (0.7.6, A1)** — the
    /// two lamp buttons are the pins now, and the panel is a display again — but
    /// the constant is not, because the vocabulary outlived the surface: the lamp
    /// chooser is where pinning is done, and it is the one place left that needs
    /// to draw a pin.
    ///
    /// Not on the route table, then or now: the chooser is an overlay on whatever
    /// page you were on rather than a destination, which is exactly why this is a
    /// glyph constant instead of a `DexRoute` case.
    public static let pins = "pin.fill"
}

/// One group of settings, each with its own panel.
///
/// The settings screen is a grid of these rather than one long scroll: the
/// toggles had grown past a screenful, and the two a user actually reaches for
/// were below the developer-facing ones.
///
/// SCREEN, TEXT and SKIN used to be three tiles. They are one CUSTOMIZE tile
/// now: all three answer the same question — what the device looks like — and
/// splitting them meant three taps to try a colourway against a screen mode,
/// with a trip back to the grid between each. Their panels were also the three
/// shortest in the app, so a combined one still fits a screenful.
///
/// **The raw values are storage, and were mis-documented as display copy until
/// 0.7.5.** The sentence that stood here said "no `SettingsSection` is persisted
/// anywhere". That has been untrue since 0.7.2 (A7): the pin store writes these
/// raw values comma-joined into the `marqueeQuickPins` default, and its decoder
/// drops anything it does not recognise — so a rename does not fail loudly, it
/// silently unpins whatever the user had pinned. B2 renames ACCESS to SHOP and
/// therefore does it in `displayName`, per the house rule the skins have followed
/// since 0.5.1: rename the label, never the stored word.
///
/// **The pin vocabulary is `MarqueePin` as of 0.7.6 (A1)**, whose raw values are
/// a strict superset of these — so this paragraph is still exactly true, and the
/// one case with no counterpart there (`dev`) is the one the pin chooser has
/// never offered. See `MarqueePin` for why the vocabulary had to widen.
///
/// (CUSTOMIZATION → CUSTOMIZE predates the pin store and is already in the raw
/// values; it is left alone rather than being unwound into a `displayName` for
/// the sake of it.)
public enum SettingsSection: String, CaseIterable, Hashable, Sendable, Identifiable {
    case customization = "CUSTOMIZE"
    /// Device behaviour rather than device looks: text size, haptics, and the
    /// stored-data reset. Split from CUSTOMIZE so that panel stays purely
    /// cosmetic — a wipe button between two colour pickers is a trap.
    case settings = "SETTINGS"
    /// What the database actually holds. Read-only, unlike everything else
    /// here — it is a readout rather than a setting, but the settings grid is
    /// where a user goes looking for "what is in this thing".
    case data = "DATA"
    /// **The shop (0.7.5, B1/B2).** Displayed as SHOP; stored as `"ACCESS"`,
    /// which is what the pin store already has on disk.
    ///
    /// It holds the expansion-pack shelves as of B1 — they were reached from
    /// inside CUSTOMIZE, which was always a compromise: that door existed
    /// because the settings grid is a fixed three-by-two sized to fill the LCD
    /// and a seventh tile would have been an orphan on a fourth row. B1 resolves
    /// it without touching the grid at all, because packs are paid content and
    /// this is the tile paid content already had.
    ///
    /// **`case packs` retired here.** It existed to give the shelf a marquee
    /// title, a glyph, Back behaviour and `ChromeTests` coverage; the shelf now
    /// gets all four from this case instead. The grid is six tiles either way,
    /// and the marquee's chip row is back to four — which is what its own
    /// comment has claimed since 0.7.1 and stopped being true when PACKS landed.
    /// Anyone who had pinned PACKS loses that pin, the same trivially recoverable
    /// cost a rename would have had.
    case access = "ACCESS"
    case dev = "DEV"

    public var id: String { rawValue }

    /// What the device calls this section on screen.
    ///
    /// Defaults to the raw value, so a section only appears here when its label
    /// and its storage have diverged — which makes the list of divergences the
    /// list of cases in this switch rather than something to be grepped for.
    public var displayName: String {
        switch self {
        // ACCESS → SHOP (0.7.5, B2). Label only; see the note on the case.
        case .access: "SHOP"
        default: rawValue
        }
    }

    /// SF Symbol for the grid tile. All iOS 17-safe — see KNOWN-ISSUES on
    /// symbols with a later OS floor rendering blank rather than failing.
    public var symbol: String {
        switch self {
        case .customization: "paintpalette.fill"
        case .settings: "slider.horizontal.3"
        case .data: "chart.bar.fill"
        // `bag.fill` since 0.7.5 (B2), replacing `lock.fill`. A padlock was the
        // right glyph for a panel about what you could not reach; this is a
        // storefront, and a shop marked with a padlock reads as closed. SF
        // Symbols 1 / iOS 13, well under the iOS 17 floor, and it collides with
        // nothing on `DexRoute.marqueeSymbol`'s table —
        // `ChromeTests.glyphsAreDistinct` covers that, because every
        // `SettingsSection` is folded into `allRoutes`.
        case .access: "bag.fill"
        case .dev: "ladybug.fill"
        }
    }

    /// The drawn button face for the grid tile, or nil where there is none
    /// (0.8.1, J3).
    ///
    /// Separate from `symbol` rather than replacing it, for two reasons. The
    /// symbol names are load-bearing beyond the picture — `ChromeTests`
    /// asserts every route's glyph is distinct, and a stem that happened to
    /// repeat would fail a test about something else entirely. And the art is
    /// partial across the app as a whole, so `symbol` stays the thing that
    /// always renders and this stays the thing that may not — the fallback runs
    /// per glyph, not per screen.
    ///
    /// Note SYSTEM and SETTINGS: the route titled SYSTEM is `.settings`, and it
    /// takes the `settings` face. The drop's `system` face goes to the gear on
    /// the chassis, which is the control that opens it.
    public var artStem: String? {
        switch self {
        case .customization: "customize"
        case .settings: "settings"
        case .data: "data"
        case .access: "shop"
        case .dev: "dev"
        }
    }

    /// The same five sections in the marquee's own register (0.8.4, A1).
    ///
    /// A second table rather than a prefix applied to `artStem`, because the two
    /// drops are not guaranteed to agree on a spelling and a computed stem is a
    /// spelling nobody checked. They happen to agree on all five today; when
    /// they stop, this is where it is written down rather than discovered.
    ///
    /// Total, not optional: every section has a glyph in the marquee drop, which
    /// is the one place the conversion is complete.
    public var marqueeStem: String {
        switch self {
        case .customization: "marquee-customize"
        case .settings: "marquee-settings"
        case .data: "marquee-data"
        case .access: "marquee-shop"
        case .dev: "marquee-dev"
        }
    }
}

/// A destination on the navigation stack.
///
/// Filters travel as associated values rather than the web app's stringly-typed
/// `filterMode` / `filterValue` query-parameter pair, so an unrepresentable
/// combination cannot be constructed.
///
/// `detail` carries an id rather than a whole entry: routes are hashed on every
/// navigation change, and hashing a full entry graph for that is wasteful.
public enum DexRoute: Hashable, Sendable {
    case list(category: EntryCategory, filter: EntryFilter?)
    // `case masterSearch` **retired in 0.7.1 (A1).** It was a plain text search
    // over the whole database, left standing but unreachable through 0.7.0
    // (I1) on the grounds that deleting a working screen was not what had been
    // asked. A1 asks for it now, by implication: it renames `.chipFilter`'s
    // label to MASTER SEARCH, and two routes cannot both be the master search.
    //
    // Nothing is lost. This route had no screen of its own — it was one
    // configuration of `EncyclopediaListScreen`, and `ChipFilterScreen` runs
    // the very same `EntryQuery.masterSearch(_:)` behind its own field, so the
    // surviving screen is a strict superset. `EntryQuery.masterSearch(_:)` in
    // `EntryFilter.swift` is a different thing with the same name — the query
    // itself — and is very much still in use.
    case detail(entryID: String)
    case globe
    /// Place search: continents and regions, which between them carry the
    /// country and state names too. Its own screen rather than an overlay on
    /// the globe — results floating over a spinning sphere read as a glitch.
    case globeSearch
    /// Saved entries — see `BookmarkStore`.
    case bookmarks
    /// A country's page: its regions, and its states where it has any.
    /// Assembled from region origins rather than a data entry, since
    /// COUNTRY_GATE is not ported.
    case country(name: String)
    /// The regions of one state within a country.
    case state(name: String)
    /// Professor Vino's own screen (0.8.93, item 9): who he is, his six faces,
    /// the silence switch, and — for now — the dev-facing ledger of what he
    /// has and has not said. The interaction surface comes later; this is the
    /// room it will happen in.
    ///
    /// **This slot held `dailyGrape` — WHAT'S THAT…? — from 0.7.9 to 0.8.93.**
    /// Item 9 deletes that tool outright, screen, engine, record and all, and
    /// the convention that kept the case's old spelling through two screen
    /// rewrites does not apply to a case whose feature no longer exists: a
    /// fresh case is honest vocabulary, and `DexRoute` is not persisted, so
    /// nothing stored can dangle.
    case profVino
    /// The guided grape identifier — colour, body, origin and flavours, then a
    /// deduction. See `GrapeScanCriteria`.
    case scanner
    /// The camera label reader (0.7.2, LR1): photograph a bottle, run on-device
    /// OCR, and match what it read against the catalog. See
    /// `LabelRecognitionService`.
    ///
    /// The TOOLS tile for this existed from 0.7.0 (I2) as a COMING SOON square;
    /// this is the route it was waiting for.
    case labelReader
    /// The biodynamic day readout — see `MoonCalendar`.
    case moonDial
    /// System settings. A pushed screen rather than a side flap: the flap
    /// could never be more than a strip wide, and the toggles want room.
    /// Now a grid of `SettingsSection` tiles rather than the toggles themselves.
    case settings
    /// One settings group's toggles. A real route, not local state in the panel,
    /// so the chassis Back button returns to the settings grid instead of
    /// dropping the user out of settings entirely.
    case settingsSection(SettingsSection)
    /// The tools hub — games *and* instruments.
    ///
    /// Called MINIGAMES while everything on it was a game. It now also holds the
    /// chip filter, which is a search tool with no play in it at all, and
    /// "minigames" was the wrong promise for a shelf you go to in order to get
    /// work done. The case keeps its name because nothing persists it; only the
    /// label moved.
    case minigames
    /// Filter the whole database by tapping chips — colour, body, rarity, type,
    /// climate — with a live count of what survives. See `ChipFilter`.
    case chipFilter
    /// The WSET-style tasting quiz: one question, four answers, then the entry
    /// behind the right one. Three tiers — see `QuizTier`.
    case wsetQuiz
    /// The daily paper: five questions, everyone gets the same ones, one
    /// sitting per day. What the streak hangs off — see `StreakStore`.
    case dailyChallenge
    /// The tried shelf's stats page — see `Passport`.
    case passport
    /// The stamp series, read rather than counted (0.8.6, C3).
    ///
    /// The passport's STAMPS grid says which badges are earned; this is where
    /// the stamps themselves are, at a size their drawings are worth, with the
    /// story each one carries. Separate from `.passport` because the passport is
    /// a page of numbers and this is a page of objects — the same split the back
    /// plate makes between its counters and its collection.
    case stampCollection
    /// The guided tour. Opt-in from the settings grid, never shown unasked.
    case walkthrough
    /// The installed firmware and every release before it (0.7.3, A3). Reads
    /// `FirmwareCatalog`, which is the same source the boot POST states its
    /// version from.
    case firmwareHistory
    /// The unlock-code console (0.7.3, A4). Typed codes are matched against
    /// `CheatCode.all` and grant through `AccessStore` like any other unlock.
    case cheatConsole
    /// The premium device builder (0.7.3, B1/B2). Mix the eight `DeviceAxis`
    /// parts, preview them on the chassis you are holding, and save the result as
    /// a named `CustomDevice`. Gated on `Entitlement.workshop` at the door that
    /// opens it — see `SettingsSectionPanel.deviceWorkshop`; the route itself is
    /// not a gate, exactly as `.detail` is not.
    case deviceWorkshop
    /// One grape's pedigree, drawn as a tree (0.7.5, E1). Parents and the
    /// variety it mutated from above, offspring and mutations below, half-
    /// siblings beside. See `GrapeLineageIndex`.
    ///
    /// Carries an id for the reason `.detail` does, and gated the same way
    /// `.deviceWorkshop` is — on the button that pushes it, not here. Routes in
    /// this app are destinations rather than gates.
    case lineage(entryID: String)
    /// The continent info screen — INFO blurb plus a COUNTRIES list, each
    /// linking to that country's regions. Reached from the globe markers.
    case continent(entryID: String)
    /// One item on the shop shelf, opened (0.8.4, C1).
    ///
    /// **A route, reversing 0.7.5's B4 — and the reason it was an overlay is the
    /// reason it had to stop being one.** B4's argument was that a route would
    /// cost "a `DexRoute` case per pack or one carrying an id, plus `ChromeTests`
    /// coverage, a marquee title and a glyph — for a card that is dismissed by
    /// looking away from it", and that the chassis Back button should keep
    /// meaning "leave the shop". Every clause of that is still true and the
    /// conclusion was still wrong, because the splash is not a card you look away
    /// from: it fills the LCD, it has its own CLOSE button, and the marquee above
    /// it went on saying SHOP. It *is* a page, and it was the only page in the
    /// app that was not a stack frame.
    ///
    /// What that cost is exactly what C1 reports: Back from a pack lands on
    /// SYSTEM. Not through any back-destination logic — there is none, `goBack()`
    /// is `path.removeLast()` — but because the user was standing one frame
    /// below where they thought they were, so one pop skipped the shop entirely.
    /// A route does not need a `parent` switch to fix that; the stack already
    /// encodes it once the pack is a frame of its own.
    ///
    /// Carries the `Entitlement.id` string, which is what `ShopItem.id` already
    /// is and what the shelf already passed to its local state. Resolved through
    /// `ExpansionPacks.pack(id:)` / `SettingsPanel.allShopItems`, and an id that
    /// resolves to nothing renders the closed shelf rather than a blank screen —
    /// the same rule `.detail` follows for an entry that is not in this build.
    case pack(id: String)
    /// **Every recommendation, not the first five** (0.8.91, B3).
    ///
    /// The passport's YOU MIGHT LIKE strip is capped, and §B3 asks for a SHOW
    /// ALL behind it. A route rather than an in-place expander — which is the
    /// idiom `CountryScreen` uses for its long lists — because the full ranking
    /// is a page's worth of rows arriving under a heading that is already the
    /// bottom of a long scroll, and 0.8.4's C1 settled the general question: a
    /// thing that fills the LCD and has its own way back is a stack frame.
    ///
    /// Carries nothing. The ranking is a pure function of the tried shelf and
    /// the catalog (`PalateProfile.recommendations`), so an id here would be a
    /// second copy of state that already has one place to live.
    case recommendations
    /// **The contact screen** (0.8.91, F1) — one paragraph and a mail button.
    ///
    /// A frame rather than a `DexAlert`, for the reason `.pack` is: it fills the
    /// LCD and the chassis Back button is how you leave it. An alert would also
    /// have put a scrim over SYSTEM, which is the screen you came from and the
    /// one this is a row on.
    case support

    public var title: String {
        switch self {
        case .list(let category, let filter):
            filter?.scanTitle ?? category.listTitle
        case .detail:
            "SCAN"
        case .globe:
            "GLOBE SCAN"
        case .globeSearch:
            "WORLD SEARCH"
        // **USER, not SAVED (0.8.5, A1).** The panel named the *contents* of the
        // page — a list of saved entries — where every other title in this table
        // names the place. It is also the only route whose title disagreed with
        // the control that opens it: the cap on the chassis is USER, has been
        // since 0.6.5 (A1), and the screen behind it has grown a profile, a name
        // and an avatar since. The case, `BookmarkStore`, `onBookmarks` and
        // every state key keep their names, per the convention `.scanner` and
        // `.wsetQuiz` already follow — the label is the thing that gets to be
        // copy.
        case .bookmarks:
            "USER"
        // The scan-family label (v0.5.8, D3) — the page's own hero already
        // names the country, so the marquee names the *kind* of page, like
        // every other scan screen.
        case .country:
            "COUNTRY SCAN"
        case .state(let name):
            name.uppercased()
        case .profVino:
            "PROF. VINO"
        case .scanner:
            // SCANNER → IDENTIFY (0.7.0, I3) → BLIND TASTING (0.7.1, E3), the
            // label only each time, per the same convention `wsetQuiz` and
            // `chipFilter` already follow: the case, `ScannerScreen`,
            // `ScannerBackRouter` and every `ScreenStateStore` key keep their
            // names, because those are vocabulary rather than copy.
            //
            // IDENTIFY named the verb; BLIND TASTING names the thing a drinker
            // is actually doing when they work a glass down from colour to body
            // to origin to flavour with no label in front of them, which is
            // exactly this screen's four steps.
            "BLIND TASTING"
        // Matches the TOOLS tile that has said LABEL SCAN since 0.7.0. The type
        // is `LabelReader*` throughout the code — the tile names what you do
        // with it, the code names what it is — and per house convention the
        // label is the thing that gets to be copy.
        case .labelReader:
            "LABEL SCAN"
        case .moonDial:
            "MOON DIAL"
        case .settings:
            "SYSTEM"
        case .settingsSection(let section):
            // The label, not the stored word (0.7.5, B2) — see
            // `SettingsSection.displayName`. For every section but SHOP the two
            // are the same string.
            section.displayName
        case .minigames:
            "TOOLS"
        // FILTER SEARCH → MASTER SEARCH (0.7.1, A1), label only; the case,
        // `ChipFilterScreen` and the `chipFilter` state key stay. The screen
        // was named after its controls rather than its job, and it is the one
        // door into the whole database — every category, chips and free text
        // together — which is what MASTER SEARCH always meant here.
        case .chipFilter:
            "MASTER SEARCH"
        case .wsetQuiz:
            // Renamed from TASTING QUIZ (v0.5.9, D1); the case keeps its name
            // — `wsetQuiz` is woven into `ScreenStateStore` keys.
            "WINE EXAM"
        case .dailyChallenge:
            "DAILY CHALLENGE"
        case .passport:
            "PASSPORT"
        // Not "STAMP COLLECTION": the marquee fits fourteen characters before it
        // scales, and this is sixteen — the same arithmetic FIRMWARE and WORKSHOP
        // below are the result of. The screen's own heading says COLLECTION.
        case .stampCollection:
            "STAMPS"
        case .walkthrough:
            "WALKTHROUGH"
        // Not "FIRMWARE HISTORY": the marquee fits fourteen characters before it
        // scales, and this is sixteen. The panel's own heading says HISTORY
        // underneath it, so nothing is lost by the marquee naming the subject.
        case .firmwareHistory:
            "FIRMWARE"
        case .cheatConsole:
            "CHEAT CODES"
        // Not "DEVICE WORKSHOP": the marquee fits fourteen characters before it
        // scales and this is fifteen. The panel's own heading carries the full
        // name, and WORKSHOP is what the entitlement is called anyway.
        case .deviceWorkshop:
            "WORKSHOP"
        // The screen's own hero names the grape, so the marquee names the kind
        // of page — the same trade `.country` makes, and it fits the marquee's
        // fourteen characters where "GRAPE LINEAGE" plus a name never would.
        case .lineage:
            "LINEAGE"
        case .continent:
            "CONTINENT SCAN"
        // **PACKS, not SHOP** (0.8.4, C1). C asks for a route "distinct from
        // Shop (same glyph)", and the title is the half that has to differ:
        // two frames on the stack both reading SHOP is the state the user was
        // already in — the marquee said SHOP while a pack page filled the LCD,
        // which is most of why Back felt like it should leave the store.
        //
        // The plural is deliberate. Singular would name the pack, and the pack
        // already names itself in 28pt on its own label; the marquee names the
        // *kind* of page, which is the trade `.country` and `.lineage` both make
        // one screen up.
        case .pack:
            "PACKS"
        // Not "YOU MIGHT LIKE", which is the section heading on the passport
        // and is a sentence. The marquee names the kind of page, and this one is
        // the ranked list behind that heading.
        case .recommendations:
            "SUGGESTIONS"
        case .support:
            "SUPPORT"
        }
    }

    /// SF Symbol shown between the marquee's text repetitions (v0.5.7) —
    /// `SYSTEM ⟨gear⟩ SYSTEM ⟨gear⟩ …`. Sits beside `title` because the two
    /// travel together into the footer. All iOS 17-safe — see KNOWN-ISSUES on
    /// symbols with a later OS floor rendering blank rather than failing.
    ///
    /// **Audited end to end in 0.7.0 (K2).** The table was written a route at a
    /// time as routes arrived, and by 0.6.9 a third of it was either generic or
    /// simply not this page's glyph. Three rules came out of going through all
    /// twenty-nine of them, and they are worth stating because the next route
    /// added here will need them:
    ///
    /// 1. **A page's glyph is the glyph on the control that opens it.** The
    ///    marquee confirms where you have arrived; showing something other than
    ///    what you just tapped is a small lie every time. Six entries disagreed
    ///    with their own tile.
    /// 2. **A filter is a page.** `.list` discarded its filter, so GEOLOGY,
    ///    RARITY and CLIMATE scans all wore their parent category's glyph. See
    ///    `EntryFilter.marqueeSymbol`.
    /// 3. **Collisions are only allowed where the pages really are the same
    ///    kind of page.** `map.fill` stood for the regions listing, a country
    ///    and a region detail; `globe.americas.fill` for four different world
    ///    screens; `sparkles` for both FLAVORS and the daily reveal. Those are
    ///    separated now by what the page actually is — the globe screen keeps
    ///    the globe, continents take `globe.europe.africa.fill`, a country takes
    ///    a flag.
    ///
    /// The remaining deliberate repeats are a category's glyph appearing on both
    /// its listing and its detail pages, which is `WineEntry.scanSymbol` agreeing
    /// with `EntryCategory.marqueeSymbol` on purpose.
    public var marqueeSymbol: String {
        switch self {
        // The filter's own glyph where there is one — a GEOLOGY SCAN is not a
        // regions listing wearing a map (K2, rule 2).
        case .list(let category, let filter):
            filter?.marqueeSymbol ?? category.marqueeSymbol
        // A fallback: detail titles come from the entry, and so does the
        // symbol — see `WineEntry.scanSymbol`.
        case .detail:
            "viewfinder"
        case .globe:
            "globe.americas.fill"
        // Places, not text: this searches continents, countries and regions,
        // and the plain magnifier it once shared with the master search said
        // nothing about which of the two searches you were in. A2 unifies
        // *search* on `DexGlyph.search`; this is a search of the world, and the
        // map disc is what says so.
        case .globeSearch:
            "map.circle.fill"
        // **A person, not a bookmark (0.8.5, A1).** The title is USER now, and
        // K2 rule 1 asks for the glyph on the control that opens it — which is
        // the chassis's USER cap, a figure. `person.fill` is on no other route
        // (`glyphsAreDistinct` gates that) and is SF Symbols 1 / iOS 13, well
        // under the iOS 17 floor.
        case .bookmarks:
            "person.fill"
        // A country, not a map — `map.fill` is the regions listing's, and this
        // is the one screen whose subject is a nation.
        case .country:
            "flag.fill"
        case .state:
            "mappin.and.ellipse"
        // Matches the TOOLS tile that opens it (K2, rule 1). A mortarboard:
        // the professor's page, and no other route wears one.
        case .profVino:
            "graduationcap.fill"
        // Matches its TOOLS tile, and frees `viewfinder` to be only the
        // unresolved-entry fallback above. `sparkle.magnifyingglass` until
        // 0.7.1: A2 reserves every magnifier for search, and once the tool was
        // called BLIND TASTING (E3) a magnifying glass was describing the
        // wrong sense entirely. A covered eye is the whole premise.
        case .scanner:
            "eye.slash.fill"
        // The tile's own glyph (K2, rule 1), and the one camera in the app —
        // `camera.fill` is the avatar picker's badge, which is a control rather
        // than a page, so nothing on this table collides with it. SF Symbols 2 /
        // iOS 14, well under the iOS 17 floor.
        case .labelReader:
            "camera.viewfinder"
        case .moonDial:
            "moon.stars.fill"
        case .settings:
            "gearshape.fill"
        case .settingsSection(let section):
            section.symbol
        case .minigames:
            "wrench.and.screwdriver.fill"
        // The magnifier, matching the round button that opens it (K2, rule 1)
        // now that A2 has made that button a magnifier too.
        case .chipFilter:
            DexGlyph.search
        // Matches its TOOLS tile. `graduationcap.fill` was a reasonable glyph
        // for an exam and the wrong one for *this* exam.
        case .wsetQuiz:
            "checkmark.seal.fill"
        // The challenge mark, which is what this page is. `calendar` was the
        // only hairline glyph in the table and it named the schedule rather
        // than the thing being kept. Through the constant, so 0.7.0's D1 and
        // 0.7.1's E1 both moved it in one place.
        case .dailyChallenge:
            DexGlyph.challenge
        case .passport:
            "book.closed.fill"
        // A stamp, and the one glyph in SF Symbols that is literally one. It has
        // to differ from `.passport`'s book because `glyphsAreDistinct` says so
        // and because the two pages are a page apart. SF Symbols 1 — well under
        // the iOS 17 floor.
        case .stampCollection:
            "seal.fill"
        case .walkthrough:
            "figure.walk"
        // Both match the System-panel rows that open them (K2, rule 1). A chip
        // for the firmware, a console prompt for the codes — and neither
        // collides, because `gearshape.fill` is the settings grid's and
        // `ladybug.fill` is DEV's. SF Symbols 4 and 2 respectively, both under
        // the iOS 17 floor.
        case .firmwareHistory:
            "memorychip.fill"
        case .cheatConsole:
            "terminal.fill"
        // Matches the OPEN button on CUSTOMIZE that leads here (K2, rule 1).
        //
        // Not `wrench.and.screwdriver.fill`, which is TOOLS' — the two pages are
        // not the same kind of page (K2, rule 3) and the crossed pair and the
        // single wrench are hard to tell apart at the marquee's 26pt anyway. A
        // hammer is unmistakable at that size, is nowhere else in the app, and
        // is SF Symbols 1 / iOS 13, well under the floor. It is also the right
        // sense: the workshop is where the device gets *built*, not where the
        // tools live.
        case .deviceWorkshop:
            "hammer.fill"
        // Matches the LINEAGE button on a grape's scan that leads here (K2,
        // rule 1). A forking branch is the shape of the thing — and it is the
        // only branch in the app, so it collides with nothing on this table.
        // SF Symbols 2 / iOS 14, well under the iOS 17 floor.
        case .lineage:
            "arrow.triangle.branch"
        // Not the globe: the globe screen is the globe, and a continent page is
        // one continent (K2, rule 3).
        case .continent:
            "globe.europe.africa.fill"
        // A box, where SHOP is a bag: the shelf is a storefront and this is one
        // thing off it. `shippingbox.fill` has been free since 0.7.5 retired
        // `SettingsSection.packs`, which is what it stood for then, so C1's
        // "same glyph" is honoured in the *art* (both wear `marquee-shop`) and
        // declined here — `glyphsAreDistinct` is a K2 assertion about symbols,
        // and two stack frames wearing one symbol is the exact confusion it
        // exists to catch. SF Symbols 1 / iOS 13, well under the iOS 17 floor.
        case .pack:
            "shippingbox.fill"
        // A thumbs-up: the page is a list of things the device thinks you would
        // like. `hand.thumbsup.fill` is SF Symbols 1 / iOS 13, well under the
        // floor, and is used nowhere else in this table.
        case .recommendations:
            "hand.thumbsup.fill"
        // **Not the seal.** `checkmark.seal.fill` is what the SUPPORT *row* in
        // SYSTEM wears, and matching it here would have been K2 rule 1 — a
        // page's glyph is the glyph on the control that opens it — except that
        // WINE EXAM has worn that symbol since 0.7.5, and `glyphsAreDistinct`
        // caught the collision on the first run. The envelope is the other true
        // thing about this page and is used nowhere else in this table. SF
        // Symbols 1 / iOS 13, well under the floor.
        case .support:
            "envelope.fill"
        }
    }

    /// The drawn face for this page's marquee glyph, or nil where there is none
    /// (0.8.3, A/H; re-based on its own art 0.8.4, A1).
    ///
    /// **These are no longer the button faces, and that is the item.** 0.8.3
    /// read K2 rule 1 — "a page's glyph is the glyph on the control that opens
    /// it" — as literally as it could be read, and put the *same file* on the
    /// panel that the tile behind it wears. That was the strongest form of the
    /// rule available with one drop of art. A1 supplies a second drop drawn for
    /// this surface alone, and the rule survives the change: what a page's glyph
    /// must match is its control's *subject*, and every stem below is the
    /// dot-matrix register of the picture on the control that opens it. GRAPES
    /// still shows grapes. What it no longer shows is a painted bunch with
    /// shading, shrunk to 34pt and flattened to a silhouette on a segment LCD.
    ///
    /// `ChromeTests.marqueeArtFollowsItsControl` is where that weaker claim is
    /// written down as pairs, and `marqueeArtIsOnDisk` is what stops a stem
    /// being a guess — a miss here does not blank the panel, it silently
    /// restores the SF Symbol, which is indistinguishable from the conversion
    /// not having reached this route.
    ///
    /// **Sixteen nils became four.** The 0.8.3 table had no face for the globe,
    /// a country, a state, a continent, the lineage graph, either search, or the
    /// main menu, because the button drop was drawn for controls and those pages
    /// have none. This drop is drawn for pages, so they have one. What is still
    /// nil is `.detail`'s unresolved fallback (`WineEntry.scanArt` answers for
    /// every entry that exists) and `.bookmarks`, which nobody drew.
    ///
    /// A filtered listing answers with the *filter's* face as of 0.8.5 (B1) —
    /// see `EntryFilter.marqueeArt`. K2 rule 2 is unchanged and is what that
    /// table implements: a GEOLOGY SCAN is not a regions listing, so it may not
    /// wear the regions face — but a STYLE SCAN is a scan of styles and had been
    /// wearing nothing at all.
    public var marqueeArt: String? {
        switch self {
        case .list(let category, let filter):
            filter.map(\.marqueeArt) ?? category.marqueeArt
        // The detail screen overrides both halves through `WineEntry.scanArt`;
        // this is the unresolved-entry fallback and has no picture.
        case .detail:
            nil
        // **`marquee-user` (0.8.5, A1).** This answered nil for one release on
        // the grounds that "nobody drew a bookmark", which was true and was
        // looking at the wrong drawing: the 0.8.4 drop has a `user` glyph, and
        // it went unclaimed because this page was called SAVED. A1 renames the
        // page and the picture was already on disk waiting for it.
        case .bookmarks:
            "marquee-user"
        // The four places, each drawn as itself rather than as a globe: a
        // country is a flag on a map, a state is the same at another scale, a
        // continent is a hemisphere. The globe and the world search share
        // `globescan`, which is allowed — art repeats on purpose and only
        // `marqueeSymbol` must be distinct.
        case .globe, .globeSearch: "marquee-globescan"
        case .country: "marquee-countryscan"
        case .state: "marquee-countryscan"
        case .continent: "marquee-continentscan"
        case .lineage: "marquee-lineage"
        // The six TOOLS tiles, in the order the shelf draws them.
        case .scanner: "marquee-blindtasting"
        case .labelReader: "marquee-labelscanner"
        case .wsetQuiz: "marquee-wineexam"
        case .dailyChallenge: "marquee-dailychallenge"
        // The professor's own dot-matrix portrait (0.9.43) — the mortarboard
        // stood in from 0.8.93 until the maintainer drew him.
        case .profVino: "marquee-profvino"
        case .moonDial: "marquee-moondial"
        // The shelf itself, from the SETTINGS grid's TOOLS door.
        case .minigames: "marquee-tools"
        // **The 0.8.3 collision resolves itself here.** In the button drop the
        // route *titled* SYSTEM had to take the `settings` face, because that
        // drop's `system` picture was the chassis cog and belonged to the
        // hardware. This drop is drawn per page and has both: SYSTEM takes
        // `system`, SETTINGS takes `settings`, and neither borrows the other's.
        case .settings: "marquee-system"
        case .settingsSection(let section): section.marqueeStem
        // The four SYSTEM-panel rows that open them.
        case .walkthrough: "marquee-tutorial"
        case .firmwareHistory: "marquee-firmware"
        case .cheatConsole: "marquee-cheatcodes"
        case .deviceWorkshop: "marquee-deviceworkshop"
        case .passport: "marquee-passport"
        // **No longer the passport's (0.8.9a, A6).** C3 shared the picture on
        // the grounds that nobody had drawn a stamp for the marquee and that
        // art may repeat where a subject repeats. The first half stopped being
        // true — the drop has a franked stamp in the dot-matrix register — and
        // once it did, the second half stopped being a reason: a permitted
        // repeat is not a preferred one, and the collection and the passport
        // are two pages a user can be on.
        case .stampCollection: "marquee-stamps"
        // The magnifier the round button that opens it already wears — drawn as
        // the master search rather than as a bare glass.
        case .chipFilter: "marquee-mastersearch"
        // The pack splash (0.8.4, C1). It shares the shop's picture on purpose:
        // C asks for a route distinct from SHOP wearing the same glyph, and art
        // is the half of the pair that is allowed to repeat.
        case .pack: "marquee-shop"
        // Drawn in the 0.9.43 drop — the thumbs-up and the envelope, ending
        // the last two nils this table carried besides `.detail`'s deliberate
        // fallback.
        case .recommendations: "marquee-suggestions"
        case .support: "marquee-support"
        }
    }
}

public extension EntryCategory {
    /// The category's drawn marquee face (0.8.3, A) — the exact stem the main
    /// menu's own tile passes to `DexChromeGlyph`, which is K2 rule 1 with the
    /// two ends now being the same file rather than two agreeing switches.
    ///
    /// **Continents stopped answering nil in 0.8.4 (A1).** The menu still has no
    /// CONTINENTS tile and the globe is still reached from the chassis, but the
    /// reason this was nil was narrower than either: no face in the 0.8.1 button
    /// drop drew a world. The marquee drop does.
    var marqueeArt: String? {
        switch self {
        case .grapes: "marquee-grapescan"
        case .regions: "marquee-regions"
        case .styles: "marquee-stylescan"
        case .flavors: "marquee-flavorscan"
        // No longer nil (0.8.4, A1). The 0.8.1 button drop had no world in it,
        // which is why this answered nil for three releases; the marquee drop
        // does, so the CONTINENTS listing stops falling back to its SF Symbol.
        case .continents: "marquee-continentscan"
        }
    }

    /// The category's marquee glyph — see `DexRoute.marqueeSymbol`.
    var marqueeSymbol: String {
        switch self {
        // The main menu's own GRAPES tile (K2, rule 1). `leaf.fill` was doubly
        // wrong: it is the glyph on the menu's *FLAVORS* tile, so tapping GRAPES
        // put the other category's icon on the marquee.
        case .grapes: "circle.grid.3x3.fill"
        case .regions: "map.fill"
        case .styles: "wineglass.fill"
        // The menu's FLAVORS tile, now that grapes no longer hold it.
        case .flavors: "leaf.fill"
        case .continents: "globe.europe.africa.fill"
        }
    }
}

public extension WineEntry {
    /// Where tapping this entry leads.
    ///
    /// The web app branches here for COUNTRY_GATE entries (drilling into states
    /// or regions). Those are out of scope for the starter, so every entry opens
    /// its detail readout — except continents, which open the dedicated
    /// ContinentScreen rather than the generic entry detail readout.
    var destination: DexRoute {
        if case .continent(let c) = self { return .continent(entryID: c.id) }
        return .detail(entryID: id)
    }

    /// Header title for the detail screen, matching the web app's scan titles.
    var scanTitle: String {
        switch self {
        case .grape: "GRAPE SCAN"
        case .region: "REGION SCAN"
        case .flavor: "FLAVOR SCAN"
        case .style: "STYLE SCAN"
        case .continent: "CONTINENT SCAN"
        }
    }

    /// Marquee glyph for the detail screen — the entry-level counterpart of
    /// `scanTitle`, same reasoning as `DexRoute.marqueeSymbol`.
    var scanSymbol: String {
        switch self {
        case .grape: EntryCategory.grapes.marqueeSymbol
        case .region: EntryCategory.regions.marqueeSymbol
        case .flavor: EntryCategory.flavors.marqueeSymbol
        case .style: EntryCategory.styles.marqueeSymbol
        case .continent: EntryCategory.continents.marqueeSymbol
        }
    }

    /// The drawn face for the detail screen's marquee (0.8.3, A), following
    /// `scanSymbol` through the same category so a GRAPE SCAN and the grapes
    /// listing wear one picture. That repeat is deliberate and is the one
    /// `marqueeSymbol`'s own note calls out.
    var scanArt: String? {
        switch self {
        case .grape: EntryCategory.grapes.marqueeArt
        case .region: EntryCategory.regions.marqueeArt
        case .flavor: EntryCategory.flavors.marqueeArt
        case .style: EntryCategory.styles.marqueeArt
        case .continent: EntryCategory.continents.marqueeArt
        }
    }
}
