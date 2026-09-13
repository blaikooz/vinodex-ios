import Testing
import Foundation
@testable import VinodexCore

/// The first-run card deck, and the flag that stops it running twice.
///
/// Both halves were written after a bug. The cards shipped once with their
/// expression as a raw string where the glyph loader wanted an art stem, so
/// every card drew a fallback chip instead of Professor Vino's face; that is
/// now a type and cannot be given a stem that does not exist. And moving the
/// first-run slot off the coachmark removed the only thing that wrote
/// `hasBeenOffered`, which would have replayed the whole sequence on every
/// launch forever.
@Suite("Orientation")
struct OrientationTests {
    @Test("four pillars, each with something to say")
    func shape() {
        #expect(Orientation.count == 4)
        #expect(Orientation.cards.count == Orientation.count)
        for card in Orientation.cards {
            #expect(!card.id.isEmpty)
            #expect(!card.title.isEmpty)
            // Two sentences is the brief; one word is a bug you would only
            // find by tapping through.
            #expect(card.body.count > 40, "\(card.id) body is too short to say anything")
            #expect(card.body.count < 260, "\(card.id) body is longer than the brief allows")
        }
        #expect(Set(Orientation.cards.map(\.id)).count == Orientation.count,
                "two cards share an id")
        #expect(Set(Orientation.cards.map(\.title)).count == Orientation.count,
                "two cards claim the same pillar")
    }

    /// The ordering ruling, pinned. The scanner is the thing nothing else does,
    /// and the old sequence saved it for a closing line nobody who skipped ever
    /// reached. Attention decays down a deck, so it goes second — first place
    /// belongs to what the app *is*.
    @Test("the label reader is the second card, not the last")
    func scannerIsSecond() {
        #expect(Orientation.cards[1].id == "reader")
        #expect(Orientation.cards.last?.id != "reader")
    }

    /// Every expression has to resolve to art that exists. The type makes this
    /// true by construction; the test says so out loud, because the string
    /// version did not and shipped a deck of grey chips.
    @Test("every card's portrait resolves to a real art stem")
    func portraits() {
        for card in Orientation.cards {
            #expect(card.expression.artStem.hasPrefix("vino-"))
            #expect(VinoExpression(rawValue: card.expression.rawValue) != nil)
        }
    }

    /// The closing line addresses the player, so it has to carry the token that
    /// gets replaced — and `VinoName.fallback` has to be able to stand in for
    /// someone who skipped the name.
    @Test("the closing line is addressed, and survives a skipped name")
    func closing() {
        #expect(Orientation.closing.contains("{name}"))
        let resolved = Orientation.closing
            .replacingOccurrences(of: "{name}", with: VinoName.fallback)
        #expect(!resolved.contains("{name}"))
        #expect(resolved.contains(VinoName.fallback))
    }

    // MARK: The flag that stops it running twice

    @MainActor private func engine() -> CoachmarkEngine {
        let name = "orientation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return CoachmarkEngine(defaults: defaults)
    }

    /// **The regression that would have replayed onboarding forever.**
    /// `start()` was the only writer of `hasBeenOffered` until orientation took
    /// the first-run slot. `markOffered` is what replaced it, and it must set
    /// the flag *without* putting the guided run on screen.
    @Test("markOffered closes the first run without starting the guided run")
    @MainActor func markOfferedDoesNotStart() {
        let e = engine()
        #expect(e.shouldAutoStart)
        #expect(!e.hasBeenOffered)

        e.markOffered()

        #expect(e.hasBeenOffered)
        #expect(!e.shouldAutoStart, "the first-run sequence would replay on the next launch")
        #expect(!e.isRunning, "orientation must not raise the coachmark overlay")
    }

    /// Idempotent, and it survives a reload — the flag is storage, not state.
    @Test("marking twice is harmless and it persists")
    @MainActor func markOfferedPersists() {
        let name = "orientation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let first = CoachmarkEngine(defaults: defaults)
        first.markOffered()
        first.markOffered()
        #expect(first.hasBeenOffered)

        let reloaded = CoachmarkEngine(defaults: defaults)
        #expect(reloaded.hasBeenOffered)
        #expect(!reloaded.shouldAutoStart)
    }

    /// The guided run still works when someone asks for it from SETTINGS.
    /// Demoting it must not disable it.
    @Test("the guided run still starts when asked for")
    @MainActor func guidedRunStillWorks() {
        let e = engine()
        e.markOffered()
        e.start()
        #expect(e.isRunning)
        #expect(e.current != nil)
    }
}
