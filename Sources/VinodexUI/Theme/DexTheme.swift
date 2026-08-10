#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import CoreText
import VinodexCore

// MARK: - Colour

public extension Color {
    /// Builds a colour from `#RRGGBB` or `rgba(r,g,b,a)`, falling back to stone grey.
    ///
    /// The rgba form matters: three chip styles in `chipColors.ts`
    /// (SYSTEM / CLIMATE / BLUE) specify their background that way rather than as hex.
    init(dexHex raw: String) {
        let value = raw.trimmingCharacters(in: .whitespaces)

        if value.hasPrefix("rgba(") || value.hasPrefix("rgb(") {
            let inner = value
                .replacingOccurrences(of: "rgba(", with: "")
                .replacingOccurrences(of: "rgb(", with: "")
                .replacingOccurrences(of: ")", with: "")
            let parts = inner.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count >= 3, let r = parts[0], let g = parts[1], let b = parts[2] {
                let a = parts.count > 3 ? (parts[3] ?? 1) : 1
                self = Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
                return
            }
        }

        let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard hex.count == 6, let bits = UInt32(hex, radix: 16) else {
            self = Color(.sRGB, red: 0.47, green: 0.44, blue: 0.42, opacity: 1)
            return
        }
        self = Color(
            .sRGB,
            red: Double((bits >> 16) & 0xFF) / 255,
            green: Double((bits >> 8) & 0xFF) / 255,
            blue: Double(bits & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Chassis and LCD tokens, from the `@theme` block in `index.css` plus the
/// Tailwind palette values the chassis markup references directly.
public enum Dex {
    // index.css @theme
    public static let red = Color(dexHex: "#DC0A2D")
    public static let darkRed = Color(dexHex: "#89061C")
    public static let screen = Color(dexHex: "#232323")
    public static let screenBg = Color(dexHex: "#98CB98")
    public static let ui = Color(dexHex: "#DEDEDE")
    /// Midnight-skin equivalents of the chassis body and its front panel.
    public static let graphite = Color(dexHex: "#17161A")
    public static let graphitePanel = Color(dexHex: "#2B2A30")
    public static let graphiteEdge = Color(dexHex: "#4A4852")
    /// The original handheld's off-white shell and its cooler grey panel.
    public static let bone = Color(dexHex: "#D8D8D0")
    public static let bonePanel = Color(dexHex: "#EFEFE9")
    public static let boneEdge = Color(dexHex: "#9A9A93")
    /// Burgundy Velour — a velvet purple shell with a dusty lilac panel, so the
    /// pairing reads as upholstery rather than as a flat purple slab.
    public static let velour = Color(dexHex: "#4B1D3F")
    public static let velourPanel = Color(dexHex: "#D3BBCE")
    public static let velourEdge = Color(dexHex: "#2C0F24")
    /// Electric Riesling — the yellow of a 1980s sports Walkman. The panel is a
    /// dark grey with a light-grey edge: the pale panel it launched with sat so
    /// close to the classic white that the skin read as unskinned around the
    /// screen, and the pale-on-dark inversion is what the sports liveries did.
    public static let walkman = Color(dexHex: "#F2C11B")
    public static let walkmanPanel = Color(dexHex: "#4A4F55")
    public static let walkmanEdge = Color(dexHex: "#B9BEC4")
    public static let blue = Color(dexHex: "#2AB5FF")
    public static let yellow = Color(dexHex: "#FACC15")
    public static let green = Color(dexHex: "#4ADE80")

    // Tailwind values used by DeviceLayout.tsx
    public static let neutral900 = Color(dexHex: "#171717")
    public static let stone950 = Color(dexHex: "#0c0a09")
    public static let stone900 = Color(dexHex: "#1c1917")
    public static let stone800 = Color(dexHex: "#292524")
    public static let stone700 = Color(dexHex: "#44403c")
    public static let stone600 = Color(dexHex: "#57534e")
    public static let stone400 = Color(dexHex: "#a8a29e")
    public static let stone200 = Color(dexHex: "#e7e5e4")

    public static let cyan300 = Color(dexHex: "#67e8f9")
    public static let amber100 = Color(dexHex: "#fef3c7")
    public static let amber200 = Color(dexHex: "#fde68a")
    public static let amber400 = Color(dexHex: "#fbbf24")
    public static let amber500 = Color(dexHex: "#f59e0b")
    public static let amber700 = Color(dexHex: "#b45309")
    public static let amber900 = Color(dexHex: "#78350f")

    /// The pale end of the red ramp, added in 0.8.0 (E3) for ink on a filled red
    /// control — the amber ramp already carried its 100/200 stops for exactly
    /// this, and the reds stopped at 500. Tailwind's `red-200`, like every other
    /// stop in this enum.
    public static let red200 = Color(dexHex: "#fecaca")
    public static let red500 = Color(dexHex: "#ef4444")
    public static let red600 = Color(dexHex: "#dc2626")
    public static let red800 = Color(dexHex: "#991b1b")
    public static let yellow400 = Color(dexHex: "#facc15")
    public static let yellow600 = Color(dexHex: "#ca8a04")
    public static let green500 = Color(dexHex: "#22c55e")
    public static let green700 = Color(dexHex: "#15803d")

    /// Stat-bar fills. Ported from the reference exactly, and named here rather
    /// than spelled inline in a `[String: String]` keyed on the bar's *label*
    /// (AUDIT **L33**) — that table was one authored rename away from silently
    /// painting every bar the BODY green.
    public static let statBody = green500
    public static let statAcid = Color(dexHex: "#eab308")
    public static let statTannin = red500
    public static let statAromatics = Color(dexHex: "#c084fc")
    public static let statColor = amber500
}

/// The painted-plastic tile livery: a filled face, a darker extrusion under it,
/// and the ink on top.
///
/// One table for both grids (AUDIT **L33**). The main menu spelled its four
/// faces as hex pairs at the call site, and the settings grid kept two parallel
/// six-row tables switched on the tile's **title string** — so a renamed tile
/// fell through to the ACCESS purple, silently, and neither table was reachable
/// from the other even though five of the ten colours were the same colour.
///
/// Both modes are declared for every livery. That is the point of hoisting
/// these: light mode was added to the settings grid and missed on the main
/// menu, because there was no one place that knew a tile face has two values.
/// Light runs the deeper cuts — a bright face washes out on the pale page.
enum DexTileLivery: Sendable {
    case violet
    case green
    case amber
    case red
    case orange
    case sky
    case emerald

    private var dark: (face: String, shadow: String) {
        switch self {
        case .violet: ("#a855f7", "#6b21a8")
        case .green: ("#22c55e", "#15803d")
        case .amber: ("#eab308", "#a16207")
        case .red: ("#ef4444", "#991b1b")
        case .orange: ("#f97316", "#9a3412")
        case .sky: ("#2ab5ff", "#136a99")
        case .emerald: ("#10b981", "#065f46")
        }
    }

    private var light: (face: String, shadow: String) {
        switch self {
        case .violet: ("#7e22ce", "#4c1d95")
        case .green: ("#15803d", "#0b4a24")
        case .amber: ("#b45309", "#7a3606")
        case .red: ("#b91c1c", "#7a1010")
        case .orange: ("#c2410c", "#7c2d12")
        case .sky: ("#1d6fa8", "#11486e")
        case .emerald: ("#047857", "#064e3b")
        }
    }

    /// The pair as hexes, for `LcdMode.chrome(face:shadow:)` and
    /// `chromeInk(over:preferring:)`.
    ///
    /// The 0.7.1 C5 Emulator blend folds a control's face toward the machine's
    /// own ramp, and it does that arithmetic on `DexRGB(hex:)` — there is no way
    /// back from a resolved `Color`. So the two call sites that theme their
    /// tiles ask for the strings; `face(_:)`/`shadow(_:)` below stay the answer
    /// for anyone who just wants the colour.
    func hexes(_ lcd: LcdMode) -> (face: String, shadow: String) {
        lcd.isLight ? light : dark
    }

    /// The resolved pair, for a caller that is not theming.
    ///
    /// Both grids went through `chrome(face:shadow:)` with 0.7.1's C5, so these
    /// two currently have no callers; they are kept rather than deleted because
    /// a livery is a colour before it is a pair of strings, and the type should
    /// still say so. They resolve *through* `hexes(_:)` so the light/dark choice
    /// is made in one place — three independent reads of the same table is
    /// exactly what AUDIT **L33** hoisted this type to end.
    func face(_ lcd: LcdMode) -> Color {
        Color(dexHex: hexes(lcd).face)
    }

    func shadow(_ lcd: LcdMode) -> Color {
        Color(dexHex: hexes(lcd).shadow)
    }

    /// White on every livery, in both modes — the faces are all deep enough to
    /// carry it. Declared rather than assumed so a future livery has somewhere
    /// to disagree. (TOOLS used dark-amber ink until 0.6.4, which made it the
    /// odd one out on the grid.)
    var ink: Color { .white }
}

// MARK: - Metrics
//
// Values transcribed from `DeviceLayout.tsx`, mobile branch (below the `md:`
// breakpoint) — that is the branch the chassis uses on a phone, and the
// re-proportion-to-fill decision means we keep it rather than the fixed
// 522x850 desktop box. Tailwind rem = 16pt.

public enum DexMetrics {
    public static let rem: CGFloat = 16

    /// Outer chassis
    ///
    /// `deviceCorner` approximates the physical display's corner radius so the
    /// chassis outline follows it instead of being cropped by it; the inset
    /// keeps the stroke fully on-screen at the top corners.
    public static let chassisCorner: CGFloat = 2.5 * rem
    /// Main-menu tiles. Much rounder than the 12pt they were — at tile size a
    /// small radius reads as a plain rectangle.
    public static let menuTileCorner: CGFloat = 26
    public static let deviceCorner: CGFloat = 55
    public static let chassisBorderInset: CGFloat = 2
    public static let chassisBorder: CGFloat = 3
    /// Horizontal clearance for the display's rounded corners.
    ///
    /// A control sitting `chassisEdgeInset` (10pt) above the bottom edge is cut
    /// into by ~23pt of a 55pt corner arc — `deviceCorner - sqrt(r² - (r-h)²)`.
    /// The old 12pt padding put the outer edge of Back and Home inside that
    /// arc, so they were clipped on the diagonal. 26pt clears it with a margin.
    public static let cornerGuardH: CGFloat = 26

    /// Island strip
    ///
    /// The web app gives the orb, status lights and title their own red band
    /// above the bezel. On a phone that band is pure overhead — so they move
    /// into the top safe-area strip, flanking the Dynamic Island, which is dead
    /// chassis otherwise. The bezel keeps none of that height.
    ///
    /// The gap held open for the cutout is no longer a metric (0.6.8, F2/F3):
    /// the Dynamic Island is ~126pt wide on Pro models and the row simply puts
    /// its two clusters at their own insets, leaving whatever is between —
    /// ~45pt of margin either side on a 393pt phone.
    public static let headerPaddingH: CGFloat = rem
    /// Floor for the island strip. `.statusBarHidden()` can collapse
    /// `safeAreaInsets.top` to zero on cutout devices, so this must independently
    /// be tall enough to contain the island (~11pt from the top, ~37pt tall).
    /// Equal breathing room above the header row and below the footer row.
    /// This is the only thing holding either row off the display's rounded
    /// corners, and using one value for both is what makes the chassis read as
    /// symmetric top to bottom.
    public static let chassisEdgeInset: CGFloat = 16
    /// Gap between the screen housing and the bands. Minimal on purpose — every
    /// point here comes off the LCD — but non-zero so the housing does not butt
    /// straight into the controls. 3, down from 4 (0.6.8, E5): the band grew a
    /// long way in this batch and every point of chrome that is only a gap was
    /// re-examined.
    public static let housingGap: CGFloat = 3
    /// Gap from the island controls down to the screen housing. Used to match
    /// `footerTopInset` (6); tightened so the controls sit closer to the
    /// housing while the raised `islandTopInset` gives them air above instead.
    public static let islandBottomInset: CGFloat = 2
    /// Where the hardware cutout sits, measured from the display's top edge.
    ///
    /// Spelled out since 0.6.8 (F2): "centred vertically within the notch
    /// height" is a placement the layout can *compute* rather than a number
    /// somebody eyeballs once and then has to re-eyeball whenever the orb
    /// changes size. The Dynamic Island's own plate starts ~11pt down and is
    /// ~37pt tall, so its centre line is 29.5pt from the top.
    public static let islandNotchTop: CGFloat = 11
    public static let islandNotchHeight: CGFloat = 37
    /// The notch's centre line — what the orb and the lamp trio are levelled on.
    public static var islandNotchCenter: CGFloat { islandNotchTop + islandNotchHeight / 2 }

    /// Gap from the display's top edge down to the island controls.
    ///
    /// **Derived since 0.6.8 (F2)** rather than the flat 8 it carried from
    /// 0.6.6 (E3): whatever the slot's height, this is the inset that puts the
    /// slot's centre on `islandNotchCenter`, so the orb reads as level with the
    /// cutout by construction instead of by coincidence. (It resolves to ~7.5
    /// at the shipped sizes, which is why the flat 8 looked right — F2 is the
    /// turn where that stops being luck.)
    ///
    /// The floor is load-bearing: the display's 55pt corner arc cuts
    /// `55 - sqrt(55² - (55-h)²)` off each side at height `h`, which at 8pt is
    /// ~26pt — exactly `cornerGuardH`. The controls survive it because they are
    /// *circles*: the widest point of the orb sits half a slot lower, where the
    /// arc has closed to ~2pt. Going below 8 starts cutting the button's actual
    /// edge rather than the empty corner of its bounding box.
    ///
    /// **Re-derived in 0.7.5 (A2), when the orb stopped being a circle.** The
    /// sentence above is still true of the lamp trio, which is unchanged. It is
    /// *not* what saves the orb, and it never was: the orb's bounding box starts
    /// at `islandOrbInsetLeading` + half the slack, which is 68.4pt at SMALL and
    /// 68.0 at LARGE — 42pt inboard of the worst-case 26pt cut. Squaring the
    /// shape fills more of that box but does not move it, so the clearance is
    /// the inset's, not the geometry's, and a rounded rectangle costs nothing
    /// here. The circularity argument would matter again only for a control
    /// placed inside `cornerGuardH`, which nothing is.
    ///
    /// **Re-checked in 0.7.6 (E1), and it did not move.** The orb became a
    /// stadium, and the elongation was deliberately taken out of its *height* —
    /// see `islandOrbAspect`. Its bounding box therefore starts and ends exactly
    /// where it did, `islandSlot` is unchanged, and this inset resolves to the
    /// same number. The re-derivation is recorded rather than skipped because
    /// "the orb changed shape" is precisely the sentence that ought to send
    /// somebody to this comment.
    public static var islandTopInset: CGFloat {
        max(islandNotchCenter - islandSlot / 2, 8)
    }
    /// The glass orb, up in the notch band since 0.6.6 (E3) and no longer one
    /// of the `controlButton`-sized parts.
    ///
    /// It broke the "one diameter for every physical control" rule by being
    /// the biggest thing on the chassis while doing the least — a decorative
    /// lamp at button size reads as a button nobody labelled, and at 64pt it
    /// was also what forced the island strip to 84pt and charged the LCD for
    /// it. 55% of a control is a bead: unmistakably a lamp, and small enough to
    /// sit beside the cutout rather than under it.
    ///
    /// 0.55, back down from 0.62 (0.6.8, F1). 0.6.7 grew it 13% because 0.6.6
    /// had shrunk it a step too far; this takes that step back. It costs the
    /// layout nothing either way — `islandSlot` is floored at the 44pt touch
    /// minimum, which the bead has been under since 0.6.6, so the orb's
    /// diameter has not driven the strip's height for two batches.
    /// The orb's **width**. It was the orb's diameter through 0.7.5, and the
    /// rename in meaning is the whole of E1 — see `islandOrbAspect`.
    ///
    /// **Derived from the lamp trio since 0.7.9 (A1), not authored.** Every pass
    /// from 0.6.6 to 0.7.8 tuned this as a fraction of `controlButton` and then
    /// argued about whether the result balanced the three lamps across the
    /// cutout. A1 states the rule instead: the orb spans the *same length as the
    /// whole trio*, so the two island clusters are a matched pair of stadiums
    /// rather than a bead facing a row. 79.44pt at SMALL, 86.30 at LARGE —
    /// against 35.2 / 40.48 before, so this is the first pass since 0.6.8 to
    /// spend any of the cutout's horizontal budget, and `islandOrbInsetLeading`
    /// is re-derived below to pay for it.
    ///
    /// The old value survives in one place on purpose: `islandStatusDot` used to
    /// read `islandOrb * 0.60`, which would now be a cycle, so it reads
    /// `controlButton * 0.33` — the same number by construction, since
    /// 0.55 × 0.60 = 0.33 — and the arrow between the two metrics is reversed.
    public static var islandOrb: CGFloat {
        islandOrbWidth(lamp: islandStatusDot, spacing: statusDotSpacing)
    }

    /// A1's rule, stated once so a mockup can obey it too.
    ///
    /// Three lamps and the two gaps between them. `DeviceWorkshopScreen`,
    /// `SettingsPanel` and `WalkthroughScreen` all draw a miniature chassis with
    /// their own lamp sizes, and each used to hand-set an orb width and derive
    /// its height from `islandOrbAspect` — which was harmless while the aspect
    /// was 1.75 and produces a hairline now that it is 5.3. They call this with
    /// their own geometry instead, which is what "the preview follows the
    /// chassis" has to mean once the width is a rule rather than a number.
    public static func islandOrbWidth(lamp: CGFloat, spacing: CGFloat) -> CGFloat {
        3 * lamp + 2 * spacing
    }

    /// C1's rule, stated the same way and for the same three callers.
    ///
    /// **The orb is as tall as one lamp** (0.8.0, C1), where A1 said it is as
    /// long as three. The three miniature chassis were deriving their bead's
    /// height by dividing their own width by `DexMetrics.islandOrbAspect` — the
    /// *chassis's* aspect applied to a diagram's width, which was already only
    /// approximately right and which C1 turns into a number with no meaning at
    /// all, since the real aspect is now itself a quotient of two chassis
    /// metrics. Each preview knows its own lamp size; that is the input.
    ///
    /// It is an identity function on purpose. What it buys is that the rule has a
    /// name and one definition, exactly as `islandOrbWidth` does — a preview that
    /// writes `height: lamp` is a preview that agrees by coincidence, and the next
    /// pass on this part is the fourth in five batches.
    public static func islandOrbHeight(lamp: CGFloat) -> CGFloat { lamp }

    /// How much wider than tall the orb is (0.7.6, E1).
    ///
    /// **E1 refines 0.7.5's A2 rather than reversing it.** A2 squared the bead
    /// into a rounded key; E1 asks for a stadium — "an elongated circle, like the
    /// notch" — which is the same instinct one step further: the one hardware
    /// feature this strip is level with is a pill, and a part beside it that is
    /// almost-but-not-quite that shape reads as a near miss. So the corner
    /// fraction goes and a `Capsule` takes its place, which is the shape a
    /// rounded rectangle becomes when the radius reaches half the short side.
    ///
    /// **The elongation is spent on height, not width, and that is the
    /// constraint.** `islandOrbInsetLeading` puts the orb's slot at 64pt and the
    /// narrowest island device starts its cutout at 133 — 69pt of room, of which
    /// the 44pt slot leaves ~25pt of clearance. Widening the orb to make it a
    /// pill would eat that directly, and 0.7.1's A4 note is a page about what
    /// happens when this budget is spent twice by two edits that did not know
    /// about each other. So the orb keeps the width it has had since 0.6.8 and
    /// loses height instead: the slot, the inset and the clearance are all
    /// untouched, and the re-derivation A2's note asks for comes out identical
    /// because no horizontal number moved.
    ///
    /// 1.75 landed the bead at 35.2 × 20.1 at UI SIZE = SMALL and 40 × 22.9 at
    /// LARGE. That is unmistakably a stadium at a glance, and it put the orb's
    /// height within a point of `islandStatusDot` (22 / 24) — so the two clusters
    /// either side of the cutout became the same visual weight, which is the
    /// "mirrored pair of blocks" reading 0.6.8's F3 was after and has never quite
    /// had.
    ///
    /// **2.35 since 0.7.8 (A3): longer again, and again entirely out of height.**
    /// The paragraph above is the rule and this batch obeys it to the letter —
    /// `islandOrb`, `islandSlot`, `islandOrbInsetLeading` and
    /// `islandStatusInsetTrailing` are all untouched, so A4's "do not spend this
    /// again without re-deriving the span" is satisfied by there being no span
    /// to re-derive: not one horizontal number moved. Re-derived anyway, because
    /// that instruction is about proving it rather than asserting it — the slot
    /// still runs 64 → 108 against a cutout starting at 133 (~25pt of leading
    /// clearance), and the lamp trio still runs 3 × 22 + 2 × 6.72 = 79.4 in from
    /// `cornerGuardH + 6` = 32 at SMALL, 85.4 at LARGE. Both identical to 0.7.6.
    ///
    /// **The ceiling, and why 2.35 rather than more.** The bead's white rim is
    /// `max(height × 0.11, 2)` (`DeviceChassis.lcdOrb`), so below a height of
    /// 18.2 the 2pt floor takes over and every further point of elongation comes
    /// straight out of the coloured core rather than off the whole bead
    /// proportionally. Requiring that core to stay at least 10pt at SMALL — thin
    /// enough to read as a slot, thick enough to still read as *lit* — gives
    /// height ≥ 14, i.e. an aspect ceiling of 35.2 / 14 = 2.51. 2.35 sits inside
    /// it with room: **35.2 × 15.0 at SMALL and 40 × 17.0 at LARGE**, a core of
    /// 11.0 and 13.0 points respectively.
    ///
    /// **What it costs, said out loud.** E1's paragraph above bought a deliberate
    /// thing — orb height ≈ `islandStatusDot`, so the two clusters flanking the
    /// cutout weighed the same. At 15 against 22 that is now given up: the orb is
    /// the lighter of the pair. The device's own cutout is roughly 125 × 37, an
    /// aspect near 3.4, and A3 asks the bead to go further toward it; it cannot
    /// arrive there without width, which is forbidden, so the trade is between
    /// matching the notch's proportion and matching the trio's mass. A3 chooses
    /// the notch. Worth an eyeball on the device before it is treated as settled.
    ///
    /// ---
    ///
    /// **0.7.9 (A1) inverts the whole argument above: the aspect is no longer
    /// authored.** Every paragraph before this one is a record of choosing a
    /// number for how long the bead should be. A1 says the length is not a
    /// choice — the orb is as long as the lamp trio — so `islandOrb` is derived,
    /// the *height* becomes the one authored axis, and this falls out as the
    /// consequence. **5.30 at SMALL and 5.01 at LARGE**, up from a flat 2.35.
    ///
    /// It differs between the two scales for a real reason, which is worth
    /// knowing before anyone treats the difference as a bug: `islandStatusDot`
    /// is floored at 22, and at SMALL the floor binds (21.12 → 22) while at
    /// LARGE the 0.33 fraction does. So the trio is proportionally *wider* at
    /// SMALL than the strict fraction would make it, and the orb inherits that.
    ///
    /// **The 0.7.8 ceiling still holds and is still the constraint.** That note
    /// derived a maximum aspect of 2.51 from the rim arithmetic — but it was
    /// derived by holding the *width* and taking the elongation out of height,
    /// and the real rule underneath is about height alone: the rim is
    /// `max(height × 0.11, 2)`, so a height below 18.2 puts the rim on its 2pt
    /// floor and every further point comes out of the coloured core. Holding the
    /// height at exactly what 0.7.8 shipped keeps the core at 10.98pt (SMALL)
    /// and 13.22 (LARGE) — unchanged to two decimals — while the aspect doubles.
    /// The ceiling was never about the aspect; it was about the short axis.
    ///
    /// **What A1 buys back.** The thing E1 spent and A3 gave up — the two
    /// clusters weighing the same — returns in the other axis: the orb and the
    /// trio are now exactly the same *length*, which is the reading 0.6.8's F3
    /// was after and never had. It buys it at the cost of the notch's 3.4
    /// proportion, which the bead now overshoots by a wide margin. Worth an
    /// eyeball, like every pass on this part.
    ///
    /// ---
    ///
    /// **0.8.0 (C1): still derived, and now derived from one number.** The height
    /// stops being authored too — it is `islandStatusDot` — so this is
    /// `(3 x lamp + 2 x spacing) / lamp`, i.e. `3 + 2 x spacing / lamp` and
    /// nothing else. **3.61 at SMALL and 3.55 at LARGE**, down from 5.30/5.01,
    /// which lands the bead within a fifth of the device cutout's own ~3.4 — the
    /// proportion A3 chose and A1 then overshot. The two scales still differ, for
    /// the reason above: at SMALL `islandStatusDot`'s 22pt floor binds and the
    /// trio is proportionally wider than the strict fraction makes it.
    public static var islandOrbAspect: CGFloat { islandOrb / islandOrbHeight }

    /// The orb's height — **the lamp's, since 0.8.0 (C1)**.
    ///
    /// 0.7.9's A1 made this the authored axis at `controlButton x 0.234`, which
    /// was not a fresh number but 0.55 / 2.35 — the width fraction and the aspect
    /// 0.7.8 had shipped, multiplied out — chosen so that pass changed length and
    /// nothing else. C1 is those two factors becoming one: the bead is as tall as
    /// a status lamp, so `islandStatusDot` is read directly and the orb and the
    /// trio now agree on *both* axes. A1 gave them the same length; this gives
    /// them the same mass, which is the "mirrored pair of blocks" reading 0.6.8's
    /// F3 asked for and E1 and A3 each spent in turn.
    ///
    /// **14.98 -> 22.00 at SMALL, 17.22 -> 24.29 at LARGE.** The spec's figures
    /// were 21.12 and an aspect of 3.76, which is `controlButton x 0.33` taken
    /// without its floor; `islandStatusDot` is `max(controlButton x 0.33, 22)`
    /// and at SMALL the **22 binds** (21.12 rounds up). So the bead is a shade
    /// taller than asked and the derived aspect comes out 3.61 at SMALL against
    /// 3.55 at LARGE, rather than 3.76 flat. That is the same floor that already
    /// makes `islandOrbAspect` differ between the two scales — see its note.
    ///
    /// **No horizontal number moved, and the clearance table is confirmed rather
    /// than assumed** (0.7.1's A4 asks for exactly that). `islandOrb` is
    /// `3 x lamp + 2 x spacing` and reads neither this nor the aspect, so the
    /// width, `islandOrbSlot`, `islandOrbInsetLeading` and
    /// `islandStatusInsetTrailing` are untouched: the slot still runs 64 -> 108
    /// against a cutout starting at 133, ~25pt of leading clearance. Vertically
    /// `islandSlot` is `max(height + 8, 44)` and 22 + 8 = 30, so the 44pt touch
    /// floor still binds exactly as it has since 0.6.6 and the strip's height
    /// does not move either.
    ///
    /// **What it does change is the rim, and that is the one thing to eyeball.**
    /// `DeviceChassis.lcdOrb` draws `max(height x 0.11, 2)`; at 14.98 that was on
    /// the 2pt floor, and at 22 it is 2.42 — the first time since 0.7.6 that the
    /// rim is proportional again. The coloured core goes from 10.98 to 17.16pt.
    /// 0.7.8's ceiling argument was always about the short axis and it is
    /// satisfied with room to spare in the direction it was worried about.
    public static var islandOrbHeight: CGFloat { islandStatusDot }

    // `islandOrbCornerFraction` retired in 0.7.6 (E1). It was 0.30 of the side —
    // the radius that made 0.7.5's rounded key — and a stadium has no radius to
    // choose: `Capsule` is always half the short side, which is the definition of
    // the shape E1 names. Keeping the constant would have left a number that
    // nothing reads and that the next reader would try to tune.

    /// The row the orb and the lamp cluster share, level with the cutout.
    ///
    /// Floored at 44 rather than sized to the orb: the orb is the flip
    /// gesture's target (see `DeviceChassis.lcdOrb`), and shrinking a control's
    /// art is not a licence to shrink its touch area below the platform
    /// minimum. The extra points are padding around the bead, not more bead.
    ///
    /// **This measured the orb's width until 0.7.9 (A1/A3), and it had to stop.**
    /// One number was doing two jobs — the height of the notch-level *row* and
    /// the side of the orb's square hit box — which was invisible while the orb
    /// was 35pt wide and 44 was the floor either way. At 79.44 it stops being
    /// invisible: `max(islandOrb + 8, 44)` would be 87.44, which is the row's
    /// height as well as the target's width, and `islandTopInset` would floor to
    /// 8 and stop centring the row on the cutout at all. So this is the **short**
    /// axis now — the orb's height plus its padding — and it resolves to exactly
    /// the 44 it has resolved to since 0.6.6. The wide axis is `islandOrbSlot`.
    public static var islandSlot: CGFloat { max(islandOrbHeight + 8, 44) }

    /// The orb's touch slot across (0.7.9, A3).
    ///
    /// A3's rule: the slot grows to contain the bead. 87.44pt at SMALL and 94.30
    /// at LARGE — 4pt of transparent padding either side of the orb, which is
    /// the same slack `islandSlot` used to give it and is what centres the bead
    /// inside its target.
    ///
    /// The 44pt floor stays for the degenerate case, but it has not bound since
    /// 0.6.6 and certainly does not now; the *height* is what the platform
    /// minimum is protecting, and that is `islandSlot`'s job.
    public static var islandOrbSlot: CGFloat { max(islandOrb + 8, 44) }
    // `islandLampRow` retired in 0.6.7 (F1): the two red lamps are no longer
    // in this strip at all. They spent 0.6.6 on bare chassis below the cutout,
    // which is where the device reported them rendering *outside* the LCD's
    // border — because they were: bare chassis is outside the housing. They
    // are on the white bezel now (see `bezelTopMargin`), so the band they used
    // to need here is gone and the strip is 10pt shorter for it.
    /// Floor for the island strip: the inset above, the notch-level row, then
    /// the small `islandBottomInset` against the screen housing. Computed — it
    /// follows `controlButton`, which follows `UIScale`.
    ///
    /// ~54 at SMALL, down from 64 (0.6.7, F1/F2) and from 84 before that. This
    /// number is charged straight to the LCD on any device whose real top inset
    /// is smaller than it; a Dynamic Island reports 59, so at this size the
    /// strip costs the LCD *nothing* — the hardware inset is the binding
    /// constraint rather than our own floor, which is the whole of F4: there is
    /// no dead space up here left to reclaim, because the strip stopped being
    /// the thing setting its own height two batches ago.
    public static var islandStripMinHeight: CGFloat {
        islandTopInset + islandSlot + islandBottomInset
    }

    /// **What the LCD actually pays for the strip** (0.6.9, B1).
    ///
    /// B1 asks for the screen back at the top, and this is where the empty
    /// space up there actually was. `islandStripMinHeight` sizes the *band the
    /// controls are drawn in*, and the chassis reserved that same number — or
    /// the device's reported `safeAreaInsets.top`, whichever was larger — as
    /// dead layout above the screen housing. On a Dynamic Island phone that is
    /// 59pt, and 59 is not a measurement of anything the chassis contains: it
    /// is the inset iOS reserves for its own status furniture, which this app
    /// hides (`.statusBarHidden()`) and draws over anyway.
    ///
    /// What the housing genuinely has to clear is the *cutout* — the island's
    /// plate ends at `islandNotchTop + islandNotchHeight` (48pt), and anything
    /// drawn above that line is masked by hardware. So the reserve is that,
    /// plus the small `islandBottomInset`, and it is a **cap** rather than a
    /// second floor: the flank is a sibling overlay in `frontFace`, not a stack
    /// member, so it may stand taller than the space the housing yields to it.
    /// The only thing that overhangs is the orb's transparent touch padding —
    /// its slot's bottom edge lands at ~51.5 against a housing starting at 50,
    /// and the bead itself ends at ~47.6, well clear.
    ///
    /// Worth 9pt of LCD on an island device, and nothing at all on a device
    /// whose real inset is already smaller — which is correct: there is no
    /// empty space to reclaim there.
    public static var islandStripReserve: CGFloat {
        islandNotchTop + islandNotchHeight + islandBottomInset
    }
    // `islandClearance` and `islandFlankPaddingH` retired in 0.6.8 (F2/F3).
    //
    // Both existed to build the row out of a *fixed* gap held open for the
    // cutout: one padding either side, a hard 158pt spacer in the middle, and
    // the trio centred in whatever the spacer left. F2 moves the orb inboard
    // and F3 moves the trio outboard, which the fixed-clearance form could only
    // express by editing the clearance and the paddings in opposite directions
    // and hoping the middle still cleared the island. The row is now simply
    // "orb at its inset, spacer, trio at its inset", and the cutout's clearance
    // is what is left over — on a 393pt phone the orb ends at 88 and the trio
    // starts at ~302 against an island spanning 133–259, so the gap is
    // 45pt/43pt of margin rather than a number to maintain.

    /// Whether this display has a notch or a Dynamic Island (AUDIT **L32**).
    ///
    /// **Nothing reads this since the clearance went.** L32 added it to gate
    /// `islandClearance` — the 138pt hole the row held open in its middle —
    /// which the note above retires, and the row that replaced it needs no
    /// per-device branch. Kept rather than deleted for the reason
    /// `bandBundleDX` is kept: the *signal* is the part that was hard to get
    /// right, and it is the one thing a future pass on `islandStripReserve`
    /// would have to rediscover, since that reserve is unconditional and spends
    /// ~50pt at the top of a device with no cutout to clear.
    ///
    /// Keyed off the **bottom** inset, and that is the whole subtlety. The
    /// obvious signal is `safeAreaInsets.top`, and it is wrong here: the app
    /// sets `.statusBarHidden()` (`VinodexApp`), which can collapse the top
    /// inset to zero *on cutout devices* — see the note on
    /// `islandStripMinHeight`. Keying anything off it would therefore close the
    /// gap on exactly the phones that need it open.
    ///
    /// The home indicator has no such trapdoor: nothing this app does hides
    /// it, and the device split is clean — every display with a cutout has one,
    /// and every home-button device (the SE class) has neither. So a zero
    /// bottom inset means a flat top edge.
    public static func hasDisplayCutout(bottomSafeArea: CGFloat) -> Bool {
        bottomSafeArea > 0
    }

    /// How far in from the leading edge the orb's slot starts (0.6.8, F2).
    ///
    /// 44, out from `cornerGuardH`'s 26. The orb was in the display's corner
    /// because that is where a corner control goes — but it is a *lamp*, not a
    /// control the thumb has to reach, and the corner is also where the 55pt
    /// display arc is eating the most room. Moving it inboard puts it on flat
    /// glass and opens the corner it was crowding.
    ///
    /// **64 since 0.7.0 (G1)**, another 20 inboard. G1 moves the orb right and
    /// the coloured lights left — the two clusters travelling toward each other
    /// along the row 0.6.9's E1 levelled them on. The vertical alignment is
    /// untouched: both still centre on the cutout's line, which is what E1
    /// asked for and what `islandFlank`'s `.center` alignment does with nothing
    /// correcting it.
    ///
    /// The budget is the cutout, and it is checked rather than guessed: on the
    /// narrowest island device (393pt) the orb's 44pt slot now runs 64→108
    /// against an island starting at 133, so ~25pt of clearance remains. Both
    /// clusters keep more margin than the 20pt the row was designed around.
    ///
    /// ---
    ///
    /// **Derived, and 28 rather than 64, since 0.7.9 (A2).** A1 widened the orb
    /// from 35.2 to 79.44 (SMALL) and 40.48 to 86.30 (LARGE), which spends the
    /// clearance above directly: held at 64 the bead would have ended at 147.4
    /// and 154.3 against a cutout starting at 133 — *under the island*, at both
    /// scales. A2's instruction is explicit that the answer is to move the bead
    /// rather than shrink it back, so this moves.
    ///
    /// It is expressed as a rule rather than as a fresh literal, and the rule is
    /// the mirror A1 is chasing: **the orb's bounding box sits on the same inset
    /// the trio's outer edge does.** `islandStatusInsetTrailing` is
    /// `cornerGuardH + 6` = 32, the slot gives the bead 4pt of padding, so the
    /// slot starts at 28 and the *bead* starts at 32. Two clusters of identical
    /// width, at identical insets, on a cutout that is itself centred — which is
    /// why the two clearances below come out within half a point of each other
    /// rather than by coincidence.
    ///
    /// **The re-derivation A2 asks for**, on the narrowest island device (393pt,
    /// island spanning 133–259.5):
    ///
    /// | | SMALL | LARGE |
    /// |---|---|---|
    /// | orb | 32 → 111.4 | 32 → 118.3 |
    /// | orb clearance | **21.6** | **14.7** |
    /// | slot | 28 → 115.4 | 28 → 122.3 |
    /// | slot clearance | **17.6** | **10.7** |
    /// | trio | 281.6 → 361 | 274.7 → 361 |
    /// | trio clearance | 22.1 | 15.2 |
    ///
    /// It fits at LARGE, which A2 names as the case to stop on if it did not.
    /// LARGE is tighter than SMALL for the reason `islandStatusInsetTrailing`
    /// records: the lamp is `max(controlButton × 0.33, 22)` and the 22 floor
    /// binds at SMALL, so the cluster grows 8.6% going to LARGE while the
    /// device does not grow at all.
    ///
    /// **The corner guard, re-checked because the slot moved inboard of 32 for
    /// the first time.** `cornerGuardH` is 26 and the slot's leading edge is 28,
    /// so even the transparent padding clears it. The binding line is subtler:
    /// the display's 55pt arc eats `55 − √(55² − (55−y)²)` at height y, which is
    /// 26.4pt at the slot's top edge (y = 8) — 1.6pt inside 28, and the pixels
    /// there are empty padding. Where the bead actually is (y ≈ 22.5–37.5) the
    /// arc has closed to 10.6pt, less than a third of the way to it. There is no
    /// room left for a third pass to spend, and A4's standing instruction
    /// applies with full force: **do not move this again without re-deriving
    /// the table above.**
    public static var islandOrbInsetLeading: CGFloat {
        islandStatusInsetTrailing - (islandOrbSlot - islandOrb) / 2
    }
    /// How far in from the trailing edge the lamp trio ends (0.6.8, F3).
    ///
    /// `cornerGuardH`, i.e. the trio is trailing-aligned on the same inset the
    /// orb used to hold on the leading side — so the two clusters read as a
    /// mirrored pair of *blocks* even though the trio is half again as wide as
    /// the orb's slot. 0.6.7 (F3) centred the trio in the whole corner region
    /// instead, which put it ~70pt further left than this and left an obvious
    /// empty run of chassis outboard of it.
    ///
    /// **`cornerGuardH + 20` in 0.7.0 (G1)** — the trio's half of the same
    /// move, kept as an offset from the guard rather than as a fresh literal so
    /// the two clusters still travel the same distance from their own edges and
    /// stay a mirrored pair.
    ///
    /// **Back to `cornerGuardH + 6` in 0.7.1 (A4), and the reason is a warning
    /// about how this number gets spent.** G1's note claimed "~282→347 against
    /// an island ending at 259: ~23pt of clearance". That was true when it was
    /// written and stopped being true in the same release: a 282→347 span is
    /// 65pt, which is the *old* 17pt trio, and A5 then grew the lamps to 22pt
    /// for a 79.4pt trio without re-deriving the span. Worse, both edits were
    /// budgeted against the same figure — the "~43pt of clearance" 0.6.8
    /// measured — G1 spending 20 of it and A5 another 17, neither aware of the
    /// other. Actual clearance had fallen to **8.1pt** at UI SIZE = SMALL and
    /// **1.2pt** at LARGE, where the orb is 40pt and the trio 86.3: the
    /// leftmost lamp was touching the cutout.
    ///
    /// At `+6` the trio spans 281.6→361 at SMALL and 274.7→361 at LARGE, for
    /// 22.1pt and 15.2pt of clearance against an island ending near 259.5 on a
    /// 393pt phone. The mirrored-pair reading survives — the orb's own leading
    /// inset is `cornerGuardH`, so the two clusters are within six points of
    /// travelling the same distance from their edges.
    ///
    /// **Do not spend this again without re-deriving the span.** The trio is
    /// `islandOrbWidth(lamp: islandStatusDot, spacing: statusDotSpacing)`; the
    /// clearance is `deviceWidth − thisInset − trio − islandRightEdge`, and the
    /// binding case is LARGE, not SMALL.
    ///
    /// **One correction to the sentence this used to carry** (0.7.9, A2): it
    /// said "both of those scale with `UIScale`", and only the lamp does.
    /// `statusDotSpacing` is `0.42 × rem` with `rem` a fixed 16, so the two gaps
    /// are 6.72pt at every size. That is why the trio grows only 8.6% between
    /// the scales rather than 15%, and it is load-bearing for the clearance
    /// table on `islandOrbInsetLeading`.
    ///
    /// **Since 0.7.9 (A1) this inset is also the orb's**, by way of
    /// `islandOrbInsetLeading`, which derives itself from this number so the two
    /// clusters cannot drift apart. Changing this moves both ends of the row.
    public static let islandStatusInsetTrailing: CGFloat = cornerGuardH + 6
    // `islandStatusRise` retired in 0.6.9 (E1). 0.6.8's F3 lifted the lamp trio
    // 6pt off the orb's centre line so the two clusters read as separate
    // objects rather than as one interrupted row of four lamps. E1 answers
    // that directly: the orb and the coloured lights are to be **level**. The
    // separation is carried by the ~215pt of cutout between them, which is
    // more than enough on its own.
    /// The **white** bezel strip above the LCD — and, since 0.6.8 (D), the two
    /// red status lamps' home.
    ///
    /// The lamps have now lived in four places, and it is worth writing the
    /// anatomy down once so the fifth does not happen. Outside in, the screen
    /// assembly is: the chassis moulding, then the *white housing plate*
    /// (`skin.panel`, chamfered, rimmed by `screenPanelBorder`), then the *dark
    /// grey band* (`Dex.stone800`, `bezelFrame` thick), then the LCD itself.
    ///
    /// - 0.6.5 put the lamps in this white strip when it was 10pt tall.
    /// - 0.6.6 (D1) moved them onto bare chassis under the cutout — outside the
    ///   housing altogether, which is what "floating off the LCD's border"
    ///   meant.
    /// - 0.6.7 (F1) brought them back onto the *dark grey band*, by thickening
    ///   its top edge into a 12pt stone lamp strip.
    /// - 0.6.8 (D) puts them back on the white plate, which is where they were
    ///   asked for: the grey band keeps one uniform `bezelFrame` all the way
    ///   round (D1), and this strip grows from 2 to 20 so an 8pt lamp has real
    ///   white moulding around it rather than a seam to straddle (D2, D3).
    ///
    /// 20 is the lamp's own diameter plus half of it again above and below.
    /// This is the one dimension in the housing that is *spent* rather than
    /// borrowed — it costs the LCD ~10pt net once the stone strip it replaces
    /// is handed back.
    public static let bezelTopMargin: CGFloat = 20
    // `bezelLampStrip` retired in 0.6.8 (D1). It was the thickened top edge of
    // the grey band, and D1's whole content is that the band goes back to one
    // width on all four sides — `bezelFrame` is that width, and there is no
    // longer a second one.
    /// Spacing between the three status lamps. Widened with the lamps
    /// themselves (0.6.6, E3; again 0.6.7, F3; again 0.7.1, A5/A6) so the trio
    /// still reads as three lights rather than one blob now that each is
    /// bigger — and now that each carries a milled rim of its own, which needs
    /// a little air around it or three rims run together into a chain.
    public static let statusDotSpacing: CGFloat = 0.42 * rem
    /// The three lamps in the strip's right corner, level with the cutout.
    ///
    /// Bigger again in 0.6.7 (F3) — 0.6.6 sized them off the orb at 0.38 and
    /// they still read as specks beside a cutout 37pt tall.
    ///
    /// **Bigger again in 0.7.1 (A5).** 0.6.7's ~18pt lamps were legible; what
    /// they were not was *equipment*. The orb across the strip is 35pt, and at
    /// half that the trio still read as indicator pinpricks rather than as the
    /// other half of a mirrored pair of blocks — which is what 0.6.8's F3
    /// arranged them to be. 0.60 of the orb, floored at 22, puts them at 22pt,
    /// and A6's recessed rim needs the diameter: the wall, the lip and the
    /// specular bead are all fractions of it and none of them survive at 17.
    ///
    /// The trio grows from 62pt wide to 79.4 at UI SIZE = SMALL and 86.3 at
    /// LARGE. That was paid for twice over — see the correction on
    /// `islandStatusInsetTrailing`, which is where the room actually came
    /// from — and the arithmetic is written out there rather than here because
    /// the inset is the thing anyone changing this has to look at.
    ///
    /// **Sized off `controlButton` rather than off `islandOrb` since 0.7.9
    /// (A1), and the value does not move.** A1 makes the orb's width the trio's
    /// width, so `islandOrb × 0.60` would be a cycle: orb ← trio ← lamp ← orb.
    /// The lamp was only ever a fraction of a fraction of the control anyway —
    /// 0.55 × 0.60 = 0.33 — so pointing it straight at `controlButton` breaks
    /// the cycle and produces the identical 22.0 / 24.29 it produced before.
    /// The 22 floor still binds at SMALL and still does not at LARGE, which is
    /// why the two scales' orb aspects differ; see `islandOrbAspect`.
    public static var islandStatusDot: CGFloat { max(controlButton * 0.33, 22) }
    // `statusDotsGap` and `statusDotsRise` retired in 0.6.5 (C1): both measured
    // the cluster's placement relative to the orb, and the cluster no longer
    // sits beside the orb — it has the opposite corner of the strip to itself.
    public static let titleSize: CGFloat = 0.9375 * rem

    /// Screen housing
    public static let screenPanelCorner: CGFloat = 2 * rem
    /// The housing's rim — **the outermost line on the main screen**, and
    /// thicker for it since 0.6.9 (B2).
    ///
    /// 6, up from 4. Worth saying which line this is, because the chassis has
    /// several and B2 names one of them by position rather than by part. From
    /// the display's edge inward the main screen draws: bare shell (no outline
    /// — `chassisBorder` and `chassisBorderInset` are declared above but have
    /// never been drawn, and the shell runs to the physical bezel), then *this*
    /// stroke around the chamfered screen housing, then the `Dex.stone800`
    /// grey band (`bezelFrame`), then the LCD. So this is the outermost line
    /// that exists.
    ///
    /// Costs the LCD nothing: it is a `strokeBorder` on an overlay, inset into
    /// the housing's own bounds, so what it takes it takes from the white
    /// panel colour and not from the screen's height.
    public static let screenPanelBorder: CGFloat = 6
    /// How far the housing's two white strips hold their contents off the rim
    /// (0.6.9, B2).
    ///
    /// The rim is an *overlay* on the housing's full bounds, so it is drawn
    /// across the outer `screenPanelBorder` points of whatever the housing's
    /// stack put there — which, top and bottom, is the lamp strip and the vent
    /// strip. At 4pt that was invisible: the top lamps cleared it by 2pt and the
    /// wordmark's own inset happened to land exactly on it. At 6 it crosses the
    /// top of both red lamps and cuts 2pt off the bottom of the wordmark and the
    /// last grille slat.
    ///
    /// So the strips centre their contents in the part of themselves that is
    /// still white, rather than in their full bounds. That is also the correct
    /// reading of F1's "centred along that bezel" — the bezel is the moulding
    /// you can see, not the box it is laid out in. Deliberately derived from the
    /// border rather than being a number of its own, so thickening the rim again
    /// cannot re-open this.
    public static var housingRimGuard: CGFloat { screenPanelBorder }
    public static let screenPanelInset: CGFloat = 0.5 * rem   // m-2
    /// The housing's keyed corner (0.6.5, C2): the bottom-left is a straight
    /// diagonal cut rather than an arc, the way a moulded bezel is keyed so the
    /// part only seats one way round. Sized a little larger than
    /// `screenPanelCorner` — a chamfer the same size as the arcs beside it
    /// reads as a rounding error rather than as a deliberate cut.
    public static let screenPanelChamfer: CGFloat = 2.25 * rem
    public static let bezelCorner: CGFloat = 1.75 * rem
    public static let bezelInsetH: CGFloat = 0.75 * rem       // mx-3
    /// Thickness of the stone frame around the LCD. Kept small on purpose:
    /// every point here is a point of screen height.
    public static let bezelFrame: CGFloat = 4
    /// The white panel's skirt below the LCD. Deliberately taller than
    /// `bezelTopMargin` rather than matched to it: this one has to seat the vent
    /// dot and the three grill slats, and at 1rem they were crowding its edges.
    /// The top margin holds nothing, so it stays thin.
    public static var ventStripHeight: CGFloat { 1.75 * rem * CGFloat(UIScale.current.factor) }
    /// The **pair of red lamps on the white top bezel** — bigger since 0.6.9
    /// (B3).
    ///
    /// 0.65rem, up from 0.5 (8pt → 10.4). Sized against the strip they sit in
    /// rather than picked: `bezelTopMargin` is 20 and stays 20, because growing
    /// it would spend at the top exactly what B1 is reclaiming there, and B2
    /// takes `housingRimGuard` (6) off the usable part of it. That leaves a
    /// 14pt clear band, in which 10.4 keeps ~1.8pt of white above and below —
    /// still seated in the plate rather than straddling a seam, which is the
    /// whole reason 0.6.8 (D3) grew the strip in the first place.
    ///
    /// Deliberately still a shade under `bottomVentDot` (12): 0.6.8's G3 made
    /// the lone lamp downstairs the larger part because it sits by itself at
    /// the end of a wide strip, and B3 closes that gap without inverting it.
    public static var ventDot: CGFloat { 0.65 * rem * CGFloat(UIScale.current.factor) }
    /// The bottom strip's lone status lamp (0.6.8, G3).
    ///
    /// Half again the diameter of the pair upstairs. They are not the same
    /// part: the two on the white bezel are a matched power/link pair reading
    /// as one unit at the top of the display, while this one is by itself at
    /// the far end of a 28pt strip next to a wordmark and a grille, and at
    /// `ventDot` it read as a speck of dirt rather than as a lamp.
    public static var bottomVentDot: CGFloat { 0.75 * rem * CGFloat(UIScale.current.factor) }
    // `grilleRise` retired in 0.6.9 (F1). 0.6.8's G1 lifted the slats 5pt off
    // the bottom strip's centre line on an optical argument — four thin rules
    // with air between them read low when geometrically centred. F1 asks for
    // the lamp, the wordmark and the grille to be centred along that bezel, and
    // an optical correction on one of the three is exactly what stops them
    // reading as one row. The strip centres all three now; see `bottomVents`.

    /// The bottom-strip wordmark (0.6.7, H1).
    ///
    /// Nominal glyph size only — what actually lands on screen is this run
    /// measured and then scaled to fill the slot between the red lamp and the
    /// grille, independently in x and y. So this number sets the *proportions*
    /// of the letterform, not its size: the smaller it is, the more the
    /// stretch, and Press Start 2P at 12 gives a run wide enough that the
    /// horizontal scale lands around 1.3× the vertical one — stretched, but
    /// still recognisably the same face rather than a smear.
    public static let wordmarkSize: CGFloat = 12
    /// Letter spacing applied **before** the run is measured, which is what
    /// makes it the wordmark's proportion control rather than a spacing tweak
    /// (0.6.8, G2 — it was hardcoded at 5 inside `StretchedWordmark`).
    ///
    /// The slot is fixed, so the horizontal scale is `slot / natural`, and
    /// tracking is most of `natural`. Dropping it from 5 to 2 shortens the
    /// measured run ~18%, which the fit gives straight back as scale — so the
    /// *glyphs* come out ~21% wider while the *gaps* between them come out
    /// roughly half what they were. One number moving in one direction is
    /// exactly G2's "reduce character spacing, increase character width".
    public static let wordmarkTracking: CGFloat = 2
    /// Breathing room inside the wordmark's slot, so the stretched glyphs do
    /// not touch the strip's edges or the parts either side of them.
    ///
    /// The vertical inset is also G2's height control: it is subtracted from
    /// the strip twice, so 4 (from 2) takes ~17% off the glyphs' height while
    /// the width above grows. Between them the letterform goes from ~1.3×
    /// wider-than-tall to ~1.9×.
    public static let wordmarkInsetV: CGFloat = 4
    public static let wordmarkInsetH: CGFloat = 10

    /// Footer
    ///
    /// Trimmed from the web app's 6.5rem band: the marquee was tall enough to
    /// crowd the LCD on a phone, and its height is what drives the footer's.
    ///
    /// The band is **deliberately asymmetric** — `footerTopInset` above the row,
    /// `chassisEdgeInset` below. It was centred in a band shared with the island
    /// strip, which put an equal 16pt on both sides; but the two sides are not
    /// equivalent. Below the row is home-indicator territory and has to stay
    /// clear, while above it is just a gap to the screen housing, and closing
    /// that gap is what brings the controls up under the screen where the thumb
    /// already is.
    ///
    /// It still deliberately does **not** add the home-indicator safe-area
    /// inset: that inset alone is 34pt and made the bottom chrome nearly twice
    /// the top. The indicator falls in the `chassisEdgeInset` of bare chassis
    /// below the row rather than over a control.
    /// Two control rows since 0.6.5 — Back sits under Home — so the band is
    /// `bandHeight` tall rather than one control.
    public static var footerHeight: CGFloat { footerTopInset + bandHeight + chassisEdgeInset }
    /// Gap between the screen housing and the footer row. Much tighter than the
    /// inset below the row — see `footerHeight`. 4, down from 6 (0.6.8, E5).
    public static let footerTopInset: CGFloat = 4
    /// The band's own horizontal inset (0.6.8, E2).
    ///
    /// 10, in from `cornerGuardH`'s 26 — the buttons go to the edges, which is
    /// the whole of E2. `cornerGuardH` is the clearance a control's *bounding
    /// box* needs to clear the display's 55pt corner arc, and it was always
    /// conservative for a circle: the bottom cap's lowest point sits at
    /// `chassisEdgeInset` (16) where the arc has eaten ~16pt, but that point is
    /// the width of nothing at all. Walking the circle at 10pt of padding, the
    /// tightest approach is ~7pt clear of the arc at y≈20, and the cap's widest
    /// point sits at y≈56 where the corner has closed entirely.
    ///
    /// Deliberately no longer shared with the island strip, which keeps
    /// `cornerGuardH`: F2 and F3 move the top-row clusters on their own axes in
    /// this batch, so the old "one padding, four controls in two columns" rule
    /// had already stopped describing the chassis.
    public static let bandPaddingH: CGFloat = 10
    /// **One** diameter for every physical control on the chassis: the orb and
    /// the cog on the island strip, Back/saved and Home in the footer.
    ///
    /// The island pair used to be 3.5rem against the footer's 4rem, on the
    /// argument that the footer buttons are the ones in constant use. Sitting in
    /// the same two columns at two different sizes just read as a mistake, so
    /// they are all `footerControl` now and the strip is sized to seat it.
    public static var controlButton: CGFloat { footerControl }
    /// Computed, not stored: the chrome members follow `UIScale.current`
    /// (v0.5.8, F1), and a stored `let` would freeze whatever the factor was
    /// at first touch. Text sizes deliberately do not scale here — they have
    /// their own axis in `TextScale`.
    public static var footerControl: CGFloat { 4 * rem * CGFloat(UIScale.current.factor) }
    public static let marqueeMaxWidth: CGFloat = 16.5 * rem
    public static let marqueeCorner: CGFloat = 0.8 * rem
    public static let marqueeInnerCorner: CGFloat = 0.6 * rem
    /// Taller than the controls flanking it since 0.6.5 (B1): the marquee is
    /// the band's centrepiece now, not a strip squeezed between two buttons,
    /// and a panel that matched the button diameter read as the smallest thing
    /// in the band rather than the largest. Taller again in 0.6.6 (C1) — the
    /// diagonal cluster gave the band back the height to spend on it.
    ///
    /// **Measured off the band rather than off the button since 0.6.7 (G/F4).**
    /// It was `bandControl * 1.32`, and G2's smaller common diameter would have
    /// quietly taken 10pt off the panel as a side effect of resizing the
    /// buttons — the centrepiece shrinking because something else did. The band
    /// is as tall as a bundle whatever happens; this is simply the rest of that
    /// column once the two indicator lamps and their gap are out of it, so the
    /// panel fills its slot exactly.
    ///
    /// That construction is what makes E5 free in 0.6.8: the band roughly
    /// doubled in height to seat the bigger controls, and the panel took all of
    /// it — ~149pt against 0.6.7's ~83 — without a number changing here. The
    /// glyphs grew with it (see `marqueeTextSize`), because a panel that tall
    /// carrying 19pt letters is dead space wearing a green coat.
    public static var marqueeHeight: CGFloat {
        max(bandHeight - bandPillHeight - bandPillGap, bandControl)
    }
    // `marqueeFade` retired in 0.6.9 (D1). It sized the gradient mask at each
    // end of the strip to one glyph cell, so a character was always mid-fade
    // as it passed behind the housing. Nothing passes behind anything now: the
    // panel holds a still, fitted label, and a ramp over its first and last
    // glyph would simply dim the words.

    /// One size for every screen — **28pt since 0.6.9 (D4)**, up from 24.
    ///
    /// The history is a pendulum and it is worth knowing why this swing is
    /// different. 1.5rem was the 0.6.8 value, itself back up from the 1.2 that
    /// v0.5.4 trimmed to on the grounds that the strip "read louder than the
    /// buttons beside it". Both of those arguments were about a *scrolling*
    /// line, which could only ever be one line: every point of size bought
    /// there was a point of tail that had to scroll past.
    ///
    /// D1 removed the scroll, so the constraint changed rather than the taste.
    /// A still label can wrap to two lines and shrink into its box, which means
    /// the nominal size is a *starting* size rather than a commitment — see
    /// `MarqueeBanner.title` for the three fallbacks behind it. D4 says there is
    /// room, and with the panel ~115pt tall carrying a glyph and a wrapped
    /// title, there is.
    public static let marqueeTextSize: CGFloat = 1.75 * rem

    /// The page glyph above the title (0.6.9, D2).
    ///
    /// A third of the panel — deliberately sized off the *panel* rather than
    /// off the type. It is chrome, not a character: a symbol that scaled with
    /// SETTINGS > TEXT SIZE would grow inside a panel whose height does not,
    /// and at the HUGE step would push the words it introduces out of the
    /// bottom of it. The title takes whatever is left and fits itself to that.
    public static var marqueeGlyph: CGFloat { marqueeHeight * 0.32 }
    /// Air between the glyph and the title. Tight: they are one block, and a
    /// generous gap here reads as two unrelated things sharing a panel.
    public static let marqueeGlyphGap: CGFloat = 4
    /// Side margin inside the panel, so the wrapped title does not touch the
    /// rim. Larger than the 6 the old still label carried, because the label is
    /// now allowed to fill the panel rather than sitting in the middle of it.
    public static let marqueeTextInset: CGFloat = 10

    // `marqueePinButton`, `marqueePinInset` and `marqueePinGlyph` retired in
    // 0.7.6 (A1), with the corner pin buttons they measured.
    //
    // They were 26 / 4 / 13, and the 26 was the interesting one: below the 44pt
    // Apple asks for, and defended on the grounds that the marquee is roughly
    // 60pt tall, two 44pt circles would leave the title a slot rather than a
    // panel, and every destination they reached was also reachable at full size
    // from the drawer and the settings grid.
    //
    // Both halves of that defence are gone in the same batch — the drawer no
    // longer exists, and the two lamp buttons directly above the panel now carry
    // the same pins at `bandPillHeight` (24) across half the panel's width each,
    // which is a target several times the area. Written down rather than deleted
    // silently because "put small round shortcut buttons in the marquee corners"
    // is an idea that will come back, and this is where the arithmetic against it
    // lives.

    // `MarqueeBanner.edgeReserve` — the width the label kept clear for those
    // buttons — is now zero everywhere. The parameter survives on the banner
    // rather than being removed, because "keep your ends clear" is a property
    // worth having the next time something is drawn over the panel, and it costs
    // one defaulted argument.

    /// The ordinary marquee cross-fade — a route title replacing another.
    ///
    /// Was the greeting cycle's fade (0.6.9, D3), and outlived the cycle:
    /// 0.7.1's B1-B3 retired the five-toast loop and `marqueeGreetingDwell`
    /// with it (the dwells are `MarqueeStage.timeout` now, in Core, where they
    /// can be tested), but every screen's title still arrives this way. 0.55s
    /// is slow enough to read as a change and short enough not to lag a
    /// navigation the rest of the app has already completed.
    public static let marqueeGreetingFade: Double = 0.55

    /// Overlay in and out: alerts, prompts, the marquee's lamp chooser, a mode
    /// switching under a picker (0.7.1, F3).
    ///
    /// 0.15s eased out. Not a new number — it is the one thirteen call sites
    /// across seven files had already converged on by writing
    /// `.easeOut(duration: 0.15)` out longhand. F3 asks for the timings to be
    /// standardised, and the honest first step is to notice that most of them
    /// already were and give the agreement a name, so that the fourteenth
    /// overlay inherits it instead of guessing again. See `DexMotion`.
    public static let overlayFade: Double = 0.15

    /// The pixel dissolve between the main screen's scripted stages
    /// (0.7.1, B2/B3).
    ///
    /// **Two and a half times the cross-fade, deliberately.** B2 asks for a
    /// *slow* pixelated fade, and slowness is doing real work here rather than
    /// being a stylistic preference: the effect is cells switching over one at
    /// a time, and below about a second there are not enough frames between
    /// the first cell and the last for a viewer to see them go individually —
    /// it collapses into a single flicker and reads as a glitch. 1.4s is the
    /// point where WELCOME! is visibly *eroding* into MENU.
    ///
    /// It can afford to be slow because nothing waits on it. Both transitions
    /// it runs are unprompted — a launch settling, and ten seconds of nobody
    /// touching the device — so there is no user standing by for it to finish.
    /// That is also why it never runs on a route title, which always has
    /// someone waiting: see `MarqueeBanner.slowFade`.
    public static let marqueePixelFade: Double = 1.4

    /// The same dissolve on a page title (0.8.5, A3).
    ///
    /// A3 asks for the pixelated transition on **every** change of the panel,
    /// which the paragraph above declined for a reason that was about duration
    /// rather than about the effect: a route title always has somebody standing
    /// in front of it waiting to read the page they just opened.
    ///
    /// 0.42 is that objection priced rather than upheld. It is a little under
    /// the 0.55s cross-fade it replaces, so navigation is no slower than it was
    /// — and it is above the ~0.35s floor where the cells stop reading as cells
    /// and collapse into the single flicker `marqueePixelFade` describes. The
    /// glyph and the word cross together on the same clock, so what a user sees
    /// on arriving at a page is one panel repainting, which is what the object
    /// on the chassis is.
    public static let marqueeRoutePixelFade: Double = 0.42

    /// Button band (0.6.5, A/B; restructured 0.6.7 G, resized 0.6.8 E)
    ///
    /// Four physical controls in **two vertical bundles** — User over Settings
    /// on the left, Home over Back on the right — flanking the marquee panel,
    /// each pair sunk into its own capsule well.
    ///
    /// **1.25 of `footerControl`, up from 0.72 (0.6.8, E1).** That is 80pt
    /// against 46.1 — 1.74× the diameter and 3× the area — and it is as far as
    /// E1's "roughly 2×" can be taken without the marquee going backwards,
    /// which is worth setting out because the arithmetic is forced rather than
    /// chosen:
    ///
    /// Two caps that do not overlap sit at least one diameter apart. A pair on
    /// a diagonal therefore costs the row `d · (1 + dx/d)` of *width* on each
    /// side, and 0.6.7's `dx` of 0.57d was 26pt of that per flank at the old
    /// size — affordable then, and 46pt per flank at this size, which is most
    /// of the marquee. Only a *vertical* pair costs the row nothing beyond one
    /// diameter, so `bandBundleDX` goes to zero and the whole increase is paid
    /// in band height instead. With that, on a 393pt phone: two 88pt bundles,
    /// two 6pt gaps and 20pt of edge inset leave the marquee 185pt — up from
    /// 160, which is E3, and the indicator pills are measured off the marquee
    /// so they widen with it.
    ///
    /// The height is what E4 buys. The band goes 95.6 → 168, the footer 117.6 →
    /// 188, and the screen housing 667 → 599 on an 852pt display: **the LCD is
    /// ~10% shorter**. That is the batch's one real cost and it is deliberate —
    /// E4 authorises it and E5 is the instruction to make sure the height is
    /// actually *used*, which it is: the bundles are 68% circle by area against
    /// the diagonal's 43%, and the marquee panel absorbs the rest of the column.
    ///
    /// `bandControl` no longer undershoots `controlButton` either — it
    /// overshoots it. The "one diameter for every physical control" rule the
    /// island strip follows was already broken in the other direction; what is
    /// true now is that all four footer controls share one diameter, which is
    /// the part of the rule that was ever load-bearing.
    ///
    /// **A quarter smaller in 0.6.9 (C1): 0.9375, i.e. `1.25 × 0.75`.** 80pt
    /// → 60. Written as the product rather than collapsed to `0.9375` in one
    /// step would hide what the instruction was; the factor is spelled out
    /// here instead. The caps stay the largest controls on the chassis and are
    /// still 1.7× the area they were before 0.6.8, so E1's argument survives
    /// the trim — what does not survive is the height it charged the LCD.
    ///
    /// Everything downstream is a fraction of this, so the band, the wells and
    /// the marquee all follow from one number: `bandBundleHeight` goes 168 →
    /// 134 and the footer 188 → 154, which is 34pt straight back to the screen.
    /// See `DexMetrics.islandStripReserve` for the other 9 (B1).
    ///
    /// **A tenth larger again in 0.8.5 (E3): `× 1.10`.** 60pt → 66 at SMALL.
    /// Written as a fourth factor rather than folded into the three before it
    /// for the reason 0.6.9 spelled `1.25 × 0.75` out — the product is the
    /// argument, and collapsing it to `1.03125` would hide four separate
    /// instructions inside one number nobody could read back.
    ///
    /// What it costs, stated where the previous passes stated theirs: every
    /// dimension in the band is a fraction of this, so `bandBundleHeight` goes
    /// 134 → 146 and the whole band with it, and those 12pt come out of the LCD.
    /// That is the same currency 0.6.9's C1 spent in the other direction, and it
    /// is being spent back deliberately: E has now been asked three times, and
    /// each of the first two passes was about the caps *rendering* wrong. Size
    /// is the one complaint about them that no amount of pixel work answers.
    public static var bandControl: CGFloat { footerControl * 1.25 * 0.75 * 1.10 }
    /// Gap between the band's columns. 6, down from 10 (0.6.8, E5) — every
    /// point here is a point of marquee.
    public static let bandSpacing: CGFloat = 6

    // MARK: The button bundles (0.6.7, G1/G2; straightened 0.6.8, E1)
    //
    // Each flank is a **vertical pair in one capsule well** — the SNES face
    // recess that groups X and Y, stood upright. User over Settings on the
    // left, Home over Back on the right.
    //
    // **The diagonal is gone (0.6.8, E1).** 0.6.7's G1/G2 staggered each pair
    // by `0.57d` horizontally so the two wells leaned in toward the marquee,
    // and at a 46pt diameter that read well and cost the row 26pt a side. E1
    // roughly doubles the diameter, at which point the same fraction costs 46pt
    // a side — the marquee's entire growth and then some — and the lean's own
    // dead corners (a diagonal pair fills 43% of its bounding box; an upright
    // one fills 68%) become the largest empty region in the band, which is
    // precisely what E5 is pointing at. Upright is the only arrangement in
    // which a bigger cap costs the row nothing but height.
    //
    // The two flanks are still congruent, so the marquee is centred in the
    // chassis by construction and 0.6.7's F5 still holds for the same reason it
    // did — the geometry is not fighting it.
    //
    // Everything is a fraction of `bandControl`, so a bundle scales with
    // `UIScale` in one piece.

    /// Zero since 0.6.8 (E1) — see the note above. Kept as a named metric
    /// rather than deleted because it is the number the argument turns on, and
    /// a future pass that wants the lean back needs to see what it costs.
    public static var bandBundleDX: CGFloat { 0 }
    /// Air between a bundle's two caps (0.6.9, C3).
    ///
    /// 0.6.8 made them exactly tangent, on the argument that touching caps read
    /// as one moulded part in a single recess. C3 asks for a slight gap, which
    /// is the opposite call on the same question and a legitimate one: tangent
    /// circles share a single pinch point, and at 60pt that pinch reads as a
    /// moulding defect rather than as two parts. 6pt is a tenth of a diameter —
    /// enough to see daylight, not enough to break the pair up. The well still
    /// encloses both, which is what keeps them one bundle.
    public static let bandCapGap: CGFloat = 6
    /// The pair's centre-to-centre separation: one diameter plus `bandCapGap`
    /// since 0.6.9 (C3). It was exactly one diameter — tangent — from 0.6.8.
    public static var bandBundleDY: CGFloat { bandControl + bandCapGap }
    /// Clearance between a cap and the wall of its well. Small — the well is a
    /// recess milled around the buttons, not a tray they are sitting in.
    public static let bandWellPad: CGFloat = 4
    /// 68 at SMALL (0.6.9, C1), down from 88. One padded diameter, and no more.
    public static var bandBundleWidth: CGFloat { bandControl + bandBundleDX + bandWellPad * 2 }
    /// 134 at SMALL (0.6.9, C1/C3), down from 0.6.8's 168: two 60pt caps, the
    /// 6pt `bandCapGap` between them, and the well's own padding either end.
    public static var bandBundleHeight: CGFloat { bandControl + bandBundleDY + bandWellPad * 2 }
    // `bandWellLength` and `bandWellThickness` retired in 0.6.8 (E1). They
    // existed to size a capsule that then had to be *rotated* onto the
    // diagonal, so the well's own box and the bundle's had to be computed
    // separately and kept in agreement. Upright, they are the same box, and
    // `ButtonWell` simply fills it.

    /// The band's own height. A bundle is the tallest thing in it — the
    /// marquee column fits inside this.
    public static var bandHeight: CGFloat { bandBundleHeight }

    /// The drop shadow under every band control (0.6.6, B3).
    ///
    /// Was `0.6 / radius 6 / y 8`, which is a hard black plate under each
    /// circle rather than a shadow — at the band's scale that offset is most of
    /// a button's radius, so every control looked stuck on rather than set in.
    /// One set of tokens so the cog and the three moulded caps cannot drift.
    public static let bandShadowOpacity: Double = 0.28
    public static let bandShadowRadius: CGFloat = 4
    public static let bandShadowY: CGFloat = 3

    /// The two indicator pills above the marquee panel (0.6.5, B2).
    ///
    /// `bandPillWidth` retired in 0.6.7 (F4). It was 18pt, then 30 (0.6.6, C3),
    /// and both were guesses at "wide enough beside the panel". The pair is
    /// sized off the panel itself now: each pill takes half the marquee's own
    /// width less the gap between them, so the two lamps span exactly the strip
    /// they belong to at any screen width or `UIScale`. A fixed width could
    /// only ever be right on one phone.
    ///
    /// 14 tall since 0.6.8 (E3). "Make the marquee and its status lights wider"
    /// gives the width for free — the pills are measured off the panel, so they
    /// gained the same ~16% it did — but two 8pt slivers over a 149pt panel
    /// read as a hairline, not as lamps. Height is the part that had to be
    /// asked for.
    ///
    /// **20 since 0.7.2 (A9), because they are controls now.** The pills are the
    /// TOOLS and CUSTOMIZE buttons — see `indicatorPills` — and 14pt was sized
    /// for a lamp nobody was meant to touch. 20 is the smallest height that
    /// takes a legible glyph at `bandPillGlyph` with a rim either side of it,
    /// and it is still short enough that the pair reads as lamps on the
    /// marquee's housing rather than as a second button row.
    ///
    /// The 6pt comes out of `marqueeHeight`, which is the band's remainder — a
    /// deliberate trade, and the only one available: the band's height is
    /// `bandBundleHeight`, set by the caps either side, and growing it would
    /// take the difference out of the LCD instead.
    ///
    /// **24 since 0.7.5 (A1), and the trade is the same one A9 made.** The band
    /// is `bandBundleHeight` whatever happens (134 at SMALL, 152 at LARGE), and
    /// this column is `bandPillHeight + bandPillGap + marqueeHeight` summing to
    /// exactly that — so 4pt onto the pills is 4pt off the panel and nothing
    /// else in the chassis moves. `marqueeHeight` goes 109 → 105 (SMALL) and
    /// 127 → 123 (LARGE), still well clear of its `bandControl` floor of 60/69,
    /// and `marqueeGlyph` follows it down 34.9 → 33.6 / 40.6 → 39.4.
    ///
    /// **This is not the trio that had the clearance problem.** The pills live
    /// in the footer; the lamps that nearly touched the Dynamic Island are
    /// `islandStatusDot`, at the top of the device, and they share no budget
    /// with this. Their clearance is untouched at 22.1pt (SMALL) / 15.2pt
    /// (LARGE) — see `islandStatusInsetTrailing`, which is where that sum is
    /// written down and where it must be re-derived before anything up there
    /// grows again.
    ///
    /// The floor on shrinking a pill is `RecessedLamp`'s stroke stack, which
    /// eats ~5.8pt off the top edge of a 20pt capsule; 24 gives the glyph more
    /// room inside the recess rather than less.
    ///
    /// **30 since 0.8.5 (A2), and this time the height is not paying for a
    /// glyph.** A2 replaces the mark inside each lamp with the pin's *name* —
    /// TOOLS, CUSTOMIZE, SETTINGS, DATA, SHOP — engraved into the cap the way a
    /// controller's START and SELECT are. A word needs a line height where a
    /// symbol needed a diameter, and 24 left `bandPillLabel` no room between
    /// `RecessedLamp`'s stroke stack above and the rim below. The item asks for
    /// "slightly taller" and 6pt is what the type costs.
    ///
    /// The trade is unchanged from A9 and A1 and is why it is affordable: the
    /// band is `bandBundleHeight` whatever happens, so 6pt onto the pills is 6pt
    /// off `marqueeHeight` and nothing else in the chassis moves. E3 grows
    /// `bandControl` by a tenth in the same batch, which gives the column 12pt
    /// back — so the panel finishes this release taller than it started it.
    public static let bandPillHeight: CGFloat = 30
    /// The glyph inside a pill (0.7.2, A9). A fraction of the pill so the two
    /// move together, and well under half of it so the lamp still reads as a
    /// lamp with a mark on it rather than as a bordered icon.
    ///
    /// Unreached since 0.8.5 (A2) — the lamps carry `bandPillLabel` text now —
    /// and kept because it is what a *third* lamp with no name would need, and
    /// because the fallback path in `MarqueeLampChooser` still draws marks.
    public static var bandPillGlyph: CGFloat { bandPillHeight * 0.52 }
    /// The engraved label inside a lamp (0.8.5, A2).
    ///
    /// Sized off the pill rather than off `TextScale`, for the reason the
    /// marquee's own glyph is sized off the panel: these are moulded parts, and
    /// a legend that grew with SETTINGS > TEXT SIZE would push itself off a cap
    /// whose height does not move. The longest word is CUSTOMIZE at nine
    /// characters, which is what the fitting in `lampButton` is for.
    public static var bandPillLabel: CGFloat { bandPillHeight * 0.42 }
    public static let bandPillSpacing: CGFloat = 8
    /// Gap from the pills down to the panel they belong to. Small — they have
    /// to read as lamps *on* the marquee's housing, not as their own row.
    public static let bandPillGap: CGFloat = 5

    /// Icon wells (v0.5.8, F1): the list-row well and the detail-hero well,
    /// scaled with the chrome so LARGE grows the pictures, not the words.
    public static var iconWell: CGFloat { 48 * CGFloat(UIScale.current.factor) }
    public static var heroWell: CGFloat { 148 * CGFloat(UIScale.current.factor) }

    /// **The standard glyph sizes** (0.8.91, C4).
    ///
    /// §C4 asks for icons to be "generally bigger" and for a bump to "the
    /// standard icon size". There was no such thing: `DexIcon`'s init carried a
    /// default of 30 and every other glyph in the app was a literal at its call
    /// site — 22 on a settings row, 44 on a tools tile, 26/32/48/54 scattered
    /// through the entry page. So the first half of the item is inventing the
    /// constant the second half asks to move, which is why these are here and
    /// not three more literals a batch further on.
    ///
    /// Two sizes, because the app draws glyphs in exactly two registers: beside
    /// a line of text in a row, and as the picture on a tile. `iconWell` and
    /// `heroWell` above already cover the third and fourth (the entry list's
    /// well and the detail hero), and they were already scaled.
    ///
    /// `UIScale`, like the wells and unlike the literals they replace. A glyph
    /// that stayed put while the text beside it grew is the drift these
    /// constants exist to stop; `RootView` keys the whole chassis on the scale,
    /// so the change lands without a relaunch.
    ///
    /// 22 to 28 and 44 to 52 — a quarter and a fifth. Enough to read as bigger
    /// at arm's length, not enough to reflow a row whose height is set by two
    /// lines of type.
    public static var rowGlyph: CGFloat { 28 * CGFloat(UIScale.current.factor) }
    /// The gutter a `rowGlyph` sits in. Wider than the glyph so a tall drawing
    /// and a wide one both centre in the same column.
    public static var rowGlyphGutter: CGFloat { 36 * CGFloat(UIScale.current.factor) }
    public static var tileGlyph: CGFloat { 52 * CGFloat(UIScale.current.factor) }

    /// How long the device takes to turn over.
    ///
    /// Lives here rather than on `DeviceChassis` because that type is generic
    /// over its content, and Swift has no static stored properties on generic
    /// types — the half of this value is what times the face swap, so the two
    /// must come from one number.
    public static let flipDuration: Double = 0.7

    /// The engraved return arrow in the back plate's bottom-right corner
    /// (0.6.8, B3) — the plate's one control, replacing the swipe B2 removed.
    /// Large on purpose: it is the only way off a full-screen surface, and the
    /// swipe it replaces failed because it was invisible.
    public static let backPlateReturn: CGFloat = 92

    // `lcdBackSwipeDistance` and `lcdBackSwipeSlop` retired in 0.6.9 (A1).
    // They were the thresholds that let 0.6.8's app-wide LCD back swipe ride
    // simultaneously with every `ScrollView` in the app without firing on one;
    // A1 removes the gesture, so the numbers describe nothing.

    /// Scanline overlay
    public static let scanlineSpacing: CGFloat = 4
    public static let scanlineThickness: CGFloat = 2
    public static let scanlineOpacity: Double = 0.2
}

// MARK: - Motion

/// The app's shared animation curves (0.7.1, F3).
///
/// **What F3 actually found.** The instruction was to standardise transitions
/// and animations so screen changes, fades and popups feel uniform, and the
/// starting assumption was that they did not. Mostly they did: thirteen call
/// sites in seven files had independently written `.easeOut(duration: 0.15)`
/// for showing an overlay, and two had independently written a spring for a
/// thing being picked up. What was missing was not agreement — it was anywhere
/// to *record* the agreement, so each new surface re-derived it and the ones
/// that drifted (a 0.2/0.6 press spring, a 0.25/0.7 toggle spring, a 0.25/0.65
/// lift spring: three springs for three variations on one idea) drifted
/// silently.
///
/// So this is four named curves rather than a new motion language. Each says
/// what *kind* of event it is for, because that is the question a call site can
/// actually answer — "is this an overlay appearing or a control responding" is
/// answerable; "should this be 0.15 or 0.18" is not.
///
/// Reduce Motion is deliberately **not** handled here. It is a decision about
/// whether a movement should happen at all, and the answer differs per movement
/// — `PulseGlow` settles on a still glow, `MarqueeBanner` swaps the dissolve
/// for a cross-fade, a rising panel swaps a slide for a fade. A curve that
/// secretly became `nil` would hide all three of those judgements behind one.
public enum DexMotion {
    /// Something appearing over the screen and going away again: alerts,
    /// upgrade prompts, the rating sheet, the lamp chooser's scrim.
    public static let overlay = Animation.easeOut(duration: DexMetrics.overlayFade)

    /// One string replacing another in place — the marquee's route titles, and
    /// anything else that changes text without moving.
    public static let crossfade = Animation.easeInOut(duration: DexMetrics.marqueeGreetingFade)

    /// A dragged thing coming to rest, or a segmented control moving its
    /// selection. Damped high: this is furniture settling, not something
    /// springing.
    public static let settle = Animation.spring(response: 0.28, dampingFraction: 0.82)

    /// A control answering a finger — a cap depressing, a stamp lifting off
    /// the plate. Looser, because a physical control that answered without
    /// overshoot at all would read as a picture of a button.
    public static let press = Animation.spring(response: 0.24, dampingFraction: 0.66)
}

// MARK: - Fonts
//
// Registered from the bundle at runtime via CoreText. This is the pattern
// salvaged from the Rork skeleton and it is the correct one here: `actool` is
// macOS-only, so there is no asset catalog to declare fonts in.
//
// Swift 6 strict concurrency forbids mutable statics, so the registration
// result is computed once into an immutable value.

public enum DexFont {
    public struct Registration: Sendable {
        public var registered: [String] = []
        public var failed: [String] = []
        public var available: Bool { failed.isEmpty }
    }

    static let names = (retro: "PressStart2P-Regular", mono: "VT323-Regular")

    public static let registration: Registration = {
        var out = Registration()
        for name in [names.retro, names.mono] {
            guard let url = DexResources.url(named: name, ext: "ttf", in: .fonts) else {
                out.failed.append(name + " (not in bundle)")
                continue
            }
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                out.registered.append(name)
            } else {
                // Already-registered is not a failure worth reporting.
                let code = (error?.takeUnretainedValue() as (any Error)?).map { ($0 as NSError).code } ?? -1
                if code == Int(CTFontManagerError.alreadyRegistered.rawValue) {
                    out.registered.append(name)
                } else {
                    out.failed.append("\(name) (register failed, code \(code))")
                }
            }
        }
        return out
    }()

    /// Font availability resolved once. A face's registration state cannot change
    /// at runtime, so probing `UIFont(name:)` on every `retro`/`mono` call (which
    /// happens per glyph, per render) was pure waste. The initialiser forces
    /// `registration` first so the probe runs after the fonts are registered.
    public static let retroAvailable: Bool = { _ = registration; return isAvailable(names.retro) }()
    public static let monoAvailable: Bool = { _ = registration; return isAvailable(names.mono) }()

    /// The point size a nominal size actually draws at — floor and step applied.
    ///
    /// Public because three places outside `DexFont` need the same number: the
    /// marquee derives its glyph gap from it, and anything measuring a label has
    /// to measure the size that was drawn. Every one of them used to re-derive
    /// `size * TextScale.current.factor` by hand, which stopped being correct
    /// the moment a floor existed.
    public static func resolvedSize(_ nominal: CGFloat) -> CGFloat {
        CGFloat(TypeScale.resolve(nominal: Double(nominal), step: TextScale.current))
    }

    /// The display face's advance width, as a fraction of the point size
    /// (0.8.6, D1).
    ///
    /// Both branches of `retro` are monospaced, so one character's advance is
    /// every character's and a label's width is a multiplication rather than a
    /// layout pass. **Measured rather than assumed** because the two faces do
    /// not agree — Press Start 2P advances a full em where the `.monospaced`
    /// system fallback advances about six tenths of one — so a constant would
    /// have been right for whichever face happened to be registered on the day
    /// it was written, and wrong, invisibly, on a device where registration
    /// failed. Computed once; a face's registration cannot change at runtime.
    public static let retroAdvanceRatio: CGFloat = {
        let probe: CGFloat = 100
        let font = retroAvailable
            ? UIFont(name: names.retro, size: probe)
            : UIFont.monospacedSystemFont(ofSize: probe, weight: .bold)
        guard let font else { return 1 }
        let width = ("M" as NSString).size(withAttributes: [.font: font]).width
        return width > 0 ? width / probe : 1
    }()

    /// The display face at an exact point size, with `TextScale` deliberately
    /// **not** applied (0.8.6, D1).
    ///
    /// For legends cut into moulded parts, where the surface cannot grow with
    /// the setting. `DexMetrics.bandPillLabel`'s own note has said this since
    /// 0.8.5 — "a legend that grew with SETTINGS > TEXT SIZE would push itself
    /// off a cap whose height does not move" — while the call site went through
    /// `retro`, which scales; the label then absorbed the difference in
    /// `minimumScaleFactor`, and *that* is what made two lamps side by side
    /// render their words at two different sizes. This is the missing half of
    /// that argument, not a new exemption: everything reachable by a text-size
    /// setting still goes through `retro`.
    public static func retroFixed(_ pt: CGFloat) -> Font {
        retroAvailable
            ? .custom(names.retro, fixedSize: pt)
            : .system(size: pt, weight: .bold, design: .monospaced)
    }

    /// Pixel display face — titles, category labels, chips.
    ///
    /// `fixedSize:`, not `size:`, and that one token is half of AUDIT H11.
    /// `Font.custom(_:size:)` auto-scales with the system text size while
    /// `Font.system(size:...)` below does not, so the two branches of this
    /// function used to have *different* accessibility behaviour — a failed font
    /// registration silently froze the app's type. Both are fixed now, so the
    /// fallback changes the typeface and nothing else, and `TextScale` is the
    /// single axis. See VinodexCore/TypeScale.swift.
    public static func retro(_ size: CGFloat) -> Font {
        let pt = resolvedSize(size)
        return retroAvailable
            ? .custom(names.retro, fixedSize: pt)
            : .system(size: pt, weight: .bold, design: .monospaced)
    }

    /// CRT terminal face — body copy and readouts.
    public static func mono(_ size: CGFloat) -> Font {
        let pt = resolvedSize(size)
        return monoAvailable
            ? .custom(names.mono, fixedSize: pt)
            : .system(size: pt, design: .monospaced)
    }

    /// Whether a face actually resolved. Distinguishes "registered" from
    /// "silently falling back to a system font", which looks fine but is wrong.
    public static func isAvailable(_ name: String) -> Bool {
        UIFont(name: name, size: 12) != nil
    }

    /// Human-readable status for the debug catalog and syslog diagnostics.
    public static var statusReport: [String] {
        var lines = ["registered \(registration.registered.count)/2"]
        lines.append("PressStart2P: " + (isAvailable(names.retro) ? "OK" : "FALLBACK"))
        lines.append("VT323: " + (isAvailable(names.mono) ? "OK" : "FALLBACK"))
        lines.append(contentsOf: registration.failed.map { "FAILED " + $0 })
        return lines
    }
}

// `TextScale` moved to VinodexCore/TypeScale.swift in 0.6.4 (AUDIT H11), along
// with the size resolver it now goes through. `LcdMode`, `UIScale` and
// `ChassisSkin` followed it in 0.6.6 (arch **A6**), keeping their `Color`
// members here as extensions — see `ScreenModes.swift` and `ChassisSkins.swift`.
// All four are re-exported by the `import VinodexCore` every file here already
// carries.
//
// `DexResources` moved to `DexAsset.swift`, where the paths it resolves now
// live as an enum (arch **A22**).

#endif
