#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

// The LCD's surface effects, split out of DeviceChassis.swift (AUDIT
// **M30**). This is the cluster the audit named as the cheapest seam:
// four types that draw *onto* the screen and know nothing about the
// chassis around it. Nothing here changed in the move.

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
/// on every frame, at every one of the four instances, for as long as the app
/// is open — and these four are the only `repeatForever` animations in the
/// codebase, so that was the whole of its perpetual-motion bill. A blur of a
/// fixed radius is drawn once and then only faded.
struct PulseGlow: ViewModifier {
    let color: Color
    let period: Double
    let minRadius: CGFloat
    let maxRadius: CGFloat
    /// Suspends the pulse while the chassis is showing its underside (AUDIT
    /// **L11**). The front face is merely `opacity(0)` behind the back plate —
    /// it is still mounted and still animating, four lamps' worth, with
    /// nothing on screen to show for it.
    var paused: Bool = false

    @State private var on = false
    /// Frozen lit rather than frozen dark: the orb and the three status lamps
    /// are meant to read as powered, and a dead-looking indicator lamp is a
    /// different message, not a calmer one. (AUDIT M18)
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
