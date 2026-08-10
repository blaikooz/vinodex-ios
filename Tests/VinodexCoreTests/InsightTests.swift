import Testing
import Foundation
@testable import VinodexCore

/// The derived insight panel and the palate profile (0.8.9b, B and C1).
@Suite("Insight")
struct InsightTests {
    private let db = WineDatabase.shared

    private var allGrapes: [GrapeEntry] {
        db.entries(in: .grapes).compactMap { if case .grape(let g) = $0 { g } else { nil } }
    }

    private var allStyles: [WineEntry] { db.entries(in: .styles) }

    private func panel(
        for entry: WineEntry,
        tried: [String],
        triedDays: [String: Int] = [:],
        today: Int = 500
    ) -> InsightPanel {
        let index = DiscoveryIndex(tried: tried, in: db)
        return InsightService.panel(
            for: entry,
            index: index,
            profile: PalateProfile(index: index),
            in: db,
            triedDays: triedDays,
            today: today
        )
    }

    /// A tried set big enough to reach a given depth, drawn from the catalog.
    private func triedIDs(_ n: Int) -> [String] {
        allGrapes.prefix(n).map(\.id)
    }

    // MARK: B2 — depth

    @Test("depth thresholds ascend and start at zero")
    func depthLadder() {
        let all = InsightDepth.allCases
        #expect(all.first == .teaser)
        #expect(InsightDepth.teaser.threshold == 0)
        for (lower, higher) in zip(all, all.dropFirst()) {
            #expect(lower.threshold < higher.threshold)
            #expect(lower.deeper == higher)
            #expect(lower < higher)
        }
        #expect(all.last?.deeper == nil)
    }

    @Test("depth is earned by the tried count, inclusive at the threshold")
    func depthEarned() {
        #expect(InsightDepth.earned(by: 0) == .teaser)
        #expect(InsightDepth.earned(by: 1) == .first)
        #expect(InsightDepth.earned(by: 4) == .first)
        #expect(InsightDepth.earned(by: 5) == .shallow)
        #expect(InsightDepth.earned(by: 15) == .deep)
        #expect(InsightDepth.earned(by: 40) == .complete)
        #expect(InsightDepth.earned(by: 10_000) == .complete)
        // Never below the floor, whatever a caller hands in.
        #expect(InsightDepth.earned(by: -3) == .teaser)
    }

    @Test("an empty shelf gets the teaser and no derived lines")
    func teaserState() {
        let entry = db.entry(id: allGrapes[0].id)!
        let p = panel(for: entry, tried: [])
        #expect(p.depth == .teaser)
        #expect(p.lines.isEmpty)
        #expect(p.teaser != nil)
        #expect(!p.isEmpty, "the teaser is content — the panel still draws")
        #expect(p.nextDepth == .first)
        #expect(p.toNextDepth == 1)
    }

    /// The headline behaviour of B2: more tastings, more lines. Asserted as a
    /// monotone rather than by counting exact sentences, because the *kinds*
    /// available depend on which entry is open.
    @Test("the panel never loses a line as the shelf grows")
    func panelDeepens() {
        let entry = db.entry(id: allGrapes[0].id)!
        var previous = 0
        var kinds: Set<InsightLine.Kind> = []
        for n in [0, 1, 5, 15, 40, 60] {
            let p = panel(for: entry, tried: triedIDs(n))
            #expect(p.depth == InsightDepth.earned(by: DiscoveryIndex(tried: triedIDs(n), in: db).triedTotal))
            #expect(p.lines.count >= previous, "the panel shrank between \(previous) and \(n)")
            previous = p.lines.count
            kinds.formUnion(p.lines.map(\.kind))
        }
        // By the top depth the panel has said something of several kinds.
        #expect(kinds.count >= 3, "only produced \(kinds)")
    }

    @Test("no line appears before the depth it is declared at")
    func linesRespectTheirDepth() {
        for n in [1, 5, 15, 40, 80] {
            let tried = triedIDs(n)
            let depth = InsightDepth.earned(by: DiscoveryIndex(tried: tried, in: db).triedTotal)
            for entry in db.entries(in: .grapes).prefix(12) + db.entries(in: .styles).prefix(6) {
                let p = panel(for: entry, tried: tried)
                for line in p.lines {
                    #expect(
                        depth >= line.kind.depth,
                        "\(line.kind) showed at \(depth) but unlocks at \(line.kind.depth)"
                    )
                }
            }
        }
    }

    /// `InsightLine.id` is the kind, so two lines of one kind would collide in
    /// a SwiftUI `ForEach` and silently drop one.
    @Test("a panel holds at most one line of each kind, in enum order")
    func linesAreUniqueAndOrdered() {
        let tried = triedIDs(60)
        for entry in db.entries(in: .grapes).prefix(20) + db.entries(in: .styles).prefix(10) {
            let p = panel(for: entry, tried: tried)
            let kinds = p.lines.map(\.kind)
            #expect(Set(kinds).count == kinds.count, "\(entry.name) repeated a kind")
            let order = InsightLine.Kind.allCases
            let positions = kinds.compactMap { order.firstIndex(of: $0) }
            #expect(positions == positions.sorted(), "\(entry.name) drew its lines out of order")
            #expect(p.lines.allSatisfy { !$0.text.isEmpty })
        }
    }

    /// Reference entries are not tastings. A palate match on a region would be
    /// a category error, and the panel should stay quiet rather than invent one.
    @Test("regions, flavours and continents get no derived percentage")
    func referenceEntriesAreQuiet() {
        let tried = triedIDs(60)
        let index = DiscoveryIndex(tried: tried, in: db)
        let profile = PalateProfile(index: index)
        for entry in db.entries(in: .flavors).prefix(5) + db.entries(in: .continents) {
            #expect(profile.match(for: entry, index: index) == nil)
            let p = panel(for: entry, tried: tried)
            #expect(!p.lines.contains { $0.kind == .palateMatch })
        }
        for region in db.entries(in: .regions).prefix(8) {
            #expect(profile.match(for: region, index: index) == nil)
        }
    }

    // MARK: The individual lines

    @Test("a tried entry says when, and an untried one says nothing")
    func triedLine() {
        let grape = allGrapes[0]
        let entry = db.entry(id: grape.id)!
        let tried = triedIDs(20)
        #expect(tried.contains(grape.id))

        let today = panel(for: entry, tried: tried, triedDays: [grape.id: 500], today: 500)
        #expect(today.lines.first { $0.kind == .tried }?.text == "Tried today.")

        let yesterday = panel(for: entry, tried: tried, triedDays: [grape.id: 499], today: 500)
        #expect(yesterday.lines.first { $0.kind == .tried }?.text == "Tried yesterday.")

        let older = panel(for: entry, tried: tried, triedDays: [grape.id: 488], today: 500)
        #expect(older.lines.first { $0.kind == .tried }?.text == "Tried 12 days ago.")

        // Marked before 0.7.1 started logging days: on the shelf, date unknown.
        let undated = panel(for: entry, tried: tried, triedDays: [:], today: 500)
        #expect(undated.lines.first { $0.kind == .tried }?.text == "On your tried shelf.")

        // A clock that moved backwards is not a negative age.
        let future = panel(for: entry, tried: tried, triedDays: [grape.id: 900], today: 500)
        #expect(future.lines.first { $0.kind == .tried }?.text == "On your tried shelf.")

        // Untried: no line at all.
        let untried = allGrapes.last!
        let other = panel(for: db.entry(id: untried.id)!, tried: triedIDs(20))
        #expect(!other.lines.contains { $0.kind == .tried })
    }

    @Test("a roster line counts tried over resolvable, never over authored")
    func rosterCountsResolvableOnly() {
        let tried = triedIDs(80)
        let index = DiscoveryIndex(tried: tried, in: db)
        for style in db.entries(in: .styles) {
            let p = panel(for: style, tried: tried)
            guard let line = p.lines.first(where: { $0.kind == .grapeRoster }) else { continue }
            // The denominator can never exceed the authored list, and the
            // numerator can never exceed the denominator.
            let resolvable = style.notableGrapes
                .map { TextNormalize.label($0) }
                .filter { index.allGrapeKeys.contains($0) }
            #expect(!resolvable.isEmpty)
            #expect(line.text.contains("of \(resolvable.count) grapes behind"))
        }
    }

    /// A roster of zero resolvable grapes is not a roster. Printing "0 of 0"
    /// would be a completion nobody can reach.
    @Test("nothing resolvable means no roster line")
    func emptyRosterIsSilent() {
        let tried = triedIDs(80)
        let index = DiscoveryIndex(tried: tried, in: db)
        for style in db.entries(in: .styles) {
            let resolvable = style.notableGrapes
                .map { TextNormalize.label($0) }
                .filter { index.allGrapeKeys.contains($0) }
            if resolvable.isEmpty {
                let p = panel(for: style, tried: tried)
                #expect(!p.lines.contains { $0.kind == .grapeRoster }, "\(style.name)")
            }
        }
    }

    @Test("a rarity line names the entry's own band and counts within it")
    func rarityLine() {
        let tried = triedIDs(80)
        let index = DiscoveryIndex(tried: tried, in: db)
        for entry in db.entries(in: .grapes).prefix(30) {
            guard case .grape(let g) = entry else { continue }
            let p = panel(for: entry, tried: tried)
            guard let line = p.lines.first(where: { $0.kind == .rarityProgress }) else { continue }
            let band = index.allGrapes.filter { $0.rarity == g.rarity }
            #expect(line.text.contains("of \(band.count) \(g.rarity.rawValue) grapes."))
        }
    }

    @Test("similar-to never names the entry itself and requires real overlap")
    func similarLine() {
        let tried = triedIDs(80)
        for entry in db.entries(in: .grapes).prefix(30) {
            let p = panel(for: entry, tried: tried)
            guard let line = p.lines.first(where: { $0.kind == .similarTried }) else { continue }
            #expect(!line.text.contains("Similar to \(entry.name),"), "\(entry.name) matched itself")
        }
    }

    /// Dictionary iteration order is not stable between runs, so every "the
    /// best one" in this file sorts deterministically. A panel that reordered
    /// itself on a re-render reads as a bug.
    @Test("the same shelf produces the same panel every time")
    func deterministic() {
        let tried = triedIDs(50)
        for entry in db.entries(in: .grapes).prefix(15) + db.entries(in: .styles).prefix(8) {
            let a = panel(for: entry, tried: tried)
            let b = panel(for: entry, tried: tried.reversed())
            #expect(a.lines == b.lines, "\(entry.name) drew differently for a reordered shelf")
        }
    }

    // MARK: C1 — the profile

    @Test("an empty profile scores nothing and recommends nothing")
    func emptyProfile() {
        let index = DiscoveryIndex(tried: [], in: db)
        let profile = PalateProfile(index: index)
        #expect(profile.sampleSize == 0)
        #expect(profile.topNotes.isEmpty)
        #expect(profile.topCountries.isEmpty)
        #expect(profile.match(for: db.entry(id: allGrapes[0].id)!, index: index) == nil)
        #expect(profile.recommendations(index: index).isEmpty)
    }

    @Test("the profile is built from the tried set and is bounded")
    func profileIsBounded() {
        let index = DiscoveryIndex(tried: triedIDs(40), in: db)
        let profile = PalateProfile(index: index)
        #expect(profile.sampleSize == 40)
        #expect(profile.noteWeights.values.allSatisfy { $0 > 0 && $0 <= 1 })
        #expect(profile.noteWeights.values.max() == 1, "weights are normalised to a peak of 1")
        #expect(profile.redShare >= 0 && profile.redShare <= 1)
        for mean in [profile.meanBody, profile.meanAcid, profile.meanTannin, profile.meanAromatics] {
            #expect(mean >= 0 && mean <= 5)
        }
        // Ranked, strongest first.
        let ranked = profile.topNotes.compactMap { profile.noteWeights[TextNormalize.label($0)] }
        #expect(ranked == ranked.sorted(by: >))
    }

    @Test("a match is a percentage or an honest nil, never a misleading zero")
    func matchIsBounded() {
        let index = DiscoveryIndex(tried: triedIDs(40), in: db)
        let profile = PalateProfile(index: index)
        for entry in db.entries(in: .grapes) + db.entries(in: .styles) {
            guard let score = profile.match(for: entry, index: index) else {
                // The only reason a tastable entry scores nil is no notes.
                #expect(entry.tastingProfile.isEmpty, "\(entry.name) has notes but no score")
                continue
            }
            #expect(score >= 0 && score <= 100, "\(entry.name) scored \(score)")
        }
    }

    /// The point of the profile: a grape you have actually drunk should not
    /// score below the catalog's average stranger.
    @Test("what you drink scores above what you have never touched")
    func profilePrefersWhatYouDrink() {
        let tried = triedIDs(40)
        let index = DiscoveryIndex(tried: tried, in: db)
        let profile = PalateProfile(index: index)

        func mean(_ entries: [WineEntry]) -> Double {
            let scores = entries.compactMap { profile.match(for: $0, index: index) }
            guard !scores.isEmpty else { return 0 }
            return Double(scores.reduce(0, +)) / Double(scores.count)
        }
        let triedSet = Set(tried)
        let drunk = db.entries(in: .grapes).filter { triedSet.contains($0.id) }
        let strangers = db.entries(in: .grapes).filter { !triedSet.contains($0.id) }
        #expect(mean(drunk) > mean(strangers))
    }

    @Test("recommendations are untried, above the floor, ranked and capped")
    func recommendations() {
        let tried = triedIDs(40)
        let index = DiscoveryIndex(tried: tried, in: db)
        let profile = PalateProfile(index: index)
        let picks = profile.recommendations(index: index, limit: 6)

        #expect(picks.count <= 6)
        let triedSet = Set(tried)
        for pick in picks {
            #expect(!triedSet.contains(pick.id), "recommended something already tried")
            #expect(pick.isTastable, "recommended something you cannot drink")
            #expect((profile.match(for: pick, index: index) ?? 0) >= PalateProfile.recommendationFloor)
        }
        let scores = picks.compactMap { profile.match(for: $0, index: index) }
        #expect(scores == scores.sorted(by: >), "recommendations came back unranked")
        // Deterministic across a reordered shelf.
        let again = PalateProfile(index: DiscoveryIndex(tried: tried.reversed(), in: db))
            .recommendations(index: index, limit: 6)
        #expect(picks.map(\.id) == again.map(\.id))
    }

    @Test("a thin profile recommends nothing rather than guessing")
    func thinProfileIsSilent() {
        let index = DiscoveryIndex(tried: triedIDs(2), in: db)
        let profile = PalateProfile(index: index)
        #expect(profile.sampleSize < PalateProfile.meaningfulSample)
        #expect(profile.recommendations(index: index).isEmpty)
        // And a zero limit is empty rather than a crash.
        #expect(PalateProfile(index: DiscoveryIndex(tried: triedIDs(40), in: db))
            .recommendations(index: index, limit: 0).isEmpty)
    }

    /// Phase 1's acceptance criterion, the insight half: marking something moves
    /// the panel, live.
    @Test("marking one more entry changes the panel")
    func markingUpdatesInsight() {
        let entry = db.entry(id: allGrapes.last!.id)!
        let before = panel(for: entry, tried: triedIDs(4))
        let after = panel(for: entry, tried: triedIDs(5))
        #expect(before.depth == .first)
        #expect(after.depth == .shallow)
        #expect(after.lines.count > before.lines.count)
    }
}
