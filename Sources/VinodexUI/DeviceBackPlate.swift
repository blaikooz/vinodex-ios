#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The brushed-metal underside of the device, ported from
/// `components/DeviceBackPanel.tsx`.
///
/// Engraved nameplate, corner screws and a serial, on a diagonal metal
/// gradient. The whole plate is tappable to flip back, matching the web app.
///
/// Under a translucent skin the metal is swapped for the same smoke plastic as
/// the front, with the internals showing through — a clear device with a
/// solid steel back would be two different products. The screws and engraving
/// stay: fasteners are real parts, and the maker's mark is etched into the
/// plastic instead of the metal.
///
/// **One plate per skin since 0.7.0 (F1).** The paragraph above made the right
/// argument and then applied it to two skins out of nineteen: everything else
/// turned over to the identical aluminium slab, so a walnut device, a paper
/// device and a black-and-orange device all had the same back. Every colour on
/// this surface now comes from `ChassisSkin.backPlate`, and the surface
/// treatment follows the *front's* — `bodyPatternAsset` and `sketch`, through
/// the same `ChassisPatternLoader` and the same `PaperGrain`, rather than a
/// second table describing the same materials twice. VINODEX CLASSIC's entry is
/// the old literals, so the house device's plate is unchanged.
public struct DeviceBackPlate: View {
    private static let creator = "HORIZON/GODOT"

    /// Turns the device back over (0.6.8, B3). The plate does not own
    /// `isFlipped` — `DeviceChassis` does — so the one control on this surface
    /// reports upward rather than reaching for shared state.
    var onReturn: (() -> Void)?

    private var year: Int { Calendar.current.component(.year, from: Date()) }

    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }

    /// The stamp whose info sheet is open (0.6.4, F2) — tapping a stamp was
    /// the one interaction the plate had beyond the flip until 0.6.7 (C1)
    /// added dragging them.
    @State private var openStamp: BackPlateStamp?

    /// Where the stamps have been dragged to, across launches. See
    /// `StampLayoutStore`.
    @State private var layout = StampLayoutStore.shared
    /// The stamp the press-and-hold has *armed* (0.6.8, B1) — lifted off the
    /// plate and waiting to be moved. Separate from `dragging` because the lift
    /// has to be visible before any movement happens: that is what tells you
    /// the hold worked and that the next thing your finger does will drag.
    @State private var armed: String?
    /// The stamp currently under the finger, and how far it has travelled this
    /// gesture. Live only — the committed position goes to `layout` on release,
    /// so a drag interrupted by the app going away leaves nothing half-written.
    @State private var dragging: String?
    @State private var drag: CGSize = .zero

    public init(onReturn: (() -> Void)? = nil) {
        self.onReturn = onReturn
    }

    public var body: some View {
        // Dismissal is the engraved arrow in the bottom-right corner (0.6.8,
        // B3). It was a swipe anywhere on this surface, which had to go for two
        // reasons: it fought the stamps' own touches, and I1 gives the *LCD* an
        // app-wide back swipe while I2 excludes this plate — so a swipe here
        // would be the same movement meaning two different things depending on
        // which face is up.
        ZStack {
            if skin.isTranslucent {
                InternalsView()
                // The skin's own smoke, not a fixed grey — see `backSmoke`.
                skin.backSmoke
                highlight
            } else {
                metal
                finish
                highlight
            }
            screws
            engraving

            // Factory leavings (v0.5.3): a faded barcode sticker and half a
            // price tag someone tried to peel. Decoration in the plate's own
            // fiction — a device that has been on a shelf, not in a renderer.
            BarcodeSticker()
                .rotationEffect(.degrees(-4))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 30)
                .padding(.bottom, 96)
                .allowsHitTesting(false)
            RippedPriceTag()
                .rotationEffect(.degrees(8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 34)
                .padding(.top, 104)
                .allowsHitTesting(false)

            // The skin's own aged sticker (0.6.4, F3) — the per-skin artifact
            // the 0.6.2 stamp field displaced, back in the plate's fiction:
            // something a previous owner stuck on. One per skin, so swapping
            // shells swaps the sticker with it.
            SkinStickerView(skin: skin)
                .rotationEffect(.degrees(-7))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 36)
                .padding(.top, 190)
                .allowsHitTesting(false)

            // Postage stamps (0.6.4, F2 — the redo of 0.6.2's rubber-ink
            // blocks): each Passport unlock sticks another paper stamp
            // somewhere else on the plate, and tapping one opens its story.
            // Hit-testable on purpose, unlike every other leaving — the
            // stamps are the plate's collection, and the info tap is F2's
            // point.
            stampField

            // The way back, in the corner nearest the thumb (0.6.8, B3).
            // Mounted after the stamps so a stamp dragged onto it cannot bury
            // the only control on the plate.
            returnButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 28)
                .padding(.bottom, 84)
        }
        .overlay {
            if let stamp = openStamp {
                DexAlert(
                    title: stamp.title,
                    message: stamp.info,
                    confirmLabel: "OK",
                    cancelLabel: nil,
                    onConfirm: { openStamp = nil },
                    onCancel: { openStamp = nil }
                )
            }
        }
        .animation(DexMotion.overlay, value: openStamp)
        // A dark edge all the way round. Without it the plate's pale metal ran
        // straight into the chassis behind it and the underside read as a
        // lighting change rather than as a separate part that has been turned
        // over. Inset rather than a full-bleed stroke so the corner radius of
        // the display does not clip it away.
        .overlay {
            RoundedRectangle(cornerRadius: DexMetrics.deviceCorner)
                .strokeBorder(plate.edge, lineWidth: 5)
                .padding(3)
                .allowsHitTesting(false)
        }
        .accessibilityLabel("Device back plate.")
    }

    /// The engraved return arrow (0.6.8, B3) — the plate's only control.
    ///
    /// Large, and engraved rather than moulded: this plate has no buttons on
    /// it, and the one thing 0.6.4's swipe-hint note got right is that a chip
    /// with a border reads as bolted on. So it is cut *into* the metal the same
    /// way the nameplate and the serial are — a recessed round dish, the arrow
    /// carrying the same one-pixel light-below/dark-above pair as every other
    /// engraving here, with a thin bright lip where the light catches the rim.
    ///
    /// It replaces the SWIPE TO RETURN line entirely (B2). That line existed
    /// because the gesture was invisible; the reason it kept being moved is
    /// that no amount of moving fixes an instruction standing in for a control.
    private var returnButton: some View {
        Button {
            Haptics.tap()
            onReturn?()
        } label: {
            Image(systemName: "arrow.right")
                .font(.system(size: DexMetrics.backPlateReturn * 0.44, weight: .heavy))
                .foregroundStyle(plate.ink)
                .engraved()
                .frame(width: DexMetrics.backPlateReturn, height: DexMetrics.backPlateReturn)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [plate.recess.opacity(0.45), plate.inkDeep.opacity(0.30)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
                .overlay(
                    // The dish's wall, dark where the light does not reach…
                    Circle().strokeBorder(plate.inkDeep.opacity(0.55), lineWidth: 2)
                )
                .overlay(
                    // …and the bright lip a point lower, exactly as
                    // `ButtonWell` shades the footer's recesses.
                    Circle()
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                        .offset(y: 1.5)
                )
                .contentShape(Circle())
        }
        .buttonStyle(DexPressStyle(scale: 0.92))
        .accessibilityLabel("Return to the screen")
    }

    /// One paper stamp per earned Passport badge — issued in its own spot, and
    /// **draggable anywhere on the plate from there** (0.6.7, C1), with wherever
    /// you put it surviving a relaunch.
    ///
    /// Recomputed on each flip; `Passport.compute` is cheap and the plate is
    /// rebuilt on flip anyway. What renders in a slot is data-driven
    /// (`StampCatalog`); the table below says only where a stamp *starts*, and
    /// `StampLayoutStore` says how far it has been moved since.
    ///
    /// Laid out by absolute origin in a `GeometryReader` rather than by
    /// alignment and padding, which is what C1 needed: the old form could place
    /// a stamp against an edge but had nowhere to put "and then 40pt right of
    /// that", and there was no plate size in scope to clamp a drag against. The
    /// slot table did not have to change to make the move — an alignment was
    /// always fully implied by the signs of its own offsets, so the alignment
    /// field was redundant and is gone.
    ///
    /// ## Why the drag shook (0.7.0, E2)
    ///
    /// 0.6.8's B1 fixed *when* a drag may start (hold first, so reading a stamp
    /// stops nudging it) and left *how it tracks* broken. The report — "doesn't
    /// follow the finger, shakes a lot" — is one symptom of a positive feedback
    /// loop, and damping it would have been treating the oscillation as if it
    /// were noise. It was not noise, it was arithmetic:
    ///
    /// The gesture was attached to the stamp **above** `.offset(x: at.x,
    /// y: at.y)` in the modifier chain — that is, the offset was applied to the
    /// gesture's own view — and `DragGesture` reports `translation` as (current
    /// location − start location) *in the attached view's coordinate space*. So
    /// each frame ran: finger moves 10pt → translation 10 → `drag` = 10 →
    /// `at` moves the view 10 → the view's local space has moved 10 with it →
    /// the same finger position now measures as translation 0 → `drag` = 0 →
    /// the view snaps home → next event measures 10 again. The stamp buzzes
    /// between two positions roughly a frame apart and averages out somewhere
    /// behind the finger, which is exactly what was described.
    ///
    /// The canonical SwiftUI idiom is the other order — `.offset(…).gesture(…)`,
    /// with the offset *inside* the gesture's view so the gesture measures in
    /// the stable parent space — and that is what the chain does now. Belt and
    /// braces, the drag also names the plate's coordinate space explicitly
    /// (`plateSpace`), which additionally cancels the rotation and lift-scale
    /// distortion described at the gesture itself. Neither change damps
    /// anything: the translation is applied 1:1 and the stamp is under the
    /// finger.
    ///
    /// ## Why no touch ever reached that gesture (0.7.2, A2)
    ///
    /// The arithmetic above is right and it never ran once. 0.7.1's D3 shortened
    /// the hold to 0.25s on the theory that the gesture was firing and failing
    /// to *enter*; 0.7.2's A2 came back saying stamps are not draggable at all.
    /// They were not, and neither were they tappable — the same report would
    /// have been "nothing on this plate does anything" if anyone had tried the
    /// stamp's own story, because both gestures hung off a hit region that was
    /// nowhere near the stamp.
    ///
    /// When E2 lifted `.frame` and `.offset` up the chain it left
    /// `.contentShape(Rectangle())` sitting *outside* the offset. `.offset` is a
    /// render-time translation: it does not change layout, so in this
    /// `ZStack(alignment: .topLeading)` every stamp's layout frame is the same
    /// 88×104 box at the plate's top-left corner and only the drawing moves.
    /// Anything attached outside the offset therefore works in the *un-*offset
    /// space — and `.contentShape` does not merely describe a hit region, it
    /// **replaces** the subtree's. So all six stamps shared one touch target,
    /// stacked in the corner under the top-left screw, while every stamp on
    /// screen was inert. Pressing a stamp sent the touch nowhere; no recogniser
    /// was reached, which is why changing its duration could not have helped.
    ///
    /// Two rules now, and they are in tension only if you forget which problem
    /// each solves:
    ///
    /// 1. **`.contentShape` goes immediately after `.frame`, inside the offset**,
    ///    so the hit region is the stamp's own box and the offset carries it
    ///    along with the pixels. This is what E2's reorder broke.
    /// 2. **The offset stays inside the gesture** and the drag keeps measuring in
    ///    `plateSpace`, so E2's feedback loop stays fixed. Rule 1 does not
    ///    reintroduce it: the shape moves with the stamp, the *measurement* does
    ///    not come from the stamp.
    ///
    /// The gesture is also `highPriorityGesture` now rather than `gesture`.
    /// `.gesture(_:)` attaches with *lower* precedence than gestures already on
    /// the view, and `.onTapGesture` is already on the view one line above, so
    /// the hold-then-drag was the losing side of an exclusive pair — and
    /// SwiftUI's `TapGesture` has no maximum duration, so a deliberate press and
    /// release is a tap and would have won even after the hit region was fixed.
    /// The sequence's own comment below already assumed it got first refusal
    /// ("a plain tap fails the press … and falls through to `onTapGesture`");
    /// this is the modifier that actually grants it. `MarqueeDrawer`'s hold-to-pin
    /// had reached the same conclusion from the other direction.
    private var stampField: some View {
        let passport = Passport.compute(
            tried: BookmarkStore.shared.ids(on: .tried),
            in: WineDatabase.shared,
            bestStreak: StreakStore.shared.best,
            highestTier: QuizProgress.shared.highestUnlocked
        )
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Gives the stack the plate's own bounds to lay origins out
                // against — the positioned children contribute none.
                Color.clear

                ForEach(StampCatalog.unlocked(from: passport)) { stamp in
                    let slot = Self.stampSlots[stamp.id] ?? StampSlot(dx: 0, dy: 0, rotation: 0)
                    let home = Self.origin(of: slot, in: geo.size)
                    let live = dragging == stamp.id ? drag : .zero
                    let moved = layout.offset(for: stamp.id)
                    let at = Self.clamp(
                        CGPoint(
                            x: home.x + CGFloat(moved.dx) + live.width,
                            y: home.y + CGFloat(moved.dy) + live.height
                        ),
                        in: geo.size
                    )

                    let lifted = armed == stamp.id || dragging == stamp.id

                    // **Modifier order is the whole fix** (0.7.0, E2). See the
                    // note on `stampField` above; the two rules are that every
                    // transform the gesture drives sits *below* the gesture, and
                    // that the gesture measures in the plate's space rather than
                    // in the stamp's own.
                    BackPlateStampView(stamp: stamp)
                        .rotationEffect(.degrees(slot.rotation))
                        // **The lift-off** (0.6.8, B1). Bigger and further off
                        // the plate than 0.6.7's 1.08, and — crucially — it
                        // happens the instant the hold completes, *before*
                        // anything has moved. It is the whole feedback for a
                        // gesture that is otherwise invisible: the stamp
                        // peeling up is what says "this is yours to move now".
                        .scaleEffect(lifted ? 1.16 : 1)
                        .shadow(
                            color: .black.opacity(lifted ? 0.45 : 0),
                            radius: 12,
                            y: 8
                        )
                        .animation(DexMotion.press, value: lifted)
                        // Frame and position first — everything below this line
                        // is attached to a view already sitting where it belongs
                        // in the plate's coordinate space, which is what stops
                        // the drag from chasing its own tail.
                        .frame(width: Self.stampSize.width, height: Self.stampSize.height)
                        // **Inside the offset, deliberately** (0.7.2, A2). This
                        // one line is the whole non-functional-stamps bug: out
                        // here on the far side of `.offset` it pinned every
                        // stamp's touch target to the un-offset layout frame in
                        // the plate's top-left corner. See `stampField`'s note.
                        .contentShape(Rectangle())
                        .offset(x: at.x, y: at.y)
                        .onTapGesture {
                            // A tap on a lifted stamp puts it back down rather
                            // than opening its story: someone who armed a drag
                            // and changed their mind has no other way out, and
                            // a modal appearing instead would read as the hold
                            // having failed.
                            Haptics.select()
                            if lifted {
                                armed = nil
                            } else {
                                openStamp = stamp
                            }
                        }
                        // **Hold, then drag** (0.6.8, B1).
                        //
                        // 0.6.7 ran a bare `DragGesture(minimumDistance: 8)`
                        // alongside the tap, which is why the plate felt buggy:
                        // eight points is inside the slop of an ordinary touch,
                        // so *reading* a stamp routinely nudged it, and the
                        // recogniser also claimed the horizontal movement the
                        // plate's own swipe-to-return needed (that swipe is gone
                        // in this batch — see `body` — but the arming is the
                        // fix either way, because I1's LCD swipe has the same
                        // shape).
                        //
                        // `sequenced` rather than two independent gestures: it
                        // is one recogniser that cannot start dragging until the
                        // press has completed, so a plain tap fails the press,
                        // never reaches the drag, and falls through to
                        // `onTapGesture` above. Two gestures would race.
                        //
                        // **Named coordinate space** (0.7.0, E2), and the second
                        // half of the fix. A bare `DragGesture` reports its
                        // translation in `.local` — the *attached view's* space —
                        // which here is a stamp carrying a `rotationEffect` of up
                        // to 15° and, while lifted, a `scaleEffect` of 1.16.
                        // Both transforms sit below the gesture, so a local
                        // translation came back rotated and 16% long: dragging
                        // right moved a tilted stamp right-and-up, and moved it
                        // further than the finger went. Measuring in the plate's
                        // own space is transform-free by construction.
                        //
                        // **Shortened to 0.25s (0.7.1, D3.)** The 0.7.0 fix
                        // above is arithmetically right — the stamp tracks the
                        // finger exactly — and D3 still arrived saying dragging
                        // does not work. The remaining failure is not the
                        // tracking, it is the *entry*: `LongPressGesture` fails
                        // if the finger travels more than ~10pt before the
                        // duration elapses, so anyone who presses and starts
                        // moving straight away — which is what "drag this" means
                        // to almost everybody — gets no gesture at all and
                        // concludes it is broken. 0.35s is a long time to hold
                        // perfectly still. 0.25 is about the shortest that still
                        // cannot fire on a tap, and it is paired with the
                        // engraved hint on the plate (see `nameplate`) so the
                        // hold is something the device tells you about rather
                        // than something you have to guess.
                        //
                        // **`highPriorityGesture`, not `gesture` (0.7.2, A2).**
                        // The paragraph above this one describes a tap falling
                        // through to `onTapGesture` *after* failing the press,
                        // which is the behaviour of a gesture that gets first
                        // refusal — and `.gesture(_:)` is documented as attaching
                        // with lower precedence than gestures already declared on
                        // the view. `onTapGesture` is declared on the view, four
                        // lines up. So the sequence was the loser of that
                        // exclusive pair, and since `TapGesture` has no maximum
                        // duration, holding still and releasing simply read as a
                        // slow tap.
                        .highPriorityGesture(
                            LongPressGesture(minimumDuration: 0.25)
                                .onEnded { _ in
                                    armed = stamp.id
                                    Haptics.select()
                                }
                                .sequenced(
                                    before: DragGesture(
                                        minimumDistance: 0,
                                        coordinateSpace: .named(Self.plateSpace)
                                    )
                                )
                                .onChanged { value in
                                    guard case .second(true, let move?) = value else { return }
                                    dragging = stamp.id
                                    drag = move.translation
                                }
                                .onEnded { value in
                                    defer {
                                        armed = nil
                                        dragging = nil
                                        drag = .zero
                                    }
                                    // The press completed but the finger lifted
                                    // without moving: nothing to commit, and the
                                    // stamp settles back where it was.
                                    //
                                    // **Falls back to the last live translation**
                                    // (0.7.1, D3). A sequenced gesture that is
                                    // interrupted rather than released — the
                                    // classic case being an incoming call or the
                                    // device being turned over mid-drag — can
                                    // end without a `.second` payload, and the
                                    // 0.7.0 code silently discarded the move. A
                                    // position the user visibly dragged a stamp
                                    // to and then lost is the exact complaint
                                    // D3 makes, so the last translation this
                                    // drag reported is committed instead.
                                    let translation: CGSize
                                    if case .second(true, let move?) = value {
                                        translation = move.translation
                                    } else if dragging == stamp.id, drag != .zero {
                                        translation = drag
                                    } else {
                                        return
                                    }
                                    let settled = Self.clamp(
                                        CGPoint(
                                            x: home.x + CGFloat(moved.dx) + translation.width,
                                            y: home.y + CGFloat(moved.dy) + translation.height
                                        ),
                                        in: geo.size
                                    )
                                    // Stored relative to the issued spot, not
                                    // absolutely — see `StampOffset`.
                                    layout.move(
                                        stamp.id,
                                        to: StampOffset(
                                            dx: Double(settled.x - home.x),
                                            dy: Double(settled.y - home.y)
                                        )
                                    )
                                    Haptics.select()
                                }
                        )
                        .accessibilityLabel("\(stamp.title) stamp. Opens its story.")
                        .accessibilityHint("Press and hold, then drag to move it on the plate.")
                        // VoiceOver cannot perform a hold-then-drag at all, so
                        // the two things the gesture does are also offered as
                        // named actions (0.7.1, D3): put it back where it was
                        // issued, which is the only destination a screen reader
                        // user could name unambiguously.
                        .accessibilityAction(named: "Reset position") {
                            layout.move(stamp.id, to: .zero)
                            Haptics.select()
                        }
                }
            }
            // The space every drag is measured in — the plate's, not a stamp's.
            // Declared on the stack rather than on `GeometryReader` so it is the
            // same box the slot origins and `clamp` already work in.
            .coordinateSpace(name: Self.plateSpace)
        }
    }

    /// Name of the plate's coordinate space (0.7.0, E2).
    ///
    /// A constant rather than a literal at both ends: a typo in either would not
    /// fail to compile, it would silently fall back to a global measurement and
    /// reintroduce a subtler version of the bug this fixes.
    private static let plateSpace = "backPlateField"

    /// `BackPlateStampView`'s own frame, which the slot arithmetic has to know
    /// to place an origin and to clamp a drag. Matches its defaults.
    private static let stampSize = CGSize(width: 88, height: 104)

    private struct StampSlot {
        /// Positive = from the leading edge, negative = from the trailing.
        let dx: CGFloat
        /// Positive = from the top edge, negative = from the bottom.
        let dy: CGFloat
        let rotation: Double
    }

    /// A slot's top-leading origin on a plate of this size. Negative offsets
    /// measure back from the far edge, which is exactly what the trailing and
    /// bottom paddings used to do.
    private static func origin(of slot: StampSlot, in size: CGSize) -> CGPoint {
        CGPoint(
            x: slot.dx >= 0 ? slot.dx : size.width + slot.dx - stampSize.width,
            y: slot.dy >= 0 ? slot.dy : size.height + slot.dy - stampSize.height
        )
    }

    /// Keeps a dragged stamp on the plate. Clamped on the *unrotated* frame:
    /// the stamps sit at up to 15°, so a corner does poke a few points past the
    /// edge — which is what a stamp stuck near the edge of a real thing looks
    /// like, and much better than reserving a rotation-proof margin the user
    /// would feel as an invisible wall well inside the plate.
    private static func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), max(size.width - stampSize.width, 0)),
            y: min(max(point.y, 0), max(size.height - stampSize.height, 0))
        )
    }

    /// Where each stamp is *issued* — scattered clear of the engraving block,
    /// the screws, the barcode (bottom-leading), the price tag (top-trailing)
    /// and the skin sticker (leading, above the barcode). Colours moved into
    /// `StampCatalog` with the rest of the stamp's identity (0.6.4, F2); since
    /// 0.6.7 (C1) this is a starting position rather than a fixed home.
    private static let stampSlots: [String: StampSlot] = [
        "firstSip": StampSlot(dx: 34, dy: 96, rotation: -12),
        "tenBottles": StampSlot(dx: -38, dy: 208, rotation: 8),
        "allNoble": StampSlot(dx: -34, dy: -168, rotation: -7),
        "regionComplete": StampSlot(dx: 46, dy: -230, rotation: 10),
        "streakWeek": StampSlot(dx: -128, dy: -84, rotation: -15),
        "sommelier": StampSlot(dx: 132, dy: 150, rotation: 5),
    ]

    /// This skin's plate material (0.7.0, F1) — see `ChassisSkin.backPlate`.
    /// Resolved once and read by everything below, so the plate is one material
    /// rather than a dozen call sites each deciding.
    private var plate: BackPlateStyle { skin.backPlate }

    /// The plate's base, in the skin's own two mouldings rather than in one
    /// hardcoded aluminium (0.7.0, F1). VINODEX CLASSIC's stops are the
    /// original four, so the house device is unchanged.
    private var metal: some View {
        LinearGradient(
            colors: plate.stops,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Whatever is done to the base's surface (0.7.0, F1).
    ///
    /// The front shell already had this exact idea — `ChassisShell` lays a tiled
    /// pattern or a paper grain over `skin.body` — and the back had a brushed
    /// finish nailed to it. A walnut device with a machined back was two
    /// devices, which is the argument the plate's own header makes for the clear
    /// skins and then applied to nobody else.
    @ViewBuilder
    private var finish: some View {
        switch plate.finish {
        case .brushed:
            striations
        case .moulded:
            // Plastic has no grain. Deliberately nothing, not a faint
            // something — a token texture over every skin is the flat-slab
            // problem again with extra steps.
            EmptyView()
        case .pattern(let asset):
            if let image = ChassisPatternLoader.shared.image(asset) {
                Image(uiImage: image)
                    .resizable(resizingMode: .tile)
                    .interpolation(.none)
                    .allowsHitTesting(false)
            }
        case .paper(let grain):
            PaperGrain(color: grain)
                .allowsHitTesting(false)
        }
    }

    /// Fine vertical lines standing in for a brushed finish. The web version
    /// uses a repeating-linear-gradient; a striped Canvas is the cheap
    /// equivalent and stays crisp at any size.
    private var striations: some View {
        Canvas { context, size in
            let step: CGFloat = 2
            var x: CGFloat = 0
            while x < size.width {
                context.fill(
                    Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                    with: .color(.white.opacity(0.16))
                )
                context.fill(
                    Path(CGRect(x: x + 1, y: 0, width: 1, height: size.height)),
                    with: .color(.black.opacity(0.16))
                )
                x += step
            }
        }
        .blendMode(.overlay)
        .opacity(0.45)
        .allowsHitTesting(false)
    }

    private var highlight: some View {
        RadialGradient(
            colors: [.white.opacity(0.35), .clear],
            center: UnitPoint(x: 0.3, y: 0.2),
            startRadius: 0,
            endRadius: 420
        )
        .allowsHitTesting(false)
    }

    /// Screws pulled well in from the corners.
    ///
    /// At 16pt they sat inside the display's 55pt corner arc, so each one was
    /// cut into on the diagonal and the top pair fouled the dark border. This is
    /// the same arithmetic `cornerGuardH` does for the chassis controls: a
    /// fastener has to sit on flat plate, not on the curve.
    private var screws: some View {
        VStack {
            HStack { screw; Spacer(); screw }
            Spacer()
            HStack { screw; Spacer(); screw }
        }
        .padding(38)
        .allowsHitTesting(false)
    }

    private var screw: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: plate.screw,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 26, height: 26)
            .overlay(Circle().strokeBorder(plate.screwRim, lineWidth: 1))
            .overlay(
                // The slot.
                Capsule()
                    .fill(plate.screwRim.opacity(0.7))
                    .frame(width: 18, height: 3)
                    .rotationEffect(.degrees(45))
            )
            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
    }

    /// The engraved copy, scaled up throughout.
    ///
    /// This is a full-screen surface carrying six short lines, and it was set at
    /// list-row sizes — the nameplate that is meant to be the object's makers
    /// mark was smaller than a section header on the LCD. Every size here is up
    /// roughly a third, with the nameplate up more than that, since it is the
    /// one thing the plate exists to show.
    private var engraving: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            // Recessed nameplate.
            VStack(spacing: 12) {
                Text("VINODEX")
                    .font(DexFont.retro(36))
                    .tracking(8)
                    .foregroundStyle(plate.inkDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                // Read from `AppVersion` rather than a literal here, which had
                // been stuck at v0.3.5 for several releases.
                Text(AppVersion.display)
                    .font(DexFont.mono(28))
                    .tracking(7)
                    .foregroundStyle(plate.ink)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [plate.recess.opacity(0.4), plate.inkDeep.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(plate.ink.opacity(0.6), lineWidth: 2)
            )
            .engraved()

            // The serial block keeps its recessed panel — the nameplate's
            // treatment, one register lighter. The "CREATED BY" line is gone
            // (v0.5.3): the maker's mark lives in the © line, and the plate
            // carries factory stickers now rather than more engraving.
            VStack(spacing: 10) {
                Text("SN: VDX-\(String(year))-001")
                Text("© \(String(year)) \(Self.creator)")
                Text("ALL RIGHTS RESERVED")
            }
            .font(DexFont.mono(22))
            .tracking(4)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .foregroundStyle(plate.ink)
            .engraved()
            .padding(.horizontal, 26)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [plate.recess.opacity(0.22), plate.inkDeep.opacity(0.22)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(plate.ink.opacity(0.4), lineWidth: 2)
            )
            .engraved()

            // `swipeHint` retired in 0.6.8 (B2). It read SWIPE TO RETURN and it
            // had moved twice looking for a place where people would find it —
            // the bottom edge, then a dark chip above the nameplate, then under
            // this block. All three were the same mistake: a line of text
            // standing in for a control. The gesture it described is gone and
            // the control it should have been is in the bottom-right corner.
            //
            // **The stamp hint is not that mistake** (0.7.1, D3), and the
            // difference is worth stating since this is the same spot. That
            // line stood in for a control — there was no other way to go back.
            // This one describes a *secondary* gesture on an object that is
            // already fully usable without it: every stamp taps to open its
            // story, and the hold is the extra. Engraved into the moulding
            // alongside the other plant markings, at the smallest size on the
            // plate, because it is documentation of the object rather than an
            // instruction to the user — and D3's report was, at root, that
            // nothing anywhere said the hold existed.
            Text("HOLD A STAMP TO REPOSITION")
                // `retro(10)`: `TypeScale.nominalFloor` clamps anything below
                // it *before* the scale factor, so a smaller number here would
                // describe a size that never renders — the trap `StampFrame`
                // documents at length a few files over.
                .font(DexFont.retro(10))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(plate.ink.opacity(0.75))
                .engraved()
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .allowsHitTesting(false)
    }

}

private extension View {
    /// The two-shadow trick the web panel uses for engraved lettering: a light
    /// edge below, a dark one above.
    func engraved() -> some View {
        self
            .shadow(color: .white.opacity(0.55), radius: 0, x: 0, y: 1)
            .shadow(color: .black.opacity(0.45), radius: 0, x: 0, y: -1)
    }
}

/// A sun-faded barcode sticker. The bars are a fixed pattern, not data — a
/// deterministic sequence so the plate looks identical on every launch.
private struct BarcodeSticker: View {
    /// Bar widths, in points at the sticker's own scale. Hand-picked to read
    /// as EAN-ish without pretending to encode anything.
    private static let bars: [CGFloat] = [
        2, 1, 3, 1, 1, 2, 1, 4, 1, 2, 2, 1, 1, 3, 2, 1, 2, 1, 1, 4, 1, 2, 1, 3, 1, 1, 2, 2,
    ]

    var body: some View {
        VStack(spacing: 3) {
            Canvas { context, size in
                var x: CGFloat = 0
                let unit = size.width / Self.bars.reduce(0, +) / 1.9
                for (index, width) in Self.bars.enumerated() {
                    let w = width * unit
                    if index.isMultiple(of: 2) {
                        context.fill(
                            Path(CGRect(x: x, y: 0, width: w, height: size.height)),
                            with: .color(.black.opacity(0.55))
                        )
                    }
                    x += w * 1.9
                }
            }
            .frame(width: 108, height: 30)

            Text("4 71332 90815")
                .font(DexFont.mono(13))
                .tracking(2)
                .foregroundStyle(.black.opacity(0.55))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color(dexHex: "#E9E6DA")))
        .overlay(
            // A worn top edge, as if the lamination has yellowed.
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [Color(dexHex: "#C9C2A8").opacity(0.5), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        )
        // The fade is baked into the inks above rather than applied to the
        // whole view (v0.5.9, A3): a view-level opacity let the internals show
        // *through* the sticker under the translucent skins, and a sticker is
        // an opaque thing stuck on top of whatever it is stuck to. The bar and
        // text inks composite against the opaque label stock, so the sun-faded
        // look survives while the sticker itself stays solid.
        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
    }
}

// PR #10 raised the old PassportStamp's mono(9) to mono(10) for H11; the
// struct itself was replaced wholesale by the postage stamps (0.6.4, F2), so
// the fix has nothing left to land on — the deletion stands.
/// The pink price tag someone tried to peel — the left half survives, the
/// right edge is torn into a jagged profile.
private struct RippedPriceTag: View {
    /// The tear, as fractions of the tag's bounds: straight edges everywhere
    /// except the right side, which staggers inward and back out.
    private struct TornEdge: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX * 0.92, y: rect.minY))
            // The rip.
            let steps: [(CGFloat, CGFloat)] = [
                (0.84, 0.18), (0.95, 0.32), (0.78, 0.45),
                (0.90, 0.60), (0.74, 0.74), (0.86, 0.88), (0.70, 1.0),
            ]
            for (fx, fy) in steps {
                p.addLine(to: CGPoint(x: rect.maxX * fx, y: rect.minY + rect.height * fy))
            }
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
            return p
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("SALE")
                .font(DexFont.retro(10))
                .tracking(2)
                .foregroundStyle(Color(dexHex: "#8F2D56"))
            Text("$4.99")
                .font(DexFont.mono(24))
                .foregroundStyle(Color(dexHex: "#6B1D40"))
        }
        .padding(.leading, 10)
        .padding(.trailing, 26)
        .padding(.vertical, 8)
        .background(TornEdge().fill(Color(dexHex: "#F5A8C4")))
        .overlay(
            // The tear's raw paper edge — lighter, like exposed stock.
            TornEdge().stroke(Color(dexHex: "#FBD3E2"), lineWidth: 1.5)
        )
        .opacity(0.9)
        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
    }
}
#endif
