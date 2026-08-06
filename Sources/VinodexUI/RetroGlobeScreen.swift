#if canImport(SwiftUI) && canImport(UIKit)
import CoreImage
import SwiftUI
import SceneKit
import UIKit
import VinodexCore

/// The drag-to-spin globe, ported from `RetroGlobeScreen.tsx`.
///
/// three.js becomes SceneKit: a textured sphere inside a wireframe shell, lit by
/// an ambient plus two directionals, spinning slowly with drag inertia. Continent
/// markers are SwiftUI buttons positioned each frame by projecting their
/// lat/long through the renderer — `SCNSceneRenderer.projectPoint` replacing
/// three.js's `Vector3.project`.
public struct RetroGlobeScreen: View {
    let onSelectContinent: (Continent) -> Void
    let onWorldSearch: () -> Void
    /// Whether to offer world search.
    ///
    /// On its own route it always should. Embedded in the scanner it must not:
    /// world search is a route push, and pushing out of the scanner would
    /// discard the answers collected so far — so the control is removed rather
    /// than left present and inert.
    var showsSearch: Bool

    @State private var model = GlobeModel()
    /// Whether the flat continent list is showing instead of the globe.
    ///
    /// The globe is a *drag-and-tap-a-moving-target* control, which is not a
    /// control at all for someone using VoiceOver, Switch Control or a shaky
    /// hand — and the rear half of the sphere cannot even be reached without a
    /// drag. This list is the equivalent path, present on both mounts (the
    /// scanner's globe step turns `showsSearch` off, so before this it had no
    /// non-globe way to name a continent at all). (AUDIT M20)
    @State private var showsList = false
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }
    /// The skin's tint is the DARK-mode fallback (0.6.2, F1); every other
    /// screen mode brings its own globe colour (0.6.4, F1) — see
    /// `LcdMode.globeTint` for why the mode outranks the skin here.
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }
    /// Perpetual rotation is the one thing on this screen that is motion for
    /// its own sake. (AUDIT M18)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    /// Mode first, skin as the DARK fallback — the resolution 0.6.4 F1 exists
    /// to establish.
    private var globeTint: Color { lcd.globeTint ?? skin.globeTint }

    /// Autospin off. Two reasons, one rule: Reduce Motion asks for no
    /// unprompted movement, and VoiceOver cannot land on a target that is
    /// drifting under the cursor — "pause at rest" from AUDIT M20. A drag still
    /// spins the globe in both cases; what stops is the movement nobody asked
    /// for.
    private var freezesGlobe: Bool { reduceMotion || voiceOver }

    public init(
        onSelectContinent: @escaping (Continent) -> Void,
        onWorldSearch: @escaping () -> Void,
        showsSearch: Bool = true
    ) {
        self.onSelectContinent = onSelectContinent
        self.onWorldSearch = onWorldSearch
        self.showsSearch = showsSearch
    }

    public var body: some View {
        ZStack {
            // The same ground and grid every other screen uses, rather than a
            // black plate under a 24pt green grid of its own. The globe screen
            // was the only place the backdrop changed pitch, which read as a
            // different app — and it ignored the LCD mode setting entirely.
            DexScreenBackground()

            VStack(spacing: 12) {
                // Looks like the other screens' search bars, but it opens the
                // search screen rather than filtering in place — results laid
                // over a spinning sphere read as a rendering glitch.
                if showsSearch {
                    searchBar
                }

                ZStack {
                    GlobeSceneView(
                        model: model,
                        isLight: lcd.isLight,
                        tint: UIColor(globeTint),
                        invertsTexture: lcd.invertsGlobeTexture
                    )
                        .gesture(dragGesture)
                        // The scene's lighting, emission and tint are
                        // baked in `buildScene`, which only runs in
                        // `makeUIView` — so a mode or skin switch has to
                        // rebuild the view to take effect. Keyed on both, it
                        // costs one rebuild per toggle rather than one per
                        // render.
                        .id("\(lcd.rawValue)|\(skinRaw)")

                    markerLayer
                }
                // Hidden from assistive tech *before* the overlay is added, so
                // the list that replaces it is not hidden with it: the globe
                // and its markers are one control, and while the list is up it
                // is the list that answers for them.
                .accessibilityHidden(showsList)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if showsList {
                        continentList
                            // Full-bleed and hit-testable, so the 12pt gutters
                            // beside the card absorb touches instead of passing
                            // them to the globe underneath — a marker plate can
                            // reach the viewport edge, and tapping one while the
                            // list is up would open a continent nobody chose.
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                }

                listToggle

                // Two lines, because the globe has two affordances and the
                // second one is the one that actually gets you somewhere. A
                // marker looks like a label, so nothing on screen said it was
                // tappable — the instruction only mentioned spinning.
                //
                // Swapped rather than removed while the list is up: the pair is
                // the same two lines tall either way, so the toggle does not
                // move under the finger that pressed it.
                VStack(spacing: 5) {
                    Text(showsList ? "PICK A CONTINENT" : "DRAG TO SPIN GLOBE")
                        .font(DexFont.retro(11))
                        .tracking(3)
                        .foregroundStyle(lcd.accent)
                    Text(showsList ? "OR GO BACK TO THE GLOBE" : "TAP TO SELECT CONTINENT")
                        .font(DexFont.retro(10))
                        .tracking(2)
                        .foregroundStyle(lcd.subtext)
                }
                .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
        }
        .onAppear {
            model.autoSpins = !freezesGlobe
            // Opened straight onto the list under VoiceOver rather than onto a
            // sphere with nothing on it to focus. Not forced — the toggle still
            // works both ways, because someone may well want to explore the
            // globe itself.
            if voiceOver { showsList = true }
            // `BackSwipeGate.suspend()` used to be called here (0.6.8, I1):
            // this is the one screen that owns horizontal dragging, so it was
            // the one screen that had to stand the LCD's app-wide back swipe
            // down. 0.6.9's A1 removes that swipe, so there is nothing left to
            // negotiate with and the drag below is simply this screen's own.
        }
        .onChange(of: freezesGlobe) { _, frozen in model.autoSpins = !frozen }
        .onChange(of: voiceOver) { _, on in if on { showsList = true } }
        .onDisappear {
            model.stop()
        }
    }

    // MARK: Continent list (the non-globe path)

    /// Switches between the sphere and the list. Sized to the 44pt minimum
    /// target, and always present — the list is not an accessibility mode that
    /// has to be discovered through Settings, it is the second half of an
    /// ordinary control.
    private var listToggle: some View {
        Button {
            Haptics.screenTap()
            showsList.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: showsList ? "globe.americas.fill" : "list.bullet")
                    .font(.system(size: 13, weight: .bold))
                Text(showsList ? "BACK TO GLOBE" : "CONTINENT LIST")
                    .font(DexFont.retro(11))
                    .tracking(2)
            }
            .foregroundStyle(lcd.accent)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(lcd.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(lcd.accent, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(DexPressStyle(scale: 0.95))
    }

    /// Every continent, in one flat list, whatever the globe happens to be
    /// showing. Opaque rather than translucent: a list read over a rotating
    /// sphere is exactly the legibility problem the list exists to avoid.
    private var continentList: some View {
        VStack(spacing: 0) {
            Text("ALL CONTINENTS")
                .font(DexFont.retro(11))
                .tracking(3)
                .foregroundStyle(lcd.subtext)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 8) {
                    // From the markers rather than `Continent.allCases`, so the
                    // row's swatch is the same colour as the marker it stands
                    // in for, by construction rather than by two tables
                    // agreeing (v0.5.6's rule, and it keeps this screen down to
                    // its one existing `WineDatabase.shared` read — AUDIT M27).
                    ForEach(model.markers) { marker in
                        continentRow(marker)
                    }
                }
            }
        }
        .padding(12)
        .background(lcd.panelGround)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(lcd.surfaceEdge, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
    }

    private func continentRow(_ marker: GlobeModel.Marker) -> some View {
        Button {
            Haptics.select()
            onSelectContinent(marker.continent)
        } label: {
            HStack(spacing: 10) {
                // The continent's own hero icon (0.6.8, C1) — the drawn globe
                // every other surface in the app already shows it with (the
                // world-search row, the continent screen's hero, a saved-entry
                // tile). This list was the one place a continent was a bare
                // colour swatch, which made it the one place you could not
                // recognise one at a glance.
                //
                // No new art: `EntryIconWell` resolves the generated glyph
                // through `EntryVisual.continentVisual`, well colour and all.
                // The 10×26 swatch stays as the fallback for a continent with
                // no entry — the same guard `marker.color` already carries.
                if let entry = marker.entry {
                    EntryIconWell(entry: .continent(entry), size: 44, cornerRadius: 8)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(marker.color)
                        .frame(width: 10, height: 26)
                }

                Text(marker.continent.displayName)
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(lcd.subtext)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(lcd.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(marker.color.opacity(0.8), lineWidth: 1)
            )
        }
        .buttonStyle(DexPressStyle())
        .accessibilityLabel(marker.continent.displayName)
    }

    // MARK: Markers

    private var markerLayer: some View {
        GeometryReader { geo in
            ForEach(model.markers) { marker in
                Button {
                    Haptics.screenTap()
                    onSelectContinent(marker.continent)
                } label: {
                    // Text-only on purpose. 0.5.9 briefly put the drawn globe
                    // icons on these plates; a globe pinned onto the globe
                    // read as clutter and came back off in 0.6.x — the icon
                    // set lives on the scanner's choice tiles instead.
                    // Bigger again (0.6.5, item 10, was 15): the markers are
                    // the globe's only doorway and earn billboard size.
                    Text(marker.continent.markerLabel)
                        .font(DexFont.retro(18))
                        .multilineTextAlignment(.center)
                        // Always light, in both LCD modes. A marker does not sit
                        // on the screen background — it sits on the *globe*,
                        // whose hue now follows the mode (0.6.6, A) but whose
                        // ground is a dark sphere in every one of them. So
                        // following `lcd.text` turned the label near-black over
                        // that sphere and made it unreadable in light mode; the
                        // plate below carries the contrast instead.
                        .foregroundStyle(.white)
                        .fixedSize()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        // The plate carries the contrast instead: a black scrim
                        // under the continent tint, deepened in light mode where
                        // the surrounding page is pale and the marker would
                        // otherwise read as washed out.
                        .background(.black.opacity(lcd.isLight ? 0.5 : 0.35))
                        .background(marker.color.opacity(lcd.isLight ? 0.45 : 0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(marker.color.opacity(0.9), lineWidth: 3)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: marker.color.opacity(0.55), radius: 8)
                }
                .buttonStyle(DexPressStyle(scale: 0.9))
                .position(x: marker.position.x, y: marker.position.y)
                .opacity(marker.visible ? 1 : 0)
                .allowsHitTesting(marker.visible)
                // A marker on the far side of the sphere is invisible and
                // untappable, but was still in the accessibility tree — so
                // VoiceOver offered six continents of which only the front two
                // or three did anything. The label drops the marker plate's
                // line break. (AUDIT M20)
                .accessibilityHidden(!marker.visible)
                .accessibilityLabel(marker.continent.displayName)
                .animation(.easeOut(duration: 0.3), value: marker.visible)
            }
            .onAppear { model.viewportSize = geo.size }
            .onChange(of: geo.size) { _, size in model.viewportSize = size }
        }
    }

    /// The exact control the list screens use — same shell, same glyph tint,
    /// same placeholder face — but it opens the world-search screen instead of
    /// accepting typing in place. It used to be a hand-rolled near-copy with a
    /// different glyph colour, different padding and a trailing chevron nothing
    /// else had, which made it read as a different kind of control.
    private var searchBar: some View {
        // The ellipsis is U+2026, matching the live field this opens (0.8.0, J).
        // Three periods and an ellipsis are visibly different widths in the mono
        // face, and the whole point of `DexSearchBarButton` is that it is
        // indistinguishable from the field until you tap it.
        DexSearchBarButton(placeholder: "SEARCH WORLD…", action: onWorldSearch)
            .padding(.horizontal, 12)
    }

    // MARK: Drag

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            // `value.time` is threaded through so the throw that carries the
            // globe after the finger lifts is measured in points per *second*
            // rather than points per touch-event — those are not the same
            // number on a 120Hz panel. (AUDIT M11)
            .onChanged { value in model.drag(translation: value.translation, at: value.time) }
            .onEnded { _ in model.endDrag() }
    }
}

// MARK: - Scene

/// Hosts the `SCNView`. SceneKit is UIKit-only, so this is the bridge.
struct GlobeSceneView: UIViewRepresentable {
    let model: GlobeModel
    var isLight: Bool
    var tint: UIColor
    /// LIGHT mode's inverted-colour globe (0.6.4, F1).
    var invertsTexture: Bool = false

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling2X
        view.isUserInteractionEnabled = false   // gestures are handled in SwiftUI
        view.scene = model.buildScene(isLight: isLight, tint: tint, invertsTexture: invertsTexture)
        view.pointOfView = model.cameraNode
        model.attach(to: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}

    static func dismantleUIView(_ view: SCNView, coordinator: ()) {
        view.scene = nil
    }
}

// MARK: - Model

/// Drives rotation, inertia and marker projection.
///
/// A `CADisplayLink` on the main actor rather than SceneKit's render delegate:
/// marker positions feed SwiftUI state, and hopping from the render thread every
/// frame would be both awkward under Swift 6 concurrency and needless for a
/// scene this small.
@MainActor
@Observable
final class GlobeModel {
    struct Marker: Identifiable {
        let continent: Continent
        var position: CGPoint
        var visible: Bool
        var color: Color
        /// The continent's catalog entry, carried so the list row can draw its
        /// hero icon (0.6.8, C1) without a second `WineDatabase.shared` read on
        /// a screen deliberately held to one (AUDIT M27). It is the same lookup
        /// `color` already makes — see `markers`.
        var entry: ContinentEntry?
        var id: String { continent.rawValue }
    }

    // Constants ported directly from RetroGlobeScreen.tsx.
    //
    // The web app's were all *per frame*, on the unstated assumption that a
    // frame is 1/60s. That assumption is false on every ProMotion device the
    // app runs on: the display link fired at 120Hz, so the globe span twice as
    // fast, inertia decayed twice as quickly, and markers re-projected twice as
    // often — for the same visible result. They are per *second* here, scaled
    // by the measured frame delta. (AUDIT M11)
    private static let dragSensitivity: Double = 0.005
    /// Per-frame at `dampingReferenceRate`, kept in the tuned units and raised
    /// to `dt * 60` in `tick()` rather than re-derived — `0.94^60 ≈ 0.024/s`
    /// is not a number anyone would recognise as this dial.
    private static let inertiaDamping: Double = 0.94
    private static let dampingReferenceRate: Double = 60
    private static let maxPitch: Double = 1.0
    private static let globeRadius: Double = 1.05
    /// Was `-0.0032` per frame: the same rotation, stated per second.
    private static let autoSpinRate: Double = -0.0032 * dampingReferenceRate
    /// A frame delta longer than this is a stall, not a slow frame — a
    /// backgrounded app or a blocked main thread returning after half a second
    /// would otherwise snap the globe a third of a turn. Clamped, the worst
    /// case is one 50ms step.
    private static let maxFrameDelta: Double = 1.0 / 20
    /// Marker re-projection cadence. Was "every 4th frame", which is this at
    /// 60Hz and half as slow again at 120.
    private static let markerInterval: Double = 4.0 / dampingReferenceRate
    /// Ceiling on the coast a flick leaves behind, ~4 turns/second.
    ///
    /// A guard, not a tuning dial: it sits above the fastest throw a real
    /// gesture produces (a 4000pt/s sweep is ~20 rad/s), so ordinary flicks
    /// keep exactly the speed they had before this rewrite. It exists for the
    /// pathological case the per-second form introduces — two touch events
    /// delivered close enough together that the divide amplifies a small
    /// movement.
    ///
    /// Applied in `endDrag`, deliberately, **not** in `drag`. `tick()`
    /// integrates `velocityYaw` on every frame including while the finger is
    /// down (only the damping is gated on `!dragging`), so a ceiling applied
    /// during the drag caps half of the rotation the finger is causing — which
    /// makes the control's gain a function of how fast you move, the one thing
    /// a direct-manipulation control must never do.
    private static let maxThrowRate: Double = 8 * .pi
    /// Camera pull-back — **3.45 since 0.6.9 (L1)**, in from 3.95.
    ///
    /// The globe grows by moving the camera rather than by scaling the sphere,
    /// which is the only version of "larger" that keeps the screen coherent:
    /// `globeRadius` is the unit the marker projection, the wireframe shell and
    /// the front-facing test are all written in, so scaling it would mean
    /// re-deriving three other things to end up looking identical. Pulling the
    /// camera in is one number and everything follows through the same
    /// projection — the markers included, since `markerScreenPoint` goes
    /// through `projectPoint`.
    ///
    /// 3.95 was chosen against the web app's 3.6 to give the markers room to
    /// breathe on a phone, and that argument has since been overtaken twice:
    /// 0.6.8 (C1) put real hero icons on the continent rows so the list is now
    /// a first-class way to pick one, and the marker plates hide well before
    /// the limb anyway (`frontFacingThreshold`). At 3.45 the sphere is ~14%
    /// wider on screen and the plates still clear each other.
    private static let cameraDistance: Double = 3.45
    /// Markers hide well before the limb so they never straddle the edge.
    private static let frontFacingThreshold: Double = 0.55

    /// Correction between the lat/lng maths and where the texture actually
    /// draws each landmass.
    ///
    /// `SCNSphere` does not lay an equirectangular image out the way three.js's
    /// `SphereGeometry` does, so the projection formula ported from the web app
    /// lands a quarter-turn away from the coastline it names. Two rounds of
    /// screen-space nudging summed to roughly the globe's on-screen radius,
    /// which is the signature of a 90° longitude error — a pixel shift equal to
    /// the radius is what `sin(90°)` gives you.
    ///
    /// Applied as an angle rather than a pixel offset so it stays correct as
    /// the globe spins and as markers move away from the sphere's centre, where
    /// a fixed screen shift over-corrects.
    ///
    /// If this overshoots, the other candidates are `+90` and `180`.
    private static let markerLongitudeOffset: Double = -90
    /// Small southward bias: the label box is centred on its point, so the eye
    /// reads the marker as sitting above the landmass it names.
    private static let markerLatitudeOffset: Double = -8

    /// Marker colours come from the continent entries themselves (v0.5.6):
    /// the icon well and the globe marker are the same colour by
    /// construction, not by two tables agreeing.
    var markers: [Marker] = Continent.allCases.map {
        let entry = WineDatabase.shared.continentEntry($0)
        return Marker(
            continent: $0,
            position: .zero,
            visible: false,
            color: Color(dexHex: entry?.common.color ?? "#4ADE80"),
            entry: entry
        )
    }

    var viewportSize: CGSize = .zero

    /// Whether the globe drifts on its own. Off under Reduce Motion and under
    /// VoiceOver — see `RetroGlobeScreen.freezesGlobe`. (AUDIT M18, M20)
    var autoSpins = true

    private(set) var cameraNode = SCNNode()
    private var globeNode = SCNNode()
    private var wireNode = SCNNode()
    private weak var sceneView: SCNView?
    private var displayLink: CADisplayLink?

    private var yaw: Double = 0
    private var pitch: Double = 0
    private var velocityYaw: Double = 0
    private var velocityPitch: Double = 0
    private var dragging = false
    private var lastTranslation: CGSize = .zero
    /// The previous frame's `CADisplayLink.timestamp`. Zero means "no frame yet
    /// this run", which is also what `stop()` restores.
    private var lastTimestamp: CFTimeInterval = 0
    /// Seconds since markers were last re-projected.
    private var markerClock: Double = 0
    /// Timestamp of the previous drag event, for the per-second throw. Nil
    /// between gestures, so the first event of a drag sets no velocity rather
    /// than dividing by an interval it does not have.
    private var lastDragTime: Date?

    // MARK: Scene construction

    /// Builds the globe for one LCD mode.
    ///
    /// The screen mode has to reach in here rather than being handled by the
    /// SwiftUI layer alone: the whole rig — emission, three light colours and
    /// the wireframe — used to be a green CRT glow tuned against a black
    /// ground. Left alone on the light screen it read as a hole punched in the
    /// page, which is why the globe was the one screen the setting appeared not
    /// to touch.
    ///
    /// **Every green in the rig is derived from `tint` since 0.6.6 (A).** That
    /// item exists because the sphere stayed green in every mode while the LCD
    /// behind it themed correctly, and the cause turned out to be arithmetic,
    /// not plumbing — the tint was reaching this function all along.
    /// `updatedglobemap.jpg` is a pure-green neon coastline on black, and 0.6.5
    /// applied the tint as a channel *multiply*. A multiply can only ever take
    /// colour away: green times purple is a darker green, because the texture
    /// has no red or blue for the purple to scale up. The one mode that looked
    /// right was LIGHT, and only because it inverts the texture before the
    /// multiply reaches it.
    ///
    /// So the texture is **colorized** now (see `colorized(_:with:)`) — reduced
    /// to luminance and re-hued — and the three lights, the emission and the
    /// wireframe all take the tint too. Colorizing alone would not have been
    /// enough: a purple sphere lit by three green lamps renders green again.
    func buildScene(isLight: Bool, tint: UIColor = .white, invertsTexture: Bool = false) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        // Textured globe.
        let sphere = SCNSphere(radius: CGFloat(Self.globeRadius))
        sphere.segmentCount = 96
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        if let url = DexResources.url(named: "updatedglobemap", ext: "jpg", subdirectory: "Maps"),
           let image = UIImage(contentsOfFile: url.path) {
            // Both treatments happen to the TEXTURE, once per rebuild
            // (`buildScene` only runs from `makeUIView`): invert first
            // (LIGHT's globe, 0.6.4), then colorize into the mode/skin tint
            // (0.6.6, A — 0.6.5's item 7 multiplied here instead).
            //
            // Texture-space rather than `SCNMaterial.multiply`, which is where
            // the tint rode for two releases without ever visibly reaching the
            // device: under the physically-based lighting model that layer is
            // quietly ignored on hardware.
            let base = invertsTexture ? Self.inverted(image) ?? image : image
            material.diffuse.contents = Self.colorized(base, with: tint) ?? base
        } else {
            material.diffuse.contents = tint
        }
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .clamp
        material.roughness.contents = 0.92
        material.metalness.contents = 0.08
        // Self-illumination is what makes the dark globe glow. On paper it only
        // washes the landmasses out, so light mode keeps a trace of it for
        // warmth and lets the lights do the work. A deep shade of the tint
        // rather than the old fixed bottle green: the glow has to be the same
        // colour as the thing glowing.
        material.emission.contents = Self.shaded(tint, isLight ? 0.20 : 0.14)
        material.emission.intensity = isLight ? 0.08 : 0.3
        sphere.materials = [material]
        globeNode = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(globeNode)

        // Wireframe shell just outside it.
        let wire = SCNSphere(radius: CGFloat(Self.globeRadius + 0.04))
        wire.segmentCount = 28
        let wireMaterial = SCNMaterial()
        wireMaterial.fillMode = .lines
        wireMaterial.lightingModel = .constant
        // A pale tint disappears against the light ground, so the light shell
        // takes a deep shade of it instead — and needs more opacity, since a
        // dark line at 8% is invisible where a glowing one was not.
        wireMaterial.diffuse.contents = isLight ? Self.shaded(tint, 0.32) : Self.lifted(tint, 0.30)
        wireMaterial.transparency = isLight ? 0.22 : 0.08
        wireMaterial.isDoubleSided = true
        wire.materials = [wireMaterial]
        wireNode = SCNNode(geometry: wire)
        scene.rootNode.addChildNode(wireNode)

        // Lighting: ambient + key + rim, matching the three.js rig.
        //
        // All three carry the tint since 0.6.6 (A), lifted toward white by
        // different amounts so they stay *lights* rather than three coloured
        // gels — the key is nearly white, the rim is the tint itself. The tints
        // are pale by construction (see `LcdMode.globeTint`), so this is a cast
        // on the light rather than a wash, and the colorized texture keeps
        // control of the hue. Light mode keeps its lifted ambient so the sphere
        // reads as a lit object on paper rather than a glowing one in the dark.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = Self.lifted(tint, isLight ? 0.72 : 0.18)
        ambient.light?.intensity = isLight ? 620 : 330
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.color = Self.lifted(tint, isLight ? 1 : 0.55)
        key.light?.intensity = isLight ? 950 : 1100
        key.position = SCNVector3(2.5, 1.8, 3.2)
        key.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(key)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.color = isLight ? Self.shaded(tint, 0.62) : tint
        rim.light?.intensity = isLight ? 260 : 500
        rim.position = SCNVector3(-3, -1, -2)
        rim.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(rim)

        let camera = SCNCamera()
        camera.fieldOfView = 50
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, Float(Self.cameraDistance))
        scene.rootNode.addChildNode(cameraNode)

        return scene
    }

    func attach(to view: SCNView) {
        sceneView = view
        restoreHeading()
        applyOrientation()
        start()
    }

    /// Where the globe was pointing, kept across navigation.
    ///
    /// The globe is a *map*, and leaving one for a place and coming back to find
    /// it re-centred on the Atlantic is the same complaint as a list reopening
    /// at the top: you have to find Europe again to open the second continent.
    /// Read and written here rather than by the view, because `attach(to:)` is
    /// the moment the scene exists and the frame loop has not yet moved it.
    ///
    /// Session-only via `ScreenStateStore`, so a cold launch still opens on the
    /// default heading, and Home resets it.
    private func restoreHeading() {
        let store = ScreenStateStore.shared
        yaw = store.number("yaw", for: ScreenStateStore.globe) ?? 0
        pitch = min(max(store.number("pitch", for: ScreenStateStore.globe) ?? 0, -Self.maxPitch), Self.maxPitch)
    }

    private func saveHeading() {
        let store = ScreenStateStore.shared
        store.setNumber(yaw, "yaw", for: ScreenStateStore.globe)
        store.setNumber(pitch, "pitch", for: ScreenStateStore.globe)
    }

    // MARK: Loop

    private func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: DisplayLinkProxy { [weak self] in self?.tick() },
                                 selector: #selector(DisplayLinkProxy.fire))
        // Ask for 30–60 rather than taking the panel's native rate. The scene
        // is one slowly-rotating sphere and six labels; there is nothing in it
        // a 120Hz sample rate resolves that a 60Hz one does not, and the
        // difference is a doubled GPU/CPU bill for the whole time the screen is
        // open. The floor is what stops the system dropping it so far that the
        // rotation reads as a stutter. (AUDIT M11)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        lastTimestamp = 0
        markerClock = 0
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
        saveHeading()
    }

    private func tick() {
        guard let link = displayLink else { return }

        // Elapsed time between *presented* frames, so a dropped frame is
        // caught up rather than lost. The first frame of a run has nothing to
        // measure against and takes the nominal step.
        let now = link.timestamp
        let dt = lastTimestamp > 0
            ? min(max(now - lastTimestamp, 0), Self.maxFrameDelta)
            : 1 / Self.dampingReferenceRate
        lastTimestamp = now
        guard dt > 0 else { return }

        if !dragging {
            let decay = pow(Self.inertiaDamping, dt * Self.dampingReferenceRate)
            velocityYaw *= decay
            velocityPitch *= decay
        }

        yaw += (velocityYaw + (autoSpins ? Self.autoSpinRate : 0)) * dt
        pitch = min(max(pitch + velocityPitch * dt, -Self.maxPitch), Self.maxPitch)

        applyOrientation()

        // Markers are re-projected on a clock rather than a frame count, as the
        // web version does by frame — they move slowly and this keeps SwiftUI
        // updates cheap. Keyed to time so the cadence is the same 15Hz whatever
        // rate the display link is actually running at.
        markerClock += dt
        if markerClock >= Self.markerInterval {
            markerClock = 0
            updateMarkers()
        }
    }

    /// Composes yaw then pitch as explicit quaternions about world axes.
    ///
    /// Setting `eulerAngles` instead let SceneKit's own rotation order decide how
    /// the two combine, which is what made dragging feel flipped and unstable
    /// once the globe was tilted — three.js accumulates the two axes
    /// independently, and this reproduces that.
    ///
    /// Both writes are wrapped in a zero-duration transaction: SceneKit animates
    /// transform changes implicitly, so a per-frame write would otherwise be
    /// smoothed and lag the input.
    private func applyOrientation() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0

        let spin = simd_quatf(angle: Float(yaw), axis: SIMD3<Float>(0, 1, 0))
        let tilt = simd_quatf(angle: Float(pitch), axis: SIMD3<Float>(1, 0, 0))
        let orientation = tilt * spin

        globeNode.simdOrientation = orientation
        wireNode.simdOrientation = orientation

        SCNTransaction.commit()
    }

    private func updateMarkers() {
        guard let view = sceneView, viewportSize.width > 0 else { return }

        // Half-extents of a marker plate, used for the edge-of-viewport test.
        // Grown with the 0.6.5 (item 10) size bump — an undersized box here
        // lets a plate straddle the LCD edge before it hides.
        let hw: CGFloat = 66
        let hh: CGFloat = 38

        markers = markers.map { marker in
            var next = marker
            let local = Self.latLngToVector3(
                lat: marker.continent.coordinate.lat + Self.markerLatitudeOffset,
                lng: marker.continent.coordinate.lng + Self.markerLongitudeOffset,
                radius: Self.globeRadius
            )
            // Into world space through the globe's current orientation.
            //
            // The model node, not `presentation`: the transform is written
            // directly each frame with animation disabled, so the presentation
            // node has nothing to interpolate and trails the real orientation —
            // which left markers lagging behind the surface they mark.
            let world = globeNode.convertPosition(local, to: nil)
            let projected = view.projectPoint(world)

            let point = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
            let inBounds = point.x - hw >= 0
                && point.x + hw <= viewportSize.width
                && point.y - hh >= 0
                && point.y + hh <= viewportSize.height

            // Front-facing test. The globe sits at the origin with the camera on
            // +z, so a rotated point's world z is already its facing measure —
            // the same check the web version makes on `pos.z`.
            let facing = Double(world.z) > Self.frontFacingThreshold

            next.position = point
            next.visible = facing && inBounds
            return next
        }
    }

    // MARK: Input

    /// Applies one drag event, and records the throw it would leave behind.
    ///
    /// The rotation the finger causes is a *position* delta and is applied 1:1,
    /// exactly as before — it must track the finger, not a clock. The velocity
    /// kept for inertia is the separate thing that has to be per-second: it was
    /// simply the last event's delta, i.e. "however far the finger moved in one
    /// touch event", which on a 120Hz panel is half the distance it is on a
    /// 60Hz one for the same real speed. Dividing by the interval between the
    /// two events makes the throw the same on both. (AUDIT M11)
    func drag(translation: CGSize, at time: Date) {
        let dx = translation.width - lastTranslation.width
        let dy = translation.height - lastTranslation.height
        lastTranslation = translation
        dragging = true

        let dYaw = Double(dx) * Self.dragSensitivity
        let dPitch = Double(dy) * Self.dragSensitivity * 0.45

        // Floored, not clamped both ends: two events arriving in the same
        // millisecond would otherwise divide out to a thousandfold throw. A
        // long interval needs no floor of its own — a finger that paused has
        // moved correspondingly further, so the ratio stays honest. The ceiling
        // is applied at release instead — see `maxThrowRate`.
        //
        // The first event of a gesture has one sample and no interval, and
        // takes the nominal one, exactly as `tick()`'s first frame does. Not
        // zero: `tick()` integrates this velocity while the finger is still
        // down, so a zero here would quietly drop one event's worth of
        // rotation, and on a three-event flick that is 17% of the turn — a
        // control whose gain depends on how fast you move it, which is what
        // this whole item is about. The next event lands 8–16ms later and
        // replaces the estimate.
        let interval = lastDragTime.map { max(time.timeIntervalSince($0), 1.0 / 240) }
            ?? (1 / Self.dampingReferenceRate)
        velocityYaw = dYaw / interval
        velocityPitch = dPitch / interval
        lastDragTime = time

        yaw += dYaw
        pitch = min(max(pitch + dPitch, -Self.maxPitch), Self.maxPitch)
    }

    func endDrag() {
        dragging = false
        lastTranslation = .zero
        lastDragTime = nil
        // The only place the ceiling belongs: from here on nothing is driving
        // the globe but this number.
        velocityYaw = min(max(velocityYaw, -Self.maxThrowRate), Self.maxThrowRate)
        velocityPitch = min(max(velocityPitch, -Self.maxThrowRate), Self.maxThrowRate)
    }

    /// The map texture **colorized** into the mode/skin tint (0.6.6, A).
    ///
    /// Replaces 0.6.5's channel multiply, which could not work on this
    /// particular texture and so made the whole per-mode globe feature look
    /// like it had never shipped. `updatedglobemap.jpg` is a neon-green
    /// coastline on black — roughly `(0.25, 0.95, 0.30)` where there is ink and
    /// zero everywhere else. Multiplying that by L-WINES' purple scales a green
    /// that is already there and a red and blue that are not, so the output is
    /// a *dimmer green*. Every mode multiplied to green, which is exactly what
    /// the device showed.
    ///
    /// Colorizing throws the texture's own hue away first: each output channel
    /// is the pixel's **luminance** times that channel of the tint, which one
    /// `CIColorMatrix` does in a single pass — `inputRVector` dotted with the
    /// input RGBA *is* `luma · tint.r` when its three colour terms are the
    /// luminance weights scaled by `tint.r`. Coastline detail survives because
    /// luminance preserves it; only the hue is replaced.
    ///
    /// `gain` compensates for what desaturation costs: the neon green's
    /// luminance is well below its green channel, so a straight colorize
    /// returns a globe noticeably dimmer than the one people are used to. The
    /// 8-bit render at the end clamps whatever this pushes past white.
    ///
    /// Near-white tints skip the filter entirely — LIGHT deliberately passes
    /// white and inverts the texture instead (0.6.4, F1), and colorizing by
    /// white would flatten that inversion to greyscale.
    private static func colorized(_ image: UIImage, with tint: UIColor) -> UIImage? {
        let c = components(tint)
        guard c.r < 0.98 || c.g < 0.98 || c.b < 0.98 else { return image }

        let gain: CGFloat = 1.3
        // Rec. 601 luma weights — the same ones `CIPhotoEffectMono` uses.
        let luma = (r: 0.299 * gain, g: 0.587 * gain, b: 0.114 * gain)

        guard let input = CIImage(image: image),
              let filter = CIFilter(name: "CIColorMatrix")
        else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: luma.r * c.r, y: luma.g * c.r, z: luma.b * c.r, w: 0), forKey: "inputRVector")
        filter.setValue(CIVector(x: luma.r * c.g, y: luma.g * c.g, z: luma.b * c.g, w: 0), forKey: "inputGVector")
        filter.setValue(CIVector(x: luma.r * c.b, y: luma.g * c.b, z: luma.b * c.b, w: 0), forKey: "inputBVector")
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        guard let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// The tint's sRGB components. `getRed` fails on a colour that is not in an
    /// RGB space (a pattern or a monochrome `UIColor`), so an unreadable tint
    /// falls back to white — which is the identity everywhere it is used.
    private static func components(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return (1, 1, 1) }
        return (r, g, b)
    }

    /// `color` scaled toward black — the tint's deep register, for the
    /// emission glow and light mode's wireframe.
    private static func shaded(_ color: UIColor, _ factor: CGFloat) -> UIColor {
        let c = components(color)
        return UIColor(red: c.r * factor, green: c.g * factor, blue: c.b * factor, alpha: 1)
    }

    /// `color` mixed toward white — the tint's light register, for the lamps.
    /// At `amount` 1 this is plain white, which is what LIGHT mode wants.
    private static func lifted(_ color: UIColor, _ amount: CGFloat) -> UIColor {
        let c = components(color)
        return UIColor(
            red: c.r + (1 - c.r) * amount,
            green: c.g + (1 - c.g) * amount,
            blue: c.b + (1 - c.b) * amount,
            alpha: 1
        )
    }

    /// The map texture with its colours inverted (0.6.4, F1) — LIGHT mode's
    /// globe. Core Image over a hand-rolled pixel loop for the obvious
    /// reasons; a nil from any stage falls back to the original texture at
    /// the call site rather than to a blank sphere.
    private static func inverted(_ image: UIImage) -> UIImage? {
        guard let input = CIImage(image: image),
              let filter = CIFilter(name: "CIColorInvert")
        else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        guard let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Ported verbatim from the web app so markers land in the same places.
    private static func latLngToVector3(lat: Double, lng: Double, radius: Double) -> SCNVector3 {
        let phi = (90 - lat) * .pi / 180
        let theta = (lng + 180) * .pi / 180
        return SCNVector3(
            Float(-(radius * sin(phi) * cos(theta))),
            Float(radius * cos(phi)),
            Float(radius * sin(phi) * sin(theta))
        )
    }
}

/// `CADisplayLink` needs an ObjC target; this keeps the model free of NSObject.
private final class DisplayLinkProxy: NSObject {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func fire() {
        handler()
    }
}
#endif
