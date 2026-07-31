import Foundation

/// One postage stamp on the device's back plate (0.6.4, F2).
///
/// The 0.6.2 "passport stamps" were rubber-ink text blocks — `· VINODEX
/// PASSPORT · / ADMITTED` pressed straight onto the metal — which is not what
/// the brief meant: these are *letter* stamps, physical paper stuck to the
/// plate like the barcode sticker, each with its own picture and colour, and
/// tappable for their story. The redo splits the object the way the barcode
/// does: the frame, perforations and ageing are code-drawn
/// (`BackPlateStampView`), while the record here carries everything that makes
/// one stamp different from another — so a new stamp is a glyph plus a record,
/// no layout work.
///
/// In Core rather than the view because the catalog's contract with
/// `Passport` — one stamp per badge, no orphans in either direction — is a
/// data fact worth pinning in a Linux-runnable test.
public struct BackPlateStamp: Sendable, Equatable, Identifiable {
    /// Matches the `Passport.Badge` id that unlocks it.
    public let id: String
    /// The stamp face's caption and the info sheet's title.
    public let title: String
    /// The tap-for-info copy: what this stamp commemorates.
    public let info: String
    /// Frame, keyline and ink — `#RRGGBB`. Each stamp has its own colour,
    /// like a real series.
    public let colorHex: String
    /// Pixel-art glyph stem under `Resources/StampArt`, through the
    /// `art/icons/stamps/` pipeline. The art set is still being authored, so
    /// the view falls back to `fallbackSymbol` when the stem has no PNG yet —
    /// dropping the file in is the whole upgrade.
    public let artStem: String
    /// SF Symbol standing in until the drawn glyph exists.
    public let fallbackSymbol: String
    /// The denomination corner — postage says how much it was worth.
    public let denomination: String

    public init(
        id: String,
        title: String,
        info: String,
        colorHex: String,
        artStem: String,
        fallbackSymbol: String,
        denomination: String
    ) {
        self.id = id
        self.title = title
        self.info = info
        self.colorHex = colorHex
        self.artStem = artStem
        self.fallbackSymbol = fallbackSymbol
        self.denomination = denomination
    }
}

/// The full stamp series, keyed to the Passport's badges.
public enum StampCatalog {
    /// Every stamp the plate can carry, in badge order. Denominations climb
    /// with the badge's difficulty — a little philatelic joke that also makes
    /// each stamp's rank legible at a glance.
    public static let all: [BackPlateStamp] = [
        BackPlateStamp(
            id: "firstSip",
            title: "FIRST SIP",
            info: "Issued for your first tasting. Every cellar, every journey, every ruined carpet starts with one glass.",
            colorHex: "#A63838",
            artStem: "stamp-first-sip",
            fallbackSymbol: "wineglass",
            denomination: "1¢"
        ),
        BackPlateStamp(
            id: "tenBottles",
            title: "TEN BOTTLES",
            info: "Ten tastings on the shelf. The palate is officially a returning customer.",
            colorHex: "#33518F",
            artStem: "stamp-ten-bottles",
            fallbackSymbol: "shippingbox.fill",
            denomination: "10¢"
        ),
        BackPlateStamp(
            id: "allNoble",
            title: "ALL NOBLE",
            info: "Every noble grape, tried. The aristocracy has received you; act surprised.",
            colorHex: "#6E4F8F",
            artStem: "stamp-all-noble",
            fallbackSymbol: "crown.fill",
            denomination: "25¢"
        ),
        BackPlateStamp(
            id: "regionComplete",
            title: "REGION COMPLETE",
            info: "Every notable grape of one region, tried. Somewhere on a map, a place is entirely yours.",
            colorHex: "#2F6E4F",
            artStem: "stamp-region-complete",
            fallbackSymbol: "mappin.and.ellipse",
            denomination: "15¢"
        ),
        BackPlateStamp(
            id: "streakWeek",
            title: "STREAK WEEK",
            info: "Seven daily challenges in a row. Discipline, applied to wine — a rare vintage.",
            colorHex: "#8F5A33",
            artStem: "stamp-streak-week",
            fallbackSymbol: "flame.fill",
            denomination: "7¢"
        ),
        BackPlateStamp(
            id: "sommelier",
            title: "SOMMELIER",
            info: "The Wine Exam's top tier, unlocked. The device defers to your judgement from here on.",
            colorHex: "#2F6E6E",
            artStem: "stamp-sommelier",
            fallbackSymbol: "graduationcap.fill",
            denomination: "50¢"
        ),
    ]

    /// The stamp for one badge id, or nil for an id the series does not know.
    public static func stamp(for badgeID: String) -> BackPlateStamp? {
        all.first { $0.id == badgeID }
    }

    /// The stamps the passport has earned, in series order — the Passport
    /// unlock is what makes another stamp appear on the plate (F2).
    public static func unlocked(from passport: Passport) -> [BackPlateStamp] {
        let earned = Set(passport.badges.filter(\.earned).map(\.id))
        return all.filter { earned.contains($0.id) }
    }
}
