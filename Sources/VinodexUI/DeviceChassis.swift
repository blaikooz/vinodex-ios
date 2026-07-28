#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The retro handheld chassis that wraps every screen.
///
/// Re-proportions to fill the display rather than preserving the desktop
/// 522x850 box: bezel, vent and footer thicknesses stay fixed and the LCD
/// absorbs the remaining height. That matches what the CSS already does below
/// the `md:` breakpoint, so a phone sees the same layout the web app gives it.
public struct DeviceChassis<Content: View>: View {
    let title: String
    var showsBack: Bool = false
    var onBack: (() -> Void)?
    var onHome: (() -> Void)?
    @ViewBuilder var content: () -> Content

    /// The system panel lives here rather than in the app module so it can be
    /// confined to the LCD — see `SettingsPanel`.
    @State private var showsPanel = false

    public init(
        title: String,
        showsBack: Bool = false,
        onBack: (() -> Void)? = nil,
        onHome: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showsBack = showsBack
        self.onBack = onBack
        self.onHome = onHome
        self.content = content
    }

    private var isMainScreen: Bool { title == "VINODEX" }

    private var footerTitle: String {
        isMainScreen ? "CHEERS! - SANTE! - SALUTE! - PROST! - KANPAI!" : title
    }

    public var body: some View {
        // The whole chassis is laid out in physical-screen coordinates so the
        // top safe-area strip — the band containing the Dynamic Island — can be
        // used rather than wasted. Insets are then reserved explicitly.
        GeometryReader { geo in
            let topStrip = max(geo.safeAreaInsets.top, DexMetrics.islandStripMinHeight)
            let bottomInset = geo.safeAreaInsets.bottom

            ZStack(alignment: .top) {
                Dex.red

                VStack(spacing: 0) {
                    Color.clear.frame(height: topStrip)
                    screenHousing
                    // The footer band absorbs the home-indicator inset rather
                    // than sitting above it, which drops the marquee and the
                    // control buttons toward the bottom edge.
                    footer(extraBottom: bottomInset)
                }

                islandFlank(height: topStrip)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
        .background(Dex.red.ignoresSafeArea())
    }

    // MARK: Island flank
    //
    // Orb + status lights to the left of the Dynamic Island, wordmark to the
    // right. This band is otherwise dead chassis, so using it costs the LCD
    // nothing — the bezel keeps none of it.

    private func islandFlank(height: CGFloat) -> some View {
        // Orb and lights scale to the strip rather than using a fixed size, so
        // they stay as large as fits neatly whatever inset the device reports.
        let orb = min(height * 0.72, 46)

        return HStack(spacing: 0) {
            HStack(spacing: orb * 0.22) {
                lcdOrb(size: orb)
                statusDots(size: max(orb * 0.26, 8))
            }
            // `fixedSize` first: without it the inner HStack stays greedy and the
            // trailing alignment has nothing to push against, leaving the orb
            // pinned to the far left.
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, DexMetrics.islandFlankInnerGap)

            // Clearance held open for the cutout itself.
            Color.clear.frame(width: DexMetrics.islandClearance)

            logoButton(height: height)
                .fixedSize()
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DexMetrics.islandFlankPaddingH)
        .frame(height: height)
    }

    /// The pixel-V mark. Tapping it opens the system panel — a deliberate,
    /// discoverable-once affordance rather than a gesture that fights scrolling.
    ///
    /// Styled as a physical key on the chassis: a raised well and a lit ring
    /// while open, so it reads as a button rather than decoration.
    private func logoButton(height: CGFloat) -> some View {
        Button {
            Haptics.tap()
            showsPanel.toggle()
        } label: {
            LogoMark()
                .frame(width: height * 0.52, height: height * 0.52)
                .padding(height * 0.13)
                .background(Circle().fill(Dex.darkRed.opacity(showsPanel ? 0.55 : 0.28)))
                .overlay(
                    Circle().strokeBorder(
                        showsPanel ? Dex.yellow : Dex.darkRed,
                        lineWidth: showsPanel ? 3 : 2
                    )
                )
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                // Comfortably past the 44pt minimum even on a short strip.
                .contentShape(Circle())
        }
        .buttonStyle(DexPressStyle(scale: 0.86))
        .accessibilityLabel("System panel")
    }

    private func lcdOrb(size: CGFloat) -> some View {
        Circle()
            .fill(Dex.cyan300)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.white, lineWidth: max(size * 0.07, 2)))
            .overlay(alignment: .top) {
                // Specular highlight, kept proportional to the orb.
                Circle()
                    .fill(.white.opacity(0.8))
                    .frame(width: size * 0.26, height: size * 0.26)
                    .blur(radius: 1)
                    .padding(.top, size * 0.1)
            }
            .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
            .modifier(PulseGlow(color: Dex.blue, period: 5.3, minRadius: 2, maxRadius: size * 0.3))
    }

    private func statusDots(size: CGFloat) -> some View {
        HStack(spacing: size * 0.55) {
            statusDot(Dex.red600, border: Dex.red800, period: 6.1, size: size)
            statusDot(Dex.yellow400, border: Dex.yellow600, period: 7.4, size: size)
            statusDot(Dex.green500, border: Dex.green700, period: 4.8, size: size)
        }
    }

    private func statusDot(_ fill: Color, border: Color, period: Double, size: CGFloat) -> some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(border, lineWidth: 1))
            .modifier(PulseGlow(color: fill, period: period, minRadius: 1, maxRadius: size * 0.7))
    }

    // MARK: Screen

    private var screenHousing: some View {
        // The white bezel: 6pt borders on left/right/bottom, none on top.
        VStack(spacing: 0) {
            // Just enough margin to clear the bezel's rounded corner — the orb,
            // lights and wordmark now live in the island strip above.
            Color.clear.frame(height: DexMetrics.bezelTopMargin)
            innerBezel
            bottomVents
        }
        .background(Dex.ui)
        .clipShape(
            .rect(
                topLeadingRadius: DexMetrics.screenPanelCorner,
                bottomLeadingRadius: DexMetrics.screenPanelCorner,
                bottomTrailingRadius: DexMetrics.screenPanelCorner,
                topTrailingRadius: DexMetrics.screenPanelCorner
            )
        )
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: DexMetrics.screenPanelCorner,
                bottomLeadingRadius: DexMetrics.screenPanelCorner,
                bottomTrailingRadius: DexMetrics.screenPanelCorner,
                topTrailingRadius: DexMetrics.screenPanelCorner
            )
            .strokeBorder(Dex.stone400, lineWidth: DexMetrics.screenPanelBorder)
        }
        .padding(.horizontal, DexMetrics.screenPanelInset)
        .frame(maxHeight: .infinity)
    }

    private var ventDot: some View {
        Circle()
            .fill(Dex.red500)
            .frame(width: DexMetrics.ventDot, height: DexMetrics.ventDot)
            .overlay(Circle().strokeBorder(Dex.red800, lineWidth: 1))
            .shadow(color: Dex.red500.opacity(0.8), radius: 3)
    }

    private var innerBezel: some View {
        ZStack {
            Dex.screen
            content()

            // Confined to the LCD, so the bezel, footer and island stay put and
            // the panel reads as the device's own menu rather than an iOS modal.
            if showsPanel {
                SettingsPanel { showsPanel = false }
                    .padding(6)
                    .transition(.opacity)
            }

            ScanlineOverlay()
                .opacity(DexMetrics.scanlineOpacity)
                .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.16), value: showsPanel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DexMetrics.bezelCorner))
        // A thin stone frame, equal on every side so the LCD sits centred.
        // Note this is deliberately small: padding here costs LCD height, and
        // a uniform `bezelInsetH` (12pt) took 24pt of vertical space away.
        .padding(DexMetrics.bezelFrame)
        .background(
            RoundedRectangle(cornerRadius: DexMetrics.bezelCorner + DexMetrics.bezelFrame)
                .fill(Dex.stone800)
        )
        // Horizontal only — this insets the housing without costing height.
        .padding(.horizontal, DexMetrics.bezelInsetH - DexMetrics.bezelFrame)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomVents: some View {
        ZStack {
            Circle()
                .fill(Dex.red500)
                .frame(width: DexMetrics.ventDot, height: DexMetrics.ventDot)
                .overlay(Circle().strokeBorder(Dex.red800, lineWidth: 1))
                .shadow(color: Dex.red500.opacity(0.8), radius: 3)

            HStack {
                Spacer()
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().fill(Dex.stone400).frame(width: 64, height: 2)
                    }
                }
                .opacity(0.5)
                .padding(.trailing, DexMetrics.headerPaddingH)
            }
        }
        .frame(height: DexMetrics.ventStripHeight)
    }

    // MARK: Footer

    private func footer(extraBottom: CGFloat) -> some View {
        HStack(spacing: 8) {
            ChassisButton(kind: .back, enabled: showsBack && onBack != nil) {
                onBack?()
            }

            MarqueeBanner(
                text: footerTitle,
                fontSize: DexMetrics.marqueeTextSize
            )
            .frame(maxWidth: DexMetrics.marqueeMaxWidth)
            .frame(maxWidth: .infinity)

            ChassisButton(kind: .home, enabled: onHome != nil) {
                onHome?()
            }
        }
        .padding(.horizontal, DexMetrics.footerPaddingH)
        // Nudges the buttons and banner toward the bottom edge.
        .padding(.top, DexMetrics.footerTopNudge)
        .frame(height: DexMetrics.footerHeight + DexMetrics.footerTopNudge)
        .padding(.bottom, extraBottom)
        .background(Dex.red.opacity(0.7))
    }
}

// MARK: - Chassis buttons

/// The physical-looking Back and Home buttons.
///
/// Haptics fire here rather than at call sites so every chassis button feels the
/// same — the main thing a native build can offer that the web app cannot.
public struct ChassisButton: View {
    public enum Kind { case back, home }

    let kind: Kind
    let enabled: Bool
    let action: () -> Void

    public init(kind: Kind, enabled: Bool = true, action: @escaping () -> Void) {
        self.kind = kind
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            ZStack {
                Circle().fill(gradient)
                Circle().strokeBorder(borderColor, lineWidth: 3)
                icon
            }
            .frame(width: DexMetrics.controlButton, height: DexMetrics.controlButton)
            .shadow(color: .black.opacity(0.6), radius: 6, y: 8)
        }
        .buttonStyle(DexPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private var gradient: LinearGradient {
        switch kind {
        case .back:
            LinearGradient(colors: [Dex.stone700, Dex.stone950], startPoint: .top, endPoint: .bottom)
        case .home:
            LinearGradient(colors: [Dex.amber200, Dex.amber500], startPoint: .top, endPoint: .bottom)
        }
    }

    private var borderColor: Color {
        kind == .back ? Dex.stone900 : Dex.amber700
    }

    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .back:
            Image(systemName: "chevron.left")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.white)
        case .home:
            Circle()
                .fill(LinearGradient(colors: [Dex.amber100, Dex.amber400], startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(Dex.amber500, lineWidth: 1))
                .padding(2)
                .overlay {
                    Image(systemName: "house.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Dex.amber900)
                }
        }
    }
}

/// Chunky press feedback mirroring the web app's `active:scale` / `active:translate-y`.
public struct DexPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    public init(scale: CGFloat = 0.96) { self.scale = scale }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

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
    public init() {}

    public var body: some View {
        ZStack {
            Dex.stone950
            DexGridBackground(spacing: 10, color: Dex.stone700, opacity: 0.35)
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

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(on ? 0.8 : 0.25), radius: on ? maxRadius : minRadius)
            .animation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

/// The scrolling footer banner. Ports `terminal-marquee`: two copies of the
/// label offset by one cycle, which loops seamlessly.
///
/// The animation is started from `onChange(of:)` rather than `onAppear` —
/// the label is measured by a background reader, so at `onAppear` the width is
/// still zero and the animation would never run.
public struct MarqueeBanner: View {
    let text: String
    let fontSize: CGFloat
    var pointsPerSecond: Double = 34

    @State private var labelWidth: CGFloat = 0

    private let gap: CGFloat = 44

    public init(text: String, fontSize: CGFloat, pointsPerSecond: Double = 34) {
        self.text = text
        self.fontSize = fontSize
        self.pointsPerSecond = pointsPerSecond
    }

    public var body: some View {
        // A GeometryReader gives the scrolling strip a *definite* width to clip
        // against. Without one the `.fixedSize()` label pair — ~1500pt for the
        // main-menu text — ignores any `maxWidth` and renders full-bleed across
        // the footer, covering the Back button.
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner)
                    .fill(.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: DexMetrics.marqueeCorner)
                            .strokeBorder(.white.opacity(0.75), lineWidth: 1)
                    )

                // Offset is derived from elapsed time rather than driven by a
                // `withAnimation` loop. A repeatForever animation gets torn down
                // and restarted whenever the view re-renders — which is what made
                // the text skip and change speed — while a TimelineView is a pure
                // function of the clock and cannot drift.
                TimelineView(.animation) { context in
                    let cycle = labelWidth + gap
                    let elapsed = context.date.timeIntervalSinceReferenceDate
                    let travelled = cycle > 0
                        ? CGFloat((elapsed * pointsPerSecond)
                            .truncatingRemainder(dividingBy: Double(cycle)))
                        : 0

                    HStack(spacing: gap) {
                        label
                            .background(
                                GeometryReader { inner in
                                    Color.clear
                                        .onAppear { labelWidth = inner.size.width }
                                        .onChange(of: inner.size.width) { _, new in labelWidth = new }
                                }
                            )
                        label
                    }
                    .fixedSize()
                    .offset(x: -travelled)
                    .frame(
                        width: max(geo.size.width - 8, 0),
                        height: max(geo.size.height - 8, 0),
                        alignment: .leading
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DexMetrics.marqueeInnerCorner))
                }
            }
        }
        .frame(height: DexMetrics.marqueeHeight)
    }

    private var label: some View {
        Text(text)
            .font(DexFont.retro(fontSize))
            .italic()
            .foregroundStyle(Dex.green500)
            .lineLimit(1)
            .fixedSize()
            .shadow(color: Color(dexHex: "#082010").opacity(0.65), radius: 0, x: 1, y: 1)
    }

}

/// The pixel-V wordmark, bundled from the web app's logo.
public struct LogoMark: View {
    public init() {}

    public var body: some View {
        if let url = DexResources.url(named: "vinodex-logo", ext: "png", subdirectory: "Resources/Logo"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Text("V")
                .font(DexFont.retro(16))
                .foregroundStyle(.white)
        }
    }
}
#endif
