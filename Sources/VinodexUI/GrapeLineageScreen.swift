#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// One grape's pedigree, drawn as a family tree (0.7.5, E1).
///
/// **The shape of the screen is a consequence of the shape of the data**, and
/// three facts about it decided everything here:
///
/// 1. **Coverage is 42%.** 102 of 177 grapes have no relatives at all, so the
///    tree is not offered on those entries — see `EntryDetailScreen`, which
///    draws the LINEAGE section only when `WineDatabase.lineage.hasLineage`
///    says there is something to draw. A screen that opened onto an empty box
///    for three grapes in five would teach people not to tap it.
/// 2. **Half the ancestors are not in the catalog.** Magdeleine Noire des
///    Charentes fathers Merlot and Malbec and will never be an entry, because
///    nobody drinks it. Those nodes have to read as *terminal* — a real variety,
///    named, with nothing behind it — rather than as a broken link.
///    `LineageTile` draws them on the well rather than on a surface, with no
///    chevron and no press behaviour, which is the same vocabulary the app
///    already uses for "this is information, not a door". (Gouais Blanc was this
///    paragraph's example through 0.7.8 and became G176 in 0.7.9's data batch,
///    which is a useful reminder that the two kinds of node are a property of
///    the *catalog*, not of the variety.)
/// 3. **Some edges are disputed.** Listán Negro's second parent is Palomino by
///    VIVC and Listán Prieto by later Canary work, and the data says so rather
///    than picking. A contested edge draws a dashed connector and a `?` badge,
///    and its authored sentence lands in the footnotes at the bottom. The tree
///    never resolves an argument the catalog has not resolved.
///
/// **The tree is a column, not a canvas.** The LCD is roughly 2.5 inches wide
/// and a pan-and-zoom graph on it would be a worse version of a list. What is
/// drawn instead is the one thing a graph gives that a list cannot: *direction*.
/// Parents sit above the subject with lines running down into it, descendants
/// sit below with lines running out of it, and everything sideways — half-
/// siblings, unresolved relatives — is a labelled section underneath. That reads
/// as a pedigree at a glance and needs no gestures at all.
///
/// Everything is `lcd.*`, so it survives the nine screen modes and the
/// monochrome pass; the connectors are `accent` at low opacity, which is ink in
/// VINTAGE and phosphor in the four single-colour modes.
///
/// ---
///
/// **0.7.9 (C2) enlarges the nodes and stops the biggest tree from running off
/// the bottom.** Three changes, and the third is the one with an argument in it:
///
/// - `LineageTile` grows from 96pt to `Self.tileWidth`, with the art well and
///   the name up a step each. At 96 with a 30pt well the tiles were smaller than
///   the entry rows directly beneath them, which read as the tree being the
///   lesser half of the screen when it is the reason to open it.
/// - Every tier is **capped** at `Self.tierLimit` with a SHOW ALL control, on
///   the pattern HALF-SIBLINGS has used since 0.7.5. This is what makes the
///   enlargement affordable, and it is not hypothetical: Gouais Blanc arrived as
///   G176 in 0.7.9's data batch and is named as a parent by **ten** catalog
///   grapes, so its OFFSPRING tier is the largest node set in the app. At the
///   new tile width that is four rows of unlabelled squares before the footnotes
///   — a wall rather than a pedigree.
/// - **Unknown parentage has a visual state** — `LineageNode.Target.unrecorded`,
///   drawn as a dashed, unfilled tile with a slash glyph in the PARENTS slot. It
///   is the third kind of node and it is deliberately unlike the other two: an
///   external ancestor is a *name* with nothing behind it, this is not even a
///   name. Nothing in `shared/` sets it yet; sommbot's C1 pass is what fills it
///   in, against a UI that already renders it.
public struct GrapeLineageScreen: View {
    let grape: GrapeEntry
    let onSelectRelated: (WineEntry) -> Void

    private let db = WineDatabase.shared
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    /// Scroll position outlives the view — see `ScreenStateStore`.
    @State private var screens = ScreenStateStore.shared
    /// Which sibling group is expanded. Chardonnay has eleven half-siblings and
    /// the first three are the interesting ones.
    @State private var showingAllSiblings = false
    /// Which tiers of the tree are expanded past `tierLimit` (0.7.9, C2).
    /// Keyed by caption, because the two tiers are drawn by one function and a
    /// single flag would open both.
    @State private var expandedTiers: Set<String> = []

    /// How wide one node is. 96 through 0.7.8, which put the tree's tiles below
    /// the size of the plain rows underneath them. Read by `LineageTile`, which
    /// is the only other type that draws one.
    static let tileWidth: CGFloat = 116

    /// The gap between two tiles in a tier. Named because `Connector` repeats
    /// the tier's packing arithmetic to find the tiles it must reach, and a
    /// second literal 6 is exactly how the crossbar came to be drawn to a tile
    /// size that no longer existed (0.8.1, C3).
    static let tierSpacing: CGFloat = 6
    /// How many nodes a tier draws before it offers SHOW ALL.
    ///
    /// Six is two full rows at `tileWidth` on the narrowest LCD and one row shy
    /// of Pinot Noir's nine descendants, which is the tree the 0.7.5 note calls
    /// out as the reason `FlowLayout` exists. Gouais Blanc's ten offspring —
    /// the largest set in the catalog since 0.7.9 — collapse to six and a
    /// button rather than four rows of tiles.
    private static let tierLimit = 6

    public init(grape: GrapeEntry, onSelectRelated: @escaping (WineEntry) -> Void) {
        self.grape = grape
        self.onSelectRelated = onSelectRelated
    }

    private var relatives: GrapeRelatives { db.lineage.relatives(of: grape.id) }

    private var screenKey: String { ScreenStateStore.lineage(grape.id) }

    private enum Anchor {
        static let tree = "tree"
        static let siblings = "siblings"
        static let related = "related"
        static let notes = "notes"
    }

    private var anchorBinding: Binding<String?> {
        Binding(
            get: { screens.anchor(for: screenKey) },
            set: { screens.setAnchor($0, for: screenKey) }
        )
    }

    public var body: some View {
        let family = relatives
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                treeSection(family).id(Anchor.tree)
                siblingsSection(family).id(Anchor.siblings)
                relatedSection(family).id(Anchor.related)
                notesSection(family).id(Anchor.notes)
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 14, for: .scrollContent)
        .contentMargins(.bottom, 72, for: .scrollContent)
        .scrollPosition(id: anchorBinding)
        .background(lcd.page)
    }

    // MARK: The tree

    /// Ancestors, the subject, descendants — top to bottom, joined by rails.
    ///
    /// Each half draws only if it has something in it, and the connector between
    /// a half and the subject belongs to that half: an only-child with two
    /// parents gets one rail above and none below, rather than a stub pointing
    /// at nothing.
    @ViewBuilder
    private func treeSection(_ family: GrapeRelatives) -> some View {
        // **The unknown-parentage node stands where a parent would** (0.7.9,
        // C2), and only where one is actually missing: a grape with both
        // parents authored and the flag set is a data contradiction, and
        // appending a third tile to a settled cross would render the
        // contradiction as fact. Two authored ancestors is enough of a claim.
        let authoredAncestors = family.parents + (family.mutationOf.map { [$0] } ?? [])
        let ancestors = family.parentageUnknown && authoredAncestors.count < 2
            ? authoredAncestors + [LineageNode.unrecordedParent]
            : authoredAncestors
        let descendants = family.offspring + family.mutations

        section("FAMILY TREE", symbol: "arrow.triangle.branch") {
            VStack(spacing: 0) {
                if !ancestors.isEmpty {
                    tier(
                        ancestors,
                        caption: family.mutationOf == nil
                            ? "PARENTS"
                            : (family.parents.isEmpty ? "MUTATION OF" : "PARENTS + SOURCE"),
                        trunkBelow: true
                    )
                    Connector(
                        count: ancestors.count,
                        contested: ancestors.contains { $0.contested },
                        tint: lcd.accent,
                        touchesFirstRow: false
                    )
                    .frame(height: 26)
                    .padding(.horizontal, 10)
                }

                subjectTile

                if !descendants.isEmpty {
                    Connector(
                        count: descendants.count,
                        contested: descendants.contains { $0.contested },
                        tint: lcd.accent,
                        touchesFirstRow: true
                    )
                    .frame(height: 26)
                    .padding(.horizontal, 10)
                    .scaleEffect(y: -1)
                    tier(
                        descendants,
                        caption: family.mutations.isEmpty
                            ? "OFFSPRING"
                            : (family.offspring.isEmpty ? "MUTATIONS" : "OFFSPRING + MUTATIONS"),
                        trunkBelow: false
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(lcd.surface)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(lcd.surfaceEdge, lineWidth: 1))
        }
    }

    /// One horizontal rank of the tree, wrapping when it has to.
    ///
    /// `FlowLayout` rather than an `HStack`: Pinot Noir has nine descendants and
    /// a fixed row would either shrink them past legibility or push a horizontal
    /// scroll onto a screen that already scrolls vertically.
    ///
    /// **Capped at `tierLimit` since 0.7.9 (C2).** `FlowLayout` solved the
    /// *width* problem and left the height one: ten tiles at 116pt is four rows,
    /// which pushes the subject tile — the grape you are standing on — off the
    /// bottom of the LCD on the very trees that are worth looking at. The
    /// overflow is a button rather than a scroll, matching HALF-SIBLINGS below.
    ///
    /// **The caption and the SHOW ALL button moved to the far side of the tiles
    /// (0.8.1, C3).** They used to sit between the tiles and the trunk — the
    /// caption on the offspring side, the button on the parents side — so the
    /// connector's legs ended on the tier's edge with 12 to 38pt of chrome
    /// between them and the box they were pointing at. That, more than the
    /// crossbar's width, is why the lines did not meet anything: they were
    /// meeting the right coordinate of the wrong view. Tiles nearest the trunk
    /// and labels on the outside is also how a family tree is drawn.
    @ViewBuilder
    private func tier(_ nodes: [LineageNode], caption: String, trunkBelow: Bool) -> some View {
        let expanded = expandedTiers.contains(caption)
        let shown = expanded ? nodes : Array(nodes.prefix(Self.tierLimit))

        let label = Text(caption)
            .font(DexFont.retro(9))
            .tracking(1.5)
            .foregroundStyle(lcd.subtext)
        let tiles = FlowLayout(spacing: Self.tierSpacing, alignment: .center) {
            ForEach(shown) { node in
                LineageTile(node: node, isSubject: false) { open(node) }
            }
        }
        .frame(maxWidth: .infinity)

        VStack(spacing: 8) {
            if trunkBelow {
                label
                overflowButton(nodes, caption: caption, expanded: expanded)
                tiles
            } else {
                tiles
                overflowButton(nodes, caption: caption, expanded: expanded)
                label
            }
        }
        .padding(.horizontal, 10)
    }

    /// SHOW ALL / SHOW FEWER, or nothing when the tier fits.
    @ViewBuilder
    private func overflowButton(_ nodes: [LineageNode], caption: String, expanded: Bool) -> some View {
        Group {
            if nodes.count > Self.tierLimit {
                Button {
                    Haptics.select()
                    withAnimation(DexMotion.settle) {
                        if expanded { expandedTiers.remove(caption) }
                        else { expandedTiers.insert(caption) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                        Text(expanded ? "SHOW FEWER" : "SHOW ALL \(nodes.count)")
                            .font(DexFont.retro(9))
                            .tracking(1)
                    }
                    .foregroundStyle(lcd.accent)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Capsule().fill(lcd.well))
                    .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 1))
                }
                .buttonStyle(DexPressStyle(scale: 0.97))
            }
        }
    }

    /// The grape you are standing on, drawn as the one node that is not a link.
    private var subjectTile: some View {
        LineageTile(
            node: LineageNode(target: .entry(grape.id), name: grape.common.name),
            isSubject: true,
            action: {}
        )
        .padding(.horizontal, 10)
    }

    // MARK: Sideways

    /// Half-siblings, grouped by the relative they came through.
    ///
    /// The grouping is the point. Chardonnay's eleven siblings are nine children
    /// of Gouais Blanc and two more of Pinot Noir, and a flat list of eleven
    /// names says none of that — it reads as "eleven grapes, somehow".
    @ViewBuilder
    private func siblingsSection(_ family: GrapeRelatives) -> some View {
        if !family.siblings.isEmpty {
            let groups = Self.grouped(family.siblings)
            section("HALF-SIBLINGS", symbol: "person.2.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(groups, id: \.via) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("THROUGH \(group.via.uppercased())")
                                .font(DexFont.retro(8))
                                .tracking(1.2)
                                .foregroundStyle(lcd.subtext)
                            ForEach(showingAllSiblings ? group.members : Array(group.members.prefix(3))) { node in
                                lineageRow(node)
                            }
                        }
                    }
                    if family.siblings.count > 3 {
                        expandButton(total: family.siblings.count)
                    }
                }
            }
        }
    }

    /// Siblings bucketed by the relative they came through.
    ///
    /// Grouped in insertion order rather than alphabetically, so the buckets
    /// follow the parent order the tree above already drew — reading down the
    /// screen, Gouais Blanc's children come under Gouais Blanc.
    private struct SiblingGroup {
        let via: String
        var members: [LineageNode]
    }

    private static func grouped(_ nodes: [LineageNode]) -> [SiblingGroup] {
        var groups: [SiblingGroup] = []
        for node in nodes {
            // Only a malformed ref can lose its `via`, and a bucket with an
            // honest name beats dropping the node.
            let key = node.via ?? "SHARED ANCESTRY"
            if let index = groups.firstIndex(where: { $0.via == key }) {
                groups[index].members.append(node)
            } else {
                groups.append(SiblingGroup(via: key, members: [node]))
            }
        }
        return groups
    }

    private func expandButton(total: Int) -> some View {
        Button {
            Haptics.select()
            withAnimation(DexMotion.settle) { showingAllSiblings.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: showingAllSiblings ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                Text(showingAllSiblings ? "SHOW FEWER" : "SHOW ALL (\(total))")
                    .font(DexFont.retro(10))
                    .tracking(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(lcd.accent)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(lcd.well))
            .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 2))
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
    }

    /// First-degree relatives whose direction the markers do not settle.
    @ViewBuilder
    private func relatedSection(_ family: GrapeRelatives) -> some View {
        if !family.related.isEmpty {
            section("RELATED", symbol: "link") {
                VStack(spacing: 8) {
                    ForEach(family.related) { node in
                        lineageRow(node)
                    }
                }
            }
        }
    }

    /// **Where a contested edge is explained rather than hidden.**
    ///
    /// The tree can only draw that two readings exist; the sentence saying who
    /// disagrees, and about what, comes from the data. Every note reachable from
    /// this tree lands here, de-duplicated by `GrapeLineageIndex`.
    @ViewBuilder
    private func notesSection(_ family: GrapeRelatives) -> some View {
        if !family.notes.isEmpty {
            section("ON THE RECORD", symbol: "text.quote") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(family.notes, id: \.self) { note in
                        Text(note)
                            .font(DexFont.mono(19))
                            .foregroundStyle(lcd.bodyText)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 12)
                            .padding(.vertical, 8)
                            .background(alignment: .leading) { lcd.accent.frame(width: 3) }
                            .background(lcd.accent.opacity(0.06))
                    }
                }
            }
        }
    }

    // MARK: Rows and plumbing

    /// A sideways relative, as a full-width row — the shape `LinkedRow` gives
    /// every other related-entry list in the app, plus this feature's two
    /// annotations.
    @ViewBuilder
    private func lineageRow(_ node: LineageNode) -> some View {
        let entry = node.entryID.flatMap { db.entry(id: $0) }
        HStack(spacing: 8) {
            LinkedRow(
                title: node.name,
                entry: entry,
                fallbackColor: Dex.stone800,
                // An off-catalog relative is *not* an unresolved cross-link, and
                // must not be greyed like one — but it is also not tappable, so
                // it is passed as unresolved and given its own marker beside it.
                resolved: entry != nil
            ) {
                if let entry {
                    Haptics.select()
                    onSelectRelated(entry)
                }
            }
            if node.contested {
                ContestedBadge(tint: lcd.accent)
            }
        }
    }

    private func open(_ node: LineageNode) {
        guard let id = node.entryID, let entry = db.entry(id: id), id != grape.id else { return }
        Haptics.select()
        onSelectRelated(entry)
    }

    /// The section chrome the detail screen uses, so the two read as one app.
    private func section<C: View>(
        _ title: String,
        symbol: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(lcd.accent)
                Text(title)
                    .font(DexFont.retro(10))
                    .tracking(1.5)
                    .foregroundStyle(lcd.accent)
                Spacer()
            }
            .padding(.bottom, 5)
            .overlay(alignment: .bottom) {
                Color(dexHex: "#166534").frame(height: 2)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }
}

// MARK: - Tiles

/// One node in the tree.
///
/// **Four states since 0.7.9 (C2)**, and the difference between them is the
/// whole design:
///
/// - **The subject** — the grape you are on. Accent border, no press behaviour,
///   because tapping where you already are is not navigation.
/// - **An entry** — a grape in this build. Surface fill, art well, pressable.
/// - **External** — an ancestor the catalog does not carry. Drawn on the *well*
///   with a dashed border and no glyph: legible, obviously a different kind of
///   thing, and obviously not a door. Dashes rather than grey, because grey is
///   `disabledText` and this is not disabled — it is simply the end of what the
///   catalog knows.
/// - **Unrecorded** — no variety at all: the data states the parentage is
///   undetermined. It keeps the external node's dashes and gives up everything
///   else — no name, a slash glyph, and `subtext` throughout — because the two
///   have to be distinguishable at a glance. An external node says *this grape,
///   which we cannot show you*; this one says *nobody knows*.
///
/// Sizes are up a step across the board (0.7.9, C2): `tileWidth` from 96, the
/// well from 30/34 to 40/46, the name from 8/9 to 9/11. At the old size a node
/// in the tree was smaller than a plain related-entry row on the same screen.
struct LineageTile: View {
    let node: LineageNode
    let isSubject: Bool
    let action: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    /// The catalog entry behind this node, subject or not — external and
    /// unrecorded nodes have none, which are the cases that draw no art.
    private var entry: WineEntry? {
        guard let id = node.entryID else { return nil }
        return WineDatabase.shared.entry(id: id)
    }

    /// Filled like a part of the tree, or sunk into the well behind it.
    private var isSolid: Bool { node.isNavigable || isSubject }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                if let entry {
                    EntryIconWell(entry: entry, size: isSubject ? 46 : 40, cornerRadius: isSubject ? 8 : 6)
                } else if node.isUnrecorded {
                    // Where the art well would be. A slashed circle rather than
                    // a question mark: `ContestedBadge` already owns the
                    // question mark and means something else by it — "two
                    // sources disagree", not "there is no source".
                    Image(systemName: "circle.slash")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(lcd.subtext.opacity(0.7))
                        .frame(height: 40)
                } else {
                    // **The off-catalog node is a box too (0.8.1, C1).** This
                    // branch did not exist, so a parent named but not in the
                    // dex — Magdeleine Noire des Charentes, Gouais Blanc's
                    // partners — collapsed to a 116pt strip the height of its
                    // own label and sat in a row of 90pt tiles looking like
                    // stray text rather than a node.
                    //
                    // Same shape as `unrecorded`, different mark, which is the
                    // distinction the 0.8.0 log draws: `circle.slash` means
                    // research says nobody knows, and this means the grape is
                    // real and simply has no page here. A dashed square is the
                    // app's existing vocabulary for "a picture that is not
                    // there" — it is what `DexIcon` falls back to — so the tile
                    // says *absent from the catalog* rather than *absent*.
                    Image(systemName: "square.dashed")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(lcd.subtext.opacity(0.7))
                        .frame(height: 40)
                }
                Text(node.isUnrecorded
                     ? "PARENTAGE\nUNRECORDED"
                     : EntryDisplay.hyphenated(node.name.uppercased()))
                    .font(DexFont.retro(isSubject ? 11 : 9))
                    .tracking(0.5)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(isSubject ? lcd.text : (node.isNavigable ? lcd.text : lcd.subtext))
                if let role = node.role {
                    Text(role == .mother ? "SEED" : "POLLEN")
                        .font(DexFont.retro(8))
                        .tracking(1)
                        .foregroundStyle(lcd.subtext)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(width: GrapeLineageScreen.tileWidth)
            .background(isSolid ? lcd.surface : lcd.well)
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        isSubject ? lcd.accent : lcd.surfaceEdge,
                        style: StrokeStyle(
                            lineWidth: isSubject ? 3 : 2,
                            // The one visual that says "not in the catalog" —
                            // and, for an unrecorded node, "not anything".
                            dash: isSolid ? [] : [4, 3]
                        )
                    )
            }
            .overlay(alignment: .topTrailing) {
                if node.contested {
                    ContestedBadge(tint: lcd.accent)
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(DexPressStyle(scale: 0.96))
        .disabled(isSubject || !node.isNavigable)
        .accessibilityLabel(
            node.isUnrecorded ? "Parentage unrecorded" : node.name
        )
    }
}

/// The marker on a disputed edge.
///
/// A question mark rather than a warning triangle: nothing here is *wrong*, and
/// a hazard glyph over a wine grape's parentage would say the data is broken
/// when what it actually says is that two sources disagree. Tapping it goes
/// nowhere; the sentence is in ON THE RECORD at the bottom of the screen, which
/// is the only place there is room for it.
struct ContestedBadge: View {
    let tint: Color

    var body: some View {
        Image(systemName: "questionmark.circle.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(tint)
            .accessibilityLabel("Contested relationship")
    }
}

/// The rails joining one rank of the tree to the subject below it.
///
/// Drawn rather than assembled from views: a fan of `n` stems into one trunk is
/// a path, and expressing it as nested stacks would mean spacer arithmetic that
/// has to agree with `FlowLayout`'s. `Canvas` also costs one draw call at any
/// width, which matters on a view that redraws with the scroll.
///
/// The dashed variant is the contested one, matching `LineageTile`'s border, so
/// a disputed edge looks disputed from the line as well as from the badge.
struct Connector: View {
    let count: Int
    let contested: Bool
    let tint: Color

    /// True when the row this connector touches is the tier's *first* row —
    /// the offspring case, where the trunk arrives from above.
    var touchesFirstRow: Bool

    /// The centres of the tiles this connector actually has to reach, in the
    /// connector's own coordinates (0.8.1, C3).
    ///
    /// **The old span was `min(width * 0.5, count * 46) / 2` and 46 was a
    /// number about nothing** — near half of the 96pt tile 0.8.0 replaced with
    /// a 116pt one, so the crossbar had been drawn to the previous tile size
    /// for a release, and to a guess before that. The comment beside it said
    /// the tiles' true centres were "a layout answer this view does not have",
    /// which was fair while `FlowLayout` left-packed into a full-width bounds:
    /// a row of two sat at the left and the trunk came down the middle.
    ///
    /// Both halves of that are now false. The tier centres its rows, and the
    /// packing rule is arithmetic this view can repeat exactly — same tile
    /// width, same spacing, same available width, because the connector is
    /// inside the tier and inherits its padding. So the legs go to the tiles
    /// rather than towards them.
    private func centres(in width: CGFloat) -> [CGFloat] {
        let step = GrapeLineageScreen.tileWidth + GrapeLineageScreen.tierSpacing
        let perRow = max(1, Int((width + GrapeLineageScreen.tierSpacing) / step))
        let rows = max(1, Int(ceil(Double(count) / Double(perRow))))
        // Parents hang off the tier's last row, offspring off its first.
        let onRow = touchesFirstRow
            ? min(count, perRow)
            : count - (rows - 1) * perRow
        let mid = width / 2
        return (0..<max(onRow, 1)).map { i in
            mid + (CGFloat(i) - CGFloat(max(onRow, 1) - 1) / 2) * step
        }
    }

    var body: some View {
        Canvas { context, size in
            let mid = size.width / 2
            // Half height, not 0.45 of it: the offspring side draws this same
            // view through `.scaleEffect(y: -1)`, and an off-centre stem made
            // the two sides of one tree meet their trunks at different heights.
            let stemY = size.height / 2
            let tiles = centres(in: size.width)
            var path = Path()
            // The trunk into the subject.
            path.move(to: CGPoint(x: mid, y: stemY))
            path.addLine(to: CGPoint(x: mid, y: size.height))
            if let first = tiles.first, let last = tiles.last, tiles.count > 1 {
                path.move(to: CGPoint(x: first, y: stemY))
                path.addLine(to: CGPoint(x: last, y: stemY))
                // A leg per tile, including the ones between the ends — three
                // parents used to get a crossbar with the middle one hanging
                // off nothing.
                for x in tiles {
                    path.move(to: CGPoint(x: x, y: stemY))
                    path.addLine(to: CGPoint(x: x, y: 0))
                }
            } else {
                let x = tiles.first ?? mid
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: stemY))
                if x != mid {
                    path.move(to: CGPoint(x: x, y: stemY))
                    path.addLine(to: CGPoint(x: mid, y: stemY))
                }
            }
            context.stroke(
                path,
                with: .color(tint.opacity(0.75)),
                style: StrokeStyle(lineWidth: 2, dash: contested ? [4, 3] : [])
            )
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
#endif
