import Testing
@testable import VinodexCore

/// The back-plate stamp series (0.6.4, F2) against its contract with the
/// Passport: one stamp per badge, no orphans in either direction, and record
/// fields well-formed enough for the code-drawn frame to render them.
@Suite("Back-plate stamp catalog")
struct StampCatalogTests {
    private let db = WineDatabase.shared

    private var passport: Passport {
        Passport.compute(tried: [], in: db, bestStreak: 0, highestTier: .novice)
    }

    @Test("catalog ids are exactly the Passport badge ids")
    func catalogMatchesBadges() {
        let badgeIDs = passport.badges.map(\.id)
        let stampIDs = StampCatalog.all.map(\.id)

        #expect(
            stampIDs == badgeIDs,
            "a badge without a stamp never appears on the plate; a stamp without a badge can never be earned"
        )
    }

    @Test("every stamp record is renderable")
    func recordsWellFormed() {
        for stamp in StampCatalog.all {
            #expect(!stamp.title.isEmpty, "\(stamp.id) has no title")
            #expect(!stamp.info.isEmpty, "\(stamp.id) has no tap-for-info copy")
            #expect(!stamp.denomination.isEmpty, "\(stamp.id) has no denomination")
            #expect(!stamp.fallbackSymbol.isEmpty, "\(stamp.id) has no fallback glyph")

            // #RRGGBB — what Color(dexHex:) parses without falling back to grey.
            #expect(
                stamp.colorHex.hasPrefix("#") && stamp.colorHex.count == 7
                    && stamp.colorHex.dropFirst().allSatisfy(\.isHexDigit),
                "\(stamp.id) ink '\(stamp.colorHex)' is not #RRGGBB"
            )

            // Pipeline stems are kebab-case under the stamp- prefix, so the
            // authored art can drop straight into art/icons/chrome/stamps/.
            #expect(
                stamp.artStem.hasPrefix("stamp-"),
                "\(stamp.id) art stem '\(stamp.artStem)' misses the stamp- prefix"
            )
        }
    }

    @Test("stems and inks are unique — each stamp is its own issue")
    func distinctIssues() {
        #expect(Set(StampCatalog.all.map(\.artStem)).count == StampCatalog.all.count)
        #expect(Set(StampCatalog.all.map(\.colorHex)).count == StampCatalog.all.count)
    }

    @Test("an empty passport unlocks nothing; lookup finds every badge")
    func unlockFlow() {
        #expect(StampCatalog.unlocked(from: passport).isEmpty)
        for badge in passport.badges {
            #expect(StampCatalog.stamp(for: badge.id) != nil)
        }
        #expect(StampCatalog.stamp(for: "notABadge") == nil)
    }
}
