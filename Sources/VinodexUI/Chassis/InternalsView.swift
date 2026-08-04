#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The board's materials, named (AUDIT **L33**).
///
/// Twenty-odd bare hex literals used to sit inline in the drawing, several of
/// them the same colour written more than once — `#9CA3AF` is the steel of the
/// shield, the chip pins, the coin cell's rim and its stamped "+", and nothing
/// said so. These are deliberately *not* `Dex` tokens and deliberately not
/// mode-aware: this is a picture of a circuit board seen through smoke plastic,
/// not a surface the LCD theme has any business recolouring. Naming them is the
/// whole fix — a palette that can be read, rather than one that has to be
/// decoded.
///
/// File scope, so the nonisolated `Canvas` renderer can reach it — see the note
/// on `InternalsView`.
private enum Board {
    static let ground = Color(dexHex: "#14161A")
    /// Solder-mask green, the colour every consumer PCB is.
    static let substrate = Color(dexHex: "#166534")
    static let copper = Color(dexHex: "#B45309")
    static let via = Color(dexHex: "#FBBF24")

    /// Brushed steel: the EMI can, the chip pins, the coin cell.
    static let steel = Color(dexHex: "#9CA3AF")
    static let steelShade = Color(dexHex: "#6B7280")
    static let steelEdge = Color(dexHex: "#4B5563")
    static let steelWeld = Color(dexHex: "#D1D5DB")
    static let crystalCan = Color(dexHex: "#C0C5CC")

    /// Moulded-black IC packages, and the pin-one dimple pressed into them.
    static let package = Color(dexHex: "#0A0A0A")
    static let packageDimple = Color(dexHex: "#3F3F46")

    /// Resistors: tan body, then the three code stripes.
    static let resistorBody = Color(dexHex: "#C8A165")
    static let resistorStripes = ["#7C2D12", "#0A0A0A", "#B45309"]
    /// Enamelled copper, a shade darker than the bare traces.
    static let coilWinding = Color(dexHex: "#7C3F0A")

    static let ribbon = Color(dexHex: "#475569")
    static let ribbonConductor = Color(dexHex: "#CBD5E1")
    static let connector = Color(dexHex: "#E7E5E4")

    /// Electrolytic cans and the bright discs on top of them.
    static let canBody = Color(dexHex: "#27272A")
    static let canTop = Color(dexHex: "#D4D4D8")

    /// Speaker magnet, outer ring inwards.
    static let speakerRings = ["#3F3F46", "#71717A", "#27272A"]
}

/// The mock electronics behind a translucent shell — GLOUGLOU's whole point.
///
/// One static `Canvas`: no state, no timeline, nothing animated. Everything is
/// positioned in unit fractions of the size with component sizes scaled off the
/// width, so the board fills any device without the parts stretching. All of it
/// is deterministic — a clear shell whose innards rearranged themselves between
/// launches would read as a glitch, not as hardware.
///
/// The corner screws are the exception to the unit-fraction rule: they sit at
/// the same absolute inset and diameter as `DeviceBackPlate`'s screws (38pt
/// padding, 26pt across), because the front and back of one housing are held
/// by the same four fasteners and a mismatch reads as two different devices.
///
/// The drawing happens entirely inside the renderer closure with local
/// constants and nested functions — the closure is nonisolated, and reaching
/// back into view members from it is a cross-actor call under Swift 6 (see
/// `DataWave`'s note in `SettingsPanel`).
struct InternalsView: View {
    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }
            let w = size.width
            let h = size.height
            // Component scale: sized against a phone-width board so parts stay
            // believable on wider canvases rather than growing with the area.
            let u = w / 390

            func rect(_ x: Double, _ y: Double, _ rw: Double, _ rh: Double) -> CGRect {
                CGRect(x: x * w, y: y * h, width: rw * w, height: rh * h)
            }

            // Ground, then the two boards the rest is mounted on.
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Board.ground))
            let boardColor = Board.substrate
            context.fill(Path(roundedRect: rect(0.06, 0.05, 0.88, 0.39), cornerRadius: 8 * u), with: .color(boardColor))
            context.fill(Path(roundedRect: rect(0.06, 0.53, 0.88, 0.42), cornerRadius: 8 * u), with: .color(boardColor))

            // Copper traces: right-angle runs with a via dot at each end.
            let copper = Board.copper
            let via = Board.via
            func trace(_ points: [(Double, Double)]) {
                var path = Path()
                path.move(to: CGPoint(x: points[0].0 * w, y: points[0].1 * h))
                for p in points.dropFirst() {
                    path.addLine(to: CGPoint(x: p.0 * w, y: p.1 * h))
                }
                context.stroke(path, with: .color(copper), lineWidth: 1.5 * u)
                for end in [points.first!, points.last!] {
                    let r = 2.2 * u
                    context.fill(
                        Path(ellipseIn: CGRect(x: end.0 * w - r, y: end.1 * h - r, width: r * 2, height: r * 2)),
                        with: .color(via)
                    )
                }
            }
            // Upper board runs.
            trace([(0.10, 0.09), (0.30, 0.09), (0.30, 0.14)])
            trace([(0.10, 0.12), (0.24, 0.12), (0.24, 0.20)])
            trace([(0.86, 0.08), (0.66, 0.08), (0.66, 0.13)])
            trace([(0.90, 0.12), (0.76, 0.12), (0.76, 0.22)])
            trace([(0.12, 0.30), (0.12, 0.40), (0.30, 0.40)])
            trace([(0.88, 0.30), (0.88, 0.38), (0.72, 0.38)])
            trace([(0.40, 0.42), (0.60, 0.42)])
            trace([(0.18, 0.07), (0.18, 0.10), (0.14, 0.10)])
            trace([(0.50, 0.07), (0.50, 0.12)])
            trace([(0.60, 0.30), (0.60, 0.35), (0.52, 0.35)])
            // Lower board runs.
            trace([(0.10, 0.58), (0.26, 0.58), (0.26, 0.64)])
            trace([(0.90, 0.58), (0.74, 0.58), (0.74, 0.66)])
            trace([(0.10, 0.90), (0.10, 0.80), (0.22, 0.80)])
            trace([(0.90, 0.92), (0.90, 0.82), (0.78, 0.82)])
            trace([(0.34, 0.92), (0.34, 0.86), (0.50, 0.86)])
            trace([(0.66, 0.92), (0.66, 0.88), (0.56, 0.88)])
            trace([(0.42, 0.60), (0.58, 0.60)])
            trace([(0.14, 0.70), (0.14, 0.75), (0.20, 0.75)])
            trace([(0.86, 0.74), (0.86, 0.78), (0.80, 0.78)])

            // EMI shield can: the big brushed-steel box every phone board has.
            let shield = rect(0.36, 0.56, 0.28, 0.10)
            context.fill(
                Path(roundedRect: shield, cornerRadius: 3 * u),
                with: .linearGradient(
                    Gradient(colors: [Board.steel, Board.steelShade]),
                    startPoint: shield.origin,
                    endPoint: CGPoint(x: shield.minX, y: shield.maxY)
                )
            )
            context.stroke(Path(roundedRect: shield, cornerRadius: 3 * u), with: .color(Board.steelEdge), lineWidth: 1.5 * u)
            // Spot-weld dimples along the lid's edge.
            for i in 0..<6 {
                let dx = shield.minX + shield.width * (Double(i) + 0.5) / 6
                let dr = 1.6 * u
                context.fill(
                    Path(ellipseIn: CGRect(x: dx - dr, y: shield.minY + 3 * u, width: dr * 2, height: dr * 2)),
                    with: .color(Board.steelWeld)
                )
            }

            // ICs: black packages with pin stubs marching along the long edges.
            let package = Board.package
            let pin = Board.steel
            func chip(_ x: Double, _ y: Double, _ cw: Double, _ ch: Double) {
                let body = rect(x, y, cw, ch)
                let pinCount = 5
                let pinW = 2 * u
                let pinH = 4 * u
                for i in 0..<pinCount {
                    let px = body.minX + body.width * (Double(i) + 0.5) / Double(pinCount) - pinW / 2
                    context.fill(Path(CGRect(x: px, y: body.minY - pinH, width: pinW, height: pinH)), with: .color(pin))
                    context.fill(Path(CGRect(x: px, y: body.maxY, width: pinW, height: pinH)), with: .color(pin))
                }
                context.fill(Path(roundedRect: body, cornerRadius: 2 * u), with: .color(package))
                // Pin-one dimple, the detail that says "chip" at a glance.
                let dr = 2.5 * u
                context.fill(
                    Path(ellipseIn: CGRect(x: body.minX + 4 * u, y: body.minY + 4 * u, width: dr * 2, height: dr * 2)),
                    with: .color(Board.packageDimple)
                )
            }
            chip(0.34, 0.16, 0.32, 0.10)   // the big SoC, top centre
            chip(0.14, 0.22, 0.16, 0.06)
            chip(0.62, 0.68, 0.22, 0.08)
            chip(0.18, 0.68, 0.18, 0.07)

            // Crystal oscillator: the little silver pill beside the SoC.
            let crystal = rect(0.70, 0.18, 0.09, 0.025)
            context.fill(
                Path(roundedRect: crystal, cornerRadius: crystal.height / 2),
                with: .color(Board.crystalCan)
            )
            context.stroke(
                Path(roundedRect: crystal, cornerRadius: crystal.height / 2),
                with: .color(Board.steelShade), lineWidth: 1 * u
            )

            // Resistors: tan bodies with code stripes.
            func resistor(_ x: Double, _ y: Double) {
                let body = CGRect(x: x * w, y: y * h, width: 16 * u, height: 6 * u)
                context.fill(Path(roundedRect: body, cornerRadius: 3 * u), with: .color(Board.resistorBody))
                for (i, stripe) in Board.resistorStripes.enumerated() {
                    let sx = body.minX + Double(3 + i * 4) * u
                    context.fill(
                        Path(CGRect(x: sx, y: body.minY, width: 1.6 * u, height: body.height)),
                        with: .color(Color(dexHex: stripe))
                    )
                }
            }
            resistor(0.55, 0.28)
            resistor(0.60, 0.31)
            resistor(0.24, 0.60)
            resistor(0.52, 0.78)

            // Inductor coil: a copper ring with winding lines.
            let coilCenter = CGPoint(x: 0.72 * w, y: 0.33 * h)
            let coilR = 9 * u
            context.stroke(
                Path(ellipseIn: CGRect(x: coilCenter.x - coilR, y: coilCenter.y - coilR, width: coilR * 2, height: coilR * 2)),
                with: .color(copper), lineWidth: 3.5 * u
            )
            for i in 0..<4 {
                let angle = Double(i) * .pi / 4 + .pi / 8
                var winding = Path()
                winding.move(to: CGPoint(x: coilCenter.x + cos(angle) * coilR * 0.55, y: coilCenter.y + sin(angle) * coilR * 0.55))
                winding.addLine(to: CGPoint(x: coilCenter.x + cos(angle) * coilR * 1.45, y: coilCenter.y + sin(angle) * coilR * 1.45))
                context.stroke(winding, with: .color(Board.coilWinding), lineWidth: 1.2 * u)
            }

            // Ribbon cable across the board seam.
            let ribbon = rect(0.28, 0.455, 0.44, 0.065)
            context.fill(Path(roundedRect: ribbon, cornerRadius: 3 * u), with: .color(Board.ribbon))
            for i in 1..<8 {
                let ry = ribbon.minY + ribbon.height * Double(i) / 8
                var line = Path()
                line.move(to: CGPoint(x: ribbon.minX + 3 * u, y: ry))
                line.addLine(to: CGPoint(x: ribbon.maxX - 3 * u, y: ry))
                context.stroke(line, with: .color(Board.ribbonConductor.opacity(0.7)), lineWidth: 1 * u)
            }
            // Connector blocks at the ribbon's ends.
            for cx in [ribbon.minX - 6 * u, ribbon.maxX] {
                context.fill(
                    Path(roundedRect: CGRect(x: cx, y: ribbon.minY - 2 * u, width: 6 * u, height: ribbon.height + 4 * u), cornerRadius: 1.5 * u),
                    with: .color(Board.connector)
                )
            }

            // Electrolytic capacitors: dark cans with a bright top disc.
            func capacitor(_ x: Double, _ y: Double) {
                let r = 7 * u
                let center = CGPoint(x: x * w, y: y * h)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                    with: .color(Board.canBody)
                )
                let tr = r * 0.55
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - tr, y: center.y - tr, width: tr * 2, height: tr * 2)),
                    with: .color(Board.canTop)
                )
            }
            capacitor(0.20, 0.34)
            capacitor(0.27, 0.34)
            capacitor(0.80, 0.28)
            capacitor(0.44, 0.72)
            capacitor(0.51, 0.72)
            capacitor(0.83, 0.88)

            // Coin cell, lower board — every clear shell of the era showed one.
            let cell = CGPoint(x: 0.28 * w, y: 0.88 * h)
            let cellR = 16 * u
            context.fill(
                Path(ellipseIn: CGRect(x: cell.x - cellR, y: cell.y - cellR, width: cellR * 2, height: cellR * 2)),
                with: .color(Board.canTop)
            )
            context.stroke(
                Path(ellipseIn: CGRect(x: cell.x - cellR, y: cell.y - cellR, width: cellR * 2, height: cellR * 2)),
                with: .color(Board.steel),
                lineWidth: 2 * u
            )
            // The "+" stamped into the cell.
            var plus = Path()
            plus.move(to: CGPoint(x: cell.x - 5 * u, y: cell.y))
            plus.addLine(to: CGPoint(x: cell.x + 5 * u, y: cell.y))
            plus.move(to: CGPoint(x: cell.x, y: cell.y - 5 * u))
            plus.addLine(to: CGPoint(x: cell.x, y: cell.y + 5 * u))
            context.stroke(plus, with: .color(Board.steel), lineWidth: 1.6 * u)

            // Speaker magnet: concentric rings, bottom centre where the grill is.
            let speaker = CGPoint(x: 0.52 * w, y: 0.955 * h)
            for (ring, color) in zip([13.0, 9.0, 4.5], Board.speakerRings) {
                let r = ring * u
                context.fill(
                    Path(ellipseIn: CGRect(x: speaker.x - r, y: speaker.y - r, width: r * 2, height: r * 2)),
                    with: .color(Color(dexHex: color))
                )
            }

            // Corner screws — same inset (38pt padding, 26pt across) and 45°
            // slot as DeviceBackPlate.screw, because they are the same screws.
            func screw(_ center: CGPoint) {
                let r = 13.0
                let bounds = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                context.fill(
                    Path(ellipseIn: bounds),
                    with: .linearGradient(
                        Gradient(colors: [Dex.stone200, Dex.stone400, Dex.stone600]),
                        startPoint: bounds.origin,
                        endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)
                    )
                )
                context.stroke(Path(ellipseIn: bounds), with: .color(Dex.stone700), lineWidth: 1)
                var slot = Path()
                let arm = 9.0 * 0.707
                slot.move(to: CGPoint(x: center.x - arm, y: center.y - arm))
                slot.addLine(to: CGPoint(x: center.x + arm, y: center.y + arm))
                context.stroke(slot, with: .color(Dex.stone800.opacity(0.7)), lineWidth: 3)
            }
            let inset = 38.0 + 13.0
            screw(CGPoint(x: inset, y: inset))
            screw(CGPoint(x: w - inset, y: inset))
            screw(CGPoint(x: inset, y: h - inset))
            screw(CGPoint(x: w - inset, y: h - inset))
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
#endif
