import Testing
import Foundation
@testable import VinodexCore

/// The only automated signal AUDIT H11 can get.
///
/// Everything H11 touches on the UI side — `DexFont`, the root pin, the raised
/// literals — is inside `#if canImport(SwiftUI) && canImport(UIKit)` and
/// compiles to nothing on this host, so none of it is reachable from a test.
/// That is precisely why the floor and the step live in Core: the arithmetic
/// that decides how large every label in the app draws is checkable here.
@Suite("TypeScale")
struct TypeScaleTests {
    private func defaults() -> UserDefaults {
        let name = UUID().uuidString
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    /// Close enough for point sizes; `0.85 * 10` is not exactly 8.5 in binary.
    private func expect(_ got: Double, _ want: Double, _ what: String) {
        #expect(abs(got - want) < 0.000_001, "\(what): got \(got), want \(want)")
    }

    // MARK: - The floor

    @Test("sub-floor nominals are lifted to the floor")
    func floorLifts() {
        // The ten call sites the audit named, at the shipped default step.
        expect(TypeScale.resolve(nominal: 8, step: .small), 8.5, "retro(8) @SMALL")
        expect(TypeScale.resolve(nominal: 9, step: .small), 8.5, "retro(9) @SMALL")
        // Not 6.80 and 7.65, which is what they drew before 0.6.4.
        #expect(TypeScale.resolve(nominal: 8, step: .small) > 8 * 0.85)
    }

    /// The guarantee that makes this change reviewable without a device: every
    /// call site already at or above the floor draws at exactly the size it did
    /// before, at every step. If this fails, the fix silently re-sized the app.
    @Test("call sites at or above the floor are untouched at every step")
    func atOrAboveFloorUnchanged() {
        let shipped: [Double] = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 19.2,
                                 20, 21, 22, 24, 26, 28, 30, 36]
        for nominal in shipped {
            for step in TextScale.allCases {
                expect(TypeScale.resolve(nominal: nominal, step: step),
                       nominal * step.factor,
                       "\(nominal) @\(step.rawValue) must be the plain product")
            }
        }
    }

    @Test("the floor is exactly a call-site rewrite, applied before the step")
    func floorPrecedesFactor() {
        for step in TextScale.allCases {
            expect(TypeScale.resolve(nominal: 4, step: step),
                   TypeScale.resolve(nominal: TypeScale.nominalFloor, step: step),
                   "anything under the floor draws as the floor @\(step.rawValue)")
        }
    }

    @Test("resolve is monotonic in nominal and in step")
    func monotonic() {
        for step in TextScale.allCases {
            var previous = 0.0
            for nominal in stride(from: 1.0, through: 60.0, by: 0.5) {
                let got = TypeScale.resolve(nominal: nominal, step: step)
                #expect(got >= previous)
                previous = got
            }
        }
        for nominal in stride(from: 1.0, through: 60.0, by: 0.5) {
            #expect(TypeScale.resolve(nominal: nominal, step: .small)
                    < TypeScale.resolve(nominal: nominal, step: .large))
            #expect(TypeScale.resolve(nominal: nominal, step: .large)
                    < TypeScale.resolve(nominal: nominal, step: .huge))
        }
    }

    // MARK: - The steps

    @Test("the persisted vocabulary and its two original factors are unchanged")
    func stepsAreStable() {
        // Moving either of these resizes the app under existing users.
        #expect(TextScale.small.rawValue == "SMALL")
        #expect(TextScale.large.rawValue == "LARGE")
        expect(TextScale.small.factor, 0.85, "SMALL")
        expect(TextScale.large.factor, 1.00, "LARGE")
        // The step added in 0.6.4, without which capping the system control
        // would leave a low-vision user with no way up at all.
        expect(TextScale.huge.factor, 1.15, "HUGE")
        #expect(TextScale.allCases.count == 3)
    }

    @Test("current falls back to SMALL on absent and on garbage")
    func currentFallsBack() {
        let d = defaults()
        #expect(TextScale.current(in: d) == .small)
        d.set("ENORMOUS", forKey: TextScale.storageKey)
        #expect(TextScale.current(in: d) == .small)
        d.set("HUGE", forKey: TextScale.storageKey)
        #expect(TextScale.current(in: d) == .huge)
    }

    // MARK: - The first-launch seed

    @Test("seed maps the system step, once")
    func seedMapsSystemStep() {
        // 0 xSmall … 3 large (the iOS default) … 6 xxxLarge, 7+ accessibility.
        for (ordinal, want) in [(0, TextScale.small), (3, .small),
                                (4, .large), (6, .large),
                                (7, .huge), (11, .huge)] {
            let d = defaults()
            #expect(TextScale.seedIfUnset(systemOrdinal: ordinal, in: d) == want)
            #expect(TextScale.current(in: d) == want)
        }
    }

    @Test("seed never overrides a choice the user has made")
    func seedRespectsUser() {
        let d = defaults()
        d.set(TextScale.small.rawValue, forKey: TextScale.storageKey)
        // Someone at an accessibility system size who has deliberately picked
        // SMALL keeps SMALL — this is the whole reason the seed writes the
        // stored value once instead of taking max(stored, system) forever, which
        // would leave the settings picker showing one thing and the app doing
        // another.
        #expect(TextScale.seedIfUnset(systemOrdinal: 11, in: d) == nil)
        #expect(TextScale.current(in: d) == .small)
    }

    @Test("seed is idempotent")
    func seedRunsOnce() {
        let d = defaults()
        #expect(TextScale.seedIfUnset(systemOrdinal: 7, in: d) == .huge)
        #expect(TextScale.seedIfUnset(systemOrdinal: 0, in: d) == nil)
        #expect(TextScale.current(in: d) == .huge)
    }
}
