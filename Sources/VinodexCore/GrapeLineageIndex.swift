import Foundation

/// One variety hanging off another in a rendered pedigree (0.7.5, E).
///
/// A node is either an **entry** — a grape in this build, which the tree draws
/// as a tappable tile — or **external**, an ancestor the catalog does not carry
/// and which draws as a terminal name. Those two states are the whole reason
/// this is an enum rather than an optional id: an external node is not a failed
/// lookup, and rendering it greyed-and-inert the way `LinkedRow` renders an
/// unresolved name would say "broken" about the single most-pointed-at variety
/// in the dataset (Gouais Blanc, mother of ten grapes here).
public struct LineageNode: Sendable, Hashable, Identifiable {
    public enum Target: Sendable, Hashable {
        /// A grape in this build, by id.
        case entry(String)
        /// A variety the catalog does not carry, by name. Terminal.
        case external(String)
    }

    public let target: Target
    /// What to print. For an entry this is the catalog's own name, resolved at
    /// index time — never the ref, which carries no name at all.
    public let name: String
    /// Seed or pollen parent, where the direction is established. Nil is the
    /// common case and means "a parent", not "unknown parent".
    public let role: LineageRef.Role?
    /// The relationship is real; its direction or one party's identity is not.
    /// **Carried through the reverse pass**, so a contested edge reads as
    /// contested from both ends rather than only from the child that authored it.
    public let contested: Bool
    /// For a derived sibling: the parent the two share. Nil elsewhere.
    ///
    /// Without this a sibling list is a bare pile of names — eleven of them, in
    /// Chardonnay's case — with nothing saying which of two parents put each one
    /// there.
    public let via: String?
    /// The authored footnote from whichever lineage block produced this edge.
    /// Surfaced by the screen, de-duplicated, under the tree.
    public let note: String?

    public init(
        target: Target,
        name: String,
        role: LineageRef.Role? = nil,
        contested: Bool = false,
        via: String? = nil,
        note: String? = nil
    ) {
        self.target = target
        self.name = name
        self.role = role
        self.contested = contested
        self.via = via
        self.note = note
    }

    /// The grape this node opens, or nil if it is terminal.
    public var entryID: String? {
        if case .entry(let id) = target { return id }
        return nil
    }

    /// Whether tapping it goes anywhere.
    public var isNavigable: Bool { entryID != nil }

    /// Unique within one rendered list. `via` is part of it because a grape can
    /// be a sibling twice over — once through each shared parent — and `ForEach`
    /// needs to tell those two rows apart.
    public var id: String {
        let base: String
        switch target {
        case .entry(let entryID): base = "e:\(entryID)"
        case .external(let name): base = "x:\(name)"
        }
        guard let via else { return base }
        return "\(base)@\(via)"
    }
}

/// Everything the catalog knows about one grape's family (0.7.5, E).
///
/// Authored edges point *up* (`parents`, `mutationOf`); derived edges point
/// *down* (`offspring`, `mutations`) or *sideways* (`siblings`, `related`).
public struct GrapeRelatives: Sendable, Hashable {
    /// Authored, in the order written — mother before father where both are known.
    public let parents: [LineageNode]
    /// Authored. The variety this one is a somatic mutation of.
    public let mutationOf: LineageNode?
    /// Derived: grapes naming this one as a parent.
    public let offspring: [LineageNode]
    /// Derived: grapes that are mutations of this one.
    public let mutations: [LineageNode]
    /// Derived: grapes sharing a parent, or sharing the variety this one mutated
    /// from. Each carries the relative it came through in `via`.
    public let siblings: [LineageNode]
    /// Authored `related` refs, plus the reverse of anyone who named this grape
    /// in theirs — see `GrapeLineageIndex` on why the reverse is built even
    /// though today's data has no in-catalog `related` ref to reverse.
    public let related: [LineageNode]
    /// Every authored footnote reachable from this tree, de-duplicated, in the
    /// order encountered. The honest way to render a contested edge: the tree
    /// shows both readings and this says who disagrees.
    public let notes: [String]

    public static let none = GrapeRelatives(
        parents: [], mutationOf: nil, offspring: [],
        mutations: [], siblings: [], related: [], notes: []
    )

    /// No edges in any direction — which is 103 of the 171 grapes, and the
    /// reason the encyclopedia does not offer this screen on every entry.
    public var isEmpty: Bool {
        parents.isEmpty && mutationOf == nil && offspring.isEmpty
            && mutations.isEmpty && siblings.isEmpty && related.isEmpty
    }

    /// How many relatives are drawn, for the entry-screen teaser.
    public var edgeCount: Int {
        parents.count + (mutationOf == nil ? 0 : 1) + offspring.count
            + mutations.count + siblings.count + related.count
    }
}

/// The pedigree graph, built once over the grape list (0.7.5, E).
///
/// **Only the child-facing direction is stored in the data**, which is the
/// decision this type exists to pay for. `shared/data/grapes.ts` authors
/// `parents`, `mutationOf` and `related`; offspring, mutations and siblings are
/// all this one reverse pass. Storing both directions would mean two places to
/// be wrong and an offspring list that rots every time a grape is added — see
/// `GrapeLineage` in `WineEntry.swift`, and the argument in `shared/types.ts`.
///
/// **Edges into the catalog resolve by id and only by id.** A ref carrying a
/// `name` is an off-catalog ancestor by definition, and is never matched against
/// grape names or synonyms on the way back in. That is not laziness: "Espadeiro"
/// answers to five VIVC prime names and "Nerello" to seven, and `Mammolo` is at
/// once an authored external ancestor of Verdicchio *and* a synonym of G168
/// Sciaccarellu — resolving names would silently marry those two.
/// `find-missing-refs.mjs` prints that collision rather than ruling on it, and
/// fails outright if an external name matches a catalog grape's *primary* name,
/// which is the case that really would be a mis-authored id.
///
/// External ancestors do get one job: they are **sibling keys**. Chardonnay and
/// Riesling are half-siblings through Gouais Blanc, a grape that is not in this
/// app and never will be, and losing that would lose the most interesting
/// structure in the dataset. Keys are `id ?? TextNormalize.key(name)`, which is
/// why the canonical spellings in `data-review/FINDINGS.md` are load-bearing:
/// two spellings of one ancestor split its children into two families.
public struct GrapeLineageIndex: Sendable {
    /// id -> display name, for naming the far end of a derived edge.
    private let names: [String: String]
    /// id -> the grape's own authored block.
    private let authored: [String: GrapeLineage]
    /// parent key -> the grapes naming it as a parent, with the ref that did.
    private let childrenOf: [String: [(id: String, ref: LineageRef)]]
    /// source key -> the grapes that are mutations of it.
    private let mutantsOf: [String: [(id: String, ref: LineageRef)]]
    /// grape id -> grapes that named it in their `related`.
    private let relatedBack: [String: [(id: String, ref: LineageRef)]]

    /// Every grape with at least one edge in any direction.
    ///
    /// Computed here rather than by the caller because the answer is what
    /// decides whether the encyclopedia offers this feature on a given entry,
    /// and a screen re-deriving it per render would walk the whole catalog.
    public let connectedIDs: Set<String>

    public init(grapes: [GrapeEntry]) {
        var names: [String: String] = [:]
        var authored: [String: GrapeLineage] = [:]
        var childrenOf: [String: [(id: String, ref: LineageRef)]] = [:]
        var mutantsOf: [String: [(id: String, ref: LineageRef)]] = [:]
        var relatedBack: [String: [(id: String, ref: LineageRef)]] = [:]

        names.reserveCapacity(grapes.count)
        for grape in grapes { names[grape.id] = grape.common.name }

        for grape in grapes {
            guard let lineage = grape.lineage, !lineage.isEmpty else { continue }
            authored[grape.id] = lineage

            for parent in lineage.parents {
                guard let key = Self.key(parent) else { continue }
                childrenOf[key, default: []].append((grape.id, parent))
            }
            if let source = lineage.mutationOf, let key = Self.key(source) {
                mutantsOf[key, default: []].append((grape.id, source))
            }
            // **The reverse of `related`, and it is empty in today's data.**
            // Both authored `related` refs — Sangiovese's two — are off-catalog,
            // so nothing reverses. It is built anyway because `related` means "a
            // first-degree relative of undetermined direction", which is
            // symmetric by definition: the day one of those refs names a catalog
            // grape, that grape's tree would otherwise be missing an edge its
            // partner draws. `GrapeLineageTests.relatedIsSymmetric` builds a
            // fixture that exercises it, so this is not untested code.
            for other in lineage.related {
                guard let id = other.id else { continue }
                relatedBack[id, default: []].append((grape.id, other))
            }
        }

        self.names = names
        self.authored = authored
        self.childrenOf = childrenOf
        self.mutantsOf = mutantsOf
        self.relatedBack = relatedBack

        var connected = Set(authored.keys)
        for (key, kids) in childrenOf {
            if names[key] != nil { connected.insert(key) }
            for kid in kids { connected.insert(kid.id) }
        }
        for (key, mutants) in mutantsOf {
            if names[key] != nil { connected.insert(key) }
            for mutant in mutants { connected.insert(mutant.id) }
        }
        for (key, others) in relatedBack {
            if names[key] != nil { connected.insert(key) }
            for other in others { connected.insert(other.id) }
        }
        self.connectedIDs = connected
    }

    /// `id` where the ref is in-catalog, the folded name where it is not.
    ///
    /// Nil for a ref carrying neither, which the schema forbids and
    /// `find-missing-refs.mjs` fails on — dropped here rather than crashing,
    /// because a malformed edge is worth losing and a screen is not.
    private static func key(_ ref: LineageRef) -> String? {
        if let id = ref.id { return id }
        guard let name = ref.name else { return nil }
        let folded = TextNormalize.key(name)
        return folded.isEmpty ? nil : folded
    }

    /// Whether this grape has anything to show. The gate the encyclopedia asks
    /// before offering the tree at all.
    public func hasLineage(_ id: String) -> Bool {
        connectedIDs.contains(id)
    }

    /// The whole family of one grape.
    ///
    /// Assembled per call rather than cached: the lists are single digits long,
    /// this runs once per navigation into the screen, and a cache would be a
    /// second copy of the answer to keep in step with nothing that changes.
    public func relatives(of id: String) -> GrapeRelatives {
        let lineage = authored[id]

        // Up: authored, in the order written. Mother before father is meaning,
        // not presentation, so this list is never sorted.
        let parents = (lineage?.parents ?? []).compactMap { node(for: $0, note: lineage?.note) }
        let mutationOf = lineage?.mutationOf.flatMap { node(for: $0, note: lineage?.note) }

        // Down: everyone who named this grape by id.
        let offspring = derived(childrenOf[id] ?? [])
        let mutations = derived(mutantsOf[id] ?? [])

        // Sideways: the other children of each of this grape's own parents, and
        // the other mutations of whatever it mutated from. Both go through the
        // same key, which is what lets Gouais Blanc — an ancestor with no entry
        // — still hold eleven half-siblings together.
        var siblings: [LineageNode] = []
        var seenSibling = Set<String>()
        for source in (lineage?.parents ?? []) + (lineage?.mutationOf.map { [$0] } ?? []) {
            guard let key = Self.key(source) else { continue }
            let sourceName = source.id.flatMap { names[$0] } ?? source.name ?? ""
            for candidate in (childrenOf[key] ?? []) + (mutantsOf[key] ?? []) {
                guard candidate.id != id else { continue }
                guard let name = names[candidate.id] else { continue }
                let nodeID = "\(candidate.id)@\(sourceName)"
                guard seenSibling.insert(nodeID).inserted else { continue }
                siblings.append(
                    LineageNode(
                        target: .entry(candidate.id),
                        name: name,
                        contested: candidate.ref.contested || source.contested,
                        via: sourceName.isEmpty ? nil : sourceName,
                        note: authored[candidate.id]?.note
                    )
                )
            }
        }
        siblings.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        var related = (lineage?.related ?? []).compactMap { node(for: $0, note: lineage?.note) }
        related += derived(relatedBack[id] ?? [])

        // **Collected from the nodes rather than alongside them.** Every node
        // already carries the note of the block that produced it, so gathering
        // them at the end is one ordered de-dupe instead of six call sites
        // remembering to append — and it cannot fall out of step with what the
        // tree actually drew, which is the failure mode a parallel list has.
        var notes: [String] = []
        let noteSources =
            [lineage?.note] + (parents + [mutationOf].compactMap { $0 } + offspring
                + mutations + siblings + related).map(\.note)
        for note in noteSources.compactMap({ $0 }) where !note.isEmpty {
            if !notes.contains(note) { notes.append(note) }
        }

        return GrapeRelatives(
            parents: parents,
            mutationOf: mutationOf,
            offspring: offspring,
            mutations: mutations,
            siblings: siblings,
            related: related,
            notes: notes
        )
    }

    /// One authored ref as a node. Nil only for a ref the schema forbids.
    private func node(for ref: LineageRef, note: String?) -> LineageNode? {
        if let id = ref.id {
            guard let name = names[id] else { return nil }
            return LineageNode(
                target: .entry(id), name: name,
                role: ref.role, contested: ref.contested, note: note
            )
        }
        guard let name = ref.name, !name.isEmpty else { return nil }
        return LineageNode(
            target: .external(name), name: name,
            role: ref.role, contested: ref.contested, note: note
        )
    }

    /// The far end of a reversed edge: always a catalog grape, because only a
    /// catalog grape can author a lineage block in the first place. Alphabetical
    /// — a derived list has no authored order to preserve.
    private func derived(_ edges: [(id: String, ref: LineageRef)]) -> [LineageNode] {
        var out: [LineageNode] = []
        for edge in edges {
            guard let name = names[edge.id] else { continue }
            let note = authored[edge.id]?.note
            out.append(
                LineageNode(
                    target: .entry(edge.id),
                    name: name,
                    // Role is the *child's* statement about its own parent and
                    // says nothing about the child, so it is dropped rather than
                    // reflected: an offspring is not the "mother" of anything.
                    contested: edge.ref.contested,
                    note: note
                )
            )
        }
        out.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return out
    }
}
