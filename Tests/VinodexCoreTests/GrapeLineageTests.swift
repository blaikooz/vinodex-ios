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

    /// **The coverage pin**, and the two numbers must be read as two numbers.
    ///
    /// Bump these together with a data batch, and say which batch moved them.
    ///
    /// **0.7.9 (G).** Sommbot's P1/P2 batch took the catalog to 177 grapes and
    /// the authored blocks to 61. `connectedIDs` moved further than the four
    /// new blocks would explain — 68 → 75 — because G176 Gouais Blanc arrived
    /// as a real entry and the ten grapes that named it by *name* now name it
    /// by *id*, which drags Gouais Blanc itself into the graph along with the
    /// new crosses. See `externalAncestorsAreTerminal`, which had to move
    /// grapes for the same reason.
    ///
    /// **0.8.2.** 61 → 163 blocks, 75 → 121 connected, and the gap between
    /// those two jumps is the whole character of this pass. It is not 102 new
    /// crosses: most of the new blocks carry `parentageUnknown` and nothing
    /// else, which is an authored *statement* rather than an edge, so they add
    /// a block without adding a relationship. 163 grapes now say something
    /// about their parentage; 121 have a tree to draw. The 42-grape difference
    /// is exactly the population `EntryDetailScreen` draws the flat PARENTAGE
    /// UNRECORDED panel for, and it went from zero users to its real size in
    /// one batch.
    /// **Batch A, "THE SEAM" (sommbot, 2026-09-01).** 163 → 173 blocks and
    /// 121 → 122 connected, and the lopsidedness is the batch's character:
    /// nine of the ten new natives are authored `parentageUnknown` off empty
    /// VIVC passports (with the debunked lore — Obaideh≠Chardonnay,
    /// Merwah≠Sémillon — recorded in their notes rather than as edges), so
    /// only G188 Fetească Regală, whose mother both readings agree on, joins
    /// the drawn graph.
    @Test("the authored lineage covers what 0.8.2 ships")
    func coverageIsPinned() {
        let all = grapes()
        #expect(all.count == 187)
        #expect(all.filter { $0.lineage != nil }.count == 173, "grapes carrying an authored lineage")
        #expect(db.lineage.connectedIDs.count == 122, "grapes in at least one relationship")
        // **Pinned as a distribution, not a single number** — the two counts
        // above can both be right while the split between "has edges" and
        // "states an absence" is wrong, and that split is what decides which of
        // two very different panels an entry screen draws. A batch that turned
        // every unrecorded statement into a phantom edge would not move either
        // count above by itself.
        let statedOnly = all.filter { $0.lineage?.parentageUnknown == true && $0.lineage?.isEmpty == true }
        #expect(statedOnly.count == 65, "blocks that state an absence and author no edge")
        #expect(all.filter { $0.lineage?.parentageUnknown == true }.count == 83, "grapes stating unknown parentage")
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
    ///
    /// **Rewritten in 0.7.9 (G), not renumbered.** This test used to stand on
    /// Chardonnay and Gouais Blanc, and all three of its assertions were false
    /// the moment sommbot's P1/P2 batch shipped G176 Gouais Blanc as a real
    /// entry — `isNavigable` became true, `entryID` became `"G176"` and
    /// `db.entry(named:)` started resolving. Renumbering would have deleted the
    /// property rather than moved it, because the property *is* "an ancestor
    /// the catalog does not carry draws as a terminal node".
    ///
    /// Magdeleine Noire des Charentes is the replacement, and it is a better
    /// one: it is named by two grapes (G004 Merlot and G012 Malbec), so the
    /// mixed-parent row below is still exercised, and unlike Gouais Blanc it is
    /// a variety nobody drinks and no data batch has a reason to promote.
    @Test("an off-catalog ancestor is a terminal node, not a broken link")
    func externalAncestorsAreTerminal() {
        let merlot = db.lineage.relatives(of: "G004")
        let magdeleine = merlot.parents.first { $0.name == "Magdeleine Noire des Charentes" }
        #expect(magdeleine != nil, "Merlot lost its Magdeleine Noire des Charentes parent")
        #expect(magdeleine?.isNavigable == false, "an off-catalog ancestor must not be tappable")
        #expect(magdeleine?.entryID == nil)
        // The other parent *is* an entry, on the same list — which is exactly
        // the mixed row the renderer has to handle. (G013 Cabernet Franc.)
        #expect(merlot.parents.contains { $0.entryID == "G013" })
        // And it is not an entry by any route, including the name index the
        // rest of the catalog resolves through.
        #expect(db.entry(named: "Magdeleine Noire des Charentes") == nil)
        // The half-sibling key still works off an off-catalog ancestor: Malbec
        // is Merlot's half-sibling through a grape that is not in this app.
        #expect(
            merlot.siblings.contains {
                $0.entryID == "G012" && $0.via == "Magdeleine Noire des Charentes"
            },
            "Malbec is no longer a half-sibling through Magdeleine"
        )
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

    /// Half-siblings through the most-pointed-at ancestor in the dataset.
    ///
    /// This is the pass's most load-bearing property: the shared-parent key is
    /// `id ?? normalised name`, so *either* kind of ancestor still holds a
    /// family together. It also pins `via`, without which an eleven-name
    /// sibling list says nothing about *why* those eleven.
    ///
    /// **Gouais Blanc crossed the line in 0.7.9 (G)** — it is G176 now, and the
    /// ten grapes that named it by name name it by id, so this exercises the
    /// `id` branch of the key. The `name` branch moved to
    /// `externalAncestorsAreTerminal`, which stands on Magdeleine Noire des
    /// Charentes. The count was unchanged at 9 across that move, which was the
    /// point: the key changed form and the family did not come apart.
    ///
    /// **0.8.2 moved it to 12**, and this is a data pin doing its job rather
    /// than a logic failure. Sommbot's pass gave Gouais Blanc three more
    /// children — Xinomavro, Romorantin and Jacquère — which is 13 in the
    /// family and 12 half-siblings once Chardonnay itself is dropped. Note that
    /// this is the *only* count in the suite that moved on new crosses rather
    /// than on new `parentageUnknown` statements, which is worth saying because
    /// the latter is the shape almost every other edit in this batch took.
    @Test("half-siblings group through a shared parent")
    func siblingsGroupThroughExternalParents() {
        let chardonnay = db.lineage.relatives(of: "G003")
        let throughGouais = chardonnay.siblings.filter { $0.via == "Gouais Blanc" }
        #expect(throughGouais.count == 12, "the other twelve children of Gouais Blanc")
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

    /// **The 102 grapes with nothing to show**, which is the case the feature is
    /// shaped around rather than the exception.
    ///
    /// **The subject is derived rather than named, since 0.7.9 (G).** It used to
    /// be Zinfandel, and 0.7.9's data batch connected it: G177 Plavac Mali
    /// authors a contested `related` ref to G017, so Zinfandel acquired an edge
    /// and this test started failing on a change that had nothing to do with
    /// the reverse pass. This half of the suite pins *logic*, not data (see the
    /// suite note), so a hardcoded id here was the wrong kind of pin — it made
    /// a logic test rot on every catalog batch. Asking the index for a grape it
    /// says is unconnected, and then checking the index agrees with itself, is
    /// the assertion that was actually wanted.
    @Test("a grape with no relatives reports empty")
    func unconnectedGrapesAreEmpty() throws {
        let unconnected = try #require(
            grapes().first { !db.lineage.hasLineage($0.id) },
            "every grape is connected — the 40%-coverage premise no longer holds"
        )
        let relatives = db.lineage.relatives(of: unconnected.id)
        #expect(relatives.isEmpty, "\(unconnected.common.name) reports edges it does not have")
        #expect(relatives.edgeCount == 0)
        // An id that is not a grape at all answers the same way rather than
        // trapping — the screen is reachable by route, and a route carries a
        // string.
        #expect(db.lineage.relatives(of: "not-an-entry").isEmpty)
    }

    /// A grape that authors no edge of its own is still in the graph, because
    /// something else names it. The distinction `connectedIDs` exists to draw.
    ///
    /// **Rewritten in 0.8.2, and the rewrite is the finding.** This stood on
    /// G008 Nebbiolo and asserted `g.lineage == nil` — "authors nothing" spelled
    /// as "carries no block". Sommbot's pass gave Nebbiolo
    /// `{ parentageUnknown: true }`, so the block exists and the assertion
    /// broke, and the handoff read that breakage as the *category* emptying:
    /// zero grapes connected only by derived edges, retire the test. That is
    /// not what happened. Fourteen grapes are still connected purely by edges
    /// other grapes drew — Nebbiolo among them, along with Zinfandel, Palomino
    /// and Gouais Blanc — and every one of them now carries a
    /// `parentageUnknown` block. The category did not empty; it changed shape,
    /// from "no block" to "a block that states an absence", and `lineage == nil`
    /// was only ever a proxy for the thing this test means.
    ///
    /// So the assertion is now the thing itself: **authors no edge**, which is
    /// `lineage?.isEmpty != false` — nil block, or a block `GrapeLineage.isEmpty`
    /// rejects. That is also the exact predicate `GrapeLineageIndex` uses to
    /// decide what goes in `authored`, so the test and the code are reading the
    /// same rule rather than two that happen to agree.
    ///
    /// The subject is derived rather than named, for the reason
    /// `unconnectedGrapesAreEmpty` above gives at length: this half of the suite
    /// pins logic, and a hardcoded id here is what made it rot on a data batch
    /// twice now. `#require` states the premise, so if the category ever *does*
    /// empty the failure says so in words instead of leaving a stale id.
    @Test("a grape with only derived edges still has a tree")
    func derivedOnlyGrapesAreConnected() throws {
        let derivedOnly = try #require(
            grapes().first { db.lineage.hasLineage($0.id) && $0.lineage?.isEmpty != false },
            "no grape is connected only by derived edges — the reverse pass has nothing to prove here"
        )
        let relatives = db.lineage.relatives(of: derivedOnly.id)
        #expect(relatives.parents.isEmpty, "\(derivedOnly.common.name) authors parents after all")
        #expect(relatives.mutationOf == nil)
        #expect(db.lineage.hasLineage(derivedOnly.id))
        #expect(relatives.edgeCount > 0, "\(derivedOnly.common.name) is connected with no edges to show")
        #expect(!relatives.isEmpty)
    }

    /// `related` is symmetric by definition, so the index reverses it.
    ///
    /// **The day this doc comment anticipated arrived in 0.8.2.** It used to say
    /// that both authored `related` refs were off-catalog — Sangiovese's two —
    /// so nothing in the shipped data exercised the reverse pass, and that this
    /// was precisely why a fixture was right. Sommbot's pass authored five
    /// in-catalog ones, and `Marsanne`, `Graciano`, `Hondarrabi Beltza`,
    /// `Zinfandel` and `Primitivo` now draw an edge that appears nowhere in
    /// their own records.
    ///
    /// The fixture stays anyway, and the reason is the general one: a property
    /// pinned only by an example in the catalog is a property that quietly stops
    /// being pinned when a later batch removes the example. That is how
    /// `derivedOnlyGrapesAreConnected` above came to be read as retired.
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

    /// **A mutually authored `related` pair draws one row, not two (0.8.2).**
    ///
    /// `relatives(of:)` builds `related` from two sources — the grape's own refs
    /// and the reverse of everyone who named it — and until 0.8.2 it simply
    /// concatenated them, where `siblings` two lines above had carried a `seen`
    /// set since 0.7.5. Nothing in the shipped data hit it, because sommbot
    /// authors these one direction at a time; but authoring both directions is
    /// the obvious way to write down a relationship the schema itself calls
    /// symmetric, so the trap was one plausible data edit away, and 0.8.2 is the
    /// batch that put the first in-catalog `related` refs in at all.
    ///
    /// Pinned because the failure is not a visible duplicate. `LineageNode.id`
    /// is `"e:X1"` for both copies and `GrapeLineageScreen`'s `ForEach` is keyed
    /// on it, so two rows share one identity — SwiftUI's answer to which is
    /// undefined and in practice is a dropped or doubled row somewhere else in
    /// the list. A reader would have blamed the tree, not the data.
    ///
    /// The authored copy must survive rather than the derived one: it is the
    /// side that carries `role`, which `derived` drops on purpose.
    @Test("a related edge authored from both ends still draws once")
    func relatedIsDeduplicated() {
        let index = GrapeLineageIndex(grapes: [
            Self.fixture(
                id: "X1", name: "Alpha",
                lineage: GrapeLineage(related: [LineageRef(id: "X2", contested: true)])
            ),
            Self.fixture(
                id: "X2", name: "Beta",
                lineage: GrapeLineage(related: [LineageRef(id: "X1")])
            ),
        ])
        for id in ["X1", "X2"] {
            let related = index.relatives(of: id).related
            #expect(related.count == 1, "\(id) draws the same relative twice")
            #expect(Set(related.map(\.id)).count == related.count, "\(id) has two nodes sharing a ForEach key")
        }
        // Authored wins: X1's own ref says contested, the reverse of X2's does
        // not, and X1 is reading its own record.
        #expect(index.relatives(of: "X1").related.first?.contested == true)
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

    // MARK: Unknown parentage (0.7.9, C2)

    /// **The contract C1 was going to have to invent, settled here first.**
    ///
    /// `parents.isEmpty` means "nobody has authored them", and the app has no
    /// way to say "nobody knows". Silence is the honest rendering of the first
    /// and a wrong one for the second. It was written as a fixture because
    /// `shared/` set the flag nowhere — the data arrived in 0.8.2, on 74 grapes
    /// — and it stays a fixture for the reason `relatedIsSymmetric` gives: the
    /// behaviour is a property of the index, not of whichever grapes a batch
    /// happened to reach.
    @Test("an unknown parentage is a stated fact, not an absent one")
    func unknownParentageIsDistinctFromUnauthored() {
        let index = GrapeLineageIndex(grapes: [
            Self.fixture(id: "X1", name: "Stated", lineage: GrapeLineage(parentageUnknown: true)),
            Self.fixture(id: "X2", name: "Silent"),
        ])
        #expect(index.parentageIsUnknown("X1"))
        #expect(!index.parentageIsUnknown("X2"))
        #expect(index.relatives(of: "X1").parentageUnknown)
        #expect(!index.relatives(of: "X2").parentageUnknown)
    }

    /// **It must not manufacture a tree.** A pedigree screen whose only content
    /// is a sentence saying there is no pedigree is worse than the entry screen
    /// staying quiet — which is the argument `EntryDetailScreen.lineageSection`
    /// has carried since 0.7.5.
    @Test("an unknown parentage does not make a grape connected")
    func unknownParentageIsNotAnEdge() {
        let index = GrapeLineageIndex(grapes: [
            Self.fixture(id: "X1", name: "Stated", lineage: GrapeLineage(parentageUnknown: true)),
        ])
        #expect(!index.hasLineage("X1"), "a stated absence is not a relationship")
        #expect(index.relatives(of: "X1").isEmpty)
        #expect(index.relatives(of: "X1").edgeCount == 0)
        #expect(index.connectedIDs.isEmpty)
        // …and it is still reportable, which is the whole point of storing it
        // outside the edge tables.
        #expect(index.parentageIsUnknown("X1"))
    }

    /// The flag rides alongside real edges rather than replacing them: a grape
    /// with one established parent and an unresolved second is the case that
    /// makes this worth having at all.
    @Test("a half-known cross keeps both its edges and its flag")
    func unknownParentageCoexistsWithEdges() {
        let index = GrapeLineageIndex(grapes: [
            Self.fixture(
                id: "X1", name: "Alpha",
                lineage: GrapeLineage(parents: [LineageRef(id: "X2")], parentageUnknown: true)
            ),
            Self.fixture(id: "X2", name: "Beta"),
        ])
        let alpha = index.relatives(of: "X1")
        #expect(alpha.parents.count == 1)
        #expect(alpha.parentageUnknown)
        #expect(index.hasLineage("X1"))
    }

    /// The flag is new, and every entry in the shipped catalog predates it.
    /// A synthesised decoder would treat the missing key as a failure and cost
    /// the whole grape — the migration hazard this repo has hit three times.
    ///
    /// **0.8.2 is when this stopped being hypothetical.** Until this batch the
    /// key appeared in no shipped block, so the catalog proved the *absent*
    /// branch and nothing proved the present one. Now 74 blocks carry it and 89
    /// still do not, in the same file, decoded by the same pass — which is a
    /// better test than either number alone, because it is the mixed corpus a
    /// migration actually meets.
    @Test("a lineage block without the new key still decodes")
    func lineageDecodesWithoutTheNewKey() throws {
        let json = #"{"parents":[{"id":"G002"}],"note":"x"}"#
        let decoded = try JSONDecoder().decode(GrapeLineage.self, from: Data(json.utf8))
        #expect(decoded.parents.count == 1)
        #expect(decoded.parentageUnknown == false)
        // And the shipped catalog is the real proof: 173 blocks decoded
        // (163 + Batch A's ten), of which 90 omit the key entirely and still
        // arrived intact — Fetească Regală is the batch's one addition to
        // that side of the split.
        let blocks = grapes().compactMap(\.lineage)
        #expect(blocks.count == 173)
        #expect(blocks.filter { !$0.parentageUnknown }.count == 90, "blocks predating the key")
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
