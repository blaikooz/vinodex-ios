import Testing
import Foundation
@testable import VinodexCore

/// The France region map's pure half (0.9.55, a test feature).
///
/// These read the *shipped* manifest and index rather than fixtures, because
/// the interesting failures are all drift between the renderer's output and
/// what the app expects of it — a fixture would keep passing while the real
/// map stopped resolving.
@Suite("France region map")
struct FranceMapTests {
    private func load() throws -> FranceMap {
        // From Tests/VinodexCoreTests up to the repo root.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dir = root.appendingPathComponent("Sources/VinodexUI/Resources/Maps/france")
        return try FranceMap(
            manifest: Data(contentsOf: dir.appendingPathComponent("france-manifest.json")),
            index: Data(contentsOf: dir.appendingPathComponent("france-region-index.json"))
        )
    }

    @Test("the manifest carries all fourteen painted regions")
    func fourteenRegions() throws {
        let map = try load()
        #expect(map.regions.count == 14)
        #expect(map.canvas.w == 162 && map.canvas.h == 156)
    }

    /// The load-bearing property of the whole hit test: two regions sharing a
    /// fill would make one of them unreachable, silently, for every tap.
    @Test("every region's fill colour is unique")
    func fillsAreDistinct() throws {
        let map = try load()
        #expect(map.byFill.count == map.regions.count,
                "two regions share a fill — one is unreachable")
    }

    @Test("markers sit inside the canvas")
    func buttonsInBounds() throws {
        for region in try load().regions {
            #expect(region.button.x > 0 && region.button.x < 1, "\(region.id) x")
            #expect(region.button.y > 0 && region.button.y < 1, "\(region.id) y")
        }
    }

    /// The frame that lets a chosen region lift off the base map in place.
    /// Derived from the renderer's projected bounds through the base
    /// projection, so an arithmetic slip here would park Bordeaux's close-up
    /// over Alsace — visible, but only to someone who knows France.
    @Test("each detail drawing's frame sits on its own region")
    func detailFramesAlign() throws {
        let map = try load()
        for region in map.regions {
            let f = region.detailFrame
            #expect(f.w > 0 && f.h > 0, "\(region.id) has no detail frame")
            #expect(f.x >= -0.02 && f.x + f.w <= 1.02, "\(region.id) runs off the canvas")
            #expect(f.y >= -0.02 && f.y + f.h <= 1.02, "\(region.id) runs off the canvas")
            // The close-up is of this region, so the marker — the point
            // furthest inside it — must fall within the frame.
            #expect(region.button.x >= f.x && region.button.x <= f.x + f.w,
                    "\(region.id) marker is outside its own detail frame")
            #expect(region.button.y >= f.y && region.button.y <= f.y + f.h,
                    "\(region.id) marker is outside its own detail frame")
        }
    }

    /// A painted area with no catalog region behind it renders as inert, and
    /// the drop asks for it to be reported. Today there are none — all
    /// twenty catalog regions land on one of the fourteen stems.
    @Test("every painted region has at least one catalog region behind it")
    func everyStemIsBacked() throws {
        let map = try load()
        let empty = map.regions.map(\.id).filter { map.regionIDs(for: $0).isEmpty }
        #expect(empty.isEmpty, "painted but uncatalogued: \(empty)")
    }

    /// The index is generated from `pins.json` by `france_check.py`; these
    /// are the groupings that took a config fix or an authored coordinate to
    /// get right, so they are the ones worth pinning.
    @Test("the catalog joins where the geography says it should")
    func knownGroupings() throws {
        let map = try load()
        #expect(map.regionIDs(for: "bordeaux").sorted() == ["R001", "R011"])
        // Four regions behind one painted area — the case that makes a stem
        // an art name rather than an id.
        #expect(map.regionIDs(for: "southwest").sorted() == ["R079", "R108", "R122", "R155"])
        // Beaujolais and the northern Rhône share a département, split at
        // 45.62N by the renderer. If the split regressed these two swap.
        #expect(map.regionIDs(for: "beaujolais") == ["R008"])
        #expect(map.regionIDs(for: "rhone").sorted() == ["R004", "R099"])
        // Alsace decoded from mapPosition landed in Champagne; the authored
        // coordinate is what fixed it. This pin is that bug's gravestone.
        #expect(map.regionIDs(for: "alsace") == ["R006"])
    }

    @Test("all twenty France regions are placed, none twice")
    func everyCatalogRegionPlaced() throws {
        let map = try load()
        let placed = map.regions.flatMap { map.regionIDs(for: $0.id) }
        #expect(placed.count == 20)
        #expect(Set(placed).count == 20, "a region is on the map twice")
    }

    @Test("hex decoding accepts the manifest's form and refuses nonsense")
    func hexDecoding() {
        #expect(FranceMap.RGB(hex: "#8E2F45") == FranceMap.RGB(r: 142, g: 47, b: 69))
        #expect(FranceMap.RGB(hex: "8E2F45") == FranceMap.RGB(r: 142, g: 47, b: 69))
        #expect(FranceMap.RGB(hex: "#8E2F4") == nil)
        #expect(FranceMap.RGB(hex: "zzzzzz") == nil)
    }

    @Test("every stem has a display name spelled the catalog's way")
    func displayNames() throws {
        let map = try load()
        for region in map.regions {
            #expect(FranceMap.displayNames[region.id] != nil, "no display name for \(region.id)")
        }
        // The one that would be wrong if a stem were simply up-cased.
        #expect(map.displayName("rhone") == "RHÔNE")
    }
}
