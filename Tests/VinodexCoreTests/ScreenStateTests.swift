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

    /// Home is the reset — see `RootView.goHome()`.
    @Test("clear empties everything")
    func clearEmpties() {
        let store = makeStore()
        store.setAnchor("regions", for: ScreenStateStore.country("France"))
        store.setFlag("grapes", true, for: ScreenStateStore.country("Italy"))
        store.setAnchor("sections", for: ScreenStateStore.detail("GRP_001"))
        store.setAnchor("SAVED_1", for: ScreenStateStore.bookmarks)

        store.clear()
        #expect(store.isEmpty)
        #expect(store.anchor(for: ScreenStateStore.country("France")) == nil)
        #expect(!store.isOn("grapes", for: ScreenStateStore.country("Italy")))
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
    }
}
