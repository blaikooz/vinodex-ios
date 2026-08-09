#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// What the device and display cartridges actually hold (0.7.3, 0.7.3c — C1/D1).
///
/// **This file is the join, and it is deliberately a `switch` rather than a
/// lookup by string.** `ExpansionPacks` lives in `VinodexCore`, which cannot see
/// `ChassisSkinSection` or `LcdModeSection` — those are `VinodexUI` types on a
/// module with no test target — so the two halves of a device pack have to meet
/// somewhere. The tempting version has Core carry the section's raw value
/// (`"CLEARTECH"`) and the UI look it up; that compiles forever and breaks
/// silently the first time somebody renames a heading, leaving a cartridge that
/// opens onto nothing.
///
/// Written as an exhaustive switch instead, it is checked in **both**
/// directions by the compiler: add a `ChassisSkinSection` and this stops
/// building until it names a pack, delete an `ExpansionPacks` constant and this
/// stops building because the name is gone. Neither failure can reach a device.
/// It is the same argument `ChassisSkin.section` makes for deriving the picker's
/// groups rather than listing them — no string, no drift.
extension ChassisSkinSection {
    /// The cartridge this collection of shells is sold as.
    var pack: ExpansionPack {
        switch self {
        case .classic: ExpansionPacks.classicDevices
        case .wines: ExpansionPacks.wineDevices
        case .vessel: ExpansionPacks.vesselDevices
        case .retrofit: ExpansionPacks.retrofitDevices
        case .clearTech: ExpansionPacks.clearTechDevices
        case .festive: ExpansionPacks.festiveDevices
        }
    }
}

extension LcdModeSection {
    /// The cartridge this family of screens is sold as.
    ///
    /// Note `.retro`, not a `.vintage` — 0.7.1's C1 renamed the section and D1's
    /// spelling of "Vintage" predates it. See `ExpansionPacks.retroDisplays`.
    var pack: ExpansionPack {
        switch self {
        case .classic: ExpansionPacks.classicDisplays
        case .retro: ExpansionPacks.retroDisplays
        case .emulator: ExpansionPacks.emulatorDisplays
        }
    }
}

extension ExpansionPack {
    /// How many skins or modes this cartridge holds.
    ///
    /// Counted from the section enums rather than stored on the pack, which is
    /// why `ExpansionPack.Contents.cosmetics` carries no number: `section.skins`
    /// and `section.modes` are already derived from `allCases`, so this figure
    /// cannot disagree with the picker it describes. `0` for the atlas packs,
    /// which hold no cosmetics — they have `progress(tried:in:)` instead, and the
    /// detail strip asks that question first.
    var cosmeticMemberCount: Int {
        if let section = ChassisSkinSection.allCases.first(where: { $0.pack.id == id }) {
            return section.skins.count
        }
        if let section = LcdModeSection.allCases.first(where: { $0.pack.id == id }) {
            return section.modes.count
        }
        return 0
    }
}
#endif
