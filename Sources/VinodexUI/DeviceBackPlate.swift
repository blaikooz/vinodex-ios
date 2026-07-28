#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The brushed-metal underside of the device, ported from
/// `components/DeviceBackPanel.tsx`.
///
/// Engraved nameplate, corner screws and a serial, on a diagonal metal
/// gradient. The whole plate is tappable to flip back, matching the web app.
public struct DeviceBackPlate: View {
    private static let creator = "HORIZON"
    private static let version = "v0.3.5"

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

    private var screws: some View {
        VStack {
            HStack { screw; Spacer(); screw }
            Spacer()
            HStack { screw; Spacer(); screw }
        }
        .padding(16)
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
            .frame(width: 20, height: 20)
            .overlay(Circle().strokeBorder(Dex.stone700, lineWidth: 1))
            .overlay(
                // The slot.
                Capsule()
                    .fill(Dex.stone800.opacity(0.7))
                    .frame(width: 14, height: 2)
                    .rotationEffect(.degrees(45))
            )
            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
    }

    private var engraving: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            // Recessed nameplate.
            VStack(spacing: 8) {
                Text("VINODEX")
                    .font(DexFont.retro(26))
                    .tracking(6)
                    .foregroundStyle(Dex.stone800)
                Text(Self.version)
                    .font(DexFont.mono(20))
                    .tracking(6)
                    .foregroundStyle(Dex.stone700)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Dex.stone600.opacity(0.4), Dex.stone800.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Dex.stone700.opacity(0.6), lineWidth: 1)
            )
            .engraved()

            Text("CREATED BY \(Self.creator)")
                .font(DexFont.mono(19))
                .tracking(5)
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
                .frame(height: 1)
                .padding(.horizontal, 40)

            VStack(spacing: 7) {
                Text("SN: VDX-\(String(year))-001")
                Text("© \(String(year)) \(Self.creator)")
                Text("ALL RIGHTS RESERVED")
            }
            .font(DexFont.mono(17))
            .tracking(3)
            .foregroundStyle(Dex.stone700)
            .engraved()

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 13))
                Text("SWIPE TO RETURN")
                    .font(DexFont.mono(18))
                    .tracking(5)
            }
            .foregroundStyle(Dex.stone800.opacity(0.85))
            .padding(.bottom, 28)
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
