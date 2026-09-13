import Testing
import Foundation
@testable import VinodexCore

/// The painted region maps' pure half (0.9.55, a test feature) — France and
/// Italy, whichever `RegionMap.mapped` lists.
///
/// These read the *shipped* manifests and indexes rather than fixtures,
/// because the interesting failures are all drift between the renderer's
/// output and what the app expects of it — a fixture would keep passing while
/// the real map stopped resolving. That is not hypothetical: the generalised
/// drop renamed `france_rect` to `subject_rect`, and nothing but reading the
/// shipped file catches that.
@Suite("Region maps")
struct RegionMapTests {
    private func load(_ country: String = "france") throws -> RegionMap {
        // From Tests/VinodexCoreTests up to the repo root.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dir = root.appendingPathComponent("Sources/VinodexUI/Resources/Maps/\(country)")
        return try RegionMap(
            manifest: Data(contentsOf: dir.appendingPathComponent("\(country)-manifest.json")),
            index: Data(contentsOf: dir.appendingPathComponent("\(country)-region-index.json"))
        )
    }

    @Test("each manifest carries its painted regions")
    func fourteenRegions() throws {
        let map = try load()
        #expect(map.regions.count == 14)
        #expect(try load("italy").regions.count == 21)
        // 167 painted areas across all thirty-nine countries, on the
        // maintainer's ruling of 13 Sep that every wine country gets a map.
        // Plus France's two children on the second index plane, which are
        // painted regions the area count does not see: 169 in all.
        var total = 0
        for country in RegionMap.mapped { total += try load(country).regions.count }
        #expect(total == 167, "painted areas across all thirty-nine: \(total)")
        var children = 0
        for country in RegionMap.mapped { children += try load(country).childrenByIndex.count }
        #expect(children == 2, "children on second planes: \(children)")
        // The canvas is whatever the render made it — it grew a margin of
        // world on every side when the backdrop arrived, and the margin is
        // config. `subjectRectIsSane` pins the part that has to hold.
        #expect(map.canvas.w > 100 && map.canvas.h > 100)
    }

    /// France's own rect on the canvas, which is what the screen scales by.
    /// Aspect-fitting the whole canvas instead would shrink France to a third
    /// of the screen and take every tap target down with it, so this being
    /// right is the difference between a usable map and an unusable one.
    @Test("the country occupies about a third of its canvas, centred")
    func subjectRectIsSane() throws {
        let fr = try load().subjectRect
        #expect(fr.w > 0.25 && fr.w < 0.40, "France's width fraction: \(fr.w)")
        #expect(fr.h > 0.25 && fr.h < 0.40, "France's height fraction: \(fr.h)")
        // Roughly centred, since the renderer puts an equal margin all round.
        #expect(abs((fr.x + fr.w / 2) - 0.5) < 0.05)
        #expect(abs((fr.y + fr.h / 2) - 0.5) < 0.05)
    }

    /// **No canvas may claim a latitude the world does not have.**
    ///
    /// `region_map.py` gives every country the same 502-cell canvas height and
    /// pads the remainder as sea, so a far-northern country runs off the top:
    /// Canada's raw canvas reaches **128.2°N**, thirty-eight degrees past the
    /// pole, all of it empty blue.
    ///
    /// Empty is not harmless. The globe lays the backdrop on a lat/lon mesh,
    /// and a vertex at 128°N is placed by going over the pole and 52 degrees
    /// down the far side — so the top of Canada's canvas folded back onto the
    /// near hemisphere and z-fought with itself. On the device that read as
    /// evenly spaced curved bands of sea cutting through Greenland, which is
    /// the bug the maintainer photographed on 13 Sep. The fence measures these
    /// same bounds, so an impossible north would also have fenced the camera
    /// to a latitude it can never reach.
    @Test("every canvas describes a real extent, poles included")
    func canvasBoundsAreReal() throws {
        for country in RegionMap.mapped {
            let b = try load(country).canvasBounds
            #expect(b.north <= 90, "\(country) canvas claims \(b.north)°N")
            #expect(b.south >= -90, "\(country) canvas claims \(b.south)°S")
            #expect(b.north > b.south, "\(country) canvas is inverted or empty")
            #expect(b.east > b.west, "\(country) canvas is inverted or empty")
            // The subject has to survive the clamp — trimming dead margin must
            // never trim the country.
            let s = try load(country).subjectBounds
            #expect(s.north <= b.north + 0.001 && s.south >= b.south - 0.001,
                    "\(country)'s country sits outside its own clamped canvas")
        }
    }

    /// Canada by name, because it is the one the clamp exists for and a
    /// regression here would be invisible in the aggregate above.
    @Test("Canada's canvas stops at the pole, not thirty-eight degrees past it")
    func canadaStopsAtThePole() throws {
        let b = try load("canada").canvasBounds
        #expect(b.north == 90)
        // Still the whole country: Canada reaches 83.1°N at Cape Columbia.
        #expect(try load("canada").subjectBounds.north > 80)
    }

    /// **A painted area must be named after itself** (0.9.58).
    ///
    /// The stem is the geography the renderer drew; the display name is what
    /// the screen says you tapped. When they are different *places* the map
    /// lies about what is under your finger, and it had done so four times:
    /// `oregon` displayed as WILLAMETTE VALLEY, `washington` as WALLA WALLA,
    /// `newyork` as FINGER LAKES and `ningxia` as HELAN MOUNTAIN — in each
    /// case an administrative unit wearing the name of the one appellation
    /// the catalog happens to hold inside it. Tapping the whole of Oregon and
    /// being told it is the Willamette Valley is wrong in the same way the
    /// California tile reading NAPA VALLEY was.
    ///
    /// Folded rather than compared outright, because the display name is
    /// allowed to be the *same* place spelled properly: `dao` is DÃO,
    /// `southwest` is SOUTH WEST, `niederosterreich` keeps its umlaut. What is
    /// not allowed is a name neither string contains.
    @Test("no painted area is named after a different place")
    func displayNamesNameTheArea() throws {
        func fold(_ value: String) -> String {
            value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .filter { $0.isLetter || $0.isNumber }
        }
        for country in RegionMap.mapped {
            let map = try load(country)
            for stem in map.regions.map(\.id) {
                let shown = fold(map.displayName(stem))
                let key = fold(stem)
                #expect(shown.contains(key) || key.contains(shown),
                        "\(country)/\(stem) displays as \"\(map.displayName(stem))\", a different place")
            }
        }
    }

    /// The load-bearing property of the whole hit test: two regions sharing a
    /// fill would make one of them unreachable, silently, for every tap.
    /// **The contract the hit test rests on.** Ids are what resolve a tap;
    /// fills are presentation and repeat across countries on purpose — 85
    /// regions share 35 colours, because two that never appear on screen
    /// together are free to look alike. A duplicate *id* inside one country
    /// would make a region unreachable, silently.
    @Test("every region's index id is unique within its country")
    func indexesAreDistinct() throws {
        for country in RegionMap.mapped {
            let map = try load(country)
            #expect(map.byIndex.count == map.regions.count,
                    "\(country): two regions share an index id")
            // One byte, and 0 and 255 are reserved for outside and unassigned.
            for region in map.regions {
                #expect(region.index >= 1 && region.index <= 254,
                        "\(country)/\(region.id) id \(region.index) is not a usable byte")
            }
        }
    }

    @Test("markers sit inside the canvas")
    func buttonsInBounds() throws {
        for country in RegionMap.mapped {
        for region in try load(country).regions {
            #expect(region.button.x > 0 && region.button.x < 1, "\(region.id) x")
            #expect(region.button.y > 0 && region.button.y < 1, "\(region.id) y")
        }
        }
    }

    /// The frame that lets a chosen region lift off the base map in place.
    /// Derived from the renderer's projected bounds through the base
    /// projection, so an arithmetic slip here would park Bordeaux's close-up
    /// over Alsace — visible, but only to someone who knows France.
    @Test("each detail drawing's frame sits on its own region")
    func detailFramesAlign() throws {
        for country in RegionMap.mapped {
        let map = try load(country)
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
    }

    /// A painted area with no catalog region behind it renders as inert, and
    /// the drop asks for it to be reported rather than silently tapped.
    ///
    /// France has none — all twenty catalog regions land on one of its
    /// fourteen stems. **Italy has exactly three**, and they are a finding
    /// about the catalog rather than about the map: Liguria, Molise and
    /// Valle d'Aosta are real Italian wine regions the encyclopedia does not
    /// hold yet. Pinned by name so that filling one in the catalog, or
    /// painting a fourth uncovered area, both fail here and get a decision.
    /// **25 of 85 painted areas have no catalog region behind them**, and
    /// they are pinned by name rather than counted, so that filling one in
    /// the catalog — or painting a new area nothing covers — fails here and
    /// gets a decision instead of passing quietly.
    ///
    /// This is a finding about the *catalog*, not the map. The gap is almost
    /// entirely New World: New Zealand has seven of its ten uncovered, Chile
    /// five of eight, Argentina three of six. France has none. A tap on any
    /// of these lands on a real region and then says NO CATALOG REGION HERE,
    /// which is honest but is not what a tester wants to meet.
    @Test("uncatalogued painted areas are exactly the ones we know about")
    func stemsWithoutCatalog() throws {
        let known: [String: [String]] = [
            "argentina": ["catamarca", "cordoba", "sanjuan"],
            "armenia": [],
            "australia": [],
            "austria": [],
            "brazil": [],
            "bulgaria": [],
            "canada": [],
            "chile": ["biobio", "coquimbo", "malleco", "maule", "rapel"],
            "china": [],
            "croatia": [],
            "cyprus": [],
            "czechia": [],
            "france": [],
            "georgia": [],
            "germany": [],
            "greece": [],
            "hungary": [],
            "india": [],
            "israel": [],
            "italy": ["liguria", "molise", "valledaosta"],
            "japan": [],
            "lebanon": [],
            "mexico": [],
            "moldova": [],
            "morocco": [],
            "newzealand": ["auckland", "canterbury", "gisborne", "nelson", "northland", "waikatobop", "wairarapa"],
            "portugal": ["algarve", "beirainterior", "setubal"],
            "romania": [],
            "serbia": [],
            "slovakia": [],
            "slovenia": [],
            "southafrica": [],
            "spain": ["andalucia", "aragon", "extremadura", "madrid"],
            "switzerland": [],
            "turkey": [],
            "ukraine": [],
            "unitedkingdom": [],
            "uruguay": [],
            "usa": [],
        ]
        var total = 0
        for country in RegionMap.mapped {
            let map = try load(country)
            let empty = map.regions.map(\.id)
                .filter { map.regionIDs(for: $0).isEmpty }.sorted()
            #expect(empty == known[country], "\(country) uncovered changed: \(empty)")
            total += empty.count
        }
        #expect(total == 25)
    }

    /// The index is generated from `pins.json` by `france_check.py`; these
    /// are the groupings that took a config fix or an authored coordinate to
    /// get right, so they are the ones worth pinning.
    @Test("the catalog joins where the geography says it should")
    func knownGroupings() throws {
        let map = try load()
        // **Sauternes left Bordeaux's area for the second index plane**
        // (0.9.57). It is a sub-AOC inside the Gironde that no admin unit
        // isolates, so it was only ever grouped here because one plane cannot
        // hold a region inside a region. It is a child now, and still resolves.
        #expect(map.regionIDs(for: "bordeaux") == ["R001"])
        #expect(map.regionIDs(for: "sauternes") == ["R011"])
        // Four regions behind one painted area — the case that makes a stem
        // an art name rather than an id.
        #expect(map.regionIDs(for: "southwest").sorted() == ["R079", "R108", "R122", "R155"])
        // Beaujolais and the northern Rhône share a département, split at
        // 45.62N by the renderer. If the split regressed these two swap.
        #expect(map.regionIDs(for: "beaujolais") == ["R008"])
        // Châteauneuf likewise: a commune inside the Southern Rhône. Handing
        // it the Vaucluse would have painted Gigondas and Vacqueyras as
        // Châteauneuf, which is why it waited for the second plane.
        #expect(map.regionIDs(for: "rhone") == ["R004"])
        #expect(map.regionIDs(for: "chateauneuf") == ["R099"])
        // Alsace decoded from mapPosition landed in Champagne; the authored
        // coordinate is what fixed it. This pin is that bug's gravestone.
        #expect(map.regionIDs(for: "alsace") == ["R006"])
    }

    @Test("every catalog region is placed once, in every country")
    func everyCatalogRegionPlaced() throws {
        // Portugal is 7 rather than 9, Spain 18 rather than 19: Madeira, the
        // Azores and the Canaries are 900–1800km offshore, and widening a
        // mainland map far enough to hold them would shrink the mainland —
        // and every tap target on it — to nothing. They stay reachable
        // through the ordinary region list; they simply have no square on
        // this board. See `OFF_ANY_MAP` in make_pins.py.
        let expected = [("france", 20), ("italy", 21), ("spain", 18),
                        ("portugal", 7), ("argentina", 3), ("chile", 3),
                        ("newzealand", 3)]
        var total = 0
        for (country, count) in expected {
            let map = try load(country)
            // Areas **and** children: France's twenty includes Sauternes and
            // Châteauneuf, which live on the second plane rather than being
            // areas of their own. Counting areas alone would read as two
            // catalog regions having fallen off the map.
            let placed = map.regions.flatMap { map.regionIDs(for: $0.id) }
                + map.childrenByIndex.values.flatMap { map.regionIDs(for: $0.stem) }
            #expect(placed.count == count, "\(country) placed \(placed.count)")
            #expect(Set(placed).count == count, "\(country) has a region on the map twice")
            total += placed.count
        }
        #expect(total == 75)
    }

    @Test("hex decoding accepts the manifest's form and refuses nonsense")
    func hexDecoding() {
        #expect(RegionMap.RGB(hex: "#8E2F45") == RegionMap.RGB(r: 142, g: 47, b: 69))
        #expect(RegionMap.RGB(hex: "8E2F45") == RegionMap.RGB(r: 142, g: 47, b: 69))
        #expect(RegionMap.RGB(hex: "#8E2F4") == nil)
        #expect(RegionMap.RGB(hex: "zzzzzz") == nil)
    }

    @Test("every stem has a display name spelled the catalog's way")
    func displayNames() throws {
        for country in RegionMap.mapped {
            let map = try load(country)
            for region in map.regions {
                #expect(RegionMap.displayNames[region.id] != nil,
                        "no display name for \(country)/\(region.id)")
            }
        }
        let map = try load()
        // The one that would be wrong if a stem were simply up-cased.
        #expect(map.displayName("rhone") == "RHÔNE")
    }
}
