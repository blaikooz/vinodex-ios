import Testing
@testable import VinodexCore

/// The LCD back swipe's opt-out (0.6.8, I1/I2).
///
/// Worth a suite because the gate is a *global* the whole app's back navigation
/// hangs off, and every failure mode of it is silent: latched shut and the swipe
/// stops working app-wide with nothing on screen to say so; latched open and it
/// fires underneath the globe's own drag. Neither shows up in a build.
///
/// `BackSwipeGate` is `@MainActor`, so the suite is too.
@Suite("Back-swipe gate")
@MainActor
struct BackSwipeGateTests {
    /// A fresh instance per test rather than `.shared` — these tests would
    /// otherwise leak suspensions into each other, which is precisely the bug
    /// class they exist to catch.
    private func gate() -> BackSwipeGate {
        let gate = BackSwipeGate.shared
        // Drain whatever a previous test or the app left behind. `resume`
        // clamps at zero, so over-draining is safe.
        for _ in 0..<8 { gate.resume() }
        return gate
    }

    @Test("enabled by default")
    func defaultsOn() {
        #expect(gate().isEnabled)
    }

    @Test("a suspension closes the gate and its resume reopens it")
    func roundTrip() {
        let gate = gate()
        gate.suspend()
        #expect(!gate.isEnabled)
        gate.resume()
        #expect(gate.isEnabled)
    }

    /// The globe is mounted twice — its own route and the scanner's origin step
    /// — and nested appear/disappear cycles can interleave. A boolean would
    /// reopen the gate on the first `resume` while the outer screen was still
    /// up.
    @Test("nested suspensions need matching resumes")
    func nests() {
        let gate = gate()
        gate.suspend()
        gate.suspend()
        gate.resume()
        #expect(!gate.isEnabled, "one resume must not undo two suspends")
        gate.resume()
        #expect(gate.isEnabled)
    }

    /// A view whose `onDisappear` runs without its `onAppear` having done
    /// (SwiftUI does this on some teardown paths) must not drive the count
    /// negative — that would take N extra suspends to close the gate again.
    @Test("an unmatched resume cannot latch the gate open")
    func clampsAtZero() {
        let gate = gate()
        gate.resume()
        gate.resume()
        gate.suspend()
        #expect(!gate.isEnabled, "one suspend must still close it")
        gate.resume()
        #expect(gate.isEnabled)
    }
}
