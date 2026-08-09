#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

// MARK: - ScreenEffects

// What the LCD wears over its content: scanlines, grid and screen
// backgrounds, and the pulse glow.

// MARK: - Effects

/// Repeating horizontal scanlines — the LCD's CRT texture.
public struct ScanlineOverlay: View {
    public init() {}

    public var body: some View {
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
    @AppStorage(LcdMode.storageKey) private var modeRaw = LcdMode.dark.rawValue

    private var mode: LcdMode { LcdMode(rawValue: modeRaw) ?? .dark }

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
public struct DexGridBackground: View {
    var spacing: CGFloat
    var color: Color
    var opacity: Double

    public init(spacing: CGFloat = 30, color: Color = Dex.green, opacity: Double = 0.1) {
        self.spacing = spacing
        self.color = color
        self.opacity = opacity
    }

    public var body: some View {
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
struct PulseGlow: ViewModifier {
    let color: Color
    let period: Double
    let minRadius: CGFloat
    let maxRadius: CGFloat

    @State private var on = false
    /// The instances of this modifier are the *only* `repeatForever` animations
    /// in the app, so this one check is the whole of its perpetual motion.
    /// Frozen lit rather than frozen dark: the orb, the three status lamps and
    /// the button band's two indicator pills are meant to read as powered, and
    /// a dead-looking indicator lamp is a different message, not a calmer one.
    /// (AUDIT M18; overlaps L11)
    ///
    /// The audit counted four of these; 0.6.5's button band added the two pills
    /// (`indicatorPill`), which inherit the behaviour by construction — the
    /// check lives in the modifier, not at its call sites, which is the reason
    /// to keep it here. Everything else that animates in the chassis is a
    /// response to a touch (the orb's press, `DexPressStyle`'s spring) and
    /// stays: Reduce Motion asks for no *unprompted* movement.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion {
            content
                .shadow(color: color.opacity(0.5), radius: (minRadius + maxRadius) / 2)
                // Un-latch. `on` is `@State` on the modifier itself, so it
                // survives this branch swap — without the reset, turning Reduce
                // Motion off again re-mounts the branch below, its `.onAppear`
                // writes `true` over `true`, and `.animation(_:value:)` sees no
                // change to animate. The lamps would come back stuck at full
                // glow, permanently, for someone who just asked for motion
                // *back*. Invisible here: this branch never reads `on`.
                .onAppear { on = false }
        } else {
            content
                .shadow(color: color.opacity(on ? 0.8 : 0.25), radius: on ? maxRadius : minRadius)
                .animation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true), value: on)
                .onAppear { on = true }
        }
    }
}

#endif
