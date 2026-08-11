import Testing
import Foundation
@testable import VinodexCore

/// A `WineDatabase` over hand-written entries, for the states the shipped
/// catalogue can never reach — chiefly an **empty category**, which is the only
/// thing `DailyPick`'s fallback exists for (AUDIT **M32**), and a region
/// carrying a known soil type, which is the only way to reach `.soil` at all
/// (AUDIT **M33**).
///
/// Entries go in as JSON rather than as Swift literals because there is no
/// alternative: `GrapeEntry` and its four siblings each declare `init(from:)`
/// in the type body, which suppresses the synthesised memberwise initialiser,
/// so a `WineEntry` cannot be constructed by hand at all. Going through
/// `WineDatabase.decodeEntries(from:)` is the app's real load path, so a
/// fixture that stops decoding is a fixture that has drifted from the schema —
/// which is the behaviour you want from it.
///
/// Palette and icons are borrowed from the shipped database. Nothing here
/// asserts on either, and both have fourteen-odd non-optional tables, so a
/// literal would be pure noise.
enum DBFixture {
    static func database(_ fragments: String...) throws -> WineDatabase {
        let json = "[\(fragments.joined(separator: ","))]"
        let (entries, failures) = try WineDatabase.decodeEntries(from: Data(json.utf8))
        // Without this the fixture fails *silently*: `decodeEntries` records a
        // malformed record rather than throwing, so a missing non-optional key
        // yields an empty database and every assertion below it passes for the
        // wrong reason.
        #expect(failures.isEmpty, "fixture JSON is malformed: \(failures)")
        return WineDatabase(
            entries: entries,
            palette: WineDatabase.shared.palette,
            icons: WineDatabase.shared.icons
        )
    }

    /// The minimum a `GRAPES` record needs: `EntryCommon`'s five keys plus
    /// `grapeType`, `grapeStyle`, `grapeBodyClass`, `grapeCharacteristics`,
    /// `grapeCountryOfOrigin`, `rarity`, and a `details` carrying
    /// `origin`/`synonyms`/`keyRegions`/`body`. Everything else decodes
    /// if-present.
    static let grape = #"""
    {"id":"FX_G","name":"Fixture Grape","description":"d","color":"#722F37","tags":["Berry"],
     "category":"GRAPES","grapeType":"red","grapeStyle":"Full-Body Red","grapeBodyClass":"Full",
     "grapeCharacteristics":{"tannin":4,"acid":3,"colorIntensity":4,"aromatics":3,"body":5},
     "grapeCountryOfOrigin":"France","rarity":"COMMON","wineType":"Full-Body Red",
     "tastingProfile":[{"note":"Blackcurrant","icon":"circle","color":"#4B0082"}],
     "details":{"origin":"France","synonyms":["Fixture Syn"],"keyRegions":["Bordeaux"],"body":"Full"}}
    """#

    /// `REGIONS` needs `details.origin`, `details.notableGrapes` and
    /// `details.classification`. `soilType` is here for **M33**'s `.soil`
    /// branch, which no shipped construction site can reach.
    static let region = #"""
    {"id":"FX_R","name":"Fixture Region","description":"d","color":"#2F4F4F","tags":["Chalk"],
     "category":"REGIONS","climate":"maritime",
     "details":{"origin":"France","notableGrapes":["Fixture Grape"],"classification":"AOC",
                "soilType":"Limestone and clay"}}
    """#

    static let style = #"""
    {"id":"FX_S","name":"Fixture Rose Sparkling","description":"d","color":"#C08081","tags":["Rose"],
     "category":"STYLES","rarity":"RARE",
     "details":{"origin":"France","keyRegions":["Champagne"],"notableGrapes":["Fixture Grape"],
                "classification":"STYLE"}}
    """#

    static let flavor = #"""
    {"id":"FX_F","name":"Fixture Flavor","description":"d","color":"#8B0000","tags":[],
     "category":"FLAVORS","tastingProfile":[{"note":"Cherry","icon":"circle","color":"#8B0000"}],
     "details":{"classification":"SWEET","subclass":"BERRY","notableGrapes":["Fixture Grape"]}}
    """#

    static let continent = #"""
    {"id":"FX_C","name":"Fixture Continent","description":"d","color":"#1E90FF","tags":[],
     "category":"CONTINENTS","details":{"keyRegions":["France"]}}
    """#
}
