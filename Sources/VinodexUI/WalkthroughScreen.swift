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

                DeviceDiagram(highlight: step.highlight, skin: skin, lcd: lcd)
                    .frame(height: 168)
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
    let skin: ChassisSkin
    let lcd: LcdMode

    /// Whether a part is the subject of this step. `.device` lights everything,
    /// which is how the first and last steps say "this whole object".
    private func lit(_ part: WalkthroughStep.Highlight) -> Bool {
        highlight == .device || highlight == part
    }

    private func dim(_ part: WalkthroughStep.Highlight) -> Double {
        lit(part) ? 1 : 0.25
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = min(geo.size.width, h * 0.62)
            let control = h * 0.13

            ZStack {
                RoundedRectangle(cornerRadius: h * 0.1)
                    .fill(skin.body)
                    .overlay(
                        RoundedRectangle(cornerRadius: h * 0.1)
                            .strokeBorder(skin.panelEdge.opacity(0.6), lineWidth: 2)
                    )

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
                            Circle().fill(Dex.red600)
                            Circle().fill(Dex.yellow400)
                            Circle().fill(Dex.green500)
                        }
                        .frame(width: control * 0.62, height: control * 0.2)
                        .opacity(dim(.lights))

                        Spacer(minLength: 0)

                        Circle()
                            .fill(Dex.stone700)
                            .frame(width: control, height: control)
                            .overlay(Circle().strokeBorder(Dex.stone400, lineWidth: 1.5))
                            .overlay(
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: control * 0.5))
                                    .foregroundStyle(Dex.stone200)
                            )
                            .opacity(dim(.settings))
                            .shadow(color: lcd.accent.opacity(lit(.settings) ? 0.8 : 0), radius: 6)
                    }
                    .frame(width: w * 0.84)

                    // The screen housing.
                    RoundedRectangle(cornerRadius: h * 0.05)
                        .fill(skin.panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: h * 0.04)
                                .fill(lcd.isLight ? lcd.screen : Dex.screen)
                                .padding(h * 0.022)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: h * 0.04)
                                .strokeBorder(lcd.accent, lineWidth: lit(.screen) ? 2.5 : 0)
                                .padding(h * 0.022)
                        )
                        .frame(width: w * 0.88)
                        .opacity(dim(.screen))
                        .shadow(color: lcd.accent.opacity(lit(.screen) ? 0.7 : 0), radius: 8)

                    // Footer: back/saved, marquee, home.
                    HStack(spacing: 6) {
                        // One circle standing for both, since they share a slot
                        // on the real chassis — Back becomes the saved button on
                        // the main menu. The tour says so in words.
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
                                Image(systemName: lit(.saved) ? "person.crop.circle" : "chevron.left")
                                    .font(.system(size: control * 0.5, weight: .bold))
                                    .foregroundStyle(skin.control.glyph)
                            )
                            .opacity(max(dim(.back), dim(.saved)))
                            .shadow(
                                color: lcd.accent.opacity(lit(.back) || lit(.saved) ? 0.8 : 0),
                                radius: 6
                            )

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
