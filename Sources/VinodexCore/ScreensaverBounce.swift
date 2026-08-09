import Foundation

/// Where the bouncing mark is at a given moment (0.7.3, A5).
///
/// **A closed form, not a simulation.** The obvious implementation keeps a
/// velocity and a position and steps them every frame, and it has two problems
/// this does not: it drifts (floating-point error accumulates over the minutes a
/// screensaver actually runs, and the mark walks out of its box), and it is
/// untestable from Linux because the thing you would test is a frame loop in a
/// view. A position that is a pure function of elapsed time has neither problem
/// — `TimelineView` hands the view a date, the view asks for a point, and a test
/// can ask for the point at t = 10,000 seconds and get an exact answer.
///
/// The path is the classic one: constant velocity, perfect reflection off all
/// four walls, no gravity and no damping. On each axis independently that is a
/// triangle wave, which is what `fold` computes.
/// Where the mark starts, as a phase on each axis (0.7.6, A2).
///
/// **A phase, not a point, so the closed form survives.** A2 asks for the logo to
/// begin somewhere different each time the screensaver appears. The obvious
/// implementation seeds a position and a velocity and steps them — which is
/// exactly the per-frame simulation `ScreensaverBounce`'s own header rejects, and
/// reintroducing it to get a random corner would trade a testable pure function
/// for drift.
///
/// A phase costs nothing instead. The path on each axis is a triangle wave with
/// period `2 × travel`, so *any* start position and *either* direction is
/// reachable by shifting `t` along that wave: a phase in `[0, 1)` selects a point
/// on the cycle, the first half of which is travelling one way and the second the
/// other. So a single random pair gives a random position **and** a random
/// heading, the position stays a pure function of time, and the whole thing is
/// still exact at t = 10,000 seconds.
///
/// `corner` is the old behaviour — both phases zero, mark in the top-left — and
/// is what every test that predates this asserts against.
public struct ScreensaverStart: Sendable, Equatable {
    /// Both in `[0, 1)`. Wrapped rather than clamped on the way in, so a caller
    /// doing arithmetic on one cannot produce a phase that folds oddly.
    public let x: Double
    public let y: Double

    /// The top-left corner, travelling down and right — the start every
    /// screensaver had through 0.7.5.
    public static let corner = ScreensaverStart(x: 0, y: 0)

    public init(x: Double, y: Double) {
        self.x = Self.wrap(x)
        self.y = Self.wrap(y)
    }

    /// A fresh start position. Called once when the screensaver is raised, not
    /// per frame — see `Screensaver`.
    public static func random() -> ScreensaverStart {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    /// The injectable form, so a test can pin a phase without owning the clock.
    public static func random(using generator: inout some RandomNumberGenerator) -> ScreensaverStart {
        ScreensaverStart(
            x: Double.random(in: 0..<1, using: &generator),
            y: Double.random(in: 0..<1, using: &generator)
        )
    }

    private static func wrap(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        let phase = value.truncatingRemainder(dividingBy: 1)
        return phase < 0 ? phase + 1 : phase
    }
}

public enum ScreensaverBounce: Sendable {
    /// Points per second on each axis.
    ///
    /// Different per axis, and coprime-ish rather than equal, so the mark traces
    /// a long path that does not repeat quickly. Equal speeds send it round a
    /// short diagonal loop and back to where it started every few seconds, which
    /// reads as a bug.
    public static let velocity = (x: 47.0, y: 31.0)

    /// A triangle wave: a value walking up from 0 to `span` and back, forever.
    ///
    /// The whole of the reflection. `span` here is the *travel* — the box minus
    /// the mark — so a fold at the top of the range puts the mark's far edge
    /// exactly on the wall.
    ///
    /// Guards a non-positive span: a box smaller than the mark it holds has no
    /// travel, and the modulo below would divide by zero rather than say so.
    static func fold(_ distance: Double, span: Double) -> Double {
        guard span > 0 else { return 0 }
        let cycle = span * 2
        // `truncatingRemainder` can go negative for a negative input; the
        // caller only ever passes a non-negative distance, and this keeps that
        // from being load-bearing.
        var phase = distance.truncatingRemainder(dividingBy: cycle)
        if phase < 0 { phase += cycle }
        return phase <= span ? phase : cycle - phase
    }

    /// How far along its own axis the mark has travelled by `time`, including
    /// the head start `start` gives it (0.7.6, A2).
    ///
    /// The offset is `phase × cycle`, i.e. a whole triangle wave scaled by the
    /// phase — which is why a phase of 0.5 puts the mark back at the same wall it
    /// started from but heading the other way, and why any phase in between lands
    /// somewhere real. One helper rather than the expression twice, because
    /// `origin` and `bounces` must agree about it exactly or the colour would
    /// change somewhere other than at a wall.
    static func distance(
        at time: TimeInterval,
        velocity: Double,
        span: Double,
        phase: Double
    ) -> Double {
        max(time, 0) * velocity + phase * span * 2
    }

    /// The mark's top-left corner at `time` seconds into the screensaver.
    ///
    /// - Parameters:
    ///   - time: seconds since the screensaver appeared. Negative is clamped.
    ///   - bounds: the LCD's interior.
    ///   - mark: the bouncing mark's size.
    ///   - start: where on each axis's cycle the run began (0.7.6, A2).
    ///     Defaults to `.corner`, which is the pre-0.7.6 path exactly.
    public static func origin(
        at time: TimeInterval,
        bounds: (width: Double, height: Double),
        mark: (width: Double, height: Double),
        from start: ScreensaverStart = .corner
    ) -> (x: Double, y: Double) {
        let spanX = bounds.width - mark.width
        let spanY = bounds.height - mark.height
        return (
            x: fold(distance(at: time, velocity: velocity.x, span: spanX, phase: start.x), span: spanX),
            y: fold(distance(at: time, velocity: velocity.y, span: spanY, phase: start.y), span: spanY)
        )
    }

    /// How many walls have been hit by `time`, on both axes together.
    ///
    /// Drives the colour change — the mark takes a new hue on every bounce, which
    /// is the half of the effect people actually remember. Counting rather than
    /// detecting means the colour is a pure function of time too, so it cannot
    /// drift out of step with the position it is supposed to have changed at.
    ///
    /// **Counted from the start rather than from the origin** (0.7.6, A2): the
    /// walls a non-zero phase has notionally already passed are subtracted, so a
    /// run that begins mid-flight still begins on `palette[0]` and takes its
    /// second colour at its own first real bounce. Without the subtraction a
    /// random start would also pick a random opening colour, which is a second
    /// piece of randomness A2 did not ask for and which would make the palette's
    /// deliberate first entry — the LCD's own accent — a one-in-six event.
    public static func bounces(
        by time: TimeInterval,
        bounds: (width: Double, height: Double),
        mark: (width: Double, height: Double),
        from start: ScreensaverStart = .corner
    ) -> Int {
        let travelX = bounds.width - mark.width
        let travelY = bounds.height - mark.height
        return walls(at: time, velocity: velocity.x, span: travelX, phase: start.x)
            + walls(at: time, velocity: velocity.y, span: travelY, phase: start.y)
    }

    /// Walls hit on one axis between the start and `time`.
    ///
    /// One bounce per half-cycle. `floor` and not `rounded`: the wall at the
    /// exact instant of contact has not been left yet.
    private static func walls(
        at time: TimeInterval,
        velocity: Double,
        span: Double,
        phase: Double
    ) -> Int {
        guard span > 0 else { return 0 }
        let now = distance(at: time, velocity: velocity, span: span, phase: phase)
        let began = distance(at: 0, velocity: velocity, span: span, phase: phase)
        return Int((now / span).rounded(.down)) - Int((began / span).rounded(.down))
    }
}
