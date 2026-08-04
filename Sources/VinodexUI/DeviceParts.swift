#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// One colour a chassis part can be painted (0.7.3, B1).
///
/// **Why a palette and not a colour picker.** The five colour axes each need
/// more than one colour: a button needs a six-stop lit ramp *and* a moulded cap
/// ramp, an orb needs a bead and a halo, the marquee needs a lit ground, a grid
/// and the near-black its letters are cut from. A system colour well hands back
/// one `Color`, and every part built from it would then need those ramps derived
/// anyway — so the derivation is the real work and the picker was only ever
/// going to decide the input to it. A named palette also persists as a short
/// stable string rather than as a float triple, which is what lets a saved build
/// survive a colour being retuned.
///
/// **One base hex per entry, everything else derived.** Thirteen colours across
/// five axes is sixty-five hand-authored ramps if each is written out, which is
/// sixty-five chances for one stop to be from the wrong colourway — the exact
/// failure `ChassisAccent`'s own doc comment describes as looking "like a
/// manufacturing fault rather than like a mistake in the code". Deriving them
/// through `DexRGB.mixed(with:amount:)` — the same linear sRGB mix
/// `LcdMode.chrome(face:shadow:)` uses, and linear for the same reason: these
/// are paint chips chosen by eye — means a colour is one line and cannot be
/// internally inconsistent.
///
/// The mix amounts are calibrated against VINODEX CLASSIC's hand-authored parts
/// so a derived ramp sits in the same register as the twenty-one authored ones;
/// each is noted where it is used. **CLASSIC itself is untouched** — an unset
/// axis inherits from the skin, so nothing here paints a device until the player
/// chooses it.
///
/// The raw values are persisted (they are what a `DeviceBuild` stores), so they
/// are ASCII and must not be renamed; `displayName` is where an accent may live,
/// exactly as `ChassisSkin.petNat` does it.
public enum PartColor: String, CaseIterable, Identifiable, Sendable {
    case crimson = "CRIMSON"
    case claret = "CLARET"
    case rose = "ROSE"
    case amber = "AMBER"
    case straw = "STRAW"
    case absinthe = "ABSINTHE"
    case verdant = "VERDANT"
    case glacier = "GLACIER"
    case cobalt = "COBALT"
    case violet = "VIOLET"
    case slate = "SLATE"
    case ivory = "IVORY"
    case onyx = "ONYX"

    public var id: String { rawValue }

    /// The one authored value. Everything else on this type comes out of it.
    public var baseHex: String {
        switch self {
        case .crimson: "#D2384F"
        case .claret: "#8E2436"
        case .rose: "#F2A0B5"
        case .amber: "#F0A324"
        case .straw: "#EFD25C"
        case .absinthe: "#A8E04A"
        case .verdant: "#3FBF6A"
        case .glacier: "#3FC8E0"
        case .cobalt: "#3B6FE0"
        case .violet: "#9B6BF2"
        case .slate: "#8895A6"
        case .ivory: "#EFE6D2"
        case .onyx: "#33373F"
        }
    }

    public var displayName: String {
        switch self {
        // The accent lives here and not in the rawValue, per the note on the
        // type — the rawValue is what a saved build stores.
        case .rose: "ROSÉ"
        default: rawValue
        }
    }

    // MARK: Derivation

    private var rgb: DexRGB { DexRGB(hex: baseHex) }
    private static let white = DexRGB(r: 1, g: 1, b: 1)
    private static let black = DexRGB(r: 0, g: 0, b: 0)

    private func lighter(_ amount: Double) -> DexRGB { rgb.mixed(with: Self.white, amount: amount) }
    private func darker(_ amount: Double) -> DexRGB { rgb.mixed(with: Self.black, amount: amount) }

    /// The flat form: the grille's slats, the font's ink, a swatch.
    public var color: Color { rgb.color }

    /// Whether this colour is legible as *text* on a pale or a dark ground
    /// (0.7.3, B1).
    ///
    /// **The one guard the font axis genuinely needs.** Every other part of the
    /// device is decoration — an ivory grille on an ivory shell is a bad-looking
    /// choice and nothing more — but the font is what the screen says things
    /// with, and IVORY on the paper-white LCD is a device that has stopped
    /// working. Recovering from that means finding the workshop again through
    /// text you can no longer read.
    ///
    /// So it is a *rule*, not a warning: `LcdMode.accepts(_:)` refuses inks that
    /// fail this and falls back to the mode's own, which means the unreadable
    /// state is not reachable at all — including by choosing an ink on a dark
    /// screen and then switching to a pale one, which no picker-side filter could
    /// have caught.
    ///
    /// The thresholds are asymmetric because the problem is: white grounds are
    /// brighter than dark grounds are dark, so a mid-tone that survives on black
    /// can still wash out on paper. 0.62 excludes IVORY, STRAW, ABSINTHE,
    /// GLACIER, AMBER and ROSÉ from the pale modes; 0.26 excludes ONYX and
    /// CLARET from the dark ones. Both sides keep seven or more choices, which is
    /// what makes this a rule worth having rather than one that empties the row.
    public func readsAsInk(onLightGround light: Bool) -> Bool {
        let value = rgb.luminance
        return light ? value < 0.62 : value > 0.26
    }

    /// Ink that reads on this colour.
    ///
    /// `luminance > 0.55` rather than `> 0.5`, matching
    /// `LcdMode.chromeInk(over:preferring:)` exactly and for its stated reason:
    /// white-on-mid reads worse than black-on-mid at the small retro faces these
    /// glyphs sit in, so the tie goes to dark ink.
    ///
    /// A very dark form of the colour itself rather than flat black, so a
    /// chevron on a STRAW cap is a brown-black that belongs to the cap — which
    /// is what CLASSIC's `#78350f` ink on its amber ramp is.
    private var inkHex: String {
        rgb.luminance > 0.55 ? darker(0.80).hex : "#FFFFFF"
    }

    /// The six-stop lit ramp — the Home button's inner disc and outer ring.
    ///
    /// Calibrated against CLASSIC's amber (`pale #fef3c7` … `edge #b45309`): the
    /// two pale stops are heavy white mixes, `bright` is the chosen colour
    /// itself so the player gets the colour they picked on the part they are
    /// looking at, and `edge` is a little over half black so the ring reads as a
    /// moulded lip rather than as a stroke.
    public var accent: ChassisAccent {
        ChassisAccent(
            pale: lighter(0.80).hex,
            light: lighter(0.56).hex,
            bright: baseHex,
            mid: darker(0.20).hex,
            edge: darker(0.52).hex,
            ink: inkHex
        )
    }

    /// The moulded (unlit) cap — Back and the user button.
    ///
    /// Calibrated against CLASSIC's stone (`top #44403c`, `bottom #0c0a09`,
    /// `edge #a8a29e`): the cap's own face barely moves off the chosen colour,
    /// the shadow under it is most of the way to black, and the rim is a bright
    /// highlight — that spread is what makes an unlit cap read as moulded
    /// plastic catching a light rather than as a flat disc.
    ///
    /// `glyph` follows `inkHex` rather than being assumed white, which is the
    /// case `ChassisControl`'s own note calls out: Blanc de Blancs' pale caps
    /// make white unreadable, and IVORY and STRAW here are the same problem.
    public var control: ChassisControl {
        ChassisControl(
            top: lighter(0.10).hex,
            bottom: darker(0.70).hex,
            edge: lighter(0.48).hex,
            glyph: inkHex
        )
    }

    /// All four face buttons in one colour.
    ///
    /// A `ChassisButtonSet` rather than leaving the three moulded caps to
    /// `control` and Home to `accent`, because two of the twenty-one skins
    /// (PSVINO and CHRISTMAS) carry a set and the chassis reads
    /// `buttonSet ?? (accent, control)` — a workshop override that filled only
    /// half of that would leave a console livery's four colours fighting one
    /// chosen colour. Choosing a button colour means choosing it for the buttons,
    /// all of them.
    public var buttonSet: ChassisButtonSet {
        ChassisButtonSet(home: accent, back: control, bookmarks: control, settings: control)
    }

    /// The glass bead above the display, and the halo that pulses behind it.
    ///
    /// CLASSIC's relationship exactly — a pale bead (`cyan300`) over a saturated
    /// glow (`blue`) — rather than the flat reading of "orb colour". The bead is
    /// glass with a specular highlight on it and a white rim around it; painting
    /// it the raw colour makes it a sticker, and the pulse is where the colour
    /// actually announces itself.
    public var orb: Color { lighter(0.32).color }
    public var orbGlow: Color { rgb.color }

    /// The marquee's lit phosphor ground.
    public var marqueeText: Color { rgb.color }
    /// The grid over it — one register brighter, as CLASSIC's `green` is over
    /// its `green500`.
    public var marqueeGrid: Color { lighter(0.22).color }
    /// The letters, and the panel's rim: the very dark form of the phosphor,
    /// which is what a segment LCD's glyphs actually look like. CLASSIC's
    /// `#082010` sits about 0.84 of the way to black from its `green500`.
    public var marqueeShadow: Color { darker(0.84).color }
}

/// The speaker grille's pattern (0.7.3, B1).
///
/// **The axis that did not exist in any form.** The grille was four hardcoded
/// 64×2 capsules in `DeviceChassis.bottomVents` — not a property of the skin, not
/// a setting, not anything: every one of the twenty-one shells had the identical
/// vent in a different colour. So unlike the five colour axes, this one is not a
/// case of prising a value out of `ChassisSkin`; it is a new part of the device.
///
/// Five patterns, and the count is the argument: a grille is a 64pt strip about
/// 14pt tall sitting beside a wordmark at the bottom of the shell, and the
/// patterns have to be distinguishable *there* rather than in a picker. Anything
/// finer than `MESH` is a texture; anything busier reads as damage.
///
/// `slats` is what the device has always had and is what an empty stored value
/// resolves to, so this axis costs an untouched device nothing.
public enum GrilleShape: String, CaseIterable, Identifiable, Sendable {
    /// Four horizontal capsules — the vent through 0.7.2, and still the default.
    case slats = "SLATS"
    /// The same run turned ninety degrees: a comb of narrow vertical bars.
    case bars = "BARS"
    /// A perforated plate — the drilled-hole grille of a desk telephone.
    case dots = "DOTS"
    /// Crosshatch: the woven mesh over a valve radio's speaker.
    case mesh = "MESH"
    /// No vent at all. A sealed shell is a legitimate look and is the only way
    /// to make the wordmark the sole thing on the bottom strip.
    case none = "NONE"

    public var id: String { rawValue }

    public var displayName: String { rawValue }

    /// The picker's glyph. All SF Symbols 1–2, under the iOS 17 floor.
    public var symbol: String {
        switch self {
        case .slats: "line.3.horizontal"
        // A run of narrow vertical bars, which is what this pattern is. The
        // barcode on the back plate is a drawing rather than a symbol, so
        // nothing in the app collides with it.
        case .bars: "barcode"
        case .dots: "circle.grid.3x3.fill"
        case .mesh: "grid"
        case .none: "rectangle"
        }
    }
}

/// The grille itself, in whichever pattern is fitted (0.7.3, B1).
///
/// One view rather than a shape per case in the chassis, so the vent has one
/// size and one opacity wherever it is drawn — the workshop's preview draws it
/// at a third of the size and must not quietly become a different part.
///
/// Faint on purpose at 0.5, unchanged from the capsules this replaces: the vent
/// is texture, not a feature.
public struct ChassisGrille: View {
    public let shape: GrilleShape
    public let ink: Color
    /// The run's width. 64 in the chassis, less in the workshop's preview.
    public let width: CGFloat

    public init(shape: GrilleShape, ink: Color, width: CGFloat = 64) {
        self.shape = shape
        self.ink = ink
        self.width = width
    }

    /// Scaled off `width` so every pattern shrinks together in the preview.
    private var unit: CGFloat { max(width / 64, 0.5) }

    /// The run the four slats occupy: `4 × 2 + 3 × 3`. Every other pattern is
    /// centred in the same slot, so swapping the vent cannot move the wordmark
    /// beside it — the bottom strip lays its three parts out along one line and
    /// a pattern an unfamiliar height would shift all of them.
    private var slotHeight: CGFloat { 17 * unit }

    public var body: some View {
        Group {
            switch shape {
            case .slats:
                VStack(spacing: 3 * unit) {
                    ForEach(0..<4, id: \.self) { _ in
                        Capsule().fill(ink).frame(width: width, height: 2 * unit)
                    }
                }
            case .bars:
                // Thirteen bars at 2 with 3 between them is 62 of the 64 the
                // slats run, which is as near as an odd count gets.
                HStack(spacing: 3 * unit) {
                    ForEach(0..<13, id: \.self) { _ in
                        Capsule().fill(ink).frame(width: 2 * unit, height: slotHeight)
                    }
                }
            case .dots:
                VStack(spacing: 3 * unit) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 3 * unit) {
                            ForEach(0..<12, id: \.self) { _ in
                                Circle().fill(ink).frame(width: 2.4 * unit, height: 2.4 * unit)
                            }
                        }
                    }
                }
            case .mesh:
                // One stroked path rather than stacked rules: a crosshatch built
                // from overlapping `Rectangle`s doubles the ink at every
                // crossing, which at 0.5 opacity is a grid of darker dots — the
                // one artefact that makes a mesh read as damage rather than as
                // weave.
                Canvas { context, size in
                    var path = Path()
                    let step = 4 * unit
                    var x: CGFloat = 0
                    while x <= size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += step
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += step
                    }
                    context.stroke(path, with: .color(ink), lineWidth: unit)
                }
            case .none:
                // Holds the slot rather than collapsing it: a zero-width vent
                // would let the wordmark slide into the corner the moment
                // somebody removed the grille.
                Color.clear
            }
        }
        .frame(width: width, height: slotHeight)
        .opacity(shape == .none ? 0 : 0.5)
    }
}

/// How the device is actually painted, part by part (0.7.3, B1).
///
/// **The resolver, and the reason there is only one.** Before this batch a
/// chassis view held `private var skin: ChassisSkin` and read `skin.orb`,
/// `skin.grill`, `skin.accent` off it. Six of those properties are now
/// overridable, and the wrong way to do that is for each view to write
/// `partOrb.map(\.orb) ?? skin.orb` at each of its call sites — which is the
/// `option != .classic && !access.isUnlocked(.skins)` mistake F1 spent a batch
/// undoing, with six times the surface.
///
/// So this type carries **the same member names the skin does**, and the views
/// changed one line each: the type of their `skin` property. Every `skin.orb` in
/// `DeviceChassis` still reads `skin.orb`; it now goes through the fallback
/// rather than around it, and the compiler found every call site rather than a
/// search doing it.
///
/// Everything not overridable forwards to the skin untouched — a workshop that
/// let you recolour the shell's *pattern* or the back plate's screws is a
/// different feature, and forwarding says so plainly.
public struct ChassisLook {
    public let skin: ChassisSkin
    private let buttonsPart: PartColor?
    private let orbPart: PartColor?
    private let marqueePart: PartColor?
    private let grillePart: PartColor?
    public let grilleShape: GrilleShape

    /// Built from raw stored strings, because that is what the views hold: each
    /// reads its axes through `@AppStorage`, which is KVO-backed, so the chassis
    /// repaints the instant the workshop writes a part. Resolving here rather
    /// than at each `@AppStorage` declaration keeps the "unknown value falls back
    /// to the skin" rule in one place, where an older build's stored colour that
    /// no longer exists cannot crash anything.
    public init(
        skinRaw: String,
        buttons: String = "",
        orb: String = "",
        marquee: String = "",
        grille: String = "",
        grilleShape: String = ""
    ) {
        self.skin = ChassisSkin(rawValue: skinRaw) ?? .classic
        self.buttonsPart = PartColor(rawValue: buttons)
        self.orbPart = PartColor(rawValue: orb)
        self.marqueePart = PartColor(rawValue: marquee)
        self.grillePart = PartColor(rawValue: grille)
        self.grilleShape = GrilleShape(rawValue: grilleShape) ?? .slats
    }

    /// The whole build at once — the workshop's preview, which has a candidate
    /// build in hand rather than eight `@AppStorage` reads.
    public init(build: DeviceBuild) {
        self.init(
            skinRaw: build.shell,
            buttons: build.buttons,
            orb: build.orb,
            marquee: build.marquee,
            grille: build.grilleColor,
            grilleShape: build.grilleShape
        )
    }

    // MARK: The overridable parts

    public var accent: ChassisAccent { buttonsPart?.accent ?? skin.accent }
    public var control: ChassisControl { buttonsPart?.control ?? skin.control }

    /// **A chosen button colour replaces a console livery's set outright.** The
    /// alternative — keeping PSVINO's four face-button colours and repainting
    /// only Home — is a device whose buttons are five colours, which is not a
    /// choice anybody made.
    public var buttonSet: ChassisButtonSet? { buttonsPart?.buttonSet ?? skin.buttonSet }

    public var orb: Color { orbPart?.orb ?? skin.orb }
    public var orbGlow: Color { orbPart?.orbGlow ?? skin.orbGlow }

    public var marqueeText: Color { marqueePart?.marqueeText ?? skin.marqueeText }
    public var marqueeGrid: Color { marqueePart?.marqueeGrid ?? skin.marqueeGrid }
    public var marqueeShadow: Color { marqueePart?.marqueeShadow ?? skin.marqueeShadow }

    public var grill: Color { grillePart?.color ?? skin.grill }

    // MARK: Forwarded, unchanged

    public var body: Color { skin.body }
    public var underlay: Color { skin.underlay }
    public var footerWash: Color { skin.footerWash }
    public var panel: Color { skin.panel }
    public var panelEdge: Color { skin.panelEdge }
    public var bodyPatternAsset: String? { skin.bodyPatternAsset }
    public var isTranslucent: Bool { skin.isTranslucent }
    public var rimGlow: Color? { skin.rimGlow }
    public var statusLights: [(fill: Color, border: Color)] { skin.statusLights }
    public var userMark: SkinMark? { skin.userMark }
    public var drawnMark: SkinMark? { skin.drawnMark }
    public var sketch: SketchStyle? { skin.sketch }
    public var next: ChassisSkin { skin.next }
}
#endif
