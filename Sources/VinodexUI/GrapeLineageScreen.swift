#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// One grape's pedigree, drawn as a family tree (0.7.5, E1).
///
/// **The shape of the screen is a consequence of the shape of the data**, and
/// three facts about it decided everything here:
///
/// 1. **Coverage is 40%.** 103 of 171 grapes have no relatives at all, so the
///    tree is not offered on those entries — see `EntryDetailScreen`, which
///    draws the LINEAGE section only when `WineDatabase.lineage.hasLineage`
///    says there is something to draw. A screen that opened onto an empty box
///    for three grapes in five would teach people not to tap it.
/// 2. **Half the ancestors are not in the catalog.** Gouais Blanc is the mother
///    of ten grapes here and will never be an entry. Those nodes have to read as
///    *terminal* — a real variety, named, with nothing behind it — rather than
///    as a broken link. `LineageTile` draws them on the well rather than on a
///    surface, with no chevron and no press behaviour, which is the same
///    vocabulary the app already uses for "this is information, not a door".
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
        let ancestors = family.parents + (family.mutationOf.map { [$0] } ?? [])
        let descendants = family.offspring + family.mutations

        section("FAMILY TREE", symbol: "arrow.triangle.branch") {
            VStack(spacing: 0) {
                if !ancestors.isEmpty {
                    tier(
                        ancestors,
                        caption: family.mutationOf == nil
                            ? "PARENTS"
                            : (family.parents.isEmpty ? "MUTATION OF" : "PARENTS + SOURCE")
                    )
                    Connector(
                        count: ancestors.count,
                        contested: ancestors.contains { $0.contested },
                        tint: lcd.accent
                    )
                    .frame(height: 26)
                }

                subjectTile

                if !descendants.isEmpty {
                    Connector(
                        count: descendants.count,
                        contested: descendants.contains { $0.contested },
                        tint: lcd.accent
                    )
                    .frame(height: 26)
                    .scaleEffect(y: -1)
                    tier(
                        descendants,
                        caption: family.mutations.isEmpty
                            ? "OFFSPRING"
                            : (family.offspring.isEmpty ? "MUTATIONS" : "OFFSPRING + MUTATIONS")
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
    private func tier(_ nodes: [LineageNode], caption: String) -> some View {
        VStack(spacing: 8) {
            Text(caption)
                .font(DexFont.retro(8))
                .tracking(1.5)
                .foregroundStyle(lcd.subtext)
            FlowLayout(spacing: 6) {
                ForEach(nodes) { node in
                    LineageTile(node: node, isSubject: false) { open(node) }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
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
/// Three states, and the difference between them is the whole design:
///
/// - **The subject** — the grape you are on. Accent border, no press behaviour,
///   because tapping where you already are is not navigation.
/// - **An entry** — a grape in this build. Surface fill, art well, pressable.
/// - **External** — an ancestor the catalog does not carry. Drawn on the *well*
///   with a dashed border and no glyph: legible, obviously a different kind of
///   thing, and obviously not a door. Dashes rather than grey, because grey is
///   `disabledText` and this is not disabled — it is simply the end of what the
///   catalog knows.
struct LineageTile: View {
    let node: LineageNode
    let isSubject: Bool
    let action: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    /// The catalog entry behind this node, subject or not — an external node has
    /// none, which is the only case that draws no art.
    private var entry: WineEntry? {
        guard let id = node.entryID else { return nil }
        return WineDatabase.shared.entry(id: id)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                if let entry {
                    EntryIconWell(entry: entry, size: isSubject ? 34 : 30, cornerRadius: isSubject ? 6 : 5)
                }
                Text(EntryDisplay.hyphenated(node.name.uppercased()))
                    .font(DexFont.retro(isSubject ? 9 : 8))
                    .tracking(0.5)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(isSubject ? lcd.text : (node.isNavigable ? lcd.text : lcd.subtext))
                if let role = node.role {
                    Text(role == .mother ? "SEED" : "POLLEN")
                        .font(DexFont.retro(7))
                        .tracking(1)
                        .foregroundStyle(lcd.subtext)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(width: 96)
            .background(node.isNavigable || isSubject ? lcd.surface : lcd.well)
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        isSubject ? lcd.accent : lcd.surfaceEdge,
                        style: StrokeStyle(
                            lineWidth: isSubject ? 3 : 2,
                            // The one visual that says "not in the catalog".
                            dash: node.isNavigable || isSubject ? [] : [4, 3]
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

    var body: some View {
        Canvas { context, size in
            let mid = size.width / 2
            let stemY = size.height * 0.45
            var path = Path()
            // The trunk into the subject.
            path.move(to: CGPoint(x: mid, y: stemY))
            path.addLine(to: CGPoint(x: mid, y: size.height))
            if count > 1 {
                // A crossbar wide enough to read as a fan without pretending to
                // reach each tile — the tiles wrap, so their true centres are a
                // layout answer this view does not have and should not guess.
                let span = min(size.width * 0.5, CGFloat(count) * 46) / 2
                path.move(to: CGPoint(x: mid - span, y: stemY))
                path.addLine(to: CGPoint(x: mid + span, y: stemY))
                path.move(to: CGPoint(x: mid - span, y: stemY))
                path.addLine(to: CGPoint(x: mid - span, y: 0))
                path.move(to: CGPoint(x: mid + span, y: stemY))
                path.addLine(to: CGPoint(x: mid + span, y: 0))
            } else {
                path.move(to: CGPoint(x: mid, y: 0))
                path.addLine(to: CGPoint(x: mid, y: stemY))
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
