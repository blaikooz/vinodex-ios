import Foundation

// MARK: - What a recogniser hands back
//
// The label reader's boundary with the outside world (0.7.2, LR1). Everything
// in this file is Foundation-only and therefore Linux-testable: the whole point
// of the split is that the *matching* is gated by CI while the *seeing* — which
// needs Vision, a camera and a device — is not.

/// One string an OCR pass read off a label, with what the recogniser thought of
/// it and how big it was on the bottle.
///
/// `prominence` is the only geometric fact that crosses into Core, and it earns
/// the trip: with no producer entity in the catalog (see `LabelField.producer`),
/// the tallest line that matched nothing in the database is the best guess at a
/// producer name anyone can make from text alone. Expressed as a fraction of the
/// image height so it means the same thing whatever the camera resolution was,
/// and defaulted so a provider that cannot report geometry — a future
/// text-completion API, say — still conforms without inventing numbers.
public struct RecognizedString: Codable, Sendable, Hashable {
    /// The string exactly as read. Never normalised here: the no-match state
    /// shows this to the user, and a folded, punctuation-stripped version of
    /// their label would read as a bug.
    public let text: String
    /// The recogniser's own 0–1 confidence in this string.
    public let confidence: Double
    /// Cap height as a fraction of the image height, 0–1.
    public let prominence: Double

    public init(text: String, confidence: Double = 1, prominence: Double = 0) {
        self.text = text
        self.confidence = confidence
        self.prominence = prominence
    }
}

/// Anything that can turn a photograph into strings.
///
/// **The extension point.** `VisionOCRProvider` (in `VinodexUI`) is the shipping
/// implementation and runs entirely on-device, which is the constraint this
/// feature was specified under. The protocol exists so that is a *choice* rather
/// than an assumption: an `OpenAIProvider` or a `GoogleVisionProvider` conforms
/// by implementing one method, and `LabelReaderViewModel` takes the provider in
/// its initialiser, so swapping one in touches neither the view nor the matcher.
///
/// It takes `Data` rather than a `UIImage` deliberately. Core cannot see UIKit,
/// a remote provider would want the encoded bytes anyway, and `VNImageRequestHandler`
/// accepts data directly — so the lowest common denominator is also nobody's
/// inconvenience.
public protocol LabelRecognitionProvider: Sendable {
    /// Named for the DEV panel and for error copy, so "which recogniser failed"
    /// is answerable without a debugger.
    var providerName: String { get }

    /// Every string found in the image, in no particular order.
    ///
    /// Implementations must return *all* of them rather than a best line: the
    /// matcher scans n-grams across the whole set, and a producer, an
    /// appellation and a vintage are typically three different lines in three
    /// different sizes.
    func recognizeText(in imageData: Data) async throws -> [RecognizedString]
}

/// Why a read failed, in terms a user can act on.
///
/// A single enum shared by the provider and the view model so the screen has one
/// switch rather than one per layer. `message` is user-facing copy; the cases
/// are what the code branches on.
public enum LabelReadError: Error, Sendable, Equatable {
    case cameraUnavailable
    case cameraDenied
    case photoLibraryDenied
    case imageUnreadable
    case recognitionFailed(String)

    public var message: String {
        switch self {
        case .cameraUnavailable:
            "This device has no camera available. Choose a photo from your library instead."
        case .cameraDenied:
            "Camera access is off for Vinodex. Turn it on in Settings, or choose a photo from your library."
        case .photoLibraryDenied:
            "Photo access is off for Vinodex. Turn it on in Settings to pick a label photo."
        case .imageUnreadable:
            "That image could not be read. Try another photo."
        case .recognitionFailed(let detail):
            "The label could not be read. \(detail)"
        }
    }
}

// MARK: - Staged progress

/// The processing screen's stages, in order.
///
/// In Core rather than in the view because the *order* is a fact about the
/// pipeline — text before search before inference — and a fact about the
/// pipeline is testable. The view reads `title`; it does not get to invent a
/// sixth stage or run them out of sequence.
public enum LabelReaderStage: String, Codable, Sendable, CaseIterable {
    case reading
    case recognizing
    case searching
    case findingRegions
    case findingGrapes

    public var title: String {
        switch self {
        case .reading: "READING LABEL…"
        case .recognizing: "RECOGNIZING TEXT…"
        case .searching: "SEARCHING VINODEX…"
        case .findingRegions: "FINDING REGIONS…"
        case .findingGrapes: "FINDING GRAPES…"
        }
    }

    /// 0–1, for the progress bar. `allCases` order is the sequence, so this
    /// cannot disagree with the order the stages actually run in.
    public var progress: Double {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), all.count > 1 else { return 0 }
        return Double(index + 1) / Double(all.count)
    }
}

// MARK: - Fields and weights

/// What a label can tell us, in the priority order the matcher works down.
///
/// `allCases` order **is** the priority order (producer first, grape last), so
/// the scan loop reads it from here rather than repeating the sequence.
public enum LabelField: String, Codable, Sendable, CaseIterable {
    /// **There is no Producer entity in Vinodex.** The catalog is grapes,
    /// regions, styles, flavours and countries; nothing models a domaine, a
    /// château or an estate, and no amount of walking the data will produce one.
    ///
    /// So producer matching is text-only and always will be until a producer
    /// dataset exists: `LabelTextScan.producerGuess(...)` picks the most
    /// label-like line that nothing else claimed. It cannot be *confirmed*, only
    /// *reported* — which is why the weight below degrades rather than being
    /// dropped or, worse, awarded in full for a guess. See
    /// `LabelConfidence.producerConfirmed` / `.producerTextOnly`.
    case producer
    /// The named wine. Resolved against **style** entries, which are the only
    /// named-wine entities the catalog holds — Champagne, Port, Sherry,
    /// Prosecco, Super Tuscan, Bordeaux Blend and the body/colour families.
    case wineName
    /// A village or cru inside a region's `details.appellations` — Barolo,
    /// Vouvray, Pauillac. The most specific place a label usually states, and
    /// the one that unlocks the §8 inference walk.
    case appellation
    /// A region entry, by name or synonym.
    case region
    /// A country, from the region origins the catalog actually ships.
    case country
    /// A grape entry, by name, synonym or alternate name.
    case grape
    /// A four-digit year in a plausible range.
    case vintage

    public var title: String {
        switch self {
        case .producer: "PRODUCER"
        case .wineName: "WINE"
        case .appellation: "APPELLATION"
        case .region: "REGION"
        case .country: "COUNTRY"
        case .grape: "GRAPE"
        case .vintage: "VINTAGE"
        }
    }
}

/// The confidence table, summed and clamped to 0–100.
///
/// **These numbers are the spec's, and they are the only place they appear.**
/// A weight is a product decision, not an implementation detail, so tuning one
/// is an edit here rather than a hunt through the matcher.
///
/// The sum of everything *except* a confirmed producer is already 125, so a
/// fully-resolved label clamps to 100 without the producer weight ever being
/// awarded. That is deliberate and it is what "degrade gracefully" means here:
/// the absence of a producer index costs a reading nothing it could otherwise
/// have earned, because the fields that *are* backed by data can reach the
/// ceiling on their own.
public enum LabelConfidence {
    /// Awarded when a producer is confirmed against a producer index.
    /// **Currently unreachable** — no such index exists. Kept at the spec's
    /// value so the day one lands, this is already right.
    public static let producerConfirmed = 50
    /// Awarded when a producer name is *read* but cannot be checked against
    /// anything. Deliberately small: it is the reader's opinion about which line
    /// on the bottle is the estate, and an unverifiable opinion should not be
    /// able to carry a reading over the confidence floor by itself.
    public static let producerTextOnly = 15
    public static let wineName = 40
    public static let appellation = 35
    public static let region = 25
    public static let country = 20
    public static let vintage = 5

    /// A fuzzy match is worth less than an exact one. Applied as a multiplier so
    /// the table above stays the single statement of what each field is worth.
    public static let fuzzyMultiplier = 0.7

    /// Below this, the results screen shows the no-match state — which still
    /// lists the extracted text, the suggested countries and regions, and any
    /// vintage. Set just above `country` so a lone country reading (20), which
    /// is a near-useless identification, does not present itself as one.
    public static let floor = 25

    public static func weight(for field: LabelField, confirmed: Bool = true) -> Int {
        switch field {
        case .producer: confirmed ? producerConfirmed : producerTextOnly
        case .wineName: wineName
        case .appellation: appellation
        case .region: region
        case .country: country
        case .grape: 0   // see `LabelReading.score`
        case .vintage: vintage
        }
    }
}

// MARK: - Result models

/// One field the reader resolved.
///
/// Carries the raw text it matched *and* the catalog's spelling of it, because
/// those differ often enough to matter: OCR reads `CHATEAUNEUF DU PAPE` and the
/// data says `Châteauneuf-du-Pape`, and showing the user only one of the two
/// hides either what the camera saw or what the app decided it meant.
public struct LabelMatch: Codable, Sendable, Hashable, Identifiable {
    public let field: LabelField
    /// The catalog's name for the thing.
    public let name: String
    /// The n-gram from the photo that matched it.
    public let readAs: String
    /// The entry this resolves to, when it resolves to one. Countries are not
    /// entries and vintages are not anything, so this is optional rather than
    /// the model pretending everything is an entry.
    public let entryID: String?
    /// False when the match needed edit-distance tolerance to land. Shown in the
    /// UI and worth less in `score`.
    public let isExact: Bool
    /// True when the field was **walked to** rather than read.
    ///
    /// A label saying only `BAROLO` states a country as surely as one saying
    /// `ITALIA` does — Piedmont's entry says so — and the results screen should
    /// show it either way. But the two are not independent evidence: scoring the
    /// inferred country would award 20 points for the appellation's 35 a second
    /// time. So an inferred match is displayed and is worth nothing, which is
    /// the same rule the grape list already follows.
    public let isInferred: Bool

    public var id: String { "\(field.rawValue)-\(name)" }

    public init(
        field: LabelField,
        name: String,
        readAs: String,
        entryID: String? = nil,
        isExact: Bool = true,
        isInferred: Bool = false
    ) {
        self.field = field
        self.name = name
        self.readAs = readAs
        self.entryID = entryID
        self.isExact = isExact
        self.isInferred = isInferred
    }
}

/// Everything one photograph produced.
///
/// `Codable` so `ScreenStateStore` can hold it while the reader's view is torn
/// down — opening a suggested grape from the results and pressing Back must not
/// throw the read away and send the user back to the camera, which is the same
/// contract `GrapeScanCriteria` has on the blind-tasting screen.
///
/// Entries are referenced by id rather than embedded: the ids are what survive a
/// round trip through JSON cheaply, and `WineDatabase.entry(id:)` is a hash
/// lookup on the other side.
public struct LabelReading: Codable, Sendable, Hashable {
    /// Every string the recogniser returned, in the order it returned them.
    /// Shown verbatim in the no-match state.
    public let recognizedText: [String]
    /// The resolved fields, in `LabelField.allCases` priority order.
    public let matches: [LabelMatch]
    /// Grape entry ids inferred from the place, or matched outright.
    public let grapeIDs: [String]
    /// Style entry ids inferred from the grapes and the place.
    public let styleIDs: [String]
    /// Near-misses, for the no-match state. Empty when the read was confident.
    public let suggestedCountries: [String]
    public let suggestedRegionIDs: [String]
    /// Which provider produced `recognizedText`, for diagnostics.
    public let providerName: String

    public init(
        recognizedText: [String],
        matches: [LabelMatch],
        grapeIDs: [String] = [],
        styleIDs: [String] = [],
        suggestedCountries: [String] = [],
        suggestedRegionIDs: [String] = [],
        providerName: String = ""
    ) {
        self.recognizedText = recognizedText
        self.matches = matches
        self.grapeIDs = grapeIDs
        self.styleIDs = styleIDs
        self.suggestedCountries = suggestedCountries
        self.suggestedRegionIDs = suggestedRegionIDs
        self.providerName = providerName
    }

    public func match(_ field: LabelField) -> LabelMatch? {
        matches.first { $0.field == field }
    }

    /// The confidence score, 0–100.
    ///
    /// Each matched field contributes its weight from `LabelConfidence`, scaled
    /// down when the match was fuzzy, and the total is clamped. Grapes carry no
    /// weight of their own: the spec's table has no grape row, and a grape is
    /// almost always *inferred* from the place rather than read — scoring an
    /// inference would be scoring the same evidence twice.
    public var score: Int {
        var total = 0.0
        // Inferred fields are excluded outright: they are a restatement of
        // evidence another field has already been paid for. See
        // `LabelMatch.isInferred`.
        for match in matches where !match.isInferred {
            // A producer is never confirmed today; `isExact` is what a producer
            // guess carries, and the weight table is what decides that a guess
            // is worth 15 rather than 50.
            let confirmed = match.field == .producer ? false : true
            let weight = Double(LabelConfidence.weight(for: match.field, confirmed: confirmed))
            total += match.isExact ? weight : weight * LabelConfidence.fuzzyMultiplier
        }
        return min(100, max(0, Int(total.rounded())))
    }

    /// Whether to show the results or the no-match state.
    ///
    /// Two conditions, not one. The score floor alone would let a producer guess
    /// plus a vintage (20) sit just under it and a producer guess plus a country
    /// (35) sail over it on no wine knowledge at all — so a confident reading
    /// must also have named something the *database* recognises.
    public var isConfident: Bool {
        guard score >= LabelConfidence.floor else { return false }
        return matches.contains { match in
            guard !match.isInferred else { return false }
            return match.field == .wineName || match.field == .appellation
                || match.field == .region || match.field == .grape
        }
    }

    /// A vintage as an integer, for anything that wants to compare years.
    public var vintage: Int? {
        match(.vintage).flatMap { Int($0.name) }
    }
}
