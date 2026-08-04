import Foundation

/// One customizable part of the device (0.7.3, B1).
///
/// **The prerequisite check, written down.** 0.7.3b's spec asks for seven parts
/// to be "individually settable" and assumes the 0.6.x/0.7.1 chassis work made
/// them so. It did not. Through 0.7.2 the device had exactly *two* axes — the
/// shell (`chassisSkin`) and the screen mode (`lcdMode`) — and every other part
/// was a property *of the shell*: `ChassisSkin.orb`, `.accent`, `.control`,
/// `.grill`, `.marqueeText`. Choosing BURGUNDY chose a purple orb, purple caps
/// and a pink marquee together, because a skin was a whole dye lot rather than a
/// palette to draw from. The grille had no shape axis at all (four hardcoded
/// capsules), and the font colour was whatever the screen mode's ink token said.
///
/// So this enum is the batch's actual foundation: the six axes that did not
/// exist, beside the two that did, all read and written the same way. See
/// `DeviceBuild` for how they compose.
///
/// **The raw values are not persisted; `storageKey` is.** The cases can be
/// renamed freely, the keys cannot — see the note there.
public enum DeviceAxis: String, CaseIterable, Identifiable, Sendable {
    /// The moulded shell — a whole `ChassisSkin`, and still the thing every
    /// other axis falls back to.
    case shell
    /// The face buttons: the lit ramp and the moulded caps together.
    case buttons
    /// The glass bead above the display.
    case orb
    /// The footer panel's phosphor.
    case marquee
    /// The speaker grille's colour…
    case grilleColor
    /// …and, separately, its pattern. The one axis in the range that is not a
    /// colour, which is why the grille takes two entries here and one row in the
    /// workshop.
    case grilleShape
    /// The LCD's colour scheme — a whole `LcdMode`.
    case screen
    /// The ink the screen draws text in.
    case font

    public var id: String { rawValue }

    /// The `UserDefaults` key this axis is stored under.
    ///
    /// **`shell` and `screen` keep the keys they have always had.** Those two
    /// hold real choices on real installs, and a tidier spelling here would
    /// reset every device in the field back to a black CLASSIC — the same
    /// argument `LocalEntitlementStore.storageKey` makes about `.skins` grants
    /// and `ChassisSkin.displayName` makes about renaming a case. `ChassisSkin`
    /// and `LcdMode` now read their `storageKey` *from here* rather than
    /// restating the literal, so there is one spelling of each and it is this
    /// one.
    ///
    /// The six new keys share a `devicePart` prefix so a defaults dump groups
    /// them, and so `SavedDataReset` can be read and checked at a glance.
    public var storageKey: String {
        switch self {
        case .shell: "chassisSkin"
        case .buttons: "devicePartButtons"
        case .orb: "devicePartOrb"
        case .marquee: "devicePartMarquee"
        case .grilleColor: "devicePartGrille"
        case .grilleShape: "devicePartGrilleShape"
        case .screen: "lcdMode"
        case .font: "devicePartFont"
        }
    }

    /// What the workshop calls this row.
    public var title: String {
        switch self {
        case .shell: "SHELL"
        case .buttons: "BUTTONS"
        case .orb: "ORB"
        case .marquee: "MARQUEE"
        case .grilleColor: "GRILLE"
        case .grilleShape: "GRILLE PATTERN"
        case .screen: "SCREEN"
        case .font: "FONT"
        }
    }

    /// The row's glyph. All SF Symbols 1–2, well under the iOS 17 floor — see
    /// KNOWN-ISSUES on symbols that render blank rather than failing to compile.
    public var symbol: String {
        switch self {
        case .shell: "rectangle.portrait.fill"
        case .buttons: "circle.grid.2x2.fill"
        case .orb: "smallcircle.filled.circle.fill"
        case .marquee: "text.alignleft"
        case .grilleColor: "speaker.wave.2.fill"
        case .grilleShape: "square.grid.3x3.fill"
        case .screen: "display"
        case .font: "textformat"
        }
    }
}

/// Every part selection that makes up one device (0.7.3, B1/B2).
///
/// **Empty means "as the device ships".** Every axis stores a raw string and
/// treats `""` and "no stored value" as the same state — which is the invariant
/// that makes the whole arrangement safe to add to a shipped app. A user who
/// never opens the workshop has eight empty axes and gets a byte-identical
/// device to 0.7.2's: the shell resolves to CLASSIC, the screen to DARK, and the
/// five colour overrides resolve to *whatever the shell says*, which is exactly
/// what the chassis did before this type existed.
///
/// That is also why `shell` and `screen` are not special-cased here even though
/// their emptiness means something different (the default skin, versus "inherit
/// from the skin"). One rule — empty is default — is checkable; two rules with
/// an exception table is the thing that goes wrong on the ninth axis.
///
/// **This is not a second source of truth.** `DeviceBuild` is a *value*: the
/// live device is the eight defaults keys and nothing else, `active(in:)` reads
/// them and `apply(to:)` writes them. A saved `CustomDevice` holds one of these
/// as a recipe, and applying it writes the recipe into the same keys the chassis
/// has always read. There is deliberately no "currently active build id" stored
/// anywhere — see `CustomDeviceStore.matching(_:)`.
///
/// The strings are deliberately untyped here: `ChassisSkin`, `LcdMode`,
/// `PartColor` and `GrilleShape` all live in `VinodexUI` because they resolve to
/// `Color`, which Core cannot see. Core owns the *shape* of a build and the
/// rules about it; UI owns what each string paints.
public struct DeviceBuild: Codable, Hashable, Sendable {
    /// A `ChassisSkin` raw value, or empty for the default shell.
    public var shell: String
    /// A `PartColor` raw value, or empty to follow the shell.
    public var buttons: String
    public var orb: String
    public var marquee: String
    public var grilleColor: String
    /// A `GrilleShape` raw value, or empty for the slats the device ships with.
    public var grilleShape: String
    /// An `LcdMode` raw value, or empty for the default screen.
    public var screen: String
    /// A `PartColor` raw value, or empty to follow the screen mode's own ink.
    public var font: String

    /// The device as it leaves the factory: every axis empty.
    public static let stock = DeviceBuild()

    public init(
        shell: String = "",
        buttons: String = "",
        orb: String = "",
        marquee: String = "",
        grilleColor: String = "",
        grilleShape: String = "",
        screen: String = "",
        font: String = ""
    ) {
        self.shell = shell
        self.buttons = buttons
        self.orb = orb
        self.marquee = marquee
        self.grilleColor = grilleColor
        self.grilleShape = grilleShape
        self.screen = screen
        self.font = font
    }

    /// Read and write an axis by name.
    ///
    /// The workshop draws eight rows that differ only in which axis they set,
    /// and without this each row would carry its own `\.orb` key path — eight
    /// chances to wire a row to the wrong field, none of them visible to a test
    /// because the whole builder is `VinodexUI`. With it the builder is one row
    /// view over `DeviceAxis.allCases`, and `axesRoundTrip` below proves the
    /// mapping.
    ///
    /// Empty is normalised on write, so a caller passing `"  "` cannot create a
    /// third state that is neither set nor unset.
    public subscript(axis: DeviceAxis) -> String {
        get {
            switch axis {
            case .shell: shell
            case .buttons: buttons
            case .orb: orb
            case .marquee: marquee
            case .grilleColor: grilleColor
            case .grilleShape: grilleShape
            case .screen: screen
            case .font: font
            }
        }
        set {
            let value = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            switch axis {
            case .shell: shell = value
            case .buttons: buttons = value
            case .orb: orb = value
            case .marquee: marquee = value
            case .grilleColor: grilleColor = value
            case .grilleShape: grilleShape = value
            case .screen: screen = value
            case .font: font = value
            }
        }
    }

    /// Whether this is the device as it ships.
    public var isStock: Bool { self == .stock }

    /// How many axes have been chosen. The workshop's "3 OF 8 PARTS" readout,
    /// and the thing that tells a saved build apart from an empty one.
    public var chosenCount: Int {
        DeviceAxis.allCases.filter { !self[$0].isEmpty }.count
    }

    // MARK: The live device

    /// The device as it looks right now.
    ///
    /// The eight keys are the source of truth for what the user is holding —
    /// the chassis has read `chassisSkin` since 0.5.x and reads the six new ones
    /// the same way — so this is a *read* of the device rather than a cache of
    /// it. Nothing calls this to decide what to draw; the views read their own
    /// `@AppStorage`, which is what makes a change repaint. This is for the
    /// workshop, which needs the whole build as one value to save, compare and
    /// restore.
    public static func active(in defaults: UserDefaults = .standard) -> DeviceBuild {
        var build = DeviceBuild()
        for axis in DeviceAxis.allCases {
            build[axis] = defaults.string(forKey: axis.storageKey) ?? ""
        }
        return build
    }

    /// Make this the device.
    ///
    /// Removes the key for an empty axis rather than storing `""`, per the
    /// invariant on this type and the same rule `QuickPinStore` and
    /// `StampLayoutStore` follow: an empty stored value and no stored value must
    /// not be two different states, or every reader has to know about both and
    /// `SavedDataReset` has to unwind both.
    public func apply(to defaults: UserDefaults = .standard) {
        for axis in DeviceAxis.allCases {
            let value = self[axis]
            if value.isEmpty {
                defaults.removeObject(forKey: axis.storageKey)
            } else {
                defaults.set(value, forKey: axis.storageKey)
            }
        }
    }
}
