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
    /// How long the staged checks run.
    ///
    /// **This used to be the whole screen, and 0.7.7 (C1/C2) split it.** Through
    /// 0.7.5 the POST *was* the lines: they finished, the screen cut, and
    /// `duration` bounded the entire launch cost. The BIOS redesign makes the
    /// lines the first of two phases — they resolve, the composition settles,
    /// and it then holds on `PRESS ANY BUTTON TO CONTINUE` until a touch or
    /// `autoAdvance`.
    ///
    /// The number did not move and neither did the argument behind it. A fourth
    /// line "since we are here" is still what stops this being brief, and
    /// `BootSequenceTests.brief` still refuses it. What changed is that the pin
    /// is now scoped to the phase it was always actually about, with
    /// `neverTraps` bounding the rest — see that test for why the old single
    /// assertion could not simply be widened.
    public static let duration: TimeInterval = 1.9

    /// The pause after the last line, so the final result is readable rather
    /// than a flash before the cut.
    public static let settle: TimeInterval = 0.45

    /// How long the resting composition holds before advancing itself
    /// (0.7.7, C2).
    ///
    /// **A timeout is the requirement; the length is the judgement.** C2 asks
    /// for a prompt that any input answers *and* a timeout so the screen can
    /// never trap someone — a device with a dead digitiser, a screen reader
    /// user who has not found the tap target, anyone who set the thing down.
    /// So this is a ceiling on being stuck, not a dwell someone is meant to
    /// wait out.
    ///
    /// 3.5s, from both ends: under about three the prompt is gone before it can
    /// be read, which makes it a lie rather than an instruction, and much over
    /// four it stops being a safety net and becomes a splash screen — the tax
    /// on every single launch forever that 0.7.3a's note is about. The whole
    /// point of `longestUntouched` is that this number has somewhere to be
    /// asserted.
    public static let autoAdvance: TimeInterval = 3.5

    /// The longest a launch can sit on the BIOS with nobody touching it.
    ///
    /// Derived rather than declared so it cannot drift from the two constants
    /// it bounds. A ceiling, not the measured time: the last check lands at
    /// 1.10 and `duration` is the budget it fits inside.
    public static var longestUntouched: TimeInterval { duration + autoAdvance }

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
