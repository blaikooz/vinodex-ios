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
                        // The newest release stays open — it is what this
                        // build is — and everything older folds into minor
                        // families (0.9.X, 0.8.X …) that expand on tap
                        // (0.9.53, maintainer order). Thirty-plus entries
                        // had become a scroll of history before the reader
                        // reached the credit.
                        if let current = catalog.releases.first {
                            entry(current)
                        }
                        ForEach(families, id: \.name) { family in
                            familySection(family)
                        }
                        credit
                    }
                    .padding(18)
                }
            }
        }
    }

    /// One collapsed minor family (0.8.X …) of the history.
    private struct Family {
        let name: String
        let releases: [FirmwareRelease]
    }

    /// Which families are open. Session state, like a scroll position.
    @State private var expandedFamilies: Set<String> = []

    /// Everything after the newest release, grouped by minor version in the
    /// order the (newest-first) list already has.
    private var families: [Family] {
        var out: [Family] = []
        for release in catalog.releases.dropFirst() {
            let name = release.version.split(separator: ".").prefix(2).joined(separator: ".")
            if let last = out.indices.last, out[last].name == name {
                out[last] = Family(name: name, releases: out[last].releases + [release])
            } else {
                out.append(Family(name: name, releases: [release]))
            }
        }
        return out
    }

    @ViewBuilder
    private func familySection(_ family: Family) -> some View {
        let open = expandedFamilies.contains(family.name)
        Button {
            Haptics.select()
            withAnimation(.easeOut(duration: 0.2)) {
                if open { expandedFamilies.remove(family.name) }
                else { expandedFamilies.insert(family.name) }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(lcd.accent)
                    .rotationEffect(.degrees(open ? 90 : 0))
                Text("\(family.name.uppercased()).X")
                    .font(DexFont.retro(12))
                    .tracking(1.5)
                    .foregroundStyle(lcd.text)
                Text("\(family.releases.count) RELEASES")
                    .font(DexFont.retro(10))
                    .tracking(1)
                    .foregroundStyle(lcd.subtext)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        .accessibilityLabel("Firmware \(family.name) family, \(family.releases.count) releases, \(open ? "expanded" : "collapsed")")

        if open {
            ForEach(family.releases) { release in
                entry(release)
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
                // The drawn chip (0.8.9a, A7). The *route* title goes on the
                // chassis marquee and already wears `marquee-firmware`, which
                // is the dot-matrix register -- a painted glyph there would be
                // flattened to a silhouette by `DexChromeGlyph(flatten:)` and
                // lose the thing that makes it worth drawing. This readout is
                // the page's own title, on a lit LCD that renders art as art,
                // and it is where a painted chip belongs.
                DexChromeGlyph(
                    UIGlyph.firmware.artStem, symbol: "memorychip.fill",
                    size: 20, weight: .bold, tint: lcd.accent
                )
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

    /// The credit lines (0.9.46; a second joined them in 0.9.55).
    ///
    /// The bundled pixel flags are R74n's, restored by the collective's kind
    /// permission (2026-09-07) with the ask that credit be provided. The
    /// bundled wine index is Liv-ex's LWIN database under **CC BY 4.0**,
    /// which does not merely invite credit but *requires* it — attribution to
    /// the licensor, the licence, and a statement that the work was modified.
    /// 0.9.54 shipped the data with none of the three; this is the repair.
    ///
    /// The modification is real and must be declared: the import keeps the
    /// Live wines and fortified wines and drops the spirits, combined and
    /// deleted rows, taking 211,786 records to 184,968, and re-encodes what
    /// survives into the app's own packed format. "MODIFIED" below is that
    /// statement in the space a retro device's foot-of-screen allows; the
    /// full account is in ATTRIBUTION.md, which this line names.
    ///
    /// The foot of the device's own version record is where a credit belongs:
    /// it is the one screen already about provenance.
    /// Broken across two lines rather than one, because the credit has to
    /// survive HUGE: the retro face advances close to a full em, so the
    /// 45-character single line wanted ~630pt at the 1.30 step against an
    /// LCD barely 340 wide. The R74n line above it is 30 characters and has
    /// always sat near that limit, which is the measurement this follows.
    private var credit: some View {
        VStack(spacing: 3) {
            Text("PIXEL FLAGS BY R74N (R74N.COM)")
            Text("WINE INDEX: LWIN BY LIV-EX")
            Text("CC BY 4.0, MODIFIED")
        }
        .font(DexFont.retro(10))
        .tracking(1)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .multilineTextAlignment(.center)
        .foregroundStyle(lcd.subtext)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 4)
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
                        .font(DexFont.retro(10))
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
