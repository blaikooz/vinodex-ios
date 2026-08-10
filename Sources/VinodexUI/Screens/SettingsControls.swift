#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import VinodexCore

// The two bespoke controls the settings panels draw with. Split out of
// SettingsPanel.swift (AUDIT **M30**) — neither is settings-specific in
// anything but its current call sites, and both are pure presentation.
// Nothing changed in the move itself; the two deltas below — `DexMotion.settle`
// on the throw and 0.6.7's dropped height floor on the wave — landed after it.

/// A hardware-looking switch: a recessed track with a raised, bevelled throw
/// that slides between two detents.
///
/// Replaces a flat 42x24 capsule with a white dot in it. On a chassis built
/// entirely out of physical metaphors — moulded buttons, a screwed-on back
/// plate, a glass orb — the one actual *setting* control was the only thing
/// that looked like a web page. Sized to be hit with a thumb, too: the old one
/// was under the 44pt touch minimum in both axes.
struct DexToggle: View {
    let isOn: Bool
    /// Lit colour of the track and the throw's inset when engaged.
    var tint: Color = Dex.yellow
    let action: () -> Void

    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }

    init(isOn: Bool, tint: Color = Dex.yellow, action: @escaping () -> Void) {
        self.isOn = isOn
        self.tint = tint
        self.action = action
    }

    private let width: CGFloat = 76
    private let height: CGFloat = 40
    private var throwSize: CGFloat { height - 8 }

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                // The well. Darker than the surface it sits on, so the throw
                // reads as sitting *in* something rather than on top of it.
                Capsule()
                    .fill(isOn ? tint.opacity(0.85) : Dex.stone900)
                    .overlay(
                        Capsule().strokeBorder(
                            isOn ? tint : Dex.stone700,
                            lineWidth: 2
                        )
                    )
                    .overlay(
                        // Inner shadow along the top lip — the cue that sells a
                        // recess. A full inner shadow is not available, so this
                        // is the top edge alone, which is the part the eye uses.
                        Capsule()
                            .stroke(.black.opacity(0.45), lineWidth: 3)
                            .blur(radius: 2)
                            .mask(Capsule().fill(
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            ))
                    )

                // The throw: bevelled, with a knurled grip line so it reads as
                // something a thumb pushes.
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Dex.stone200, Dex.stone400, Dex.stone600],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                    .overlay(
                        Capsule()
                            .fill(Dex.stone700.opacity(0.55))
                            .frame(width: 2, height: throwSize * 0.42)
                    )
                    .frame(width: throwSize, height: throwSize)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                    .padding(4)
            }
            .frame(width: width, height: height)
            // `DexMotion.settle` rather than a spring spelled out here: the
            // throw sliding to its detent is furniture coming to rest, and the
            // "0.25/0.7 toggle spring" `DexMotion` names as one of the three it
            // replaced was this very line.
            .animation(DexMotion.settle, value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "On" : "Off")
    }
}

// MARK: - Growth wave

/// The DATA panel's growth graph: an area chart that sweeps left to right
/// through the dataset's milestones while a counter runs up alongside it.
///
/// Drawn in a `Canvas` rather than assembled from shapes because the curve is
/// sampled per pixel-column — a ripple rides on top of the value line so it
/// reads as a wave rather than as three straight segments.
// `internal` rather than `private` since the M30 split: `private` at file scope
// meant "SettingsPanel.swift", which is exactly the coupling the split removes.
// The DATA panel is still its only caller.
struct DataWave: View {
    let milestones: [Int]
    let lcd: LcdMode

    /// When the sweep started, and whether it has run out.
    ///
    /// Driven by a `TimelineView` clock rather than by animating a `@State`
    /// through an `Animatable` view. The obvious version — a view conforming to
    /// `Animatable` so SwiftUI hands it interpolated values — does not compile
    /// under Swift 6: `View` conformance isolates the type to the main actor
    /// while `Animatable.animatableData` is a nonisolated requirement, and the
    /// conformance is rejected as a data race. A clock needs no such crossing,
    /// and `paused` lets the timeline stop once the sweep is done rather than
    /// redrawing this panel forever.
    @State private var start = Date()
    @State private var finished = false
    /// The sweep is decoration over a number that is already correct, so under
    /// Reduce Motion it simply starts finished — the panel shows the settled
    /// curve and the real total, and no clock runs. (AUDIT M18)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let duration: Double = 2.6

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineView(.animation(paused: finished || reduceMotion)) { timeline in
                // The counter and the curve must advance together, so both are
                // rendered from the same value.
                let elapsed = timeline.date.timeIntervalSince(start)
                let linear = reduceMotion ? 1 : min(max(elapsed / Self.duration, 0), 1)
                // Eased so the sweep settles into the total instead of running
                // at full speed and stopping dead on the last frame.
                let p = linear * linear * (3 - 2 * linear)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(Int(dataWaveValue(at: p, in: milestones).rounded()))")
                        .font(DexFont.retro(22))
                        .foregroundStyle(lcd.accent)
                    wave(p)
                }
            }
            legend
        }
        .onAppear {
            start = Date()
            finished = false
        }
        .task {
            // A little past the end, so the final frame is the settled one.
            try? await Task.sleep(for: .seconds(Self.duration + 0.15))
            finished = true
        }
    }

    private func wave(_ p: Double) -> some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }
            let peak = Double(milestones.max() ?? 0)
            guard peak > 0 else { return }

            let baseline = size.height - 8
            let top: CGFloat = 8
            let usable = baseline - top
            guard usable > 0 else { return }

            // Never exactly zero: a zero-width sweep produces a degenerate path
            // that Canvas draws as a stray dot at the origin.
            let visible = min(max(p, 0.0001), 1)
            let steps = 140

            func point(at f: Double) -> CGPoint {
                let v = dataWaveValue(at: f, in: milestones) / peak
                // The ripple scales with the value so the flat empty start does
                // not wobble below its own axis.
                let ripple = sin(f * 13 + p * 5) * 0.03 * v
                let height = min(max(v + ripple, 0), 1)
                return CGPoint(
                    x: CGFloat(f) * size.width,
                    y: baseline - CGFloat(height) * usable
                )
            }

            var line = Path()
            var area = Path()
            area.move(to: CGPoint(x: 0, y: baseline))

            for i in 0...steps {
                let f = Double(i) / Double(steps) * visible
                let pt = point(at: f)
                if i == 0 { line.move(to: pt) } else { line.addLine(to: pt) }
                area.addLine(to: pt)
            }
            area.addLine(to: CGPoint(x: CGFloat(visible) * size.width, y: baseline))
            area.closeSubpath()

            // Axis first, so the fill sits over it rather than cutting it.
            var axis = Path()
            axis.move(to: CGPoint(x: 0, y: baseline))
            axis.addLine(to: CGPoint(x: size.width, y: baseline))
            context.stroke(axis, with: .color(lcd.accent.opacity(0.3)), lineWidth: 1)

            context.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [lcd.accent.opacity(0.42), lcd.accent.opacity(0.03)]),
                    startPoint: CGPoint(x: 0, y: top),
                    endPoint: CGPoint(x: 0, y: baseline)
                )
            )
            context.stroke(line, with: .color(lcd.accent), lineWidth: 2)

            let head = point(at: visible)
            context.fill(
                Path(ellipseIn: CGRect(x: head.x - 4, y: head.y - 4, width: 8, height: 8)),
                with: .color(lcd.accent)
            )
        }
        // Flexible since 0.6.4 (C2): the DATA page is fixed-height now and
        // the wave is what soaks up the LCD's leftover space.
        //
        // **The 96pt floor is gone (0.6.7, I1).** It was the old fixed height,
        // kept "so the curve can never collapse", and it was half of why this
        // page changed the size of the LCD when you opened it: a hard minimum
        // on the one screen in the app that does not scroll is a demand the
        // page makes of the housing, and on a shorter device (or at a larger
        // text step) the sum of the two count blocks plus 96 exceeded the
        // display. The housing is clamped at the other end now — see
        // `DeviceChassis.innerBezel` — but a page that only fits because it is
        // being clipped is not fitting. The `Canvas` has no intrinsic size, so
        // without a floor the graph simply takes what is left, down to
        // nothing, and the readout above it always fits.
        .frame(maxHeight: .infinity)
    }

    /// Milestone values under the curve, pinned to the ends so the first and
    /// last sit over the points they label rather than floating inward.
    private var legend: some View {
        HStack(spacing: 0) {
            ForEach(Array(milestones.enumerated()), id: \.offset) { index, value in
                Text("\(value)")
                    .font(DexFont.mono(15))
                    .foregroundStyle(lcd.subtext)
                    .frame(
                        maxWidth: .infinity,
                        alignment: index == 0
                            ? .leading
                            : (index == milestones.count - 1 ? .trailing : .center)
                    )
            }
        }
    }

}

/// The value along the milestone track at `f` in 0...1.
///
/// Eased between stops with a smoothstep rather than interpolated linearly, so
/// the curve arcs into each milestone instead of turning a hard corner at it —
/// the difference between a wave and a zigzag.
///
/// A free function rather than a method on `DataWave`: it is called from the
/// `Canvas` renderer, which is a nonisolated closure, and a member of a
/// main-actor-isolated `View` reached from there is diagnosed as a cross-actor
/// call. Nothing here touches view state, so it does not need to be one.
private func dataWaveValue(at f: Double, in points: [Int]) -> Double {
    guard let first = points.first else { return 0 }
    guard points.count > 1 else { return Double(first) }

    let clamped = min(max(f, 0), 1)
    let scaled = clamped * Double(points.count - 1)
    let index = min(Int(scaled), points.count - 2)
    let local = scaled - Double(index)
    let eased = local * local * (3 - 2 * local)

    let a = Double(points[index])
    let b = Double(points[index + 1])
    return a + (b - a) * eased
}
#endif
