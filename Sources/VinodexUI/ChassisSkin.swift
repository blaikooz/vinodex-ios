#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import CoreText
import VinodexCore

// MARK: - ChassisSkin

// The chassis skins -- what the shell looks like, per skin, and the value
// types a skin is described with.

/// A colour as three channels, so two of them can be mixed.
///
/// SwiftUI's `Color` is opaque — there is no supported way back out to
/// components without going through `UIColor`, which would make this file
/// UIKit-dependent for arithmetic that is four lines of `Double`. Everything
/// upstream is already `#RRGGBB` strings (`Color(dexHex:)`, `ChassisAccent`,
/// every tile literal), so the strings are the honest input.
public struct DexRGB: Sendable, Equatable {
    public var r: Double
    public var g: Double
    public var b: Double

    /// Parses `#RRGGBB`. Falls back to mid grey on anything else, matching
    /// `Color(dexHex:)`'s own behaviour rather than trapping — a colour is
    /// never worth a crash.
    public init(hex raw: String) {
        let value = raw.trimmingCharacters(in: .whitespaces)
        let digits = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard digits.count == 6, let bits = UInt32(digits, radix: 16) else {
            (r, g, b) = (0.47, 0.44, 0.42)
            return
        }
        r = Double((bits >> 16) & 0xFF) / 255
        g = Double((bits >> 8) & 0xFF) / 255
        b = Double(bits & 0xFF) / 255
    }

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// `amount` of `other`, the rest of self. Linear in sRGB, which is wrong
    /// physically and right here: the inputs are UI paint chips chosen by eye,
    /// and a gamma-correct mix of two mid-tones comes back lighter than either
    /// of the colours a designer picked.
    public func mixed(with other: DexRGB, amount: Double) -> DexRGB {
        let t = min(max(amount, 0), 1)
        return DexRGB(
            r: r + (other.r - r) * t,
            g: g + (other.g - g) * t,
            b: b + (other.b - b) * t
        )
    }

    /// Rec. 709 relative luminance, for deciding black ink or white.
    public var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    public var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }

    /// Back out to `#RRGGBB` (0.7.3, B1).
    ///
    /// The round trip exists because `ChassisAccent` and `ChassisControl` take
    /// *hex strings* rather than colours — deliberately, so a skin author writes
    /// a ramp the way a paint chip is written — and `PartColor` derives its ramps
    /// by mixing. Without this, deriving a six-stop ramp would mean either a
    /// second colour-taking initialiser on both structs (two ways to build one
    /// part, which is how one of them ends up subtly different) or reimplementing
    /// the mix in string space.
    ///
    /// Clamped and rounded rather than truncated: a channel that lands on
    /// 254.9999 through a linear mix is 255, and `String(format:)` would floor
    /// it to `FE`.
    public var hex: String {
        func channel(_ value: Double) -> Int {
            Int((min(max(value, 0), 1) * 255).rounded())
        }
        return String(format: "#%02X%02X%02X", channel(r), channel(g), channel(b))
    }
}

/// The six-stop colour ramp one lit chassis button is built from.
///
/// A struct rather than six properties on `ChassisSkin` because they are only
/// ever used together, and a skin that got four of them right and two of them
/// from the previous colourway would look like a manufacturing fault rather than
/// like a mistake in the code.
///
/// Named by lightness rather than by where each one lands, so a skin author does
/// not have to know that `mid` is both the outer button's bottom stop and the
/// inner disc's ring. `ChassisButton` owns that arrangement.
public struct ChassisAccent: Sendable {
    /// Inner disc, top.
    public let pale: Color
    /// Outer button, top.
    public let light: Color
    /// Inner disc, bottom.
    public let bright: Color
    /// Outer button, bottom — and the inner disc's hairline.
    public let mid: Color
    /// Outer border.
    public let edge: Color
    /// The glyph.
    public let ink: Color

    /// The two stops kept as components as well as colours, so a ramp can be
    /// *mixed into* something (0.7.1, C5 — see `LcdMode.chrome(face:shadow:)`).
    /// `bright` and `edge` are the pair a themed control needs: the face it
    /// leans toward and the shadow under it. Stored at init rather than parsed
    /// per call — a tools shelf asks for six of these per render.
    public let brightRGB: DexRGB
    public let edgeRGB: DexRGB
    /// `light` as its source string — Home's face, for `ChassisCapLoader`.
    /// See `ChassisControl.topHex`, which this mirrors.
    public let lightHex: String
    /// `ink` as its source string (0.8.4, E1) -- Home's incised symbol, the
    /// counterpart of `ChassisControl.glyphHex`. Home is the one cap whose face
    /// comes off the accent ramp rather than off a `ChassisControl`, so it needs
    /// its own pair or it would be the single button in the band that kept the
    /// 0.8.3 single-tone treatment.
    public let inkHex: String

    public init(pale: String, light: String, bright: String, mid: String, edge: String, ink: String) {
        self.lightHex = light
        self.inkHex = ink
        self.pale = Color(dexHex: pale)
        self.light = Color(dexHex: light)
        self.bright = Color(dexHex: bright)
        self.mid = Color(dexHex: mid)
        self.edge = Color(dexHex: edge)
        self.ink = Color(dexHex: ink)
        self.brightRGB = DexRGB(hex: bright)
        self.edgeRGB = DexRGB(hex: edge)
    }
}

/// The moulded (unlit) chassis buttons: Back and the user/saved button.
///
/// Separate from `ChassisAccent` because these are a different *kind* of part.
/// The accent ramp describes something that looks powered — six stops, an inner
/// disc, a glow. This is a moulded cap: a face, a shadow under it, a rim, and
/// whatever colour the glyph has to be to sit on it.
///
/// `glyph` is here rather than assumed white because one skin needs it dark.
/// Blanc de Blancs' buttons are the original handheld's pale grey, and white on
/// pale grey is unreadable.
public struct ChassisControl: Sendable {
    /// Top of the cap's gradient.
    public let top: Color
    /// Bottom of it.
    public let bottom: Color
    /// The rim.
    public let edge: Color
    /// The chevron or person glyph.
    public let glyph: Color

    /// `top` kept as its source string as well as a colour (0.8.2).
    ///
    /// `ChassisCapLoader` re-inks the drawn footer caps to the skin's face
    /// colour, which means reading its hue and saturation and keying a cache on
    /// it — neither of which a `SwiftUI.Color` will answer without a round trip
    /// through `UIColor` that is unavailable to the type this struct lives
    /// beside. The same trade `ChassisAccent` already makes with `brightRGB`
    /// and `edgeRGB`, and for the same reason: the caller has the string at
    /// init and nowhere afterwards.
    public let topHex: String
    /// `glyph` kept as its source string as well (0.8.4, E1), for the same
    /// reason and the same reader: `ChassisCapLoader` now inks the incised
    /// symbol separately from the face, so it needs both ends of the pair as
    /// hue and saturation rather than as `SwiftUI.Color`.
    public let glyphHex: String
    /// And the last two of the four (0.8.94, A1), for a different reader:
    /// `ChassisAccent.init(cap:)` restates this whole cap as the ramp Home
    /// draws from, and a ramp needs every stop as a string it can mix.
    public let bottomHex: String
    public let edgeHex: String

    public init(top: String, bottom: String, edge: String, glyph: String) {
        self.top = Color(dexHex: top)
        self.bottom = Color(dexHex: bottom)
        self.edge = Color(dexHex: edge)
        self.glyph = Color(dexHex: glyph)
        self.topHex = top
        self.glyphHex = glyph
        self.bottomHex = bottom
        self.edgeHex = edge
    }
}

public extension ChassisAccent {
    /// The moulded cap, restated as the ramp Home draws from (0.8.94, A1).
    ///
    /// **This initialiser is the Home-button fix, stated as a type
    /// conversion.** The four footer caps were two colour models: Back, User
    /// and Settings resolve a `ChassisControl`, while Home resolves a
    /// `ChassisAccent` whose fallback was `skin.accent` — a bright accent
    /// unrelated to the moulded cap beside it. That fallback is why Home wore
    /// gold on OAKED's wood and white on BURGUNDY's purple, and why three
    /// consecutive batches of cap fixes each "missed the home button": every
    /// fix landed on the `ChassisControl` path, and Home was never on it.
    ///
    /// Now the fallback *is* the cap. `light` and `bright` are the cap's own
    /// face — so the drawn cap re-inks to exactly the material Back re-inks to,
    /// which is the equality `FooterCapTests` pins — `mid` is the cap's
    /// shadow, the rim and the ink come straight across, and the one derived
    /// stop is `pale`: the inner disc's top, a 16% lift of the face, which is
    /// the moulded highlight an unlit cap has in place of a glow.
    ///
    /// The console liveries never reach this: their `buttonSet.home` is an
    /// authored ramp and still wins — see `ChassisLook.homeAccent`.
    init(cap: ChassisControl) {
        let pale = DexRGB(hex: cap.topHex)
            .mixed(with: DexRGB(r: 1, g: 1, b: 1), amount: 0.16)
            .hex
        self.init(
            pale: pale,
            light: cap.topHex,
            bright: cap.topHex,
            mid: cap.bottomHex,
            edge: cap.edgeHex,
            ink: cap.glyphHex
        )
    }
}

/// Four individually-coloured face buttons (0.6.7, K2/K3).
///
/// Only the two console liveries carry one — see `ChassisSkin.buttonSet`. Home
/// keeps the six-stop `ChassisAccent` rather than being flattened to a cap,
/// because it is still the lit button on those shells and losing its inner disc
/// to gain a colour would be a downgrade; the other three are ordinary moulded
/// caps that happen to be four different colours.
///
/// One struct rather than four optional properties, for `ChassisAccent`'s own
/// reason: a skin that coloured three of the four and inherited the fourth from
/// the default cap would read as a bug, not as a colourway.
public struct ChassisButtonSet: Sendable {
    public let home: ChassisAccent
    public let back: ChassisControl
    public let bookmarks: ChassisControl
    public let settings: ChassisControl

    public init(
        home: ChassisAccent,
        back: ChassisControl,
        bookmarks: ChassisControl,
        settings: ChassisControl
    ) {
        self.home = home
        self.back = back
        self.bookmarks = bookmarks
        self.settings = settings
    }
}

/// How a skin's parts are *drawn*, for the one skin that is not a palette
/// (0.6.9, M1).
///
/// Sibling to `ChassisButtonSet` and `SkinMark` in intent: an optional hook on
/// `ChassisSkin` that is nil on every ordinary colourway and costs them nothing.
/// The difference is what it varies. Those two vary colours and a badge; this
/// varies the *line* — the shell gains a paper grain and every rim on the
/// chassis is re-emitted as a wobbled, twice-drawn ink stroke instead of a
/// geometric one. See `SketchRender.swift` for why that is the only way to get a
/// hand-drawn look out of a system whose eighteen other skins are hex tables.
///
/// Two colours, because that is all a drawing has: what you draw *with* and
/// what you draw *on*.
public struct SketchStyle: Sendable {
    /// The pen. Every outline on the chassis is stroked in this.
    public let ink: Color
    /// The paper's tooth — the stipple laid over the shell.
    public let grain: Color

    public init(ink: String, grain: String) {
        self.ink = Color(dexHex: ink)
        self.grain = Color(dexHex: grain)
    }
}

/// A drawn skin emblem, for skins that cannot use an SF Symbol (0.6.7, K1).
///
/// An enum with one case rather than a view, so `ChassisSkin` — which is data —
/// does not have to know how to draw anything; `SkinEmblem` in the view layer
/// resolves it. Adding a second mark is a case here and an arm there.
public enum SkinMark: Sendable, Equatable {
    /// The Vinodex sigil: an original maker's mark. See `SkinSigil`.
    case sigil
    /// A jack-o'-lantern (0.7.0, B2). Drawn rather than named because SF
    /// Symbols has no pumpkin at the iOS 17 floor — not a licensing problem
    /// like `.sigil`'s, simply an absent glyph, and the same hook answers both.
    /// See `SkinPumpkin`.
    /// See `SkinPumpkin`.
    ///
    /// How a mark is *drawn* stays in `SkinMarkView`'s switch rather than
    /// becoming a flag here: the sigil is three open strokes and has to be
    /// stroked, the lantern is a silhouette with its face cut out and has to be
    /// filled `eoFill`, and a third mark will have its own answer that no
    /// `isStroked` boolean would have covered. An exhaustive switch in one
    /// renderer is the thing that will not compile until that answer exists.
    case pumpkin
}

/// How one chassis skin's **back plate** is made (0.7.0, F1).
///
/// The plate was a single hardcoded sheet of brushed aluminium with one
/// exception carved out of it — `isTranslucent` swapped the metal for the mock
/// internals, and seventeen of nineteen skins therefore turned over to a
/// byte-identical slab. A shell moulded from walnut, from paper or from
/// bottle glass with a steel back is two products, which is the argument the
/// plate's own doc comment already made for the clear skins and then applied to
/// nobody else.
///
/// A struct rather than a pile of separate hooks, for `ChassisAccent`'s reason:
/// these values are only ever used together, and a plate is one material.
///
/// **VINODEX CLASSIC's values are the plate exactly as it was** — every literal
/// below for `.classic` is lifted from the hardcoded sheet, so the house device
/// is provably untouched and stays the reference the others vary from.
public struct BackPlateStyle: Sendable {
    /// The four diagonal stops of the plate's own material.
    public let stops: [Color]
    /// What is done to that material's surface.
    public let finish: BackPlateFinish
    /// The dark band around the whole plate.
    public let edge: Color
    /// Fill for anything cut *into* the plate: the nameplate recess, the serial
    /// panel, the return dish.
    public let recess: Color
    /// The engraved copy, and the heavier weight for the maker's mark.
    public let ink: Color
    public let inkDeep: Color
    /// The fasteners: three stops for the head, one for its rim.
    public let screw: [Color]
    public let screwRim: Color

    public init(
        stops: [String],
        finish: BackPlateFinish,
        edge: String,
        recess: String,
        ink: String,
        inkDeep: String,
        screw: [String],
        screwRim: String
    ) {
        self.stops = stops.map { Color(dexHex: $0) }
        self.finish = finish
        self.edge = Color(dexHex: edge)
        self.recess = Color(dexHex: recess)
        self.ink = Color(dexHex: ink)
        self.inkDeep = Color(dexHex: inkDeep)
        self.screw = screw.map { Color(dexHex: $0) }
        self.screwRim = Color(dexHex: screwRim)
    }
}

/// The surface treatment over a plate's base material (0.7.0, F1).
public enum BackPlateFinish: Sendable, Equatable {
    /// The fine vertical striations that say "machined aluminium" — the
    /// original plate's finish, and still CLASSIC's.
    case brushed
    /// Nothing at all: injection-moulded plastic, which has no grain.
    case moulded
    /// A tiled pattern from `Resources/Chassis`, by the same name and through
    /// the same loader the *front* shell uses (`ChassisSkin.bodyPatternAsset`).
    /// Reusing the front's asset is the point — a walnut device is walnut on
    /// both sides or it is two devices.
    case pattern(String)
    /// Paper tooth, for the drawn shell — `SketchRender.PaperGrain` in this
    /// colour, exactly as `ChassisShell` mounts it on the front.
    case paper(Color)
}

/// Chassis colourway. The LCD itself never changes — only the moulding around
/// it — so a skin swap cannot affect legibility of the content.
///
/// Persisted under this key by both `DeviceChassis` and `SettingsPanel`;
/// `@AppStorage` keeps the two in sync without threading state between them.
///
/// A heading in the chassis-skin picker (0.7.0, B2).
///
/// Twenty-one shells in one flat grid is a swatch book, not a range. These six
/// headings are the six *arguments* the range actually makes: the house
/// colourways, the ones named for a wine's colour, the ones named for what wine
/// is kept in, the ones quoting consumer hardware, the see-through ones, and the
/// seasonal ones.
///
/// `allCases` order is picker order. Membership is not declared here — see
/// `ChassisSkin.section`.
public enum ChassisSkinSection: String, CaseIterable, Identifiable, Sendable {
    /// The house device and the two shells that are variations on it.
    case classic = "CLASSIC"
    /// Named for what is in the glass.
    case wines = "WINES"
    /// Named for what the wine is kept in — cask, tank, bottle.
    case vessel = "VESSEL"
    /// The consumer-hardware homages. Never anybody's mark — see `drawnMark`.
    case retrofit = "RETROFIT"
    /// The translucent shells, mock internals showing through.
    case clearTech = "CLEARTECH"
    /// Seasonal in theme only. A skin that vanished in January would read as a
    /// bug, not as a gift — see `.christmas`.
    case festive = "FESTIVE"

    public var id: String { rawValue }

    /// The skins under this heading, in `ChassisSkin.allCases` order.
    ///
    /// Derived rather than declared, so the six sections are provably a
    /// partition of `allCases`: no skin can be dropped from the picker by being
    /// left off a list, and none can appear twice.
    public var skins: [ChassisSkin] { ChassisSkin.allCases.filter { $0.section == self } }
}

/// A skin used to be four greys and a body colour: swap it and you got the same
/// cyan orb, the same amber Home button and the same green marquee in a
/// different-coloured tray. The moulding changed and none of the *parts* did,
/// which is why four of the five read as recolours of one device rather than as
/// five devices. Each now carries its own orb, its own lit-button ramp and its
/// own marquee phosphor.
///
/// **Vinodex Classic is deliberately untouched** — every value below for
/// `.classic` is what the whole chassis used before this existed. It is the
/// house device and the reference the others are variations on; changing it
/// would move the baseline rather than add to it.
/// Everything a chassis skin declares as a flat value, grouped by skin (S3, 1/1b).
///
/// One row per skin instead of one `switch` per property — **sixteen switches
/// became one**. Mostly colour, plus the values that were the same shape: which
/// shelf the skin sits on (`section`), what the workshop calls it
/// (`displayName`), its SF Symbol (`symbol`), and the two struct ramps
/// (`accent`, `control`).
///
/// Named for what it mostly is. What is deliberately *not* here:
///
/// - **`statusLights`** — its switch sits under a local `trio(...)` function, so
///   moving it would mean promoting that helper too. That is a code change, not
///   a move, and it would forfeit the check that made the rest of this safe.
/// - **`buttonSet`, `drawnMark`, `userMark`, `backPlate`, `sketch`** — partial
///   switches with a `default`, or no switch at all. They carry logic rather
///   than a row per skin, and forcing them into a table would mean inventing a
///   value for every skin that currently falls through.
///
/// See `ChassisSkin.palette` for why a `switch` and not a dictionary.
public struct ChassisSkinPalette: Sendable {
    public let section: ChassisSkinSection
    public let displayName: String
    public let symbol: String
    public let accent: ChassisAccent
    public let control: ChassisControl
    public let globeTint: Color
    public let body: Color
    public let footerWash: Color
    public let panel: Color
    public let panelEdge: Color
    public let grill: Color
    public let orb: Color
    public let orbGlow: Color
    public let marqueeText: Color
    public let marqueeGrid: Color
    public let marqueeShadow: Color
}

public enum ChassisSkin: String, CaseIterable, Identifiable, Sendable {
    case classic = "CLASSIC"
    case midnight = "MIDNIGHT"
    /// The original grey-and-white shell rather than the red one.
    case original = "ORIGINAL"
    /// Velvet purple.
    case burgundy = "BURGUNDY"
    /// Vintage Walkman yellow.
    case riesling = "RIESLING"
    /// Forest-green DMG homage: pea-green screen tint, grey/black buttons,
    /// dark brown accents.
    case vinhoVerde = "VINHO VERDE"
    /// The clear-technology shell — translucent smoke plastic over mock
    /// internals, with bright orange for everything powered.
    case glouglou = "GLOUGLOU"
    /// The iPhone calculator's livery: near-black shell, warm dark-grey keys
    /// with a brown cast, and calculator-orange for everything powered.
    case smartGrape = "SMART GRAPE"
    /// Pale champagne-gold shell with gold-leaf powered parts — elegant, not
    /// garish; the dressing-table of the range.
    case champagne = "CHAMPAGNE"
    /// Pine shell, snow panel, red caps and gold lights. Seasonal in theme
    /// only — a skin that vanished in January would read as a bug, not a gift.
    case christmas = "CHRISTMAS"
    /// Atomic-purple clear shell — the second translucent colourway. Grape-
    /// juice gloss for everything powered, the guts faintly visible through it.
    case nouveau = "NOUVEAU"
    /// Walnut woodgrain deck, cream faceplate, brass for the powered parts.
    case oaked = "OAKED"
    /// Glow-in-the-dark pale luminous green with a softly glowing rim.
    case nocturne = "NOCTURNE"
    /// Brushed aluminium: mirror highlights, crisp dark seams.
    case steel = "STEEL"
    /// Rose-pink shell with a pale blush faceplate and pearl-pink lights —
    /// unapologetically pink and girly (v0.6, D1).
    case blush = "BLUSH"
    /// The DualShock 2 livery (0.6.5, item 9): matte charcoal moulding, a
    /// darker console-grey faceplate, and the four face-button colours doing
    /// all the talking — lights run triangle/circle/cross, the powered parts
    /// run the cross's blue. Subtle on purpose; the reference hardware was.
    case psvino = "PSVINO"
    /// The original handheld brick (0.6.7, J1): warm grey moulding with red
    /// face buttons, the pea-green screen surviving only as the marquee's
    /// phosphor.
    ///
    /// Named for the wine, not the console — `gris de gris` is a real style
    /// (pale grey-pink rosé pressed from Gris grapes), and "grey shell, red
    /// buttons" is the same sentence. The house has done this twice before:
    /// the forest-green DMG homage ships as BOX WINE and the calculator livery
    /// as SMART GRAPE. Naming a skin after someone else's hardware is the one
    /// thing this range does not do.
    case grisDeGris = "GRIS DE GRIS"
    /// Warning-orange moulding with black buttons (0.6.7, J2) — hazard livery,
    /// and the only skin in the range whose powered parts are *darker* than its
    /// shell.
    ///
    /// Orange wine is a real category (skin-contact white), which makes it the
    /// obvious name for the one orange device.
    case orangeWine = "ORANGE WINE"
    /// **The hand-drawn shell** (0.6.9, M1): cartridge paper with a fibre
    /// tooth, every rim inked by hand, and a blue-black pen doing all the work
    /// the other eighteen skins give to a colour ramp. See `sketch`.
    ///
    /// Named for the wine whose bottles look like this. Pét-nat is a real style
    /// — méthode ancestrale, bottled before the first fermentation finishes —
    /// and the hand-drawn label is so nearly universal on it that it is the
    /// category's visual signature. The house rule holds: a wine name, not a
    /// description, and nobody else's mark. The rawValue is ASCII on purpose
    /// (it persists); the accent lives in `displayName`, exactly as GRUNER BOY
    /// does.
    case petNat = "PET NAT"
    /// **Forest glass** (0.7.0, B2) — the green translucent shell, and the only
    /// skin in the range whose reference is older than electricity.
    ///
    /// *Waldglas* is genuine: the potash glass blown in the German and Bohemian
    /// forests from the middle ages on, coloured a pale olive-green by the iron
    /// in the wood ash that fluxed it. Bottle green is not a design choice, it is
    /// what glass does when nobody decolourises it — which makes this the most
    /// literal possible reading of "clear plastic shell" and lands it squarely in
    /// CLEARTECH beside EMPTY BOTTLE and RETROVIN.
    ///
    /// The house naming rule holds without straining: a real glass name, not a
    /// description, and nobody's mark.
    case waldglas = "WALDGLAS"
    /// **Black and orange** (0.7.0, B2) — the one skin in the range that is a
    /// night rather than a wine or a material.
    ///
    /// Seasonal in theme only, exactly as WINE XMAS is: it is always available,
    /// because a skin that appeared for a fortnight in October and then vanished
    /// would read as a bug. It carries the range's only per-skin *control* glyph
    /// — the user button is a drawn pumpkin, see `controlMark`.
    case halloween = "HALLOWEEN"
    /// **The purple deck** (0.7.6, D1) — a violet shell with four face-button
    /// colours doing all the talking, in the manner of the mid-nineties consoles
    /// that made a coloured moulded brick a mainstream object.
    ///
    /// **Inspired-by only, and the boundary is drawn where the house has always
    /// drawn it.** `buttonSet`'s own note has said since 0.6.7 (K2/K3) that a
    /// console livery takes *colours* and nothing else: the glyphs stay Vinodex's
    /// own chevron, house, person and cog, no silhouette is reproduced, and no
    /// mark of anybody's appears anywhere on the device or in this file. That is
    /// the same discipline the bouncing-mark screensaver was built under — see
    /// `VinodexV`, drawn from scratch precisely so the most-looked-at thing on an
    /// idle screen is unambiguously ours.
    ///
    /// **The rawValue is three separate commitments and was chosen once,
    /// carefully.** It is the `chassisSkin` `@AppStorage` value, the FNV-1a seed
    /// `WornSeed.of(skin.rawValue)` draws the back plate's procedural wear
    /// from, and the stem `stickerStem` derives (`sticker-w64`). Moving it later
    /// resets the shell, repaints the wear on the devices that survive, and
    /// orphans the sticker — the three costs FIBERGLASS's and HALLOWINE's rename
    /// notes were written up to avoid. It is ASCII, it collides with nothing in
    /// `shared/`, the generated JSON or the art scripts, and it is the label as
    /// well — `displayName` restates it rather than diverging from it, which is
    /// the one thing every rename note in this file wishes the earlier names had
    /// done.
    case w64 = "W64"

    /// Read from `DeviceAxis` since 0.7.3 (B1) rather than spelled out here.
    ///
    /// The literal was `"chassisSkin"` and still is — it holds real choices on
    /// real installs and cannot move. What changed is that the workshop needs the
    /// same key from Core, where `ChassisSkin` is invisible, and two files each
    /// carrying their own copy of a persisted key is precisely the arrangement
    /// that survives right up until somebody improves one of them.
    public static var storageKey: String { DeviceAxis.shell.storageKey }

    public var id: String { rawValue }

    /// Which heading this skin sits under in the picker (0.7.0, B2).
    ///
    /// An exhaustive switch, for `LcdMode.section`'s reason: written the other
    /// way round — six declared lists of skins — a skin could be left off every
    /// list and would simply stop appearing in the picker, with nothing failing
    /// to say so. This way the compiler refuses to build a skin with no home.
    ///
    /// Note that several skins sit under a heading their *case name* does not
    /// suggest, because the case name is the persisted raw value and the label
    /// has moved since: `.nocturne` is VINHO VERDE, `.vinhoVerde` is BOX WINE,
    /// `.riesling` is VIN JAUNE, `.nouveau` is RETROVIN, `.glouglou` is EMPTY
    /// BOTTLE. Read `displayName` before moving anything here.
    public var section: ChassisSkinSection { palette.section }

    /// Whether the shell is see-through — `DeviceChassis`'s cue to mount the
    /// mock internals behind it. A flag rather than sniffing alpha out of a
    /// `Color`, which SwiftUI does not expose anyway.
    public var isTranslucent: Bool {
        self == .glouglou || self == .nouveau || self == .waldglas
    }

    /// A soft halo around the screen housing — NOCTURNE's glow-in-the-dark
    /// charge. Nil everywhere else; the chassis applies it as a shadow, so
    /// an absent glow costs nothing.
    public var rimGlow: Color? {
        self == .nocturne ? Color(dexHex: "#A8FF96") : nil
    }

    /// The globe screen's sphere tint (0.6.2, F1) — every skin sees the world
    /// through its own colour. Pale on purpose: the tint multiplies over the
    /// map texture, so a saturated dark here would swallow the coastlines.
    public var globeTint: Color { palette.globeTint }

    /// What sits behind the shell: the shell itself for opaque skins, a
    /// near-black base under GLOUGLOU so the smoke plastic has something to be
    /// smoke over.
    public var underlay: Color {
        isTranslucent ? Color(dexHex: "#14161A") : body
    }

    /// The clear back moulding, laid over the internals — a touch lighter than
    /// the front shell, since the back of a clear device is one moulding
    /// further from the boards. Meaningful only for translucent skins.
    /// RETROVIN's back is its own atomic purple (v0.5.9, A2): the plate used
    /// one hardcoded grey smoke, so the purple shell turned grey from behind.
    /// A switch since 0.7.0 (B2) rather than the two-way ternary it was: with
    /// WALDGLAS there are three translucent skins and three back mouldings, and
    /// a ternary that has to name two of them is one skin away from lying about
    /// the third — which is exactly the bug v0.5.9's A2 fixed for RETROVIN.
    public var backSmoke: Color {
        switch self {
        case .nouveau: Color(dexHex: "rgba(147,51,234,0.34)")
        // Forest glass from behind: the same olive, one degree paler for the
        // extra moulding between the eye and the boards.
        case .waldglas: Color(dexHex: "rgba(176,196,132,0.34)")
        default: Color(dexHex: "rgba(204,216,224,0.34)")
        }
    }

    /// What the picker calls this skin.
    ///
    /// Deliberately separate from `rawValue`: the raw value is the persisted
    /// `@AppStorage` key, so renaming ORIGINAL to "Blanc de Blancs" by editing
    /// the case would silently reset every device already storing "ORIGINAL"
    /// back to the default shell. The stored vocabulary stays put and only the
    /// label moves.
    public var displayName: String { palette.displayName }

    /// A tileable pixel-art pattern drawn over the shell colour, or nil for a
    /// plain moulding. WINE XMAS wraps the chassis in wrapping paper, OAKED
    /// in walnut grain, STEEL in brushed aluminium; the pattern sits under
    /// the panel and footer wash like any other body.
    public var bodyPatternAsset: String? {
        switch self {
        case .christmas: "xmas-wrap"
        case .oaked: "oak-grain"
        case .steel: "steel-brush"
        default: nil
        }
    }

    /// Emblem glyph — the picker tile carries it the way screen-mode tiles
    /// carry theirs, and the back plate wears it as an enamel badge.
    public var symbol: String { palette.symbol }

    /// The three status lamps, left to right, as (fill, border, ink) triples — a
    /// unique trio per skin (v0.5.6, generalising WINE XMAS's all-red set,
    /// which used to be the one override on a fixed red/yellow/green).
    ///
    /// **`ink` is new in 0.7.5 (A1) and is derived, not authored.** The two
    /// marquee pills print a glyph inside the lamp, and until now that glyph was
    /// drawn in `border` — the same stop as the lamp's own keyline, so the mark
    /// and the rim around it were one colour and the mark read as part of the
    /// rim rather than as a symbol on a lamp. A1 asks for a darker glyph, and
    /// the honest way to get one is a further stop of the *lamp's own hue*
    /// rather than a chassis token: forty-two authored hexes would have to be
    /// re-picked otherwise, and a glyph in `marqueeShadow` would be the same
    /// near-black on all twenty-one skins.
    ///
    /// Mixed 45% toward black through `DexRGB`, the same primitive `PartColor`
    /// derives its ramps with — one derivation, twenty-one skins, and a new skin
    /// gets an ink by writing the two hexes it was always going to write.
    ///
    /// Adding a third *named* member is source-compatible: every call site
    /// reads `.fill` / `.border` by name, so the island trio and the vent lamps
    /// did not move.
    public var statusLights: [(fill: Color, border: Color, ink: Color)] {
        func trio(_ a: (String, String), _ b: (String, String), _ c: (String, String)) -> [(fill: Color, border: Color, ink: Color)] {
            [a, b, c].map {
                let border = DexRGB(hex: $0.1)
                return (
                    fill: Color(dexHex: $0.0),
                    border: border.color,
                    ink: border.mixed(with: DexRGB(r: 0, g: 0, b: 0), amount: 0.45).color
                )
            }
        }
        switch self {
        // The classic trio, exactly as it always was.
        case .classic:
            return trio(("#dc2626", "#991b1b"), ("#facc15", "#ca8a04"), ("#22c55e", "#15803d"))
        case .midnight:
            return trio(("#d8b4fe", "#7c3aed"), ("#a855f7", "#6b21a8"), ("#7c3aed", "#4c1d95"))
        case .original:
            return trio(("#ffd76e", "#f0b429"), ("#e8e0cc", "#9a9a93"), ("#d4a017", "#8a6820"))
        case .burgundy:
            return trio(("#f9a8d4", "#be185d"), ("#c084fc", "#7c3aed"), ("#7c3aed", "#4c1d95"))
        case .riesling:
            return trio(("#ef4444", "#b91c1c"), ("#facc15", "#ca8a04"), ("#4b5563", "#1f2937"))
        case .vinhoVerde:
            return trio(("#9BBC0F", "#6a8a0a"), ("#8BAC0F", "#5a740a"), ("#306230", "#0F380F"))
        case .glouglou:
            return trio(("#FDBA74", "#EA580C"), ("#FB923C", "#C2410C"), ("#F97316", "#9A3412"))
        case .smartGrape:
            return trio(("#FF9F0A", "#C97800"), ("#FFD60A", "#B8860B"), ("#8E8E93", "#48484A"))
        case .champagne:
            return trio(("#F5D97E", "#D4A017"), ("#E3BC5F", "#8A6820"), ("#FDF6E3", "#C8B87A"))
        // Holly-berry fairy lights, all three.
        case .christmas:
            return trio(("#FF4D4D", "#8F1414"), ("#FF4D4D", "#8F1414"), ("#FF4D4D", "#8F1414"))
        case .nouveau:
            return trio(("#E9D5FF", "#A855F7"), ("#C084FC", "#7C3AED"), ("#A855F7", "#6B21A8"))
        case .oaked:
            return trio(("#E8C15A", "#B5892E"), ("#D9AE55", "#8A6820"), ("#B5892E", "#7A5A14"))
        case .nocturne:
            return trio(("#B9FFAB", "#57D63E"), ("#8DF06A", "#2E8A20"), ("#57D63E", "#1E6A14"))
        case .steel:
            return trio(("#E8F1FF", "#9FB8D8"), ("#C7CBD1", "#6B7078"), ("#9FD4FF", "#5FA8E8"))
        // Pearl-pink fairy trio, light to deep — and the range widened in
        // 0.6.6 (E3). The three lamps grew in this batch, and at the old
        // spread (#FDA4AF / #F9A8D4 / #F472B6, three pinks within a few
        // percent of one luminance) that just made one flat pink smear three
        // times as obvious. These lamps carry no state — see
        // `DeviceChassis.statusDots` — so nothing is *lost* by a tight trio,
        // but a device with three indistinguishable indicators reads as
        // broken, and every other skin's trio steps.
        case .blush:
            return trio(("#FFE0E6", "#E11D48"), ("#F9A8D4", "#DB2777"), ("#D6296B", "#7A0B36"))
        // Triangle, circle, cross — the face buttons as indicator lamps.
        case .psvino:
            return trio(("#3AC4B4", "#0E7A6E"), ("#F0435C", "#8F0E20"), ("#6FA3E8", "#1B4470"))
        // Three reds stepped light to deep, matching the caps - the grey
        // shell leaves room for exactly one colour and the buttons have it.
        case .grisDeGris:
            return trio(("#FF8A8A", "#B02020"), ("#E23E3E", "#8F1414"), ("#A81E1E", "#5C0A0A"))
        // Hazard trio: signal yellow, safety orange, deep amber. Not black -
        // the buttons carry this skin's black, and an unlit indicator lamp
        // reads as a fault rather than as a colourway.
        case .orangeWine:
            return trio(("#FFD22E", "#B98A00"), ("#FF8A1F", "#A34C00"), ("#C24E06", "#6E2A00"))
        // Felt-tip primaries, the three pens anyone actually owns. Flat
        // and unshaded on purpose: a gradient lamp on a drawn shell is
        // the one thing that would give the trick away.
        case .petNat:
            return trio(("#E24A4A", "#8E1C1C"), ("#E8B93A", "#8E6A0A"), ("#3E7FBF", "#1B4470"))
        // Three depths of the same glass: the thin edge of a blown wall,
        // the body, and the punt where it stacks up almost opaque.
        case .waldglas:
            return trio(("#D7E8AE", "#7E9A3E"), ("#A8C766", "#5A7526"), ("#5F7A28", "#2E3F10"))
        // Candle, pumpkin, ember — stepped wide on purpose. Three oranges
        // within a few percent of one luminance is the BLUSH mistake
        // (see its note above): a device with three indistinguishable
        // indicators reads as broken.
        // Candle, pumpkin, ember — stepped wide on purpose. Three oranges
        // within a few percent of one luminance is the BLUSH mistake
        // (see its note above): a device with three indistinguishable
        // indicators reads as broken.
        case .halloween:
            return trio(("#FFC98A", "#B36A00"), ("#FF8A1F", "#A34C00"), ("#8A2E00", "#3D1200"))
        // Three of the four face colours, stepped light to deep — green, blue,
        // red. The fourth (yellow) is the settings cap in `buttonSet`, so all
        // four appear on the device without any one part carrying a colour
        // twice. Stepped wide, per BLUSH's note: three lamps within a few
        // percent of one luminance read as a fault.
        case .w64:
            return trio(("#63C86B", "#1E7A2E"), ("#3E7FD8", "#123C74"), ("#D8343E", "#7A0E16"))
        }
    }

    /// The moulding.
    public var body: Color { palette.body }

    /// Wash behind the footer row, a shade off the body.
    public var footerWash: Color { palette.footerWash }

    /// The panel the LCD is set into — white on the classic shell.
    public var panel: Color { palette.panel }

    public var panelEdge: Color { palette.panelEdge }

    /// Speaker grill slats.
    public var grill: Color { palette.grill }

    // MARK: Parts
    //
    // The three things on the chassis that emit light rather than merely being
    // moulded: the orb, the lit button, and the marquee. Everything above this
    // point is plastic; everything below it is powered, which is why these are
    // the parts worth varying — a skin reads as a different *device* when its
    // indicators are a different colour, and as a paint job when they are not.

    /// The glass orb on the island strip.
    public var orb: Color { palette.orb }

    /// Its halo. Deeper than `orb` in every case — the glow reads as the orb's
    /// own colour bleeding out, not as a second light behind it.
    public var orbGlow: Color { palette.orbGlow }

    /// Home, and anything else built to look powered.
    public var accent: ChassisAccent { palette.accent }

    /// Back and the user button.
    ///
    /// These were one dark cap on all five shells, on the argument that the
    /// mechanical controls should stay the same part across the range while only
    /// Home looked powered. In practice a near-black button reads as a hole
    /// punched in a bone or yellow shell — the two pale skins were the ones it
    /// suited least, and they are the ones whose real-world references had
    /// *light* buttons. The cap is moulded from the shell now, like the rest of
    /// the plastic; Home still reads as the lit one because it is the only thing
    /// on the chassis carrying a six-stop ramp and an inner disc.
    public var control: ChassisControl { palette.control }

    /// Per-button colours for the two console liveries (0.6.7, K2/K3).
    ///
    /// Nil on every other skin, which is the whole point of the hook: those
    /// keep one moulded cap for the three mechanical controls and the `accent`
    /// ramp for Home, exactly as they always have. Only the console skins
    /// colour-code the four face buttons individually, because on the hardware
    /// they are quoting that is the single thing anyone remembers about them.
    ///
    /// **Colours only.** The glyphs stay Vinodex's own — the chevron, the
    /// house, the person, the cog. No shape from either reference set is
    /// reproduced here, and the PSVino emblem that *was* a trademark is gone
    /// (see `drawnMark`). A palette is not a mark.
    ///
    /// Each button gets its face *and* its glyph from its own colour: the
    /// glyph is a pale (or, on a pale cap, a dark) form of the same hue rather
    /// than a flat white, so all four read as coloured parts rather than as
    /// coloured caps with the same white icon stamped on them. All four
    /// recolour — the brief is explicit that this is not a subset.
    public var buttonSet: ChassisButtonSet? {
        switch self {
        // **Four grey glyphs on four black caps** (0.8.91, D2).
        //
        // CLASSIC is the only skin here that is not a colour scheme. The other
        // three sets exist because their liveries paint each cap a different
        // colour; this one exists because CLASSIC's caps disagreed with each
        // other. Back, User and the cog resolved through `control` to near-black
        // stone with a **white** glyph, while Home resolved through `accent` to
        // an **amber** cap with dark amber ink — so one of the four buttons was
        // a different colour and a different ink from its three neighbours, on
        // the skin the device ships wearing.
        //
        // The type's header used to say "Vinodex Classic is deliberately
        // untouched", which was true of a default and not of a decision. §D2
        // makes it a decision and it goes here rather than in `control` and
        // `accent` separately, because this is the one hook that reaches all
        // four — including the `moldedCap` fallback, which resolves the same
        // pair of hexes.
        //
        // Home keeps a *ramp* rather than a flat black, because `ChassisAccent`
        // is what draws the moulded highlight and six identical stops would
        // render a disc. It is a black ramp: near-black through charcoal, with
        // the same grey ink the other three wear.
        case .classic:
            ChassisButtonSet(
                home: ChassisAccent(pale: "#57534e", light: "#3f3c39", bright: "#292524",
                                    mid: "#1c1917", edge: "#0c0a09", ink: "#a8a29e"),
                back: ChassisControl(top: "#292524", bottom: "#0c0a09", edge: "#57534e", glyph: "#a8a29e"),
                bookmarks: ChassisControl(top: "#292524", bottom: "#0c0a09", edge: "#57534e", glyph: "#a8a29e"),
                settings: ChassisControl(top: "#292524", bottom: "#0c0a09", edge: "#57534e", glyph: "#a8a29e")
            )
        // Green / red / blue / magenta-pink.
        case .psvino:
            ChassisButtonSet(
                home: ChassisAccent(pale: "#E6FBF7", light: "#9FE6DA", bright: "#3AC4B4",
                                    mid: "#1E9E90", edge: "#0B5C54", ink: "#04241F"),
                back: ChassisControl(top: "#F0435C", bottom: "#7E0C1C", edge: "#FF97A6", glyph: "#FFE3E8"),
                bookmarks: ChassisControl(top: "#6FA3E8", bottom: "#173D6B", edge: "#A9CBF5", glyph: "#E4EFFC"),
                settings: ChassisControl(top: "#E86FC0", bottom: "#6E1250", edge: "#F5A9DA", glyph: "#FCE4F3")
            )
        // Green / red / blue / yellow.
        case .vinhoVerde:
            ChassisButtonSet(
                home: ChassisAccent(pale: "#E4F7DF", light: "#A7E39A", bright: "#5CC246",
                                    mid: "#3A9A28", edge: "#1E5C14", ink: "#062A02"),
                back: ChassisControl(top: "#E5402F", bottom: "#7A1409", edge: "#FF9587", glyph: "#FFE2DE"),
                bookmarks: ChassisControl(top: "#3F8FE0", bottom: "#123C68", edge: "#9AC6F0", glyph: "#E2EEFA"),
                // Dark glyph on the yellow cap, per the Blanc de Blancs
                // precedent — a pale glyph on this one is unreadable.
                settings: ChassisControl(top: "#F2C130", bottom: "#7A5A05", edge: "#FBE08C", glyph: "#3A2A00")
            )
        // Green / blue / red / yellow (0.7.6, D1). The four-colour face is the
        // whole of this livery, and — per the note on the case — it is four
        // *colours*: Back, Home, User and the cog keep the house glyphs they
        // wear on every other shell, and no shape from any reference hardware
        // appears here.
        //
        // Home takes the green because it is the one control on the device
        // built to look powered. The yellow goes on the cog rather than on a
        // lamp, so all four colours appear at once on a device whose trio is
        // already carrying the other three.
        case .w64:
            ChassisButtonSet(
                home: ChassisAccent(pale: "#E8F8E6", light: "#A8E3A4", bright: "#63C86B",
                                    mid: "#3A9A44", edge: "#1E5C24", ink: "#062A08"),
                back: ChassisControl(top: "#D8343E", bottom: "#6E0C14", edge: "#F59098", glyph: "#FFE4E6"),
                bookmarks: ChassisControl(top: "#3E7FD8", bottom: "#123C74", edge: "#9AC2F0", glyph: "#E2EEFA"),
                // Dark glyph on the yellow cap, per the Blanc de Blancs
                // precedent — a pale glyph on this one is unreadable.
                settings: ChassisControl(top: "#F2C93A", bottom: "#7A6008", edge: "#FBE694", glyph: "#3A2E00")
            )
        default: nil
        }
    }

    /// Home's ramp for a bare skin (0.8.94/0.8.95) — the same rule
    /// `ChassisLook.homeAccent` applies after part overrides: the authored
    /// lit ramp where a livery has one, the cap's own material everywhere
    /// else.
    ///
    /// On the type as well as on the look because the *previews* take bare
    /// skins: `ChassisMockup` and the workshop schematic drew their home
    /// stand-ins straight from `accent`, which meant the pickers went on
    /// showing an accent-lit Home after A1 took it off the device — the last
    /// two accent-reads §A's diagnosis was about, found by the user's
    /// screenshots rather than by the invariant, which is why
    /// `FooterCapTests` now pins the two rules equal.
    public var homeAccent: ChassisAccent {
        buttonSet?.home ?? ChassisAccent(cap: control)
    }

    /// An original drawn mark, for the skins whose reference hardware's emblem
    /// is somebody's trademark (0.6.7, K1).
    ///
    /// PSVino carried `playstation.logo` — a real SF Symbol, and a real
    /// registered mark, which is not ours to ship however convenient the API
    /// makes it. It is replaced by a drawing of our own: see `SkinSigil`. The
    /// hook is general rather than a special case on `.psvino` so the next
    /// homage skin has somewhere to put its badge instead of reaching for a
    /// logo, and `symbol` keeps a neutral fallback for anything that only
    /// knows how to render a string.
    public var drawnMark: SkinMark? {
        switch self {
        case .psvino: .sigil
        // Not a trademark problem, an absent-glyph one: there is no pumpkin in
        // SF Symbols at the iOS 17 floor, and `symbol` therefore holds only a
        // neutral fallback for anything that can render nothing but a string.
        case .halloween: .pumpkin
        default: nil
        }
    }

    /// A per-skin glyph for the **user button**, or nil for the house one
    /// (0.7.0, B2/F1).
    ///
    /// Deliberately separate from `drawnMark`, which is the skin's *badge* — the
    /// thing on the picker tile and the back-plate sticker. This is a glyph on a
    /// mechanical control, and the two are different surfaces with different
    /// rules: `buttonSet` established that a skin may recolour the four face
    /// buttons, with the explicit caveat that the *glyphs* stay Vinodex's own.
    ///
    /// HALLOWEEN is the first skin to take a glyph as well, and it is worth
    /// being clear about why that does not reopen the caveat: the pumpkin is a
    /// drawing of ours, not a shape quoted from anybody's hardware. The rule was
    /// never "the glyphs never change", it was "we do not reproduce someone
    /// else's mark".
    ///
    /// Nil on twenty of twenty-one skins and costs them one optional check.
    public var userMark: SkinMark? {
        self == .halloween ? .pumpkin : nil
    }

    /// This skin's back plate (0.7.0, F1). See `BackPlateStyle`.
    ///
    /// Twenty of the twenty-one entries are built from the skin's *own* existing
    /// tokens — `panel`, `body`, `panelEdge`, `accent` — rather than from
    /// twenty-one hand-authored palettes. That is not laziness, it is the
    /// property that makes the hook survive: a skin whose shell colour is
    /// retuned gets a back that follows it, and a twenty-second skin gets a
    /// plate for free instead of one more table to forget.
    ///
    /// `.classic` is the exception in both directions: it is written out in
    /// literals, and those literals are the plate as it shipped.
    public var backPlate: BackPlateStyle {
        // The steel plate, verbatim. Do not derive this one — it is the
        // reference, and deriving it would move the baseline.
        if self == .classic {
            return BackPlateStyle(
                stops: ["#cdcfd2", "#9ea1a5", "#7e8186", "#b8babd"],
                finish: .brushed,
                edge: "#2b2d30",
                recess: "#57534e",
                ink: "#44403c",
                inkDeep: "#292524",
                screw: ["#e7e5e4", "#a8a29e", "#57534e"],
                screwRim: "#44403c"
            )
        }
        return BackPlateStyle(
            // Panel over body over body over panel: the same diagonal the steel
            // sheet runs, in this shell's two mouldings, so the plate catches
            // the light the way the front does.
            stops: [panelHex, bodyHex, bodyHex, panelHex],
            finish: plateFinish,
            edge: panelEdgeHex,
            recess: panelEdgeHex,
            ink: panelEdgeHex,
            inkDeep: panelEdgeHex,
            screw: [panelHex, bodyHex, panelEdgeHex],
            screwRim: panelEdgeHex
        )
    }

    /// The surface over the plate's base, which follows the front's.
    ///
    /// Reads `bodyPatternAsset` and `sketch` rather than declaring a second
    /// table: STEEL is brushed on both faces, OAKED is walnut on both faces,
    /// PÉT-NAT is paper on both faces. Anything with no front treatment is
    /// plain moulding, which is what plastic looks like from behind.
    private var plateFinish: BackPlateFinish {
        if let sketch { return .paper(sketch.grain) }
        if let asset = bodyPatternAsset { return .pattern(asset) }
        // Everything else is injection-moulded plastic, which has no grain.
        // Note that STAINLESS STEEL does *not* fall through to `.brushed` here:
        // it ships a `steel-brush` pattern and takes the branch above, so the
        // two faces wear the same machining rather than two different
        // approximations of it. `.brushed` is now CLASSIC's alone — the literal
        // aluminium sheet the plate has always been.
        return .moulded
    }

    // The plate is built from hex strings rather than from the `Color` values
    // the rest of this type exposes, because `BackPlateStyle` composes them into
    // gradients and SwiftUI gives no way to read a component back out of a
    // `Color`. These three are the same literals `body`, `panel` and `panelEdge`
    // resolve, kept beside them.
    private var bodyHex: String {
        switch self {
        case .classic: "#DC0A2D"
        case .midnight: "#17161A"
        case .original: "#D8D8D0"
        case .burgundy: "#4B1D3F"
        case .riesling: "#F2C11B"
        case .vinhoVerde: "#24402B"
        case .glouglou: "rgba(204,216,224,0.40)"
        case .smartGrape: "#1C1C1E"
        case .champagne: "#E8D5A6"
        case .christmas: "#1B4332"
        case .nouveau: "rgba(147,51,234,0.42)"
        case .oaked: "#5C4028"
        case .nocturne: "#C9F2BE"
        case .steel: "#C7CBD1"
        case .blush: "#EEA7B6"
        case .psvino: "#232427"
        case .grisDeGris: "#C8C4BC"
        case .orangeWine: "#E8720E"
        case .petNat: "#EFE9DC"
        case .waldglas: "rgba(160,183,116,0.42)"
        case .halloween: "#17141A"
        case .w64: "#4A2E8C"
        }
    }

    private var panelHex: String {
        switch self {
        case .classic: "#DEDEDE"
        case .midnight: "#2B2A30"
        case .original: "#EFEFE9"
        case .burgundy: "#D3BBCE"
        case .riesling: "#4A4F55"
        case .vinhoVerde: "#2E4F36"
        case .glouglou: "rgba(234,241,246,0.55)"
        case .smartGrape: "#2C2A28"
        case .champagne: "#F6EEDC"
        case .christmas: "#F4F7F2"
        case .nouveau: "rgba(216,180,254,0.50)"
        case .oaked: "#F2E8D5"
        case .nocturne: "#E9FBE0"
        case .steel: "#DDE0E4"
        case .blush: "#FBE9EC"
        case .psvino: "#3B3C41"
        case .grisDeGris: "#DAD6CE"
        case .orangeWine: "#F6A550"
        case .petNat: "#F8F4EA"
        case .waldglas: "rgba(214,229,178,0.55)"
        case .halloween: "#241E2B"
        case .w64: "#33206B"
        }
    }

    private var panelEdgeHex: String {
        switch self {
        case .classic: "#a8a29e"
        case .midnight: "#4A4852"
        case .original: "#9A9A93"
        case .burgundy: "#2C0F24"
        case .riesling: "#B9BEC4"
        case .vinhoVerde: "#16281B"
        case .glouglou: "rgba(148,163,184,0.85)"
        case .smartGrape: "#5A5148"
        case .champagne: "#B49B62"
        case .christmas: "#9CAF9C"
        case .nouveau: "rgba(233,213,255,0.90)"
        case .oaked: "#B5892E"
        case .nocturne: "#8FCB7C"
        case .steel: "#6B7078"
        case .blush: "#D2718A"
        case .psvino: "#141517"
        case .grisDeGris: "#8B8880"
        case .orangeWine: "#8A4406"
        case .petNat: "#2B3244"
        case .waldglas: "rgba(122,142,84,0.85)"
        case .halloween: "#0C0A10"
        case .w64: "#1D1145"
        }
    }

    /// How this skin's parts are drawn, or nil for the ordinary moulded ones
    /// (0.6.9, M1).
    ///
    /// Nil on eighteen of nineteen skins, which is the point of the hook: they
    /// keep the geometric rims, the gradients and the specular highlights that
    /// make a shell read as injection-moulded plastic, and they pay nothing —
    /// no shape, no canvas, no branch beyond one optional check per part.
    ///
    /// The one non-nil case is what M1 actually needs. Adding PÉT-NAT as
    /// nineteen more hexes would have produced a beige device, because what
    /// says "hand-drawn" is the line and not the colour. See
    /// `SketchRender.swift`, and `DeviceChassis`/`ChassisButton` for the four
    /// places that read this.
    ///
    /// A struct rather than a `Bool`, for `ChassisAccent`'s reason: the ink and
    /// the paper's tooth are only ever used together, and a second sketch skin
    /// (a red-pen one, say) should be a second pair of colours here rather than
    /// a second flag somewhere else.
    public var sketch: SketchStyle? {
        // Payne's grey rather than black: a pen line on paper is never actually
        // black, and a true #000 outline is the fastest way to make a drawn
        // thing look printed.
        self == .petNat ? SketchStyle(ink: "#2B3244", grain: "#B7AE99") : nil
    }

    /// Marquee phosphor. Period LED strips came in green, amber, red and blue,
    /// so this is the one part where a colour change is period-correct rather
    /// than merely decorative.
    public var marqueeText: Color { palette.marqueeText }

    /// The faint grid behind the phosphor, and the colour its letters are cut
    /// out of. One step deeper, so the strip still reads as glass over a grid.
    public var marqueeGrid: Color { palette.marqueeGrid }

    /// Hard drop shadow under each glyph on the strip — a very dark form of the
    /// phosphor, which is what makes the letters look lit rather than printed.
    public var marqueeShadow: Color { palette.marqueeShadow }

    // `next` retired in 0.7.6 (A1) — see the note where `LcdMode.next` was.

    /// Every flat value this skin owns, in one place.
    ///
    /// **This replaced sixteen parallel `switch self` statements.** They held no
    /// logic — 1,339 lines of `ChassisSkin` contain three conditional lines and
    /// no property reads another — so they were a constant table written in
    /// switch syntax, transposed: each column a function, each row repeated
    /// twenty-two times. Adding a skin meant editing sixteen switches in sixteen
    /// places and hoping none was missed.
    ///
    /// Grouped by skin because the skin is the thing that gets added. It stays a
    /// `switch` rather than a dictionary on purpose: the compiler then refuses a
    /// new case until it has every value, which a `[ChassisSkin: ...]` lookup
    /// would trade for a runtime `nil` and a force unwrap.
    ///
    /// Every expression here was moved verbatim from the switch it came from.
    private var palette: ChassisSkinPalette {
        switch self {
        case .classic:
            ChassisSkinPalette(
                section: .classic,
                // The house colourway, named for the house rather than described as
                // "classic" — every other skin here has a wine name, and the default
                // was the only one still labelled by category.
                displayName: "VINODEX CLASSIC",
                symbol: "gamecontroller.fill",
                // Amber, exactly as before.
                accent: ChassisAccent(pale: "#fef3c7", light: "#fde68a", bright: "#fbbf24", mid: "#f59e0b", edge: "#b45309", ink: "#78350f"),
                // Stone, exactly as before.
                control: ChassisControl(top: "#44403c", bottom: "#0c0a09", edge: "#a8a29e", glyph: "#ffffff"),
                globeTint: Color(dexHex: "#B8FFD6"),
                body: Dex.red,
                footerWash: Dex.red.opacity(0.7),
                panel: Dex.ui,
                panelEdge: Dex.stone400,
                grill: Dex.stone400,
                orb: Dex.cyan300,
                orbGlow: Dex.blue,
                marqueeText: Dex.green500,
                marqueeGrid: Dex.green,
                marqueeShadow: Color(dexHex: "#082010")
            )
        case .midnight:
            ChassisSkinPalette(
                section: .classic,
                displayName: "CÔTE DE NUITS",
                symbol: "moon.fill",
                accent: ChassisAccent(pale: "#f3e8ff", light: "#e9d5ff", bright: "#c084fc", mid: "#a855f7", edge: "#6b21a8", ink: "#3b0764"),
                control: ChassisControl(top: "#3b3746", bottom: "#0b0a10", edge: "#8b86a3", glyph: "#ffffff"),
                globeTint: Color(dexHex: "#D6B8FF"),
                body: Dex.graphite,
                footerWash: Dex.graphite.opacity(0.75),
                panel: Dex.graphitePanel,
                panelEdge: Dex.graphiteEdge,
                grill: Dex.stone600,
                // Pinot noir after dark: amethyst rather than ice.
                orb: Color(dexHex: "#d8b4fe"),
                orbGlow: Color(dexHex: "#a855f7"),
                marqueeText: Color(dexHex: "#c084fc"),
                marqueeGrid: Color(dexHex: "#a855f7"),
                marqueeShadow: Color(dexHex: "#1e0b32")
            )
        case .original:
            ChassisSkinPalette(
                section: .classic,
                displayName: "BLANC DE BLANCS",
                symbol: "sparkles",
                // Yellow — sunlight on the bone shell, and the one warm colour the
                // pale moulding leaves room for. (Was magenta, after the original
                // handheld's A/B buttons, which read as an error state on white.)
                accent: ChassisAccent(pale: "#fefce8", light: "#fef08a", bright: "#facc15", mid: "#eab308", edge: "#a16207", ink: "#713f12"),
                // Pale grey with a dark glyph — the original handheld's own d-pad.
                control: ChassisControl(top: "#c2c2ba", bottom: "#83837b", edge: "#5f5f59", glyph: "#262622"),
                globeTint: Color(dexHex: "#FFEDBB"),
                body: Dex.bone,
                footerWash: Dex.bone.opacity(0.75),
                panel: Dex.bonePanel,
                panelEdge: Dex.boneEdge,
                grill: Dex.stone400,
                // A champagne bead on the pale shell — cyan vanished against bone.
                orb: Color(dexHex: "#ffd76e"),
                orbGlow: Color(dexHex: "#f0b429"),
                marqueeText: Color(dexHex: "#fbbf24"),
                marqueeGrid: Color(dexHex: "#f59e0b"),
                marqueeShadow: Color(dexHex: "#301a02")
            )
        case .burgundy:
            ChassisSkinPalette(
                section: .wines,
                displayName: "BURGUNDY",
                symbol: "diamond.fill",
                // Deep purple, one shade brighter than the shell so Home still reads
                // as the powered part rather than more upholstery.
                accent: ChassisAccent(pale: "#ede9fe", light: "#ddd6fe", bright: "#8b5cf6", mid: "#6d28d9", edge: "#4c1d95", ink: "#2e1065"),
                // Deep purple caps, matching the accent ramp and the orb.
                control: ChassisControl(top: "#5b21b6", bottom: "#1e0a38", edge: "#a78bfa", glyph: "#ffffff"),
                globeTint: Color(dexHex: "#E4C0FF"),
                body: Dex.velour,
                footerWash: Dex.velour.opacity(0.75),
                panel: Dex.velourPanel,
                panelEdge: Dex.velourEdge,
                grill: Dex.velourEdge,
                // Deep purple, matching the buttons — the whole powered set on this
                // shell now runs one colour, like a single dye lot.
                orb: Color(dexHex: "#7c3aed"),
                orbGlow: Color(dexHex: "#5b21b6"),
                marqueeText: Color(dexHex: "#f9a8d4"),
                marqueeGrid: Color(dexHex: "#ec4899"),
                marqueeShadow: Color(dexHex: "#3b0723")
            )
        case .riesling:
            ChassisSkinPalette(
                section: .retrofit,
                // Renamed from ELECTRIC RIESLING (0.6.x) — label only, per the note
                // above; the yellow Walkman shell suits Jura's yellow wine as well.
                displayName: "VIN JAUNE",
                symbol: "bolt.fill",
                // Greys, to match the moulded caps — on this shell the red orb is the
                // only powered colour, which is what makes it a signal lamp.
                accent: ChassisAccent(pale: "#f4f5f6", light: "#d8dadd", bright: "#b6b9be", mid: "#8b8f95", edge: "#4b4f54", ink: "#1c1e21"),
                // Neutral grey — the blue cast the caps used to carry fought the
                // livery once the orb went red.
                control: ChassisControl(top: "#5a6068", bottom: "#14171c", edge: "#a7adb5", glyph: "#ffffff"),
                globeTint: Color(dexHex: "#FFF4A8"),
                body: Dex.walkman,
                footerWash: Dex.walkman.opacity(0.7),
                panel: Dex.walkmanPanel,
                panelEdge: Dex.walkmanEdge,
                grill: Dex.walkmanEdge,
                // A red signal lamp on the yellow shell — the one saturated colour the
                // grey-buttoned livery leaves room for.
                orb: Color(dexHex: "#ef4444"),
                orbGlow: Color(dexHex: "#b91c1c"),
                marqueeText: Dex.green500,
                marqueeGrid: Color(dexHex: "#16a34a"),
                marqueeShadow: Color(dexHex: "#082010")
            )
        case .vinhoVerde:
            ChassisSkinPalette(
                section: .retrofit,
                // Renamed labels only — the raw values are the persisted vocabulary
                // and stay put, per the note above. "VINHO VERDE" moved houses in
                // two steps: the forest-green skin became BOX WINE in 0.5.1, which
                // freed the name for the glow-green skin in 0.5.4.
                displayName: "BOX WINE",
                symbol: "shippingbox.fill",
                // Dark brown — the DMG's burgundy buttons aged into leather.
                accent: ChassisAccent(pale: "#E7D8C9", light: "#C8A98B", bright: "#8B5E3C", mid: "#6B4226", edge: "#3E2417", ink: "#241207"),
                control: ChassisControl(top: "#4B4F54", bottom: "#111316", edge: "#8A9096", glyph: "#ffffff"),
                globeTint: Color(dexHex: "#D9FFB8"),
                body: Color(dexHex: "#24402B"),
                footerWash: Color(dexHex: "#24402B").opacity(0.75),
                panel: Color(dexHex: "#2E4F36"),
                panelEdge: Color(dexHex: "#16281B"),
                grill: Color(dexHex: "#16281B"),
                // The DMG's own pea-green screen, reborn as a lamp.
                orb: Color(dexHex: "#9BBC0F"),
                orbGlow: Color(dexHex: "#8BAC0F"),
                marqueeText: Color(dexHex: "#9BBC0F"),
                marqueeGrid: Color(dexHex: "#8BAC0F"),
                marqueeShadow: Color(dexHex: "#0F380F")
            )
        case .glouglou:
            ChassisSkinPalette(
                section: .clearTech,
                displayName: "EMPTY BOTTLE",
                symbol: "wineglass.empty",
                accent: ChassisAccent(pale: "#FFEDD5", light: "#FED7AA", bright: "#FB923C", mid: "#F97316", edge: "#C2410C", ink: "#7C2D12"),
                // Clear caps: the rgba stops are what makes the buttons read as
                // moulded from the same smoke plastic as the shell.
                control: ChassisControl(top: "rgba(203,213,225,0.55)", bottom: "rgba(51,65,85,0.60)", edge: "rgba(226,232,240,0.90)", glyph: "#0F172A"),
                globeTint: Color(dexHex: "#FFD9B0"),
                // Smoke plastic — the only translucent body; see `underlay`.
                body: Color(dexHex: "rgba(204,216,224,0.40)"),
                footerWash: Color(dexHex: "rgba(204,216,224,0.28)"),
                panel: Color(dexHex: "rgba(234,241,246,0.55)"),
                panelEdge: Color(dexHex: "rgba(148,163,184,0.85)"),
                // Opaque on purpose: the slats sit over the internals and would
                // otherwise vanish into them.
                grill: Color(dexHex: "#64748B"),
                orb: Color(dexHex: "#FB923C"),
                orbGlow: Color(dexHex: "#EA580C"),
                marqueeText: Color(dexHex: "#FB923C"),
                marqueeGrid: Color(dexHex: "#F97316"),
                marqueeShadow: Color(dexHex: "#33130A")
            )
        case .smartGrape:
            ChassisSkinPalette(
                section: .retrofit,
                displayName: "SMART GRAPE",
                symbol: "plus.forwardslash.minus",
                // The operator key: calculator orange, lit.
                accent: ChassisAccent(pale: "#FFE8C7", light: "#FFC66E", bright: "#FF9F0A", mid: "#E08600", edge: "#8F5600", ink: "#3D2400"),
                // The number key: dark grey with the brown cast of the brief.
                control: ChassisControl(top: "#4A4239", bottom: "#151210", edge: "#8A7B6B", glyph: "#ffffff"),
                globeTint: Color(dexHex: "#FFCB79"),
                body: Color(dexHex: "#1C1C1E"),
                footerWash: Color(dexHex: "#1C1C1E").opacity(0.75),
                panel: Color(dexHex: "#2C2A28"),
                panelEdge: Color(dexHex: "#5A5148"),
                grill: Color(dexHex: "#5A5148"),
                // Calculator-orange, the operator key.
                orb: Color(dexHex: "#FF9F0A"),
                orbGlow: Color(dexHex: "#C97800"),
                marqueeText: Color(dexHex: "#FF9F0A"),
                marqueeGrid: Color(dexHex: "#E08600"),
                marqueeShadow: Color(dexHex: "#331F04")
            )
        case .champagne:
            ChassisSkinPalette(
                section: .wines,
                displayName: "CHAMPAGNE GOLD",
                symbol: "party.popper.fill",
                // Gold leaf, one register deeper than the shell.
                accent: ChassisAccent(pale: "#FDF6E3", light: "#F5E3AE", bright: "#E3BC5F", mid: "#C89B3C", edge: "#8A6820", ink: "#4A3510"),
                // Pale gold caps with a dark glyph, per the Blanc de Blancs precedent.
                control: ChassisControl(top: "#D8C48E", bottom: "#7A6535", edge: "#55431F", glyph: "#2E2410"),
                globeTint: Color(dexHex: "#FFF0C8"),
                body: Color(dexHex: "#E8D5A6"),
                footerWash: Color(dexHex: "#E8D5A6").opacity(0.75),
                panel: Color(dexHex: "#F6EEDC"),
                panelEdge: Color(dexHex: "#B49B62"),
                grill: Color(dexHex: "#B49B62"),
                // A gold bead in a gold shell — one dye lot, like burgundy's purple.
                orb: Color(dexHex: "#F5D97E"),
                orbGlow: Color(dexHex: "#D4A017"),
                marqueeText: Color(dexHex: "#F2C14E"),
                marqueeGrid: Color(dexHex: "#D4A017"),
                marqueeShadow: Color(dexHex: "#33240A")
            )
        case .christmas:
            ChassisSkinPalette(
                section: .festive,
                displayName: "WINE XMAS",
                symbol: "gift.fill",
                // Holly-berry red, to match the caps and the lights — the whole
                // powered set runs red on the wrapping paper. (Was bauble gold; the
                // orb keeps the fairy-light gold so the shell still carries both
                // Christmas colours.)
                accent: ChassisAccent(pale: "#FFE7E7", light: "#FFB3B3", bright: "#F25454", mid: "#D32F2F", edge: "#7A1010", ink: "#3D0000"),
                // The holly-berry caps.
                control: ChassisControl(top: "#C93B3B", bottom: "#5C1010", edge: "#E88A8A", glyph: "#ffffff"),
                globeTint: Color(dexHex: "#FFC2C2"),
                body: Color(dexHex: "#1B4332"),
                footerWash: Color(dexHex: "#1B4332").opacity(0.75),
                panel: Color(dexHex: "#F4F7F2"),
                panelEdge: Color(dexHex: "#9CAF9C"),
                grill: Color(dexHex: "#9CAF9C"),
                // Holly red, completing the set: caps, Home, lamps and orb all run
                // red on the wrapping paper (was fairy-light gold through 0.5.3).
                orb: Color(dexHex: "#FF4D4D"),
                orbGlow: Color(dexHex: "#A61E1E"),
                marqueeText: Color(dexHex: "#FF6B6B"),
                marqueeGrid: Color(dexHex: "#E03131"),
                marqueeShadow: Color(dexHex: "#240808")
            )
        case .nouveau:
            ChassisSkinPalette(
                section: .clearTech,
                // Renamed from NOUVEAU (v0.5.9, A1) — label only, per the note above.
                displayName: "RETROVIN",
                symbol: "cpu.fill",
                // Glossy grape juice — the whole powered set runs one purple.
                accent: ChassisAccent(pale: "#F3E8FF", light: "#D8B4FE", bright: "#A855F7", mid: "#7C3AED", edge: "#4C1D95", ink: "#2E1065"),
                // Clear purple caps, moulded from the same smoke as the shell.
                control: ChassisControl(top: "rgba(216,180,254,0.55)", bottom: "rgba(76,29,149,0.60)", edge: "rgba(233,213,255,0.90)", glyph: "#2E1065"),
                globeTint: Color(dexHex: "#DDBBFF"),
                // Atomic-purple smoke — translucent, like GLOUGLOU; see `underlay`.
                body: Color(dexHex: "rgba(147,51,234,0.42)"),
                footerWash: Color(dexHex: "rgba(147,51,234,0.30)"),
                panel: Color(dexHex: "rgba(216,180,254,0.50)"),
                panelEdge: Color(dexHex: "rgba(233,213,255,0.90)"),
                // Opaque over the internals, like GLOUGLOU's.
                grill: Color(dexHex: "#7C3AED"),
                // Grape juice under gloss.
                orb: Color(dexHex: "#A855F7"),
                orbGlow: Color(dexHex: "#7C3AED"),
                marqueeText: Color(dexHex: "#C084FC"),
                marqueeGrid: Color(dexHex: "#A855F7"),
                marqueeShadow: Color(dexHex: "#22083B")
            )
        case .oaked:
            ChassisSkinPalette(
                section: .vessel,
                displayName: "OAKED",
                symbol: "tree.fill",
                // Polished brass on the cream faceplate.
                accent: ChassisAccent(pale: "#F8EFD8", light: "#EFD9A0", bright: "#D9AE55", mid: "#B5892E", edge: "#7A5A14", ink: "#3D2B05"),
                // Walnut caps with a cream glyph, like inlay.
                control: ChassisControl(top: "#7A5A3A", bottom: "#2E2014", edge: "#A8865E", glyph: "#F2E8D5"),
                globeTint: Color(dexHex: "#FFDDAF"),
                // The walnut base the grain pattern sits over.
                body: Color(dexHex: "#5C4028"),
                // No wash at all (v0.5.9, A4). 0.5.8's frosted-pan fix swapped the
                // translucent wash for a solid deeper walnut, which traded the haze
                // for a solid bar — still a bar. The walnut grain runs uninterrupted
                // behind the footer now; the buttons sit directly on the deck.
                footerWash: Color.clear,
                // The cream faceplate against the walnut deck.
                panel: Color(dexHex: "#F2E8D5"),
                // A hint of brass around the cream.
                panelEdge: Color(dexHex: "#B5892E"),
                grill: Color(dexHex: "#8A6B45"),
                // A polished chestnut knob on the walnut (v0.5.8, C1 — was brass).
                // Lighter than the #5C4028 body so it still reads as a lamp.
                orb: Color(dexHex: "#B06A32"),
                orbGlow: Color(dexHex: "#7A4218"),
                marqueeText: Color(dexHex: "#FFB84D"),
                marqueeGrid: Color(dexHex: "#E69A28"),
                marqueeShadow: Color(dexHex: "#33200A")
            )
        case .nocturne:
            ChassisSkinPalette(
                section: .wines,
                displayName: "VINHO VERDE",
                symbol: "moon.zzz.fill",
                // The charged phosphor itself, lit.
                accent: ChassisAccent(pale: "#EFFFE8", light: "#C9F9B8", bright: "#8DF06A", mid: "#57D63E", edge: "#2E8A20", ink: "#0F3D08"),
                // Moulded from the luminous shell, one register deeper.
                control: ChassisControl(top: "#A9D89A", bottom: "#4E7A42", edge: "#6FA75E", glyph: "#123B0C"),
                globeTint: Color(dexHex: "#CCFFB8"),
                body: Color(dexHex: "#C9F2BE"),
                footerWash: Color(dexHex: "#C9F2BE").opacity(0.75),
                panel: Color(dexHex: "#E9FBE0"),
                panelEdge: Color(dexHex: "#8FCB7C"),
                grill: Color(dexHex: "#8FCB7C"),
                // The one part that is *always* charged.
                orb: Color(dexHex: "#7CFC9A"),
                orbGlow: Color(dexHex: "#3EE06C"),
                marqueeText: Color(dexHex: "#86FF7E"),
                marqueeGrid: Color(dexHex: "#57D63E"),
                marqueeShadow: Color(dexHex: "#0E2E0C")
            )
        case .steel:
            ChassisSkinPalette(
                section: .vessel,
                displayName: "STAINLESS STEEL",
                symbol: "gearshape.2.fill",
                // Cool steel-blue — powered, but restrained like the livery.
                accent: ChassisAccent(pale: "#F2F6FA", light: "#D7DEE6", bright: "#AEB9C6", mid: "#7E8A98", edge: "#454C56", ink: "#14181D"),
                // Machined caps with a dark glyph, per the Blanc de Blancs precedent.
                control: ChassisControl(top: "#B9BEC6", bottom: "#5E646C", edge: "#3E434B", glyph: "#14181D"),
                globeTint: Color(dexHex: "#CDE7FF"),
                // The aluminium base the brush pattern sits over.
                body: Color(dexHex: "#C7CBD1"),
                footerWash: Color(dexHex: "#B8BCC2").opacity(0.8),
                panel: Color(dexHex: "#DDE0E4"),
                panelEdge: Color(dexHex: "#6B7078"),
                grill: Color(dexHex: "#6B7078"),
                // Ice on silver.
                orb: Color(dexHex: "#E8F1FF"),
                orbGlow: Color(dexHex: "#9FB8D8"),
                marqueeText: Color(dexHex: "#9FD4FF"),
                marqueeGrid: Color(dexHex: "#5FA8E8"),
                marqueeShadow: Color(dexHex: "#0A1A2A")
            )
        case .blush:
            ChassisSkinPalette(
                section: .festive,
                displayName: "BLUSH",
                symbol: "heart.fill",
                // Hot-pink ramp on the pastel shell — the powered parts get the
                // saturation the moulding deliberately holds back.
                accent: ChassisAccent(pale: "#FFF1F4", light: "#FBCFE0", bright: "#F472B6", mid: "#DB2777", edge: "#9D174D", ink: "#500724"),
                // Pink caps one register deeper than the shell, dark glyph like the
                // other pale skins.
                control: ChassisControl(top: "#F5BBC9", bottom: "#C97F94", edge: "#8F4A5E", glyph: "#4A1220"),
                globeTint: Color(dexHex: "#FFCCDD"),
                // Soft rose-pink moulding.
                body: Color(dexHex: "#EEA7B6"),
                footerWash: Color(dexHex: "#EEA7B6").opacity(0.75),
                // The pale blush faceplate against the rose shell.
                panel: Color(dexHex: "#FBE9EC"),
                panelEdge: Color(dexHex: "#D2718A"),
                grill: Color(dexHex: "#C8879A"),
                // A pearl-pink bead — the one saturated light on the pastel shell.
                orb: Color(dexHex: "#FF7FA8"),
                orbGlow: Color(dexHex: "#E1447E"),
                // Pink phosphor — period LED strips never came in pink, but this is
                // the one skin allowed to care more about the look than the period.
                marqueeText: Color(dexHex: "#FF9EC0"),
                marqueeGrid: Color(dexHex: "#F472B6"),
                marqueeShadow: Color(dexHex: "#3B0A1E")
            )
        case .psvino:
            ChassisSkinPalette(
                section: .retrofit,
                displayName: "PSVINO",
                // The console emblem is gone (0.6.7, K1) - see `drawnMark`. This is
                // only the fallback for anything that still wants a plain symbol.
                symbol: "seal.fill",
                // Cross-button blue, lit — one restrained colour on the matte black,
                // the way the console itself wore it.
                accent: ChassisAccent(pale: "#E3EEFA", light: "#B9D2F0", bright: "#5B93D8", mid: "#2E6DB4", edge: "#173D6B", ink: "#0A1F38"),
                // The DualShock's own grey-black buttons.
                control: ChassisControl(top: "#3A3B40", bottom: "#101114", edge: "#6A6C72", glyph: "#ffffff"),
                // Console-boot blue — the cross button, paled for the multiply.
                globeTint: Color(dexHex: "#BBD4F5"),
                // DualShock matte charcoal — near-black with the plastic's warmth.
                body: Color(dexHex: "#232427"),
                footerWash: Color(dexHex: "#232427").opacity(0.75),
                // Console grey — the PS2's own two-tone: charcoal shell, grey deck.
                panel: Color(dexHex: "#3B3C41"),
                panelEdge: Color(dexHex: "#141517"),
                grill: Color(dexHex: "#55575E"),
                // The analog-stick LED: cross-button blue on the charcoal.
                orb: Color(dexHex: "#5B93D8"),
                orbGlow: Color(dexHex: "#2E6DB4"),
                // Boot-screen blue phosphor.
                marqueeText: Color(dexHex: "#7DB2F0"),
                marqueeGrid: Color(dexHex: "#2E6DB4"),
                marqueeShadow: Color(dexHex: "#08182E")
            )
        case .grisDeGris:
            ChassisSkinPalette(
                section: .retrofit,
                displayName: "GRIS DE GRIS",
                // The brick's own control: a d-pad.
                symbol: "dpad.fill",
                // The brick's red face buttons - the one saturated colour on the grey.
                accent: ChassisAccent(pale: "#FFE5E5", light: "#FFB3B3", bright: "#E23E3E", mid: "#C22626", edge: "#7A1414", ink: "#3D0505"),
                // Red caps on the grey shell.
                control: ChassisControl(top: "#D8484E", bottom: "#8A1F24", edge: "#F0989C", glyph: "#ffffff"),
                // The DMG screen's own pea-green, paled for the multiply.
                globeTint: Color(dexHex: "#DCE8C4"),
                // Warm handheld grey, a shade off neutral the way ABS ages.
                body: Color(dexHex: "#C8C4BC"),
                footerWash: Color(dexHex: "#C8C4BC").opacity(0.75),
                // The lighter grey faceplate the original brick set its screen into.
                panel: Color(dexHex: "#DAD6CE"),
                panelEdge: Color(dexHex: "#8B8880"),
                grill: Color(dexHex: "#9A968E"),
                // The power lamp, in the caps own red.
                orb: Color(dexHex: "#E23E3E"),
                orbGlow: Color(dexHex: "#8F1414"),
                // The pea-green screen, kept as the one thing on this device that is
                // still a display. Stepped off BOX WINE #9BBC0F so the two handheld
                // homages do not glow the identical green.
                marqueeText: Color(dexHex: "#A6C550"),
                marqueeGrid: Color(dexHex: "#7E9B2E"),
                marqueeShadow: Color(dexHex: "#16240A")
            )
        case .orangeWine:
            ChassisSkinPalette(
                section: .retrofit,
                displayName: "ORANGE WINE",
                symbol: "exclamationmark.triangle.fill",
                // Black, and deliberately: J2 asks for black buttons, so the *lit*
                // button is black too. `ink` is pale rather than dark because Home's
                // inner disc runs pale->bright, which on this ramp is a dark disc.
                accent: ChassisAccent(pale: "#6E6E70", light: "#4A4A4C", bright: "#2A2A2C", mid: "#161617", edge: "#0A0A0B", ink: "#F2EFEA"),
                // Black caps on the warning orange.
                control: ChassisControl(top: "#3A3A3C", bottom: "#0B0B0C", edge: "#6E6E70", glyph: "#ffffff"),
                globeTint: Color(dexHex: "#FFDF8A"),
                body: Color(dexHex: "#E8720E"),
                footerWash: Color(dexHex: "#E8720E").opacity(0.75),
                panel: Color(dexHex: "#F6A550"),
                panelEdge: Color(dexHex: "#8A4406"),
                grill: Color(dexHex: "#A85708"),
                // Hazard yellow: the buttons are black, so the orb is the only thing
                // on this shell allowed to look lit.
                orb: Color(dexHex: "#FFD22E"),
                orbGlow: Color(dexHex: "#C99000"),
                marqueeText: Color(dexHex: "#FFC93C"),
                marqueeGrid: Color(dexHex: "#E0A100"),
                marqueeShadow: Color(dexHex: "#33220A")
            )
        case .petNat:
            ChassisSkinPalette(
                section: .vessel,
                // PÉT-NAT → FIBERGLASS (0.7.5, A4). Label only, per the note above,
                // and the note is load-bearing on this case in particular: the rawValue
                // `"PET NAT"` is the `chassisSkin` `@AppStorage` value on every install
                // wearing this shell, the FNV-1a seed `WornSeed.of(skin.rawValue)`
                // draws the back plate's procedural wear from, and the stem
                // `stickerStem` derives (`sticker-pet-nat`). Moving it would reset the
                // shell, repaint the wear on the devices that survived, and orphan the
                // sticker — the exact three costs HALLOWINE's rename was written up to
                // avoid. Checked rather than assumed: `"PET NAT"` appears nowhere in
                // `shared/`, the generated JSON or the art scripts. (The `petnat`
                // hits in `icons.json` and `art/icons/entries/styles/` are the *wine style*
                // Pétillant Naturel and have nothing to do with this skin.)
                displayName: "FIBERGLASS",
                // The pen that drew the shell.
                symbol: "pencil.and.outline",
                // Pencil greys with a blue-black rim. Deliberately the flattest
                // ramp in the range: the six stops exist to make a cap look
                // moulded, and this cap is meant to look drawn.
                accent: ChassisAccent(pale: "#FBF8F1", light: "#E6E0D2", bright: "#C9C2B2", mid: "#A79F8E", edge: "#2B3244", ink: "#2B3244"),
                // Paper caps with an ink glyph, per the Blanc de Blancs
                // precedent — white on paper is nothing at all.
                control: ChassisControl(top: "#FBF8F1", bottom: "#DED7C7", edge: "#2B3244", glyph: "#2B3244"),
                // Pencil blue on paper — the one skin whose globe should look
                // like a drawing of a globe.
                globeTint: Color(dexHex: "#DCE3F0"),
                // Cartridge paper, slightly warm — pure white reads as a blank
                // canvas rather than as a sheet somebody drew on.
                body: Color(dexHex: "#EFE9DC"),
                // No wash, like OAKED: a translucent bar across a sheet of paper
                // is a smudge. The grain runs uninterrupted under the buttons.
                footerWash: Color.clear,
                // A second sheet laid on the first, a shade brighter.
                panel: Color(dexHex: "#F8F4EA"),
                // The ink itself — the geometric rim is drawn at very low
                // opacity under the hand line, so the two do not read as two
                // outlines. See `DeviceChassis.screenHousing`.
                panelEdge: Color(dexHex: "#2B3244"),
                grill: Color(dexHex: "#4A5468"),
                // A wash of ink where the lamp is — the drawn device's one
                // concession to looking powered.
                orb: Color(dexHex: "#7FA6D8"),
                orbGlow: Color(dexHex: "#3E6FA8"),
                // A highlighter stripe. The one panel on the device that is
                // filled rather than outlined, because a marquee has to read as
                // lit and there is no drawn equivalent of lit.
                marqueeText: Color(dexHex: "#E8DF7A"),
                marqueeGrid: Color(dexHex: "#BFB55A"),
                marqueeShadow: Color(dexHex: "#2B3244")
            )
        case .waldglas:
            ChassisSkinPalette(
                section: .clearTech,
                displayName: "WALDGLAS",
                // Forest glass, named for the woods it was blown in.
                symbol: "leaf.circle.fill",
                // The glass itself, lit — one dye lot, like BURGUNDY's purple.
                accent: ChassisAccent(pale: "#F0F7DE", light: "#D7E8AE", bright: "#A8C766", mid: "#7E9A3E", edge: "#48601E", ink: "#1F2C0A"),
                // Clear green caps, moulded from the same glass as the shell.
                control: ChassisControl(top: "rgba(203,222,160,0.55)", bottom: "rgba(72,96,30,0.60)", edge: "rgba(226,238,200,0.90)", glyph: "#1F2C0A"),
                // Seen through bottle glass.
                globeTint: Color(dexHex: "#DCEAC0"),
                // Olive-green smoke — translucent, like GLOUGLOU; see `underlay`.
                // The colour iron in wood ash gives glass nobody decolourised.
                body: Color(dexHex: "rgba(160,183,116,0.42)"),
                footerWash: Color(dexHex: "rgba(160,183,116,0.28)"),
                panel: Color(dexHex: "rgba(214,229,178,0.55)"),
                panelEdge: Color(dexHex: "rgba(122,142,84,0.85)"),
                // Opaque over the internals, like GLOUGLOU's and RETROVIN's.
                grill: Color(dexHex: "#6C8348"),
                // A bright bead of the same glass, lit from behind.
                orb: Color(dexHex: "#C9E86A"),
                orbGlow: Color(dexHex: "#7A9A2E"),
                marqueeText: Color(dexHex: "#B8D96A"),
                marqueeGrid: Color(dexHex: "#8AA83E"),
                marqueeShadow: Color(dexHex: "#1A240A")
            )
        case .halloween:
            ChassisSkinPalette(
                section: .festive,
                // HALLOWEEN → HALLOWINE (0.7.1, C4). Label only — the rawValue is the
                // `@AppStorage` key *and* the seed for the back plate's procedural wear
                // (see `WornSeed.of`), so moving it would both reset every device
                // wearing this shell and repaint the ones that survived.
                displayName: "HALLOWINE",
                // The neutral fallback only. This skin's emblem is a drawing —
                // SF Symbols has no pumpkin at the iOS 17 floor. See `drawnMark`.
                symbol: "moon.haze.fill",
                // Pumpkin orange, and it is the only colour on the shell.
                accent: ChassisAccent(pale: "#FFEBD4", light: "#FFC98A", bright: "#FF8A1F", mid: "#E0670A", edge: "#8A3A00", ink: "#331500"),
                // Black caps with an orange glyph — the two colours, and only the
                // two colours.
                control: ChassisControl(top: "#2A2530", bottom: "#0A080C", edge: "#5E5468", glyph: "#FF8A1F"),
                // Jack-o'-lantern light.
                globeTint: Color(dexHex: "#FFD6A8"),
                // Not black: a true #000 shell has no moulding in it at all. This
                // is near-black with a violet cast, which is what reads as night.
                body: Color(dexHex: "#17141A"),
                footerWash: Color(dexHex: "#17141A").opacity(0.75),
                panel: Color(dexHex: "#241E2B"),
                panelEdge: Color(dexHex: "#0C0A10"),
                grill: Color(dexHex: "#4A3F55"),
                // The candle inside the lantern — the one lit thing on a shell
                // whose buttons are deliberately unlit.
                orb: Color(dexHex: "#FF8A1F"),
                orbGlow: Color(dexHex: "#B34700"),
                marqueeText: Color(dexHex: "#FFA23C"),
                marqueeGrid: Color(dexHex: "#E0670A"),
                marqueeShadow: Color(dexHex: "#2B1200")
            )
        case .w64:
            ChassisSkinPalette(
                section: .retrofit,
                // The one skin whose label and stored word are the same string on
                // purpose (0.7.6, D1). This switch is exhaustive rather than defaulted,
                // so the entry is required either way — but it is worth saying that the
                // agreement is deliberate: every rename note in this file is about the
                // cost of a label that has drifted from its rawValue, and picking a name
                // that never needs to drift is the cheapest version of that.
                displayName: "W64",
                // Four coloured points around a centre: what this livery *is*, taken
                // from the house's own symbol set rather than quoted from anyone's
                // hardware. SF Symbols 2 / iOS 14, well under the floor, and it
                // collides with nothing — `circle.grid.2x2.fill` is a workshop axis
                // glyph and `circle.grid.3x3.fill` is GRAPES.
                symbol: "circle.grid.cross.fill",
                // Never read on this skin — `buttonSet` below gives Home its own green
                // ramp, exactly as it does for the two existing console liveries.
                // Present so the switch stays exhaustive, and so anything asking a skin
                // for "its one accent" gets the green rather than nothing.
                accent: ChassisAccent(pale: "#E8F8E6", light: "#A8E3A4", bright: "#63C86B", mid: "#3A9A44", edge: "#1E5C24", ink: "#062A08"),
                // Never read on this skin either — see `accent` above and `buttonSet`
                // below. Violet moulding a register off the shell, so a caller that
                // bypasses the set still gets a cap belonging to this device.
                control: ChassisControl(top: "#6A4BB8", bottom: "#221448", edge: "#A98EE8", glyph: "#ffffff"),
                // The shell's own violet, paled for the multiply.
                globeTint: Color(dexHex: "#DCC8F5"),
                // Grape violet, and opaque: the reference era is remembered for
                // translucency, and a fourth clear shell would file this under
                // CLEARTECH beside three skins it has nothing else in common with.
                // The colour is the quotation; the plastic is ours.
                body: Color(dexHex: "#4A2E8C"),
                footerWash: Color(dexHex: "#4A2E8C").opacity(0.75),
                // A deeper violet faceplate, so the LCD is set into the shell rather
                // than floating on it.
                panel: Color(dexHex: "#33206B"),
                panelEdge: Color(dexHex: "#1D1145"),
                grill: Color(dexHex: "#8B6FD4"),
                // The power lamp, in the fourth face colour — the one this livery
                // has spare once green, blue and red are on the lamp trio.
                orb: Color(dexHex: "#F2C93A"),
                orbGlow: Color(dexHex: "#B58A0C"),
                // Period-correct green, and the fifth green strip in the range —
                // stepped clear of BOX WINE's #9BBC0F and GRIS DE GRIS's #A6C550 so
                // the three homages do not glow the identical colour, which is the
                // note GRIS DE GRIS's own entry above records.
                marqueeText: Color(dexHex: "#7FD98A"),
                marqueeGrid: Color(dexHex: "#3A9A44"),
                marqueeShadow: Color(dexHex: "#08240E")
            )
        }
    }
}

#endif
