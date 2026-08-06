import Foundation

/// The BIOS screen's fixed text and its one live readout (0.7.7).
///
/// **Why any of this is in Core.** `BootScreen` is a bespoke pixel composition
/// and almost all of it is geometry, which belongs in the view and is invisible
/// to `swift test` anyway. What is *not* geometry is the handful of things the
/// screen asserts about the machine — the firmware version, the copyright year,
/// the battery — and every one of those has a way of quietly going wrong that a
/// test can catch. So the strings and the two derivations live here and the view
/// renders them.
///
/// **The version is deliberately not in this file.** The mockup this batch was
/// built from shows `VINODEX BIOS v1.0.0`, and that string is a trap: xtool
/// stamps `CFBundleShortVersionString = 1.0.0` into every bundle it builds, and
/// `AppVersion.placeholders` exists to reject exactly that value so the app
/// reports the version a human chose. "The screen reads 1.0.0" is the standing
/// signal that the denylist has broken. A BIOS screen printing it as decoration
/// would be indistinguishable from that failure, so the title comes from
/// `BootSequence.header(version:)`, which reads `FirmwareCatalog` through
/// `AppVersion` — C3 over the mockup, and the one place in the spec where the
/// literal had to lose.
public enum BiosChrome: Sendable {
    /// The tagline under the divider.
    ///
    /// Middle dots rather than the hyphens the written spec transcribes: the
    /// description calls it "bullet-separated", the hyphens are what a plain-text
    /// rendering of a bullet looks like, and `PressStart2P` carries U+00B7 (this
    /// was checked against the shipped TTF's cmap, not assumed — the face has a
    /// *partial* Latin-1 range, which is why `BootSequence`'s lines are held to
    /// ASCII). `EntryDetailScreen` already joins on the same character.
    public static let tagline = "DISCOVER · COLLECT · TASTE"

    // `system` retired in 0.8.0 (B2). It read VINODEX HANDHELD SYSTEM and it was
    // the pill interrupting the bottom rule. B2 asks for the line gone, and the
    // constant goes with it rather than being left for a reader to wire back up:
    // the screen already names the machine twice — the wordmark in the centre and
    // the title in the top bar — and a third assertion of the same fact, at the
    // bottom, in a box, is the "line of text standing in for something" that
    // `DeviceBackPlate`'s swipe-hint note is about. The rule it interrupted stays
    // as `BiosSolidRule`; what closes the composition is the line, not the label.
    //
    // `BiosChromeTests.chromeIsDrawable` lost its entry here and nothing else
    // named it.

    /// The resting status line: label in cream, result in gold.
    public static let checkLabel = "SYSTEM CHECK..."
    public static let checkResult = "OK"

    /// The prompt (C2). Says "button" rather than "screen" because the device
    /// this is pretending to be has buttons, and the chassis under this screen
    /// has six of them — though what actually advances is any touch at all.
    public static let prompt = "PRESS ANY BUTTON TO CONTINUE"

    /// The year the copyright line claims, when no release date is readable.
    ///
    /// A floor rather than a guess: it is the year of the releases this build
    /// was written alongside, and a catalog that failed to load is a bigger
    /// problem than a stale year.
    public static let fallbackYear = "2026"

    /// The authorship the copyright line claims (0.8.0, B1).
    ///
    /// **`VINODEX SOFTWARE` until 0.8.0, and the change is the point of the minor
    /// bump.** The fictional publisher was named after the product, which made
    /// the boot screen's one piece of telemetry a tautology — the machine
    /// asserting that it was made by itself. HORIZON/GODOT is the house; Vinodex
    /// is the thing it ships. That is also what makes the title and the copyright
    /// two different claims rather than the same one twice, which is what B3 and
    /// B4 then have room to centre on separate lines.
    ///
    /// A constant rather than a literal inside `copyright(releaseDate:)` because
    /// it is the half of that string a future release might change again, and
    /// because a test asserting the whole formatted line would then be asserting
    /// the format and the name at once.
    public static let publisher = "HORIZON/GODOT"

    /// `(c)2026 HORIZON/GODOT`, with the year taken from the firmware.
    ///
    /// **Derived rather than typed** for the same reason the version is. A
    /// hardcoded year is a literal nobody remembers to edit, which is the exact
    /// failure mode `AppVersion` was written to end; deriving it from
    /// `Date()` instead would make the screen's text depend on the clock, which
    /// is untestable and would let a device with a wrong date print a wrong
    /// year. The release the build ships as already carries a date, it moves
    /// once per batch, and it is the same source the version comes from.
    ///
    /// - Parameter releaseDate: `FirmwareCatalog.shared.current?.date`, an
    ///   ISO-ish `YYYY-MM-DD`. Anything that does not start with four digits
    ///   falls back.
    public static func copyright(releaseDate: String?) -> String {
        "(c)" + year(from: releaseDate) + " " + publisher
    }

    /// The four-digit year at the head of `date`, or `fallbackYear`.
    public static func year(from date: String?) -> String {
        guard let date, date.count >= 4 else { return fallbackYear }
        let head = String(date.prefix(4))
        guard head.allSatisfy({ $0.isASCII && $0.isNumber }) else { return fallbackYear }
        return head
    }

    /// What the battery corner shows (D1).
    ///
    /// One type carrying both the text and the fill, so the number and the bars
    /// cannot disagree — they are read at two different points in the view.
    public struct BatteryReadout: Sendable, Equatable {
        /// `"100%"`, `"73%"`.
        public let text: String
        /// 0...1, for the glyph's filled bars.
        public let fill: Double
        /// False when the level was unreadable and this is the fallback. The
        /// view does not branch on it; the test does, because "falls back to
        /// 100%" and "the battery is genuinely full" produce identical text and
        /// only this tells them apart.
        public let isReal: Bool
    }

    /// A `UIDevice.batteryLevel` reading, turned into what the corner prints.
    ///
    /// **-1 is the case this function exists for.** `batteryLevel` returns -1.0
    /// for `.unknown`, which is what you get on the simulator *and* on a real
    /// device before `isBatteryMonitoringEnabled` has been set — so the naive
    /// `Int(level * 100)` prints `-100%`, on the first screen of the app, on
    /// every simulator run. D1 asks for a fallback to `100%` and this is it.
    /// Levels are also clamped: the documented range is 0...1 and a device that
    /// reported 1.02 would otherwise print `102%`.
    public static func battery(level: Float) -> BatteryReadout {
        guard level >= 0 else {
            return BatteryReadout(text: "100%", fill: 1, isReal: false)
        }
        let clamped = min(max(Double(level), 0), 1)
        return BatteryReadout(
            text: "\(Int((clamped * 100).rounded()))%",
            fill: clamped,
            isReal: true
        )
    }
}
