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

            // Diagram at the top taking every point the page can spare, then
            // the walkthrough copy at the bottom directly above the buttons
            // (0.6.7, E1/E2).
            //
            // The old order was progress / diagram / copy / **spacer** /
            // controls, which parked the paragraph in the middle of the screen
            // with a growing hole under it — and pinned the diagram at a fixed
            // 230pt while that hole grew to 150 on a tall phone. Moving the
            // spare height from the spacer into the diagram does both items at
            // once: the device gets bigger *because* the text moved down.
            //
            // **The device is a fixed size now (0.8.8, D2), and the page scrolls
            // instead.**
            //
            // The paragraph above is the 0.6.7 argument for the *opposite*, and
            // it was right about the layout it was fixing and wrong about what it
            // cost. `maxHeight: .infinity` with no floor means the diagram is
            // whatever the copy leaves it: the shortest step's body is 84
            // characters and the longest is 175, so the device visibly grew and
            // shrank as you pressed NEXT — a picture that changes size between
            // steps reads as the thing itself changing, which on a tour *about*
            // the device is the one impression it must not give. On a small
            // phone the longest steps squeezed it toward unreadable, and D2 adds
            // four more steps, three of them long.
            //
            // `diagramHeight` is fitted rather than round: it is what the old
            // layout gave the diagram on a mid-size phone with a two-line body,
            // so the common case is unchanged and only the extremes stop moving.
            // The page gains a `ScrollView` in exchange, which is what the 0.6.7
            // note's "one of the two screens that does not scroll" was protecting
            // — a fixed picture and a fixed paragraph cannot both be honoured on
            // every device, and the paragraph is the part you can scroll to.
            ScrollView {
                VStack(spacing: 14) {
                    progress

                    DeviceDiagram(
                        highlight: step.highlight,
                        isolated: step.isolated,
                        skin: skin,
                        lcd: lcd
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.diagramHeight)
                    // Redrawn per step so the lit part animates rather than
                    // cutting, which is what makes it read as "look here".
                    .animation(.easeInOut(duration: 0.3), value: step.highlight)

                    copy

                    controls
                }
                .padding(16)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// The device's one size, on every step. See `body`.
    private static let diagramHeight: CGFloat = 300

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
                Haptics.screenTap()
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
/// The white ring and glow a pointed-at tile wears on the little LCD.
///
/// A modifier rather than the inline overlay it was, because 0.8.8's D2 needs
/// three tiles able to wear it rather than one, and three copies of a border and
/// a shadow is how two of them come to differ.
private struct MiniTileGlow: ViewModifier {
    let on: Bool
    let control: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: control * 0.18)
                    .strokeBorder(.white, lineWidth: on ? 2 : 0)
            )
            .shadow(color: Dex.yellow.opacity(on ? 0.9 : 0), radius: 6)
    }
}

struct DeviceDiagram: View {
    let highlight: WalkthroughStep.Highlight
    /// See `WalkthroughStep.isolated`: the opening step hides everything
    /// that is not its subject instead of dimming it.
    var isolated: Bool = false
    let skin: ChassisSkin
    let lcd: LcdMode

    /// The four caps, resolved through the skin the same way the real chassis
    /// resolves them (0.6.7, K2/K3) — the console liveries colour each button
    /// individually, everything else shares one moulded cap. The diagram claims
    /// to be "this device in your colourway", so it has to follow.
    private var backCap: ChassisControl { skin.buttonSet?.back ?? skin.control }
    private var userCap: ChassisControl { skin.buttonSet?.bookmarks ?? skin.control }
    private var settingsCap: ChassisControl { skin.buttonSet?.settings ?? skin.control }
    private var homeRamp: ChassisAccent { skin.buttonSet?.home ?? skin.accent }

    /// Whether a part is the subject of this step. `.device` lights everything,
    /// which is how the last step says "this whole object". The tools step
    /// lights the cog too — TOOLS lives behind it, and the step's whole point
    /// is showing that path.
    private func lit(_ part: WalkthroughStep.Highlight) -> Bool {
        highlight == .device || highlight == part
            // The cog lights for anything that lives behind it — TOOLS since
            // v0.5.4, and the passport, workshop and shop since 0.8.8's D2. The
            // step's point in every case is the path, and the path starts here.
            || (part == .settings && (highlight == .tools || highlight == .collection))
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

    /// The settings grid on the little LCD, with one tile glowing.
    ///
    /// **Redrawn to the grid that actually exists (0.8.8, D2).** This mock drew
    /// four tiles — TUTORIAL, TOOLS, CUSTOMIZE, SETTINGS — and its own comment
    /// called them "the grid's real neighbours". They stopped being that in
    /// 0.7.6's F1, which took TUTORIAL off the grid entirely (it is a row inside
    /// SETTINGS > DEVICE now, and is where *this very tour* is launched from) and
    /// left five tiles in three rows: two, two, and SHOP the width of the panel.
    /// So the tour's picture of the settings panel had a tile on it that the
    /// panel has not had for four releases — and the tile it had was the tour.
    ///
    /// Symbols and layout track `SettingsPanel.body`; the colours are this
    /// diagram's own flat faces rather than that panel's ground-aware pairs,
    /// because a 20pt square inside a mocked LCD is not the surface those were
    /// tuned for.
    ///
    /// `glowing` is which tile the step is pointing at, so one drawing serves the
    /// tools step and D2's three collection steps rather than four mocks.
    private func miniSettingsGrid(
        control: CGFloat,
        spacing: CGFloat,
        glowing: WalkthroughStep.Highlight
    ) -> some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                miniMenuTile("wrench.and.screwdriver.fill", "#FACC15", control: control, ink: Dex.amber900)
                    .modifier(MiniTileGlow(on: glowing == .tools, control: control))
                miniMenuTile("paintpalette.fill", "#ef4444", control: control)
                    .modifier(MiniTileGlow(on: glowing == .collection, control: control))
            }
            HStack(spacing: spacing) {
                miniMenuTile("slider.horizontal.3", "#f97316", control: control)
                miniMenuTile("chart.bar.fill", "#22c55e", control: control)
            }
            // SHOP, the width of the panel — F1's own layout.
            miniMenuTile("bag.fill", "#a855f7", control: control)
                .frame(height: control * 0.7)
                .modifier(MiniTileGlow(on: glowing == .collection, control: control))
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
                        // A stadium, with the real orb (0.7.5 A2, 0.7.6 E1).
                        // This diagram exists to point at a specific part of the
                        // device the user is holding; it has to be the same part.
                        //
                        // **Width taken from this diagram's own lamp cluster
                        // (0.7.9, A1).** The trio below is `control * 0.75`
                        // across, and the chassis rule is that the orb spans
                        // exactly that. It used to be `control` — wider than the
                        // trio, which was the reading A1 exists to fix — with
                        // the height divided out of a 2.35 aspect. At 5.3 that
                        // arithmetic gives a hairline, so the rim is
                        // proportional here too.
                        let orbShape = Capsule(style: .continuous)
                        let orbW = control * 0.75
                        // The lamp trio below is `control * 0.26` tall, so that
                        // is this diagram's lamp and therefore its orb's height
                        // (0.8.0, C1) — the same one-lamp rule the chassis
                        // follows now. It was `orbW / islandOrbAspect`, which at
                        // 5.3 drew a bead barely half the lamps beside it.
                        let orbH = DexMetrics.islandOrbHeight(lamp: control * 0.26)
                        orbShape
                            .fill(skin.orb)
                            .frame(width: orbW, height: orbH)
                            .overlay(orbShape.strokeBorder(.white.opacity(0.8), lineWidth: max(orbH * 0.11, 0.75)))
                            .opacity(dim(.orb))
                            .shadow(color: skin.orbGlow.opacity(lit(.orb) ? 0.9 : 0), radius: 6)
                            // The row is centred on the orb's old height, so a
                            // shorter bead must not let the lamp cluster beside
                            // it drift up: the slot stays what it was and the
                            // part sits in the middle of it, exactly as the
                            // chassis does with `islandSlot`.
                            .frame(height: control)

                        HStack(spacing: 2.5) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle().fill(skin.statusLights[i].fill)
                                    .overlay(Circle().strokeBorder(skin.statusLights[i].border, lineWidth: 1))
                            }
                        }
                        .frame(width: control * 0.75, height: control * 0.26)
                        .opacity(dim(.lights))

                        Spacer(minLength: 0)

                        // The skin's caps, like the real cog (v0.5.4). Note
                        // the real cog moved to the button band in 0.6.5 and
                        // under User in 0.6.7 (G2); the diagram keeps it up
                        // here because the *step* is about reaching settings,
                        // and a schematic that redraws itself every batch stops
                        // being a map.
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [settingsCap.top, settingsCap.bottom],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: control, height: control)
                            .overlay(Circle().strokeBorder(settingsCap.edge, lineWidth: 1.5))
                            .overlay(
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: control * 0.5))
                                    // The skin's glyph, not a fixed silver —
                                    // the real cog took `control.glyph` in
                                    // 0.6.6 (F1) and this copy did not follow.
                                    .foregroundStyle(settingsCap.glyph)
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
                            if highlight == .tools || highlight == .collection {
                                // The tools step, and D2's three collection
                                // steps, swap the little LCD to a mock of the
                                // settings grid — see `miniSettingsGrid`.
                                miniSettingsGrid(
                                    control: control,
                                    spacing: h * 0.016,
                                    glowing: highlight
                                )
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
                            highlight == .search || highlight == .tools
                                || highlight == .entry || highlight == .collection
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
                                    colors: [backCap.top, backCap.bottom],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: control, height: control)
                            .overlay(Circle().strokeBorder(backCap.edge, lineWidth: 1.5))
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .font(.system(size: control * 0.5, weight: .bold))
                                    .foregroundStyle(backCap.glyph)
                            )
                            .opacity(dim(.back))
                            .shadow(color: lcd.accent.opacity(lit(.back) ? 0.8 : 0), radius: 6)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [userCap.top, userCap.bottom],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: control, height: control)
                            .overlay(Circle().strokeBorder(userCap.edge, lineWidth: 1.5))
                            .overlay(
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: control * 0.5, weight: .bold))
                                    .foregroundStyle(userCap.glyph)
                            )
                            .opacity(dim(.saved))
                            .shadow(color: lcd.accent.opacity(lit(.saved) ? 0.8 : 0), radius: 6)

                        // The marquee column: its two lamp buttons over the
                        // panel, which is how the real footer is stacked.
                        //
                        // The lamps are on the diagram since 0.7.6 (A1) because
                        // there is now a step about them (see `Walkthrough`), and
                        // a step that lights a part the diagram does not draw is
                        // a step pointing at nothing. They take the shell's own
                        // outer two lamp colours, exactly as the chassis does, so
                        // the picture matches the device the reader is holding.
                        VStack(spacing: 2) {
                            HStack(spacing: 3) {
                                Capsule()
                                    .fill(skin.statusLights[0].fill)
                                    .frame(height: control * 0.16)
                                Capsule()
                                    .fill(skin.statusLights[2].fill)
                                    .frame(height: control * 0.16)
                            }
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.black)
                                .overlay(
                                    Capsule()
                                        .fill(skin.marqueeText)
                                        .frame(height: 2.5)
                                        .padding(.horizontal, 5)
                                )
                                .frame(height: control * 0.62)
                        }
                        .opacity(dim(.marquee))
                        .shadow(color: lcd.accent.opacity(lit(.marquee) ? 0.8 : 0), radius: 6)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [homeRamp.light, homeRamp.mid],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: control, height: control)
                            .overlay(Circle().strokeBorder(homeRamp.edge, lineWidth: 1.5))
                            .overlay(
                                Image(systemName: "house.fill")
                                    .font(.system(size: control * 0.45, weight: .bold))
                                    .foregroundStyle(homeRamp.ink)
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
