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

    /// The mark's top-left corner at `time` seconds into the screensaver.
    ///
    /// - Parameters:
    ///   - time: seconds since the screensaver appeared. Negative is clamped.
    ///   - bounds: the LCD's interior.
    ///   - mark: the bouncing mark's size.
    public static func origin(
        at time: TimeInterval,
        bounds: (width: Double, height: Double),
        mark: (width: Double, height: Double)
    ) -> (x: Double, y: Double) {
        let t = max(time, 0)
        return (
            x: fold(t * velocity.x, span: bounds.width - mark.width),
            y: fold(t * velocity.y, span: bounds.height - mark.height)
        )
    }

    /// How many walls have been hit by `time`, on both axes together.
    ///
    /// Drives the colour change — the mark takes a new hue on every bounce, which
    /// is the half of the effect people actually remember. Counting rather than
    /// detecting means the colour is a pure function of time too, so it cannot
    /// drift out of step with the position it is supposed to have changed at.
    public static func bounces(
        by time: TimeInterval,
        bounds: (width: Double, height: Double),
        mark: (width: Double, height: Double)
    ) -> Int {
        let t = max(time, 0)
        let travelX = bounds.width - mark.width
        let travelY = bounds.height - mark.height
        // One bounce per half-cycle on each axis. `floor` and not `rounded`: the
        // wall at the exact instant of contact has not been left yet.
        let x = travelX > 0 ? Int((t * velocity.x / travelX).rounded(.down)) : 0
        let y = travelY > 0 ? Int((t * velocity.y / travelY).rounded(.down)) : 0
        return x + y
    }
}
