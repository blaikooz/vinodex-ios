import Foundation

/// One line of the power-on self test (0.7.3, A1).
///
/// A POST line is a label, a result, and the moment it appears. Modelled rather
/// than hardcoded into the view because the interesting half of a boot screen is
/// not the typography — it is *what it claims, in what order, and how long the
/// whole thing takes*, and "keep it brief" is an assertion someone should be
/// able to make in a test rather than a promise in a spec.
public struct BootLine: Sendable, Hashable, Identifiable {
    /// Stable across runs — the view animates on it.
    public let id: String
    /// The left column. Uppercase ASCII; the boot screen is set in the retro
    /// face, which has a partial Latin-1 range.
    public let label: String
    /// The right column, revealed at `at`.
    public let result: String
    /// Seconds from the start of the sequence.
    public let at: TimeInterval

    public init(id: String, label: String, result: String, at: TimeInterval) {
        self.id = id
        self.label = label
        self.result = result
        self.at = at
    }
}

/// The startup POST (0.7.3, A1).
///
/// **Brief is the requirement, so brief is what the table encodes.** A1 asks for
/// a memory check, a database initialisation and the firmware version, then the
/// app — and says "keep it brief and skippable". Every line lands inside
/// `duration`, which is under two seconds, and `BootSequenceTests` pins that:
/// a boot animation is a tax on every single launch forever, and the second
/// somebody adds a fourth line "since we are here" is the second it stops being
/// brief. Skipping is the view's job and costs nothing.
///
/// **The numbers are real where a real number exists.** The database line
/// reports the catalog's actual entry count, because the app has one and a boot
/// screen that invented one would be the same quiet lie `AppVersion` spends
/// forty lines on. The memory figure is the exception and is deliberately a
/// joke: 640K is the line every reader of a POST screen knows, this device has
/// no memory budget to report, and reporting the process's real resident size
/// would be both meaningless and alarming.
public enum BootSequence: Sendable {
    /// How long the whole sequence runs before the app takes over.
    public static let duration: TimeInterval = 1.9

    /// The pause after the last line, so the final result is readable rather
    /// than a flash before the cut.
    public static let settle: TimeInterval = 0.45

    /// The POST, for a given catalog size and firmware version.
    ///
    /// - Parameters:
    ///   - entries: the loaded catalog's entry count. Zero is a legitimate
    ///     answer — a build whose data failed to decode boots too, and saying
    ///     `0 ENTRIES` on the way in is better diagnostics than the app has
    ///     anywhere else.
    ///   - version: from `FirmwareCatalog` via `AppVersion` — A1 reads F3.
    ///   - verbose: the `verboseBoot` easter egg (A4). Adds the lines a real
    ///     POST would have and this one does not need.
    public static func lines(
        entries: Int,
        version: String,
        verbose: Bool = false
    ) -> [BootLine] {
        var lines: [BootLine] = [
            BootLine(id: "mem", label: "MEMORY", result: "640K OK", at: 0.30),
            BootLine(
                id: "db",
                label: "DATABASE",
                result: entries > 0 ? "\(entries) ENTRIES" : "NO DATA",
                at: 0.70
            ),
            BootLine(id: "fw", label: "FIRMWARE", result: "v" + version, at: 1.10),
        ]
        if verbose {
            // Between the database and the firmware in a real POST; appended and
            // re-sorted rather than spliced, so the base table above stays the
            // one anybody reading this file has to hold in their head.
            lines.append(BootLine(id: "cat", label: "CATALOG", result: "MOUNTED", at: 0.90))
            lines.append(BootLine(id: "lcd", label: "DISPLAY", result: "LCD OK", at: 0.50))
            lines.sort { $0.at < $1.at }
        }
        return lines
    }

    /// The banner above the POST.
    public static func header(version: String) -> String { "VINODEX BIOS v" + version }
}
