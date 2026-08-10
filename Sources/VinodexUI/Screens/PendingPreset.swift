#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import VinodexCore

// The value behind CUSTOMIZE's FIT prompt. Its own file rather than a tail on
// SettingsPanel.swift, for the reason `SettingsControls` and `SavedDataActions`
// are theirs (AUDIT **M30**): it is not a panel, it is a small value type two
// pickers share, and nothing about it is settings-specific but its call sites.

/// A preset the user has tapped in CUSTOMIZE, and what fitting it will cost
/// (0.7.8, A2).
///
/// **Why this is a value rather than two `if` branches in the two grids.** The
/// SHELL and SCREEN pickers are the same instrument with different contents —
/// they were written that way on purpose in 0.5.6 — and A2's rule is one rule
/// about presets, not two rules about skins and modes. Modelling the tap as a
/// value lets both grids raise the same alert, and lets the alert be built from
/// what the tap *is* rather than from a copy of the rule per call site. It also
/// means the eleventh axis, whenever it arrives, changes `DeviceAxis.inherits`
/// and nothing here.
///
/// The three things it holds beyond the choice itself are all things Core
/// cannot know: `label` is a `displayName` (a `VinodexUI` concept), and
/// `defaultValue` is which raw value means "as it ships" for this particular
/// enum, which is `ChassisSkin.classic` / `LcdMode.dark` — again UI's.
struct PendingPreset: Equatable {
    let axis: DeviceAxis
    let value: String
    let defaultValue: String
    let label: String

    /// The fitted parts this choice would clear. Read once, at the moment of
    /// the tap, so the alert cannot describe a device that has since changed.
    let cleared: [DeviceAxis]

    init(axis: DeviceAxis, value: String, defaultValue: String, label: String) {
        self.axis = axis
        self.value = value
        self.defaultValue = defaultValue
        self.label = label
        self.cleared = DeviceBuild.overrides(clearedByChoosing: axis)
    }

    /// Write the choice, and bring the settings model back in step with it.
    ///
    /// **`@MainActor` because of the second line, and the second line is not
    /// optional** (arch **A17** meeting 0.7.3's B1). `DeviceBuild.choose` writes
    /// `UserDefaults` directly, and two of the ten keys it owns are the two
    /// `AppSettings` also owns — `DeviceAxis.shell.storageKey` *is*
    /// `ChassisSkin.storageKey`, and `.screen`'s *is* `LcdMode.storageKey`.
    /// `AppSettings` reads its keys once in `init` and holds them for the life
    /// of the process, so a write that goes round it leaves the shell tile
    /// ticked and the whole chassis unchanged until the next launch. This is the
    /// trap **M35** recorded, reached from the other side, and `reload()` is the
    /// same answer `SavedDataRestore.apply` gives it.
    @MainActor
    func commit() {
        DeviceBuild.choose(axis, value, defaultValue: defaultValue)
        AppSettings.shared.reload()
    }

    /// What the alert says.
    ///
    /// `fitted` is the saved build the device currently matches, if any. It is
    /// named when there is one because "your build stops being fitted" and
    /// "your build is gone" are the two readings of what is about to happen and
    /// only one of them is true — `customDevices` is untouched by any of this,
    /// and saying so is cheaper than a user discovering it or not.
    func message(fitted: CustomDevice?) -> String {
        let parts = cleared.map(\.title).joined(separator: ", ")
        let count = cleared.count == 1 ? "part" : "parts"
        var lines = [
            "\(label) brings its own colours, so the \(cleared.count) \(count) you fitted "
            + "(\(parts)) go back to following it.",
        ]
        if let fitted {
            lines.append("\(fitted.name) stays saved in the Workshop — fit it again there whenever you like.")
        } else {
            lines.append("Save a build in the Workshop first if you want to come back to it.")
        }
        return lines.joined(separator: " ")
    }
}
#endif
