#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// **Professor Vino's speech bubble** (0.8.9c, D1/D2).
///
/// ## Not a `DexAlert`, and not a `ToolIntroCard` either
///
/// The house rule is that modals are `DexAlert`, and `ToolIntroCard` already
/// bends it once — borrowing the alert's scrim, panel and motion for something
/// that needed a picture well. This bends further, and the reason is that it is
/// **not a modal at all**.
///
/// A tool card interrupts: it dims the screen, it has a button, and you deal
/// with it before you do the thing you came to do. Vino remarks. Spec D1 asks
/// for "a small dismissible speech bubble", and the difference is the whole
/// design — no scrim, no button, bottom of the LCD, and the screen behind it
/// stays live and legible because the line is usually *about* what is on it
/// ("A grape entry, {name}. Origin, body, tannin, lineage..."). Dimming the
/// grape to talk about the grape would be self-defeating.
///
/// That is also why it does not stack with a `ToolIntroCard`: two first-run
/// interruptions on one screen is the failure mode, and the sequencing is
/// `VinoPresenter.isSuspended`, set by `RootView`. This view never has to know a
/// card exists.
///
/// ## Tap anywhere
///
/// The whole bubble is the dismiss target, portrait included, per D1. There is
/// deliberately no close glyph: a 44pt control inside a bubble this size would
/// be most of it, and an affordance that competes with "tap it" makes the
/// simpler gesture look wrong.
public struct VinoBubble: View {
    let line: VinoLine
    let onDismiss: () -> Void

    public init(line: VinoLine, onDismiss: @escaping () -> Void) {
        self.line = line
        self.onDismiss = onDismiss
    }

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    /// The name the player gave themselves on the USER screen. Read from the
    /// same default that screen writes — see `VinoName.storageKey` for why there
    /// is no second name. Empty resolves to the lowercase `explorer` fallback,
    /// which is why no line may open with `{name}`.
    @AppStorage(VinoName.storageKey) private var displayName = ""

    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The portrait's square.
    ///
    /// Follows `UIScale.current.factor`, the pattern `DexMetrics.iconWell` and
    /// every other chrome member use — so the picture grows with the text rather
    /// than sitting fixed beside enlarged copy. `DexFont.mono` already tracks
    /// TEXT SIZE on its own, which is the other half of D1's "honors the UI
    /// text-size setting", and `RootView` keys the whole chassis on both scales
    /// so a change takes effect without a relaunch.
    ///
    /// **52 to 64** (0.8.91, G1). The spec asks for the whole presenter larger —
    /// bubble and portrait — and the portrait is the half that was carrying the
    /// character: at 52 against a bubble spanning most of the LCD he read as an
    /// icon beside a panel rather than as somebody talking. The bubble grows with
    /// him below (`DexFont.mono(15)` to `(18)`, and its padding with it), because
    /// enlarging one and not the other is how a speech bubble stops looking
    /// attached to its speaker.
    private var portraitSize: CGFloat { 64 * UIScale.current.factor }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 0) {
                portrait
                bubble
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            // One target, per the type's note.
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.screenTap()
                onDismiss()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Vinobot: " + line.rendered(name: displayName))
            .accessibilityHint("Tap to dismiss")
            .accessibilityAddTraits(.isButton)
            // Rises from the bottom edge, which is where he is - not a panel
            // fading in over the middle of the screen.
            .offset(y: landed ? 0 : 14)
            .opacity(landed ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else { landed = true; return }
            withAnimation(DexMotion.settle) { landed = true }
        }
        // Re-runs the entrance for the next queued line, so two bubbles in a row
        // read as two remarks rather than as one panel whose text changed.
        .onChange(of: line.trigger) { _, _ in
            guard !reduceMotion else { return }
            landed = false
            withAnimation(DexMotion.settle) { landed = true }
        }
    }

    /// The expression this line asked for. No tint: `VinoArt` ships its own
    /// colours, the rule every drawn face in the app follows.
    ///
    /// `cpu` is the fallback if the PNG is ever missing — `PixelArtLoader`
    /// returns nil silently, which is the fault `DexChromeGlyph` is written
    /// around, and a retro AI with no face should degrade to a chip rather than
    /// to a hole. `ArtPipelineRosterTests` is what makes that a theoretical case.
    private var portrait: some View {
        DexChromeGlyph(
            line.expression.artStem,
            symbol: "cpu",
            size: portraitSize,
            weight: .semibold,
            tint: lcd.accent
        )
        // Overlaps the bubble's left edge so the tail reads as coming from him
        // rather than from the gap between them.
        .padding(.trailing, -6)
        .zIndex(1)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let chirp = line.chirp {
                // Its own run, in the retro face - which is the reason `chirp`
                // is a separate field. See `VinoChirp`.
                Text(chirp.text)
                    .font(DexFont.retro(10))
                    .tracking(1)
                    .foregroundStyle(lcd.accent)
            }

            Text(line.rendered(name: displayName))
                .font(DexFont.mono(18))
                .foregroundStyle(lcd.text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            VinoBubbleFrame(tailInset: portraitSize * 0.35)
                .fill(lcd.surface)
        )
        .overlay(
            VinoBubbleFrame(tailInset: portraitSize * 0.35)
                .stroke(lcd.accent.opacity(0.8), lineWidth: 2)
        )
    }
}

/// The bubble outline: a hard-cornered panel with a tail pointing left, at the
/// portrait.
///
/// **Drawn rather than a `RoundedRectangle` with a triangle behind it**, because
/// the two would need the same fill *and* the same stroke, and a stroked
/// triangle overlapping a stroked rectangle draws a line straight through the
/// join. One path has one outline.
///
/// A 3pt corner radius rather than the 10 `ToolIntroCard` uses: this is meant to
/// look stamped out of the same pixel grid as the portrait beside it, and a soft
/// panel next to hard pixel art reads as two different apps.
struct VinoBubbleFrame: Shape {
    /// How far down the left edge the tail sits, from the top.
    var tailInset: CGFloat
    var radius: CGFloat = 3
    /// How far the tail sticks out to the left.
    var tail: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(radius, min(rect.width, rect.height) / 2)
        // Clamped so a short bubble - one line, large portrait - cannot push the
        // tail past the bottom corner and invert the path.
        let tailTop = min(max(tailInset, r + 2), rect.maxY - r - 2 - tail)
        let tailBottom = min(tailTop + tail * 1.6, rect.maxY - r)

        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
            radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
            radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
            radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        // Up the left edge, out to the tail's point, and back.
        path.addLine(to: CGPoint(x: rect.minX, y: tailBottom))
        path.addLine(to: CGPoint(x: rect.minX - tail, y: (tailTop + tailBottom) / 2))
        path.addLine(to: CGPoint(x: rect.minX, y: tailTop))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.minY + r),
            radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
#endif
