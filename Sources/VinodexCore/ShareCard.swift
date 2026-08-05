import Foundation

/// What the shareable cards state (0.7.8, B1–B3).
///
/// **In Core because the numbers are the part that can be wrong.** The drawing
/// is `ImageRenderer` and stays in `VinodexUI`; "42 of 171 grapes" printing 43,
/// or a card claiming 100% at 437 of 438, is a data bug and `VinodexUI` has no
/// test target. Same split the label reader uses.
///
/// These are outward-facing images — they carry the product's name into
/// somebody else's feed — so every string here is assembled from live state.
/// Nothing is a literal that can go stale, and the version comes from
/// `AppVersion.display`, whose `placeholders` denylist exists precisely so a
/// card cannot ship reading `v1.0.0`.
public enum ShareCard {
    /// The wordmark on every card.
    public static let wordmark = "VINODEX"

    /// A player's passport, reduced to what fits on a card (B2).
    public struct Profile: Sendable, Equatable {
        /// `PassportTier.displayName`, or the unranked line.
        public let rank: String
        public let triedTotal: Int
        /// Everything tastable in the catalog — grapes plus styles, the same
        /// pool `triedTotal` counts against.
        public let collectible: Int
        public let triedGrapes: Int
        public let totalGrapes: Int
        public let triedStyles: Int
        public let totalStyles: Int
        public let countries: Int
        public let continents: Int
        public let badgesEarned: Int
        public let badgesTotal: Int
        public let streak: Int
        public let bestStreak: Int
        /// What the player is running — a fitted workshop build's name, or the
        /// shell's. See `favouriteDevice` on the UI side for why this is a
        /// string rather than a type.
        public let device: String

        public init(
            rank: String, triedTotal: Int, collectible: Int,
            triedGrapes: Int, totalGrapes: Int, triedStyles: Int, totalStyles: Int,
            countries: Int, continents: Int, badgesEarned: Int, badgesTotal: Int,
            streak: Int, bestStreak: Int, device: String
        ) {
            self.rank = rank
            self.triedTotal = triedTotal
            self.collectible = collectible
            self.triedGrapes = triedGrapes
            self.totalGrapes = totalGrapes
            self.triedStyles = triedStyles
            self.totalStyles = totalStyles
            self.countries = countries
            self.continents = continents
            self.badgesEarned = badgesEarned
            self.badgesTotal = badgesTotal
            self.streak = streak
            self.bestStreak = bestStreak
            self.device = device
        }

        /// Completion over the tastable catalog, 0...1.
        public var completion: Double {
            collectible > 0 ? Double(triedTotal) / Double(collectible) : 0
        }

        /// Whole percent, **floored short of the end and exact at it**.
        ///
        /// Rounding would print `100%` at 437 of 438, which is the one number
        /// on this card a reader would check and the one claim the player has
        /// not earned. Floor everywhere, then 100 only when it is genuinely
        /// finished — and 0% stays 0% rather than rounding up off nothing.
        public var completionPercent: Int {
            guard collectible > 0 else { return 0 }
            if triedTotal >= collectible { return 100 }
            return min(99, Int((completion * 100).rounded(.down)))
        }
    }

    /// The passport/achievement card's headline (B3).
    ///
    /// Two shapes, because the brief names two: a milestone that was *unlocked*
    /// and a count that was *reached*.
    public struct Achievement: Sendable, Equatable {
        public let headline: String
        public let caption: String

        public init(headline: String, caption: String) {
            self.headline = headline
            self.caption = caption
        }

        /// "SOMMELIER TIER UNLOCKED" — a badge or rank crossing.
        public static func unlocked(_ title: String, blurb: String) -> Achievement {
            Achievement(headline: "\(title) UNLOCKED", caption: blurb)
        }

        /// "42/171 GRAPES COLLECTED".
        public static func collected(_ done: Int, of total: Int, noun: String) -> Achievement {
            Achievement(
                headline: "\(done)/\(total) \(noun) COLLECTED",
                caption: done >= total
                    ? "The whole shelf."
                    : "\(total - done) left to pour."
            )
        }
    }

    /// Builds the profile card from the passport and the two stores that sit
    /// beside it. Pure, so the arithmetic is testable.
    public static func profile(
        from passport: Passport,
        streak: Int,
        bestStreak: Int,
        device: String
    ) -> Profile {
        Profile(
            rank: passport.tier?.displayName ?? "UNRANKED",
            triedTotal: passport.triedTotal,
            collectible: passport.totalGrapes + passport.totalStyles,
            triedGrapes: passport.triedGrapes,
            totalGrapes: passport.totalGrapes,
            triedStyles: passport.triedStyles,
            totalStyles: passport.totalStyles,
            countries: passport.countries,
            continents: passport.continents.count,
            badgesEarned: passport.badges.filter(\.earned).count,
            badgesTotal: passport.badges.count,
            streak: streak,
            bestStreak: bestStreak,
            device: device
        )
    }

    /// The achievement worth leading a card with, or nil for a passport that
    /// has nothing to announce yet.
    ///
    /// Prefers the rank — it is the ladder the player is actually climbing —
    /// and falls back to the newest earned badge, then to the grape count,
    /// which every player has some of.
    public static func headline(for passport: Passport) -> Achievement {
        if let tier = passport.tier {
            return .unlocked(tier.displayName, blurb: tier.blurb)
        }
        if let badge = passport.badges.last(where: \.earned) {
            return .unlocked(badge.title, blurb: badge.blurb)
        }
        return .collected(passport.triedGrapes, of: passport.totalGrapes, noun: "GRAPES")
    }
}
