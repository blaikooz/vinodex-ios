#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

// The chassis's *value* types: what a shell is made of, rather than how it is
// drawn. Six small declarations that `ChassisSkin` hands out and that
// `ChassisButton`, `DeviceBackPlate`, `SkinEmblem` and `ChassisLook` read
// back — a colour with components, a set of face-button liveries, a drawn
// line, an emblem, a back plate and its finish.
//
// They live together because they share one shape: each is a bundle of stops
// that is only ever used whole. `ChassisAccent`'s doc comment makes the
// argument once and the rest inherit it — a skin that got four values of a
// ramp right and two from the previous colourway reads as a manufacturing
// fault rather than as a mistake in the code, so the ramp is one type and a
// skin either has it or does not.
//
// They live *here* rather than in `ChassisSkins.swift` because that file is
// the colour catalogue — one long `extension ChassisSkin` of per-skin tables —
// and these are the vocabulary those tables are written in. Splitting them out
// keeps the catalogue readable and gives `DeviceParts`, which composes the same
// vocabulary from a workshop build rather than from a skin, somewhere to point
// that is not the catalogue. Carried over from DexTheme.swift, which this
// refactor dissolved (AUDIT **M30**); nothing in the move changed a value.

// MARK: - Colour arithmetic

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

// MARK: - Face buttons

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

// MARK: - Drawn shells and emblems

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
    ///
    /// How a mark is *drawn* stays in `SkinMarkView`'s switch rather than
    /// becoming a flag here: the sigil is three open strokes and has to be
    /// stroked, the lantern is a silhouette with its face cut out and has to be
    /// filled `eoFill`, and a third mark will have its own answer that no
    /// `isStroked` boolean would have covered. An exhaustive switch in one
    /// renderer is the thing that will not compile until that answer exists.
    case pumpkin
}

// MARK: - Back plate

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
#endif
