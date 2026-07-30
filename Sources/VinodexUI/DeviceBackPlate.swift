#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The brushed-metal underside of the device, ported from
/// `components/DeviceBackPanel.tsx`.
///
/// Engraved nameplate, corner screws and a serial, on a diagonal metal
/// gradient. The whole plate is tappable to flip back, matching the web app.
///
/// Under a translucent skin the metal is swapped for the same smoke plastic as
/// the front, with the internals showing through — a clear device with a
/// solid steel back would be two different products. The screws and engraving
/// stay: fasteners are real parts, and the maker's mark is etched into the
/// plastic instead of the metal.
public struct DeviceBackPlate: View {
    private static let creator = "HORIZON/GODOT"

    private var year: Int { Calendar.current.component(.year, from: Date()) }

    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue
    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }

    public init() {}

    public var body: some View {
        // Dismissal is a swipe, owned by `DeviceChassis` — the plate is a
        // surface, not a button.
        ZStack {
            if skin.isTranslucent {
                InternalsView()
                // A touch lighter than the front shell: the back of a clear
                // device is one moulding further from the boards.
                Color(dexHex: "rgba(204,216,224,0.34)")
                highlight
            } else {
                metal
                striations
                highlight
            }
            screws
            engraving

            // Factory leavings (v0.5.3): a faded barcode sticker and half a
            // price tag someone tried to peel. Decoration in the plate's own
            // fiction — a device that has been on a shelf, not in a renderer.
            BarcodeSticker()
                .rotationEffect(.degrees(-4))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 30)
                .padding(.bottom, 96)
                .allowsHitTesting(false)
            RippedPriceTag()
                .rotationEffect(.degrees(8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 34)
                .padding(.top, 104)
                .allowsHitTesting(false)
            // The skin's enamel badge (v0.5.6): every colourway pins its own
            // emblem to the plate, so turning the device over answers "which
            // one is this" the way a console's model badge does.
            SkinBadge(skin: skin)
                .rotationEffect(.degrees(-7))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 36)
                .padding(.top, 108)
                .allowsHitTesting(false)
        }
        // A dark edge all the way round. Without it the plate's pale metal ran
        // straight into the chassis behind it and the underside read as a
        // lighting change rather than as a separate part that has been turned
        // over. Inset rather than a full-bleed stroke so the corner radius of
        // the display does not clip it away.
        .overlay {
            RoundedRectangle(cornerRadius: DexMetrics.deviceCorner)
                .strokeBorder(Color(dexHex: "#2b2d30"), lineWidth: 5)
                .padding(3)
                .allowsHitTesting(false)
        }
        .accessibilityLabel("Device back plate. Swipe to return.")
    }

    private var metal: some View {
        LinearGradient(
            colors: [
                Color(dexHex: "#cdcfd2"),
                Color(dexHex: "#9ea1a5"),
                Color(dexHex: "#7e8186"),
                Color(dexHex: "#b8babd"),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Fine vertical lines standing in for a brushed finish. The web version
    /// uses a repeating-linear-gradient; a striped Canvas is the cheap
    /// equivalent and stays crisp at any size.
    private var striations: some View {
        Canvas { context, size in
            let step: CGFloat = 2
            var x: CGFloat = 0
            while x < size.width {
                context.fill(
                    Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                    with: .color(.white.opacity(0.16))
                )
                context.fill(
                    Path(CGRect(x: x + 1, y: 0, width: 1, height: size.height)),
                    with: .color(.black.opacity(0.16))
                )
                x += step
            }
        }
        .blendMode(.overlay)
        .opacity(0.45)
        .allowsHitTesting(false)
    }

    private var highlight: some View {
        RadialGradient(
            colors: [.white.opacity(0.35), .clear],
            center: UnitPoint(x: 0.3, y: 0.2),
            startRadius: 0,
            endRadius: 420
        )
        .allowsHitTesting(false)
    }

    /// Screws pulled well in from the corners.
    ///
    /// At 16pt they sat inside the display's 55pt corner arc, so each one was
    /// cut into on the diagonal and the top pair fouled the dark border. This is
    /// the same arithmetic `cornerGuardH` does for the chassis controls: a
    /// fastener has to sit on flat plate, not on the curve.
    private var screws: some View {
        VStack {
            HStack { screw; Spacer(); screw }
            Spacer()
            HStack { screw; Spacer(); screw }
        }
        .padding(38)
        .allowsHitTesting(false)
    }

    private var screw: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Dex.stone200, Dex.stone400, Dex.stone600],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 26, height: 26)
            .overlay(Circle().strokeBorder(Dex.stone700, lineWidth: 1))
            .overlay(
                // The slot.
                Capsule()
                    .fill(Dex.stone800.opacity(0.7))
                    .frame(width: 18, height: 3)
                    .rotationEffect(.degrees(45))
            )
            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
    }

    /// The engraved copy, scaled up throughout.
    ///
    /// This is a full-screen surface carrying six short lines, and it was set at
    /// list-row sizes — the nameplate that is meant to be the object's makers
    /// mark was smaller than a section header on the LCD. Every size here is up
    /// roughly a third, with the nameplate up more than that, since it is the
    /// one thing the plate exists to show.
    private var engraving: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            // Recessed nameplate.
            VStack(spacing: 12) {
                Text("VINODEX")
                    .font(DexFont.retro(36))
                    .tracking(8)
                    .foregroundStyle(Dex.stone800)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                // Read from `AppVersion` rather than a literal here, which had
                // been stuck at v0.3.5 for several releases.
                Text(AppVersion.display)
                    .font(DexFont.mono(28))
                    .tracking(7)
                    .foregroundStyle(Dex.stone700)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Dex.stone600.opacity(0.4), Dex.stone800.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Dex.stone700.opacity(0.6), lineWidth: 2)
            )
            .engraved()

            // The serial block keeps its recessed panel — the nameplate's
            // treatment, one register lighter. The "CREATED BY" line is gone
            // (v0.5.3): the maker's mark lives in the © line, and the plate
            // carries factory stickers now rather than more engraving.
            VStack(spacing: 10) {
                Text("SN: VDX-\(String(year))-001")
                Text("© \(String(year)) \(Self.creator)")
                Text("ALL RIGHTS RESERVED")
            }
            .font(DexFont.mono(22))
            .tracking(4)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .foregroundStyle(Dex.stone700)
            .engraved()
            .padding(.horizontal, 26)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Dex.stone600.opacity(0.22), Dex.stone800.opacity(0.22)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Dex.stone700.opacity(0.4), lineWidth: 2)
            )
            .engraved()

            swipeHint

            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .allowsHitTesting(false)
    }

    /// The way out, engraved directly under the middle block.
    ///
    /// It has moved twice. It began in engraved grey at the very bottom edge,
    /// below the serial and the copyright, where nobody found it. It was then
    /// tried as a dark chip above the nameplate, which solved the contrast by
    /// putting a *button* on a plate that has no buttons — the one element here
    /// that did not look machined.
    ///
    /// This is the version that keeps both: it stays engraved, in the plate's
    /// own language, but sits directly under the centred block rather than at
    /// the bottom edge, and is set larger and darker than the serial lines
    /// around it. Position and weight carry the emphasis instead of colour.
    ///
    /// VT323 rather than the retro face: `SWIPE TO RETURN` is fifteen tracked
    /// characters, and Press Start 2P at a size worth reading overruns the
    /// plate on a phone at the LARGE text scale.
    private var swipeHint: some View {
        HStack(spacing: 14) {
            Image(systemName: "hand.draw")
                .font(.system(size: 26, weight: .semibold))
            Text("SWIPE TO RETURN")
                .font(DexFont.mono(30))
                .tracking(7)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(Dex.stone800)
        .engraved()
    }
}

private extension View {
    /// The two-shadow trick the web panel uses for engraved lettering: a light
    /// edge below, a dark one above.
    func engraved() -> some View {
        self
            .shadow(color: .white.opacity(0.55), radius: 0, x: 0, y: 1)
            .shadow(color: .black.opacity(0.45), radius: 0, x: 0, y: -1)
    }
}

/// A sun-faded barcode sticker. The bars are a fixed pattern, not data — a
/// deterministic sequence so the plate looks identical on every launch.
private struct BarcodeSticker: View {
    /// Bar widths, in points at the sticker's own scale. Hand-picked to read
    /// as EAN-ish without pretending to encode anything.
    private static let bars: [CGFloat] = [
        2, 1, 3, 1, 1, 2, 1, 4, 1, 2, 2, 1, 1, 3, 2, 1, 2, 1, 1, 4, 1, 2, 1, 3, 1, 1, 2, 2,
    ]

    var body: some View {
        VStack(spacing: 3) {
            Canvas { context, size in
                var x: CGFloat = 0
                let unit = size.width / Self.bars.reduce(0, +) / 1.9
                for (index, width) in Self.bars.enumerated() {
                    let w = width * unit
                    if index.isMultiple(of: 2) {
                        context.fill(
                            Path(CGRect(x: x, y: 0, width: w, height: size.height)),
                            with: .color(.black.opacity(0.78))
                        )
                    }
                    x += w * 1.9
                }
            }
            .frame(width: 108, height: 30)

            Text("4 71332 90815")
                .font(DexFont.mono(13))
                .tracking(2)
                .foregroundStyle(.black.opacity(0.7))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color(dexHex: "#E9E6DA")))
        .overlay(
            // A worn top edge, as if the lamination has yellowed.
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [Color(dexHex: "#C9C2A8").opacity(0.5), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        )
        // Faded: the sticker sits *under* years of handling.
        .opacity(0.68)
        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
    }
}

/// The skin's enamel badge: the emblem glyph on the accent ramp, ringed like
/// a pin pressed into the plate. Colour and glyph both come off the skin, so
/// each colourway leaves a different mark.
private struct SkinBadge: View {
    let skin: ChassisSkin

    var body: some View {
        Image(systemName: skin.symbol)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(skin.accent.ink)
            .frame(width: 52, height: 52)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [skin.accent.light, skin.accent.bright],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(Circle().strokeBorder(skin.accent.edge, lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
    }
}

/// The pink price tag someone tried to peel — the left half survives, the
/// right edge is torn into a jagged profile.
private struct RippedPriceTag: View {
    /// The tear, as fractions of the tag's bounds: straight edges everywhere
    /// except the right side, which staggers inward and back out.
    private struct TornEdge: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX * 0.92, y: rect.minY))
            // The rip.
            let steps: [(CGFloat, CGFloat)] = [
                (0.84, 0.18), (0.95, 0.32), (0.78, 0.45),
                (0.90, 0.60), (0.74, 0.74), (0.86, 0.88), (0.70, 1.0),
            ]
            for (fx, fy) in steps {
                p.addLine(to: CGPoint(x: rect.maxX * fx, y: rect.minY + rect.height * fy))
            }
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
            return p
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("SALE")
                .font(DexFont.retro(10))
                .tracking(2)
                .foregroundStyle(Color(dexHex: "#8F2D56"))
            Text("$4.99")
                .font(DexFont.mono(24))
                .foregroundStyle(Color(dexHex: "#6B1D40"))
        }
        .padding(.leading, 10)
        .padding(.trailing, 26)
        .padding(.vertical, 8)
        .background(TornEdge().fill(Color(dexHex: "#F5A8C4")))
        .overlay(
            // The tear's raw paper edge — lighter, like exposed stock.
            TornEdge().stroke(Color(dexHex: "#FBD3E2"), lineWidth: 1.5)
        )
        .opacity(0.9)
        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
    }
}
#endif
