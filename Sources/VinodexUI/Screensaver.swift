#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The Vinodex V (0.7.3, A5).
///
/// **Drawn here, from scratch**, for the same reason `SkinSigil` is: a mark that
/// bounces around a screen is the most-looked-at thing in the app while it is
/// up, and the one shape that must unambiguously be *ours*. The brief names the
/// bounce as a familiar idea and is explicit that the familiar logo is not to be
/// reproduced — so what bounces is the wordmark's own initial, and nothing about
/// this file, its names or its geometry refers to anything else.
///
/// The letterform is the chevron the wordmark's V already is: two strokes down
/// to a point, cut square at the top and mitred at the bottom, with the interior
/// notch making it a V rather than a triangle. Proportions are in unit space and
/// scaled to the rect, so it is the same letter at any size.
struct VinodexV: Shape {
    /// Stroke width as a fraction of the mark's width. Heavy — this is read at
    /// a glance across a room in demo mode, and a hairline V reads as a crack in
    /// the screen.
    var weight: CGFloat = 0.30

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let t = w * weight

        var path = Path()
        // Outer left shoulder, down to the point, and back up the outer right.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + t, y: rect.minY))
        // The interior notch: the inner edges meet a little above the outer
        // point, which is what gives the letter a mitre instead of a spike.
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.66))
        path.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + t * 0.16, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - t * 0.16, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The idle screensaver (0.7.3, A5).
///
/// Appears at fifteen seconds of inactivity, via the app's one idle timer (F2),
/// and leaves on any input — which needs no wiring of its own, because the same
/// touch that would dismiss it has already reset the timer through
/// `IdleTouchWatcher` before this view hears anything.
///
/// **Why this device needs one at all.** `ScreenWake.keepAwake(true)` pins
/// `isIdleTimerDisabled`, so iOS never dims the display — a reference app gets
/// consulted with wet hands and a bottle in the other one, and a screen that
/// sleeps mid-lookup is useless. The cost is that a forgotten Vinodex holds one
/// static image at full brightness indefinitely, which is precisely the
/// condition screensavers were invented for.
///
/// **Position is a pure function of time** — see `ScreensaverBounce`. A
/// `TimelineView` hands this the current date, it asks Core where the mark is,
/// and nothing is stored between frames. That is what keeps the mark inside its
/// box after an hour instead of drifting out of it.
struct Screensaver: View {
    /// When the screensaver appeared, so the mark starts in the corner rather
    /// than wherever a global clock happens to be.
    let since: Date

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    /// The mark's size relative to the shorter edge of the LCD. Big enough to
    /// read across a room, small enough that the travel is most of the screen.
    private static let markFraction: CGFloat = 0.22

    /// The hues the mark cycles through on each bounce.
    ///
    /// Taken from the LCD's own accent and the app's chip palette rather than a
    /// rainbow: the screensaver still has to look like this device's screen, and
    /// a saturated spectrum over an amber phosphor reads as a fault. The
    /// monochrome modes flatten it anyway — the LCD's `grayscale`/`colorMultiply`
    /// pass sits above this view — so on VINTAGE and AMBER the mark simply
    /// changes value, which is the correct answer for a one-colour display.
    private var palette: [Color] {
        [lcd.accent, Dex.red500, Dex.amber400, Dex.green500, Dex.blue, Dex.cyan300]
    }

    var body: some View {
        GeometryReader { geo in
            let box = geo.size
            let side = min(box.width, box.height) * Self.markFraction
            // A V is wider than it is tall by a little; keeping the box square
            // and letting the shape fill it would squash the letter.
            let mark = CGSize(width: side, height: side * 1.05)

            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(since)
                let spot = ScreensaverBounce.origin(
                    at: t,
                    bounds: (width: box.width, height: box.height),
                    mark: (width: mark.width, height: mark.height)
                )
                let hits = ScreensaverBounce.bounces(
                    by: t,
                    bounds: (width: box.width, height: box.height),
                    mark: (width: mark.width, height: mark.height)
                )

                VinodexV()
                    .fill(palette[hits % palette.count])
                    .frame(width: mark.width, height: mark.height)
                    .position(x: spot.x + mark.width / 2, y: spot.y + mark.height / 2)
            }
        }
        // The LCD, blanked. Not translucent: a screensaver you can read the app
        // through is a dimmer, and the point is that no static image stays lit.
        .background(lcd.screen)
        // **Swallows the touch that dismisses it.** The dismissal itself is
        // already handled — `IdleTouchWatcher` saw the touch on the window
        // before this view did, and the stage has dropped to `.active` — but
        // without this the same tap would also press whatever button is
        // underneath, so waking the device would fire a navigation the user
        // never chose. An empty `onTapGesture` is the cheapest absorber, and it
        // exists only while the screensaver is mounted, so it competes with
        // nothing: there is no screen behind it that is still interactive.
        .contentShape(Rectangle())
        .onTapGesture {}
        .transition(.opacity)
        .accessibilityHidden(true)
    }
}
#endif
