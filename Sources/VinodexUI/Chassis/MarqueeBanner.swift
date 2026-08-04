#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

// The scrolling footer banner, split out of DeviceChassis.swift (AUDIT
// **M30**). At ~210 lines it was the single largest type in that file
// after the chassis itself, and the one with the most intricate
// reasoning behind it — see the doc comments below, which are the
// record of three separate attempts. Nothing here changed in the move.

/// The scrolling footer banner. Ports `terminal-marquee`: two copies of the
/// label offset by one cycle, which loops seamlessly.
///
/// The animation is started from `onChange(of:)` rather than `onAppear` —
/// the label is measured by a background reader, so at `onAppear` the width is
/// still zero and the animation would never run.
struct MarqueeBanner: View {
    /// The words the strip cycles. Most screens pass one segment — their
    /// title; the main screen passes its five toasts. Segments, not a single
    /// string, so every word boundary gets the same `gap` the wrap seam does
    /// (v0.5.7, E1) instead of whatever spacing was baked into the text.
    let segments: [String]
    /// SF Symbol stamped between repetitions — `SYSTEM ⟨gear⟩ SYSTEM ⟨gear⟩`
    /// (v0.5.7, E2). Nil runs text-only.
    let symbol: String?
    let fontSize: CGFloat
    var pointsPerSecond: Double = 34
    /// Stops the clock (AUDIT M8). The strip is inside the front face, which
    /// the flip merely hides at `opacity 0` — without this it kept redrawing at
    /// the display's refresh rate, forever, behind an opaque metal back plate.
    var paused: Bool = false

    /// The first copy's width, measured from its own laid-out geometry.
    ///
    /// Every previous version *predicted* this number — character count
    /// times a `UIFont`-measured cell (0.5.1), then the same corrected for
    /// the text-scale factor (0.5.4, audit M9) — and every prediction
    /// disagreed with SwiftUI's actual layout by a point or two: `NSString`
    /// metrics and SwiftUI `Text` rounding are not the same machinery, the
    /// error scaled with the label's length, and the seam skipped by exactly
    /// that error every lap. Measuring the rendered label itself cannot
    /// disagree with the rendered label. Until the first measurement lands
    /// the strip holds still (shift 0) rather than popping.
    @State private var copyWidth: CGFloat = 0

    /// Spacing between the two copies — part of the cycle geometry, scaled
    /// like the glyphs.
    ///
    /// Resolved in `init`, not per access (AUDIT M8). It was a computed
    /// property reading `TextScale.current`, which is a `UserDefaults` lookup,
    /// and the `TimelineView` closure touches it four times per frame — so a
    /// banner nobody is looking at was hitting the defaults store ~500×/s.
    /// `DeviceChassis` is `.id`-keyed on the text scale, so a change rebuilds
    /// this view rather than needing it re-read.
    private let gap: CGFloat
    /// Likewise: `DexFont.retro` reads `TextScale.current` on every call, and
    /// `label` is rebuilt inside the timeline closure on every frame.
    private let segmentFont: Font
    private let symbolSize: CGFloat

    /// The strip's phosphor follows the shell — see `ChassisSkin.marqueeText`.
    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared
    /// A strip of text sliding sideways under the screen, on every screen, for
    /// as long as the app is open — the single most continuous movement in the
    /// app. Read here rather than passed in by `DeviceChassis` so the banner
    /// keeps working wherever else it is mounted. (AUDIT M18)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var skin: ChassisSkin { settings.chassisSkin }

    init(
        segments: [String],
        symbol: String? = nil,
        fontSize: CGFloat,
        pointsPerSecond: Double = 34,
        paused: Bool = false
    ) {
        self.segments = segments
        self.symbol = symbol
        self.fontSize = fontSize
        self.pointsPerSecond = pointsPerSecond
        self.paused = paused

        // Through the resolver, not `fontSize * TextScale.current.factor`:
        // since 0.6.4 a size floor sits between the two, so the hand-rolled
        // form can disagree with what `DexFont.retro` actually drew. The gap
        // and the symbol are laid out against the glyphs, and this file has
        // already lost three rounds to a marquee seam that skipped by exactly
        // such a disagreement (audit M8, M9).
        let pt = DexFont.resolvedSize(fontSize)
        self.gap = pt * 1.5
        self.segmentFont = DexFont.retro(fontSize)
        self.symbolSize = pt * 0.8
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner)
                .fill(.black)
                .overlay(
                    DexGridBackground(spacing: 12, color: skin.marqueeGrid, opacity: 0.18)
                        .clipShape(RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner)
                        .strokeBorder(.white.opacity(0.75), lineWidth: 1)
                )

            // Offset is a pure function of the clock, so it cannot drift and
            // cannot be restarted mid-run by a re-render. The cycle is one
            // measured copy plus the gap: the second copy starts exactly
            // there, so a wrap lands on identical pixels.
            // `paused:` and not simply unmounting the strip: the measured
            // `copyWidth` has to survive, or the flip back holds still at
            // shift 0 until the geometry reader lands again. The offset is a
            // pure function of the clock, so resuming needs no stored phase.
            // (AUDIT M8)
            // Reduce Motion stops the clock the same way the flip does, but it
            // cannot simply *pause* the strip: pinning a scrolling label at
            // shift 0 is only safe if the label fits, and these do not. A
            // scrolling label is allowed to overflow because the scroll is what
            // reveals its tail. Measured against the bundled Press Start 2P in
            // the strip's 256pt of usable width, DAILY CHALLENGE is 288pt at
            // the default text step, and at HUGE six of the app's ten page
            // titles overflow. So the still form is a different view — see
            // `staticLabel`. Taking the motion away must not take the words
            // with it. (AUDIT M18)
            TimelineView(.animation(paused: paused || reduceMotion)) { context in
                let cycle = copyWidth + gap
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let shift = (copyWidth > 0 && !reduceMotion)
                    ? CGFloat((elapsed * pointsPerSecond).truncatingRemainder(dividingBy: Double(cycle)))
                    : 0

                // The GeometryReader is load-bearing, not decoration: the
                // `.fixedSize()` label pair is ~1500pt wide for the main-menu
                // text, and without a *definite* width to clip against it
                // ignores `maxWidth` entirely, renders full-bleed across the
                // footer and squeezes the Back/user button out of the row.
                GeometryReader { strip in
                    Group {
                        if reduceMotion {
                            staticLabel
                        } else {
                            HStack(spacing: gap) {
                                label
                                    .background(
                                        GeometryReader { copy in
                                            Color.clear
                                                .onAppear { copyWidth = copy.size.width }
                                                .onChange(of: copy.size.width) { _, new in
                                                    copyWidth = new
                                                }
                                        }
                                    )
                                label
                            }
                            .offset(x: -shift)
                        }
                    }
                    .frame(
                        width: max(strip.size.width, 0),
                        height: max(strip.size.height, 0),
                        alignment: reduceMotion ? .center : .leading
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DexMetrics.marqueeInnerCorner))
                }
                .padding(4)
            }
        }
        .frame(height: DexMetrics.marqueeHeight)
    }

    /// The Reduce Motion form: one label, centred, still, and sized to fit.
    ///
    /// `minimumScaleFactor` rather than `.fixedSize()` — the whole point is
    /// that this one has to fit the strip rather than run past its edge, and
    /// the worst case (DAILY CHALLENGE at HUGE) needs about 0.7. Ellipsis
    /// behind that as a floor, so a longer title added later degrades to a
    /// visible truncation mark rather than to a word chopped mid-glyph.
    ///
    /// One segment, not all of them joined: the only multi-segment caller is
    /// the main screen's five toasts, and CHEERS/SANTE/SALUTE/PROST/KANPAI are
    /// five ways of saying one thing. Shrinking the strip to a fifth of its
    /// size to fit four synonyms would trade legibility for nothing.
    private var staticLabel: some View {
        HStack(spacing: gap * 0.4) {
            Text(segments.first ?? "")
                .font(segmentFont)
                .foregroundStyle(skin.marqueeText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .truncationMode(.tail)
                .shadow(color: skin.marqueeShadow.opacity(0.65), radius: 0, x: 1, y: 1)

            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: symbolSize, weight: .bold))
                    .foregroundStyle(skin.marqueeText)
                    .shadow(color: skin.marqueeShadow.opacity(0.65), radius: 0, x: 1, y: 1)
            }
        }
        .padding(.horizontal, 6)
    }

    /// One full cycle of content: every segment, `gap` apart, with the page
    /// glyph closing it. Two copies of this sit `gap` apart in the strip, so
    /// the seam between them is indistinguishable from any internal boundary
    /// — which is what makes the loop read as endless.
    private var label: some View {
        HStack(spacing: gap) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Text(segment)
                    .font(segmentFont)
                    .foregroundStyle(skin.marqueeText)
                    .lineLimit(1)
                    .fixedSize()
                    .shadow(color: skin.marqueeShadow.opacity(0.65), radius: 0, x: 1, y: 1)
            }
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: symbolSize, weight: .bold))
                    .foregroundStyle(skin.marqueeText)
                    .shadow(color: skin.marqueeShadow.opacity(0.65), radius: 0, x: 1, y: 1)
            }
        }
    }
}
#endif
