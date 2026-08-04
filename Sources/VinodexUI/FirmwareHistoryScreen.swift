#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The installed firmware and every release before it (0.7.3, A3).
///
/// Reads `FirmwareCatalog`, which is the same source the boot POST states its
/// version from and the same source `AppVersion` resolves against — F3's whole
/// point. Nothing on this screen is a literal.
///
/// **Newest first, and the current one is marked.** A changelog whose top entry
/// might or might not be what you are running is a changelog you have to
/// cross-reference against the About box, so the installed release carries a
/// badge and the rest do not.
public struct FirmwareHistoryScreen: View {
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    private let catalog = FirmwareCatalog.shared

    public init() {}

    public var body: some View {
        ZStack {
            DexScreenBackground()

            if catalog.releases.isEmpty {
                // The distress state — `firmware.json` did not load. Says what
                // is wrong rather than showing an empty list, which would read
                // as "this device has no history". Drawn here rather than
                // through `DexEmptyState`: that wraps a *screen* whose query
                // found nothing, and this screen has no query — the resource is
                // either there or the build is broken.
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Dex.red500)
                    Text("NO FIRMWARE RECORD")
                        .font(DexFont.retro(12))
                        .tracking(1)
                        .foregroundStyle(lcd.text)
                    Text("The changelog resource failed to load. See SETTINGS > DEV.")
                        .font(DexFont.mono(16))
                        .foregroundStyle(lcd.subtext)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(28)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        installed
                        ForEach(catalog.releases) { release in
                            entry(release)
                        }
                    }
                    .padding(18)
                }
            }
        }
    }

    /// The headline readout: what is on this device right now.
    private var installed: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("INSTALLED")
                .font(DexFont.retro(10))
                .tracking(1.5)
                .foregroundStyle(lcd.subtext)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "memorychip.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(lcd.accent)
                Text(AppVersion.display)
                    .font(DexFont.retro(20))
                    .tracking(1)
                    .foregroundStyle(lcd.accent)
            }
            if let current = catalog.current {
                Text(current.headline)
                    .font(DexFont.retro(10))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(lcd.accent.opacity(0.5), lineWidth: 2)
        )
    }

    private func entry(_ release: FirmwareRelease) -> some View {
        let isCurrent = release.version == catalog.version
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("v" + release.version)
                    .font(DexFont.retro(13))
                    .tracking(1)
                    .foregroundStyle(isCurrent ? lcd.accent : lcd.text)
                if isCurrent {
                    Text("CURRENT")
                        .font(DexFont.retro(8))
                        .tracking(1)
                        .foregroundStyle(lcd.onAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 3).fill(lcd.accent))
                }
                Spacer(minLength: 8)
                Text(release.date)
                    .font(DexFont.mono(15))
                    .foregroundStyle(lcd.subtext)
            }

            Text(release.headline)
                .font(DexFont.retro(10))
                .tracking(1.5)
                .foregroundStyle(lcd.subtext)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { lcd.accent.opacity(0.3).frame(height: 1) }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(release.notes.enumerated()), id: \.offset) { _, note in
                    HStack(alignment: .top, spacing: 8) {
                        // A bullet the retro face definitely has, rather than a
                        // typographic one it may not — same rule as every other
                        // marquee-adjacent string in the app.
                        Text(">")
                            .font(DexFont.mono(16))
                            .foregroundStyle(lcd.accent.opacity(0.7))
                        Text(note)
                            .font(DexFont.mono(16))
                            .foregroundStyle(lcd.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
        )
    }
}
#endif
