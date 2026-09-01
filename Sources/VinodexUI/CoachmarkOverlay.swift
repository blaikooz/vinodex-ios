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
/// The dictionary allows one publisher per target on screen at a time, and
/// **the first one in the view tree wins** — corrected in 0.8.91 (I1).
///
/// It used to be the last, with the note here claiming that this is what made
/// the USER screen's PASSPORT row beat the chassis user button. It did the
/// opposite. Both publish `passportButton`, and both are on screen together on
/// exactly that screen, because the chassis furniture is mounted everywhere; the
/// footer is the *last* child of `frontFace`'s stack and the LCD content is the
/// middle one, so "later wins" handed the spotlight to the plastic on the one
/// screen the comment was written about. Keeping the first is the same sentence
/// with the tree order it actually has: the LCD is earlier, so the row takes
/// over once the player is through the door, and everywhere else the chassis is
/// the only publisher and wins by being alone.
public struct CoachmarkTargetKey: PreferenceKey {
    // Computed rather than stored: a stored `static var` is mutable global
    // state, which Swift 6's language mode rejects outright.
    public static var defaultValue: [CoachmarkTarget: Anchor<CGRect>] { [:] }

    public static func reduce(
        value: inout [CoachmarkTarget: Anchor<CGRect>],
        nextValue: () -> [CoachmarkTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { earlier, _ in earlier }
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
/// NEXT and QUIT are always drawn and always live. They are the exits from
/// the barrier, so a target whose anchor never resolves degrades to a bubble
/// with two ways out rather than to a locked device.
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
    /// The window this overlay covers, **supplied rather than read** (0.8.91,
    /// I1). The caller resolves the anchors against its own reader; taking the
    /// size from the same reader is what makes the rects below and the drawing
    /// below share one coordinate space by construction. See the call site in
    /// `RootView` for the bug this replaces.
    let canvas: CGSize
    /// The target's rectangle in this overlay's space, or nil when the step
    /// points at nothing (the closing line) or its target is not on screen.
    let spotlight: CGRect?
    let position: Int
    let total: Int
    let onNext: () -> Void
    let onQuit: () -> Void

    public init(
        step: CoachmarkStep,
        canvas: CGSize,
        spotlight: CGRect?,
        position: Int,
        total: Int,
        onNext: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.step = step
        self.canvas = canvas
        self.spotlight = spotlight
        self.position = position
        self.total = total
        self.onNext = onNext
        self.onQuit = onQuit
    }

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    @AppStorage(VinoName.storageKey) private var displayName = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    /// Measured, not assumed — see `placement(hole:)`.
    ///
    /// **Seeded rather than started at zero**, and the reason is the barrier. A
    /// zero here would have to be excluded from the opacity, and an
    /// `opacity(0)` view in SwiftUI still hit-tests — so a measurement that
    /// never arrived would leave an invisible wall over the whole window with an
    /// invisible QUIT on it, which is the one failure this overlay's own note
    /// says it must not have. 128 is roughly what the block measures at the
    /// default text size, so the first frame is approximately right and every
    /// frame after it is exact.
    @State private var bubbleHeight: CGFloat = 128

    /// How far the lit ring stands off the control it is lighting.
    private static let halo: CGFloat = 8
    /// The gap between the bubble and the thing it points at.
    private static let standoff: CGFloat = 14
    /// How close to the window edge the bubble may sit.
    private static let margin: CGFloat = 12
    /// The caret's height. Written down rather than measured because the caret
    /// is drawn to this number two screens down (`caret(x:pointingUp:)`), and
    /// the placement has to reserve its slot before it exists.
    private static let caretHeight: CGFloat = 9
    /// The smallest visible sliver of a target that still counts as a target.
    ///
    /// **A clamped rect can be empty and still be `.some`** — that is the whole
    /// reason this constant exists (0.8.91, I1). Two of the six steps point at
    /// something that lives in a `ScrollView`: `.listingRow` is inside a
    /// `LazyVStack`, so scrolling it out of realization drops the anchor
    /// entirely, and `.insightPanel` sits below the fold on an entry page, so
    /// before you scroll to it the clamp yields a degenerate rectangle pinned to
    /// an edge. The old code drew a zero-size glowing ring at that edge and a
    /// caret pointing into it. Under this floor both cases resolve to "no
    /// target", which is a state the bubble already knows how to be in.
    private static let minimumTarget: CGFloat = 16

    /// The portrait's square.
    ///
    /// **44 to 58** (0.8.91, G1/I2). §G1 asks for a larger Vino and §I2 asks for
    /// the tutorial to read as *him* talking rather than as chrome with a
    /// decoration on it; at 46 against a full-width panel he was the smaller
    /// half of his own bubble. `VinoBubble` moves with him — the two portraits
    /// are the same character and drifting them apart is how one of them starts
    /// looking like a different asset.
    private var portraitSize: CGFloat { 58 * UIScale.current.factor }

    public var body: some View {
        let hole = resolvedHole()
        let place = placement(hole: hole)

        return ZStack(alignment: .topLeading) {
            dim(size: canvas, hole: hole)
            if let hole { ring(hole) }
            barrier(size: canvas, hole: hole)
            bubbleLayer(hole: hole, place: place)
        }
        .frame(width: canvas.width, height: canvas.height)
        .opacity(landed ? 1 : 0)
        .onAppear {
            guard !reduceMotion else { landed = true; return }
            withAnimation(DexMotion.overlay) { landed = true }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Geometry

    /// The lit hole, or nil when there is nothing worth lighting.
    ///
    /// One place where "is there a target" is decided, so the ring, the barrier,
    /// the caret and the placement cannot disagree about it — which they could
    /// when each tested `hole != nil` against a rectangle that had survived the
    /// clamp as an empty sliver.
    private func resolvedHole() -> CGRect? {
        guard let spotlight else { return nil }
        let lit = clamp(spotlight.insetBy(dx: -Self.halo, dy: -Self.halo), in: canvas)
        guard lit.width >= Self.minimumTarget, lit.height >= Self.minimumTarget else { return nil }
        return lit
    }

    /// Where the bubble goes, and whether it has earned its arrow.
    struct Placement {
        /// The top of the caret-plus-bubble group, in canvas space.
        var top: CGFloat
        /// True when the bubble sits under its target, so the caret points up.
        var below: Bool
        /// False when the bubble is not actually adjacent to anything — no
        /// target, or a window too short to hold both. An arrow into empty grey
        /// is worse than none.
        var showsCaret: Bool
    }

    /// **A fit test, not a half-screen guess** (0.8.91, I1).
    ///
    /// The old rule was "below when the target is in the top half", with the
    /// bubble pinned by a spacer capped at 62% of the window. That is two
    /// separate ways to be wrong: a target just above the midpoint with a tall
    /// bubble under it runs off the bottom, and once the cap bit, the bubble
    /// detached from its subject while the caret went on tracking it — an arrow
    /// some distance from the thing it points at, which is exactly the
    /// "off-target" §I1 reports.
    ///
    /// This measures the bubble (see `block`) and asks whether it
    /// fits, preferring below because reading order puts the explanation after
    /// its subject. When neither side fits it takes the roomier one, clamps into
    /// the window and drops the caret: overlapping the target is the failure
    /// §I1 names, so the clamp is the last resort and it says so by losing the
    /// arrow rather than by lying with it.
    func placement(hole: CGRect?) -> Placement {
        let group = bubbleHeight + Self.caretHeight
        let lo = Self.margin
        let hi = max(Self.margin, canvas.height - group - Self.margin)

        guard let hole else {
            // The closing step points at nothing. Bottom of the window, where
            // `VinoBubble` lives — the same character in the same place.
            return Placement(top: hi, below: false, showsCaret: false)
        }

        let need = group + Self.standoff
        let roomBelow = canvas.height - hole.maxY - Self.margin
        let roomAbove = hole.minY - Self.margin
        let fitsBelow = roomBelow >= need
        let fitsAbove = roomAbove >= need
        let below = fitsBelow || (!fitsAbove && roomBelow >= roomAbove)

        let ideal = below
            ? hole.maxY + Self.standoff
            : hole.minY - Self.standoff - group
        return Placement(
            top: min(max(ideal, lo), hi),
            below: below,
            showsCaret: below ? fitsBelow : fitsAbove
        )
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

    /// The caret and the bubble as one group, offset to the solved position.
    ///
    /// An `offset` on a fixed-height group rather than a pair of `Spacer`s: the
    /// spacers were what let the layout disagree with the arithmetic, since the
    /// second one had to restate the first one's sum to keep the block where the
    /// first had put it. One number, applied once.
    ///
    /// The caret's slot is reserved whether or not it is drawn, so `bubbleHeight
    /// + caretHeight` is the group's height in every branch and the placement
    /// does not have to know which one it is in.
    private func bubbleLayer(hole: CGRect?, place: Placement) -> some View {
        // The caret's x, clamped to the bubble's own edges — the block is inset
        // by `margin` on both sides, and an arrow hanging off the corner radius
        // reads as a rendering fault rather than as a pointer.
        let caretW: CGFloat = 20
        let lo = Self.margin + 14
        let hi = max(lo, canvas.width - Self.margin - caretW - 14)
        let caretX = min(max((hole?.midX ?? canvas.width / 2) - caretW / 2, lo), hi)

        return VStack(spacing: 0) {
            if place.below {
                caret(x: caretX, pointingUp: true, visible: place.showsCaret)
                block
            } else {
                block
                caret(x: caretX, pointingUp: false, visible: place.showsCaret)
            }
        }
        .frame(width: canvas.width, alignment: .top)
        .offset(y: place.top)
        // The bubble follows its subject rather than cutting to it, which is
        // what makes a step that moves the spotlight read as one narrator
        // turning to point at something else.
        .animation(reduceMotion ? nil : DexMotion.overlay, value: place.top)
        .animation(reduceMotion ? nil : DexMotion.overlay, value: place.below)
    }

    /// The little arrow on the bubble's near edge, horizontally over the target.
    ///
    /// §G1 asks for a bubble "pointing at it", and the frame's own tail already
    /// points left at the portrait, so this is the second pointer and it points
    /// at the subject. Hidden — but not removed — when there is nothing to point
    /// at: the slot still occupies its 9 points, because a group that changed
    /// height depending on whether the arrow was drawn would make the placement
    /// arithmetic wrong in exactly the case it is compensating for.
    private func caret(x: CGFloat, pointingUp: Bool, visible: Bool) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0).frame(width: x)
            CoachmarkCaret(pointingUp: pointingUp)
                .fill(lcd.accent)
                .frame(width: 20, height: Self.caretHeight)
                .opacity(visible ? 1 : 0)
            Spacer(minLength: 0)
        }
        .frame(height: Self.caretHeight)
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
                    // **He signs it** (0.8.91, I2). This line was `STEP n OF m`
                    // — a progress readout, which is what a wizard says, not
                    // what a person does. `VinoBubble` puts his chirp in this
                    // slot and in this face, so borrowing the slot is what makes
                    // the two bubbles read as one character rather than as a
                    // remark and a tutorial that happen to share a portrait.
                    // The count stays: it is the one thing a walkthrough owes
                    // you that a remark does not.
                    Text("VINOBOT \u{00B7} \(position)/\(total)")
                        .font(DexFont.retro(10))
                        .tracking(1)
                        .foregroundStyle(lcd.accent)

                    Text(step.rendered(name: displayName))
                        .font(DexFont.mono(18))
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
        .padding(.horizontal, Self.margin)
        // What the placement solves against.
        //
        // `onChange` as well as `onAppear`, because the height moves with TEXT
        // SIZE and with the line — a
        // measurement taken once would be stale for two of those three. Both
        // run after layout, so neither writes state during a view update.
        //
        // A reader in the background rather than a `PreferenceKey`, which is
        // the other way to do this: `onPreferenceChange`'s action is `@Sendable`
        // in the Swift 6 SDK, and this closure has to write a `@State` on a
        // non-`Sendable` view.
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { bubbleHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, height in bubbleHeight = height }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Vinobot, step \(position) of \(total)")
    }

    private var controls: some View {
        HStack(spacing: 8) {
            // NEXT on every step (maintainer ruling, 0.9.45 test pass). This
            // was CONTINUE, drawn only on `.acknowledged` steps, on the theory
            // that a button beside an action step claims something you did not
            // do — and then a step whose target sat offscreen wedged the whole
            // run. The engine's `advance()` moves on without reporting the
            // action, so the ledgers stay honest and the run stays walkable.
            Button {
                Haptics.screenTap()
                onNext()
            } label: {
                pill("NEXT", fill: lcd.accent, ink: lcd.isLight ? .white : .black)
            }
            .buttonStyle(DexPressStyle(scale: 0.97))

            Button {
                Haptics.select()
                onQuit()
            } label: {
                pill("QUIT", fill: .clear, ink: lcd.subtext)
            }
            .buttonStyle(DexPressStyle(scale: 0.97))
        }
        .padding(.top, 2)
    }

    private func pill(_ text: String, fill: Color, ink: Color) -> some View {
        Text(text)
            .font(DexFont.retro(10))
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
