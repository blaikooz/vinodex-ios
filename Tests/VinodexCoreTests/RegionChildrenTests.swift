import Testing
import Foundation
@testable import VinodexCore

/// The second index plane, and the cell convention that decides who a tap
/// belongs to.
///
/// Both come from the 13 Sep drop. The convention was never written down until
/// then, and the app and the renderer had quietly disagreed about it: the
/// rasteriser fills cell `i` from `[i, i+1)`, while the hit test rounded. On a
/// 464-cell Rhône that never shows. On a five-cell Sauternes it decides the
/// answer.
@Suite("Region children")
struct RegionChildrenTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func map(_ key: String) throws -> RegionMap {
        let dir = Self.root.appendingPathComponent("Sources/VinodexUI/Resources/Maps/\(key)")
        return try RegionMap(
            manifest: Data(contentsOf: dir.appendingPathComponent("\(key)-manifest.json")),
            index: Data(contentsOf: dir.appendingPathComponent("\(key)-region-index.json"))
        )
    }

    /// France is the only country with a second plane, and that is the point of
    /// the design: opt-in per country is what keeps the other thirty-eight
    /// byte-identical. If a second country grows one, this fails and somebody
    /// decides deliberately rather than discovering it later.
    @Test("only France ships children, and it ships exactly two")
    func onlyFrance() throws {
        let france = try map("france")
        #expect(france.hasChildren)
        #expect(france.childrenByIndex.count == 2)

        for key in ["italy", "spain", "portugal", "argentina", "chile",
                    "newzealand", "austria", "china", "usa", "germany"] {
            #expect(!(try map(key).hasChildren), "\(key) grew a second plane unannounced")
        }
    }

    /// Each child names a parent that exists as a painted area, and carries a
    /// plane-2 byte no sibling shares. A child pointing at a parent that is not
    /// there would resolve to a region the map cannot draw.
    @Test("every child sits inside a real parent, under its own byte")
    func childrenAreWellFormed() throws {
        let france = try map("france")
        let areas = Set(france.regions.map(\.id))

        for (byte, child) in france.childrenByIndex {
            #expect(byte == child.index)
            #expect(byte > 0, "0 is reserved for 'no child here'")
            #expect(areas.contains(child.parent),
                    "\(child.stem) claims parent \(child.parent), which is not a painted area")
            #expect(!areas.contains(child.stem),
                    "\(child.stem) is both a child and an area of its own")
        }
        #expect(Set(france.childrenByIndex.values.map(\.stem)).count == 2)
    }

    /// The two the drop shipped, named. These are the pair the whole second
    /// plane exists for: a sub-AOC inside the Gironde and a commune inside the
    /// Southern Rhône, neither of which any admin unit isolates.
    @Test("Sauternes and Châteauneuf, in their right parents")
    func theTwo() throws {
        let france = try map("france")
        let byStem = Dictionary(
            uniqueKeysWithValues: france.childrenByIndex.values.map { ($0.stem, $0) }
        )
        #expect(byStem["sauternes"]?.parent == "bordeaux")
        #expect(byStem["chateauneuf"]?.parent == "rhone")
    }

    /// **The convention, stated as arithmetic.**
    ///
    /// The manifest's `cell_note` is explicit: the cell containing a point is
    /// `floor(x)`, because the rasteriser fills cell `i` from `[i, i+1)`.
    /// Rounding picks the nearest cell *centre* and lands one over for anything
    /// past halfway. This pins the rule the hit test now follows.
    @Test("a point belongs to the cell that contains it, not the nearest centre")
    func flooringIsTheRule() {
        // Art space at 5x: cell 0 covers art [0, 5), cell 1 covers [5, 10).
        func cell(art: Double, scale: Double = 5) -> Int { Int((art / scale).rounded(.down)) }

        #expect(cell(art: 0.0) == 0)
        #expect(cell(art: 4.9) == 0, "still inside cell 0")
        #expect(cell(art: 5.0) == 1, "the boundary belongs to the cell it opens")
        #expect(cell(art: 9.99) == 1)
        #expect(cell(art: 10.0) == 2)

        // What rounding used to do, kept as the counter-example: 4.9 rounds to
        // 5 and divides into cell 1 — one cell right of where the point is.
        let rounded = Int(4.9.rounded()) / 5
        #expect(rounded == 1)
        #expect(rounded != cell(art: 4.9), "this is the disagreement that was fixed")
    }
}
