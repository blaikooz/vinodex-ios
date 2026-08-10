#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

// The skin catalogue's colours — a range of devices rather than one device in
// a set of colourways (v0.4.2.1), each carrying its own accent ramp, control
// livery, back plate and marquee phosphor.
//
// `ChassisSkin` itself — the cases, the persisted raw values, the storage key,
// the labels, the emblems and the picker sections — moved to
// `Sources/VinodexCore/ChassisSkin.swift` (arch **A6**), and the value types
// the tables below are written in — `DexRGB`, `ChassisButtonSet`,
// `SketchStyle`, `SkinMark`, `BackPlateStyle`, `BackPlateFinish` — to
// `ChassisStyle.swift` beside this file. What is left here is the catalogue
// proper: the half that needs `Color`, plus the two part descriptions it is
// built from. The file was split out of DexTheme.swift by AUDIT **M30**;
// nothing in any of those moves changed a value.

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
    /// The last two stops as strings (0.8.98), for `ChassisControl(litRamp:)`
    /// — the adapter that restates an authored lit-Home ramp as the moulded
    /// cap the one button pass draws. Same trade as `lightHex`, same reader
    /// count: the caller has the string at init and nowhere afterwards.
    public let midHex: String
    public let edgeHex: String

    public init(pale: String, light: String, bright: String, mid: String, edge: String, ink: String) {
        self.lightHex = light
        self.inkHex = ink
        self.midHex = mid
        self.edgeHex = edge
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

public extension ChassisControl {
    /// An authored lit-Home ramp, restated as the moulded cap it colours
    /// (0.8.98) — the adapter that runs the other way from
    /// `ChassisAccent(cap:)`.
    ///
    /// **This is how "lit" stopped being a code path.** Through 0.8.97 a
    /// console livery's Home travelled as a `ChassisAccent` all the way into
    /// `ChassisButton`, which kept a `.home` branch alive at every read the
    /// ramp reached — and §A's history is that every such branch eventually
    /// disagrees with its neighbours. Restating the ramp as a `ChassisControl`
    /// at the *resolution* step means the buttons' view code has exactly one
    /// colour model and cannot tell Home apart: a lit Home is a cap that
    /// happens to be bright.
    ///
    /// `top` takes the ramp's `light` — the face `ChassisButton` has re-inked
    /// the drawn cap with since 0.8.2 — so a console Home's drawn face is
    /// byte-identical to what it was; `bottom` its `mid`, `edge` its `edge`,
    /// `glyph` its `ink`, each the stop the old branch read for that surface.
    init(litRamp ramp: ChassisAccent) {
        self.init(
            top: ramp.lightHex,
            bottom: ramp.midHex,
            edge: ramp.edgeHex,
            glyph: ramp.inkHex
        )
    }
}

extension ChassisSkin {
    /// A soft halo around the screen housing — NOCTURNE's glow-in-the-dark
    /// charge. Nil everywhere else; the chassis applies it as a shadow, so
    /// an absent glow costs nothing.
    public var rimGlow: Color? {
        self == .nocturne ? Color(dexHex: "#A8FF96") : nil
    }

    /// The globe screen's sphere tint (0.6.2, F1) — every skin sees the world
    /// through its own colour. Pale on purpose: the tint multiplies over the
    /// map texture, so a saturated dark here would swallow the coastlines.
    public var globeTint: Color {
        switch self {
        case .classic: Color(dexHex: "#B8FFD6")
        case .midnight: Color(dexHex: "#D6B8FF")
        case .original: Color(dexHex: "#FFEDBB")
        case .burgundy: Color(dexHex: "#E4C0FF")
        case .riesling: Color(dexHex: "#FFF4A8")
        case .vinhoVerde: Color(dexHex: "#D9FFB8")
        case .glouglou: Color(dexHex: "#FFD9B0")
        case .smartGrape: Color(dexHex: "#FFCB79")
        case .champagne: Color(dexHex: "#FFF0C8")
        case .christmas: Color(dexHex: "#FFC2C2")
        case .nouveau: Color(dexHex: "#DDBBFF")
        case .oaked: Color(dexHex: "#FFDDAF")
        case .nocturne: Color(dexHex: "#CCFFB8")
        case .steel: Color(dexHex: "#CDE7FF")
        case .blush: Color(dexHex: "#FFCCDD")
        // Console-boot blue — the cross button, paled for the multiply.
        case .psvino: Color(dexHex: "#BBD4F5")
        // The DMG screen's own pea-green, paled for the multiply.
        case .grisDeGris: Color(dexHex: "#DCE8C4")
        case .orangeWine: Color(dexHex: "#FFDF8A")
        // Pencil blue on paper — the one skin whose globe should look
        // like a drawing of a globe.
        case .petNat: Color(dexHex: "#DCE3F0")
        // Seen through bottle glass.
        case .waldglas: Color(dexHex: "#DCEAC0")
        // Jack-o'-lantern light.
        case .halloween: Color(dexHex: "#FFD6A8")
        // The shell's own violet, paled for the multiply.
        case .w64: Color(dexHex: "#DCC8F5")
        }
    }

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
    public var body: Color {
        switch self {
        case .classic: Dex.red
        case .midnight: Dex.graphite
        case .original: Dex.bone
        case .burgundy: Dex.velour
        case .riesling: Dex.walkman
        case .vinhoVerde: Color(dexHex: "#24402B")
        // Smoke plastic — the only translucent body; see `underlay`.
        case .glouglou: Color(dexHex: "rgba(204,216,224,0.40)")
        case .smartGrape: Color(dexHex: "#1C1C1E")
        case .champagne: Color(dexHex: "#E8D5A6")
        case .christmas: Color(dexHex: "#1B4332")
        // Atomic-purple smoke — translucent, like GLOUGLOU; see `underlay`.
        case .nouveau: Color(dexHex: "rgba(147,51,234,0.42)")
        // The walnut base the grain pattern sits over.
        case .oaked: Color(dexHex: "#5C4028")
        case .nocturne: Color(dexHex: "#C9F2BE")
        // The aluminium base the brush pattern sits over.
        case .steel: Color(dexHex: "#C7CBD1")
        // Soft rose-pink moulding.
        case .blush: Color(dexHex: "#EEA7B6")
        // DualShock matte charcoal — near-black with the plastic's warmth.
        case .psvino: Color(dexHex: "#232427")
        // Warm handheld grey, a shade off neutral the way ABS ages.
        case .grisDeGris: Color(dexHex: "#C8C4BC")
        case .orangeWine: Color(dexHex: "#E8720E")
        // Cartridge paper, slightly warm — pure white reads as a blank
        // canvas rather than as a sheet somebody drew on.
        case .petNat: Color(dexHex: "#EFE9DC")
        // Olive-green smoke — translucent, like GLOUGLOU; see `underlay`.
        // The colour iron in wood ash gives glass nobody decolourised.
        case .waldglas: Color(dexHex: "rgba(160,183,116,0.42)")
        // Not black: a true #000 shell has no moulding in it at all. This
        // is near-black with a violet cast, which is what reads as night.
        case .halloween: Color(dexHex: "#17141A")
        // Grape violet, and opaque: the reference era is remembered for
        // translucency, and a fourth clear shell would file this under
        // CLEARTECH beside three skins it has nothing else in common with.
        // The colour is the quotation; the plastic is ours.
        case .w64: Color(dexHex: "#4A2E8C")
        }
    }

    /// Wash behind the footer row, a shade off the body.
    public var footerWash: Color {
        switch self {
        case .classic: Dex.red.opacity(0.7)
        case .midnight: Dex.graphite.opacity(0.75)
        case .original: Dex.bone.opacity(0.75)
        case .burgundy: Dex.velour.opacity(0.75)
        case .riesling: Dex.walkman.opacity(0.7)
        case .vinhoVerde: Color(dexHex: "#24402B").opacity(0.75)
        case .glouglou: Color(dexHex: "rgba(204,216,224,0.28)")
        case .smartGrape: Color(dexHex: "#1C1C1E").opacity(0.75)
        case .champagne: Color(dexHex: "#E8D5A6").opacity(0.75)
        case .christmas: Color(dexHex: "#1B4332").opacity(0.75)
        case .nouveau: Color(dexHex: "rgba(147,51,234,0.30)")
        // No wash at all (v0.5.9, A4). 0.5.8's frosted-pan fix swapped the
        // translucent wash for a solid deeper walnut, which traded the haze
        // for a solid bar — still a bar. The walnut grain runs uninterrupted
        // behind the footer now; the buttons sit directly on the deck.
        case .oaked: Color.clear
        case .nocturne: Color(dexHex: "#C9F2BE").opacity(0.75)
        case .steel: Color(dexHex: "#B8BCC2").opacity(0.8)
        case .blush: Color(dexHex: "#EEA7B6").opacity(0.75)
        case .psvino: Color(dexHex: "#232427").opacity(0.75)
        case .grisDeGris: Color(dexHex: "#C8C4BC").opacity(0.75)
        case .orangeWine: Color(dexHex: "#E8720E").opacity(0.75)
        // No wash, like OAKED: a translucent bar across a sheet of paper
        // is a smudge. The grain runs uninterrupted under the buttons.
        case .petNat: Color.clear
        case .waldglas: Color(dexHex: "rgba(160,183,116,0.28)")
        case .halloween: Color(dexHex: "#17141A").opacity(0.75)
        case .w64: Color(dexHex: "#4A2E8C").opacity(0.75)
        }
    }

    /// The panel the LCD is set into — white on the classic shell.
    public var panel: Color {
        switch self {
        case .classic: Dex.ui
        case .midnight: Dex.graphitePanel
        case .original: Dex.bonePanel
        case .burgundy: Dex.velourPanel
        case .riesling: Dex.walkmanPanel
        case .vinhoVerde: Color(dexHex: "#2E4F36")
        case .glouglou: Color(dexHex: "rgba(234,241,246,0.55)")
        case .smartGrape: Color(dexHex: "#2C2A28")
        case .champagne: Color(dexHex: "#F6EEDC")
        case .christmas: Color(dexHex: "#F4F7F2")
        case .nouveau: Color(dexHex: "rgba(216,180,254,0.50)")
        // The cream faceplate against the walnut deck.
        case .oaked: Color(dexHex: "#F2E8D5")
        case .nocturne: Color(dexHex: "#E9FBE0")
        case .steel: Color(dexHex: "#DDE0E4")
        // The pale blush faceplate against the rose shell.
        case .blush: Color(dexHex: "#FBE9EC")
        // Console grey — the PS2's own two-tone: charcoal shell, grey deck.
        case .psvino: Color(dexHex: "#3B3C41")
        // The lighter grey faceplate the original brick set its screen into.
        case .grisDeGris: Color(dexHex: "#DAD6CE")
        case .orangeWine: Color(dexHex: "#F6A550")
        // A second sheet laid on the first, a shade brighter.
        case .petNat: Color(dexHex: "#F8F4EA")
        case .waldglas: Color(dexHex: "rgba(214,229,178,0.55)")
        case .halloween: Color(dexHex: "#241E2B")
        // A deeper violet faceplate, so the LCD is set into the shell rather
        // than floating on it.
        case .w64: Color(dexHex: "#33206B")
        }
    }

    public var panelEdge: Color {
        switch self {
        case .classic: Dex.stone400
        case .midnight: Dex.graphiteEdge
        case .original: Dex.boneEdge
        case .burgundy: Dex.velourEdge
        case .riesling: Dex.walkmanEdge
        case .vinhoVerde: Color(dexHex: "#16281B")
        case .glouglou: Color(dexHex: "rgba(148,163,184,0.85)")
        case .smartGrape: Color(dexHex: "#5A5148")
        case .champagne: Color(dexHex: "#B49B62")
        case .christmas: Color(dexHex: "#9CAF9C")
        case .nouveau: Color(dexHex: "rgba(233,213,255,0.90)")
        // A hint of brass around the cream.
        case .oaked: Color(dexHex: "#B5892E")
        case .nocturne: Color(dexHex: "#8FCB7C")
        case .steel: Color(dexHex: "#6B7078")
        case .blush: Color(dexHex: "#D2718A")
        case .psvino: Color(dexHex: "#141517")
        case .grisDeGris: Color(dexHex: "#8B8880")
        case .orangeWine: Color(dexHex: "#8A4406")
        // The ink itself — the geometric rim is drawn at very low
        // opacity under the hand line, so the two do not read as two
        // outlines. See `DeviceChassis.screenHousing`.
        case .petNat: Color(dexHex: "#2B3244")
        case .waldglas: Color(dexHex: "rgba(122,142,84,0.85)")
        case .halloween: Color(dexHex: "#0C0A10")
        case .w64: Color(dexHex: "#1D1145")
        }
    }

    /// Speaker grill slats.
    public var grill: Color {
        switch self {
        case .classic: Dex.stone400
        case .midnight: Dex.stone600
        case .original: Dex.stone400
        case .burgundy: Dex.velourEdge
        case .riesling: Dex.walkmanEdge
        case .vinhoVerde: Color(dexHex: "#16281B")
        // Opaque on purpose: the slats sit over the internals and would
        // otherwise vanish into them.
        case .glouglou: Color(dexHex: "#64748B")
        case .smartGrape: Color(dexHex: "#5A5148")
        case .champagne: Color(dexHex: "#B49B62")
        case .christmas: Color(dexHex: "#9CAF9C")
        // Opaque over the internals, like GLOUGLOU's.
        case .nouveau: Color(dexHex: "#7C3AED")
        case .oaked: Color(dexHex: "#8A6B45")
        case .nocturne: Color(dexHex: "#8FCB7C")
        case .steel: Color(dexHex: "#6B7078")
        case .blush: Color(dexHex: "#C8879A")
        case .psvino: Color(dexHex: "#55575E")
        case .grisDeGris: Color(dexHex: "#9A968E")
        case .orangeWine: Color(dexHex: "#A85708")
        case .petNat: Color(dexHex: "#4A5468")
        // Opaque over the internals, like GLOUGLOU's and RETROVIN's.
        case .waldglas: Color(dexHex: "#6C8348")
        case .halloween: Color(dexHex: "#4A3F55")
        case .w64: Color(dexHex: "#8B6FD4")
        }
    }

    // MARK: Parts
    //
    // The three things on the chassis that emit light rather than merely being
    // moulded: the orb, the lit button, and the marquee. Everything above this
    // point is plastic; everything below it is powered, which is why these are
    // the parts worth varying — a skin reads as a different *device* when its
    // indicators are a different colour, and as a paint job when they are not.

    /// The glass orb on the island strip.
    public var orb: Color {
        switch self {
        case .classic: Dex.cyan300
        // Pinot noir after dark: amethyst rather than ice.
        case .midnight: Color(dexHex: "#d8b4fe")
        // A champagne bead on the pale shell — cyan vanished against bone.
        case .original: Color(dexHex: "#ffd76e")
        // Deep purple, matching the buttons — the whole powered set on this
        // shell now runs one colour, like a single dye lot.
        case .burgundy: Color(dexHex: "#7c3aed")
        // A red signal lamp on the yellow shell — the one saturated colour the
        // grey-buttoned livery leaves room for.
        case .riesling: Color(dexHex: "#ef4444")
        // The DMG's own pea-green screen, reborn as a lamp.
        case .vinhoVerde: Color(dexHex: "#9BBC0F")
        case .glouglou: Color(dexHex: "#FB923C")
        // Calculator-orange, the operator key.
        case .smartGrape: Color(dexHex: "#FF9F0A")
        // A gold bead in a gold shell — one dye lot, like burgundy's purple.
        case .champagne: Color(dexHex: "#F5D97E")
        // Holly red, completing the set: caps, Home, lamps and orb all run
        // red on the wrapping paper (was fairy-light gold through 0.5.3).
        case .christmas: Color(dexHex: "#FF4D4D")
        // Grape juice under gloss.
        case .nouveau: Color(dexHex: "#A855F7")
        // A polished chestnut knob on the walnut (v0.5.8, C1 — was brass).
        // Lighter than the #5C4028 body so it still reads as a lamp.
        case .oaked: Color(dexHex: "#B06A32")
        // The one part that is *always* charged.
        case .nocturne: Color(dexHex: "#7CFC9A")
        // Ice on silver.
        case .steel: Color(dexHex: "#E8F1FF")
        // A pearl-pink bead — the one saturated light on the pastel shell.
        case .blush: Color(dexHex: "#FF7FA8")
        // The analog-stick LED: cross-button blue on the charcoal.
        case .psvino: Color(dexHex: "#5B93D8")
        // The power lamp, in the caps own red.
        case .grisDeGris: Color(dexHex: "#E23E3E")
        // Hazard yellow: the buttons are black, so the orb is the only thing
        // on this shell allowed to look lit.
        case .orangeWine: Color(dexHex: "#FFD22E")
        // A wash of ink where the lamp is — the drawn device's one
        // concession to looking powered.
        case .petNat: Color(dexHex: "#7FA6D8")
        // A bright bead of the same glass, lit from behind.
        case .waldglas: Color(dexHex: "#C9E86A")
        // The candle inside the lantern — the one lit thing on a shell
        // whose buttons are deliberately unlit.
        case .halloween: Color(dexHex: "#FF8A1F")
        // The power lamp, in the fourth face colour — the one this livery
        // has spare once green, blue and red are on the lamp trio.
        case .w64: Color(dexHex: "#F2C93A")
        }
    }

    /// Its halo. Deeper than `orb` in every case — the glow reads as the orb's
    /// own colour bleeding out, not as a second light behind it.
    public var orbGlow: Color {
        switch self {
        case .classic: Dex.blue
        case .midnight: Color(dexHex: "#a855f7")
        case .original: Color(dexHex: "#f0b429")
        case .burgundy: Color(dexHex: "#5b21b6")
        case .riesling: Color(dexHex: "#b91c1c")
        case .vinhoVerde: Color(dexHex: "#8BAC0F")
        case .glouglou: Color(dexHex: "#EA580C")
        case .smartGrape: Color(dexHex: "#C97800")
        case .champagne: Color(dexHex: "#D4A017")
        case .christmas: Color(dexHex: "#A61E1E")
        case .nouveau: Color(dexHex: "#7C3AED")
        case .oaked: Color(dexHex: "#7A4218")
        case .nocturne: Color(dexHex: "#3EE06C")
        case .steel: Color(dexHex: "#9FB8D8")
        case .blush: Color(dexHex: "#E1447E")
        case .psvino: Color(dexHex: "#2E6DB4")
        case .grisDeGris: Color(dexHex: "#8F1414")
        case .orangeWine: Color(dexHex: "#C99000")
        case .petNat: Color(dexHex: "#3E6FA8")
        case .waldglas: Color(dexHex: "#7A9A2E")
        case .halloween: Color(dexHex: "#B34700")
        case .w64: Color(dexHex: "#B58A0C")
        }
    }

    /// Home, and anything else built to look powered.
    public var accent: ChassisAccent {
        switch self {
        // Amber, exactly as before.
        case .classic:
            ChassisAccent(pale: "#fef3c7", light: "#fde68a", bright: "#fbbf24",
                          mid: "#f59e0b", edge: "#b45309", ink: "#78350f")
        case .midnight:
            ChassisAccent(pale: "#f3e8ff", light: "#e9d5ff", bright: "#c084fc",
                          mid: "#a855f7", edge: "#6b21a8", ink: "#3b0764")
        // Yellow — sunlight on the bone shell, and the one warm colour the
        // pale moulding leaves room for. (Was magenta, after the original
        // handheld's A/B buttons, which read as an error state on white.)
        case .original:
            ChassisAccent(pale: "#fefce8", light: "#fef08a", bright: "#facc15",
                          mid: "#eab308", edge: "#a16207", ink: "#713f12")
        // Deep purple, one shade brighter than the shell so Home still reads
        // as the powered part rather than more upholstery.
        case .burgundy:
            ChassisAccent(pale: "#ede9fe", light: "#ddd6fe", bright: "#8b5cf6",
                          mid: "#6d28d9", edge: "#4c1d95", ink: "#2e1065")
        // Greys, to match the moulded caps — on this shell the red orb is the
        // only powered colour, which is what makes it a signal lamp.
        case .riesling:
            ChassisAccent(pale: "#f4f5f6", light: "#d8dadd", bright: "#b6b9be",
                          mid: "#8b8f95", edge: "#4b4f54", ink: "#1c1e21")
        // Dark brown — the DMG's burgundy buttons aged into leather.
        case .vinhoVerde:
            ChassisAccent(pale: "#E7D8C9", light: "#C8A98B", bright: "#8B5E3C",
                          mid: "#6B4226", edge: "#3E2417", ink: "#241207")
        case .glouglou:
            ChassisAccent(pale: "#FFEDD5", light: "#FED7AA", bright: "#FB923C",
                          mid: "#F97316", edge: "#C2410C", ink: "#7C2D12")
        // The operator key: calculator orange, lit.
        case .smartGrape:
            ChassisAccent(pale: "#FFE8C7", light: "#FFC66E", bright: "#FF9F0A",
                          mid: "#E08600", edge: "#8F5600", ink: "#3D2400")
        // Gold leaf, one register deeper than the shell.
        case .champagne:
            ChassisAccent(pale: "#FDF6E3", light: "#F5E3AE", bright: "#E3BC5F",
                          mid: "#C89B3C", edge: "#8A6820", ink: "#4A3510")
        // Holly-berry red, to match the caps and the lights — the whole
        // powered set runs red on the wrapping paper. (Was bauble gold; the
        // orb keeps the fairy-light gold so the shell still carries both
        // Christmas colours.)
        case .christmas:
            ChassisAccent(pale: "#FFE7E7", light: "#FFB3B3", bright: "#F25454",
                          mid: "#D32F2F", edge: "#7A1010", ink: "#3D0000")
        // Glossy grape juice — the whole powered set runs one purple.
        case .nouveau:
            ChassisAccent(pale: "#F3E8FF", light: "#D8B4FE", bright: "#A855F7",
                          mid: "#7C3AED", edge: "#4C1D95", ink: "#2E1065")
        // Polished brass on the cream faceplate.
        case .oaked:
            ChassisAccent(pale: "#F8EFD8", light: "#EFD9A0", bright: "#D9AE55",
                          mid: "#B5892E", edge: "#7A5A14", ink: "#3D2B05")
        // The charged phosphor itself, lit.
        case .nocturne:
            ChassisAccent(pale: "#EFFFE8", light: "#C9F9B8", bright: "#8DF06A",
                          mid: "#57D63E", edge: "#2E8A20", ink: "#0F3D08")
        // Cool steel-blue — powered, but restrained like the livery.
        case .steel:
            ChassisAccent(pale: "#F2F6FA", light: "#D7DEE6", bright: "#AEB9C6",
                          mid: "#7E8A98", edge: "#454C56", ink: "#14181D")
        // Hot-pink ramp on the pastel shell — the powered parts get the
        // saturation the moulding deliberately holds back.
        case .blush:
            ChassisAccent(pale: "#FFF1F4", light: "#FBCFE0", bright: "#F472B6",
                          mid: "#DB2777", edge: "#9D174D", ink: "#500724")
        // Cross-button blue, lit — one restrained colour on the matte black,
        // the way the console itself wore it.
        case .psvino:
            ChassisAccent(pale: "#E3EEFA", light: "#B9D2F0", bright: "#5B93D8",
                          mid: "#2E6DB4", edge: "#173D6B", ink: "#0A1F38")
        // The brick's red face buttons - the one saturated colour on the grey.
        case .grisDeGris:
            ChassisAccent(pale: "#FFE5E5", light: "#FFB3B3", bright: "#E23E3E",
                          mid: "#C22626", edge: "#7A1414", ink: "#3D0505")
        // Black, and deliberately: J2 asks for black buttons, so the *lit*
        // button is black too. `ink` is pale rather than dark because Home's
        // inner disc runs pale->bright, which on this ramp is a dark disc.
        case .orangeWine:
            ChassisAccent(pale: "#6E6E70", light: "#4A4A4C", bright: "#2A2A2C",
                          mid: "#161617", edge: "#0A0A0B", ink: "#F2EFEA")
        // Pencil greys with a blue-black rim. Deliberately the flattest
        // ramp in the range: the six stops exist to make a cap look
        // moulded, and this cap is meant to look drawn.
        case .petNat:
            ChassisAccent(pale: "#FBF8F1", light: "#E6E0D2", bright: "#C9C2B2",
                          mid: "#A79F8E", edge: "#2B3244", ink: "#2B3244")
        // The glass itself, lit — one dye lot, like BURGUNDY's purple.
        case .waldglas:
            ChassisAccent(pale: "#F0F7DE", light: "#D7E8AE", bright: "#A8C766",
                          mid: "#7E9A3E", edge: "#48601E", ink: "#1F2C0A")
        // Pumpkin orange, and it is the only colour on the shell.
        case .halloween:
            ChassisAccent(pale: "#FFEBD4", light: "#FFC98A", bright: "#FF8A1F",
                          mid: "#E0670A", edge: "#8A3A00", ink: "#331500")
        // Never read on this skin — `buttonSet` below gives Home its own green
        // ramp, exactly as it does for the two existing console liveries.
        // Present so the switch stays exhaustive, and so anything asking a skin
        // for "its one accent" gets the green rather than nothing.
        case .w64:
            ChassisAccent(pale: "#E8F8E6", light: "#A8E3A4", bright: "#63C86B",
                          mid: "#3A9A44", edge: "#1E5C24", ink: "#062A08")
        }
    }

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
    public var control: ChassisControl {
        switch self {
        // Stone, exactly as before.
        case .classic:
            ChassisControl(top: "#44403c", bottom: "#0c0a09", edge: "#a8a29e", glyph: "#ffffff")
        case .midnight:
            ChassisControl(top: "#3b3746", bottom: "#0b0a10", edge: "#8b86a3", glyph: "#ffffff")
        // Pale grey with a dark glyph — the original handheld's own d-pad.
        case .original:
            ChassisControl(top: "#c2c2ba", bottom: "#83837b", edge: "#5f5f59", glyph: "#262622")
        // Deep purple caps, matching the accent ramp and the orb.
        case .burgundy:
            ChassisControl(top: "#5b21b6", bottom: "#1e0a38", edge: "#a78bfa", glyph: "#ffffff")
        // Neutral grey — the blue cast the caps used to carry fought the
        // livery once the orb went red.
        case .riesling:
            ChassisControl(top: "#5a6068", bottom: "#14171c", edge: "#a7adb5", glyph: "#ffffff")
        case .vinhoVerde:
            ChassisControl(top: "#4B4F54", bottom: "#111316", edge: "#8A9096", glyph: "#ffffff")
        // Clear caps: the rgba stops are what makes the buttons read as
        // moulded from the same smoke plastic as the shell.
        case .glouglou:
            ChassisControl(top: "rgba(203,213,225,0.55)", bottom: "rgba(51,65,85,0.60)",
                           edge: "rgba(226,232,240,0.90)", glyph: "#0F172A")
        // The number key: dark grey with the brown cast of the brief.
        case .smartGrape:
            ChassisControl(top: "#4A4239", bottom: "#151210", edge: "#8A7B6B", glyph: "#ffffff")
        // Pale gold caps with a dark glyph, per the Blanc de Blancs precedent.
        case .champagne:
            ChassisControl(top: "#D8C48E", bottom: "#7A6535", edge: "#55431F", glyph: "#2E2410")
        // The holly-berry caps.
        case .christmas:
            ChassisControl(top: "#C93B3B", bottom: "#5C1010", edge: "#E88A8A", glyph: "#ffffff")
        // Clear purple caps, moulded from the same smoke as the shell.
        case .nouveau:
            ChassisControl(top: "rgba(216,180,254,0.55)", bottom: "rgba(76,29,149,0.60)",
                           edge: "rgba(233,213,255,0.90)", glyph: "#2E1065")
        // Walnut caps with a cream glyph, like inlay.
        case .oaked:
            ChassisControl(top: "#7A5A3A", bottom: "#2E2014", edge: "#A8865E", glyph: "#F2E8D5")
        // Moulded from the luminous shell, one register deeper.
        case .nocturne:
            ChassisControl(top: "#A9D89A", bottom: "#4E7A42", edge: "#6FA75E", glyph: "#123B0C")
        // Machined caps with a dark glyph, per the Blanc de Blancs precedent.
        case .steel:
            ChassisControl(top: "#B9BEC6", bottom: "#5E646C", edge: "#3E434B", glyph: "#14181D")
        // Pink caps one register deeper than the shell, dark glyph like the
        // other pale skins.
        case .blush:
            ChassisControl(top: "#F5BBC9", bottom: "#C97F94", edge: "#8F4A5E", glyph: "#4A1220")
        // The DualShock's own grey-black buttons.
        case .psvino:
            ChassisControl(top: "#3A3B40", bottom: "#101114", edge: "#6A6C72", glyph: "#ffffff")
        // Red caps on the grey shell.
        case .grisDeGris:
            ChassisControl(top: "#D8484E", bottom: "#8A1F24", edge: "#F0989C", glyph: "#ffffff")
        // Black caps on the warning orange.
        case .orangeWine:
            ChassisControl(top: "#3A3A3C", bottom: "#0B0B0C", edge: "#6E6E70", glyph: "#ffffff")
        // Paper caps with an ink glyph, per the Blanc de Blancs
        // precedent — white on paper is nothing at all.
        case .petNat:
            ChassisControl(top: "#FBF8F1", bottom: "#DED7C7", edge: "#2B3244", glyph: "#2B3244")
        // Clear green caps, moulded from the same glass as the shell.
        case .waldglas:
            ChassisControl(top: "rgba(203,222,160,0.55)", bottom: "rgba(72,96,30,0.60)",
                           edge: "rgba(226,238,200,0.90)", glyph: "#1F2C0A")
        // Black caps with an orange glyph — the two colours, and only the
        // two colours.
        case .halloween:
            ChassisControl(top: "#2A2530", bottom: "#0A080C", edge: "#5E5468", glyph: "#FF8A1F")
        // Never read on this skin either — see `accent` above and `buttonSet`
        // below. Violet moulding a register off the shell, so a caller that
        // bypasses the set still gets a cap belonging to this device.
        case .w64:
            ChassisControl(top: "#6A4BB8", bottom: "#221448", edge: "#A98EE8", glyph: "#ffffff")
        }
    }

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
        ChassisAccent(cap: buttonSet.map { ChassisControl(litRamp: $0.home) } ?? control)
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
    public var marqueeText: Color {
        switch self {
        case .classic: Dex.green500
        case .midnight: Color(dexHex: "#c084fc")
        case .original: Color(dexHex: "#fbbf24")
        case .burgundy: Color(dexHex: "#f9a8d4")
        case .riesling: Dex.green500
        case .vinhoVerde: Color(dexHex: "#9BBC0F")
        case .glouglou: Color(dexHex: "#FB923C")
        case .smartGrape: Color(dexHex: "#FF9F0A")
        case .champagne: Color(dexHex: "#F2C14E")
        case .christmas: Color(dexHex: "#FF6B6B")
        case .nouveau: Color(dexHex: "#C084FC")
        case .oaked: Color(dexHex: "#FFB84D")
        case .nocturne: Color(dexHex: "#86FF7E")
        case .steel: Color(dexHex: "#9FD4FF")
        // Pink phosphor — period LED strips never came in pink, but this is
        // the one skin allowed to care more about the look than the period.
        case .blush: Color(dexHex: "#FF9EC0")
        // Boot-screen blue phosphor.
        case .psvino: Color(dexHex: "#7DB2F0")
        // The pea-green screen, kept as the one thing on this device that is
        // still a display. Stepped off BOX WINE #9BBC0F so the two handheld
        // homages do not glow the identical green.
        case .grisDeGris: Color(dexHex: "#A6C550")
        case .orangeWine: Color(dexHex: "#FFC93C")
        // A highlighter stripe. The one panel on the device that is
        // filled rather than outlined, because a marquee has to read as
        // lit and there is no drawn equivalent of lit.
        case .petNat: Color(dexHex: "#E8DF7A")
        case .waldglas: Color(dexHex: "#B8D96A")
        case .halloween: Color(dexHex: "#FFA23C")
        // Period-correct green, and the fifth green strip in the range —
        // stepped clear of BOX WINE's #9BBC0F and GRIS DE GRIS's #A6C550 so
        // the three homages do not glow the identical colour, which is the
        // note GRIS DE GRIS's own entry above records.
        case .w64: Color(dexHex: "#7FD98A")
        }
    }

    /// The faint grid behind the phosphor, and the colour its letters are cut
    /// out of. One step deeper, so the strip still reads as glass over a grid.
    public var marqueeGrid: Color {
        switch self {
        case .classic: Dex.green
        case .midnight: Color(dexHex: "#a855f7")
        case .original: Color(dexHex: "#f59e0b")
        case .burgundy: Color(dexHex: "#ec4899")
        case .riesling: Color(dexHex: "#16a34a")
        case .vinhoVerde: Color(dexHex: "#8BAC0F")
        case .glouglou: Color(dexHex: "#F97316")
        case .smartGrape: Color(dexHex: "#E08600")
        case .champagne: Color(dexHex: "#D4A017")
        case .christmas: Color(dexHex: "#E03131")
        case .nouveau: Color(dexHex: "#A855F7")
        case .oaked: Color(dexHex: "#E69A28")
        case .nocturne: Color(dexHex: "#57D63E")
        case .steel: Color(dexHex: "#5FA8E8")
        case .blush: Color(dexHex: "#F472B6")
        case .psvino: Color(dexHex: "#2E6DB4")
        case .grisDeGris: Color(dexHex: "#7E9B2E")
        case .orangeWine: Color(dexHex: "#E0A100")
        case .petNat: Color(dexHex: "#BFB55A")
        case .waldglas: Color(dexHex: "#8AA83E")
        case .halloween: Color(dexHex: "#E0670A")
        case .w64: Color(dexHex: "#3A9A44")
        }
    }

    /// Hard drop shadow under each glyph on the strip — a very dark form of the
    /// phosphor, which is what makes the letters look lit rather than printed.
    public var marqueeShadow: Color {
        switch self {
        case .classic: Color(dexHex: "#082010")
        case .midnight: Color(dexHex: "#1e0b32")
        case .original: Color(dexHex: "#301a02")
        case .burgundy: Color(dexHex: "#3b0723")
        case .riesling: Color(dexHex: "#082010")
        case .vinhoVerde: Color(dexHex: "#0F380F")
        case .glouglou: Color(dexHex: "#33130A")
        case .smartGrape: Color(dexHex: "#331F04")
        case .champagne: Color(dexHex: "#33240A")
        case .christmas: Color(dexHex: "#240808")
        case .nouveau: Color(dexHex: "#22083B")
        case .oaked: Color(dexHex: "#33200A")
        case .nocturne: Color(dexHex: "#0E2E0C")
        case .steel: Color(dexHex: "#0A1A2A")
        case .blush: Color(dexHex: "#3B0A1E")
        case .psvino: Color(dexHex: "#08182E")
        case .grisDeGris: Color(dexHex: "#16240A")
        case .orangeWine: Color(dexHex: "#33220A")
        case .petNat: Color(dexHex: "#2B3244")
        case .waldglas: Color(dexHex: "#1A240A")
        case .halloween: Color(dexHex: "#2B1200")
        case .w64: Color(dexHex: "#08240E")
        }
    }
}
#endif
