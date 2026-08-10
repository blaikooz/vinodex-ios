#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// **Where the spotlight's targets announce themselves** (0.8.9d, G1).
///
/// Spec §G1 suggests anchor preferences, and they are the right tool for the one
/// reason a coordinate would not be: the walkthrough follows the *user*, so a
/// step's target may be on screen, off screen, or drawn by a different view than
/// last time, and an anchor is simply absent in the cases a stored rectangle
/// would be stale in.
///
/// The dictionary allows one publisher per target on screen at a time; a later
/// one wins, which matters for `passportButton` — the chassis user button
/// publishes it on every screen and the USER screen's PASSPORT row publishes it
/// too, and the row is the one the player should be looking at once they are
/// there.
public struct CoachmarkTargetKey: PreferenceKey {
    // Computed rather than stored: a stored `static var` is mutable global
    // state, which Swift 6's language mode rejects outright.
    public static var defaultValue: [CoachmarkTarget: Anchor<CGRect>] { [:] }

    public static func reduce(
        value: inout [CoachmarkTarget: Anchor<CGRect>],
        nextValue: () -> [CoachmarkTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { _, later in later }
    }
}

public extension View {
    /// Offer this view to the coachmark spotlight under `target`.
    ///
    /// Free when no walkthrough is running: an anchor preference costs a
    /// geometry read, and the overlay that consumes it is not built at all
    /// unless `CoachmarkEngine.current` is non-nil.
    ///
    /// **Optional**, so a row inside a `ForEach` can claim the target only when
    /// it is the first one without the call site growing an `if`. Nil publishes
    /// an empty dictionary, which merges to nothing.
    func coachmarkTarget(_ target: CoachmarkTarget?) -> some View {
        anchorPreference(key: CoachmarkTargetKey.self, value: .bounds) { anchor in
            target.map { [$0: anchor] } ?? [:]
        }
    }
}

/// **The grayout walkthrough's one screen** (0.8.9d, G1).
///
/// ## What it does and does not decide
///
/// Nothing. `CoachmarkEngine` owns which step is up, what advances it, where a
/// resumed run lands and whether the thing has ever been finished — all in Core,
/// where `swift test` can see it. This view draws a hole, a ring and a bubble,
/// and calls two closures.
///
/// ## The dim is a barrier, and that is the point
///
/// `WalkthroughScreen`'s note rejected live spotlights partly because "a user
/// who tapped something mid-tour would end up somewhere the script did not
/// expect". A coachmark answers that by construction: **only the cut-out passes
/// touches.** Everything else is swallowed, so the player cannot leave the path
/// by accident, and the engine's strict route arm (see `CoachmarkAction.action`)
/// never has to cope with an arrival it did not ask for.
///
/// The barrier is four bands around the hole rather than one shape with an
/// even-odd fill, because hit-testing a filled path does not honour the fill
/// rule and a "hole" that silently swallowed its own taps would be a walkthrough
/// nobody could advance. The **dim** is the even-odd path, and it does no hit
/// testing at all — one job each.
///
/// SKIP is always drawn and always live. It is the only exit from the barrier,
/// so a target whose anchor never resolves degrades to a bubble with a way out
/// rather than to a locked device.
///
/// ## It covers the chassis, unlike every other overlay in this app
///
/// The house rule since 0.7.8's A4 is that popups live inside the LCD, because a
/// translucent sheet over the plastic reads as the device losing power. This one
/// is the exception and it is forced: one of the six steps points at the USER
/// button, which is chassis furniture, and a spotlight that could not reach the
/// furniture would have to teach the passport by pointing at nothing. It reads
/// as a spotlight rather than as a power cut because the cut-out is at full
/// brightness with a lit ring round it — the opposite of a screen going dark.
public struct CoachmarkOverlay: View {
    let step: CoachmarkStep
    /// The target's rectangle in this overlay's space, or nil when the step
    /// points at nothing (the closing line) or its target is not on screen.
    let spotlight: CGRect?
    let position: Int
    let total: Int
    let onAcknowledge: () -> Void
    let onSkip: () -> Void

    public init(
        step: CoachmarkStep,
        spotlight: CGRect?,
        position: Int,
        total: Int,
        onAcknowledge: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.step = step
        self.spotlight = spotlight
        self.position = position
        self.total = total
        self.onAcknowledge = onAcknowledge
        self.onSkip = onSkip
    }

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    @AppStorage(VinoName.storageKey) private var displayName = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    /// How far the lit ring stands off the control it is lighting.
    private static let halo: CGFloat = 8
    /// The gap between the bubble and the thing it points at.
    private static let standoff: CGFloat = 14

    private var portraitSize: CGFloat { 46 * UIScale.current.factor }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let hole = spotlight.map { clamp($0.insetBy(dx: -Self.halo, dy: -Self.halo), in: size) }
            // Below the target when the target is in the top half, above it when
            // it is in the bottom half. Two positions rather than a solver: the
            // bubble is a fixed-width block and the only thing it must never do
            // is cover its own subject.
            let below = (hole?.midY ?? size.height) < size.height / 2

            ZStack(alignment: .topLeading) {
                dim(size: size, hole: hole)
                if let hole { ring(hole) }
                barrier(size: size, hole: hole)
                bubbleLayer(size: size, hole: hole, below: below)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .opacity(landed ? 1 : 0)
        .onAppear {
            guard !reduceMotion else { landed = true; return }
            withAnimation(DexMotion.overlay) { landed = true }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: The grey

    /// One path, even-odd filled, doing no hit testing. See the type note.
    private func dim(size: CGSize, hole: CGRect?) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            if let hole {
                path.addRoundedRect(in: hole, cornerSize: CGSize(width: 10, height: 10))
            }
        }
        // The alert scrim's two values (`DexAlert`): a 0.72 black over the paper
        // LCD reads as a power cut, so the light modes dim more gently.
        .fill(Color.black.opacity(lcd.isLight ? 0.4 : 0.74), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }

    private func ring(_ hole: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(lcd.accent, lineWidth: 2)
            .frame(width: hole.width, height: hole.height)
            .offset(x: hole.minX, y: hole.minY)
            .shadow(color: lcd.accent.opacity(0.7), radius: 7)
            .allowsHitTesting(false)
    }

    /// Four bands around the hole, or one full-bleed band when there is none.
    ///
    /// A tap on a band is consumed and does nothing — deliberately not treated
    /// as a skip or an acknowledgement. Mistaking a stray tap for consent to
    /// leave the tutorial is worse than ignoring it, and the bubble carries both
    /// real answers.
    @ViewBuilder
    private func barrier(size: CGSize, hole: CGRect?) -> some View {
        if let hole {
            band(CGRect(x: 0, y: 0, width: size.width, height: hole.minY))
            band(CGRect(x: 0, y: hole.maxY, width: size.width, height: size.height - hole.maxY))
            band(CGRect(x: 0, y: hole.minY, width: hole.minX, height: hole.height))
            band(
                CGRect(
                    x: hole.maxX, y: hole.minY,
                    width: size.width - hole.maxX, height: hole.height
                )
            )
        } else {
            band(CGRect(origin: .zero, size: size))
        }
    }

    /// One rectangle of swallowed input. A method rather than a local closure so
    /// the four calls share one concrete view type without asking the type
    /// checker to infer it inside a result builder.
    private func band(_ rect: CGRect) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: max(rect.width, 0), height: max(rect.height, 0))
            .offset(x: rect.minX, y: rect.minY)
            .onTapGesture {}
    }

    // MARK: The bubble

    private func bubbleLayer(size: CGSize, hole: CGRect?, below: Bool) -> some View {
        // The caret's x, clamped so it stays on the bubble's own edge when the
        // target is hard against a screen edge.
        let caretX = min(max((hole?.midX ?? size.width / 2) - 14, 26), size.width - 54)

        return VStack(spacing: 0) {
            if below {
                Spacer(minLength: 0)
                    .frame(height: min((hole?.maxY ?? 0) + Self.standoff, size.height * 0.62))
                caret(x: caretX, pointingUp: true, visible: hole != nil)
                block
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                block
                caret(x: caretX, pointingUp: false, visible: hole != nil)
                Spacer(minLength: 0)
                    .frame(height: max(size.height - (hole?.minY ?? size.height) + Self.standoff, 0))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    /// The little arrow on the bubble's near edge, horizontally over the target.
    ///
    /// §G1 asks for a bubble "pointing at it", and the frame's own tail already
    /// points left at the portrait, so this is the second pointer and it points
    /// at the subject. Hidden when there is no target, because an arrow into
    /// empty grey is worse than none.
    @ViewBuilder
    private func caret(x: CGFloat, pointingUp: Bool, visible: Bool) -> some View {
        if visible {
            HStack(spacing: 0) {
                Spacer(minLength: 0).frame(width: x)
                CoachmarkCaret(pointingUp: pointingUp)
                    .fill(lcd.accent)
                    .frame(width: 20, height: 9)
                Spacer(minLength: 0)
            }
        }
    }

    private var block: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 0) {
                // The same portrait treatment `VinoBubble` uses — same
                // character, same bubble, so the tutorial is recognisably him
                // rather than a second narrator.
                DexChromeGlyph(
                    step.expression.artStem,
                    symbol: "cpu",
                    size: portraitSize,
                    weight: .semibold,
                    tint: lcd.accent
                )
                .padding(.trailing, -6)
                .zIndex(1)

                VStack(alignment: .leading, spacing: 6) {
                    Text("STEP \(position) OF \(total)")
                        .font(DexFont.retro(9))
                        .tracking(1)
                        .foregroundStyle(lcd.accent)

                    Text(step.rendered(name: displayName))
                        .font(DexFont.mono(16))
                        .foregroundStyle(lcd.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    controls
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    VinoBubbleFrame(tailInset: portraitSize * 0.35).fill(lcd.surface)
                )
                .overlay(
                    VinoBubbleFrame(tailInset: portraitSize * 0.35)
                        .stroke(lcd.accent.opacity(0.85), lineWidth: 2)
                )
            }
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Professor Vino, step \(position) of \(total)")
    }

    private var controls: some View {
        HStack(spacing: 8) {
            // CONTINUE only on the steps that have nothing to do — see
            // `CoachmarkAction.acknowledged`. Every other step is advanced by
            // the thing it is asking for, and a button beside that would be a
            // way to claim you did something you did not.
            if step.advancesOn == .acknowledged {
                Button {
                    Haptics.screenTap()
                    onAcknowledge()
                } label: {
                    pill("CONTINUE", fill: lcd.accent, ink: lcd.isLight ? .white : .black)
                }
                .buttonStyle(DexPressStyle(scale: 0.97))
            }

            Button {
                Haptics.select()
                onSkip()
            } label: {
                pill("SKIP", fill: .clear, ink: lcd.subtext)
            }
            .buttonStyle(DexPressStyle(scale: 0.97))
        }
        .padding(.top, 2)
    }

    private func pill(_ text: String, fill: Color, ink: Color) -> some View {
        Text(text)
            .font(DexFont.retro(9))
            .tracking(1.5)
            .foregroundStyle(ink)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(ink.opacity(0.55), lineWidth: 1.5))
    }

    /// Keep the halo inside the window, so a control against an edge does not
    /// produce a hole whose bands have negative width.
    private func clamp(_ rect: CGRect, in size: CGSize) -> CGRect {
        let minX = max(rect.minX, 0)
        let minY = max(rect.minY, 0)
        let maxX = min(rect.maxX, size.width)
        let maxY = min(rect.maxY, size.height)
        return CGRect(x: minX, y: minY, width: max(maxX - minX, 0), height: max(maxY - minY, 0))
    }
}

/// The bubble's arrow. Flat-edged so it butts against the panel without a seam.
struct CoachmarkCaret: Shape {
    var pointingUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointingUp {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }
}
#endif
