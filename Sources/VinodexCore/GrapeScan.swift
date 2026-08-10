import Foundation

/// The three body classes the dataset actually carries.
///
/// A closed enum rather than the raw `grapeBodyClass` string so the scanner
/// cannot offer a body no grape has — the data holds exactly Light, Medium and
/// Full, and a fourth chip would be a dead end you could only find by tapping.
public enum GrapeBody: String, Codable, Sendable, CaseIterable, Identifiable {
    case light = "Light"
    case medium = "Medium"
    case full = "Full"

    public var id: String { rawValue }

    public var label: String { rawValue.uppercased() }
}

/// What the scanner has been told so far.
///
/// Every field is optional because the game is explicitly skippable at each
/// step — "I don't know" is a first-class answer, and the reveal has to work
/// from none, some or all of it. An empty criteria set matches every grape,
/// which is the correct behaviour: you told it nothing, so nothing is excluded.
/// `Codable` so `ScreenStateStore` can hold the answers while the scanner's view
/// is torn down — opening a revealed grape and pressing Back used to drop five
/// questions' worth of input on the floor.
public struct GrapeScanCriteria: Codable, Sendable, Hashable {
    /// Ceiling on the flavour basket. Three is the point at which an AND across
    /// tasting notes stops matching anything real — see `matches`.
    public static let flavorLimit = 3

    public var color: GrapeColor?
    public var body: GrapeBody?
    /// Country of origin, as named by the globe's continent → country walk.
    public var country: String?
    /// Ids of chosen flavour entries, capped at `flavorLimit`.
    public var flavorIDs: [String]

    public init(
        color: GrapeColor? = nil,
        body: GrapeBody? = nil,
        country: String? = nil,
        flavorIDs: [String] = []
    ) {
        self.color = color
        self.body = body
        self.country = country
        self.flavorIDs = flavorIDs
    }

    /// Whether anything at all has been chosen. A reveal from a blank slate is
    /// just a shuffled list, so the UI keeps the button honest.
    public var isEmpty: Bool {
        color == nil && body == nil && country == nil && flavorIDs.isEmpty
    }

    public var flavorsAreFull: Bool { flavorIDs.count >= Self.flavorLimit }

    /// Adds or removes a flavour, refusing to exceed the cap.
    public mutating func toggleFlavor(_ id: String) {
        if let index = flavorIDs.firstIndex(of: id) {
            flavorIDs.remove(at: index)
        } else if !flavorsAreFull {
            flavorIDs.append(id)
        }
    }
}

public extension WineDatabase {
    /// Whether one grape carries one flavour.
    ///
    /// Checked both ways round on purpose. The generated link runs flavour →
    /// grape (`FlavorDetails.notableGrapes` is how flavours are derived in the
    /// first place), but a grape's own `tastingProfile` names its notes as free
    /// text, and the two do not agree for every pair. Either direction counts.
    func grape(_ grape: WineEntry, carries flavor: WineEntry) -> Bool {
        let grapeKey = TextNormalize.label(grape.name)
        if flavor.notableGrapes.contains(where: { TextNormalize.label($0) == grapeKey }) {
            return true
        }
        let flavorKey = TextNormalize.label(flavor.name)
        return grape.tastingProfile.contains { TextNormalize.label($0.note) == flavorKey }
    }

    /// Grapes satisfying every criterion given.
    ///
    /// The flavours are ANDed, not ORed: picking Blackcurrant *and* Cedar means
    /// "a grape that shows both", which is how anyone describing a wine in
    /// front of them would mean it. That is also why the basket is capped —
    /// three specific notes already narrow 80 grapes to a handful, and a fourth
    /// reliably produces nothing.
    func grapesMatching(_ criteria: GrapeScanCriteria) -> [WineEntry] {
        let flavors = criteria.flavorIDs.compactMap { entry(id: $0) }

        return entries(in: .grapes)
            .filter { candidate in
                guard case .grape(let g) = candidate else { return false }

                if let color = criteria.color, g.grapeType != color { return false }

                if let body = criteria.body,
                   TextNormalize.label(g.grapeBodyClass) != TextNormalize.label(body.rawValue) {
                    return false
                }

                if let country = criteria.country,
                   !TextNormalize.matchesWholeTerm(g.grapeCountryOfOrigin, country) {
                    return false
                }

                return flavors.allSatisfy { grape(candidate, carries: $0) }
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Flavour entries under one class (SWEET, UMAMI, ...) or one subclass
    /// (BERRY, SMOKY, ...), for the scanner's flavour tiles.
    func flavors(inClass classification: String? = nil, subclass: String? = nil) -> [WineEntry] {
        entries(in: .flavors)
            .filter { entry in
                guard case .flavor(let f) = entry else { return false }
                if let classification,
                   TextNormalize.label(f.details.classification) != TextNormalize.label(classification) {
                    return false
                }
                if let subclass,
                   TextNormalize.label(f.details.subclass) != TextNormalize.label(subclass) {
                    return false
                }
                return true
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// The style classes present in the data, in descending size (0.7.0, H2).
    ///
    /// Beside the flavour taxonomies below and derived the same way, for the
    /// same reason: `StyleClassType` has five cases and the catalog uses four,
    /// because `.style` is only ever reached as
    /// `EntryDisplay.styleClass(name:classification:)`'s fallback. A chip row
    /// built from the enum offers a fifth chip that empties the list.
    var styleClasses: [StyleClassType] {
        var tally: [StyleClassType: Int] = [:]
        for case .style(let s) in entries(in: .styles) {
            let cls = EntryDisplay.styleClass(
                name: s.common.name,
                classification: s.details.classification
            )
            tally[cls, default: 0] += 1
        }
        return tally.keys.sorted {
            let a = tally[$0] ?? 0
            let b = tally[$1] ?? 0
            return a == b ? $0.rawValue < $1.rawValue : a > b
        }
    }

    /// The flavour classes present in the data, in descending size — the
    /// scanner lists them rather than hardcoding five names that the generator
    /// is free to change.
    var flavorClasses: [String] {
        counted { entry in
            guard case .flavor(let f) = entry else { return nil }
            return f.details.classification
        }
    }

    /// The flavour subclasses present in the data, in descending size.
    var flavorSubclasses: [String] {
        counted { entry in
            guard case .flavor(let f) = entry else { return nil }
            return f.details.subclass
        }
    }

    /// **The grape styles present in the data, in descending size (0.8.8, C1).**
    ///
    /// The catalog's own spelling of `grapeStyle` — "Full-Body Red", "Aromatic
    /// White" — not a normalised or reconstructed form, because this is the
    /// vocabulary a chip's stored value has to equal and the value is what
    /// `EntryFilter.type` already compares.
    ///
    /// **Derived rather than enumerated, and there is no enum to enumerate.**
    /// This is the fourth data-driven row and the first whose vocabulary has no
    /// Swift type at all: `grapeStyle` is a free-text field on the grape, ten
    /// distinct values across 177 grapes today, and the shape of the ten is the
    /// whole reason this facet exists rather than a body-and-colour compound.
    /// Six of them read as a compound (`Full-Body Red`, `Light-Body White`);
    /// **four do not** — `Aromatic White`, `Sweet White`, `Madeira`,
    /// `Sparkling Red` — and those four sit on 14 grapes whose separate
    /// `grapeBodyClass` and `grapeType` fields say something else entirely.
    /// Gewürztraminer is `Full` and `white` and `Aromatic White`. See
    /// `EntryFilter.chipOption` for the measurement that settles it.
    ///
    /// `Madeira` is a fortified wine rather than a grape style and rests on
    /// three grapes; that is a data question and is left to one, but it is a
    /// good illustration of why the row is read off the catalog — an authored
    /// list here would have quietly dropped it.
    var grapeStyles: [String] {
        counted(in: .grapes) { entry in
            guard case .grape(let g) = entry else { return nil }
            return g.grapeStyle
        }
    }

    /// Distinct values of some field across one category's entries, most common
    /// first, ties broken alphabetically so the order is stable between builds.
    ///
    /// The category became a parameter in 0.8.8's C1, when `grapeStyles` joined
    /// the two flavour rows. It was hardcoded to `.flavors` because both callers
    /// were flavour rows; a third caller over a different table is exactly the
    /// moment to pass it rather than to write the loop again.
    private func counted(
        in category: EntryCategory = .flavors,
        _ key: (WineEntry) -> String?
    ) -> [String] {
        var tally: [String: Int] = [:]
        for entry in entries(in: category) {
            guard let value = key(entry), !value.isEmpty else { continue }
            tally[value, default: 0] += 1
        }
        return tally
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)
    }
}
