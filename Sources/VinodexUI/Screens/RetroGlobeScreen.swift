#if canImport(SwiftUI) && canImport(UIKit)
import CoreImage
import SwiftUI
import SceneKit
import simd
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

    /// The database this screen reads. Defaulted so no call site changes, but
    /// injectable — and here it also seeds `GlobeModel`, which is not a `View`
    /// and so has no other way to be given one. (AUDIT **M27**)
    private let db: WineDatabase

    @State private var model: GlobeModel
    /// Whether the flat continent list is showing instead of the globe.
    ///
    /// The globe is a *drag-and-tap-a-moving-target* control, which is not a
    /// control at all for someone using VoiceOver, Switch Control or a shaky
    /// hand — and the rear half of the sphere cannot even be reached without a
    /// drag. This list is the equivalent path, present on both mounts (the
    /// scanner's globe step turns `showsSearch` off, so before this it had no
    /// non-globe way to name a continent at all). (AUDIT M20)
    @State private var showsList = false
    /// The country under the last tap. A second tap on the same one opens its
    /// region map — the prototype's two-tier gesture, which is why this is
    /// state rather than a transient highlight.
    @State private var pickedCountry: GlobeIndex.Country?
    /// The globe viewport's size, so the debug probe below can tap its centre.
    @State private var globeSize: CGSize = .zero
    /// The country whose region map is raised over the globe, if any.
    @State private var regionTier: String?
    /// The last tap, for counting a double — see `tapped(at:)`.
    @State private var lastTap: (point: CGPoint, when: Date)?
    /// A region for the screenshot probe to open the overlay's card on. Always
    /// nil outside `-vinodexScreenshot`.
    @State private var probeStem: String?
    /// The region under the last tap at the region tier, named in the HUD and
    /// carrying the entry tile.
    @State private var selectedRegion: String?
    /// The magnification a pinch started from. `MagnifyGesture` reports a
    /// factor against the gesture's own start, not against the last frame, so
    /// without an anchor each update would compound the one before it.
    @State private var pinchAnchor: Double?
    /// The entry behind the chosen region, resolved once when it is chosen.
    ///
    /// **Not resolved in the view body.** `GlobeModel` writes `yaw` every
    /// frame and `@Observable` invalidates on every write, so this screen's
    /// body runs at 60Hz — and the tile was doing a catalog id-resolve plus two
    /// store lookups inside it, sixty times a second, for a tile that changes
    /// only when you tap.
    @State private var selectedEntry: WineEntry?

    /// The magnification the region tier was framed at, so a pinch past it can
    /// hand dragging back. Nil away from that tier.
    @State private var fittedZoom: Double?


    /// **The map holds still at the size it was framed at, and moves once you
    /// zoom past that.** Locking the region tier outright made pinch a trap:
    /// magnification is about the screen centre, so anything that left the
    /// glass could not be brought back and the small regions pinch exists to
    /// reach became unreachable. Fitted or wider, it is pinned; closer in, it
    /// pans.
    private var canDragGlobe: Bool {
        guard regionTier != nil else { return true }
        guard let fitted = fittedZoom else { return false }
        return model.zoom > fitted * 1.02
    }

    /// What a scene rebuild is keyed on — the screen mode, the skin and the
    /// texture are all baked in `buildScene`, so each has to force one.
    private var sceneKey: String {
        "\(lcd.rawValue)|\(skin.rawValue)|\(globeTexture.stem)"
    }

    /// The globe viewport's width over its height. On a portrait screen the
    /// horizontal field is the narrow one, so the fit has to know this or
    /// every wide country loses its coasts.
    private var viewportAspect: Double {
        guard globeSize.height > 1 else { return 0.8 }
        return Double(globeSize.width / globeSize.height)
    }
    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }
    /// The skin's tint is the DARK-mode fallback (0.6.2, F1); every other
    /// screen mode brings its own globe colour (0.6.4, F1) — see
    /// `LcdMode.globeTint` for why the mode outranks the skin here.
    private var skin: ChassisSkin { settings.chassisSkin }
    /// Perpetual rotation is the one thing on this screen that is motion for
    /// its own sake. (AUDIT M18)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    /// Mode first, skin as the DARK fallback — the resolution 0.6.4 F1 exists
    /// to establish.
    private var globeTint: Color { lcd.globeTint ?? skin.globeTint }
    private var globeTexture: GlobeTexture { settings.wineGlobe ? .wine : .coastline }

    /// Autospin off. Two reasons, one rule: Reduce Motion asks for no
    /// unprompted movement, and VoiceOver cannot land on a target that is
    /// drifting under the cursor — "pause at rest" from AUDIT M20. A drag still
    /// spins the globe in both cases; what stops is the movement nobody asked
    /// for.
    private var freezesGlobe: Bool { reduceMotion || voiceOver }

    /// Opens a country's painted region map (0.9.55). Nil where the host has
    /// nowhere to send it, in which case a second tap simply re-names the
    /// country rather than going anywhere.
    /// Opens an entry page from the region overlay's card — the last step of
    /// the artifact's descent: globe, country, region, entry.
    let onOpenEntry: ((WineEntry) -> Void)?
    /// Opens a country's own page, from the tile the globe raises when one is
    /// tapped.
    let onOpenCountry: ((String) -> Void)?

    public init(
        db: WineDatabase = .shared,
        onSelectContinent: @escaping (Continent) -> Void,
        onWorldSearch: @escaping () -> Void,
        showsSearch: Bool = true,
        onOpenEntry: ((WineEntry) -> Void)? = nil,
        onOpenCountry: ((String) -> Void)? = nil
    ) {
        self.db = db
        _model = State(initialValue: GlobeModel(db: db))
        self.onSelectContinent = onSelectContinent
        self.onWorldSearch = onWorldSearch
        self.showsSearch = showsSearch
        self.onOpenEntry = onOpenEntry
        self.onOpenCountry = onOpenCountry
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
                // **The globe's own controls stand down while the region map
                // is up.** The scrim dims the sphere, which is the point — you
                // can see you are still on Globe Scan — but it cannot make a
                // search field or a zoom bank stop reading as controls, and a
                // map of Italy framed by buttons belonging to the tier above it
                // is just two screens drawn on top of each other. The globe
                // stays; the things you could press on it go.
                if showsSearch && regionTier == nil {
                    searchBar
                }

                ZStack {
                    GlobeSceneView(
                        model: model,
                        isLight: lcd.isLight,
                        tint: UIColor(globeTint),
                        invertsTexture: lcd.invertsGlobeTexture,
                        texture: globeTexture
                    )
                        // The scene's lighting, emission and tint are
                        // baked in `buildScene`, which only runs in
                        // `makeUIView` — so a mode or skin switch has to
                        // rebuild the view to take effect. Keyed on both, it
                        // costs one rebuild per toggle rather than one per
                        // render.
                        // The texture joins the key for the same reason the
                        // other two are in it: it is baked in `buildScene`,
                        // so flipping the switch has to rebuild the view to
                        // be seen at all.
                        .id(sceneKey)

                    // The drag rides an explicit clear hit-shape rather than
                    // the representable (0.9.51 fix): the SCNView disables its
                    // own interaction on purpose, and the iOS 18 runtime
                    // stopped routing SwiftUI gestures through a
                    // non-interactive representable — the globe froze with
                    // zero code changed. A shape SwiftUI owns cannot be
                    // opted out from under us. Markers sit above and keep
                    // hit priority.
                    // **The sphere itself is the tap target** (0.9.55). The
                    // drag still rides its own clear shape — the 0.9.51 fix:
                    // the SCNView disables its interaction on purpose and the
                    // iOS 18 runtime stopped routing SwiftUI gestures through
                    // a non-interactive representable. The tap is layered on
                    // the same shape, and a drag that starts moving wins, so
                    // spinning the globe never selects a country.
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            // **The drag stays the primary gesture and the
                            // taps ride alongside it.** `.gesture(drag)` with
                            // a separate `.onTapGesture` is a SwiftUI
                            // arbitration conflict: the drag claims the touch
                            // sequence and the tap never fires, which is
                            // exactly what "nothing happens" looked like.
                            // Simultaneous lets both recognise — the drag
                            // needs 4pt of travel, a tap needs none, so they
                            // cannot both win the same touch.
                            .gesture(dragGesture)
                            // **One tap gesture, and the second tap counted
                            // here.** `SpatialTapGesture(count: 2)` never
                            // fired alongside the drag, whether composed
                            // exclusively or simultaneously — SwiftUI's
                            // arbitration has been the cause of every dead
                            // gesture on this screen. Counting the taps
                            // ourselves is a dozen lines and cannot be
                            // out-voted by a gesture we do not control.
                            .simultaneousGesture(
                                SpatialTapGesture()
                                    .onEnded { tapped(at: $0.location) }
                            )
                            // **Pinch is the magnification control now**
                            // (0.9.56). A slider spent the screen's whole
                            // width reporting a number, on a screen whose
                            // subject is a picture; two fingers say the same
                            // thing and cost nothing. Simultaneous, like the
                            // tap: a pinch and a drag can share a touch
                            // sequence, and arbitration on this screen has
                            // eaten every gesture that had to win one.
                            .simultaneousGesture(
                                MagnifyGesture()
                                    .onChanged { value in
                                        if pinchAnchor == nil { pinchAnchor = model.zoom }
                                        let base = pinchAnchor ?? model.zoom
                                        model.zoom = min(GlobeModel.maxZoom,
                                                         max(1, base * value.magnification))
                                    }
                                    .onEnded { _ in pinchAnchor = nil }
                            )
                            .onAppear { globeSize = geo.size }
                            .onChange(of: geo.size) { _, new in globeSize = new }
                    }

                    // **The instrument panel** (0.9.55), after the Globe Scan
                    // prototype: the readout sits on the glass rather than
                    // printed under it. Hidden while the list is up — the
                    // list answers for the globe then, and a coordinate for a
                    // sphere nobody is looking at is furniture.
                    if !showsList {
                        globeScanlines
                        globeHUD
                        // **The tile floats on the glass, not below it.** Laid
                        // over the whole screen it covered the continent
                        // toggle — the non-globe path, which is the one route
                        // through this screen that does not require aiming at
                        // a moving sphere, so burying it was the one thing
                        // this layout could not afford to do.
                        floatingTile
                    }
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

                // **The continent list belongs to the whole globe only.** Once
                // you have chosen a country the screen is about that country,
                // and a button offering to swap the sphere for a list of
                // continents is answering a question nobody is asking. The way
                // back takes the same slot at the region tier.
                if regionTier != nil {
                    globeBackButton
                } else if pickedCountry == nil {
                    listToggle
                }

                // Two lines, because the globe has two affordances and the
                // second one is the one that actually gets you somewhere. A
                // marker looks like a label, so nothing on screen said it was
                // tappable — the instruction only mentioned spinning.
                //
                // Swapped rather than removed while the list is up: the pair is
                // the same two lines tall either way, so the toggle does not
                // move under the finger that pressed it.
                // The globe's own instructions moved onto the glass; what is
                // left here speaks for the list, which has no HUD of its own.
                if showsList {
                    VStack(spacing: 5) {
                        Text("PICK A CONTINENT")
                            .font(DexFont.retro(11))
                            .tracking(3)
                            .foregroundStyle(lcd.accent)
                        Text("OR GO BACK TO THE GLOBE")
                            .font(DexFont.retro(10))
                            .tracking(2)
                            .foregroundStyle(lcd.subtext)
                    }
                    .multilineTextAlignment(.center)
                }
            }
            // **The glass runs to the chassis.** Twelve points of padding on a
            // screen this size is a visible frame around a picture that wants
            // to be the screen, and the sphere is the subject here.
            .padding(.vertical, 2)


        }
        .onAppear {
            model.autoSpins = !freezesGlobe
            #if DEBUG
            runProbeIfAsked()
            #endif
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
        // The scene is rebuilt from scratch on a mode, skin or texture change
        // (see the `.id` on `GlobeSceneView`), which takes the region map with
        // it. Re-laid here, so changing the screen colour while reading a map
        // does not empty it.
        .onChange(of: sceneKey) { _, _ in
            // After the update settles. `.onChange` here and `makeUIView` on
            // the `.id`-keyed representable run in the same SwiftUI pass and
            // their order is undocumented; re-laying first would parent the map
            // to the globe that is about to be replaced, and it would vanish
            // with nothing to put it back.
            Task { @MainActor in
                guard let country = regionTier,
                      let atlas = RegionAtlas.of(country) else { return }
                model.showRegions(atlas.map, image: atlas.base, backdrop: atlas.backdrop)
                if let stem = selectedRegion { model.popRegion(atlas.cutout(stem)) }
            }
        }
        .onChange(of: voiceOver) { _, on in if on { showsList = true } }
        .onDisappear {
            model.stop()
        }
    }

    #if DEBUG
    /// **A tap the simulator cannot send.** `-vinodexScreenshot globe@<lon>,<lat>`
    /// turns the globe to a coordinate, lets it arrive, then picks the centre
    /// of the viewport — which is that coordinate if, and only if, the whole
    /// chain agrees: the orientation maths, SceneKit's texture wrap, and the
    /// index raster. The HUD then names what it found, and a screenshot says
    /// whether it is right. It is the only way to test this without a finger.
    private func runProbeIfAsked() {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-vinodexScreenshot"),
              args.index(after: flag) < args.endIndex else { return }
        let name = args[args.index(after: flag)]
        guard name.hasPrefix("globe@") else { return }
        // A trailing `:double` sends two taps instead of one, through the same
        // entry point a finger uses — the point being to test the double-tap
        // detector and the overlay it raises, not to route around them. Driving
        // it from the simulator with two `click` events could not be made to
        // land inside the 0.35s window reliably, and a test that flakes on the
        // harness cannot tell you anything about the code.
        // `globe@12.5,42.5` turns there and taps once; `:double` taps twice
        // and `:double:tuscany` opens the overlay's card on that region too.
        // `:hold` turns there and taps nothing, which is the form that leaves
        // the screen ready for a real tap from the simulator — with any other
        // form the probe's own tap has already changed the state under it.
        var spec = name.dropFirst("globe@".count)
        var taps = 1
        if let colon = spec.firstIndex(of: ":") {
            let tail = spec[spec.index(after: colon)...].split(separator: ":")
            switch tail.first {
            case "hold": taps = 0
            case "double": taps = 2
            // Three: two to open the region tier, and a third that goes
            // through `tappedRegion` and picks whatever region is under the
            // middle of the glass — so the region hit test is exercised by the
            // same entry point a finger uses, not stubbed past with a stem.
            case "region": taps = 3
            default: break
            }
            // `:region:tuscany` names a stem too — the condition read `== 2`
            // and silently dropped it for the three-tap form.
            if taps >= 2, tail.count == 2 { probeStem = String(tail[1]) }
            spec = spec[..<colon]
        }
        let parts = spec.split(separator: ",")
        guard parts.count == 2, let lon = Double(parts[0]), let lat = Double(parts[1]) else { return }

        model.autoSpins = false
        model.focus(lon: lon, lat: lat, zoom: 1)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard globeSize != .zero else { return }
            let centre = CGPoint(x: globeSize.width / 2, y: globeSize.height / 2)
            for i in 0..<taps {
                // 120ms between the first two: they have to read as a double
                // tap. But the second starts a fly-to that `tick` eases over
                // frames, so a third tap 120ms later hit-tests whatever the
                // camera happened to be passing through — the region it named
                // was a function of frame timing. A third tap waits for the
                // globe to arrive, which is what makes this probe evidence
                // rather than a coin toss.
                if i == 1 { try? await Task.sleep(for: .milliseconds(120)) }
                if i == 2 { try? await Task.sleep(for: .seconds(2)) }
                tapped(at: centre)
            }
            // After the fly-to has settled, or the glass is still showing the
            // magnification it was leaving rather than the one it arrived at.
        }
    }
    #endif

    /// How close in time and place two taps must be to count as one double.
    /// 0.35s is the platform's own double-tap window; 44pt is the minimum
    /// target, so two taps inside it were aimed at the same thing.
    private static let doubleTapWindow: TimeInterval = 0.35
    private static let doubleTapSlop: CGFloat = 44

    /// Every tap on the sphere arrives here, and the second one of a pair is
    /// recognised by the clock rather than by a gesture.
    private func tapped(at point: CGPoint) {
        // At the region tier every tap is about regions, and a second tap on
        // the same one is a choice rather than a double tap to descend again.
        if regionTier != nil {
            tappedRegion(at: point)
            return
        }
        let now = Date()
        if let last = lastTap,
           now.timeIntervalSince(last.when) < Self.doubleTapWindow,
           hypot(point.x - last.point.x, point.y - last.point.y) < Self.doubleTapSlop {
            lastTap = nil
            openMap(at: point)
            return
        }
        lastTap = (point, now)
        toggle(at: point)
    }

    /// One tap: choose a country, or let go of the one already chosen.
    ///
    /// **Tapping the same country again releases it** and the globe returns
    /// to drifting, which is what makes the selection feel held rather than
    /// stuck — there is otherwise no way back to the turning globe except
    /// leaving the screen.
    private func toggle(at point: CGPoint) {
        // **Anywhere that is not a wine country takes you back out.** Ocean,
        // ice, or a country with no wine: the globe returns to its default
        // size and resumes drifting. Tapping the chosen country again used to
        // do this, which put the way out on the one target you were least
        // likely to aim at by accident — and made the selected country
        // behave differently from every other one on the sphere.
        guard let hit = model.country(at: point) else {
            release()
            return
        }
        pick(hit)
    }

    /// Back to the turning globe.
    private func release() {
        Haptics.select()
        pinchAnchor = nil
        fittedZoom = nil
        model.autoSpins = !freezesGlobe
        model.zoom = 1
        withAnimation(DexMotion.settle) { pickedCountry = nil }
    }

    /// Two taps: raise the country's region map **over** the globe.
    ///
    /// An overlay rather than a push, which is the artifact's own shape: the
    /// globe stays the screen you are on and stays visible behind, so
    /// descending a tier never feels like leaving.
    private func openMap(at point: CGPoint) {
        // **The country already chosen, not whatever is under the finger
        // now.** The first tap of the pair flies the globe to the country and
        // magnifies it, so by the second tap the geography beneath that screen
        // point has moved — re-picking there found the neighbour, or the sea.
        // The artifact has the same rule for the same reason: a second tap
        // acts on the selection, not on the pixel.
        guard let hit = pickedCountry ?? model.country(at: point) else { return }
        guard hit.isMapped, let atlas = RegionAtlas.of(hit.admin) else {
            // A double tap on a country with no map still selects it, rather
            // than doing nothing and reading as a dead control.
            pick(hit)
            return
        }
        Haptics.screenTap()
        // **Painted onto the sphere, in place.** Not a panel over the globe:
        // the country's regions appear where the country is, and moving in is
        // the same globe getting closer rather than a new screen arriving.
        model.showRegions(atlas.map, image: atlas.base, backdrop: atlas.backdrop)
        let b = atlas.map.subjectBounds
        let fit = GlobeModel.zoomToFit(
            west: b.west, east: b.east,
            south: b.south, north: b.north,
            // Tighter than the country tier: the regions are the subject now,
            // so less air around them.
            aspect: viewportAspect, margin: 1.02)
        fittedZoom = fit
        model.focus(lon: (b.west + b.east) / 2,
                    lat: (b.south + b.north) / 2,
                    zoom: fit)
        if let stem = probeStem { model.popRegion(atlas.cutout(stem)) }
        let found = probeStem.flatMap { entry(for: $0, in: atlas) }
        withAnimation(DexMotion.settle) {
            regionTier = hit.admin
            selectedRegion = probeStem
            selectedEntry = found
        }
    }

    /// The entry behind a painted region — the region itself, never an
    /// appellation inside it. `RegionMap.primaryEntryID` decides; this resolves.
    private func entry(for stem: String, in atlas: RegionAtlas) -> WineEntry? {
        let all = atlas.map.regionIDs(for: stem).compactMap { db.entry(id: $0) }
        guard let id = atlas.map.primaryEntryID(
            for: stem, names: all.map { (id: $0.id, name: $0.name) }
        ) else { return nil }
        return all.first { $0.id == id }
    }

    /// A tap while the regions are up: name one, or leave the tier.
    private func tappedRegion(at point: CGPoint) {
        guard let country = regionTier, let atlas = RegionAtlas.of(country),
              let art = model.regionArtPoint(at: point, artSize: atlas.baseSize),
              let stem = atlas.region(atX: art)
        else {
            // Off the country is the way out, matching the tier above: there
            // the sea returns the globe, here it returns the country.
            closeRegions()
            return
        }
        // The same region twice opens its entry — the tile is a confirmation
        // step, not a menu to be dismissed by hand.
        Haptics.select()
        model.popRegion(atlas.cutout(stem))
        let found = entry(for: stem, in: atlas)
        withAnimation(DexMotion.settle) {
            selectedRegion = stem
            selectedEntry = found
        }
    }

    /// Back up to the country tier: the patch comes off and the globe pulls
    /// out to the magnification that had the whole country on the glass.
    private func closeRegions() {
        Haptics.screenTap()
        model.hideRegions()
        // A pinch that is cancelled rather than ended never clears its anchor,
        // and a stale one makes the next pinch jump from the wrong base.
        pinchAnchor = nil
        fittedZoom = nil
        withAnimation(DexMotion.settle) {
            regionTier = nil
            selectedRegion = nil
            selectedEntry = nil
        }
        // **Back to the view `pick` established, not a second opinion of it.**
        // This re-framed on the manifest's country box while `pick` framed on
        // the globe raster's — two sources of truth for "where is Italy", so
        // coming back up a tier landed somewhere slightly else than you left.
        if let picked = pickedCountry, let tap = model.lastHit,
           let box = model.landmass(of: picked.id, near: tap.lon, near: tap.lat) {
            model.focus(lon: box.lon, lat: box.lat,
                        zoom: GlobeModel.zoomToFit(
                            west: box.west, east: box.east,
                            south: box.south, north: box.north,
                            aspect: viewportAspect))
        } else {
            model.zoom = 1
        }
    }

    /// A tap on the sphere. The first names the country; a second on the same
    /// one opens its region map, which is the prototype's two-tier gesture.
    ///
    /// A country with no painted map stops at being named — twenty-three of
    /// the thirty do. That is not a dead end so much as the honest state of
    /// the catalog, and the HUD says which it is.
    private func pick(_ hit: GlobeIndex.Country) {
        Haptics.select()
        // **The drift stops when a country is chosen** (maintainer order).
        // A globe that keeps turning under a selected country carries it off
        // the glass, and the second tap then lands on its neighbour. Spinning
        // resumes only by leaving and coming back, which is the one moment
        // nobody is aiming at anything.
        model.autoSpins = false
        withAnimation(DexMotion.settle) { pickedCountry = hit }
        // **The globe comes to the country.** Turning it until the country
        // faces the camera and moving in is what makes the first tap feel
        // like it did something, rather than only writing a name in the HUD —
        // and it puts the country under the finger for the second tap, which
        // near the limb is the difference between hitting Chile and hitting
        // Argentina. The drift stops while it flies; `focus` hands control
        // back when it arrives, and a drag takes it back sooner.
        if let tap = model.lastHit,
           let middle = model.landmass(of: hit.id, near: tap.lon, near: tap.lat) {
            // Zoomed to the country's own size rather than to a fixed step:
            // Chile and Luxembourg both fill the glass, which is what "tap a
            // country and look at it" has to mean if it is to mean anything.
            // **The middle of the box, not the middle of the mass.** The mean
            // of a country's cells is pulled toward whichever end is widest —
            // northern Italy is broader than the toe, so the mean sits about a
            // degree north of centre, and at this magnification that was
            // enough to push Sicily off the bottom of the glass while leaving
            // empty sky above the Alps. Measured, not guessed: the viewport
            // showed 36.1 to 48.9 for a country spanning 35.4 to 47.2.
            model.focus(lon: middle.lon, lat: middle.lat,
                        zoom: GlobeModel.zoomToFit(
                            west: middle.west, east: middle.east,
                            south: middle.south, north: middle.north,
                            aspect: viewportAspect))
        }
    }

    // MARK: The instrument panel

    /// Top row names the tier and the coordinate the camera is looking at;
    /// bottom row carries the two affordances the globe has. Both on a scrim,
    /// so they stay legible over ocean and over ice alike.
    /// **What floats on the glass.** One slot, whichever tier you are on: the
    /// country you tapped, or the region you tapped inside it. Both are the
    /// step between naming a place and leaving for its page, and both sit over
    /// the sphere rather than under it — laid out below the globe they pushed
    /// the continent toggle off the screen, and that toggle is the only route
    /// through here that does not require aiming at a moving target.
    @ViewBuilder
    private var floatingTile: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if let country = regionTier {
                if let stem = selectedRegion, let atlas = RegionAtlas.of(country) {
                    regionEntryCard(atlas, stem: stem)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            } else if let picked = pickedCountry {
                countryTile(picked)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        // As low as the glass goes: the HUD's bottom line is gone, so there is
        // nothing left down here to clear, and every point given back is map.
        .padding(.bottom, 4)
    }

    /// The country under the last tap, as a tile you can take. Naming a country
    /// in the HUD says what you hit; the tile is what makes the tap lead
    /// somewhere — the same shape the lists use.
    private func countryTile(_ picked: GlobeIndex.Country) -> some View {
        Button {
            Haptics.select()
            // **The catalog's spelling, not the atlas's.** Natural Earth
            // calls it "United States of America" and the catalog files it
            // under "USA"; it is the only one of the thirty that disagrees,
            // and the country page opened empty for it.
            onOpenCountry?(GlobeIndex.catalogName(for: picked.admin))
        } label: {
            HStack(spacing: 12) {
                // The catalog's spelling here too — the flag is looked up by
                // the same name the country page is, so "United States of
                // America" drew an empty swatch beside a correct label.
                FlagSwatch(db: db, country: GlobeIndex.catalogName(for: picked.admin),
                           width: 36, height: 23)
                Text(picked.label)
                    .font(DexFont.retro(12))
                    .foregroundStyle(lcd.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(lcd.subtext)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(lcd.accent.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
    }

    /// The way back up to the globe, in the slot the continent toggle uses at
    /// the tier above.
    private var globeBackButton: some View {
        Button {
            closeRegions()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                Text("BACK TO THE GLOBE")
                    .font(DexFont.retro(11))
                    .tracking(2)
            }
            .foregroundStyle(lcd.subtext)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(lcd.surfaceEdge, lineWidth: 2))
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        .padding(.horizontal, 12)
    }

    /// The entries behind the chosen region. Compact, because it sits over a
    /// globe the reader is still looking at — the full tile is what the entry
    /// page opens with.
    private func regionEntryCard(_ atlas: RegionAtlas, stem: String) -> some View {
        let entries = selectedEntry.map { [$0] } ?? []
        return VStack(alignment: .leading, spacing: 8) {
            // No name header: the tile under it already carries the region's
            // name, and printing it twice cost a line of map for nothing. The
            // empty case still needs words, so it keeps them.
            if entries.isEmpty {
                Text(atlas.map.displayName(stem))
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(lcd.accent)
                Text("NO CATALOG ENTRY HERE YET")
                    .font(DexFont.retro(10))
                    .tracking(1)
                    .foregroundStyle(lcd.subtext)
            } else {
                ForEach(entries) { entry in
                    EntryTileView(
                        entry: entry,
                        palette: db.palette,
                        locked: AccessStore.shared.isLocked(entry, in: db),
                        tried: BookmarkStore.shared.contains(entry.id, on: .tried)
                    ) {
                        onOpenEntry?(entry)
                    }
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.accent.opacity(0.5), lineWidth: 1))
    }

    /// **The readout, and nothing else** (0.9.56, maintainer order).
    ///
    /// The name line went because the floating tile already carries it, and
    /// the instruction line went because a sphere that turns under your finger
    /// and lights up when you tap it does not need to be captioned. What is
    /// left is where the camera is pointing, which is the one thing the
    /// picture cannot say for itself.
    private var globeHUD: some View {
        HStack {
            Spacer(minLength: 0)
            // Its own dark ground: the readout is drawn over whatever the
            // globe happens to be showing, and over a bright painted country
            // it was unreadable. A plate under it costs nothing and means the
            // one piece of text left on the glass can always be read.
            Text(facingText)
                .font(DexFont.mono(14))
                .foregroundStyle(lcd.subtext)
                .lineLimit(1)
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(lcd.page.opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(lcd.surfaceEdge.opacity(0.7), lineWidth: 1)
                )
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }


    /// Hemispheres rather than signs, and one decimal: this drifts as the
    /// globe turns, and a second decimal would be a number nobody can read
    /// changing faster than anyone can read it.
    private var facingText: String {
        let f = model.facing
        return String(format: "%.1f°%@ %.1f°%@",
                      abs(f.lat), f.lat >= 0 ? "N" : "S",
                      abs(f.lon), f.lon >= 0 ? "E" : "W")
    }

    /// A hairline at 7 percent every four points. Not `ScanlineOverlay`,
    /// which lays 50 percent black over everything — right for the LCD and
    /// far too heavy on a sphere that is already lit from three sides.
    private var globeScanlines: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(.black.opacity(0.07))
                )
                y += 4
            }
        }
        .allowsHitTesting(false)
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
                    // its one database read, which M27 has since moved into
                    // `GlobeModel.init(db:)`).
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
                //
                // Handed this screen's database rather than letting the well
                // default to `.shared`, so an injected fixture reaches the
                // visual too (AUDIT **M27**) — the same call shape
                // `ContinentScreen` uses for its hero.
                if let entry = marker.entry {
                    EntryIconWell(db: db, entry: .continent(entry), size: 44, cornerRadius: 8)
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
    //
    // **The floating marker plates are gone (0.9.55).** Six SwiftUI
    // buttons projected onto the sphere each frame were how a place was
    // reached while the globe could not be asked what lay under a finger.
    // It can now — see `GlobeModel.country(at:)` — so the plates became
    // furniture standing in front of the thing they labelled, and the
    // sphere answers for itself.
    //
    // `model.markers` survives and still feeds the continent LIST below:
    // it is the projection that is retired, not the roster.

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

    /// **The region map does not move** (0.9.56, maintainer order). A country
    /// is flown to and framed to fit; dragging from there only ever slid the
    /// subject off the glass, and at this magnification a small drag throws it
    /// a long way. The tier above keeps its drag — the whole globe is a thing
    /// you turn.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            // `value.time` is threaded through so the throw that carries the
            // globe after the finger lifts is measured in points per *second*
            // rather than points per touch-event — those are not the same
            // number on a 120Hz panel. (AUDIT M11)
            .onChanged { value in
                guard canDragGlobe else { return }
                model.drag(translation: value.translation, at: value.time)
            }
            // **`endDrag` is never skipped.** Guarding it too left `dragging`
            // true whenever a touch satisfied both the 4pt drag minimum and the
            // tap recogniser and the tap opened the region tier mid-gesture —
            // and `tick` damps velocity only while `!dragging`, so the map slid
            // away forever. At the region tier this is a no-op anyway: nothing
            // fed it any velocity.
            .onEnded { _ in model.endDrag() }
    }
}

// MARK: - Scene

/// Hosts the `SCNView`. SceneKit is UIKit-only, so this is the bridge.
/// What the sphere is painted with (0.9.55).
enum GlobeTexture {
    /// The neon-green coastline that has always shipped.
    case coastline
    /// The thirty wine countries, each in its own colour — a test behind
    /// `AppSettings.wineGlobe`. The picture only: tapping the sphere to pick
    /// a country is the prototype's real interaction and stays upstream until
    /// someone measures per-pixel un-projection on a phone (AUDIT §5).
    case wine

    var stem: String { self == .wine ? "globe-wine" : "updatedglobemap" }
    var ext: String { self == .wine ? "png" : "jpg" }
}

struct GlobeSceneView: UIViewRepresentable {
    let model: GlobeModel
    var isLight: Bool
    var tint: UIColor
    /// LIGHT mode's inverted-colour globe (0.6.4, F1).
    var invertsTexture: Bool = false
    /// Which texture the sphere wears (0.9.55) — see `AppSettings.wineGlobe`.
    var texture: GlobeTexture = .coastline

    /// The model itself, so `dismantleUIView` — which is static and is handed
    /// nothing but the view and the coordinator — can reach it. (AUDIT **L10**)
    func makeCoordinator() -> GlobeModel { model }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling2X
        view.isUserInteractionEnabled = false   // gestures are handled in SwiftUI
        view.scene = model.buildScene(isLight: isLight, tint: tint,
                                      invertsTexture: invertsTexture, texture: texture)
        view.pointOfView = model.cameraNode
        model.attach(to: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}

    /// Teardown that does not depend on `onDisappear` running (AUDIT **L10**).
    ///
    /// `RetroGlobeScreen.onDisappear` calls `stop()`, and for the ordinary
    /// pop that is enough — but it is not the only way this view dies. The
    /// globe is mounted a second time inside the scanner flow, and the whole
    /// root tree is rebuilt by `.id(…)` on a text-size or UI-scale change. A
    /// display link that survives either of those goes on firing at 60Hz for
    /// the rest of the process.
    ///
    /// `detach(from:)` rather than `stop()`, because the `.id("\(lcd)|\(skin)")`
    /// on this view means a mode or skin switch rebuilds the representable —
    /// and SwiftUI is free to make the replacement before dismantling the one
    /// it replaces. An unconditional `stop()` here would then kill the link the
    /// new view had just started, freezing the globe the first time the user
    /// changed skin. Matching on the view makes the order irrelevant.
    static func dismantleUIView(_ view: SCNView, coordinator: GlobeModel) {
        coordinator.detach(from: view)
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
    private static let autoSpinRate: Double = -0.0016 * dampingReferenceRate
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
    static let cameraDistance: Double = 2.95
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
    var markers: [Marker]

    /// The model is not a `View`, so no SwiftUI environment can reach it and
    /// `markers` cannot be a stored-property initialiser reading `.shared`.
    /// Taking the database here is what makes the globe injectable at all.
    /// (AUDIT **M27**)
    ///
    /// Each continent is looked up exactly once and the entry is kept on the
    /// marker, so the plate's colour and the list row's hero icon (0.6.8, C1)
    /// are the same read rather than two.
    init(db: WineDatabase = .shared) {
        markers = Continent.allCases.map {
            let entry = db.continentEntry($0)
            return Marker(
                continent: $0,
                position: .zero,
                visible: false,
                color: Color(dexHex: entry?.common.color ?? "#4ADE80"),
                entry: entry
            )
        }
    }

    var viewportSize: CGSize = .zero

    /// False until the first projection pass has settled on screen (0.8.92,
    /// item 10). The marker layer reads it to decide whether visibility
    /// changes animate: the pass that *introduces* the plates must not — the
    /// markers should simply be on the globe when the screen arrives — while
    /// every later flip (rotation carrying a plate past the limb) keeps its
    /// fade. Flipped by the *second* pass rather than the first, because the
    /// flag and the visibilities land in the same SwiftUI transaction: a flag
    /// set true in the introducing pass would animate exactly the change it
    /// exists to suppress.
    private(set) var markersSettled = false
    private var hasProjectedOnce = false

    /// Whether the globe drifts on its own. Off under Reduce Motion and under
    /// VoiceOver — see `RetroGlobeScreen.freezesGlobe`. (AUDIT M18, M20)
    var autoSpins = true

    private(set) var cameraNode = SCNNode()
    private var globeNode = SCNNode()

    /// The wine-country index and its raster, loaded once. Nil only when the
    /// bundle is missing them, in which case tapping the sphere does nothing
    /// and the globe behaves exactly as it did before it could be tapped.
    private static let atlas: (index: GlobeIndex, cells: [UInt8], w: Int, h: Int)? = {
        guard let metaURL = Bundle.module.url(forResource: "globe-meta", withExtension: "json",
                                              subdirectory: "Maps"),
              let rasterURL = Bundle.module.url(forResource: "globe-index", withExtension: "png",
                                                subdirectory: "Maps"),
              let meta = try? Data(contentsOf: metaURL),
              let index = try? GlobeIndex(meta: meta),
              let image = UIImage(contentsOfFile: rasterURL.path),
              let cg = image.cgImage
        else { return nil }
        let w = cg.width, h = cg.height
        var bytes = [UInt8](repeating: 0, count: w * h)
        bytes.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(
                data: buf.baseAddress, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return }
            // Data, not a picture — the bytes have to survive the draw.
            ctx.interpolationQuality = .none
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return (index, bytes, w, h)
    }()

    /// Where a country sits **near a given point** — the mean of its cells
    /// within a window around the tap.
    ///
    /// **Not the whole country's mean**, which is wrong for any state with
    /// scattered territory and silently so. Natural Earth's France includes
    /// Guiana, Réunion and New Caledonia, and averaging them puts "France"
    /// at 41.5N 3.2W — in the sea off Barcelona. Tapping Bordeaux would have
    /// flown the globe to the Mediterranean.
    ///
    /// A window around the finger instead: it finds the landmass that was
    /// actually tapped and ignores the far-flung rest, which is both correct
    /// and what someone pointing at a country means by it. Longitude is
    /// averaged as a unit vector, because a window can straddle the date
    /// line and averaging +179 with -179 as arithmetic lands in Africa.
    func landmass(of id: Int, near lon: Double, near lat: Double)
        -> (lon: Double, lat: Double,
            west: Double, east: Double, south: Double, north: Double)? {
        guard let atlas = Self.atlas else { return nil }
        let span = 25.0
        let cells = GlobeIndex.cell(lon: lon, lat: lat, width: atlas.w, height: atlas.h)
        let dx = Int(span / 360 * Double(atlas.w))
        let dy = Int(span / 180 * Double(atlas.h))
        var sx = 0.0, sy = 0.0, slat = 0.0, n = 0.0
        // Every matching cell's position, because the *extremes* are exactly
        // what an outlying island gives you and the box has to ignore them.
        var lats: [Double] = [], dLons: [Double] = []
        for y in max(0, cells.y - dy)...min(atlas.h - 1, cells.y + dy) {
            for wx in (cells.x - dx)...(cells.x + dx) {
                // Wrapped, so a window over the Pacific still sees both sides.
                let x = ((wx % atlas.w) + atlas.w) % atlas.w
                // `clamping`, not the trapping init: `id` comes off decoded
                // JSON, and `RegionAtlas` already uses `clamping` at both of
                // its analogous sites. Safe by data today; a crash tomorrow.
                guard atlas.cells[y * atlas.w + x] == UInt8(clamping: id) else { continue }
                let cl = (Double(x) / Double(atlas.w)) * 360 - 180
                let la = 90 - (Double(y) / Double(atlas.h)) * 180
                sx += cos(cl * .pi / 180)
                sy += sin(cl * .pi / 180)
                slat += la
                n += 1
                lats.append(la)
                // Longitude spread measured against the tap, so a country
                // straddling the date line does not read as 360 degrees wide.
                var d = cl - lon
                if d > 180 { d -= 360 } else if d < -180 { d += 360 }
                dLons.append(d)
            }
        }
        guard n > 0 else { return nil }

        // **The box that holds the country, not the one that holds its
        // furthest island.** Portugal owns the Azores and Madeira, a thousand
        // miles out into the Atlantic; the outright minimum and maximum put
        // the centre of the view in open ocean with the mainland pressed
        // against the edge and a great deal of empty sea in frame.
        //
        // Trimming a fixed percentage does not separate them — the Azores and
        // Madeira are about three and a half per cent of Portugal's painted
        // cells, and a trim deep enough to lose them takes the southern end of
        // Chile with it. What actually distinguishes the two cases is the
        // *gap*: Sicily lies a few degrees off Italy with the Tyrrhenian in
        // between, while the Azores sit across a thousand miles of nothing. So
        // look for open water wide enough that what is beyond it is a separate
        // thing, and stop there.
        let midLat = slat / n
        let cosLat = cos(midLat * .pi / 180)
        var far = zip(lats, dLons)
            .map { hypot($0 - midLat, $1 * cosLat) }
            .sorted()
        let median = far[far.count / 2]
        // A gap has to be both absolutely wide and wide relative to the
        // country, or a small nation reads as its own outlier.
        let gapLimit = max(3.0, median * 1.5)
        var keep = far.count
        if far.count > 8 {
            var i = far.count - 1
            while i > far.count / 2 {
                if far[i] - far[i - 1] > gapLimit { keep = i; break }
                i -= 1
            }
        }
        let cutoff = far[max(0, keep - 1)]

        var minLat = 90.0, maxLat = -90.0, minDLon = 0.0, maxDLon = 0.0
        for (la, d) in zip(lats, dLons) where hypot(la - midLat, d * cosLat) <= cutoff {
            minLat = min(minLat, la); maxLat = max(maxLat, la)
            minDLon = min(minDLon, d); maxDLon = max(maxDLon, d)
        }
        guard minLat <= maxLat else { return nil }

        return (lon: lon + (minDLon + maxDLon) / 2,
                lat: (minLat + maxLat) / 2,
                west: lon + minDLon, east: lon + maxDLon,
                south: minLat, north: maxLat)
    }

    /// The magnification that makes a country of `span` degrees fill the
    /// glass. A sphere at 1x shows about 140 usable degrees before the limb
    /// curls away, so this is that over the span, kept inside bounds a globe
    /// still reads as a globe at.
    /// The furthest in the lens goes, and the ceiling a pinch runs to.
    static let maxZoom: Double = 12

    /// **Magnification that actually fits the country on the glass.**
    ///
    /// The old version divided a constant by the larger of the two spans in
    /// degrees, which crops for two independent reasons. A degree of longitude
    /// is not a degree of arc — at 45 degrees north it is only about seven
    /// tenths of one — so a wide country read as wider than it is and a tall
    /// one as narrower. And the viewport is portrait, so the horizontal field
    /// is the *narrow* one: a country that fits vertically can still have its
    /// coasts cut off. Chile was the case that showed both at once.
    ///
    /// So: measure both extents as real arc, ask what angle each subtends from
    /// the camera, and take whichever needs the wider lens once the viewport's
    /// own aspect is accounted for.
    static func zoomToFit(
        west: Double, east: Double, south: Double, north: Double,
        aspect: Double, margin: Double = 1.28
    ) -> Double {
        let midLat = (south + north) / 2 * .pi / 180
        // Longitude converges toward the poles; latitude does not.
        let lonArc = abs(east - west) * cos(midLat)
        let latArc = abs(north - south)

        // How wide a lens an arc of this size needs, from where the camera is.
        func fieldFor(arc: Double) -> Double {
            let half = min(max(arc, 0.5), 170) / 2 * .pi / 180
            let across = Self.globeRadius * sin(half)
            let depth = Self.cameraDistance - Self.globeRadius * cos(half)
            guard depth > 0.01 else { return Self.baseFieldOfView }
            return 2 * atan(across / depth) * 180 / .pi
        }

        let vertical = fieldFor(arc: latArc)
        // The horizontal field is narrower than the vertical one on a portrait
        // viewport, so a horizontal extent needs a *larger* vertical field to
        // be contained: tan(h/2) = aspect * tan(v/2), inverted.
        let horizontal = fieldFor(arc: lonArc)
        let neededForWidth = 2 * atan(tan(horizontal / 2 * .pi / 180)
                                      / max(aspect, 0.05)) * 180 / .pi

        let needed = max(vertical, neededForWidth) * margin
        guard needed > 0.01 else { return 1 }
        return min(Self.maxZoom, max(1, Self.baseFieldOfView / needed))
    }

    /// Turn the globe until a coordinate faces the camera, and move in.
    ///
    /// Eased over frames in `tick` rather than set outright: the globe is a
    /// physical thing on this device and a sphere that teleports reads as a
    /// glitch rather than as a movement.
    func focus(lon: Double, lat: Double, zoom target: Double) {
        let wantYaw = -lon * .pi / 180
        // The shortest way round, so turning from Chile to New Zealand does
        // not unwind most of the way through Africa first.
        var delta = (wantYaw - yaw).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi } else if delta < -.pi { delta += 2 * .pi }
        focusYaw = yaw + delta
        focusPitch = min(max(lat * .pi / 180, -Self.maxPitch), Self.maxPitch)
        zoom = target
    }

    /// Drop the fly-to's hold on magnification, leaving its turn alone.
    /// Where the last successful pick landed, so the focus can centre the
    /// landmass that was tapped rather than the country's scattered mean.
    private(set) var lastHit: (lon: Double, lat: Double)?

    private var focusYaw: Double?
    private var focusPitch: Double?

    /// The country under a point on screen, or nil for sea, ice, or a country
    /// that makes no wine.
    ///
    /// **SceneKit answers the geometry, not us.** `hitTest` fires one ray when
    /// a finger lands and hands back where it met the sphere, in the sphere's
    /// own local space — already undoing whatever yaw and pitch the globe is
    /// carrying. Rolling our own ray-sphere intersection would mean a second
    /// opinion about the camera, the FOV and the orientation, and the first
    /// one to drift would do it silently.
    ///
    /// AUDIT §5's worry was per-pixel un-projection at 60fps. This is one ray
    /// per tap and one array read, which is a different thing entirely.
    func country(at point: CGPoint) -> GlobeIndex.Country? {
        guard let atlas = Self.atlas,
              let view = sceneView,
              // **`.all`, not `.closest`.** The scene carries a wireframe
              // shell a shade larger than the sphere, so the closest thing a
              // ray meets is the wire — and with `.closest` the globe itself
              // never appeared in the results at all. The tap did nothing,
              // silently, which is exactly the shape of bug a hit test hides.
              let hit = view.hitTest(point, options: [
                  .boundingBoxOnly: false,
                  .searchMode: SCNHitTestSearchMode.all.rawValue,
              ]).first(where: { $0.node === globeNode })
        else { return nil }

        // **The texture coordinate, from SceneKit itself.** Inverting
        // `latLngToVector3` gave a lon/lat that was self-consistent and still
        // wrong, because what matters is not where the point is in the
        // sphere's own maths but which texel of the wrapped image sits there
        // — and the index raster is aligned to the texture, not to the
        // marker formula. SceneKit already computed that UV to draw the
        // pixel; asking for it is the one answer that cannot disagree with
        // what is on screen.
        let uv = hit.textureCoordinates(withMappingChannel: 0)
        let u = Double(uv.x) - floor(Double(uv.x))          // wrapped, not clamped
        // v rises from the top of the raster, whose first row is the north
        // pole — the same sense SceneKit hands back. It was flipped here for
        // one commit, which made taps work while the globe's pitch was ALSO
        // inverted: two wrongs agreeing. With the pitch corrected the flip
        // had to go, and the pair is now right rather than merely consistent.
        let v = min(max(Double(uv.y), 0), 1)

        let x = min(atlas.w - 1, Int(u * Double(atlas.w)))
        let y = min(atlas.h - 1, Int(v * Double(atlas.h)))
        let value = Int(atlas.cells[y * atlas.w + x])

        // Degrees for the HUD and the fly-to, read off the same UV so the
        // readout can never name one place while the tap resolves another.
        lastHit = (lon: u * 360 - 180, lat: 90 - v * 180)

        guard value != 0, let found = atlas.index.country(id: value) else { return nil }
        return found
    }
    // MARK: - The region tier, painted on the sphere

    /// The patch carrying a country's painted regions, or nil at the globe
    /// tier. A child of `globeNode`, so it turns with the surface it sits on
    /// rather than needing its own orientation kept in step.
    private var regionNode: SCNNode?

    /// Whether a country's regions are currently laid on the globe.
    var showsRegions: Bool { regionNode != nil }

    /// **The region map goes ON the globe, not over it** (0.9.55, maintainer
    /// order, after the prototype recording).
    ///
    /// A panel of Italy floating above the sphere is a second screen wearing
    /// the first as wallpaper; painting the regions into the place Italy
    /// actually occupies keeps one continuous world, and zooming in is then
    /// the same gesture it was a tier ago rather than a new kind of thing.
    ///
    /// Built as a lat/lon grid rather than by compositing into the globe's own
    /// texture: at 2048x1024 a country the size of Italy owns about 68 texels
    /// across, which is a coloured smudge at the magnification this tier uses.
    /// The patch carries the painted art at its own resolution instead, and
    /// costs one small geometry.
    /// `backdrop` is the opaque world the region art is drawn over. A
    /// parameter rather than a property: it was a property for one build, and
    /// `showRegions` opens by calling `hideRegions`, which cleared it — so the
    /// value the caller had just set was gone by the line that read it, and the
    /// underlay silently never drew. Passed in, there is no order to get wrong.
    func showRegions(_ map: RegionMap, image: UIImage, backdrop: UIImage?) {
        hideRegions()
        let b = map.subjectBounds
        // Half a degree of margin: the subject rect is the country's own
        // bounding box, and a patch cut exactly to it clips the coastline it
        // is there to draw.
        let pad = 0.5
        let west = b.west - pad, east = b.east + pad
        let north = b.north + pad, south = b.south - pad

        // Enough divisions that the patch follows the curve without a visible
        // facet at this tier's magnification, and few enough to stay free.

        // **The map's own backdrop goes under it.** The globe paints Italy in
        // one flat bright colour at 2048x1024 — cells 14km across at this
        // latitude — while the painted coastline is finer, so the globe's
        // blockier Italy overhung the map and showed as a rim of its own
        // colour: green around Italy, purple around Spain, tan around France.
        // It read as the map bleeding onto its neighbours; it was the globe
        // showing around the map. The backdrop is opaque and shares the art's
        // canvas, projection and origin exactly, so laid underneath it there is
        // no seam to mis-register and nothing of the globe left to show.
        if let world = backdrop {
            let underGeometry = patchGeometry(map: map, bounds: map.canvasBounds, lift: 1.002)
            let under = SCNMaterial()
            under.diffuse.contents = world
            under.lightingModel = .constant
            under.isDoubleSided = true
            under.diffuse.magnificationFilter = .nearest
            under.diffuse.minificationFilter = .nearest
            under.diffuse.mipFilter = .none
            under.diffuse.wrapS = .clamp
            under.diffuse.wrapT = .clamp
            underGeometry.materials = [under]
            let underNode = SCNNode(geometry: underGeometry)
            underNode.renderingOrder = 9
            globeNode.addChildNode(underNode)
            regionUnderNode = underNode
        }

        let geometry = patchGeometry(map: map, bounds: (west, east, south, north), lift: 1.004)

        let material = SCNMaterial()
        material.diffuse.contents = image
        // Flat: the globe's own rig shades the sphere for depth, and the same
        // shading over the region colours turns a palette chosen for contrast
        // into a gradient that hides the smallest regions at the limb.
        material.lightingModel = .constant
        // **Nearest in every direction, and no mipmaps.** The art is clean —
        // zero partial-alpha pixels, zero surviving key colour — so the halo
        // around every painted country came entirely from filtering: an opaque
        // region colour averaged with the transparent black beside it gives a
        // half-strength version of that colour, which then draws OVER the
        // neighbouring country. That is why Spain bled purple and Italy bled
        // green: each country was haloed in its own coastal region's colour.
        // Mipmaps do the same averaging one level down, so they go too.
        material.diffuse.magnificationFilter = .nearest
        material.diffuse.minificationFilter = .nearest
        material.diffuse.mipFilter = .none
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.renderingOrder = 10
        globeNode.addChildNode(node)
        regionNode = node

        // **The graticule comes off while a map is up.** The wire shell sits at
        // radius + 0.04 and the map at radius * 1.004, so the grid is nearer
        // the camera and rules lines straight across the regions. It is scenery
        // for a spinning globe; over a map of Tuscany it is just lines on the
        // subject.
        wireNode.isHidden = true

        // **The chosen region rides a copy of the mesh, further out.** Same
        // grid, same texel under every vertex, just a larger radius — so it
        // lifts off the country without any chance of sliding out of register
        // with the shape it was cut from. A drop shadow would have been the
        // flat-map way to say "raised"; on a sphere the honest way is to
        // actually raise it.
        let popGeometry = patchGeometry(map: map, bounds: (west, east, south, north),
                                        lift: Self.regionLift)
        let pop = SCNMaterial()
        pop.lightingModel = .constant
        pop.isDoubleSided = true
        pop.diffuse.magnificationFilter = .nearest
        pop.diffuse.minificationFilter = .nearest
        pop.diffuse.mipFilter = .none
        pop.diffuse.wrapS = .clamp
        pop.diffuse.wrapT = .clamp
        pop.diffuse.contents = UIColor.clear
        popGeometry.materials = [pop]
        let popNode = SCNNode(geometry: popGeometry)
        popNode.renderingOrder = 11
        globeNode.addChildNode(popNode)
        regionPopNode = popNode
    }

    /// How far a tapped region stands off the surface, as a fraction of the
    /// globe's radius. Enough to read as lifted at the magnification this tier
    /// uses, and not so much that it floats free of its own outline.
    private static let regionLift: Double = 1.022

    /// Raise one region off the country, or put them all back down.
    func popRegion(_ cutout: UIImage?) {
        regionPopNode?.geometry?.firstMaterial?.diffuse.contents
            = cutout ?? UIColor.clear
    }

    private var regionPopNode: SCNNode?
    private var regionUnderNode: SCNNode?

    /// The lat/lon mesh the region tier is drawn on, at a given radius.
    private func patchGeometry(
        map: RegionMap,
        bounds b: (west: Double, east: Double, south: Double, north: Double),
        lift: Double
    ) -> SCNGeometry {
        // Enough divisions that the patch follows the curve without a visible
        // facet at this tier's magnification, and few enough to stay free.
        let cols = 72, rows = 72
        var verts: [SCNVector3] = [], norms: [SCNVector3] = [], uvs: [CGPoint] = []
        verts.reserveCapacity((cols + 1) * (rows + 1))
        let radius = Self.globeRadius * lift

        for j in 0...rows {
            let lat = b.north + (b.south - b.north) * Double(j) / Double(rows)
            for i in 0...cols {
                let lon = b.west + (b.east - b.west) * Double(i) / Double(cols)
                // The marker projection, with the same longitude correction —
                // this has to sit exactly where the globe's own texture draws
                // that coordinate, and that offset is the difference between
                // the ported formula and how SceneKit wraps a sphere.
                let p = Self.latLngToVector3(lat: lat,
                                             lng: lon + Self.markerLongitudeOffset,
                                             radius: radius)
                verts.append(p)
                let unit = simd_normalize(SIMD3<Float>(p.x, p.y, p.z))
                norms.append(SCNVector3(unit.x, unit.y, unit.z))
                // The manifest's own projection decides which texel belongs at
                // this corner — contract 2, forwards.
                let c = map.canvas(atLon: lon, lat: lat)
                uvs.append(CGPoint(x: c.x / Double(map.canvas.w),
                                   y: c.y / Double(map.canvas.h)))
            }
        }

        var indices: [Int32] = []
        indices.reserveCapacity(cols * rows * 6)
        for j in 0..<rows {
            for i in 0..<cols {
                let a = Int32(j * (cols + 1) + i)
                let bRight = a + 1
                let c = a + Int32(cols + 1)
                let d = c + 1
                indices.append(contentsOf: [a, c, bRight, bRight, c, d])
            }
        }

        return SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: verts),
                SCNGeometrySource(normals: norms),
                SCNGeometrySource(textureCoordinates: uvs),
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
    }

    func hideRegions() {
        wireNode.isHidden = false
        regionUnderNode?.removeFromParentNode()
        regionUnderNode = nil
        regionNode?.removeFromParentNode()
        regionNode = nil
        regionPopNode?.removeFromParentNode()
        regionPopNode = nil
    }

    /// Where a tap landed on the region patch, in the art's own pixel space,
    /// or nil if the tap missed the patch.
    ///
    /// Asks SceneKit for the texture coordinate, exactly as the country hit
    /// test does, rather than un-projecting the ray by hand: the one answer
    /// that cannot disagree with what is drawn.
    func regionArtPoint(at point: CGPoint, artSize: CGSize) -> CGPoint? {
        guard let view = sceneView, let node = regionNode,
              let hit = view.hitTest(point, options: [
                  .boundingBoxOnly: false,
                  .searchMode: SCNHitTestSearchMode.all.rawValue,
              // **The map, and only the map.** The raised region rides a copy
              // of this mesh 2.2% further out, so a ray meets it at a
              // different coordinate than it meets the map — and being nearer
              // the camera it was hit FIRST, so every tap resolved against the
              // raised shell and landed a region or two off. It was answering
              // UMBRIA for the middle of LAZIO.
              ]).first(where: { $0.node === node })
        else { return nil }
        let uv = hit.textureCoordinates(withMappingChannel: 0)
        return CGPoint(x: CGFloat(uv.x) * artSize.width,
                       y: CGFloat(uv.y) * artSize.height)
    }

    private var wireNode = SCNNode()
    private weak var sceneView: SCNView?
    private var displayLink: CADisplayLink?

    private var yaw: Double = 0
    private var pitch: Double = 0

    /// The coordinate at the centre of the sphere — what the camera is
    /// looking straight at. Yaw spins about the pole so it reads as
    /// longitude; pitch tips the globe so it reads as latitude, negated
    /// because tipping the globe *down* brings the northern hemisphere up.
    ///
    /// The globe drifts at rest, so this changes continuously. That is the
    /// point: it is a position readout on an instrument, not a label.
    var facing: (lon: Double, lat: Double) {
        var lon = -yaw * 180 / .pi
        lon = lon.truncatingRemainder(dividingBy: 360)
        if lon > 180 { lon -= 360 } else if lon < -180 { lon += 360 }
        // **Positive pitch faces north.** It was negated here and negated
        // again in `focus`, so the two agreed with each other and disagreed
        // with the sphere: asking the globe for 60N turned it to 60S and the
        // readout confidently said 60N. Two errors cancelling is why a probe
        // that fed a coordinate through `focus` and read it back here could
        // never have caught it — only looking at the picture did.
        return (lon, pitch * 180 / .pi)
    }

    /// Magnification — a **lens**, not a dolly.
    ///
    /// Moving the camera in was the obvious reading of "zoom" and it is wrong
    /// on a sphere: the globe's radius is 1.05 and the camera sits at 3.45, so
    /// anything past about 3x puts the camera *inside* the globe and the
    /// screen fills with the far wall. Narrowing the field of view instead
    /// magnifies from where it stands — the geometry, the three lights and
    /// the marker projection all carry on exactly as they were, and there is
    /// no distance at which it breaks.
    var zoom: Double = 1 {
        didSet {
            guard zoom != oldValue else { return }
            cameraNode.camera?.fieldOfView = CGFloat(Self.baseFieldOfView / zoom)
        }
    }

    static let baseFieldOfView: Double = 50
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
    func buildScene(
        isLight: Bool,
        tint: UIColor = .white,
        invertsTexture: Bool = false,
        texture: GlobeTexture = .coastline
    ) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        // Textured globe.
        let sphere = SCNSphere(radius: CGFloat(Self.globeRadius))
        sphere.segmentCount = 96
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        if let url = DexResources.url(named: texture.stem, ext: texture.ext, in: .maps)
            ?? DexResources.url(named: GlobeTexture.coastline.stem,
                                ext: GlobeTexture.coastline.ext, in: .maps),
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
            // **The wine globe keeps its own palette.** `colorized` reduces to
            // luma and multiplies by the screen tint, which is right for the
            // coastline texture — one neon line on black, whose colour is the
            // mode's to choose. It is exactly wrong here: thirty countries
            // authored in thirty distinct colours all collapse to the same
            // green, and "which countries can I tap" becomes unanswerable.
            // The wine texture is a map, not a monochrome overlay, so it wears
            // the colours it was drawn in.
            if texture == .wine {
                material.diffuse.contents = image
            } else {
                let base = invertsTexture ? Self.inverted(image) ?? image : image
                material.diffuse.contents = Self.colorized(base, with: tint) ?? base
            }
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
        // The wine map carries its own brightness; the glow that makes a
        // single neon coastline readable only washes thirty colours together.
        material.emission.intensity = texture == .wine ? 0.04 : (isLight ? 0.08 : 0.3)
        sphere.materials = [material]
        globeNode = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(globeNode)
        // **The region patch was parented to the globe that just went.**
        // `buildScene` runs again whenever the screen mode, skin or texture
        // changes, and it builds a fresh `globeNode` — so the map, its backdrop
        // and the raised region are all detached, while these references went on
        // claiming they were on screen. The screen watches the same key and
        // lays the map down again; this makes the model honest in the meantime.
        regionNode = nil
        regionUnderNode = nil
        regionPopNode = nil

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
        camera.fieldOfView = CGFloat(Self.baseFieldOfView / zoom)
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
        // The scene exists and points where it will point; if the viewport is
        // already known this is the moment the markers can be placed, before
        // the first frame rather than a quarter-second after it (0.8.92, item 10).
        projectNow()
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

    /// Idempotent — `attach(to:)` calls it on every rebuild of the
    /// representable, and the `.id("\(lcd)|\(skin)")` on `GlobeSceneView` makes
    /// that once per LCD-mode or skin change. This is also the restart half of
    /// **L10**: `detach(from:)` clears `displayLink`, so the guard below lets
    /// the next `attach` start a fresh loop rather than leaving a dead globe.
    private func start() {
        guard displayLink == nil else { return }
        let proxy = DisplayLinkProxy { [weak self] in
            guard let self else { return false }
            self.tick()
            return true
        }
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire))
        proxy.link = link
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

    /// Stops the loop, but only if `view` is still the view this model is
    /// driving — see the note on `GlobeSceneView.dismantleUIView` (AUDIT
    /// **L10**). A stale dismantle arriving after the replacement has attached
    /// names a view we no longer hold, and is ignored.
    func detach(from view: SCNView) {
        guard sceneView === view else { return }
        sceneView = nil
        stop()
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

        if let ty = focusYaw, let tp = focusPitch {
            // Ease toward the chosen country, and hand control back the
            // moment it is close enough that another frame would not show.
            let k = min(1, dt * 6)
            yaw += (ty - yaw) * k
            pitch += (tp - pitch) * k
            if abs(ty - yaw) < 0.002 && abs(tp - pitch) < 0.002 {
                yaw = ty; pitch = tp
                focusYaw = nil; focusPitch = nil
            }
        } else {
            yaw += (velocityYaw + (autoSpins ? Self.autoSpinRate : 0)) * dt
            pitch = min(max(pitch + velocityPitch * dt, -Self.maxPitch), Self.maxPitch)
        }

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

    /// Projects immediately instead of waiting out the 15Hz clock (0.8.92,
    /// item 10). Called when the viewport is first known and when the scene
    /// attaches — whichever lands second does the real work; the guards make
    /// the earlier call a no-op. Without this the markers were absent for up
    /// to `markerInterval` and then faded in, which read as a fly-in nobody
    /// designed.
    func projectNow() {
        markerClock = 0
        updateMarkers()
    }

    private func updateMarkers() {
        guard let view = sceneView, viewportSize.width > 0 else { return }
        defer {
            if hasProjectedOnce { markersSettled = true } else { hasProjectedOnce = true }
        }

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

        // A finger outranks the animation: dragging mid-flight should take
        // the globe, not fight it.
        focusYaw = nil
        focusPitch = nil
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
///
/// It also takes the link off the run loop when the model it was driving has
/// gone (AUDIT **L10**). A `CADisplayLink` retains its target, so this proxy
/// outlives the `GlobeModel` by design — the model is held weakly, and nothing
/// else is in a position to notice that the frames now go nowhere. `deinit` on
/// the model cannot do it either: the link is what keeps the proxy alive, not
/// the other way round. This is the last-resort net; the deterministic teardown
/// is `GlobeSceneView.dismantleUIView`.
private final class DisplayLinkProxy: NSObject {
    /// Returns false once the target is gone.
    private let handler: () -> Bool
    /// Weak: the link retains this proxy, so a strong reference back would be
    /// a cycle that neither end could break.
    weak var link: CADisplayLink?

    init(handler: @escaping () -> Bool) {
        self.handler = handler
    }

    @objc func fire() {
        guard handler() else {
            link?.invalidate()
            link = nil
            return
        }
    }
}
#endif
