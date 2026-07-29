#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The brushed-metal underside of the device, ported from
/// `components/DeviceBackPanel.tsx`.
///
/// Engraved nameplate, corner screws and a serial, on a diagonal metal
/// gradient. The whole plate is tappable to flip back, matching the web app.
public struct DeviceBackPlate: View {
    private static let creator = "HORIZON"

    private var year: Int { Calendar.current.component(.year, from: Date()) }

    public init() {}

    public var body: some View {
        // Dismissal is a swipe, owned by `DeviceChassis` — the plate is a
        // surface, not a button.
        ZStack {
            metal
            striations
            highlight
            screws
            engraving
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

            Text("CREATED BY \(Self.creator)")
                .font(DexFont.mono(25))
                .tracking(6)
                .foregroundStyle(Dex.stone700)
                .engraved()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Dex.stone800.opacity(0.4), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                Text("SN: VDX-\(String(year))-001")
                Text("© \(String(year)) \(Self.creator)")
                Text("ALL RIGHTS RESERVED")
            }
            .font(DexFont.mono(22))
            .tracking(4)
            .foregroundStyle(Dex.stone700)
            .engraved()

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 18))
                Text("SWIPE TO RETURN")
                    .font(DexFont.mono(23))
                    .tracking(6)
            }
            .foregroundStyle(Dex.stone800.opacity(0.85))
            .padding(.bottom, 34)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .allowsHitTesting(false)
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
#endif
