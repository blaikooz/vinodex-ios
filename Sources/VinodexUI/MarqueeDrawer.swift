#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The quick-access drawer the marquee opens (0.7.1, B4/B5).
///
/// **Why the marquee is the handle.** The panel is mounted once, in the chassis
/// footer, and is therefore the only surface in the app that is on screen on
/// every single route — B4's "tappable from every screen" is free the moment it
/// is a control at all. It is also the one piece of chrome that already *tells*
/// you where you are, so making it the thing you press to go somewhere else is
/// a short step rather than a new idiom.
///
/// **Where it is drawn, and the house rule it bends.** Every overlay in this app
/// is confined to the LCD — `DexAlert`'s own header explains that a system
/// sheet sliding up from the bottom of the *phone* breaks the handheld
/// metaphor, and the settings panel is an overlay for the same reason. A
/// drawer opened from the footer is the first surface with a claim to sit on
/// the chassis instead, and it does not take it: it rises from the bottom edge
/// of the display, which is the edge the marquee is directly below. So it still
/// reads as coming out of the panel, and it still inherits everything the LCD
/// does to its contents — the monochrome pass, the scanlines, the mode's
/// palette. A drawer that stayed in full colour while VINTAGE greyed out the
/// screen behind it would look like an iOS sheet, which is the exact failure
/// the rule exists to prevent.
///
/// **Swipeable** (B5). Down to dismiss, with the drag tracking the finger and a
/// distance-or-velocity release. The app removed its app-wide LCD swipe in
/// 0.6.9 (A1) on the grounds that a gesture riding on whatever screen happened
/// to be mounted had to be negotiated with all of them; this one rides on the
/// drawer's own surface, which is modal and owns every point inside it, so
/// there is nothing to negotiate with. The grab handle is drawn because a
/// gesture with no affordance is the other half of what A1 was complaining
/// about.
struct MarqueeDrawer: View {
    /// Navigate. The chassis closes the drawer first, so this is a plain push.
    let onRoute: (DexRoute) -> Void
    let onClose: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }

    @State private var pins = QuickPinStore.shared
    @State private var access = AccessStore.shared
    @State private var drag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far down the sheet must be dragged to dismiss on release, or how
    /// fast it must be moving. Either, not both: a slow deliberate pull and a
    /// quick flick are both plainly "close this", and requiring distance alone
    /// makes the flick feel broken.
    private static let dismissDistance: CGFloat = 90
    private static let dismissVelocity: CGFloat = 320

    var body: some View {
        ZStack(alignment: .bottom) {
            // The scrim doubles as the other way out. Tapping outside a panel
            // to dismiss it is `DexAlert`'s convention and the one every modal
            // in this app follows.
            Color.black.opacity(lcd.isLight ? 0.32 : 0.66)
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            sheet
                .offset(y: max(drag, 0))
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { drag = $0.translation.height }
                        .onEnded { value in
                            let far = value.translation.height > Self.dismissDistance
                            let fast = value.predictedEndTranslation.height - value.translation.height
                                > Self.dismissVelocity
                            if far || fast {
                                onClose()
                            } else {
                                withAnimation(DexMotion.settle) { drag = 0 }
                            }
                        }
                )
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var sheet: some View {
        VStack(spacing: 0) {
            handle
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    shortcuts
                    tools
                    customize
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
            // The drawer takes at most three-quarters of the display: enough
            // that the sections do not have to scroll on a full-size phone, and
            // little enough that the screen behind it is still visibly there
            // and still visibly what you will come back to.
            .frame(maxHeight: 420)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(lcd.surface)
                .overlay(alignment: .top) {
                    // The skin's phosphor as a hairline along the top edge —
                    // the one place the drawer admits it came out of the
                    // marquee, which is that colour.
                    skin.marqueeText.frame(height: 2)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(lcd.accent.opacity(0.55), lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        )
        .shadow(color: .black.opacity(0.5), radius: 14, y: -4)
        .padding(.horizontal, 6)
    }

    private var handle: some View {
        Capsule()
            .fill(lcd.subtext.opacity(0.55))
            .frame(width: 42, height: 5)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityLabel("Close quick access")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onClose() }
    }

    // MARK: Pin bar (B5)

    /// Two slots, then the five sections that can fill them.
    ///
    /// **Both halves are visible at once rather than behind an edit mode.** A
    /// pin bar whose customisation is hidden is a pin bar nobody customises —
    /// and there are only five candidates, so the chooser is one row. Tap a
    /// chip to go there; hold it to pin it. That is the same tap/hold split the
    /// back plate's stamps already use (tap opens the story, hold picks it up),
    /// so it is a gesture pair this device has taught once already.
    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 8) {
            heading("PINNED")

            HStack(spacing: 8) {
                ForEach(0..<QuickPinStore.capacity, id: \.self) { slot in
                    if slot < pins.pins.count {
                        pinnedSlot(pins.pins[slot])
                    } else {
                        emptySlot
                    }
                }
            }

            // `retro(10)` and guarded (0.7.1, A4). `TypeScale.nominalFloor`
            // is 10 and applies before the scale factor, so nothing in this
            // file ever rendered below it — the smaller numbers were a lie
            // about what ships, and this line needed 312pt of a 295pt sheet at
            // the HUGE step and wrapped, displacing the chip row under it.
            Text("HOLD A SHORTCUT TO PIN IT")
                .font(DexFont.retro(10))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(lcd.disabledText)

            HStack(spacing: 6) {
                ForEach(SettingsSection.allCases.filter { $0 != .dev }) { section in
                    sectionChip(section)
                }
            }
        }
    }

    private func pinnedSlot(_ section: SettingsSection) -> some View {
        Button {
            Haptics.screenTap()
            onRoute(.settingsSection(section))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: section.symbol)
                    .font(.system(size: 14, weight: .bold))
                Text(section.rawValue)
                    .font(DexFont.retro(10))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(lcd.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 8).fill(lcd.accent))
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
        .accessibilityLabel("\(section.rawValue), pinned shortcut")
    }

    /// An empty slot says what it is for rather than being blank.
    ///
    /// Dashed, and not a button: the way to fill it is the chip row below, and
    /// a tappable placeholder that opened a *second* chooser would be a third
    /// path to a two-item setting.
    private var emptySlot: some View {
        HStack(spacing: 6) {
            Image(systemName: "pin")
                .font(.system(size: 12, weight: .bold))
            Text("EMPTY")
                .font(DexFont.retro(10))
                .tracking(1)
        }
        .foregroundStyle(lcd.disabledText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    lcd.surfaceEdge,
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
        )
        .accessibilityLabel("Empty pin slot")
    }

    private func sectionChip(_ section: SettingsSection) -> some View {
        let pinned = pins.isPinned(section)

        return Button {
            Haptics.screenTap()
            onRoute(.settingsSection(section))
        } label: {
            VStack(spacing: 4) {
                Image(systemName: section.symbol)
                    .font(.system(size: 15, weight: .semibold))
                // Four chips in a 295pt row give 69pt columns, and CUSTOMIZE
                // needs 108 — so the scale floor was doing real work here and
                // resolved near 0.64, about 7pt of a face whose pixels stop
                // being legible below that. Two lines is the cheaper fix than
                // shrinking further (0.7.1, A4).
                Text(section.rawValue)
                    .font(DexFont.retro(10))
                    .tracking(0.5)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(pinned ? lcd.accent : lcd.subtext)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(lcd.well)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(
                                pinned ? lcd.accent : lcd.surfaceEdge,
                                lineWidth: pinned ? 2 : 1
                            )
                    )
            )
            .overlay(alignment: .topTrailing) {
                if pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(lcd.accent)
                        .padding(3)
                }
            }
        }
        .buttonStyle(DexPressStyle(scale: 0.95))
        // Hold to pin. `simultaneousGesture` rather than `.gesture` so the
        // button's own tap is not swallowed — the two do different things and
        // both must survive.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                Haptics.select()
                pins.toggle(section)
            }
        )
        .accessibilityLabel("\(section.rawValue)\(pinned ? ", pinned" : "")")
        .accessibilityHint("Press and hold to \(pinned ? "unpin" : "pin") this shortcut")
        .accessibilityAction(named: pinned ? "Unpin" : "Pin") { pins.toggle(section) }
    }

    // MARK: Tools (B5)

    /// The tools shelf, at drawer scale.
    ///
    /// The same five routes `ToolsScreen` offers, minus LABEL SCAN, which is a
    /// coming-soon placeholder and has no business taking a slot in a shortcut
    /// list. MASTER SEARCH leads because it is the app's most-used destination
    /// and the one the drawer most obviously saves a trip to.
    private var tools: some View {
        VStack(alignment: .leading, spacing: 8) {
            heading("TOOLS")
            LazyVGrid(columns: Self.gridColumns, spacing: 8) {
                quickTile(.chipFilter)
                quickTile(.scanner)
                quickTile(.wsetQuiz)
                quickTile(.dailyChallenge)
                quickTile(.dailyGrape)
                quickTile(.moonDial)
            }
        }
    }

    // MARK: Customize (B5)

    /// Two cycles and a door.
    ///
    /// The cycles are the reason this section is worth having at all: trying a
    /// shell against a screen mode is the one customisation people actually do
    /// repeatedly, and doing it from the settings panel means leaving whatever
    /// you were looking at. From here the device changes under a screen you can
    /// still see.
    ///
    /// **Both respect the paywall.** `ChassisSkin.next` and `LcdMode.next` walk
    /// `allCases` and would happily land on a locked shell, so a locked cycle
    /// pushes the CUSTOMIZE panel instead, which is where the upgrade prompt
    /// lives. Cheaper and more honest than reimplementing that prompt here.
    private var customize: some View {
        VStack(alignment: .leading, spacing: 8) {
            heading("CUSTOMIZE")
            LazyVGrid(columns: Self.gridColumns, spacing: 8) {
                actionTile(title: "NEXT\nSKIN", symbol: "paintbrush.fill") {
                    guard access.isUnlocked(.skins) else {
                        onRoute(.settingsSection(.customization))
                        return
                    }
                    skinRaw = skin.next.rawValue
                }
                actionTile(title: "NEXT\nSCREEN", symbol: "display") {
                    guard access.isUnlocked(.lightMode) else {
                        onRoute(.settingsSection(.customization))
                        return
                    }
                    lcdRaw = lcd.next.rawValue
                }
                actionTile(title: "ALL\nOPTIONS", symbol: SettingsSection.customization.symbol) {
                    onRoute(.settingsSection(.customization))
                }
            }
        }
    }

    // MARK: Furniture

    private static let gridColumns = [GridItem(.flexible(), spacing: 8),
                                      GridItem(.flexible(), spacing: 8),
                                      GridItem(.flexible(), spacing: 8)]

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(DexFont.retro(11))
            .tracking(1.5)
            .foregroundStyle(lcd.subtext)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A tile that navigates. Reads its own label and glyph off `DexRoute`, so
    /// a drawer shortcut can never disagree with the marquee it will put on the
    /// panel when it lands — the same rule K2 wrote for the glyph table.
    private func quickTile(_ route: DexRoute) -> some View {
        actionTile(title: route.title, symbol: route.marqueeSymbol) { onRoute(route) }
    }

    private func actionTile(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.screenTap()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(DexFont.retro(10))
                    .tracking(0.5)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(lcd.text)
            .frame(maxWidth: .infinity, minHeight: 62)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(lcd.well)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.96))
    }
}
#endif
