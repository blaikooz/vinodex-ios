import Foundation
import Testing
@testable import VinodexCore

/// Vinobot's entry takes (rework V3): the whole catalog through the gates.
@MainActor
@Suite("Vino takes")
struct VinoTakeTests {
    let db = WineDatabase.shared

    /// **The floor is total and clean.** Every non-continent entry composes
    /// a take; every take respects the word cap and the ASCII rule; every
    /// override names a real entry. One gate, whole catalog.
    @Test("every entry composes a take that passes every rule")
    func catalogIsClean() {
        let problems = VinoTake.problems(in: db)
        #expect(problems.isEmpty, "\(problems)")
    }

    /// **Eight overrides since V3** — counted in the title, per the house
    /// rule that a silent addition is how a wrong one arrives.
    @Test("the eight authored overrides win over the floor")
    func overridesWin() {
        #expect(VinoTake.overrides.count == 8)
        for (id, authored) in VinoTake.overrides {
            let entry = db.entry(id: id)
            #expect(entry != nil, "\(id)")
            #expect(entry.flatMap { VinoTake.compose(for: $0, in: db) } == authored, "\(id)")
        }
    }

    /// Continents get no take, deliberately — a table of contents is not a
    /// wine, and a line pretending otherwise would be the fault the module
    /// note names.
    @Test("continents stay silent")
    func continentsSilent() {
        for entry in db.entries(in: .continents) {
            #expect(VinoTake.compose(for: entry, in: db) == nil)
        }
    }
}
