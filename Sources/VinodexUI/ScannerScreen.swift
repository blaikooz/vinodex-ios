#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import VinodexCore

/// The scanner: five questions about the glass in front of you, then a
/// deduction.
///
/// The whole flow lives in one view with a `Step` cursor rather than as pushed
/// `DexRoute`s. That is the opposite of the choice made for the settings
/// sections, and for the opposite reason: settings panels are independent
/// destinations, whereas these steps share one accumulating answer.
///
/// The chassis Back button steps between questions too (0.6.4, B2), via
/// `ScannerBackRouter`. It used to mean "leave the scanner" — but the
/// questionnaire persists across the pop, so leaving from question three and
/// re-entering landed you back on question three, and the main Back button
/// read as broken on every scanner page. It now unwinds the cursor like the
/// in-screen arrow, and only pops the route from question one.
public struct ScannerScreen: View {
    let onOpen: (WineEntry) -> Void

    /// Both mirrored into `ScreenStateStore` on every change — see
    /// `persist()`. `@State` alone dies with the view, and this screen is one of
    /// the two the user *leaves and comes back to* mid-task: the reveal offers
    /// OPEN ENTRY, and taking it used to mean answering all five questions again
    /// to see the second candidate.
    @State private var step: Step = .color
    @State private var criteria = GrapeScanCriteria()
    @State private var screens = ScreenStateStore.shared
    /// The flavour step's search box. Session-local on purpose: the answers
    /// persist across the trip to an entry, but a half-typed query is scaffolding,
    /// not an answer.
    @State private var flavorQuery = ""
    /// What that box matches, recomputed on change rather than in `body`.
    ///
    /// It was resolved inside a `@ViewBuilder` property, so it re-ran on every
    /// body pass of the whole scanner — not merely on every keystroke —
    /// re-folding every searched field of every entry each time (AUDIT M5).
    @State private var flavorMatches: [WineEntry] = []
    /// Which query `flavorMatches` actually answers. `nil` until the first run.
    ///
    /// Load-bearing for the empty case: during the debounce the results belong
    /// to the *previous* query, and an empty array then means "not asked yet",
    /// not "nothing matches". Without this the first character typed produces
    /// "No flavor matches that." for the length of the debounce.
    @State private var matchedQuery: String?
    /// The query the last `task` run started from — see `awaitSearchDebounce`.
    @State private var debouncedFrom = ""
    /// Whether the reveal's runner-up list is expanded past the shortlist
    /// (0.6.8, L5). Session-local, like `flavorQuery`: it describes how you are
    /// looking at one result, not what you answered, so it resets with the next
    /// scan rather than persisting into it.
    @State private var showsAllMatches = false

    /// How many runners-up the reveal lists before SHOW ALL takes over
    /// (0.6.8, L5). Four, so the card reads as "the best one, and these four" —
    /// five grapes total, which is the count L5 names as the threshold.
    private static let revealShortlist = 4

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    private let db = WineDatabase.shared

    public init(onOpen: @escaping (WineEntry) -> Void) {
        self.onOpen = onOpen
    }

    // MARK: Steps

    private enum Step: Hashable {
        case color
        case body
        case origin
        /// The globe itself, reached from the origin question.
        case globe
        case country(Continent)
        case flavors
        /// A filtered flavour list, opened from a class or subclass tile.
        case flavorList(kind: FlavorKind, value: String)
        case reveal
    }

    private enum FlavorKind: Hashable {
        case classification
        case subclass

        var storageValue: String {
            switch self {
            case .classification: "class"
            case .subclass: "sub"
            }
        }
    }

    /// Which of the five questions a step belongs to. The globe, the country
    /// list and the flavour list are continuations of their question rather
    /// than questions of their own, so they do not advance the counter.
    private var questionNumber: Int {
        switch step {
        case .color: 1
        case .body: 2
        case .origin, .globe, .country: 3
        case .flavors, .flavorList: 4
        case .reveal: 5
        }
    }

    private func back() {
        Haptics.select()
        withAnimation(.easeOut(duration: 0.2)) {
            switch step {
            case .color: break
            case .body: step = .color
            case .origin: step = .body
            case .globe: step = .origin
            case .country: step = .globe
            case .flavors: step = .origin
            case .flavorList: step = .flavors
            case .reveal: step = .flavors
            }
        }
    }

    private func advance(to next: Step) {
        withAnimation(.easeOut(duration: 0.2)) { step = next }
    }

    // MARK: Surviving the trip to an entry

    /// Where the questionnaire had got to, as a string.
    ///
    /// Spelled out rather than derived from `String(describing:)` for the reason
    /// `ScreenStateStore`'s own keys are: that form is a compiler detail, and a
    /// renamed case would silently restore the wrong question. Split with
    /// `maxSplits` so a flavour value containing a colon still round-trips.
    private static func storageValue(of step: Step) -> String {
        switch step {
        case .color: "color"
        case .body: "body"
        case .origin: "origin"
        case .globe: "globe"
        case .country(let continent): "country:" + continent.rawValue
        case .flavors: "flavors"
        case .flavorList(let kind, let value): "flavorList:\(kind.storageValue):\(value)"
        case .reveal: "reveal"
        }
    }

    private static func step(from raw: String) -> Step? {
        let parts = raw.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        switch parts.first.map(String.init) {
        case "color": return .color
        case "body": return .body
        case "origin": return .origin
        case "globe": return .globe
        case "flavors": return .flavors
        case "reveal": return .reveal
        case "country":
            guard parts.count == 2, let continent = Continent(rawValue: String(parts[1])) else { return nil }
            return .country(continent)
        case "flavorList":
            guard parts.count == 3 else { return nil }
            let kind: FlavorKind? = parts[1] == "class" ? .classification : (parts[1] == "sub" ? .subclass : nil)
            guard let kind else { return nil }
            return .flavorList(kind: kind, value: String(parts[2]))
        default: return nil
        }
    }

    /// Restores on appear rather than on init: the view is rebuilt on every
    /// navigation and an initialiser cannot touch `@State` that SwiftUI has not
    /// installed yet. Anything unreadable falls back to a fresh scan.
    private func restore() {
        let key = ScreenStateStore.scanner
        if let raw = screens.value("step", for: key), let restored = Self.step(from: raw) {
            step = restored
        }
        if let saved = screens.decoded(GrapeScanCriteria.self, "criteria", for: key) {
            criteria = saved
        }
    }

    private func persist() {
        let key = ScreenStateStore.scanner
        screens.setValue(Self.storageValue(of: step), "step", for: key)
        // A blank slate stores nothing, so RESET genuinely resets: leaving and
        // returning after it lands back on question one rather than on whatever
        // was there before.
        screens.encode(criteria.isEmpty ? nil : criteria, "criteria", for: key)
    }

    // MARK: Body

    public var body: some View {
        ZStack {
            DexScreenBackground()

            switch step {
            case .globe:
                // Full-bleed: the globe needs the height, and a scroll view
                // around a drag-to-spin surface fights the gesture.
                VStack(spacing: 0) {
                    header
                    globeStep
                }
            default:
                VStack(spacing: 0) {
                    header
                    // Centred and cushioned rather than pinned to the top-left.
                    // Each step is two lines of prompt and a handful of controls
                    // — a third of a screen of content sitting in the top corner
                    // of an otherwise empty LCD, which read as a form rather
                    // than as a game.
                    //
                    // `GeometryReader` rather than `onGeometryChange(for:)`:
                    // that one is iOS 18 and the deployment target is 17, where
                    // it compiles against the SDK and is simply unavailable at
                    // runtime. The reader gives the scroll view's own height, so
                    // `minHeight` centres short steps in the visible area while
                    // long ones (the flavour lists) still scroll from the top.
                    GeometryReader { geo in
                        ScrollView {
                            content
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 22)
                                .frame(minHeight: geo.size.height, alignment: .center)
                        }
                    }
                }
            }
        }
        .onAppear {
            restore()
            // The chassis Back button routes here first (0.6.4, B2): consume
            // the press by stepping back a question, or decline from question
            // one so the app pops the route. Registered on appear and cleared
            // on disappear — a trip into an entry from the reveal unmounts
            // this view, and a stale handler would eat the entry's Back.
            ScannerBackRouter.shared.handler = {
                if step == .color { return false }
                back()
                return true
            }
        }
        .onDisappear { ScannerBackRouter.shared.handler = nil }
        // Debounced (AUDIT M5): `task(id:)` cancels the pending run on the next
        // keystroke, so a burst of typing queries once at the end of the burst.
        .task(id: flavorQuery) {
            let previous = debouncedFrom
            debouncedFrom = flavorQuery
            guard await awaitSearchDebounce(from: previous, to: flavorQuery) else { return }
            flavorMatches = db.entries(
                matching: EntryQuery(categories: [.flavors], search: flavorQuery)
            )
            matchedQuery = flavorQuery
        }
        // Mirrored on change rather than at each of the dozen call sites that
        // move the cursor or amend an answer — one of those would eventually be
        // added without its matching save.
        .onChange(of: step) { _, _ in persist() }
        .onChange(of: criteria) { _, _ in persist() }
    }

    /// No in-screen back arrow since 0.6.5 (item 6): the chassis Back button
    /// steps the questionnaire via `ScannerBackRouter` (0.6.4, B2), so the
    /// header arrow was a second control doing the same thing — and the
    /// device's own buttons are the ones that should do device things.
    ///
    /// **The step counter has left this row (0.6.9, H2).** It sat here, hard
    /// against the leading edge, with RESET at the trailing one — chrome in the
    /// top corner of a screen whose content is centred in the middle of the
    /// LCD, so the number and the question it counted were the two things
    /// furthest apart on the page. H2 puts it directly above the question and
    /// centred on it; see `question(_:_:content:)`. RESET keeps the row, and
    /// the reveal keeps its RESULT label here because a result is not a
    /// question and does not go through that helper.
    private var header: some View {
        HStack(spacing: 10) {
            if step == .reveal {
                Text("RESULT")
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(lcd.subtext)
            } else if step == .globe {
                // The one question step that does not go through
                // `question(_:_:content:)` — the globe is mounted full-bleed,
                // because it needs the height and a scroll view around a
                // drag-to-spin surface fights the gesture. Its counter has
                // nowhere else to be, so it stays in the row.
                Text("STEP \(questionNumber) OF 5")
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(lcd.subtext)
            }

            Spacer(minLength: 0)

            if !criteria.isEmpty {
                // A real red button (0.6.4, B3), not bare text: RESET throws
                // away answers, and the destructive controls elsewhere (CLEAR
                // SAVED DATA, REVOKE ALL) already speak this red-on-outline
                // dialect — the scanner's was the only one whispering.
                Button {
                    Haptics.select()
                    withAnimation(.easeOut(duration: 0.2)) {
                        criteria = GrapeScanCriteria()
                        showsAllMatches = false
                        step = .color
                    }
                } label: {
                    Text("RESET")
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .foregroundStyle(Dex.red500)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Dex.red500.opacity(0.65), lineWidth: 2)
                        )
                }
                .buttonStyle(DexPressStyle(scale: 0.94))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .color: colorStep
        case .body: bodyStep
        case .origin: originStep
        case .globe: EmptyView()   // handled full-bleed above
        case .country(let continent): countryStep(continent)
        case .flavors: flavorStep
        case .flavorList(let kind, let value): flavorListStep(kind: kind, value: value)
        case .reveal: revealStep
        }
    }

    // MARK: 1 — colour

    private var colorStep: some View {
        question("WHAT COLOR?", "Start with the easy one.") {
            HStack(spacing: 10) {
                ForEach([GrapeColor.red, .white], id: \.rawValue) { option in
                    chip(
                        label: option.rawValue.uppercased(),
                        chip: db.palette.colorTypeChips[option.rawValue.uppercased()],
                        selected: criteria.color == option,
                        fill: true,
                        iconID: db.icons.colorIcon(option.rawValue.uppercased())
                    ) {
                        criteria.color = criteria.color == option ? nil : option
                        advance(to: .body)
                    }
                }
            }
            skip("NOT SURE") { advance(to: .body) }
        }
    }

    // MARK: 2 — body

    private var bodyStep: some View {
        question("HOW IS THE BODY?", "How much of it is there, from a wisp to a mouthful.") {
            // Stacked, not side by side: three abreast squeezed LIGHT/MEDIUM/
            // FULL to a width where the labels shrank, and a vertical run
            // also reads as the scale it is — a wisp at the top, a mouthful
            // at the bottom.
            VStack(spacing: 8) {
                ForEach(GrapeBody.allCases) { option in
                    chip(
                        label: option.label,
                        chip: bodyChip(option),
                        selected: criteria.body == option,
                        fill: true,
                        iconID: db.icons.bodyIcon(option.rawValue)
                    ) {
                        criteria.body = criteria.body == option ? nil : option
                        advance(to: .origin)
                    }
                }
            }
            skip("NOT SURE") { advance(to: .origin) }
        }
    }

    /// Body has no generated palette table of its own, so it borrows the
    /// wine-type chips' vocabulary: the same three weights, graded light to
    /// full.
    ///
    /// The table itself moved to `Palette.bodyChips` in 0.6.9 (J1). It was
    /// private here, and the filter screen's new BODY hero chips need the same
    /// three colours — two copies of a hand-authored triple is exactly the
    /// arrangement that ends with a scanner answer and a filter chip for the
    /// same body class in two different greens.
    private func bodyChip(_ body: GrapeBody) -> Palette.Chip {
        Palette.bodyChips[body.rawValue]
            ?? Palette.Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
    }

    // MARK: 3 — origin

    private var originStep: some View {
        question("DO YOU KNOW WHERE IT'S FROM?", "Open the globe and walk it down, or say so and move on.") {
            VStack(spacing: 10) {
                if let country = criteria.country {
                    HStack(spacing: 10) {
                        FlagSwatch(country: country, width: 52, height: 34)
                        Text(country.uppercased())
                            .font(DexFont.retro(12))
                            .foregroundStyle(lcd.text)
                        Spacer(minLength: 0)
                        Button {
                            Haptics.select()
                            criteria.country = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(lcd.subtext)
                        }
                        .buttonStyle(DexPressStyle(scale: 0.9))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.accent, lineWidth: 2)
                    )
                }

                bigButton(
                    criteria.country == nil ? "OPEN GLOBE SCAN" : "PICK ANOTHER",
                    symbol: "globe.americas.fill",
                    tint: Dex.green
                ) {
                    advance(to: .globe)
                }

                // "NOT SURE", not "I DON'T KNOW" (0.6.8, L3) — the same words
                // the colour and body steps skip with, so one answer has one
                // name across the whole questionnaire. **Glyphless since 0.6.9
                // (H1)** — see `bigButton`.
                bigButton("NOT SURE", tint: lcd.subtext) {
                    criteria.country = nil
                    advance(to: .flavors)
                }

                if criteria.country != nil {
                    bigButton("NEXT", symbol: "arrow.right", tint: Dex.yellow) {
                        advance(to: .flavors)
                    }
                }
            }
        }
    }

    private var globeStep: some View {
        // The real globe screen, not a copy of it: "open globe scan" should
        // open the globe scan. `showsSearch` is off because world search is a
        // route push, and pushing out of the scanner would discard the answers
        // collected so far.
        RetroGlobeScreen(
            onSelectContinent: { continent in
                advance(to: .country(continent))
            },
            onWorldSearch: {},
            showsSearch: false
        )
    }

    private func countryStep(_ continent: Continent) -> some View {
        let countries = db.countries(in: continent)

        return question(
            continent.displayName,
            "Which one?"
        ) {
            if countries.isEmpty {
                emptyNote("No countries listed for this continent.")
            } else {
                VStack(spacing: 8) {
                    ForEach(countries, id: \.self) { country in
                        Button {
                            Haptics.select()
                            criteria.country = country
                            advance(to: .flavors)
                        } label: {
                            HStack(spacing: 12) {
                                FlagSwatch(country: country, width: 64, height: 42)
                                Text(country.uppercased())
                                    .font(DexFont.retro(14))
                                    .foregroundStyle(lcd.text)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(lcd.subtext)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(lcd.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                            )
                        }
                        .buttonStyle(DexPressStyle(scale: 0.98))
                    }
                }
            }
        }
    }

    // MARK: 4 — flavours

    private var basket: [WineEntry] {
        criteria.flavorIDs.compactMap { db.entry(id: $0) }
    }

    private var flavorStep: some View {
        question(
            "AROMAS AND FLAVORS?",
            "Search, or pick a family to browse. Up to \(GrapeScanCriteria.flavorLimit) go in the basket — fewer is fine, none is fine."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                basketView

                // **Directly under the basket** (0.6.8, L1). SCAN used to close
                // the step, below the class and subclass grids — which put the
                // one control that ends the questionnaire at the bottom of a
                // scroll two or three screens long, so finishing meant scrolling
                // past every tile you had just decided against. The basket is
                // where the answer *is*; the button that acts on it belongs
                // against it.
                bigButton(
                    // L4: the empty-basket label. "CONTINUE WITHOUT FLAVORS"
                    // described the mechanism; "NOT SURE, SCAN" is the same
                    // answer in the vocabulary the rest of the questionnaire
                    // now uses (see `skip`, and L3 on step 3).
                    basket.isEmpty ? "NOT SURE, SCAN" : "SCAN",
                    symbol: "sparkle.magnifyingglass",
                    tint: Dex.yellow
                ) {
                    advance(to: .reveal)
                }

                // Name a flavour directly rather than walking the taxonomy —
                // someone who can already say "graphite" should not have to
                // know which subclass files it.
                DexSearchBar(text: $flavorQuery, placeholder: "SEARCH FLAVORS…")

                if flavorQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    group("CLASSES", values: db.flavorClasses, kind: .classification)
                    group("SUBCLASSES", values: db.flavorSubclasses, kind: .subclass)
                } else {
                    flavorSearchResults
                }
            }
        }
    }

    /// Search matches as the same hero-icon tiles the subclass lists use
    /// (0.6.4, B1) — one affordance for "a pickable flavour", wherever it was
    /// found, and the drawn portraits reach the search path too.
    @ViewBuilder
    private var flavorSearchResults: some View {
        // Merged (testing): PR #10's debounced source (M5) feeding the 0.6.4
        // hero-icon tiles — the results are `flavorMatches`, not a per-render
        // query, and they render as the tile grid, not chips.
        let matches = flavorMatches
        if !matches.isEmpty {
            // Held from the previous query while a new one debounces, which is
            // what a search list is expected to do — the alternative is a blank
            // beat between every pair of keystrokes.
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(matches) { flavor in
                    flavorTile(flavor)
                }
            }
        } else if matchedQuery == flavorQuery {
            // Only once the results are known to answer *this* query. Empty
            // before that means unasked, not unmatched — see `matchedQuery`.
            emptyNote("No flavor matches that.")
        }
    }

    /// The class and subclass doorways as little tiles — hero icon over name
    /// (0.6.2, B2). These finally wear the drawn taxonomy glyphs; as chips
    /// they had nowhere to put one.
    private func group(_ title: String, values: [String], kind: FlavorKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DexFont.retro(12))
                .tracking(1)
                .foregroundStyle(lcd.accent)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(values, id: \.self) { value in
                    taxonomyTile(value, kind: kind)
                }
            }
        }
    }

    private func taxonomyTile(_ value: String, kind: FlavorKind) -> some View {
        let paletteChip = kind == .classification
            ? db.palette.flavorClassChips[value]
            : db.palette.flavorSubclassChips[value]
        let resolved = paletteChip ?? Palette.Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
        let iconID = kind == .classification
            ? db.icons.flavorClassIcon(value)
            : db.icons.flavorSubclassIcon(value)

        return Button {
            Haptics.select()
            advance(to: .flavorList(kind: kind, value: value))
        } label: {
            VStack(spacing: 6) {
                DexIcon(iconID: iconID, size: 44, color: Color(dexHex: resolved.text))
                Text(EntryDisplay.hyphenated(value.replacingOccurrences(of: "_", with: " ").uppercased()))
                    .font(DexFont.retro(10))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Color(dexHex: resolved.text))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 6).fill(Color(dexHex: resolved.bg).opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(dexHex: resolved.border), lineWidth: 1)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.95))
    }

    @ViewBuilder
    private var basketView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "basket.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(lcd.accent)
                Text("BASKET \(basket.count)/\(GrapeScanCriteria.flavorLimit)")
                    .font(DexFont.retro(10))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                Spacer(minLength: 0)
            }

            if basket.isEmpty {
                Text("Empty — that is a valid answer.")
                    .font(DexFont.mono(16))
                    .foregroundStyle(lcd.subtext)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(basket) { flavor in
                        Button {
                            Haptics.select()
                            criteria.toggleFlavor(flavor.id)
                        } label: {
                            HStack(spacing: 5) {
                                Text(flavor.name.uppercased())
                                    .font(DexFont.retro(10))
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(Color(dexHex: flavorChip(flavor).text))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(dexHex: flavorChip(flavor).bg))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color(dexHex: flavorChip(flavor).border), lineWidth: 1)
                            )
                        }
                        .buttonStyle(DexPressStyle(scale: 0.94))
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
        )
    }

    private func flavorChip(_ entry: WineEntry) -> Palette.Chip {
        guard case .flavor(let f) = entry else {
            return Palette.Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
        }
        return db.palette.flavorSubclassChips[f.details.subclass]
            ?? db.palette.flavorClassChips[f.details.classification]
            ?? Palette.Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
    }

    private func flavorListStep(kind: FlavorKind, value: String) -> some View {
        let matches = kind == .classification
            ? db.flavors(inClass: value)
            : db.flavors(subclass: value)

        return question(
            value.replacingOccurrences(of: "_", with: " "),
            criteria.flavorsAreFull
                ? "Basket is full — remove one to swap it out."
                : "Tap what you can taste."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                basketView

                // Under the basket, for the same reason SCAN is (0.6.8, L1):
                // a subclass can run to thirty tiles, and DONE at the foot of
                // them meant scrolling the whole list again to leave it.
                bigButton("DONE", symbol: "checkmark", tint: Dex.green) {
                    advance(to: .flavors)
                }

                if matches.isEmpty {
                    emptyNote("Nothing filed under this one.")
                } else {
                    // Hero-icon + name tiles (0.6.4, B1), matching the class
                    // and subclass doorways one step up. These were text chips
                    // with a 22pt *tinted glyph* — the note's generic
                    // game-icons mark, flattened to the chip's ink — so the
                    // drawn flavour portraits never appeared on this step at
                    // all. The tile's `EntryIconWell` resolves the same
                    // full-colour art the list rows and reveal wear.
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                        spacing: 8
                    ) {
                        ForEach(matches) { flavor in
                            flavorTile(flavor)
                        }
                    }
                }
            }
        }
    }

    /// One pickable flavour as a tile: its own pixel-art portrait over its
    /// name, in its subclass's chip colours — a choice, so selection fills it
    /// in and badges a checkmark, unlike the doorway tiles it sits beside.
    private func flavorTile(_ flavor: WineEntry) -> some View {
        let chosen = criteria.flavorIDs.contains(flavor.id)
        let resolved = flavorChip(flavor)

        return Button {
            Haptics.select()
            // The cap is enforced in `toggleFlavor`, so a tap past the limit
            // is a no-op rather than a silent replacement of someone's first
            // pick.
            criteria.toggleFlavor(flavor.id)
        } label: {
            VStack(spacing: 6) {
                EntryIconWell(entry: flavor, size: 44, cornerRadius: 8)
                Text(EntryDisplay.hyphenated(flavor.name.uppercased()))
                    .font(DexFont.retro(9))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Color(dexHex: resolved.text))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(dexHex: resolved.bg).opacity(chosen ? 1 : 0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(dexHex: resolved.border), lineWidth: chosen ? 3 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if chosen {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(dexHex: resolved.text))
                        .padding(4)
                }
            }
        }
        .buttonStyle(DexPressStyle(scale: 0.95))
    }

    // MARK: 5 — reveal

    private var revealStep: some View {
        let matches = db.grapesMatching(criteria)

        return VStack(alignment: .leading, spacing: 16) {
            criteriaSummary

            if let best = matches.first {
                // **Best match, then four, then the rest behind SHOW ALL**
                // (0.6.8, L5). It used to be best plus a flat six, with the
                // remainder simply not listed and a count in the heading
                // standing in for them — so a scan that fitted twenty grapes
                // showed seven of them and there was no way to reach the other
                // thirteen. Four runners-up is a glance; the expander is where
                // the long tail goes.
                reveal(best, others: Array(matches.dropFirst()), total: matches.count)
            } else {
                notFound
            }

            bigButton("SCAN AGAIN", symbol: "arrow.counterclockwise", tint: lcd.subtext) {
                Haptics.select()
                withAnimation(.easeOut(duration: 0.2)) {
                    criteria = GrapeScanCriteria()
                    step = .color
                }
            }
        }
    }

    private var criteriaSummary: some View {
        FlowLayout(spacing: 6) {
            if let color = criteria.color {
                summaryChip(color.rawValue.uppercased(), db.palette.colorTypeChips[color.rawValue.uppercased()])
            }
            if let body = criteria.body {
                summaryChip(body.label, bodyChip(body))
            }
            if let country = criteria.country {
                summaryChip(country.uppercased(), db.palette.chip(country: country))
            }
            ForEach(basket) { flavor in
                summaryChip(flavor.name.uppercased(), flavorChip(flavor))
            }
            if criteria.isEmpty {
                summaryChip("NO CRITERIA", nil)
            }
        }
    }

    private func summaryChip(_ label: String, _ chip: Palette.Chip?) -> some View {
        let resolved = chip ?? Palette.Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
        return Text(label)
            .font(DexFont.retro(11))
            .foregroundStyle(Color(dexHex: resolved.text))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color(dexHex: resolved.bg)))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(dexHex: resolved.border), lineWidth: 1)
            )
    }

    private func reveal(_ grape: WineEntry, others: [WineEntry], total: Int) -> some View {
        VStack(spacing: 14) {
            Text(total == 1 ? "IT'S PROBABLY" : "BEST MATCH")
                .font(DexFont.retro(14))
                .tracking(2)
                .foregroundStyle(Dex.yellow)

            EntryIconWell(entry: grape, size: 150, cornerRadius: 18)

            Text(grape.name.uppercased())
                .font(DexFont.retro(22))
                .foregroundStyle(lcd.text)
                .shadow(color: lcd.accent.opacity(0.55), radius: 0, x: 3, y: 3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(grape.entryDescription)
                .font(DexFont.mono(21))
                .foregroundStyle(lcd.bodyText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.screenTap()
                onOpen(grape)
            } label: {
                Text("OPEN ENTRY")
                    .font(DexFont.retro(15))
                    .tracking(2)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 18)
                    .background(Capsule().fill(Dex.green))
            }
            .buttonStyle(DexPressStyle(scale: 0.96))

            if !others.isEmpty {
                // The next four, and the rest only if asked for (0.6.8, L5).
                let shortlist = Array(others.prefix(Self.revealShortlist))
                let hidden = others.count - shortlist.count
                let shown = showsAllMatches ? others : shortlist

                VStack(alignment: .leading, spacing: 8) {
                    Text("ALSO FITS (\(total - 1) MORE)")
                        .font(DexFont.retro(12))
                        .tracking(1)
                        .foregroundStyle(lcd.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(shown) { other in
                        Button {
                            Haptics.select()
                            onOpen(other)
                        } label: {
                            HStack(spacing: 10) {
                                EntryIconWell(entry: other, size: 44, cornerRadius: 8)
                                Text(other.name.uppercased())
                                    .font(DexFont.retro(13))
                                    .foregroundStyle(lcd.text)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(lcd.subtext)
                            }
                            .padding(7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(lcd.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                            )
                        }
                        .buttonStyle(DexPressStyle(scale: 0.98))
                    }

                    if hidden > 0 {
                        Button {
                            Haptics.select()
                            withAnimation(.easeOut(duration: 0.2)) {
                                showsAllMatches.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: showsAllMatches ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                                Text(showsAllMatches ? "SHOW FEWER" : "SHOW ALL \(total)")
                                    .font(DexFont.retro(12))
                                    .tracking(1)
                            }
                            .foregroundStyle(lcd.accent)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 6).fill(lcd.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(lcd.accent.opacity(0.6), lineWidth: 2)
                            )
                        }
                        .buttonStyle(DexPressStyle(scale: 0.97))
                        .accessibilityLabel(
                            showsAllMatches
                                ? "Show fewer matches"
                                : "Show all \(total) matches"
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8).fill(lcd.accent.opacity(0.07)))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(lcd.accent.opacity(0.45), lineWidth: 2)
        )
    }

    private var notFound: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.diamond.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Dex.amber400)

            Text("GRAPE NOT FOUND")
                .font(DexFont.retro(19))
                .tracking(1)
                .foregroundStyle(Dex.amber400)
                .multilineTextAlignment(.center)

            Text("You're drinking rare grapes!")
                .font(DexFont.mono(24))
                .foregroundStyle(lcd.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Nothing in the database fits all of that. Loosen a criterion and scan again — or accept the compliment.")
                .font(DexFont.mono(16))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 8).fill(Dex.amber400.opacity(0.1)))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(Dex.amber400.opacity(0.5), lineWidth: 2)
        )
    }

    // MARK: Shared chrome

    /// The prompt and its controls, centred.
    ///
    /// Deliberately centre-aligned where the rest of the app is left-aligned:
    /// the scanner is one question at a time on an otherwise empty screen, not
    /// a list, and a lone left-aligned question in the top corner looked like
    /// the screen had failed to finish loading.
    ///
    /// **Leads with the step counter since 0.6.9 (H2)**, centred over the
    /// question rather than parked in the header's leading corner. Rendered
    /// here rather than in `header` so it travels with the prompt it counts:
    /// every question step goes through this helper, so one line covers all
    /// six of them and no step can be added without one.
    private func question<C: View>(
        _ title: String,
        _ subtitle: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(spacing: 18) {
            // Tight to the title rather than at the stack's own 18pt: the
            // counter is a label *on* the question, not a section above it.
            VStack(spacing: 8) {
                Text("STEP \(questionNumber) OF 5")
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(lcd.subtext)

                Text(title)
                    .font(DexFont.retro(20))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            Text(subtitle)
                .font(DexFont.mono(22))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            content()
        }
        .frame(maxWidth: .infinity)
    }

    /// A selectable chip in the palette's own colours.
    ///
    /// `fill` distinguishes a *choice* from a *doorway*: answers paint
    /// themselves in when picked, while the class and subclass tiles stay
    /// outlined because tapping them opens a list rather than answering
    /// anything.
    ///
    /// `iconID` puts the taxonomy's own drawn glyph on the choice (v0.6, C2):
    /// the colour and body answers carry the same `art:` icons their tiles
    /// wear on the entry screen, so the choice and the fact it sets are
    /// recognisably the same thing. The flavour chips carry their note's own
    /// glyph too (0.6.x), at `iconSize` 22 — big enough to read as the note,
    /// small enough that a flow of them stays a flow.
    private func chip(
        label: String,
        chip: Palette.Chip?,
        selected: Bool,
        fill: Bool,
        iconID: String? = nil,
        iconSize: CGFloat = 30,
        action: @escaping () -> Void
    ) -> some View {
        let resolved = chip ?? Palette.Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
        let border = Color(dexHex: resolved.border)

        return Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 6) {
                if let iconID {
                    DexIcon(iconID: iconID, size: iconSize, color: Color(dexHex: resolved.text))
                }
                Text(EntryDisplay.hyphenated(label.replacingOccurrences(of: "_", with: " ").uppercased()))
                    .font(DexFont.retro(14))
                    .multilineTextAlignment(.center)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .foregroundStyle(Color(dexHex: resolved.text))
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: fill ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(dexHex: resolved.bg).opacity(selected ? 1 : 0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(border, lineWidth: selected ? 3 : 1)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.96))
    }

    /// A full-width labelled action.
    ///
    /// `symbol` is optional since 0.6.9 (H1). Step 3's NOT SURE carried
    /// `questionmark`, which is the one glyph on the questionnaire that says
    /// nothing the label does not: the other three symbols here name an
    /// *action* (open the globe, run the scan, move on), while a question mark
    /// beside the words NOT SURE is the words again, in a picture. Nil is a
    /// real state rather than a blank slot — the label centres in the button on
    /// its own.
    private func bigButton(
        _ label: String,
        symbol: String? = nil,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.screenTap()
            action()
        } label: {
            HStack(spacing: 12) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 21, weight: .bold))
                }
                Text(label)
                    .font(DexFont.retro(14))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(tint)
            .padding(.vertical, 19)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(0.6), lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
    }

    /// Skipping is a real answer, so it gets a real control rather than being
    /// something you discover by pressing Next with nothing chosen.
    ///
    /// **A rounded-square button since 0.6.8 (L2).** It was bare tracked text
    /// on the LCD ground — which is what "a real control" was *meant* to mean
    /// in 0.6.4, but bare text sitting under two filled answer chips reads as a
    /// caption about them, not as a third thing you can press. The surface and
    /// rim are the choice chips' own (`lcd.surface` in a 6pt rounded rect),
    /// left unfilled and in `subtext` so it still reads as the quieter answer.
    private func skip(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Text(label)
                .font(DexFont.retro(13))
                .tracking(1)
                .foregroundStyle(lcd.subtext)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6).fill(lcd.surface.opacity(0.75))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(lcd.surfaceEdge, lineWidth: 2)
                )
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(DexFont.mono(21))
            .foregroundStyle(lcd.subtext)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
#endif
