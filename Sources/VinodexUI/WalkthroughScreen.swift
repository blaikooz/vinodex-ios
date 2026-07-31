#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The guided tour: a little diagram of the device with one part lit, and a
/// friendly paragraph about it.
///
/// **Why a diagram rather than spotlights on the live chassis.** The obvious
/// build is an overlay that dims the real device and cuts a hole over the real
/// Back button. It is also the one that breaks: the tour would have to drive the
/// navigation stack to reach each screen it wants to talk about, every step
/// would depend on the exact geometry of a control that moves between screens
/// (Back *is* the saved button on the main menu), and a user who tapped
/// something mid-tour would end up somewhere the script did not expect. A
/// diagram is a drawing that cannot desynchronise from anything.
///
/// It is drawn from the same `DexMetrics` proportions as the real chassis and
/// tinted by the same `ChassisSkin`, so it is recognisably *this* device in
/// *your* colourway rather than generic artwork.
public struct WalkthroughScreen: View {
    let onFinish: () -> Void

    @State private var index = 0
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue

    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }

    public init(onFinish: @escaping () -> Void = {}) {
        self.onFinish = onFinish
    }

    private var steps: [WalkthroughStep] { Walkthrough.steps }
    private var step: WalkthroughStep { steps[min(index, steps.count - 1)] }
    private var isLast: Bool { index >= steps.count - 1 }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            VStack(spacing: 14) {
                progress

                DeviceDiagram(highlight: step.highlight, isolated: step.isolated, skin: skin, lcd: lcd)
                    .frame(height: 230)
                    // Redrawn per step so the lit part animates rather than
                    // cutting, which is what makes it read as "look here".
                    .animation(.easeInOut(duration: 0.3), value: step.highlight)

                copy

                Spacer(minLength: 0)

                controls
            }
            .padding(16)
        }
    }

    private var progress: some View {
        HStack(spacing: 5) {
            ForEach(steps.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? lcd.accent : lcd.surfaceEdge)
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: index)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(step.title)
                .font(DexFont.retro(16))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)

            Text(step.body)
                .font(DexFont.mono(21))
                .foregroundStyle(lcd.bodyText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 2)
        )
    }

    private var controls: some View {
        HStack(spacing: 10) {
            if index > 0 {
                Button {
                    Haptics.select()
                    withAnimation(.easeOut(duration: 0.2)) { index -= 1 }
                } label: {
                    pill("BACK", fill: lcd.surface, ink: lcd.subtext, border: lcd.surfaceEdge)
                }
                .buttonStyle(DexPressStyle(scale: 0.97))
            }

            Button {
                Haptics.tap()
                if isLast {
                    onFinish()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { index += 1 }
                }
            } label: {
                pill(
                    isLast ? "FINISH" : "NEXT",
                    fill: lcd.accent,
                    // Never white on mint — see the note in `ChipFilterScreen`.
                    ink: lcd.isLight ? .white : .black,
                    border: lcd.accent
                )
            }
            .buttonStyle(DexPressStyle(scale: 0.97))
        }
    }

    private func pill(_ text: String, fill: Color, ink: Color, border: Color) -> some View {
        Text(text)
            .font(DexFont.retro(12))
            .tracking(1.5)
            .foregroundStyle(ink)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(border, lineWidth: 2))
    }
}

// MARK: - The diagram

/// A miniature of the chassis, with one part lit.
///
/// Deliberately schematic — this is a map, not a screenshot. Everything unlit is
/// drawn at low opacity so the highlighted part is the only thing with contrast,
/// which is the whole job.
struct DeviceDiagram: View {
    let highlight: WalkthroughStep.Highlight
    /// See `WalkthroughStep.isolated`: the opening step hides everything
    /// that is not its subject instead of dimming it.
    var isolated: Bool = false
    let skin: ChassisSkin
    let lcd: LcdMode

    /// Whether a part is the subject of this step. `.device` lights everything,
    /// which is how the last step says "this whole object". The tools step
    /// lights the cog too — TOOLS lives behind it, and the step's whole point
    /// is showing that path.
    private func lit(_ part: WalkthroughStep.Highlight) -> Bool {
        highlight == .device || highlight == part
            || (part == .settings && highlight == .tools)
    }

    private func dim(_ part: WalkthroughStep.Highlight) -> Double {
        // 0.38, up from 0.25 — at the old value the unlit parts vanished
        // entirely on the dark skins and the diagram read as one floating dot.
        // Isolated steps do want them vanished; that is their whole point.
        if lit(part) { return 1 }
        return isolated ? 0 : 0.38
    }

    /// One of the main menu's category buttons, at diagram scale — the same
    /// glyph and face colour as `MainMenuScreen`'s tile, so the miniature is
    /// recognisably the real menu.
    private func miniMenuTile(_ symbol: String, _ hex: String, control: CGFloat, ink: Color = .white) -> some View {
        RoundedRectangle(cornerRadius: control * 0.18)
            .fill(Color(dexHex: hex))
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: control * 0.42, weight: .semibold))
                    .foregroundStyle(ink)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The entry step's little LCD: a mocked-up entry page — icon well and
    /// title, the three-tile link row, then section rules with rows — so the
    /// copy about "one shape" has the shape right there to point at.
    private func miniEntryMock(control: CGFloat, spacing: CGFloat) -> some View {
        VStack(spacing: spacing * 2) {
            // Hero: icon well + name bar.
            VStack(spacing: spacing) {
                RoundedRectangle(cornerRadius: control * 0.18)
                    .fill(Color(dexHex: "#8B0000"))
                    .frame(width: control * 0.8, height: control * 0.8)
                    .overlay(
                        Image(systemName: "leaf.fill")
                            .font(.system(size: control * 0.4, weight: .semibold))
                            .foregroundStyle(Color(dexHex: "#E03131"))
                    )
                Capsule()
                    .fill(lcd.text.opacity(0.9))
                    .frame(width: control * 1.7, height: 4)
            }
            // The three link tiles.
            HStack(spacing: spacing) {
                miniMenuTile("wineglass.fill", "#7f1d1d", control: control)
                miniMenuTile("scalemass.fill", "#78350f", control: control)
                miniMenuTile("flag.fill", "#1e3a8a", control: control)
            }
            .frame(height: control * 0.7)
            // Two sections: an accent rule, then rows.
            VStack(alignment: .leading, spacing: spacing) {
                Capsule().fill(lcd.accent).frame(width: control * 1.2, height: 3)
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(lcd.surface)
                        .frame(height: control * 0.28)
                        .overlay(alignment: .trailing) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: control * 0.16, weight: .bold))
                                .foregroundStyle(lcd.subtext)
                                .padding(.trailing, 3)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(lcd.surfaceEdge, lineWidth: 0.5)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The tools step's little LCD: a mock of the settings grid, with the
    /// TOOLS tile glowing. The other three tiles are the grid's real
    /// neighbours (TUTORIAL, CUSTOMIZE, SETTINGS), so the drawing points at
    /// where TOOLS actually sits rather than at a made-up menu.
    private func miniSettingsGrid(control: CGFloat, spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                miniMenuTile("flag.checkered", "#22c55e", control: control)
                miniMenuTile("wrench.and.screwdriver.fill", "#FACC15", control: control, ink: Dex.amber900)
                    .overlay(
                        RoundedRectangle(cornerRadius: control * 0.18)
                            .strokeBorder(.white, lineWidth: 2)
                    )
                    .shadow(color: Dex.yellow.opacity(0.9), radius: 6)
            }
            HStack(spacing: spacing) {
                miniMenuTile("paintpalette.fill", "#ef4444", control: control)
                miniMenuTile("slider.horizontal.3", "#f97316", control: control)
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = min(geo.size.width, h * 0.62)
            let control = h * 0.15

            ZStack {
                // Dark base under the body so a translucent GLOUGLOU shell has
                // something to be smoke over; opaque skins cover it entirely.
                RoundedRectangle(cornerRadius: h * 0.1)
                    .fill(Color(dexHex: "#1b1d21"))
                    .overlay(RoundedRectangle(cornerRadius: h * 0.1).fill(skin.body))
                    .overlay(
                        RoundedRectangle(cornerRadius: h * 0.1)
                            .strokeBorder(skin.panelEdge.opacity(0.6), lineWidth: 2)
                    )
                    // Isolated steps hide the parts; the shell fades to a
                    // ghost so the one lit control still has somewhere to be.
                    .opacity(isolated && highlight != .device ? 0.15 : 1)

                VStack(spacing: h * 0.035) {
                    // Island strip: orb + lights on the left, cog on the right.
                    HStack(spacing: 6) {
                        Circle()
                            .fill(skin.orb)
                            .frame(width: control, height: control)
                            .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5))
                            .opacity(dim(.orb))
                            .shadow(color: skin.orbGlow.opacity(lit(.orb) ? 0.9 : 0), radius: 6)

                        HStack(spacing: 2.5) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle().fill(skin.statusLights[i].fill)
                                    .overlay(Circle().strokeBorder(skin.statusLights[i].border, lineWidth: 1))
                            }
                        }
                        .frame(width: control * 0.75, height: control * 0.26)
                        .opacity(dim(.lights))

                        Spacer(minLength: 0)

                        // The skin's caps, like the real cog (v0.5.4).
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [skin.control.top, skin.control.bottom],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: control, height: control)
                            .overlay(Circle().strokeBorder(skin.control.edge, lineWidth: 1.5))
                            .overlay(
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: control * 0.5))
                                    .foregroundStyle(Dex.stone200)
                            )
                            .opacity(dim(.settings))
                            .shadow(color: lcd.accent.opacity(lit(.settings) ? 0.8 : 0), radius: 6)
                    }
                    .frame(width: w * 0.84)

                    // The screen housing — with the main menu's four category
                    // buttons drawn on the little LCD, so the step about the
                    // screen can point at the buttons it is describing rather
                    // than at an empty rectangle.
                    RoundedRectangle(cornerRadius: h * 0.05)
                        .fill(skin.panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: h * 0.04)
                                .fill(lcd.ground)
                                .padding(h * 0.022)
                        )
                        .overlay {
                            if highlight == .tools {
                                // The tools step swaps the little LCD to a
                                // mock of the settings grid — see
                                // `miniSettingsGrid`.
                                miniSettingsGrid(control: control, spacing: h * 0.016)
                                    .padding(h * 0.05)
                            } else if highlight == .entry {
                                miniEntryMock(control: control, spacing: h * 0.016)
                                    .padding(h * 0.05)
                            } else {
                                VStack(spacing: h * 0.016) {
                                    HStack(spacing: h * 0.016) {
                                        miniMenuTile("circle.grid.3x3.fill", "#a855f7", control: control)
                                        miniMenuTile("globe.americas.fill", "#22c55e", control: control)
                                    }
                                    // The master-search button sits between the
                                    // rows, exactly where the real menu puts it.
                                    ZStack {
                                        Circle().fill(Dex.yellow)
                                        Circle().strokeBorder(Dex.yellow600, lineWidth: 2)
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: control * 0.4, weight: .bold))
                                            .foregroundStyle(Dex.amber900)
                                    }
                                    .frame(width: control * 0.8, height: control * 0.8)
                                    // No opacity of its own — the housing already
                                    // dims everything on the little LCD together,
                                    // and stacking a second dim made this button
                                    // darker than its neighbours.
                                    .shadow(color: Dex.yellow.opacity(lit(.search) ? 0.9 : 0), radius: 6)
                                    HStack(spacing: h * 0.016) {
                                        miniMenuTile("wineglass.fill", "#f97316", control: control)
                                        miniMenuTile("leaf.fill", "#10b981", control: control)
                                    }
                                }
                                .padding(h * 0.05)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: h * 0.04)
                                .strokeBorder(lcd.accent, lineWidth: lit(.screen) ? 2.5 : 0)
                                .padding(h * 0.022)
                        )
                        .frame(width: w * 0.88)
                        // The search, tools and entry steps light a part
                        // *inside* the housing — dimming the housing would dim
                        // its own subject.
                        .opacity(
                            highlight == .search || highlight == .tools || highlight == .entry
                                ? 1 : dim(.screen)
                        )
                        .shadow(color: lcd.accent.opacity(lit(.screen) ? 0.7 : 0), radius: 8)

                    // Footer: back, saved, marquee, home — the actual buttons.
                    //
                    // Back and Saved share a slot on the real chassis (Back
                    // becomes the saved button on the main menu), but the
                    // diagram shows both: the tour has a step for each, and a
                    // glyph that swapped mid-tour looked like a redraw bug.
                    HStack(spacing: 6) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [skin.control.top, skin.control.bottom],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: control, height: control)
                            .overlay(Circle().strokeBorder(skin.control.edge, lineWidth: 1.5))
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .font(.system(size: control * 0.5, weight: .bold))
                                    .foregroundStyle(skin.control.glyph)
                            )
                            .opacity(dim(.back))
                            .shadow(color: lcd.accent.opacity(lit(.back) ? 0.8 : 0), radius: 6)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [skin.control.top, skin.control.bottom],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: control, height: control)
                            .overlay(Circle().strokeBorder(skin.control.edge, lineWidth: 1.5))
                            .overlay(
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: control * 0.5, weight: .bold))
                                    .foregroundStyle(skin.control.glyph)
                            )
                            .opacity(dim(.saved))
                            .shadow(color: lcd.accent.opacity(lit(.saved) ? 0.8 : 0), radius: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(.black)
                            .overlay(
                                Capsule()
                                    .fill(skin.marqueeText)
                                    .frame(height: 2.5)
                                    .padding(.horizontal, 5)
                            )
                            .frame(height: control * 0.62)
                            .opacity(dim(.marquee))

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [skin.accent.light, skin.accent.mid],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: control, height: control)
                            .overlay(Circle().strokeBorder(skin.accent.edge, lineWidth: 1.5))
                            .overlay(
                                Image(systemName: "house.fill")
                                    .font(.system(size: control * 0.45, weight: .bold))
                                    .foregroundStyle(skin.accent.ink)
                            )
                            .opacity(dim(.home))
                            .shadow(color: lcd.accent.opacity(lit(.home) ? 0.8 : 0), radius: 6)
                    }
                    .frame(width: w * 0.84)
                }
                .padding(.vertical, h * 0.05)
            }
            .frame(width: w, height: h)
            .frame(maxWidth: .infinity)
        }
    }
}
#endif
