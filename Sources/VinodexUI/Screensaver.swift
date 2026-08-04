#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The wordmark's two tinted layers, loaded once (0.7.5, A5).
///
/// **Cached in statics because the screensaver redraws at display rate.** The
/// mark's position is a function of time inside a `TimelineView`, so the body
/// below is re-evaluated every frame; `LogoMark` reads its PNG off disk on each
/// render, which is fine for a still on the back plate and would be sixty file
/// reads a second here.
///
/// `Resources/Logo` rather than `Resources/Icons` on purpose. `IconLoader` is
/// the wrong door for a hand-made asset twice over: it resolves ids through
/// `IconManifest.slug`, which is an Iconify convention this file has no id in,
/// and `rasterize-icons.sh` **deletes** any PNG in `Resources/Icons` that the
/// generated `icons.json` does not list — so an asset parked there would
/// survive exactly until the next `npm run icons`. `Resources/Logo` is outside
/// that prune and already holds the wordmark.
///
/// Both layers are `.alwaysTemplate`: the shipped PNGs are white-on-alpha
/// silhouettes and every colour they wear comes from `foregroundStyle` at the
/// call site. See `scripts/import-logo-art.py` for why the mark ships as two
/// masks rather than as the master's own white-and-grey.
@MainActor
enum ScreensaverMarkArt {
    static let face: UIImage? = load("vinodex-mark-face")
    static let shade: UIImage? = load("vinodex-mark-shade")

    /// Whether the mark can be drawn at all. False means a build shipped
    /// without the two PNGs, which `LogoLayerTests` exists to catch first.
    static var isAvailable: Bool { face != nil && shade != nil }

    /// Width over height, taken from the art rather than written down, so a
    /// re-import at a different size cannot leave the bounce box stretched.
    /// Falls back to the fallback shape's own proportion.
    static var aspect: CGFloat {
        guard let size = face?.size, size.height > 0 else { return 1 / 1.05 }
        return size.width / size.height
    }

    private static func load(_ name: String) -> UIImage? {
        guard let url = DexResources.url(named: name, ext: "png", subdirectory: "Resources/Logo"),
              let image = UIImage(contentsOfFile: url.path)
        else { return nil }
        return image.withRenderingMode(.alwaysTemplate)
    }
}

/// The bouncing mark (0.7.5, A5) — the wordmark itself, in two tinted layers.
///
/// **Supersedes 0.7.3a's drawn placeholder.** That release had no logo asset in
/// the tree, so it drew the wordmark's initial from scratch; `VinodexV` below is
/// still here, now as the fallback rather than as the mark.
///
/// The two layers are the master's lit face and its extruded edge, split on
/// luminance at import time. They are tinted separately here rather than shipped
/// pre-coloured because this is drawn on the LCD, whose ink the user chooses —
/// baking the master's white and grey into the PNGs would put two fixed colours
/// on a screen that has twenty-one colourways, and would look wrong on all of
/// them the moment the phosphor is not white.
///
/// `.interpolation(.none)`: the mark is pixel art with hard edges, and the
/// import deliberately re-thresholds alpha after downscaling to keep them.
struct ScreensaverMark: View {
    /// The face colour. The shade is derived from it, so a bounce changes both
    /// together and the relief never comes from two unrelated hues.
    let tint: Color

    var body: some View {
        if let face = ScreensaverMarkArt.face, let shade = ScreensaverMarkArt.shade {
            ZStack {
                Image(uiImage: shade)
                    .resizable()
                    .interpolation(.none)
                    // Not a second colour: the same ink, dimmed. On the
                    // monochrome modes the whole LCD collapses to one phosphor
                    // anyway, and an opacity step is the only depth cue that
                    // survives that pass.
                    .foregroundStyle(tint.opacity(0.45))
                Image(uiImage: face)
                    .resizable()
                    .interpolation(.none)
                    .foregroundStyle(tint)
            }
        } else {
            // Visible on purpose, exactly as `DexIcon`'s missing-glyph branch
            // is: a mark that failed to load must not be an empty box bouncing
            // silently around the screen. This is 0.7.3a's drawn letterform,
            // which needs no asset and cannot fail.
            VinodexV().fill(tint)
        }
    }
}

/// The drawn wordmark initial (0.7.3, A5; the fallback since 0.7.5, A5).
///
/// **Drawn here, from scratch**, for the same reason `SkinSigil` is: a mark that
/// bounces around a screen is the most-looked-at thing in the app while it is
/// up, and the one shape that must unambiguously be *ours*. The brief names the
/// bounce as a familiar idea and is explicit that the familiar logo is not to be
/// reproduced — so what bounces is the wordmark's own initial, and nothing about
/// this file, its names or its geometry refers to anything else. That still
/// holds now that the real wordmark has arrived: it is *our* mark, and no name
/// in this file, in the shipped PNGs or in any string the app prints says
/// otherwise.
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
/// Appears at thirty seconds of inactivity (0.7.6, A3), via the app's one idle
/// timer (F2), and leaves on any input — which needs no wiring of its own,
/// because the same touch that would dismiss it has already reset the timer
/// through `IdleTouchWatcher` before this view hears anything.
///
/// **The marquee greets you at the same instant since 0.7.6 (A4).** That is the
/// chassis's business rather than this view's — see `DeviceChassis.footerText` —
/// but it is worth knowing here that the screensaver and the toast are now one
/// event on one threshold rather than two stages twenty seconds apart.
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
    /// When the screensaver appeared, so the mark's path is measured from this
    /// run rather than from wherever a global clock happens to be.
    let since: Date

    /// Where on each axis's cycle this run began (0.7.6, A2).
    ///
    /// Passed in rather than drawn here, and that is load-bearing: this view's
    /// body runs inside a `TimelineView` at display rate, so a `random()` call in
    /// it would re-roll sixty times a second and the mark would sit still. The
    /// chassis rolls it once, when the screensaver is raised, and holds it in
    /// `@State` for the life of the run. Defaulted so a caller that has no opinion
    /// gets 0.7.5's top-left corner exactly.
    var start: ScreensaverStart = .corner

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
            // The mark is wider than it is tall; keeping the box square and
            // letting it fill would squash the wordmark. The ratio comes from
            // the art (see `ScreensaverMarkArt.aspect`) rather than from a
            // literal here, so re-importing at a different size cannot leave
            // the bounce box the wrong shape — which is a fault nothing would
            // catch, because a stretched logo still bounces correctly.
            let mark = CGSize(width: side * ScreensaverMarkArt.aspect, height: side)

            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(since)
                let spot = ScreensaverBounce.origin(
                    at: t,
                    bounds: (width: box.width, height: box.height),
                    mark: (width: mark.width, height: mark.height),
                    from: start
                )
                let hits = ScreensaverBounce.bounces(
                    by: t,
                    bounds: (width: box.width, height: box.height),
                    mark: (width: mark.width, height: mark.height),
                    from: start
                )

                ScreensaverMark(tint: palette[hits % palette.count])
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
