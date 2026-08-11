#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

// The LCD's surface effects, split out of DeviceChassis.swift (AUDIT
// **M30**). This is the cluster the audit named as the cheapest seam:
// four types that draw *onto* the screen and know nothing about the
// chassis around it. Nothing changed in the move itself; what has
// changed since is upstream's own work on these four — 0.7.0's C1
// returning to one backdrop for every mode, and the button band's pills
// joining `PulseGlow`'s count — carried across to here rather than left
// behind in the file they were split out of.

// MARK: - Effects

/// Repeating horizontal scanlines — the LCD's CRT texture.
struct ScanlineOverlay: View {
    init() {}

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: DexMetrics.scanlineThickness)),
                    with: .color(.black.opacity(0.5))
                )
                y += DexMetrics.scanlineSpacing
            }
        }
        .allowsHitTesting(false)
    }
}

/// The LCD backdrop shared by every screen.
///
/// Exists as one view rather than per-screen copies so the main menu cannot
/// drift from the list and detail screens — they looked different because each
/// had its own colour and grid settings.
public struct DexScreenBackground: View {
    /// Read here rather than passed down: every screen uses this one view for
    /// its ground, so honouring the setting in one place covers all of them.
    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared

    private var mode: LcdMode { settings.lcdMode }

    public init() {}

    public var body: some View {
        ZStack {
            mode.ground
            // **Back to one backdrop for every mode** (0.7.0, C1).
            //
            // 0.6.9's M1 branched here on `LcdMode.isSketchPaper` to mount
            // `RuledPaper` for NOTEBOOK. C1 removes that mode, so the branch has
            // nothing left to select and the grid is unconditional again. The
            // *shell* half of M1 is untouched — `ChassisSkin.sketch` still draws
            // PÉT-NAT by hand — which is the documented design: the shell and
            // the screen are independent choices.
            //
            // See the retirement note on `LcdMode` for what happens to
            // `RuledPaper`, which is kept and unmounted rather than deleted.
            DexGridBackground(
                spacing: 10,
                color: mode.gridLine,
                opacity: 0.35
            )
        }
        .ignoresSafeArea()
    }
}

/// Faint square grid used as an atmospheric LCD backdrop.
struct DexGridBackground: View {
    var spacing: CGFloat
    var color: Color
    var opacity: Double

    init(spacing: CGFloat = 30, color: Color = Dex.green, opacity: Double = 0.1) {
        self.spacing = spacing
        self.color = color
        self.opacity = opacity
    }

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 0
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// Replaces the CSS `lcd-pulse` / `dot-pulse-*` keyframes. The web versions use
/// irregular multi-stop timings; a symmetric ease here reads the same in motion.
///
/// What animates is the **opacity of a circle blurred once**, not the radius of
/// a shadow (AUDIT **L11**). Those look identical and cost differently: a
/// shadow whose radius is a function of the animation has to be re-rasterised
/// on every frame, at every one of its instances, for as long as the app is
/// open — and these are the only `repeatForever` animations in the codebase, so
/// that was the whole of its perpetual-motion bill. A blur of a fixed radius is
/// drawn once and then only faded. The saving grows with the instance count,
/// which is why it is worth having made here: 0.6.5's button band added two
/// more lamps without touching this file.
struct PulseGlow: ViewModifier {
    let color: Color
    let period: Double
    let minRadius: CGFloat
    let maxRadius: CGFloat
    /// Suspends the pulse while the chassis is showing its underside (AUDIT
    /// **L11**). The front face is merely `opacity(0)` behind the back plate —
    /// it is still mounted and still animating, every lamp on it, with nothing
    /// on screen to show for it.
    ///
    /// Defaulted so a call site that has no back face to hide behind — or has
    /// not been threaded yet — is unchanged.
    var paused: Bool = false

    @State private var on = false
    /// Frozen lit rather than frozen dark: the orb, the three status lamps and
    /// the button band's two indicator pills are meant to read as powered, and
    /// a dead-looking indicator lamp is a different message, not a calmer one.
    /// (AUDIT M18; overlaps L11)
    ///
    /// The audit counted four of these; 0.6.5's button band added the two pills
    /// (`indicatorPill`), which inherit the behaviour by construction — the
    /// check lives in the modifier, not at its call sites, which is the reason
    /// to keep it here, and the same reason `paused` is resolved into `isStill`
    /// below rather than branched on by each caller. Everything else that
    /// animates in the chassis is a response to a touch (the orb's press,
    /// `DexPressStyle`'s spring) and stays: Reduce Motion asks for no
    /// *unprompted* movement.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One term for the two reasons to stop, so the branch swap — and the
    /// un-latch that depends on it — happens once rather than twice.
    private var isStill: Bool { reduceMotion || paused }

    @ViewBuilder
    func body(content: Content) -> some View {
        if isStill {
            content
                .shadow(color: color.opacity(0.5), radius: (minRadius + maxRadius) / 2)
                // Un-latch. `on` is `@State` on the modifier itself, so it
                // survives this branch swap — without the reset, coming back
                // re-mounts the branch below, its `.onAppear` writes `true`
                // over `true`, and `.animation(_:value:)` sees no change to
                // animate. The lamps would come back stuck at full glow,
                // permanently, for someone who just asked for motion *back*.
                // Invisible here: this branch never reads `on`.
                .onAppear { on = false }
        } else {
            content
                // The resting glow, static — nothing re-rasterises for it.
                .shadow(color: color.opacity(0.25), radius: minRadius)
                .background {
                    Circle()
                        .fill(color)
                        .blur(radius: maxRadius)
                        .opacity(on ? 0.55 : 0)
                        .animation(
                            .easeInOut(duration: period / 2).repeatForever(autoreverses: true),
                            value: on
                        )
                        .allowsHitTesting(false)
                }
                .onAppear { on = true }
        }
    }
}
#endif
