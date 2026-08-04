#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// Font/data/palette health, as OK-or-not lines.
///
/// Extracted from `CatalogScreen` so the settings panel and the debug catalog
/// show the same report rather than two that drift apart.
public struct DiagnosticsReport: View {
    let db: WineDatabase
    let exam: ExamCatalog

    public init(db: WineDatabase = .shared, exam: ExamCatalog = .shared) {
        self.db = db
        self.exam = exam
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
            // The exam bank is its own resource with its own decode, so a
            // healthy catalog says nothing about it (0.7.5, D). It decodes
            // element-wise, which means a broken question is silent by
            // construction — this is where it stops being silent.
            row("exam questions \(exam.questions.count)", ok: !exam.isEmpty)

            if db.decodeErrors.isEmpty, exam.decodeErrors.isEmpty {
                row("decode clean", ok: true)
            } else {
                ForEach(db.decodeErrors, id: \.self) { row($0, ok: false) }
                ForEach(exam.decodeErrors, id: \.self) { row("exam \($0)", ok: false) }
            }
        }
    }

    private func row(_ text: String, ok: Bool) -> some View {
        HStack(spacing: 6) {
            Text(ok ? "OK" : "!!")
                .font(DexFont.retro(10))
                .foregroundStyle(ok ? Dex.green : Dex.red500)
            Text(text)
                .font(DexFont.mono(18))
                .foregroundStyle(Dex.stone200)
        }
    }
}
#endif
