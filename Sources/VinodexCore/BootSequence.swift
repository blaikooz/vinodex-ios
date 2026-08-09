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
    /// and it then holds on `PRESS ANY BUTTON TO CONTINUE` until a touch
    /// (until a touch *or a timeout* through 0.8.93 — see the retirement note
    /// below).
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

    /// **`autoAdvance` retired in 0.8.94 (B1), and nothing replaces it.**
    ///
    /// 0.7.7's C2 argued a timeout was a safety net — a dead digitiser, a
    /// screen-reader user who has not found the target, a device set down —
    /// and shipped 3.5 seconds of it. B1 reverses the ruling with the lived
    /// result: the net caught nobody and the screen *opened the app on its
    /// own* before an unhurried reader finished the prompt, which makes
    /// `PRESS ANY BUTTON TO CONTINUE` a countdown wearing an instruction's
    /// words. The prompt now means what it says: the composition holds until
    /// a touch, however long that takes. `longestUntouched` went with it —
    /// there is no longer a bound to derive, which is the point.
    ///
    /// What survives of C2's worry is the *reachability* of the answer, not a
    /// timer: any touch anywhere advances (the window-level catcher), so
    /// "found the tap target" is every point on the glass.

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
