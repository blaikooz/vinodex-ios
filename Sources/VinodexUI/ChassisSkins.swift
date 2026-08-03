#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

// The skin catalogue — five devices rather than one device in five
// colours (v0.4.2.1), each carrying its own accent ramp, control livery
// and marquee phosphor. Split out of DexTheme.swift (AUDIT **M30**); it
// was 720 lines, the largest single block in that file. Nothing here
// changed in the move.

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
struct ChassisAccent: Sendable {
    /// Inner disc, top.
    let pale: Color
    /// Outer button, top.
    let light: Color
    /// Inner disc, bottom.
    let bright: Color
    /// Outer button, bottom — and the inner disc's hairline.
    let mid: Color
    /// Outer border.
    let edge: Color
    /// The glyph.
    let ink: Color

    init(pale: String, light: String, bright: String, mid: String, edge: String, ink: String) {
        self.pale = Color(dexHex: pale)
        self.light = Color(dexHex: light)
        self.bright = Color(dexHex: bright)
        self.mid = Color(dexHex: mid)
        self.edge = Color(dexHex: edge)
        self.ink = Color(dexHex: ink)
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
struct ChassisControl: Sendable {
    /// Top of the cap's gradient.
    let top: Color
    /// Bottom of it.
    let bottom: Color
    /// The rim.
    let edge: Color
    /// The chevron or person glyph.
    let glyph: Color

    init(top: String, bottom: String, edge: String, glyph: String) {
        self.top = Color(dexHex: top)
        self.bottom = Color(dexHex: bottom)
        self.edge = Color(dexHex: edge)
        self.glyph = Color(dexHex: glyph)
    }
}

/// Chassis colourway. The LCD itself never changes — only the moulding around
/// it — so a skin swap cannot affect legibility of the content.
///
/// Persisted under this key by both `DeviceChassis` and `SettingsPanel`;
/// `@AppStorage` keeps the two in sync without threading state between them.
///
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
enum ChassisSkin: String, CaseIterable, Identifiable, Sendable {
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

    static let storageKey = SavedDataKey.chassisSkin.rawValue

    var id: String { rawValue }

    /// Whether the shell is see-through — `DeviceChassis`'s cue to mount the
    /// mock internals behind it. A flag rather than sniffing alpha out of a
    /// `Color`, which SwiftUI does not expose anyway.
    var isTranslucent: Bool { self == .glouglou || self == .nouveau }

    /// A soft halo around the screen housing — NOCTURNE's glow-in-the-dark
    /// charge. Nil everywhere else; the chassis applies it as a shadow, so
    /// an absent glow costs nothing.
    var rimGlow: Color? {
        self == .nocturne ? Color(dexHex: "#A8FF96") : nil
    }

    /// The globe screen's sphere tint (0.6.2, F1) — every skin sees the world
    /// through its own colour. Pale on purpose: the tint multiplies over the
    /// map texture, so a saturated dark here would swallow the coastlines.
    var globeTint: Color {
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
        }
    }

    /// What sits behind the shell: the shell itself for opaque skins, a
    /// near-black base under GLOUGLOU so the smoke plastic has something to be
    /// smoke over.
    var underlay: Color {
        isTranslucent ? Color(dexHex: "#14161A") : body
    }

    /// The clear back moulding, laid over the internals — a touch lighter than
    /// the front shell, since the back of a clear device is one moulding
    /// further from the boards. Meaningful only for translucent skins.
    /// RETROVIN's back is its own atomic purple (v0.5.9, A2): the plate used
    /// one hardcoded grey smoke, so the purple shell turned grey from behind.
    var backSmoke: Color {
        self == .nouveau
            ? Color(dexHex: "rgba(147,51,234,0.34)")
            : Color(dexHex: "rgba(204,216,224,0.34)")
    }

    /// What the picker calls this skin.
    ///
    /// Deliberately separate from `rawValue`: the raw value is the persisted
    /// `@AppStorage` key, so renaming ORIGINAL to "Blanc de Blancs" by editing
    /// the case would silently reset every device already storing "ORIGINAL"
    /// back to the default shell. The stored vocabulary stays put and only the
    /// label moves.
    var displayName: String {
        switch self {
        // The house colourway, named for the house rather than described as
        // "classic" — every other skin here has a wine name, and the default
        // was the only one still labelled by category.
        case .classic: "VINODEX CLASSIC"
        case .midnight: "CÔTE DE NUITS"
        case .original: "BLANC DE BLANCS"
        case .burgundy: "BURGUNDY"
        // Renamed from ELECTRIC RIESLING (0.6.x) — label only, per the note
        // above; the yellow Walkman shell suits Jura's yellow wine as well.
        case .riesling: "VIN JAUNE"
        // Renamed labels only — the raw values are the persisted vocabulary
        // and stay put, per the note above. "VINHO VERDE" moved houses in
        // two steps: the forest-green skin became BOX WINE in 0.5.1, which
        // freed the name for the glow-green skin in 0.5.4.
        case .vinhoVerde: "BOX WINE"
        case .glouglou: "EMPTY BOTTLE"
        case .smartGrape: "SMART GRAPE"
        case .champagne: "CHAMPAGNE GOLD"
        case .christmas: "WINE XMAS"
        // Renamed from NOUVEAU (v0.5.9, A1) — label only, per the note above.
        case .nouveau: "RETROVIN"
        case .oaked: "OAKED"
        case .nocturne: "VINHO VERDE"
        case .steel: "STAINLESS STEEL"
        case .blush: "BLUSH"
        case .psvino: "PSVINO"
        }
    }

    /// A tileable pixel-art pattern drawn over the shell colour, or nil for a
    /// plain moulding. WINE XMAS wraps the chassis in wrapping paper, OAKED
    /// in walnut grain, STEEL in brushed aluminium; the pattern sits under
    /// the panel and footer wash like any other body.
    var bodyPatternAsset: String? {
        switch self {
        case .christmas: "xmas-wrap"
        case .oaked: "oak-grain"
        case .steel: "steel-brush"
        default: nil
        }
    }

    /// Emblem glyph — the picker tile carries it the way screen-mode tiles
    /// carry theirs, and the back plate wears it as an enamel badge.
    var symbol: String {
        switch self {
        case .classic: "gamecontroller.fill"
        case .midnight: "moon.fill"
        case .original: "sparkles"
        case .burgundy: "diamond.fill"
        case .riesling: "bolt.fill"
        case .vinhoVerde: "shippingbox.fill"
        case .glouglou: "wineglass.empty"
        case .smartGrape: "plus.forwardslash.minus"
        case .champagne: "party.popper.fill"
        case .christmas: "gift.fill"
        case .nouveau: "cpu.fill"
        case .oaked: "tree.fill"
        case .nocturne: "moon.zzz.fill"
        case .steel: "gearshape.2.fill"
        case .blush: "heart.fill"
        case .psvino: "playstation.logo"
        }
    }

    /// The three status lamps, left to right, as (fill, border) pairs — a
    /// unique trio per skin (v0.5.6, generalising WINE XMAS's all-red set,
    /// which used to be the one override on a fixed red/yellow/green).
    var statusLights: [(fill: Color, border: Color)] {
        func trio(_ a: (String, String), _ b: (String, String), _ c: (String, String)) -> [(fill: Color, border: Color)] {
            [a, b, c].map { (Color(dexHex: $0.0), Color(dexHex: $0.1)) }
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
        // Pearl-pink fairy trio, light to deep.
        case .blush:
            return trio(("#FDA4AF", "#E11D48"), ("#F9A8D4", "#DB2777"), ("#F472B6", "#9D174D"))
        // Triangle, circle, cross — the face buttons as indicator lamps.
        case .psvino:
            return trio(("#3AC4B4", "#0E7A6E"), ("#F0435C", "#8F0E20"), ("#6FA3E8", "#1B4470"))
        }
    }

    /// The moulding.
    var body: Color {
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
        }
    }

    /// Wash behind the footer row, a shade off the body.
    var footerWash: Color {
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
        }
    }

    /// The panel the LCD is set into — white on the classic shell.
    var panel: Color {
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
        }
    }

    var panelEdge: Color {
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
        }
    }

    /// Speaker grill slats.
    var grill: Color {
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
    var orb: Color {
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
        }
    }

    /// Its halo. Deeper than `orb` in every case — the glow reads as the orb's
    /// own colour bleeding out, not as a second light behind it.
    var orbGlow: Color {
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
        }
    }

    /// Home, and anything else built to look powered.
    var accent: ChassisAccent {
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
    var control: ChassisControl {
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
        }
    }

    /// Marquee phosphor. Period LED strips came in green, amber, red and blue,
    /// so this is the one part where a colour change is period-correct rather
    /// than merely decorative.
    var marqueeText: Color {
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
        }
    }

    /// The faint grid behind the phosphor, and the colour its letters are cut
    /// out of. One step deeper, so the strip still reads as glass over a grid.
    var marqueeGrid: Color {
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
        }
    }

    /// Hard drop shadow under each glyph on the strip — a very dark form of the
    /// phosphor, which is what makes the letters look lit rather than printed.
    var marqueeShadow: Color {
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
        }
    }

    var next: ChassisSkin {
        let all = ChassisSkin.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
}
#endif
