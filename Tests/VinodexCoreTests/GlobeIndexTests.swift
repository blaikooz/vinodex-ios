import Testing
import Foundation
@testable import VinodexCore

/// The globe's country index (0.9.55) — the pure half of tapping the sphere.
///
/// Reads the shipped meta rather than a fixture, for the reason the region
/// map tests do: the interesting failures are all drift between what the
/// renderer emits and what the app expects of it.
@Suite("Globe index")
struct GlobeIndexTests {
    private func load() throws -> GlobeIndex {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("Sources/VinodexUI/Resources/Maps/globe-meta.json")
        return try GlobeIndex(meta: Data(contentsOf: url))
    }

    @Test("thirty wine countries, every id a usable byte")
    func roster() throws {
        let index = try load()
        #expect(index.countries.count == 30)
        for country in index.countries {
            // 0 is reserved for everywhere else, and the raster is 8-bit.
            #expect(country.id >= 1 && country.id <= 255, "\(country.admin) id \(country.id)")
            #expect(!country.label.isEmpty)
        }
        #expect(Set(index.countries.map(\.id)).count == 30, "two countries share an id")
    }

    /// The seven with painted region maps are exactly the seven the flat maps
    /// ship, and `mapped` is what decides whether a second tap goes anywhere.
    /// If these fall out of step, the globe offers a door to a missing room.
    @Test("the mapped countries match the region-map roster")
    func mappedAgreesWithRegionMaps() throws {
        let index = try load()
        let mapped = index.countries.filter(\.isMapped)
        #expect(mapped.count == 7)
        for country in mapped {
            #expect(RegionMap.key(forCountry: country.admin) != nil,
                    "\(country.admin) says it has a region map, but RegionMap.mapped disagrees")
        }
        // And nothing claims a map it has not got.
        for country in index.countries where !country.isMapped {
            #expect(RegionMap.key(forCountry: country.admin) == nil,
                    "\(country.admin) has a region map but the globe says mapped=0")
        }
    }

    /// Plain equirectangular, matching how the texture is wrapped onto the
    /// sphere. The corners are the ones worth pinning: an off-by-one at the
    /// date line or the poles is a tap that lands a hemisphere away.
    @Test("coordinates land in the right cell")
    func cellMapping() {
        let w = 2048, h = 1024
        let middle = GlobeIndex.cell(lon: 0, lat: 0, width: w, height: h)
        #expect(middle.x == w / 2 && middle.y == h / 2)

        let westEdge = GlobeIndex.cell(lon: -180, lat: 90, width: w, height: h)
        #expect(westEdge.x == 0 && westEdge.y == 0)

        // Clamped rather than wrapped past the edge, so the far corner is the
        // last cell and never one beyond it.
        let eastEdge = GlobeIndex.cell(lon: 180, lat: -90, width: w, height: h)
        #expect(eastEdge.x == w - 1 && eastEdge.y == h - 1)

        // Somewhere real: Bordeaux is a little west of the meridian and well
        // north of the equator, so a little left of centre and well above it.
        let bordeaux = GlobeIndex.cell(lon: -0.578, lat: 44.838, width: w, height: h)
        #expect(bordeaux.x < w / 2 && bordeaux.x > w / 2 - 10)
        #expect(bordeaux.y < h / 2)
    }
}
