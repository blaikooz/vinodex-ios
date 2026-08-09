#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

// MARK: - MarqueeBanner

// The dot-matrix marquee band and its script.

/// The title panel — the centrepiece of the button band.
///
/// **It does not scroll (0.6.9, D1).** From 0.5.1 through 0.6.8 this ported the
/// web app's `terminal-marquee`: two copies of the label offset by one measured
/// cycle, animated off a `TimelineView` clock, with a gradient mask at each end
/// so the letters read as passing behind the housing rather than being
/// guillotined by the clip. D1 retires the whole mechanism. What is left is the
/// form PR #11's M18 already built for Reduce Motion — a still, centred,
/// fitted label — promoted from the accessibility branch to the only branch.
///
/// Deleting rather than disabling the scroll is the point. Keeping both alive
/// behind a flag would leave the measured `copyWidth`, the two-copy `HStack`,
/// the end fade and the timeline clock as code nothing reaches, and every one of
/// those is a thing this file has previously lost a round to (audit M8, M9, and
/// the 0.6.6 C2 fade). Gone with it: `pointsPerSecond`, `copyWidth`, `gap`,
/// `label`, `endFade` and `DexMetrics.marqueeFade`.
///
/// What the still form gains is room. A scrolling strip could only ever be one
/// line of one size, because the scroll was what revealed the tail; a fixed
/// label can wrap, can be set much larger (D4), and has space above it for the
/// page's own glyph at a size worth looking at (D2). And a panel that is not
/// moving can say something *else* on the main screen — see the greeting cycle
/// below (D3).
///
/// **Lit, not backlit, since 0.6.5 (B1).** It used to be a black strip with the
/// skin's phosphor glowing on it, which is a VFD; the mockup's centrepiece is a
/// green *panel* with its letters dark — a segment LCD, where the ground is what
/// lights and the glyphs are what the liquid crystal blocks. So the two colours
/// swap: `marqueeText` fills the panel and `marqueeShadow` cuts the letters out
/// of it. Every skin follows, since both were already per-skin — CLASSIC's green
/// phosphor is what makes the panel green, and NOCTURNE's or BLUSH's panel is
/// its own colour rather than a green one bolted onto the wrong shell.
///
/// **What it says is scripted now (0.7.1, B1-B3).** 0.6.9's D3 gave the main
/// screen five toasts on an endless 2.6-second cycle. B1-B3 replace the loop
/// with three states and an end — WELCOME! on launch, MENU while you are using
/// it, CHEERS! after ten seconds of not — and the state machine that decides
/// between them is `MarqueeScript` in Core, where a Linux gate can see it. The
/// banner keeps the clock and the pixels; it does not keep the rules.
public struct MarqueeBanner: View {
    /// The words on the panel. One string since 0.7.1 (B1): the five-toast
    /// list and the `index` that walked it are gone with the cycle, and the
    /// main screen now passes whichever of `MarqueeScript`'s three stages is
    /// current, exactly as every other screen passes its title.
    let text: String
    /// SF Symbol for the page, drawn **above** the title since 0.6.9 (D2) at
    /// `DexMetrics.marqueeGlyph` — or beside it, where `glyphBeside` says so
    /// (0.7.2, A3). It used to be stamped inline after the words (v0.5.7, E2),
    /// which was the only place a scrolling single line had for it. Nil runs
    /// text-only and the label takes the whole panel.
    let symbol: String?
    /// The drawn button face for `symbol`, or nil where the route has none
    /// (0.8.3, A). See `DexRoute.marqueeArt`.
    var art: String?
    let fontSize: CGFloat
    /// Freezes the transition (AUDIT M8, through D3, still true). The panel is
    /// inside the front face, which the flip merely hides at `opacity 0` — a
    /// dissolve left running behind an opaque metal back plate is a clock
    /// nobody can see, and it would be halfway through when the device came
    /// back over.
    var paused: Bool = false

    /// Whether this change gets the *long* dissolve (0.7.1 B2; renamed and
    /// narrowed 0.8.5, A3).
    ///
    /// **Every change dissolves now. This only chooses how long it takes.**
    /// Through 0.8.4 the flag decided *whether* to pixelate at all, and only the
    /// main screen passed true. The argument was: B2 asks for the slow pixelated
    /// fade between the scripted stages, and running it on every route title too
    /// would put a 1.4-second dissolve in front of every navigation in the app,
    /// which is not a transition, it is a wait.
    ///
    /// A3 asks for the dissolve on every change of the panel, and that argument
    /// does not survive it — but it was never an argument about the *effect*, it
    /// was an argument about the *duration*, and it had been settled by
    /// conflating the two. So the two come apart: the banner always dissolves,
    /// and `DexMetrics.marqueeRoutePixelFade` is what a page title costs.
    ///
    /// That is also the honest reading of what the panel is. It is a dot-matrix
    /// display; a dot-matrix display repaints by cell whatever it is repainting
    /// to, and a cross-fade was the one thing on this chassis that behaved like
    /// software. Both timings live in `DexMetrics` rather than here, per F3.
    var slowFade: Bool = false

    /// Draw the glyph beside the word rather than above it (0.7.2, A3).
    ///
    /// Extra horizontal room the label must leave at each end (0.7.2, A7).
    ///
    /// The pinned-app buttons sit in the panel's two top corners, and they are
    /// drawn by the chassis as siblings *over* this view rather than inside it —
    /// a button nested in another button's label is not a control, it is a
    /// picture. So the banner cannot see them, and without being told it would
    /// happily set CONTINENTS the full width of the panel and straight under
    /// them. This is that telling: the chassis passes the width it is about to
    /// cover, and the label treats it as unusable.
    ///
    /// Zero when nothing is pinned, so a device with no pins loses no width at
    /// all — the reserve exists only when there is something to reserve for.
    var edgeReserve: CGFloat = 0

    /// The string currently drawn. Distinct from `text` for exactly the length
    /// of a dissolve, during which both are on the panel at once.
    @State private var shown = ""
    /// The string being dissolved *out*, or nil when the panel is at rest.
    @State private var outgoing: String?
    /// The glyph's half of the same pair (0.8.1, H2). The symbol changes in the
    /// same update as the text — both derive from the route — so it is carried
    /// through `change(to:)` rather than watched separately, and the two halves
    /// of the panel cannot start their dissolves a frame apart.
    @State private var shownSymbol: String?
    @State private var outgoingSymbol: String?
    /// The drawn face's stem, carried alongside the symbol (0.8.3, A) for the
    /// reason the symbol is carried alongside the text: all three derive from
    /// the route and change in one update, so a stem watched separately could
    /// start its dissolve a frame out of step with the glyph it belongs to.
    @State private var shownArt: String?
    @State private var outgoingArt: String?
    /// When the running dissolve began; nil at rest, which is also the
    /// `TimelineView`'s pause condition.
    @State private var fadeStart: Date?

    /// Resolved in `init`, not per access (AUDIT M8): `DexFont.retro` reads
    /// `TextScale.current`, which is a `UserDefaults` lookup, and `body` is
    /// rebuilt on every skin or cycle change. `DeviceChassis` is `.id`-keyed on
    /// the text scale, so a change rebuilds this view rather than needing it
    /// re-read.
    private let segmentFont: Font

    /// The strip's phosphor follows the shell — see `ChassisSkin.marqueeText` —
    /// unless the workshop has fitted a different one (0.7.3, B1).
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    @AppStorage(DeviceAxis.marquee.storageKey) private var partMarquee = ""
    /// Read here rather than passed in by `DeviceChassis` so the banner keeps
    /// working wherever else it is mounted. (AUDIT M18)
    ///
    /// Its job changed in 0.6.9. It used to choose between the scrolling and
    /// still forms; the still form is now the only one, so what is left for it
    /// to gate is the greeting cycle — see `cycle()`.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var skin: ChassisLook {
        ChassisLook(skinRaw: skinRaw, marquee: partMarquee)
    }

    /// The lit ground: the skin's phosphor, filling the panel rather than the
    /// letters (0.6.5, B1).
    private var ground: Color { skin.marqueeText }

    /// The letters and the panel's rim — the very dark form of the phosphor,
    /// which is what a segment LCD's glyphs actually look like.
    private var ink: Color { skin.marqueeShadow }

    public init(
        text: String,
        symbol: String? = nil,
        art: String? = nil,
        fontSize: CGFloat,
        paused: Bool = false,
        slowFade: Bool = false,
        edgeReserve: CGFloat = 0
    ) {
        self.text = text
        self.symbol = symbol
        self.art = art
        self.fontSize = fontSize
        self.paused = paused
        self.slowFade = slowFade
        self.edgeReserve = edgeReserve
        self.segmentFont = DexFont.retro(fontSize)
    }

    public var body: some View {
        ZStack {
            panel
            content
        }
        .frame(height: DexMetrics.marqueeHeight)
        .onAppear {
            if shown.isEmpty { shown = text }
            shownSymbol = symbol
            shownArt = art
        }
        .onChange(of: text) { _, next in change(to: next) }
        // A symbol that moves without the text does not dissolve — there is no
        // pair to cross — but it must still not strand `shownSymbol` on the
        // previous route's glyph. Nothing in the app does this today; it costs
        // two lines to make sure nothing quietly starts.
        .onChange(of: symbol) { _, next in
            if fadeStart == nil {
                shownSymbol = next
                shownArt = art
            }
        }
        // Ends the dissolve. Keyed on the start instant, so a second change
        // arriving mid-dissolve cancels the pending teardown rather than
        // letting it fire late and clear the new one.
        .task(id: fadeStart) { await endFade() }
    }

    /// The panel's text changed under us.
    ///
    /// **Reduce Motion takes the dissolve, not the change.** A pixel dissolve
    /// is a large unprompted movement and is exactly what the setting asks to
    /// be spared; the cross-fade is the substitute Apple's own guidance offers
    /// for one, and it is what a title change has used here since D3.
    /// `PulseGlow` in this file makes the same distinction — the reduced branch
    /// settles on the most informative still state rather than simply refusing
    /// to update.
    private func change(to next: String) {
        guard shown != next else { return }
        // `paused` still refuses outright: the panel is behind an opaque back
        // plate and a dissolve nobody can see would be halfway through when the
        // device came back over. Reduce Motion still takes the cross-fade. A3
        // removes only the third condition, which was the panel's own opinion
        // about which of its changes were worth animating.
        guard !reduceMotion, !paused else {
            outgoing = nil
            outgoingSymbol = nil
            outgoingArt = nil
            fadeStart = nil
            withAnimation(.easeInOut(duration: DexMetrics.marqueeGreetingFade)) {
                shown = next
                shownSymbol = symbol
                shownArt = art
            }
            return
        }
        outgoing = shown
        shown = next
        outgoingSymbol = shownSymbol
        shownSymbol = symbol
        outgoingArt = shownArt
        shownArt = art
        fadeStart = .now
    }

    /// How long this dissolve runs (0.8.5, A3). See `slowFade`.
    private var fadeDuration: Double {
        slowFade ? DexMetrics.marqueePixelFade : DexMetrics.marqueeRoutePixelFade
    }

    private func endFade() async {
        guard fadeStart != nil else { return }
        try? await Task.sleep(for: .seconds(fadeDuration))
        guard !Task.isCancelled else { return }
        outgoing = nil
        outgoingSymbol = nil
        outgoingArt = nil
        fadeStart = nil
    }

    /// How far through the dissolve, smoothstepped.
    ///
    /// Eased rather than linear, and eased at both ends: a linear dissolve
    /// spends its whole duration flipping cells at a constant rate, which reads
    /// as noise turning on and then off. Easing gives it the two things that
    /// make it one deliberate event instead — a moment where the old word is
    /// still legible while the first cells go, and a moment where the new one
    /// is nearly whole while the last ones arrive. The same
    /// `p * p * (3 - 2p)` `DataWave` uses, for the same reason.
    private func fadeProgress(at date: Date) -> Double {
        guard let fadeStart else { return 1 }
        let linear = min(max(date.timeIntervalSince(fadeStart) / fadeDuration, 0), 1)
        return linear * linear * (3 - 2 * linear)
    }

    /// The lit plate itself: fill, segment grid, lamp gradient, rim, glow.
    private var panel: some View {
        RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner)
            .fill(ground)
            // The pixel grid sits on the lit ground rather than over black, so
            // it reads as the panel's own segment structure — `marqueeGrid` is
            // a register off the phosphor either way, so it still separates
            // from the fill.
            .overlay(
                DexGridBackground(spacing: 12, color: skin.marqueeGrid, opacity: 0.22)
                    .clipShape(RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner))
            )
            // A lit panel is brightest where the lamp behind it is: a touch of
            // ink settling toward the bottom is what stops the fill reading as
            // flat paint.
            .overlay(
                LinearGradient(
                    colors: [.clear, ink.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner)
                    .strokeBorder(ink.opacity(0.8), lineWidth: 2)
            )
            // The panel's own glow, spilling onto the chassis around it — the
            // one thing that says this is a display and not a green sticker.
            .shadow(color: ground.opacity(0.45), radius: 6)
    }

    /// The glyph over the title (0.6.9, D2/D4).
    ///
    /// The glyph is sized off the **panel**, not off the type: it is chrome,
    /// and a symbol that grew with SETTINGS > TEXT SIZE would push the words it
    /// is supposed to introduce off a panel whose height does not move. The
    /// words take whatever is left, and shrink into it.
    ///
    /// **One arrangement again (0.8.1, H1).** 0.7.2's A3 added a `glyphBeside`
    /// flag and set it on the main screen, arguing that MENU is four characters
    /// on a 225pt panel and stacking a glyph over them leaves a short word
    /// marooned under a big symbol with air either side. That observation was
    /// true and is now outweighed: the panel is the one part of the chassis
    /// whose layout the user sees change as they navigate, and it was changing
    /// *shape* — glyph beside on the menu, glyph above on every page — so the
    /// return home read as the panel rearranging itself rather than as its
    /// contents changing. H2 puts the glyph through the dissolve for the same
    /// reason: one transition, not a transition plus a reflow. The flag and its
    /// branch are gone rather than left passing `false`, because a layout switch
    /// nothing selects is a switch that will be re-selected by accident.
    ///
    /// **The glyph slot only exists when there is a glyph** (0.8.91, G2).
    ///
    /// §G2 reports the screensaver toast off-centre, and this stack is why. The
    /// greetings carry no symbol — `footerSymbol` and `footerArt` both return
    /// nil while the script is at `.cheers` — but the slot was unconditional, so
    /// the panel still paid `marqueeGlyphGap` for a child with nothing in it.
    /// At rest that is a nil-optional child and SwiftUI mostly forgives it; on
    /// the way *in* to CHEERS! it is a live `TimelineView` wrapping two empty
    /// glyphs, which is a real view with a real slot, and the word sat four
    /// points low for the whole 1.4-second dissolve — the one moment the toast
    /// is being looked at.
    ///
    /// Gating the child *and* the spacing rather than only the child, because a
    /// `VStack` with one child and a spacing still reserves nothing but a
    /// `VStack` with two children one of which measures zero reserves the gap.
    /// One condition, both terms.
    private var content: some View {
        VStack(spacing: hasGlyph ? DexMetrics.marqueeGlyphGap : 0) {
            if hasGlyph { glyph }
            title
        }
        .padding(.horizontal, DexMetrics.marqueeTextInset + edgeReserve)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A guard rather than a mechanism: the label is fitted, so nothing
        // should reach this. If a future title does, it is cut at the panel's
        // rim like a display clipping an oversized image, not spilled onto the
        // moulding.
        .clipShape(RoundedRectangle(cornerRadius: DexMetrics.marqueeInnerCorner))
    }

    /// The page glyph, or nothing (0.6.9, D2; extracted 0.7.2, A3).
    ///
    /// **Dissolves with the title since 0.8.1 (H2).** The title had the pixel
    /// transition and the glyph above it cut instantly, so returning home was
    /// one part of the panel dissolving while the other part next to it
    /// snapped — which reads as the dissolve failing rather than as two
    /// different treatments. Same clock, same `fadeStart`, so the two
    /// `TimelineView`s cannot drift; the cell size differs because the cell is
    /// a fraction of what it is dissolving, and the glyph is not the type.
    /// Whether either side of a dissolve has a symbol. Both, not just the
    /// incoming one — a glyph on its way out still needs somewhere to be.
    private var hasGlyph: Bool { shownSymbol != nil || outgoingSymbol != nil }

    @ViewBuilder
    private var glyph: some View {
        if fadeStart == nil {
            glyphImage(shownSymbol, art: shownArt)
        } else {
            TimelineView(.animation) { context in
                let p = fadeProgress(at: context.date)
                ZStack {
                    glyphImage(outgoingSymbol, art: outgoingArt)
                        .mask(PixelDissolve(progress: p, cell: glyphFadeCell, incoming: false))
                    glyphImage(shownSymbol, art: shownArt)
                        .mask(PixelDissolve(progress: p, cell: glyphFadeCell, incoming: true))
                }
            }
        }
    }

    /// One glyph, or nothing at all — the toasts carry no symbol, so a nil here
    /// is a normal state of the panel rather than a missing asset.
    ///
    /// **The dot-matrix marquee glyph, in the panel's own ink (0.8.4, A).** The
    /// stem travels beside the symbol — see `DexRoute.marqueeArt` — and
    /// `DexChromeGlyph` resolves the pair the way every other converted control
    /// does: the drawing where there is one, the SF Symbol where there is not.
    ///
    /// **`ink`, not black, and this is A2 reversing 0.8.3's A.** That item
    /// argued the glyph must be black because a segment LCD's ink is what blocks
    /// light, and it was right about the *material* and wrong about the colour:
    /// what blocks light on this panel is not black, it is `skin.marqueeShadow`
    /// — a very dark register of each skin's own phosphor, which is exactly what
    /// the letters beside the glyph are drawn in. So the old rule produced a
    /// glyph that was nearly the text colour on twenty-one skins and never quite
    /// it, which is the worst of both: too close to read as a deliberate
    /// contrast, far enough to read as a different material sitting on the same
    /// panel.
    ///
    /// A2 asks for the two to recolour together, and `ink` is that in the
    /// strongest available form — not a matching value, the same expression the
    /// label reads. A skin that changes its marquee phosphor moves both in one
    /// edit, and the SF Symbol fallback below has always taken `ink` too, so a
    /// route with a face and a route without now agree for the first time.
    ///
    /// `flatten:` rather than a loader is unchanged and still right: these are
    /// silhouettes by construction (`import-marquee-art.py` throws the colour
    /// away and keeps the alpha), and `ChassisCapLoader`'s value-preserving
    /// re-ink has nothing to preserve here.
    ///
    /// **`smoothing:` is the one thing the new drop needs that the old did not**
    /// — see `DexChromeGlyph.smoothing`. These are drawn circles, and
    /// nearest-neighbour at the fitted scale turns an even grid into an uneven
    /// one.
    @ViewBuilder
    private func glyphImage(_ name: String?, art: String?) -> some View {
        if let name {
            DexChromeGlyph(
                art ?? name,
                symbol: name,
                size: DexMetrics.marqueeGlyph,
                weight: .bold,
                tint: ink,
                flatten: ink,
                smoothing: true
            )
            .shadow(color: ground.opacity(0.7), radius: 0, x: 1, y: 1)
        }
    }

    /// Coarser than the title's, for the same reason `fadeCell` is coarser than
    /// the font's own grid: a symbol is one large shape, and cells fine enough
    /// to suit 28pt letterforms read as the glyph eroding rather than
    /// dissolving.
    private var glyphFadeCell: CGFloat { max(DexMetrics.marqueeGlyph * 0.22, 3) }

    /// The title, wrapped and fitted (0.6.9, D2).
    ///
    /// Three fallbacks in order, which is what "wrap or adjust the text to fit"
    /// costs at 28pt in a pixel face on a ~225pt panel:
    ///
    /// 1. **Soft hyphens** (`EntryDisplay.hyphenated`) so a single long word
    ///    can break at all — SwiftUI's `Text` exposes no hyphenation setting,
    ///    so CONTINENTS or SAUVIGNON would otherwise be one unbreakable run.
    ///    Already proven in this typeface: the entry chips have used it since
    ///    v0.5.7.
    /// 2. **Two lines**, which is what the panel's height affords once the
    ///    glyph is out of it. DAILY CHALLENGE breaks at its space and reads
    ///    better stacked than it ever did scrolling past.
    /// 3. **`minimumScaleFactor`**, down to 0.4 — deep, because the worst case
    ///    is a long entry name at the HUGE text step, and a title that shrinks
    ///    is better than one that truncates. The ellipsis behind it is the
    ///    floor, so anything longer still degrades to a visible truncation mark
    ///    rather than to a word chopped mid-glyph.
    ///
    /// `.id(shown)` is what makes the cross-fade actually fade: SwiftUI does
    /// not animate a `Text`'s *contents* changing, so the identity has to
    /// change for the transition to have an insertion and a removal to run.
    /// That trick is only good for an alpha ramp, which is why B2's dissolve
    /// takes the other branch below and masks two live labels instead.
    @ViewBuilder
    private var title: some View {
        if fadeStart == nil {
            label(shown)
                .id(shown)
                .transition(.opacity)
        } else {
            // The clock. `TimelineView` rather than an animatable value for the
            // reason `DataWave` sets out in `SettingsPanel`: `Canvas` has no
            // animatable content, and `Animatable` on the wrapper is not usable
            // here under Swift 6.
            TimelineView(.animation) { context in
                let p = fadeProgress(at: context.date)
                ZStack {
                    if let outgoing {
                        label(outgoing)
                            .mask(PixelDissolve(progress: p, cell: fadeCell, incoming: false))
                    }
                    label(shown)
                        .mask(PixelDissolve(progress: p, cell: fadeCell, incoming: true))
                }
            }
        }
    }

    /// The dissolve's cell edge, in points.
    ///
    /// Tied to the type size rather than fixed, so it survives SETTINGS > TEXT
    /// SIZE: the letters in this face are drawn on a notional grid of about
    /// eight cells to the cap height, and a dissolve cell around a sixth of the
    /// point size lands a little coarser than the glyph's own pixels. Coarser
    /// on purpose — matching the font's grid exactly makes the letters look
    /// like they are losing strokes rather than dissolving. Floored at 3pt,
    /// below which the effect is indistinguishable from a plain alpha fade at
    /// arm's length and costs several hundred more cells to draw.
    private var fadeCell: CGFloat { max(fontSize * 0.16, 3) }

    /// One string on the panel, with the three fallbacks above applied.
    private func label(_ string: String) -> some View {
        Text(EntryDisplay.hyphenated(string))
            .font(segmentFont)
            .foregroundStyle(ink)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.4)
            .truncationMode(.tail)
            // A hard catch of the lit ground below-right, where a black drop
            // shadow would be. Same one-pixel trick, inverted with the panel:
            // it is what makes the letters read as cut into the display rather
            // than printed on it.
            .shadow(color: ground.opacity(0.7), radius: 0, x: 1, y: 1)
    }
}

#endif
