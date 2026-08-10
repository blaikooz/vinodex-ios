import Foundation

/// The "WHAT'S THAT…?" guessing game (0.7.9, B).
///
/// **What replaced what.** The tile at `ToolsScreen` opened `DailyGrapeScreen`
/// from 0.6.x to 0.7.8: a silhouette, a REVEAL button, an answer. The door is
/// unchanged — same tile, same `DexRoute.dailyGrape`, same marquee — and what is
/// behind it is now a round you can lose. The old screen's own doc comment had
/// already worked out why the reveal was thin ("a shuffled entry shown outright
/// is just a list of one"); holding the name back for a beat was as far as a
/// reveal could go. Clues make the beat into a decision.
///
/// **All of it lives here rather than in the view**, which is the rule
/// `OCRService` writes down: anything that is a claim about *wine* belongs in
/// `VinodexCore` where `swift test` on Linux can see it, and `VinodexUI` only
/// gets the drawing. So clue generation, ordering, sufficiency, scoring and
/// answer-matching are all in this file and all covered by `WhatsThatTests`.
/// `WhatsThatScreen` chooses fonts.
///
/// **The answer matcher is `LabelRecognitionService` and is not reimplemented.**
/// Free text against a 446-entry catalog needs accent folding, synonym
/// resolution and near-miss tolerance, and that is precisely the job the label
/// reader already does — `chateau neuf`, `Steen`, `Albarino` for `Albariño`. A
/// second fuzzy matcher here would be a second set of thresholds to keep in step
/// with the index it is comparing against, which is the exact failure
/// `LabelTextScan`'s normalisation note exists to prevent. See `judge(_:in:)`.
public enum WhatsThat {

    // MARK: - Clues

    /// One revealed fact about the hidden entry.
    ///
    /// `value` is the comparable form and `text` is what the chip prints. They
    /// are separate because the *set* of clues has to be checkable against the
    /// whole catalog — see `candidates(for:in:)` — and "IT'S A RED GRAPE" is not
    /// a predicate.
    public struct Clue: Sendable, Hashable, Codable, Identifiable {
        /// **`allCases` order is reveal order: vague first, specific last.**
        ///
        /// This is the game's only real design decision. A first chip reading
        /// "GROWN IN BAROLO" ends the round before it starts; a last chip
        /// reading "IT'S RED" is a round nobody can finish. So the kinds are
        /// sorted by how much of the catalog they eliminate — category, then
        /// colour, then country, then the structural facts, then the ones that
        /// name another entry outright.
        public enum Kind: String, Codable, Sendable, CaseIterable {
            /// Grape or region. Always first, because every other clue reads
            /// differently depending on the answer.
            case category
            case color
            case country
            case climate
            case body
            case tannin
            case rarity
            case flavor
            /// A region this grape is grown in.
            case region
            /// A grape this region is planted with.
            case grape
            /// A style this region is known for.
            case style
            /// A village or cru inside this region. The giveaway, and last.
            case appellation

            /// **How much of the answer this kind of clue hands over** (0.8.8,
            /// E2).
            ///
            /// Relative, not points. `Round.score` turns these into a price by
            /// dividing each clue's weight by the round's total, so a round is
            /// always worth the same to someone who buys the same *proportion*
            /// of it — which is the property `score(revealed:)` had when it
            /// counted chips and which had to survive chips ceasing to be
            /// interchangeable.
            ///
            /// The numbers are this enum's own ordering made arithmetic. The
            /// declaration order is already the app's statement of how much of
            /// the catalog each kind eliminates ("sorted by how much of the
            /// catalog they eliminate" — see the note above), so what these add
            /// is only *how far apart* the rungs are: naming a cru is four times
            /// the give-away of naming a colour, not one rung more.
            ///
            /// `category` is 0 because it is the opening clue and is never
            /// bought — every round starts with IT'S A GRAPE or IT'S A WINE
            /// REGION showing, and a price on a thing you cannot decline is not
            /// a price.
            var weight: Int {
                switch self {
                case .category: 0
                case .color, .body, .tannin: 2
                case .climate, .rarity: 3
                case .country, .flavor: 4
                case .style: 5
                case .region, .grape: 6
                case .appellation: 8
                }
            }
        }

        public let kind: Kind
        /// Normalised, for `satisfies`. Never shown.
        public let value: String
        /// The chip's copy.
        public let text: String

        public var id: String { "\(kind.rawValue):\(value)" }

        public init(kind: Kind, value: String, text: String) {
            self.kind = kind
            self.value = value
            self.text = text
        }
    }

    /// One playable round.
    ///
    /// `Codable` so `ScreenStateStore` can hold it while the screen is torn
    /// down — the same contract `LabelReading` and `GrapeScanCriteria` have, and
    /// for the same reason: opening the answer's entry and pressing Back must
    /// not deal a new hand.
    public struct Round: Sendable, Hashable, Codable {
        public let answerID: String
        public let answerName: String
        /// Vague to specific. Between `minClues` and `maxClues` of them, and the
        /// full set identifies the answer uniquely — see `isSolvable(_:in:)`.
        public let clues: [Clue]

        public init(answerID: String, answerName: String, clues: [Clue]) {
            self.answerID = answerID
            self.answerName = answerName
            self.clues = clues
        }

        /// The clue every round opens with, free.
        public var opening: Clue? { clues.first }

        /// The clues that can be bought — everything after the opener.
        public var purchasable: [Clue] { Array(clues.dropFirst()) }

        /// Points for guessing right having revealed `revealed`.
        ///
        /// **Full marks down to a floor of `scoreFloor`, spent by weight rather
        /// than by count (0.8.8, E2).** The old shape counted chips: a round was
        /// worth `(remaining + 1) / total` of 100, so every clue in a round cost
        /// the same and the only decision left was *how many*. Chips are not
        /// interchangeable — one of them names a cru inside the answer — so
        /// pricing them alike is what made NEXT CLUE the whole interface.
        ///
        /// What is preserved is the reason the old shape divided by the round's
        /// own length, and it is worth restating because it is the subtle half:
        /// the denominator is this round's total weight, so buying the whole of
        /// a cheap five-clue round and the whole of an expensive six-clue one
        /// both land on the floor. Without that the game would quietly reward
        /// drawing an easy entry, which is the one thing a player cannot
        /// influence.
        ///
        /// Unknown kinds in `revealed` are ignored rather than trusted, so a
        /// restored session that has drifted cannot spend points on a clue this
        /// round does not contain.
        public func score(revealed: Set<Clue.Kind>) -> Int {
            let total = purchasable.reduce(0) { $0 + $1.kind.weight }
            guard total > 0 else { return 100 }
            let spent = purchasable
                .filter { revealed.contains($0.kind) }
                .reduce(0) { $0 + $1.kind.weight }
            let fraction = Double(spent) / Double(total)
            return max(
                WhatsThat.scoreFloor,
                Int((100 - Double(100 - WhatsThat.scoreFloor) * fraction).rounded())
            )
        }

        /// What buying `clue` would cost, given what is already revealed.
        ///
        /// Derived as the drop in `score` rather than computed alongside it, so
        /// the number printed on a chip is *exactly* what pressing it takes off.
        /// Computing a price independently and a score independently is how the
        /// two come to disagree by a rounding step, which on a 20-point floor is
        /// visible.
        public func price(of clue: Clue, revealed: Set<Clue.Kind>) -> Int {
            score(revealed: revealed) - score(revealed: revealed.union([clue.kind]))
        }
    }

    /// The least a solved round can be worth. A round you have opened entirely
    /// is still a round you finished.
    public static let scoreFloor = 20

    /// Fewer than this and a round is a coin toss; more and it is a reading
    /// exercise. The catalog reliably supports five for a grape and five for a
    /// region; the sixth is the discriminator `pick` adds when five leave two
    /// entries standing.
    public static let minClues = 4
    public static let maxClues = 6

    // MARK: - Playing one

    /// How a round ended.
    public enum Outcome: String, Sendable, Hashable, Codable {
        case solved
        case gaveUp
        /// Wrong with nothing left to reveal. The losing condition the game did
        /// not have before 0.8.8.
        case lost
    }

    /// **One round in progress — the state the screen used to hold loose
    /// (0.8.8, E1/E2).**
    ///
    /// ## Why this type exists at all
    ///
    /// `WhatsThatScreen` held `revealed`, `verdict`, `solvedAt` and `gaveUp` as
    /// four `@State` properties and moved between them itself, which put the
    /// game's transitions in the one module `swift test` cannot see — in a file
    /// whose own header says "this file draws and nothing else". `QuizSession`,
    /// the nearest sibling on the same shelf, has had exactly this shape since
    /// it shipped: an immutable question set, a mutable cursor over it, and
    /// `mutating` verbs that are the only way to move. This is that, and it is
    /// the reason E1 and E2 are testable at all.
    ///
    /// ## What was wrong with the game, stated plainly
    ///
    /// The round had exactly one cost — pressing NEXT CLUE — and guessing was
    /// free and unlimited. So the dominant strategy was to type every name you
    /// could think of before ever spending a clue, and the score measured
    /// patience rather than knowledge. Nothing was recorded either:
    /// `ScreenStateStore` is session state and is deliberately never written to
    /// disk, and `VinodexApp` forgets the key on leaving the route, so a
    /// hundred-point solve and a twenty-point solve were the same event, which
    /// is to say neither was one.
    ///
    /// Three changes, one economy:
    ///
    /// **E1 — a wrong guess costs a clue.** A guess that names a real catalog
    /// entry and is not the answer reveals one, at that clue's price. An
    /// *unrecognised* guess costs nothing, deliberately: nothing in the dex by
    /// that name is a typo or a blank, not a wrong answer, and charging for it
    /// would make the field punish spelling. When there is nothing left to
    /// reveal a wrong guess ends the round — which is the losing condition the
    /// game did not have.
    ///
    /// **The clue a wrong guess reveals is the cheapest one left**, not the next
    /// in order and not the player's pick. Being wrong should cost the *choice*
    /// as well as the points, and the cheapest is the least informative thing
    /// remaining, so the penalty is proportionate rather than a windfall: a
    /// player cannot farm the giveaway clue by guessing rubbish, because
    /// rubbish is unrecognised and a named wrong answer hands over the least it
    /// can.
    ///
    /// **E2 — the clue is chosen, and they are not all the same price.** See
    /// `Clue.Kind.weight` and `Round.score`.
    public struct Play: Sendable, Hashable, Codable {
        public let round: Round
        /// In purchase order, opener first. An array rather than a set so the
        /// order a player opened the round in survives a round trip — it is what
        /// the chips are drawn in and it is the shape of the decision they made.
        public private(set) var revealed: [Clue.Kind]
        public private(set) var outcome: Outcome?
        /// Named-but-wrong guesses. Unrecognised typing is not counted.
        public private(set) var wrongGuesses: Int

        public init(round: Round) {
            self.round = round
            self.revealed = round.opening.map { [$0.kind] } ?? []
            self.outcome = nil
            self.wrongGuesses = 0
        }

        // MARK: Reading

        public var isOver: Bool { outcome != nil }
        public var revealedKinds: Set<Clue.Kind> { Set(revealed) }
        public var score: Int { outcome == .solved ? round.score(revealed: revealedKinds) : 0 }

        /// Clues still to be bought, in the round's own vague-to-specific order.
        public var hidden: [Clue] {
            let shown = revealedKinds
            return round.clues.filter { !shown.contains($0.kind) }
        }

        /// What buying this clue takes off the score right now.
        public func price(of clue: Clue) -> Int {
            round.price(of: clue, revealed: revealedKinds)
        }

        /// The clue a wrong guess would turn over — the cheapest left, ties
        /// broken by the round's own order so this is deterministic.
        public var forfeit: Clue? {
            hidden.min { price(of: $0) < price(of: $1) }
        }

        // MARK: Moving

        /// Buy one clue. Silently ignores a clue already showing, one this round
        /// does not hold, and any call after the round is over — all three are
        /// double-taps rather than states worth modelling.
        public mutating func reveal(_ kind: Clue.Kind) {
            guard !isOver, round.clues.contains(where: { $0.kind == kind }) else { return }
            guard !revealed.contains(kind) else { return }
            revealed.append(kind)
        }

        /// Fold a judged guess into the round.
        ///
        /// Returns the clue the guess cost, if it cost one, so the screen can say
        /// which — a chip turning over on its own is otherwise a thing that
        /// happened rather than a consequence.
        @discardableResult
        public mutating func record(_ verdict: Verdict) -> Clue? {
            guard !isOver else { return nil }
            switch verdict {
            case .correct:
                outcome = .solved
                return nil
            case .unrecognized:
                // Not a guess at the answer. Costs nothing, by design.
                return nil
            case .wrong:
                wrongGuesses += 1
                guard let taken = forfeit else {
                    outcome = .lost
                    return nil
                }
                reveal(taken.kind)
                return taken
            }
        }

        public mutating func giveUp() {
            guard !isOver else { return }
            outcome = .gaveUp
        }
    }

    // MARK: - Does an entry fit a clue

    /// Whether `entry` is consistent with one revealed clue.
    ///
    /// This is what makes "the clues must identify the answer" a property rather
    /// than a hope: the same predicate that generated a clue is run back over
    /// the whole catalog. A clue whose predicate did not match its own subject
    /// would be a lie the game tells, and `WhatsThatTests` checks every clue of
    /// every round against its own answer.
    public static func entry(_ entry: WineEntry, satisfies clue: Clue, in db: WineDatabase) -> Bool {
        switch clue.kind {
        case .category:
            return entry.category.rawValue == clue.value
        case .color:
            guard case .grape(let g) = entry else { return false }
            return g.grapeType.rawValue == clue.value
        case .country:
            return TextNormalize.label(entry.origin ?? "") == clue.value
        case .climate:
            return entry.climate?.rawValue == clue.value
        case .body:
            guard case .grape(let g) = entry else { return false }
            return String(Int(g.grapeCharacteristics.body.rounded())) == clue.value
        case .tannin:
            guard case .grape(let g) = entry else { return false }
            return String(Int(g.grapeCharacteristics.tannin.rounded())) == clue.value
        case .rarity:
            return entry.rarity?.rawValue == clue.value
        case .flavor:
            return entry.tastingProfile.contains { TextNormalize.label($0.note) == clue.value }
        case .region:
            guard case .grape(let g) = entry else { return false }
            return g.details.keyRegions.contains { TextNormalize.label($0) == clue.value }
        case .grape:
            guard case .region(let r) = entry else { return false }
            return r.details.notableGrapes.contains { TextNormalize.label($0) == clue.value }
        case .style:
            guard case .region(let r) = entry else { return false }
            return styles(of: r, in: db).contains(clue.value)
        case .appellation:
            guard case .region(let r) = entry else { return false }
            return (r.details.appellations ?? []).contains { TextNormalize.label($0) == clue.value }
        }
    }

    /// The styles a region is named by, normalised.
    ///
    /// Derived by inverting `style.keyRegions` rather than stored: regions do not
    /// carry styles, and adding a mirror field for a game to read would be a
    /// second source of truth for a fact the styles already state. Matches on the
    /// whole term through `TextNormalize`, so `Rioja` does not answer to
    /// `Rioja Alavesa`.
    static func styles(of region: RegionEntry, in db: WineDatabase) -> Set<String> {
        var out: Set<String> = []
        for entry in db.entries(in: .styles) {
            guard entry.keyRegions.contains(where: {
                TextNormalize.matchesWholeTerm($0, region.common.name)
            }) else { continue }
            out.insert(TextNormalize.label(entry.name))
        }
        return out
    }

    /// Everything in the catalog that every clue is true of.
    ///
    /// Grapes and regions only, which is the pool `pick` draws from — a style or
    /// a flavour cannot satisfy a `category` clue and would only ever pad the
    /// count.
    public static func candidates(for clues: [Clue], in db: WineDatabase) -> [WineEntry] {
        let pool = db.entries(in: .grapes) + db.entries(in: .regions)
        return pool.filter { entry in
            clues.allSatisfy { self.entry(entry, satisfies: $0, in: db) }
        }
    }

    /// **The property the spec names: a round must be winnable on its full set.**
    ///
    /// Not "the player could reasonably deduce it" — that is not checkable — but
    /// the strictly weaker and entirely checkable thing: no *other* entry in the
    /// catalog is consistent with every clue. A round failing this is a round
    /// whose answer cannot be argued for, and `pick` refuses to deal one.
    public static func isSolvable(_ round: Round, in db: WineDatabase) -> Bool {
        candidates(for: round.clues, in: db).map(\.id) == [round.answerID]
    }

    // MARK: - Dealing a round

    /// The round at a given position in the shuffle.
    ///
    /// `cursor` is `RevealCursor`'s, exactly as the reveal used it — one new
    /// round per open, with the calendar day setting the starting point so two
    /// players opening it cold get the same hand. That is the one piece of the
    /// old feature kept verbatim, and it is why "grape of the day" did not
    /// disappear so much as acquire a question: the day still deals.
    ///
    /// Walks forward from the cursor's position until it finds an entry whose
    /// clues come out solvable, so a variety the catalog cannot distinguish
    /// costs one step rather than an unwinnable round. The walk is bounded; a
    /// catalog that could not produce a single solvable round returns nil and
    /// the screen says so rather than dealing something broken.
    public static func round(
        cursor: Int,
        for date: Date = Date(),
        in db: WineDatabase,
        calendar: Calendar = .current
    ) -> Round? {
        let pool = (db.entries(in: .grapes) + db.entries(in: .regions))
            .sorted { $0.id < $1.id }
        guard !pool.isEmpty else { return nil }

        // The same coprime stride `DailyPick.entry(cursor:)` uses, for the same
        // reason: adjacent ids are often the same family, and stepping by one
        // makes every new round look like a variant of the last.
        let stride = 37
        let start = DailyPick.dayIndex(for: date, calendar: calendar) &+ cursor &* stride

        for step in 0..<pool.count {
            let raw = start &+ step
            let entry = pool[((raw % pool.count) + pool.count) % pool.count]
            if let round = round(for: entry, in: db) { return round }
        }
        return nil
    }

    /// The round for one specific entry, or nil if the catalog cannot single it
    /// out.
    ///
    /// Builds the full ordered clue list the entry can support, takes the first
    /// `minClues` — the vague end — and then adds discriminators until the
    /// candidate set is down to the answer alone.
    ///
    /// **The extras are taken from the *specific* end, not the next one along**,
    /// and that is the whole of what makes a round finishable. Appending in
    /// reveal order fills the two spare chips with the next-vaguest facts —
    /// tannin, rarity — and hits the six-clue cap before reaching the flavour
    /// and the region, which are the only clues that actually isolate a grape.
    /// Cabernet Sauvignon was the proof: eight clues available, six spent, still
    /// ambiguous, round refused.
    ///
    /// The chosen set is re-sorted into reveal order at the end, so the round
    /// still comes out vague to specific — the *selection* is greedy from the
    /// specific end, the *presentation* is not.
    public static func round(for entry: WineEntry, in db: WineDatabase) -> Round? {
        let available = clues(for: entry, in: db)
        guard available.count >= minClues else { return nil }

        var chosen = Array(available.prefix(minClues))
        var extras = Array(available.dropFirst(minClues).reversed())
        while candidates(for: chosen, in: db).count > 1,
              chosen.count < maxClues,
              let next = extras.first {
            chosen.append(next)
            extras.removeFirst()
        }

        let rank = Dictionary(
            uniqueKeysWithValues: Clue.Kind.allCases.enumerated().map { ($1, $0) }
        )
        chosen.sort { (rank[$0.kind] ?? 0) < (rank[$1.kind] ?? 0) }

        let round = Round(answerID: entry.id, answerName: entry.name, clues: chosen)
        return isSolvable(round, in: db) ? round : nil
    }

    /// Every clue this entry can support, vague to specific.
    ///
    /// One clue per `Kind` at most: two flavours would read as one fact stated
    /// twice and would spend a chip for very little. Ties inside a kind are
    /// broken by taking the **last** listed value — `keyRegions` and
    /// `notableGrapes` lead with the famous one, and the famous one is the
    /// giveaway, so the game keeps it back rather than opening with it.
    public static func clues(for entry: WineEntry, in db: WineDatabase) -> [Clue] {
        var byKind: [Clue.Kind: Clue] = [:]

        func add(_ kind: Clue.Kind, _ value: String?, _ text: @autoclosure () -> String) {
            guard let value, !value.isEmpty, byKind[kind] == nil else { return }
            byKind[kind] = Clue(kind: kind, value: value, text: text())
        }

        add(.category, entry.category.rawValue, entry.category == .grapes
            ? "IT'S A GRAPE" : "IT'S A WINE REGION")

        if let origin = entry.origin, !origin.isEmpty {
            add(.country, TextNormalize.label(origin), "IT COMES FROM \(origin.uppercased())")
        }

        switch entry {
        case .grape(let g):
            add(.color, g.grapeType.rawValue,
                g.grapeType == .red ? "IT MAKES RED WINE" : "IT MAKES WHITE WINE")
            add(.body, String(Int(g.grapeCharacteristics.body.rounded())),
                "THE WINE IS \(Self.bodyWord(g.grapeCharacteristics.body))-BODIED")
            add(.tannin, String(Int(g.grapeCharacteristics.tannin.rounded())),
                "\(Self.levelWord(g.grapeCharacteristics.tannin)) TANNIN")
            add(.rarity, g.rarity.rawValue, "A \(g.rarity.rawValue) VARIETY")
            if let note = g.tastingProfile?.last {
                add(.flavor, TextNormalize.label(note.note), "YOU MIGHT TASTE \(note.note.uppercased())")
            }
            if let region = g.details.keyRegions.last {
                add(.region, TextNormalize.label(region), "IT'S GROWN IN \(region.uppercased())")
            }

        case .region(let r):
            if let climate = r.climate {
                add(.climate, climate.rawValue, "A \(climate.rawValue.uppercased()) CLIMATE")
            }
            if let style = Self.styles(of: r, in: db).sorted().last,
               let named = db.entry(named: style, category: .styles) {
                add(.style, style, "IT'S KNOWN FOR \(named.name.uppercased())")
            }
            if let grape = r.details.notableGrapes.last {
                add(.grape, TextNormalize.label(grape), "THEY PLANT \(grape.uppercased()) HERE")
            }
            if let appellation = (r.details.appellations ?? []).last {
                add(.appellation, TextNormalize.label(appellation),
                    "\(appellation.uppercased()) IS INSIDE IT")
            }

        case .style, .flavor, .continent:
            return []
        }

        // `Kind.allCases` order is the reveal order — see the enum's note.
        return Clue.Kind.allCases.compactMap { byKind[$0] }
    }

    /// The five-point body bar as a word. Deliberately coarse: the chip is a
    /// clue, and "3.0 BODY" is a stat readout.
    static func bodyWord(_ value: Double) -> String {
        switch Int(value.rounded()) {
        case ...2: "LIGHT"
        case 3: "MEDIUM"
        case 4: "MEDIUM-FULL"
        default: "FULL"
        }
    }

    static func levelWord(_ value: Double) -> String {
        switch Int(value.rounded()) {
        case ...1: "BARELY ANY"
        case 2: "LOW"
        case 3: "MODERATE"
        case 4: "HIGH"
        default: "VERY HIGH"
        }
    }

    // MARK: - Judging a guess

    /// What the player's typing came to.
    public enum Verdict: Sendable, Hashable {
        case correct
        /// They named something real, and it was not the answer. Carries the
        /// catalog's spelling so the screen can say *which* — "that's Merlot"
        /// is a better answer than "no".
        case wrong(named: String)
        /// Nothing in the catalog came close enough to name.
        case unrecognized
    }

    /// Judges free text against the round's answer.
    ///
    /// **Delegated to `LabelRecognitionService` in full.** The guess is handed
    /// over as a single `RecognizedString` — which is exactly what a provider
    /// returns for a one-line label — and the resulting `LabelReading` is read
    /// for what it *named*. That buys accent folding, synonyms and alternate
    /// names (`Steen` is Chenin Blanc), the length-scaled edit tolerance, and the
    /// appellation-to-region link, all of which are already tested by
    /// `LabelReaderTests` and none of which is written twice.
    ///
    /// Only **non-inferred** matches count, and that restriction is the whole
    /// correctness argument. The reading also walks the catalog: typing `BAROLO`
    /// produces an inferred region *and* an inferred country, and typing a
    /// region name produces that region's notable grapes in `grapeIDs`. Counting
    /// those would mean a player could win a grape round by naming any region
    /// that grows it, which is not a guess at the answer — it is a guess near it.
    public static func judge(
        _ guess: String,
        in round: Round,
        using service: LabelRecognitionService = .shared
    ) -> Verdict {
        let trimmed = guess.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unrecognized }

        let reading = service.read([RecognizedString(text: trimmed, confidence: 1, prominence: 1)])
        let named = reading.matches.filter { !$0.isInferred && $0.entryID != nil }

        if named.contains(where: { $0.entryID == round.answerID }) { return .correct }
        guard let first = named.first else { return .unrecognized }
        return .wrong(named: first.name)
    }

    // MARK: - Type-ahead

    /// The shortest query that produces suggestions at all (0.8.0, E2).
    ///
    /// One character must never produce a list. That is the hard requirement the
    /// spec states, and it is the requirement because a list from one letter is a
    /// *menu*: the player stops recalling a name and starts reading one, which is
    /// the round over. Two is the smallest number that cannot be reached by
    /// pressing a key at random and still narrows a shelf.
    public static let minimumSuggestionQuery = 2

    /// How many names the field will ever offer.
    ///
    /// Short on purpose and not merely for layout. The value of a type-ahead here
    /// is confirming a spelling the player already has in mind; the *cost* is
    /// every extra row, because a long list is a browsable index of the catalog
    /// with the query as its filter.
    public static let suggestionLimit = 5

    /// Names to offer as the player types.
    ///
    /// **This is E2-a, and the decision it encodes is `discovered`.** The judge
    /// counts only non-inferred matches precisely so that naming something *near*
    /// the answer cannot win a round (see `judge(_:in:)`), and a type-ahead over
    /// the whole catalog gives away by autocompletion exactly what that
    /// restriction protects: type `NEB`, read *Nebbiolo*, press GUESS. So the
    /// pool is not the catalog. It is the entries the player has already met —
    /// bookmarked, wishlisted, marked tried, or opened recently — assembled by
    /// the caller and passed in as ids.
    ///
    /// What that buys is the convenience without the give-away: a name in this
    /// list is one the player has already seen in this app, so completing it
    /// spares them the spelling of `Gewurztraminer` without telling them a wine
    /// exists. What it costs is honest and worth stating: a player who has met
    /// the answer before *can* be shown it, from two characters. That is the
    /// trade E2-a is, and it is the right way round — the alternative leaks to
    /// everyone rather than to the person who already knew.
    ///
    /// **Two clauses of the recommendation are deliberately not implemented, and
    /// the batch log carries the argument.** "Never from the answer's own
    /// category" would disable the feature outright: the first clue of every
    /// round says IT'S A GRAPE or IT'S A WINE REGION, and those are the only two
    /// categories a guess can usefully be in. And excluding the *answer itself*
    /// would be worse than the leak it prevents — a player who has met Nebbiolo,
    /// types `NEBB`, and gets nothing back has been told which entry is being
    /// withheld. Silence is information. Nothing here is filtered on the answer.
    ///
    /// - Parameters:
    ///   - typed: the raw contents of the guess field.
    ///   - discovered: entry ids the player has demonstrably encountered. Order
    ///     is respected for ties, so a caller may pass its most-recent first.
    /// - Returns: catalog spellings, prefix matches first, at most
    ///   `suggestionLimit`.
    public static func suggestions(
        for typed: String,
        among discovered: [String],
        in db: WineDatabase,
        limit: Int = suggestionLimit
    ) -> [String] {
        let query = TextNormalize.label(typed)
        guard query.count >= minimumSuggestionQuery else { return [] }

        var seen: Set<String> = []
        var prefixed: [String] = []
        var contained: [String] = []

        for id in discovered {
            guard let entry = db.entry(id: id) else { continue }
            // Grapes and regions only — the pool `round(cursor:...)` deals from,
            // so the list holds exactly the things that could be an answer. A
            // flavour or a style completing in this field is noise in a round it
            // cannot win, and noise is what makes a short list long.
            guard entry.category == .grapes || entry.category == .regions else { continue }
            guard seen.insert(entry.id).inserted else { continue }

            let folded = TextNormalize.label(entry.name)
            if folded.hasPrefix(query) {
                prefixed.append(entry.name)
            } else if folded.contains(query) {
                contained.append(entry.name)
            }
        }

        return Array((prefixed + contained).prefix(limit))
    }
}
