import Testing
import Foundation
@testable import VinodexCore

@MainActor
@Suite("Screen state")
struct ScreenStateTests {
    /// A fresh store per test rather than the shared singleton, so tests cannot
    /// see each other's keys. Nothing here touches `UserDefaults` — the store is
    /// session state by design.
    private func makeStore() -> ScreenStateStore { ScreenStateStore() }

    @Test("a screen with no stored state restores to the top, collapsed")
    func emptyIsTheDefault() {
        let store = makeStore()
        #expect(store.isEmpty)
        #expect(store.anchor(for: ScreenStateStore.country("France")) == nil)
        #expect(!store.isOn("regions", for: ScreenStateStore.country("France")))
    }

    @Test("an anchor round-trips")
    func anchorRoundTrip() {
        let store = makeStore()
        let key = ScreenStateStore.country("France")

        store.setAnchor("regions", for: key)
        #expect(store.anchor(for: key) == "regions")
        #expect(!store.isEmpty)

        store.setAnchor(nil, for: key)
        #expect(store.anchor(for: key) == nil)
        #expect(store.isEmpty)
    }

    /// The bug this whole store exists for: two countries must not share a
    /// scroll position or an expanded section.
    @Test("screens of the same kind do not share state")
    func keysAreIndependent() {
        let store = makeStore()
        let france = ScreenStateStore.country("France")
        let italy = ScreenStateStore.country("Italy")

        store.setAnchor("regions", for: france)
        store.setFlag("regions", true, for: france)

        #expect(store.anchor(for: italy) == nil)
        #expect(!store.isOn("regions", for: italy))
        #expect(store.anchor(for: france) == "regions")
        #expect(store.isOn("regions", for: france))
    }

    /// A country and a state can carry the same name — Washington is both.
    @Test("different screen kinds with the same name do not collide")
    func kindsDoNotCollide() {
        let store = makeStore()
        store.setAnchor("hero", for: ScreenStateStore.country("Washington"))
        store.setAnchor("regions", for: ScreenStateStore.state("Washington"))

        #expect(store.anchor(for: ScreenStateStore.country("Washington")) == "hero")
        #expect(store.anchor(for: ScreenStateStore.state("Washington")) == "regions")
    }

    @Test("flags are independent of each other within a screen")
    func flagsAreIndependent() {
        let store = makeStore()
        let key = ScreenStateStore.country("USA")

        store.setFlag("states", true, for: key)
        store.setFlag("regions", true, for: key)
        #expect(store.isOn("states", for: key))
        #expect(store.isOn("regions", for: key))

        store.setFlag("states", false, for: key)
        #expect(!store.isOn("states", for: key))
        #expect(store.isOn("regions", for: key))
    }

    @Test("toggle flips and flips back")
    func toggleRoundTrip() {
        let store = makeStore()
        let key = ScreenStateStore.country("Spain")

        store.toggleFlag("regions", for: key)
        #expect(store.isOn("regions", for: key))
        store.toggleFlag("regions", for: key)
        #expect(!store.isOn("regions", for: key))
    }

    /// Off is stored as absence, so collapsing everything leaves nothing behind
    /// — otherwise `isEmpty` would drift false forever after one tap.
    @Test("turning every flag off empties the store")
    func offIsAbsence() {
        let store = makeStore()
        let key = ScreenStateStore.country("Chile")

        store.setFlag("regions", true, for: key)
        store.setFlag("grapes", true, for: key)
        #expect(!store.isEmpty)

        store.setFlag("regions", false, for: key)
        store.setFlag("grapes", false, for: key)
        #expect(store.isEmpty)
    }

    @Test("setting a flag off that was never on is a no-op")
    func offOnUnsetIsHarmless() {
        let store = makeStore()
        let key = ScreenStateStore.detail("GRP_001")

        store.setFlag("regions", false, for: key)
        #expect(store.isEmpty)
        #expect(!store.isOn("regions", for: key))
    }

    @Test("forget drops one screen and leaves the rest")
    func forgetIsNarrow() {
        let store = makeStore()
        let france = ScreenStateStore.country("France")
        let italy = ScreenStateStore.country("Italy")

        store.setAnchor("regions", for: france)
        store.setFlag("regions", true, for: france)
        store.setAnchor("hero", for: italy)

        store.forget(france)
        #expect(store.anchor(for: france) == nil)
        #expect(!store.isOn("regions", for: france))
        #expect(store.anchor(for: italy) == "hero")
    }

    // MARK: Named values

    @Test("a named value round-trips and clears")
    func valueRoundTrip() {
        let store = makeStore()
        let key = ScreenStateStore.scanner

        store.setValue("flavors", "step", for: key)
        #expect(store.value("step", for: key) == "flavors")
        #expect(!store.isEmpty)

        store.setValue(nil, "step", for: key)
        #expect(store.value("step", for: key) == nil)
        #expect(store.isEmpty)
    }

    /// One screen holds several named values — the scanner's cursor and its
    /// answers — and writing one must not disturb the other.
    @Test("values within a screen are independent")
    func valuesAreIndependent() {
        let store = makeStore()
        let key = ScreenStateStore.scanner

        store.setValue("reveal", "step", for: key)
        store.setValue("{}", "criteria", for: key)
        store.setValue(nil, "step", for: key)

        #expect(store.value("step", for: key) == nil)
        #expect(store.value("criteria", for: key) == "{}")
    }

    /// The globe's heading. Round-tripping through a string must not lose
    /// precision, or coming back would land a fraction off where you left.
    @Test("a number round-trips exactly")
    func numberRoundTrip() {
        let store = makeStore()
        let key = ScreenStateStore.globe

        store.setNumber(-1.234567890123, "yaw", for: key)
        #expect(store.number("yaw", for: key) == -1.234567890123)

        store.setNumber(nil, "yaw", for: key)
        #expect(store.number("yaw", for: key) == nil)
        #expect(store.isEmpty)
    }

    @Test("a value that is not a number reads back as nil rather than zero")
    func numberRejectsGarbage() {
        let store = makeStore()
        store.setValue("flavors", "yaw", for: ScreenStateStore.globe)
        #expect(store.number("yaw", for: ScreenStateStore.globe) == nil)
    }

    // MARK: Encoded values

    private struct Answers: Codable, Equatable {
        var color: String?
        var flavorIDs: [String]
    }

    @Test("a structure round-trips through JSON")
    func codableRoundTrip() {
        let store = makeStore()
        let key = ScreenStateStore.scanner
        let answers = Answers(color: "red", flavorIDs: ["FLV_1", "FLV_2"])

        store.encode(answers, "criteria", for: key)
        #expect(store.decoded(Answers.self, "criteria", for: key) == answers)
    }

    /// Encoding nil is how a screen says "I have nothing to restore" — the
    /// scanner does exactly this when RESET empties its criteria.
    @Test("encoding nil clears the slot")
    func encodingNilClears() {
        let store = makeStore()
        let key = ScreenStateStore.scanner

        store.encode(Answers(color: "red", flavorIDs: []), "criteria", for: key)
        store.encode(Optional<Answers>.none, "criteria", for: key)

        #expect(store.decoded(Answers.self, "criteria", for: key) == nil)
        #expect(store.isEmpty)
    }

    /// A decode failure has to behave like an absent value, not like a crash: a
    /// screen restoring nothing simply opens fresh.
    @Test("undecodable stored text yields nil")
    func decodeFailureIsNil() {
        let store = makeStore()
        store.setValue("not json", "criteria", for: ScreenStateStore.scanner)
        #expect(store.decoded(Answers.self, "criteria", for: ScreenStateStore.scanner) == nil)
    }

    // MARK: Lifecycle

    /// Home is the reset — see `RootView.goHome()`.
    @Test("clear empties everything")
    func clearEmpties() {
        let store = makeStore()
        store.setAnchor("regions", for: ScreenStateStore.country("France"))
        store.setFlag("grapes", true, for: ScreenStateStore.country("Italy"))
        store.setAnchor("sections", for: ScreenStateStore.detail("GRP_001"))
        store.setAnchor("SAVED_1", for: ScreenStateStore.bookmarks)
        store.setValue("reveal", "step", for: ScreenStateStore.scanner)
        store.setNumber(2.5, "yaw", for: ScreenStateStore.globe)

        store.clear()
        #expect(store.isEmpty)
        #expect(store.anchor(for: ScreenStateStore.country("France")) == nil)
        #expect(!store.isOn("grapes", for: ScreenStateStore.country("Italy")))
        #expect(store.value("step", for: ScreenStateStore.scanner) == nil)
        #expect(store.number("yaw", for: ScreenStateStore.globe) == nil)
    }

    /// `forget` is what ends a daily-reveal *visit* — see `RootView.goBack()`.
    /// It has to take the values with it, or the held pick would outlive it.
    @Test("forget drops a screen's values as well as its anchors")
    func forgetDropsValues() {
        let store = makeStore()
        store.setNumber(7, "cursor", for: ScreenStateStore.dailyGrape)
        store.setFlag("revealed", true, for: ScreenStateStore.dailyGrape)
        store.setValue("reveal", "step", for: ScreenStateStore.scanner)

        store.forget(ScreenStateStore.dailyGrape)

        #expect(store.number("cursor", for: ScreenStateStore.dailyGrape) == nil)
        #expect(!store.isOn("revealed", for: ScreenStateStore.dailyGrape))
        #expect(store.value("step", for: ScreenStateStore.scanner) == "reveal")
    }

    /// Keys are spelled out rather than derived, so they cannot drift when a
    /// route case is renamed.
    @Test("keys are stable and prefixed per screen kind")
    func keysAreStable() {
        #expect(ScreenStateStore.country("France") == "country:France")
        #expect(ScreenStateStore.state("California") == "state:California")
        #expect(ScreenStateStore.detail("GRP_001") == "detail:GRP_001")
        #expect(ScreenStateStore.continent("CONT_europe") == "continent:CONT_europe")
        #expect(ScreenStateStore.bookmarks == "bookmarks")
        #expect(ScreenStateStore.scanner == "scanner")
        #expect(ScreenStateStore.dailyGrape == "dailyGrape")
        #expect(ScreenStateStore.globe == "globe")
        #expect(ScreenStateStore.settings("DATA") == "settings:DATA")
    }
}
