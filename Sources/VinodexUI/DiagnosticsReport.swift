#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// Font/data/palette health, as OK-or-not lines.
///
/// Extracted from `CatalogScreen` so the settings panel and the debug catalog
/// show the same report rather than two that drift apart.
struct DiagnosticsReport: View {
    let db: WineDatabase

    init(db: WineDatabase = .shared) {
        self.db = db
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(DexFont.statusReport, id: \.self) { line in
                row(line, ok: !line.contains("FALLBACK") && !line.hasPrefix("FAILED"))
            }
            row("entries \(db.entries.count)", ok: !db.entries.isEmpty)
            row("palette chips \(db.palette.countryChips.count)", ok: !db.palette.countryChips.isEmpty)

            // Counts used to be the whole story here — "icons 66", "flags 29" —
            // and a count is a statement about the *manifest*, not about the
            // build. Every one of those ids is a filename, and nothing checked
            // that the file was there; a rasterisation gap shipped as a red
            // placeholder on one tile. These rows resolve each id through the
            // bundle. (AUDIT **L26**)
            ForEach(DexAssetAudit.run(db)) { surface in
                row(surface.line, ok: surface.ok)
            }

            if db.decodeErrors.isEmpty {
                row("decode clean", ok: true)
            } else {
                ForEach(db.decodeErrors, id: \.self) { row($0, ok: false) }
            }

            // Notices, not faults (AUDIT **M45**). A missing schema stamp, an
            // absent countries table — things a maintainer should know and a
            // user must never be alerted about. This panel is the *only* place
            // they surface, which is the whole reason the split is safe.
            ForEach(db.loadNotices, id: \.self) { row($0, level: .notice) }
        }
    }

    private enum Level {
        case ok, fault, notice
    }

    private func row(_ text: String, ok: Bool) -> some View {
        row(text, level: ok ? .ok : .fault)
    }

    private func row(_ text: String, level: Level) -> some View {
        HStack(spacing: 6) {
            Text(level == .ok ? "OK" : level == .notice ? "??" : "!!")
                .font(DexFont.retro(10))
                .foregroundStyle(level == .ok ? Dex.green : level == .notice ? Dex.amber400 : Dex.red500)
            Text(text)
                .font(DexFont.mono(18))
                .foregroundStyle(Dex.stone200)
        }
    }
}
#endif
