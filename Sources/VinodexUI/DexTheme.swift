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
    public static var ventStripHeight: CGFloat { 1.75 * rem * UIScale.current.factor }
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
    public static var ventDot: CGFloat { 0.65 * rem * UIScale.current.factor }
    /// The bottom strip's lone status lamp (0.6.8, G3).
    ///
    /// Half again the diameter of the pair upstairs. They are not the same
    /// part: the two on the white bezel are a matched power/link pair reading
    /// as one unit at the top of the display, while this one is by itself at
    /// the far end of a 28pt strip next to a wordmark and a grille, and at
    /// `ventDot` it read as a speck of dirt rather than as a lamp.
    public static var bottomVentDot: CGFloat { 0.75 * rem * UIScale.current.factor }
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
    public static var footerControl: CGFloat { 4 * rem * UIScale.current.factor }
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
    /// someone waiting: see `MarqueeBanner.pixelFades`.
    public static let marqueePixelFade: Double = 1.4

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
    public static var bandControl: CGFloat { footerControl * 1.25 * 0.75 }
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
    public static let bandPillHeight: CGFloat = 24
    /// The glyph inside a pill (0.7.2, A9). A fraction of the pill so the two
    /// move together, and well under half of it so the lamp still reads as a
    /// lamp with a mark on it rather than as a bordered icon.
    public static var bandPillGlyph: CGFloat { bandPillHeight * 0.52 }
    public static let bandPillSpacing: CGFloat = 8
    /// Gap from the pills down to the panel they belong to. Small — they have
    /// to read as lamps *on* the marquee's housing, not as their own row.
    public static let bandPillGap: CGFloat = 5

    /// Icon wells (v0.5.8, F1): the list-row well and the detail-hero well,
    /// scaled with the chrome so LARGE grows the pictures, not the words.
    public static var iconWell: CGFloat { 48 * UIScale.current.factor }
    public static var heroWell: CGFloat { 148 * UIScale.current.factor }

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
            guard let url = DexResources.url(named: name, ext: "ttf", subdirectory: "Fonts") else {
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

// MARK: - Resources

/// Bundle lookup without an asset catalog.
///
/// SwiftPM places target resources in `Bundle.module`, not `Bundle.main` — a
/// distinction that matters because the skeleton's version looked in `.main`.
public enum DexResources {
    public static func url(named name: String, ext: String, subdirectory: String? = nil) -> URL? {
        if let subdirectory,
           let hit = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            return hit
        }
        return Bundle.module.url(forResource: name, withExtension: ext)
    }
}

// `TextScale` moved to VinodexCore/TypeScale.swift in 0.6.4 (AUDIT H11), along
// with the size resolver it now goes through. It is re-exported by the
// `import VinodexCore` every file here already carries.

/// Chrome scale (v0.5.8, F1) — a second axis, independent of `TextScale`.
///
/// Scales the *furniture*: footer controls, marquee band, vents, icon wells.
/// Text keeps its own setting, so a user can have big controls with small
/// type, or the reverse. SMALL is exactly the pre-0.5.8 layout.
///
/// Applied inside `DexMetrics`' computed members rather than at call sites,
/// for the same reason `TextScale` lives inside `DexFont`: the call site that
/// threads a factor through by hand is the one that forgets to.
public enum UIScale: String, CaseIterable, Identifiable, Sendable {
    case small = "SMALL"
    case large = "LARGE"

    public static let storageKey = "uiScale"

    public var id: String { rawValue }

    /// 1.15 is as far as the chassis stretches before the footer trio starts
    /// squeezing the marquee on a compact-width phone.
    public var factor: CGFloat {
        switch self {
        case .small: 1.0
        case .large: 1.15
        }
    }

    /// Mirrors `TextScale.current` — defaults-read, rebuild forced by
    /// `RootView` keying on the raw value.
    public static var current: UIScale {
        UIScale(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .small
    }
}

/// A heading in the screen-mode picker (0.7.0, B1).
///
/// Nine modes in one undifferentiated three-column grid was a wall of tiles
/// with no argument in it — the picker showed the range without saying what the
/// range *was*. These three headings are the three things a mode can be: the
/// app's own themes, a period display technology, and an homage to a specific
/// machine.
///
/// `allCases` order is picker order. Membership is *not* declared here — see
/// `LcdMode.section` for why the arrow points that way.
public enum LcdModeSection: String, CaseIterable, Identifiable, Sendable {
    /// The house themes: no conceit beyond light and dark.
    case classic = "CLASSIC"
    /// Period display hardware — phosphor and reflective LCD, monochrome by
    /// construction rather than by palette.
    ///
    /// **VINTAGE → RETRO (0.7.1, C1.)** The heading and the mode `LcdMode.vintage`
    /// both read "VINTAGE", so the picker printed a group called VINTAGE with a
    /// tile called VINTAGE inside it and two other tiles that were not — the
    /// heading looked like a mislabelled tile. RETRO names the same idea without
    /// colliding with any mode, and the case is renamed with it because *no
    /// section is persisted anywhere*: the mode rawValues are the storage, and
    /// they do not move.
    case retro = "RETRO"
    /// Modes that quote one specific machine's screen.
    case emulator = "EMULATOR"

    public var id: String { rawValue }

    /// The modes under this heading, in `LcdMode.allCases` order.
    ///
    /// Derived rather than declared, so every mode appears exactly once across
    /// the whole picker by construction: this is a partition of `allCases`, not
    /// three hand-kept lists that have to agree with it.
    public var modes: [LcdMode] { LcdMode.allCases.filter { $0.section == self } }
}

/// Whether the LCD renders dark-on-black or the original handheld's dark-on-
/// light-grey. Independent of `ChassisSkin`: the shell and the screen are
/// separate choices, and pairing a light screen with the red shell is a
/// perfectly good combination.
public enum LcdMode: String, CaseIterable, Identifiable, Sendable {
    case dark = "DARK"
    case light = "LIGHT"
    /// Monochrome — black pixels on a grey-green ground, like a vintage Palm
    /// or e-ink screen. Colour is deliberately lost: the chassis applies a
    /// grayscale-and-tint pass over the whole LCD (see `DeviceChassis`), so
    /// the tokens below only have to be high-contrast, not tastefully hued.
    case vintage = "VINTAGE"
    /// Monochrome the other way up — amber phosphor on black, like a CRT
    /// terminal. Same grayscale-and-tint pass as vintage, over the dark
    /// theme's tokens instead of the light ones.
    case amber = "AMBER"
    /// Early-desktop GUI: a grey-blue desktop with navy ink and titlebar
    /// blues. A *light* mode — the pale branch everywhere light takes it.
    case wineOS = "WINE OS"
    /// Green phosphor on black — the amber treatment with the other classic
    /// tube. Same grayscale-and-tint pass, over the dark tokens.
    case terminal = "TERMINAL"
    /// VINOFD: deep blue CRT ground with a light-blue vacuum-fluorescent
    /// glow for the text. Shipped in 0.5.1 as "Blue Screen" (white text) —
    /// the rawValue keeps that name because it is persisted; the label and
    /// the glow are what changed.
    case blueScreen = "BLUE SCREEN"
    /// A vintage starship console: black glass, amber readouts, and purple
    /// for the accents — the two colours those panels actually ran.
    case starTrek = "STAR TREK"
    /// DMG dot-matrix: dark ink on pea green, four tones total. Runs the
    /// vintage/amber grayscale-and-tint pass with the DMG's own green, so
    /// only the tokens' *luminance* matters — that is what collapses the
    /// whole LCD to the handheld's palette. The rawValue is ASCII on
    /// purpose (it persists); the umlaut lives in `displayName`.
    case gruenerBoy = "GRUNER BOY"

    /// Read from `DeviceAxis` since 0.7.3 (B1) — see `ChassisSkin.storageKey`
    /// for why. The literal is unchanged: `"lcdMode"`.
    public static var storageKey: String { DeviceAxis.screen.storageKey }

    public var id: String { rawValue }

    /// What the picker calls this mode. Separate from `rawValue` for the
    /// same reason `ChassisSkin.displayName` is: the raw value is persisted,
    /// so a rename must move the label and only the label. BLUE SCREEN
    /// shipped in 0.5.1 and re-brands as VINOFD without resetting anyone's
    /// stored choice.
    public var displayName: String {
        switch self {
        case .blueScreen: "VINOFD"
        case .gruenerBoy: "GRÜNERBOY"
        // Capitalized like the rest of the roster since 0.5.8 (E1); the dot
        // keeps the file-name conceit.
        case .wineOS: "WINE.OS"
        case .starTrek: "L-WINES"
        default: rawValue
        }
    }

    /// Which heading this mode sits under in the picker (0.7.0, B1).
    ///
    /// An exhaustive switch rather than a table on `LcdModeSection`, and that is
    /// the whole safety argument: a section list written as
    /// `[.dark, .light, .wineOS]` somewhere can silently *omit* a mode, and the
    /// omitted one simply stops appearing in the picker with nothing failing.
    /// Written this way round the compiler will not build a mode that has no
    /// home, and `LcdModeSection.modes` derives from `allCases`, so a mode
    /// cannot be listed twice either.
    ///
    /// **Two modes swapped groups in 0.7.1 (C2, C3).** WINE.OS was filed under
    /// CLASSIC because it is a *light* mode and the light modes lived together;
    /// but it is an homage to one specific desktop, which is the whole
    /// definition of EMULATOR, and it left CLASSIC as what that heading always
    /// meant — light and dark, and nothing else. GRÜNERBOY went the other way:
    /// it is a reflective dot-matrix LCD running the same grayscale-and-tint
    /// pass as VINTAGE, AMBER and TERMINAL, so it belongs with the period
    /// display *hardware* rather than with the machines that merely quote a
    /// colour scheme. Membership is derived from this switch, so both moves are
    /// one line each and the picker follows.
    public var section: LcdModeSection {
        switch self {
        case .dark, .light: .classic
        case .amber, .vintage, .terminal, .gruenerBoy: .retro
        case .starTrek, .blueScreen, .wineOS: .emulator
        }
    }

    /// Whether the screen ground is pale. An explicit list, not `!= .dark`:
    /// vintage is dark ink on a pale ground and wants every light branch, but
    /// amber is a *dark* mode — pale scrims and dark-on-accent ink on it would
    /// be wrong in both directions. WINE OS joins the pale side; the other
    /// themed modes are dark glass.
    public var isLight: Bool {
        self == .light || self == .vintage || self == .wineOS
            || self == .gruenerBoy
    }

    /// The tint the chassis multiplies the grayscaled LCD by — nil renders in
    /// colour. This is what turns "black on white" into "black on grey-green"
    /// (vintage) and "white on black" into "amber on black" (amber) or
    /// terminal green (terminal).
    public var monochromeTint: Color? {
        switch self {
        case .dark, .light, .wineOS, .blueScreen, .starTrek: nil
        case .vintage: Color(dexHex: "#C6CFB2")
        case .amber: Color(dexHex: "#FFB300")
        case .terminal: Color(dexHex: "#4DFF4D")
        // The DMG's lightest tone; everything darker falls out of the
        // grayscale multiply.
        case .gruenerBoy: Color(dexHex: "#9BBC0F")
        }
    }

    /// Glyph for the screen-mode picker's preview cards.
    public var symbol: String {
        switch self {
        case .dark: "moon.fill"
        case .light: "sun.max.fill"
        case .vintage: "hourglass"
        case .amber: "lightbulb.fill"
        case .wineOS: "macwindow"
        case .terminal: "terminal.fill"
        case .blueScreen: "pc"
        case .starTrek: "atom"
        case .gruenerBoy: "gamecontroller.fill"
        }
    }

    /// LCD ground.
    public var screen: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.screen
        case .light: Color(dexHex: "#E8E8E2")
        case .vintage: Color(dexHex: "#E4E4DC")
        case .wineOS: Color(dexHex: "#C7D3E6")
        case .blueScreen: Color(dexHex: "#1021B4")
        case .starTrek: Color(dexHex: "#0B0910")
        case .gruenerBoy: Color(dexHex: "#E6EBCF")
        }
    }

    // MARK: The font axis (0.7.3, B1)

    /// Whether a chosen font colour survives this mode.
    ///
    /// **It cannot on the four monochrome modes.** VINTAGE, AMBER, TERMINAL and
    /// GRÜNERBOY are not colour schemes — they are a `grayscale(1)` and a
    /// `colorMultiply(tint)` over the whole LCD (see `DeviceChassis.innerBezel`),
    /// which is exactly what collapses their tokens to one phosphor. A chosen ink
    /// pushed through that pass arrives as a *lightness* change of the mode's own
    /// tint: pick COBALT on AMBER and you get slightly darker amber. Rather than
    /// ship a control that silently does almost nothing, the axis declares itself
    /// inapplicable and the workshop's FONT row says so on its face.
    ///
    /// Derived from `monochromeTint` rather than listed, so a tenth mode arriving
    /// with a tint is covered by having a tint, not by being remembered here.
    public var honorsFontInk: Bool { monochromeTint == nil }

    /// Whether this mode will actually draw in a chosen ink.
    ///
    /// Two reasons it will not, and they are different in kind: the mode may
    /// collapse every hue to one phosphor (`honorsFontInk`), or the ink may be
    /// the wrong side of this mode's ground to read as text at all
    /// (`PartColor.readsAsInk(onLightGround:)`). Both answer here, because a
    /// caller only ever wants the one question — *will this show up* — and the
    /// second reason has a property the first does not: it can become true after
    /// the fact, when somebody picks an ink on a dark screen and then changes to
    /// a pale one. A filter in the picker could not have caught that; refusing at
    /// the point of use can, and does.
    public func accepts(_ ink: PartColor) -> Bool {
        honorsFontInk && ink.readsAsInk(onLightGround: isLight)
    }

    /// The player's chosen text ink, or nil to use this mode's own.
    ///
    /// Read straight from defaults rather than through `@AppStorage`, because
    /// this is consulted from a computed property on an enum that thirty screens
    /// hold as a value — there is nowhere to put a property wrapper. That has one
    /// consequence worth stating: a change here does not invalidate any SwiftUI
    /// view on its own, which is why `RootView` keys the whole chassis on this
    /// axis. See the note there.
    ///
    /// A defaults lookup per token read is the established cost in this file —
    /// `DexFont.retro` reads `TextScale.current` the same way on every call, and
    /// AUDIT M8 resolved that in the one hot spot rather than in general. The
    /// fast path here is a single `string(forKey:)` returning nil, which is what
    /// every device that has not opened the workshop takes.
    private var fontInk: Color? {
        guard
            let raw = UserDefaults.standard.string(forKey: DeviceAxis.font.storageKey),
            let part = PartColor(rawValue: raw),
            accepts(part)
        else { return nil }
        return part.color
    }

    /// Primary text on that ground. VINOFD's is deliberately *not* white:
    /// the light-blue glow is what says vacuum-fluorescent rather than BSOD.
    ///
    /// **Three tokens, one choice** (0.7.3, B1). A mode declares a primary ink, a
    /// body ink and a muted one; a chosen font colour replaces all three, as the
    /// same colour at three weights. Overriding only `text` would leave every
    /// INFO block and every caption in the previous mode's colour, which reads as
    /// a half-applied theme rather than as a font choice — and letting the player
    /// choose three inks separately is three axes, not the one the spec asks for.
    public var text: Color {
        fontInk ?? modeText
    }

    /// This mode's own ink, with any chosen font colour ignored (0.7.3, B1).
    ///
    /// The workshop's FOLLOW swatch has to show what *unsetting* the font axis
    /// would give, and `text` cannot answer that because `text` is the axis —
    /// asking it while a colour is chosen returns the chosen colour, so the
    /// "leave this to the screen" chip would preview the thing it undoes.
    public var ownInk: Color { modeText }

    private var modeText: Color {
        switch self {
        case .dark, .amber, .terminal: .white
        case .light: Color(dexHex: "#1F1F1C")
        case .vintage: Color(dexHex: "#101010")
        case .wineOS: Color(dexHex: "#0E2258")
        case .blueScreen: Color(dexHex: "#A6DBFF")
        case .starTrek: Color(dexHex: "#FFA94D")
        case .gruenerBoy: Color(dexHex: "#141A0C")
        }
    }

    /// Section rules, headers and glyph tints. The dark theme's #4ADE80 is
    /// invisible on white, so light mode drops to a deep bottle green that
    /// still reads as "the green" without disappearing. Vintage has no colour
    /// to keep — its accent is simply ink. The themed modes each pick the one
    /// colour their reference hardware used for emphasis.
    public var accent: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.green
        case .light: Color(dexHex: "#1B6B3A")
        case .vintage: Color(dexHex: "#1A1A16")
        case .wineOS: Color(dexHex: "#1D3E9E")
        // VFD electric cyan — one register brighter than the text glow.
        case .blueScreen: Color(dexHex: "#7DF9FF")
        case .starTrek: Color(dexHex: "#C983E8")
        case .gruenerBoy: Color(dexHex: "#2F3A1C")
        // Red pen — what anyone marking up a page reaches for.
        }
    }

    /// Body copy inside INFO blocks — mint on black, near-black on paper.
    ///
    /// 0.86 of the chosen ink when the font axis is set: body copy sits one
    /// register below a heading in every mode's own table (`#bbf7d0` under white
    /// on DARK), and an opacity step is the only way to reproduce that from a
    /// single colour without a second authored value per palette entry.
    public var bodyText: Color {
        if let fontInk { return fontInk.opacity(0.86) }
        return modeBodyText
    }

    private var modeBodyText: Color {
        switch self {
        case .dark, .amber, .terminal: Color(dexHex: "#bbf7d0")
        case .light: Color(dexHex: "#23342A")
        case .vintage: Color(dexHex: "#20201C")
        case .wineOS: Color(dexHex: "#22335E")
        case .blueScreen: Color(dexHex: "#BFE4FF")
        case .starTrek: Color(dexHex: "#F2CD9A")
        case .gruenerBoy: Color(dexHex: "#202817")
        }
    }

    /// Hero panel wash behind an entry title.
    public var heroWash: Color {
        switch self {
        case .dark, .amber, .terminal: Color(dexHex: "#14532d").opacity(0.1)
        case .light: Color(dexHex: "#1B6B3A").opacity(0.07)
        case .vintage: Color.black.opacity(0.06)
        case .wineOS: Color(dexHex: "#1D3E9E").opacity(0.07)
        case .blueScreen: Color.white.opacity(0.06)
        case .starTrek: Color(dexHex: "#C983E8").opacity(0.08)
        case .gruenerBoy: Color.black.opacity(0.06)
        }
    }

    /// Grid lines drawn over the hero wash. Dark mode's deep #14532d reads heavy
    /// on the light hero, so light mode lifts it toward the paper.
    public var heroGrid: Color {
        switch self {
        case .dark, .amber, .terminal: Color(dexHex: "#14532d")
        case .light: Color(dexHex: "#1B6B3A")
        case .vintage: Color(dexHex: "#3A3A34")
        case .wineOS: Color(dexHex: "#1D3E9E")
        case .blueScreen: Color(dexHex: "#4A5FE0")
        case .starTrek: Color(dexHex: "#7A4E9E")
        case .gruenerBoy: Color(dexHex: "#3A4224")
        }
    }

    /// Filled-button ground (SAVE and friends) when *not* active.
    public var buttonWell: Color {
        switch self {
        case .dark, .amber, .terminal, .starTrek: .black.opacity(0.35)
        case .light, .vintage, .wineOS, .gruenerBoy: .white
        case .blueScreen: Color(dexHex: "#0A1690")
        }
    }

    /// Ground behind entry screens, which paint their own black rather than
    /// using `DexScreenBackground`.
    public var page: Color {
        switch self {
        case .dark, .amber, .terminal: .black
        case .light: Color(dexHex: "#F2F2EC")
        case .vintage: Color(dexHex: "#EDEDE4")
        case .wineOS: Color(dexHex: "#D6DFEE")
        case .blueScreen: Color(dexHex: "#0E1CA8")
        case .starTrek: .black
        case .gruenerBoy: Color(dexHex: "#DDE3C2")
        }
    }

    /// Row and card fill.
    public var surface: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone900
        case .light: Color(dexHex: "#FFFFFF")
        case .vintage: Color(dexHex: "#F6F6EF")
        case .wineOS: Color(dexHex: "#E9EEF6")
        case .blueScreen: Color(dexHex: "#1F31CE")
        case .starTrek: Color(dexHex: "#191022")
        case .gruenerBoy: Color(dexHex: "#EFF2DE")
        }
    }

    public var surfaceEdge: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone700
        case .light: Color(dexHex: "#C9C9C1")
        case .vintage: Color(dexHex: "#84847A")
        case .wineOS: Color(dexHex: "#8598B8")
        case .blueScreen: Color(dexHex: "#5D74E8")
        case .starTrek: Color(dexHex: "#5C3E78")
        case .gruenerBoy: Color(dexHex: "#7A8258")
        }
    }

    /// Secondary text — captions, counts, placeholders.
    public var subtext: Color {
        if let fontInk { return fontInk.opacity(0.62) }
        return modeSubtext
    }

    private var modeSubtext: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone400
        case .light: Color(dexHex: "#5A5A54")
        case .vintage: Color(dexHex: "#42423C")
        case .wineOS: Color(dexHex: "#465578")
        case .blueScreen: Color(dexHex: "#8FB0F0")
        case .starTrek: Color(dexHex: "#C2915C")
        case .gruenerBoy: Color(dexHex: "#455030")
        }
    }

    /// Fill behind search fields, which are black wells on the dark theme.
    public var well: Color {
        switch self {
        case .dark, .amber, .terminal, .starTrek: .black
        case .light, .vintage, .wineOS: Color(dexHex: "#FFFFFF")
        case .blueScreen: Color(dexHex: "#0A1690")
        case .gruenerBoy: Color(dexHex: "#F4F6E8")
        }
    }

    /// Text on a row that exists but cannot be opened — a cross-link pointing
    /// outside the current selection, or a country with no region written yet.
    ///
    /// Has to read as *inactive* without disappearing, which is why light mode
    /// does not simply share the dark theme's stone600: against `surface` that
    /// grey is close enough to `text` to look like an ordinary enabled row.
    public var disabledText: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone600
        case .light: Color(dexHex: "#A3A39B")
        case .vintage: Color(dexHex: "#96968C")
        case .wineOS: Color(dexHex: "#9FACC6")
        case .blueScreen: Color(dexHex: "#6272D4")
        case .starTrek: Color(dexHex: "#6D5A49")
        case .gruenerBoy: Color(dexHex: "#939B78")
        }
    }

    /// Foreground for content sitting on an `accent` fill (selected settings
    /// options, active chips). Dark mode's accent is mint (#4ADE80) — white text
    /// on it is ~1.8:1 — so it takes black; light mode's accent is deep green and
    /// takes white, as does vintage's ink-black. Blue Screen's accent is a pale
    /// cyan, so it takes the deep well blue rather than plain black.
    public var onAccent: Color {
        switch self {
        case .dark, .amber, .terminal, .starTrek: .black
        case .light, .vintage, .wineOS, .gruenerBoy: .white
        case .blueScreen: Color(dexHex: "#0A1690")
        }
    }

    /// The LCD's raw ground, behind every screen. The three stone-dark modes
    /// keep the near-black CRT well; every themed mode grounds in its own
    /// colour instead. `DexScreenBackground` reads this rather than branching
    /// on `isLight`, which painted BLUE SCREEN's blue over with stone.
    public var ground: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone950
        default: screen
        }
    }

    /// The faint atmosphere grid drawn over `ground`.
    public var gridLine: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.stone700
        case .light, .vintage: Dex.stone400
        case .wineOS: Color(dexHex: "#8598B8")
        case .blueScreen: Color(dexHex: "#4A5FE0")
        case .starTrek: Color(dexHex: "#3A2C1E")
        case .gruenerBoy: Color(dexHex: "#7A8258")
        }
    }

    /// Ground for full-screen panels (settings and friends), which used to
    /// paint `Dex.screen` on dark and `page` on light. One token so the
    /// themed modes get their own colour in both directions.
    public var panelGround: Color {
        switch self {
        case .dark, .amber, .terminal: Dex.screen
        default: page
        }
    }

    // MARK: Chrome
    //
    // On-LCD chrome only (narrowed in v0.5.4): the master-search button and
    // the settings tiles follow the screen mode, because they are pixels on
    // the screen. The physical chassis controls — Back, Home, Saved, the cog
    // — belong to the skin again; 0.5.3 briefly tied them to the mode, and
    // every colourway read as the same device the moment the LCD changed.
    // These ramps sit outside the LCD's grayscale-and-tint pass, so the
    // monochrome modes spell their colours out literally.

    /// The on-LCD powered chrome's six-stop ramp — the search button, the
    /// settings tiles. Same vocabulary as `ChassisAccent` for the same
    /// reason: the stops are only ever used together.
    public var controlAccent: ChassisAccent {
        switch self {
        // The house amber, exactly what the classic chassis always wore.
        case .dark:
            ChassisAccent(pale: "#fef3c7", light: "#fde68a", bright: "#fbbf24",
                          mid: "#f59e0b", edge: "#b45309", ink: "#78350f")
        case .light:
            ChassisAccent(pale: "#E8F5EC", light: "#BFE3CB", bright: "#4FA76F",
                          mid: "#1B6B3A", edge: "#0F4224", ink: "#0B2E18")
        case .vintage:
            ChassisAccent(pale: "#F2F2EA", light: "#D8D8CC", bright: "#8A8A7C",
                          mid: "#4A4A40", edge: "#26261F", ink: "#111110")
        case .amber:
            ChassisAccent(pale: "#FFF4D6", light: "#FFE29A", bright: "#FFB300",
                          mid: "#D18F00", edge: "#7A5200", ink: "#3A2600")
        case .wineOS:
            ChassisAccent(pale: "#EAF0FA", light: "#C2D2EC", bright: "#5B7FD4",
                          mid: "#1D3E9E", edge: "#0E2258", ink: "#0A1A40")
        case .terminal:
            ChassisAccent(pale: "#E8FFE8", light: "#A8FFA8", bright: "#4DFF4D",
                          mid: "#1FBF3F", edge: "#0A5A1E", ink: "#06300F")
        case .blueScreen:
            ChassisAccent(pale: "#E4F7FF", light: "#A6DBFF", bright: "#7DF9FF",
                          mid: "#2FA8D8", edge: "#0A4A70", ink: "#062A40")
        case .starTrek:
            ChassisAccent(pale: "#FFE9C7", light: "#FFC98A", bright: "#FFA94D",
                          mid: "#E08A20", edge: "#7A4A08", ink: "#341F04")
        case .gruenerBoy:
            ChassisAccent(pale: "#E6EBCF", light: "#C2CE9A", bright: "#8BAC0F",
                          mid: "#566A18", edge: "#24300C", ink: "#0F1A0A")
        }
    }

    /// The globe screen's sphere tint per *screen mode* (0.6.4, F1 — the redo).
    ///
    /// 0.6.2's F1 keyed the tint on `ChassisSkin`, but the modes the user
    /// switches between on the LCD are `LcdMode`s — so flipping L-WINES or
    /// VINOFD on left the globe unchanged, which is why the feature read as
    /// not having gone through. The mode now owns the colour; DARK alone
    /// returns nil and defers to the skin's tint, keeping the per-skin
    /// behaviour as the default mode's flavour rather than losing it.
    ///
    /// Pale on purpose, like the skin table: the tint multiplies over the map
    /// texture, and a saturated dark would swallow the coastlines. The
    /// monochrome modes still pass through the chassis grayscale-and-tint, so
    /// their values only need the right luminance.
    public var globeTint: Color? {
        switch self {
        case .dark: nil
        // LIGHT inverts the texture instead (see `invertsGlobeTexture`); the
        // tint stays neutral so the inversion reads clean.
        case .light: Color.white
        case .vintage: Color(dexHex: "#C6CFB2")
        case .amber: Color(dexHex: "#FFD27A")
        case .wineOS: Color(dexHex: "#C2D2EC")
        case .terminal: Color(dexHex: "#A8FFA8")
        // VINOFD: the vacuum-fluorescent light blue.
        case .blueScreen: Color(dexHex: "#A6DBFF")
        // L-WINES: the console's accent purple.
        case .starTrek: Color(dexHex: "#C983E8")
        case .gruenerBoy: Color(dexHex: "#C2CE9A")
        }
    }

    /// LIGHT mode's globe is the *inverted-colour* globe (0.6.4, F1): the map
    /// texture runs through a colour inversion before it reaches the sphere,
    /// so dark oceans become paper and the globe reads as printed rather than
    /// glowing. Only LIGHT — the other pale modes keep the normal texture
    /// under their own tints.
    public var invertsGlobeTexture: Bool { self == .light }

    // `isSketchPaper` retired with the NOTEBOOK mode itself (0.7.0, C1).
    //
    // 0.6.9's M1 shipped the hand-drawn look as two independent halves — a
    // shell (`ChassisSkin.sketch`, still here, still PÉT-NAT's) and a screen
    // (this flag, plus `SketchRender.RuledPaper`). C1 removes the screen
    // mode and B2 keeps the shell, which is the two halves being independent
    // working exactly as designed: PÉT-NAT is now a drawn shell around an
    // ordinary gridded LCD, the same way it was always allowed to be a drawn
    // shell around AMBER.
    //
    // `RuledPaper` is deliberately left in `SketchRender.swift` rather than
    // deleted with its only call site: it is a finished drawing with no
    // owner, and the decision it is waiting on (whether the paper should
    // follow the *skin* instead of a mode) is the user's, not this batch's.
    // Re-mounting it is one `if` in `DexScreenBackground`.

    public static var current: LcdMode {
        LcdMode(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .dark
    }

    // `next` retired in 0.7.6 (A1), with `ChassisSkin.next` and
    // `ChassisLook.next` beside it. All three existed for one caller: the
    // marquee drawer's NEXT SCREEN and NEXT SKIN tiles (0.7.1, B5), which cycled
    // the two axes without leaving the screen you were on. The Decision retires
    // the drawer, and a cycle-to-the-next helper that nothing cycles is exactly
    // the code-nothing-reaches `MarqueeBanner`'s own D1 note argues against
    // keeping. Both pickers still choose either axis directly.

    // MARK: Themed chrome (0.7.1, C5)

    /// Whether this mode repaints the LCD's coloured controls in its own
    /// palette.
    ///
    /// True for the EMULATOR group only, and the group is the argument. CLASSIC
    /// is the app being itself — DARK and LIGHT are supposed to show the house
    /// colours, and a green BLIND TASTING tile beside a purple WINE EXAM tile is
    /// the design, not a leak. RETRO already has a stronger mechanism: those
    /// four modes run the chassis's grayscale-and-tint pass over the entire LCD
    /// (`DeviceChassis`), so their tiles are *already* one palette and tinting
    /// the source colours first would only change which greys came out.
    ///
    /// That leaves EMULATOR, where every mode quotes a specific machine in full
    /// colour and nothing was making the chrome agree with it. L-WINES is a
    /// black-glass console with amber readouts that had six saturated Tailwind
    /// tiles bolted to it.
    public var themesChrome: Bool { section == .emulator }

    /// A coloured control's face and shadow under this screen mode (0.7.1, C5).
    ///
    /// Call sites keep passing the hand-picked hex pair they always passed;
    /// under an Emulator mode this folds it toward that mode's own ramp and
    /// hands back the result. **The blend, not a replacement**, and that is the
    /// legibility half of C5: replacing the literals would make all six tools
    /// tiles the same colour and destroy the only thing telling them apart at a
    /// glance, so the original hue survives at 40% and the mode's `bright`
    /// supplies the other 60%. Six distinguishable tiles that are recognisably
    /// one machine's palette, rather than six identical ones or six that ignore
    /// the machine.
    ///
    /// Contrast is not left to the blend. The ink a caller draws on top is
    /// `chromeInk(over:)`, which picks black or white by the *blended* face's
    /// luminance rather than by the literal that went in — the two can land on
    /// opposite sides of the line, which is exactly how a themed control ends up
    /// with unreadable text.
    ///
    /// Non-Emulator modes get `Color(dexHex:)` on the untouched strings, so this
    /// is a no-op everywhere it should be one.
    public func chrome(face: String, shadow: String) -> (face: Color, shadow: Color) {
        guard themesChrome else {
            return (Color(dexHex: face), Color(dexHex: shadow))
        }
        let ramp = controlAccent
        return (
            DexRGB(hex: face).mixed(with: ramp.brightRGB, amount: 0.6).color,
            DexRGB(hex: shadow).mixed(with: ramp.edgeRGB, amount: 0.6).color
        )
    }

    /// The ink to draw over a face this mode produced.
    ///
    /// Callers pass the *literal* they would have used, and the face string they
    /// gave `chrome(face:shadow:)`; on a non-Emulator mode the preference is
    /// honoured untouched, because the existing tiles were hand-checked (the
    /// tools shelf's note on why the yellow and cyan faces deepened a step to
    /// keep white on them is exactly that work, and it should not be redone by a
    /// formula). On an Emulator mode the face has moved, so the preference is
    /// re-derived from where it moved to.
    public func chromeInk(over face: String, preferring preferred: Color) -> Color {
        guard themesChrome else { return preferred }
        let blended = DexRGB(hex: face).mixed(with: controlAccent.brightRGB, amount: 0.6)
        // 0.55 rather than 0.5: white-on-mid reads worse than black-on-mid at
        // the 13pt retro face these labels use, so the tie goes to dark ink.
        return blended.luminance > 0.55 ? controlAccent.ink : .white
    }
}

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

    public init(top: String, bottom: String, edge: String, glyph: String) {
        self.top = Color(dexHex: top)
        self.bottom = Color(dexHex: bottom)
        self.edge = Color(dexHex: edge)
        self.glyph = Color(dexHex: glyph)
        self.topHex = top
        self.glyphHex = glyph
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
    /// `WornOverlay.seed(skin.rawValue)` draws the back plate's procedural wear
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
    public var section: ChassisSkinSection {
        switch self {
        case .classic, .midnight, .original: .classic
        case .burgundy, .nocturne, .champagne: .wines
        case .oaked, .steel, .petNat: .vessel
        case .vinhoVerde, .psvino, .grisDeGris, .riesling, .smartGrape, .orangeWine, .w64: .retrofit
        case .glouglou, .nouveau, .waldglas: .clearTech
        case .christmas, .blush, .halloween: .festive
        }
    }

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

    /// What the picker calls this skin.
    ///
    /// Deliberately separate from `rawValue`: the raw value is the persisted
    /// `@AppStorage` key, so renaming ORIGINAL to "Blanc de Blancs" by editing
    /// the case would silently reset every device already storing "ORIGINAL"
    /// back to the default shell. The stored vocabulary stays put and only the
    /// label moves.
    public var displayName: String {
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
        case .grisDeGris: "GRIS DE GRIS"
        case .orangeWine: "ORANGE WINE"
        // PÉT-NAT → FIBERGLASS (0.7.5, A4). Label only, per the note above,
        // and the note is load-bearing on this case in particular: the rawValue
        // `"PET NAT"` is the `chassisSkin` `@AppStorage` value on every install
        // wearing this shell, the FNV-1a seed `WornOverlay.seed(skin.rawValue)`
        // draws the back plate's procedural wear from, and the stem
        // `stickerStem` derives (`sticker-pet-nat`). Moving it would reset the
        // shell, repaint the wear on the devices that survived, and orphan the
        // sticker — the exact three costs HALLOWINE's rename was written up to
        // avoid. Checked rather than assumed: `"PET NAT"` appears nowhere in
        // `shared/`, the generated JSON or the art scripts. (The `petnat`
        // hits in `icons.json` and `art/icons/styles/` are the *wine style*
        // Pétillant Naturel and have nothing to do with this skin.)
        case .petNat: "FIBERGLASS"
        case .waldglas: "WALDGLAS"
        // HALLOWEEN → HALLOWINE (0.7.1, C4). Label only — the rawValue is the
        // `@AppStorage` key *and* the seed for the back plate's procedural wear
        // (see `WornOverlay.seed`), so moving it would both reset every device
        // wearing this shell and repaint the ones that survived.
        case .halloween: "HALLOWINE"
        // The one skin whose label and stored word are the same string on
        // purpose (0.7.6, D1). This switch is exhaustive rather than defaulted,
        // so the entry is required either way — but it is worth saying that the
        // agreement is deliberate: every rename note in this file is about the
        // cost of a label that has drifted from its rawValue, and picking a name
        // that never needs to drift is the cheapest version of that.
        case .w64: "W64"
        }
    }

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
    public var symbol: String {
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
        // The console emblem is gone (0.6.7, K1) - see `drawnMark`. This is
        // only the fallback for anything that still wants a plain symbol.
        case .psvino: "seal.fill"
        // The brick's own control: a d-pad.
        case .grisDeGris: "dpad.fill"
        case .orangeWine: "exclamationmark.triangle.fill"
        // The pen that drew the shell.
        case .petNat: "pencil.and.outline"
        // Forest glass, named for the woods it was blown in.
        case .waldglas: "leaf.circle.fill"
        // The neutral fallback only. This skin's emblem is a drawing —
        // SF Symbols has no pumpkin at the iOS 17 floor. See `drawnMark`.
        case .halloween: "moon.haze.fill"
        // Four coloured points around a centre: what this livery *is*, taken
        // from the house's own symbol set rather than quoted from anyone's
        // hardware. SF Symbols 2 / iOS 14, well under the floor, and it
        // collides with nothing — `circle.grid.2x2.fill` is a workshop axis
        // glyph and `circle.grid.3x3.fill` is GRAPES.
        case .w64: "circle.grid.cross.fill"
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

    // `next` retired in 0.7.6 (A1) — see the note where `LcdMode.next` was.
}

#endif
