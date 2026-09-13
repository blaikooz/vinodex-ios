#if canImport(SwiftUI) && canImport(UIKit)
import Testing
import Foundation
import VinodexCore
@testable import VinodexUI

/// **The fence, which is arithmetic and was wrong by a sign of comparison.**
///
/// This suite lives in the UI target because `GlobeModel` does — it carries a
/// SceneKit scene — and the simulator job is what runs it. That is worth the
/// awkwardness: the numbers here are the difference between a region map that
/// fills the glass and one with a band of bare globe along its edge, and the
/// two formulas differ by `max` versus `min` in one line each.
// Every member of `GlobeModel` is main-actor isolated, the static maths
// included, so the suite is too.
@Suite("Globe fence")
@MainActor
struct GlobeFenceTests {
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

    /// A portrait viewport, near enough the device's glass. The aspect is the
    /// whole reason the two formulas disagree, so it has to be a real one.
    private let portrait = 0.63

    /// **The bug, stated as a comparison.**
    ///
    /// Lebanon's canvas is 4.8 degrees of arc wide and 5.2 tall — wider than
    /// it is tall relative to a portrait viewport. Contained, the width binds
    /// and the view reaches past the art vertically. Filled, the height binds
    /// and the art overflows sideways, where overflowing is free.
    @Test("filling a portrait viewport magnifies more than fitting it")
    func fillBeatsFit() throws {
        for key in ["lebanon", "unitedkingdom", "cyprus", "chile", "italy"] {
            let b = try map(key).canvasBounds
            let fit = GlobeModel.zoomToFit(west: b.west, east: b.east,
                                           south: b.south, north: b.north,
                                           aspect: portrait, margin: 1.0,
                                           ceiling: GlobeModel.mapMaxZoom)
            let fill = GlobeModel.zoomToFill(west: b.west, east: b.east,
                                             south: b.south, north: b.north,
                                             aspect: portrait)
            #expect(fill >= fit, "\(key): filling asked for less magnification than fitting")
        }
    }

    /// **Every shipped map can actually be fenced.** The fence is only a fence
    /// if the minimum it demands is reachable, and the globe's 12x ceiling was
    /// not enough for nine of the thirty-nine. A fortieth country arriving
    /// with a smaller canvas than the United Kingdom's would need the ceiling
    /// raised again, and this is where that shows up rather than on a device.
    @Test("no shipped canvas needs more magnification than the map tier allows")
    func everyMapIsFenceable() throws {
        for key in RegionMap.mapped {
            let b = try map(key).canvasBounds
            let fill = GlobeModel.zoomToFill(west: b.west, east: b.east,
                                             south: b.south, north: b.north,
                                             aspect: portrait)
            #expect(fill < GlobeModel.mapMaxZoom,
                    "\(key) needs \(fill)x to fill the glass, above the \(GlobeModel.mapMaxZoom) ceiling")
        }
    }

    /// At the fill magnification the lens shows no more latitude than the art
    /// covers. This is the property the whole thing exists for, checked against
    /// `visibleArc` — which is the camera's own inverse, not a second formula.
    @Test("at the fence minimum the art covers the glass")
    func artCoversTheGlass() throws {
        for key in ["lebanon", "unitedkingdom", "chile", "canada", "france"] {
            let b = try map(key).canvasBounds
            let fill = GlobeModel.zoomToFill(west: b.west, east: b.east,
                                             south: b.south, north: b.north,
                                             aspect: portrait)
            let shown = GlobeModel.visibleArc(atZoom: fill)
            let covered = b.north - b.south
            // A tenth of a degree of tolerance for the binary search.
            #expect(shown <= covered + 0.1,
                    "\(key) shows \(shown)° of latitude over \(covered)° of art")
        }
    }

    /// The ceiling depends on the tier, and the globe keeps its own. 12 is a
    /// limit on `globe-wine.png`'s 2048 pixels, not on the camera, and letting
    /// a map's ceiling leak up to the globe would put five coloured blocks on
    /// the glass.
    @Test("the map tier has more headroom than the globe, and the globe keeps its own")
    func ceilings() {
        #expect(GlobeModel.mapMaxZoom > GlobeModel.maxZoom)
        let model = GlobeModel()
        #expect(model.zoomCeiling == GlobeModel.maxZoom, "no map is up")
        model.zoom = 99
        #expect(model.zoom == GlobeModel.maxZoom, "the globe let the lens past its ceiling")

        model.fence(to: (west: -10, east: 10, south: 40, north: 50), aspect: 0.63)
        #expect(model.zoomCeiling == GlobeModel.mapMaxZoom)
        model.zoom = 99
        #expect(model.zoom == GlobeModel.mapMaxZoom)

        // And the floor holds against a pinch that writes straight through it.
        model.zoom = 1
        #expect(model.zoom > 1, "the fence let the camera off the art")

        model.unfence()
        #expect(model.zoomCeiling == GlobeModel.maxZoom)
    }
}
#endif
