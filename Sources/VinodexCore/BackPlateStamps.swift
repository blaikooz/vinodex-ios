import Foundation
import Observation

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
            fallbackSymbol: DexGlyph.challenge,
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

/// The fixed decals printed on the back plate, as opposed to the stamps the
/// Passport issues (0.8.5, F1).
///
/// **Why these are a type and not four string literals in `DeviceBackPlate`.**
/// All four were `Canvas` and `Shape` drawings from 0.6.4 — `BarcodeSticker`
/// hand-listed its bar widths, `RippedPriceTag` hand-listed its tear steps —
/// and F1 replaces the first two with drawn art and adds two more. That makes
/// four stems the bundle has to hold and the importer has to produce, and the
/// lesson of `art/icons/stamps/` arriving with ten files named for their
/// pictures is that a stem agreed by convention between a Python dict and a
/// Swift view is a stem nobody checks.
///
/// So the roster is here, in Core, next to `StampCatalog` and for the same
/// reason `DexGlyph` is in Core: it has to be visible to a Linux `swift test`.
/// `ArtPipelineRosterTests` holds it equal to `import-stamp-art.py`'s
/// `STEM_FOR` and to the PNGs on disk, in both directions — so a decal drawn
/// and not wired, and a decal wired and not drawn, are both build failures
/// rather than a blank rectangle on a screen most users turn to twice.
///
/// **A miss still falls back rather than blanking**, which is the rule every
/// drawn-art surface in this app follows: `DeviceBackPlate` keeps the
/// `Canvas`-drawn barcode and price tag it has always had, and draws them when
/// `PixelArtLoader` returns nil. The gate above is what makes that a safety net
/// instead of the state nobody notices we are in.
public enum BackPlateDecal: String, CaseIterable, Sendable, Identifiable {
    /// The sun-faded barcode label, bottom-leading.
    case barcode
    /// The ripped price tag, top-trailing.
    case priceTag
    /// Two loose postage stamps, printed rather than earned — the plate's own
    /// franking rather than anything the Passport issues.
    case decalOne
    case decalTwo

    public var id: String { rawValue }

    /// Ships in `StampArt` under the `stamp-` prefix, with the badges. A fifth
    /// prefix would have bought nothing: `PixelArtLoader`'s namespace is flat,
    /// these come out of the same source directory, and the stems are disjoint
    /// from `StampCatalog`'s by inspection and by test.
    public var artStem: String {
        switch self {
        case .barcode: "stamp-barcode"
        case .priceTag: "stamp-price-tag"
        case .decalOne: "stamp-decal-one"
        case .decalTwo: "stamp-decal-two"
        }
    }
}

/// How far a stamp has been dragged from the spot the plate issued it in
/// (0.6.7, C1).
///
/// **An offset, not a position.** Two reasons, and both are why the alternative
/// was rejected: the default slot table stays the authority on where a stamp
/// nobody has touched sits, so re-scattering the series later is still a change
/// to one table rather than a migration of everybody's saved coordinates; and an
/// offset survives the plate being a different size — an absolute point saved on
/// a Pro Max lands off the bottom of a mini, where a "somewhere else, about that
/// far" does not.
///
/// `Double` rather than `CGFloat` so the type is Foundation-only and lives in
/// Core with the rest of the stamp model, testable on Linux.
public struct StampOffset: Codable, Sendable, Equatable {
    public var dx: Double
    public var dy: Double

    public static let zero = StampOffset(dx: 0, dy: 0)

    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }
}

/// Where the user has moved each back-plate stamp to.
///
/// In `UserDefaults` rather than `ScreenStateStore`, which is explicit that it
/// holds *session* state and is wiped by Home: a stamp you deliberately dragged
/// to the corner is not a scroll position, and finding the plate re-scattered
/// on the next launch would read as the app forgetting rather than as a fresh
/// screen. Same reasoning as `QuizProgress`, and the same shape.
///
/// JSON-encoded like `BookmarkStore`'s ratings map: six stamps of two doubles is
/// a couple of hundred bytes, so defaults is proportionate.
@MainActor
@Observable
public final class StampLayoutStore {
    public static let shared = StampLayoutStore()

    public static let storageKey = "backPlateStampOffsets"

    private let defaults: UserDefaults

    /// Keyed by stamp id. Absent means "still where the plate put it" — the
    /// default is stored as absence rather than as a zero, so a plate nobody
    /// has rearranged leaves nothing behind.
    private(set) public var offsets: [String: StampOffset]

    /// Injectable for tests; defaults to `.standard` in the app.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: StampOffset].self, from: data) {
            offsets = decoded
        } else {
            offsets = [:]
        }
    }

    public func offset(for id: String) -> StampOffset {
        offsets[id] ?? .zero
    }

    /// Records a stamp's new home. A move back to the issued spot clears the
    /// entry rather than storing a zero, per the note on `offsets`.
    public func move(_ id: String, to offset: StampOffset) {
        if offset == .zero {
            offsets.removeValue(forKey: id)
        } else {
            offsets[id] = offset
        }
        persist()
    }

    public func reset() {
        offsets = [:]
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persist() {
        guard !offsets.isEmpty, let data = try? JSONEncoder().encode(offsets) else {
            defaults.removeObject(forKey: Self.storageKey)
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }
}
