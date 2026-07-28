#if canImport(SwiftUI) && canImport(UIKit)
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

    @State private var model = GlobeModel()
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }


    public init(
        onSelectContinent: @escaping (Continent) -> Void,
        onWorldSearch: @escaping () -> Void
    ) {
        self.onSelectContinent = onSelectContinent
        self.onWorldSearch = onWorldSearch
    }

    public var body: some View {
        ZStack {
            Color.black

            // 24pt scan grid behind the globe.
            DexGridBackground(spacing: 24, color: Dex.green, opacity: 0.24)
                .opacity(0.3)

            VStack(spacing: 12) {
                // Looks like the other screens' search bars, but it opens the
                // search screen rather than filtering in place — results laid
                // over a spinning sphere read as a rendering glitch.
                searchBar

                ZStack {
                    GlobeSceneView(model: model)
                        .gesture(dragGesture)

                    markerLayer
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("DRAG TO SPIN GLOBE")
                    .font(DexFont.retro(11))
                    .tracking(3)
                    .foregroundStyle(lcd.accent)
            }
            .padding(.vertical, 12)
        }
        .onDisappear { model.stop() }
    }

    // MARK: Markers

    private var markerLayer: some View {
        GeometryReader { geo in
            ForEach(model.markers) { marker in
                Button {
                    Haptics.tap()
                    onSelectContinent(marker.continent)
                } label: {
                    Text(marker.continent.markerLabel)
                        .font(DexFont.retro(11))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .frame(width: 108, height: 62)
                        .background(marker.color.opacity(0.12))
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
                .animation(.easeOut(duration: 0.3), value: marker.visible)
            }
            .onAppear { model.viewportSize = geo.size }
            .onChange(of: geo.size) { _, size in model.viewportSize = size }
        }
    }

    /// Carries the same capsule treatment as `EncyclopediaListScreen.searchBar`
    /// so it reads as a search affordance, but it is a button: tapping it opens
    /// the world-search screen with a real keyboard-backed field.
    private var searchBar: some View {
        Button {
            Haptics.tap()
            onWorldSearch()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(lcd.accent)

                // Same face, size and colour as DexSearchField's placeholder,
                // so this reads as the identical control — it just happens to
                // open the search screen rather than accept typing in place.
                Text("SEARCH WORLD...")
                    .font(DexFont.mono(26))
                    .foregroundStyle(lcd.accent.opacity(0.45))

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Dex.stone600)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Capsule().fill(lcd.well))
            .overlay(Capsule().strokeBorder(lcd.surfaceEdge, lineWidth: 2))
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
        .padding(.horizontal, 12)
    }

    // MARK: Drag

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in model.drag(translation: value.translation) }
            .onEnded { _ in model.endDrag() }
    }
}

// MARK: - Scene

/// Hosts the `SCNView`. SceneKit is UIKit-only, so this is the bridge.
struct GlobeSceneView: UIViewRepresentable {
    let model: GlobeModel

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling2X
        view.isUserInteractionEnabled = false   // gestures are handled in SwiftUI
        view.scene = model.buildScene()
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
        var id: String { continent.rawValue }
    }

    // Constants ported directly from RetroGlobeScreen.tsx.
    private static let dragSensitivity: Double = 0.005
    private static let inertiaDamping: Double = 0.94
    private static let maxPitch: Double = 1.0
    private static let globeRadius: Double = 1.05
    private static let autoSpin: Double = -0.0032
    /// Camera pull-back. The web app sits at 3.6; further out shrinks the globe
    /// so the markers have room to breathe on a phone.
    private static let cameraDistance: Double = 3.95
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

    /// Continent marker colours, overriding the continent palette entries.
    private static let markerColors: [Continent: String] = [
        .northAmerica: "#E53935",
        .southAmerica: "#8E24AA",
        .europe: "#1E88E5",
        .africa: "#8D6E63",
        .asia: "#FDD835",
        .oceania: "#43A047",
    ]

    var markers: [Marker] = Continent.allCases.map {
        Marker(
            continent: $0,
            position: .zero,
            visible: false,
            color: Color(dexHex: markerColors[$0] ?? "#4ADE80")
        )
    }

    var viewportSize: CGSize = .zero

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
    private var frameCount = 0

    // MARK: Scene construction

    func buildScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        // Textured globe.
        let sphere = SCNSphere(radius: CGFloat(Self.globeRadius))
        sphere.segmentCount = 96
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        if let url = DexResources.url(named: "updatedglobemap", ext: "jpg", subdirectory: "Resources/Maps"),
           let image = UIImage(contentsOfFile: url.path) {
            material.diffuse.contents = image
        } else {
            material.diffuse.contents = UIColor(Dex.green)
        }
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .clamp
        material.roughness.contents = 0.92
        material.metalness.contents = 0.08
        material.emission.contents = UIColor(Color(dexHex: "#0d311f"))
        material.emission.intensity = 0.3
        sphere.materials = [material]
        globeNode = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(globeNode)

        // Wireframe shell just outside it.
        let wire = SCNSphere(radius: CGFloat(Self.globeRadius + 0.04))
        wire.segmentCount = 28
        let wireMaterial = SCNMaterial()
        wireMaterial.fillMode = .lines
        wireMaterial.lightingModel = .constant
        wireMaterial.diffuse.contents = UIColor(Color(dexHex: "#7bffbc"))
        wireMaterial.transparency = 0.08
        wireMaterial.isDoubleSided = true
        wire.materials = [wireMaterial]
        wireNode = SCNNode(geometry: wire)
        scene.rootNode.addChildNode(wireNode)

        // Lighting: ambient + key + rim, matching the three.js rig.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(Color(dexHex: "#66ff99"))
        ambient.light?.intensity = 330
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.color = UIColor(Color(dexHex: "#9bffca"))
        key.light?.intensity = 1100
        key.position = SCNVector3(2.5, 1.8, 3.2)
        key.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(key)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.color = UIColor(Color(dexHex: "#1fff91"))
        rim.light?.intensity = 500
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
        applyOrientation()
        start()
    }

    // MARK: Loop

    private func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: DisplayLinkProxy { [weak self] in self?.tick() },
                                 selector: #selector(DisplayLinkProxy.fire))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func tick() {
        if !dragging {
            velocityYaw *= Self.inertiaDamping
            velocityPitch *= Self.inertiaDamping
        }

        yaw += velocityYaw + Self.autoSpin
        pitch = min(max(pitch + velocityPitch, -Self.maxPitch), Self.maxPitch)

        applyOrientation()

        // Markers are re-projected every few frames, as the web version does —
        // they move slowly and this keeps SwiftUI updates cheap.
        frameCount += 1
        if frameCount % 4 == 0 {
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

        let hw: CGFloat = 54
        let hh: CGFloat = 31

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

    func drag(translation: CGSize) {
        let dx = translation.width - lastTranslation.width
        let dy = translation.height - lastTranslation.height
        lastTranslation = translation
        dragging = true

        velocityYaw = Double(dx) * Self.dragSensitivity
        velocityPitch = Double(dy) * Self.dragSensitivity * 0.45

        yaw += velocityYaw
        pitch = min(max(pitch + velocityPitch, -Self.maxPitch), Self.maxPitch)
    }

    func endDrag() {
        dragging = false
        lastTranslation = .zero
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
