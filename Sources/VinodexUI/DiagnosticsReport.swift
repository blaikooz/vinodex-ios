#if canImport(SwiftUI)
import SwiftUI
import VinodexCore

/// Font/data/palette health, as OK-or-not lines.
///
/// Extracted from `CatalogScreen` so the settings panel and the debug catalog
/// show the same report rather than two that drift apart.
public struct DiagnosticsReport: View {
    let db: WineDatabase

    public init(db: WineDatabase = .shared) {
        self.db = db
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(DexFont.statusReport, id: \.self) { line in
                row(line, ok: !line.contains("FALLBACK") && !line.hasPrefix("FAILED"))
            }
            row("entries \(db.entries.count)", ok: !db.entries.isEmpty)
            row("palette chips \(db.palette.countryChips.count)", ok: !db.palette.countryChips.isEmpty)
            row("icons \(db.icons.unique.count)", ok: !db.icons.unique.isEmpty)
            row("flags \(db.icons.flags.count)", ok: !db.icons.flags.isEmpty)

            if db.decodeErrors.isEmpty {
                row("decode clean", ok: true)
            } else {
                ForEach(db.decodeErrors, id: \.self) { row($0, ok: false) }
            }
        }
    }

    private func row(_ text: String, ok: Bool) -> some View {
        HStack(spacing: 6) {
            Text(ok ? "OK" : "!!")
                .font(DexFont.retro(9))
                .foregroundStyle(ok ? Dex.green : Dex.red500)
            Text(text)
                .font(DexFont.mono(18))
                .foregroundStyle(Dex.stone200)
        }
    }
}
#endif
