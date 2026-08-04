import Testing
import Foundation
@testable import VinodexCore

/// The pedigree graph (0.7.5, E1).
///
/// Two kinds of assertion live here and they are worth telling apart. The first
/// half pins the **shipped data** — the counts and the specific crosses — which
/// is a data gate the way `CoverageTests` is, and moves when `sommbot` authors
/// more lineage. The second half pins the **reverse pass**, which is logic, and
/// must not move at all: only the child-facing direction is stored, so every
/// offspring, mutation and half-sibling in the app is derived by
/// `GrapeLineageIndex` and nothing else checks it.
@Suite("Grape lineage")
struct GrapeLineageTests {
    private let db = WineDatabase.shared

    private func grapes() -> [GrapeEntry] {
        db.entries.compactMap {
            if case .grape(let g) = $0 { return g }
            return nil
        }
    }

    // MARK: The shipped data

    /// **The coverage pin.** 40% is the honest number and the feature is
    /// designed around it — see `EntryDetailScreen`, which does not offer the
    /// tree on the other 60% rather than opening an empty box.
    ///
    /// Bump these together with a data batch, and say which batch moved them.
    @Test("the authored lineage covers what 0.7.5 authored")
    func coverageIsPinned() {
        let all = grapes()
        #expect(all.count == 171)
        #expect(all.filter { $0.lineage != nil }.count == 57, "grapes carrying an authored lineage")
        #expect(db.lineage.connectedIDs.count == 68, "grapes in at least one relationship")
    }

    /// Every ref resolves, and resolves to the right *kind* of thing.
    ///
    /// The Swift-side twin of `find-missing-refs.mjs`' lineage arm: that gate
    /// reads `entries.json` before the app does, this one reads what the app
    /// decoded. An `id` must name a grape; a `name` must not be blank; exactly
    /// one of the two is set, which is the schema `LineageRef` documents and
    /// nothing in Swift's type system enforces.
    @Test("every lineage ref is well formed")
    func refsAreWellFormed() {
        let ids = Set(grapes().map(\.id))
        for grape in grapes() {
            guard let lineage = grape.lineage else { continue }
            let refs = lineage.parents + (lineage.mutationOf.map { [$0] } ?? []) + lineage.related
            for ref in refs {
                #expect(
                    (ref.id == nil) != (ref.name == nil),
                    "\(grape.common.name) has a ref with both id and name, or neither"
                )
                if let id = ref.id {
                    #expect(ids.contains(id), "\(grape.common.name) points at unknown grape \(id)")
                }
                if let name = ref.name {
                    #expect(!name.isEmpty, "\(grape.common.name) has an unnamed external ancestor")
                }
            }
        }
    }

    /// The canonical five-grape cross, and the one everybody checks first.
    @Test("Cabernet Sauvignon is Cabernet Franc x Sauvignon Blanc")
    func cabernetSauvignonsParents() {
        let relatives = db.lineage.relatives(of: "G001")
        #expect(relatives.parents.count == 2)
        // Hoisted out of the macro: `#expect` wraps a bare `allSatisfy` in its
        // rethrows-checking shim and fails to compile.
        let bothNavigable = relatives.parents.allSatisfy(\.isNavigable)
        #expect(bothNavigable)
        #expect(relatives.parents.map(\.name) == ["Cabernet Franc", "Sauvignon Blanc"])
    }

    /// **The off-catalog case, and the reason the tree has two kinds of node.**
    /// Gouais Blanc is the mother of ten grapes here and is not an entry.
    @Test("an off-catalog ancestor is a terminal node, not a broken link")
    func externalAncestorsAreTerminal() {
        let chardonnay = db.lineage.relatives(of: "G003")
        let gouais = chardonnay.parents.first { $0.name == "Gouais Blanc" }
        #expect(gouais != nil, "Chardonnay lost its Gouais Blanc parent")
        #expect(gouais?.isNavigable == false, "an off-catalog ancestor must not be tappable")
        #expect(gouais?.entryID == nil)
        // The other parent *is* an entry, on the same list — which is exactly
        // the mixed row the renderer has to handle.
        #expect(chardonnay.parents.contains { $0.entryID == "G002" })
        // And it is not an entry by any route, including the name index the
        // rest of the catalog resolves through.
        #expect(db.entry(named: "Gouais Blanc") == nil)
    }

    // MARK: The reverse pass

    /// Offspring and mutations exist only because this pass builds them.
    @Test("offspring and mutations are derived from the child-facing data")
    func reversePassBuildsBothDirections() {
        let pinot = db.lineage.relatives(of: "G002")
        #expect(pinot.offspring.count == 6, "Pinot Noir's offspring")
        #expect(pinot.mutations.count == 3, "Pinot Noir's colour mutations")
        #expect(pinot.mutations.map(\.name).sorted() == ["Pinot Blanc", "Pinot Gris", "Pinot Meunier"])
        // Pinot Noir itself authors a lineage (a contested Savagnin parent), so
        // none of the above comes from its own record.
        let offspringNavigable = pinot.offspring.allSatisfy(\.isNavigable)
        #expect(offspringNavigable)

        // The other end of the same edge.
        let gris = db.lineage.relatives(of: "G021")
        #expect(gris.mutationOf?.entryID == "G002")
        #expect(gris.offspring.isEmpty)
    }

    /// Half-siblings through an ancestor that is not in the app at all.
    ///
    /// This is the pass's most load-bearing property: the shared-parent key is
    /// `id ?? normalised name`, so an external ancestor still holds a family
    /// together. It also pins `via`, without which an eleven-name sibling list
    /// says nothing about *why* those eleven.
    @Test("half-siblings group through an off-catalog parent")
    func siblingsGroupThroughExternalParents() {
        let chardonnay = db.lineage.relatives(of: "G003")
        let throughGouais = chardonnay.siblings.filter { $0.via == "Gouais Blanc" }
        #expect(throughGouais.count == 9, "the other nine children of Gouais Blanc")
        #expect(throughGouais.contains { $0.name == "Riesling" })
        #expect(throughGouais.contains { $0.name == "Gamay" })
        #expect(!chardonnay.siblings.contains { $0.entryID == "G003" }, "a grape is not its own sibling")
        // Through the *other* parent as well, which is why a sibling's identity
        // includes the relative it came through.
        #expect(chardonnay.siblings.contains { $0.via == "Pinot Noir" })
    }

    /// Two grapes that mutated from the same variety are siblings too.
    @Test("mutations of one variety are siblings of each other")
    func mutationsShareASiblingGroup() {
        let gris = db.lineage.relatives(of: "G021")
        let names = Set(gris.siblings.filter { $0.via == "Pinot Noir" }.map(\.name))
        #expect(names.contains("Pinot Blanc"))
        #expect(names.contains("Pinot Meunier"))
        // Pinot Noir's *offspring* are half-siblings of its mutations through
        // the same key, which is correct — they all descend from the one vine.
        #expect(names.contains("Chardonnay"))
    }

    /// **Contest survives the reverse pass**, which is the honesty requirement.
    ///
    /// Listán Negro authors a contested Palomino parent. Read from Palomino's
    /// end, the edge has to still say so — otherwise the app asserts from one
    /// direction exactly what it declines to assert from the other.
    @Test("a contested edge reads as contested from both ends")
    func contestSurvivesTheReversePass() {
        let listan = db.lineage.relatives(of: "G146")
        let palominoRef = listan.parents.first { $0.entryID == "G057" }
        #expect(palominoRef?.contested == true)

        let palomino = db.lineage.relatives(of: "G057")
        let listanRef = palomino.offspring.first { $0.entryID == "G146" }
        #expect(listanRef != nil, "Palomino lost its Listán Negro offspring")
        #expect(listanRef?.contested == true, "the contest was dropped on the way back")
    }

    /// The footnote reaches whoever draws the edge, from either end.
    @Test("authored notes surface on both ends of the edge")
    func notesSurface() {
        // The grape's own note.
        let syrah = db.lineage.relatives(of: "G005")
        #expect(syrah.notes.contains { $0.contains("Mondeuse Blanche") })
        // And the same note, reached from the other end of a derived edge.
        let palomino = db.lineage.relatives(of: "G057")
        #expect(palomino.notes.contains { $0.contains("Listan") })
        // De-duplicated: a note reachable by two edges prints once.
        #expect(Set(palomino.notes).count == palomino.notes.count)
    }

    /// **The 103 grapes with nothing to show**, which is the case the feature is
    /// shaped around rather than the exception.
    @Test("a grape with no relatives reports empty")
    func unconnectedGrapesAreEmpty() {
        // Zinfandel: Tribidrag's parents are unresolved, so nothing is authored
        // and nobody points at it. See data-review/FINDINGS.md.
        #expect(db.lineage.hasLineage("G017") == false)
        let relatives = db.lineage.relatives(of: "G017")
        #expect(relatives.isEmpty)
        #expect(relatives.edgeCount == 0)
        // An id that is not a grape at all answers the same way rather than
        // trapping — the screen is reachable by route, and a route carries a
        // string.
        #expect(db.lineage.relatives(of: "not-an-entry").isEmpty)
    }

    /// Nebbiolo authors nothing and is still in the graph, because something
    /// else names it. The distinction `connectedIDs` exists to draw.
    @Test("a grape with only derived edges still has a tree")
    func derivedOnlyGrapesAreConnected() {
        let nebbiolo = db.entries.first { $0.id == "G008" }
        #expect(nebbiolo != nil)
        if case .grape(let g) = nebbiolo { #expect(g.lineage == nil) }
        #expect(db.lineage.hasLineage("G008"))
        #expect(db.lineage.relatives(of: "G008").offspring.isEmpty == false)
    }

    /// `related` is symmetric by definition, so the index reverses it.
    ///
    /// **Both of today's `related` refs are off-catalog** (Sangiovese's two), so
    /// nothing in the shipped data exercises this. That is precisely why it is a
    /// fixture: the day an authored `related` names a catalog grape, the partner
    /// grape's tree must draw the edge too rather than half the pair knowing
    /// about it.
    @Test("an in-catalog related ref reverses")
    func relatedIsSymmetric() {
        let index = GrapeLineageIndex(grapes: [
            Self.fixture(id: "X1", name: "Alpha", lineage: GrapeLineage(related: [LineageRef(id: "X2", contested: true)])),
            Self.fixture(id: "X2", name: "Beta"),
        ])
        let beta = index.relatives(of: "X2")
        #expect(beta.related.count == 1)
        #expect(beta.related.first?.entryID == "X1")
        #expect(beta.related.first?.contested == true)
        #expect(index.hasLineage("X2"))
    }

    /// A ref carrying neither id nor name is dropped rather than crashing — the
    /// schema forbids it and `find-missing-refs.mjs` fails on it, but a screen
    /// is not the place to find that out.
    @Test("a malformed ref costs one edge, not the screen")
    func malformedRefsAreDropped() {
        let index = GrapeLineageIndex(grapes: [
            Self.fixture(
                id: "X1", name: "Alpha",
                lineage: GrapeLineage(parents: [LineageRef(), LineageRef(name: "Gouais Blanc")])
            ),
        ])
        let alpha = index.relatives(of: "X1")
        #expect(alpha.parents.count == 1)
        #expect(alpha.parents.first?.name == "Gouais Blanc")
    }

    /// A minimal grape, for the two fixtures above.
    ///
    /// Built by decoding JSON rather than by an initialiser, because
    /// `GrapeEntry` hand-writes `init(from:)` and has no memberwise init — and
    /// going through the decoder means a fixture cannot drift from the shape the
    /// app actually parses.
    private static func fixture(id: String, name: String, lineage: GrapeLineage? = nil) -> GrapeEntry {
        var object: [String: Any] = [
            "id": id, "name": name, "description": "", "color": "#000000", "tags": [],
            "category": "GRAPES", "grapeType": "red", "grapeStyle": "Test",
            "grapeBodyClass": "Full", "grapeCountryOfOrigin": "Nowhere", "rarity": "COMMON",
            "grapeCharacteristics": [
                "tannin": 3, "acid": 3, "colorIntensity": 3, "aromatics": 3, "body": 3,
            ],
            "details": ["origin": "Nowhere", "synonyms": [], "keyRegions": [], "body": "Full"],
        ]
        if let lineage {
            object["lineage"] = try! JSONSerialization.jsonObject(
                with: try! JSONEncoder().encode(lineage)
            )
        }
        let data = try! JSONSerialization.data(withJSONObject: object)
        return try! JSONDecoder().decode(GrapeEntry.self, from: data)
    }
}
