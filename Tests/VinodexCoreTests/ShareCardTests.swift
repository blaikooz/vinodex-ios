import Testing
import Foundation
@testable import VinodexCore

@Suite("Share cards")
struct ShareCardTests {
    let db = WineDatabase.shared

    private func profile(tried: Int, collectible: Int) -> ShareCard.Profile {
        ShareCard.Profile(
            rank: "UNRANKED", triedTotal: tried, collectible: collectible,
            triedGrapes: tried, totalGrapes: collectible, triedStyles: 0, totalStyles: 0,
            countries: 0, continents: 0, badgesEarned: 0, badgesTotal: 6,
            streak: 0, bestStreak: 0, device: "CLASSIC"
        )
    }

    // MARK: Completion — the number a reader will check

    /// The card is an outward-facing image. `100%` on an unfinished catalog is
    /// the one claim on it that is checkable and wrong.
    @Test("one entry short never reads as one hundred percent")
    func neverRoundsUpToComplete() {
        #expect(profile(tried: 437, collectible: 438).completionPercent == 99)
        #expect(profile(tried: 999, collectible: 1000).completionPercent == 99)
    }

    @Test("a finished catalog reads as one hundred percent")
    func completeIsHundred() {
        #expect(profile(tried: 438, collectible: 438).completionPercent == 100)
    }

    @Test("completion floors rather than rounds")
    func floors() {
        // 3/8 = 37.5% — rounding would say 38.
        #expect(profile(tried: 3, collectible: 8).completionPercent == 37)
        #expect(profile(tried: 0, collectible: 438).completionPercent == 0)
    }

    @Test("an empty catalog does not divide by zero")
    func emptyCatalog() {
        #expect(profile(tried: 0, collectible: 0).completionPercent == 0)
        #expect(profile(tried: 0, collectible: 0).completion == 0)
    }

    // MARK: Assembly from a real passport

    @Test("the profile card carries the passport's own figures")
    func builtFromPassport() {
        let tried = db.entries(in: .grapes).prefix(30).map(\.id)
        let passport = Passport.compute(
            tried: Array(tried), in: db, bestStreak: 9, highestTier: .enthusiast
        )
        let card = ShareCard.profile(from: passport, streak: 4, bestStreak: 9, device: "W64")

        #expect(card.triedTotal == passport.triedTotal)
        #expect(card.triedGrapes == passport.triedGrapes)
        #expect(card.totalGrapes == passport.totalGrapes)
        #expect(card.collectible == passport.totalGrapes + passport.totalStyles)
        #expect(card.badgesTotal == passport.badges.count)
        #expect(card.badgesEarned == passport.badges.filter(\.earned).count)
        #expect(card.rank == (passport.tier?.displayName ?? "UNRANKED"))
        #expect(card.streak == 4)
        #expect(card.bestStreak == 9)
        #expect(card.device == "W64")
    }

    /// The streak on a share card and the streak on the passport must be the
    /// same measurement — `StreakStore`'s calendar streak, never
    /// `ExamRecordStore.passStreak`, which counts papers and saturates.
    /// `@MainActor` only because `ExamRecordStore` is, and the comparison
    /// against its limit is the whole point — a literal 100 here would stop
    /// tracking the constant it is contrasted with.
    @MainActor
    @Test("the card's streak is whatever it was handed, unbounded")
    func streakPassesThrough() {
        let passport = Passport.compute(tried: [], in: db, bestStreak: 250, highestTier: .novice)
        let card = ShareCard.profile(from: passport, streak: 250, bestStreak: 250, device: "CLASSIC")
        // No clamp at ExamRecordStore.historyLimit — a different streak entirely.
        #expect(card.streak == 250)
        #expect(card.streak > ExamRecordStore.historyLimit)
    }

    // MARK: Headlines

    @Test("a ranked passport leads with its rank")
    func headlineIsRank() {
        let tried = db.entries(in: .grapes).prefix(30).map(\.id)
        let passport = Passport.compute(tried: Array(tried), in: db, bestStreak: 0, highestTier: .novice)
        let headline = ShareCard.headline(for: passport)
        #expect(headline.headline == "MASTER UNLOCKED")
    }

    @Test("an empty passport still has something to say")
    func headlineFallsBack() {
        let passport = Passport.compute(tried: [], in: db, bestStreak: 0, highestTier: .novice)
        let headline = ShareCard.headline(for: passport)
        #expect(headline.headline.contains("GRAPES COLLECTED"))
        #expect(!headline.caption.isEmpty)
    }

    @Test("a collected headline counts what is left, and knows when nothing is")
    func collectedWording() {
        #expect(ShareCard.Achievement.collected(42, of: 171, noun: "GRAPES").headline == "42/171 GRAPES COLLECTED")
        #expect(ShareCard.Achievement.collected(42, of: 171, noun: "GRAPES").caption == "129 left to pour.")
        #expect(ShareCard.Achievement.collected(171, of: 171, noun: "GRAPES").caption == "The whole shelf.")
    }

    @Test("an unlocked headline reads as an unlock")
    func unlockedWording() {
        let a = ShareCard.Achievement.unlocked("SOMMELIER", blurb: "The Wine Exam's top tier.")
        #expect(a.headline == "SOMMELIER UNLOCKED")
        #expect(a.caption == "The Wine Exam's top tier.")
    }

    // MARK: Branding

    /// The denylist exists so an outward-facing card cannot ship reading
    /// `v1.0.0`, which is what xtool stamps when nothing declares a version.
    @Test("the card's version is a real one")
    func versionIsNotAPlaceholder() {
        #expect(!AppVersion.placeholders.contains(AppVersion.current))
        #expect(AppVersion.display.hasPrefix("v"))
        #expect(ShareCard.wordmark == "VINODEX")
    }
}
