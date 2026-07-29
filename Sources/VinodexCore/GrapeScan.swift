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
public struct GrapeScanCriteria: Sendable, Hashable {
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

    /// Distinct values of some field across flavour entries, most common first,
    /// ties broken alphabetically so the order is stable between builds.
    private func counted(_ key: (WineEntry) -> String?) -> [String] {
        var tally: [String: Int] = [:]
        for entry in entries(in: .flavors) {
            guard let value = key(entry), !value.isEmpty else { continue }
            tally[value, default: 0] += 1
        }
        return tally
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)
    }
}
