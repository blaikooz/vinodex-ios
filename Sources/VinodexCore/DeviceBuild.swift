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
/// **Ten axes since 0.7.6 (B1)**, which adds the two lamp groups. Nothing about
/// the shape changed to take them — a new part is a case, a key, a title, a glyph
/// and an arm of the subscript, and the workshop grows a row without being
/// edited. That the eighth and ninth additions cost exactly that is the whole
/// return on 0.7.3b having built this.
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
    /// The three coloured lamps beside the cutout (0.7.6, B1).
    ///
    /// **New, and genuinely new** — unlike the six axes 0.7.3b prised out of
    /// `ChassisSkin`, this trio was not settable in any form: `statusDots` read
    /// `skin.statusLights` and that was the whole of it. B1 names it "header
    /// colored-lights colour", which is the row above the display; the two lamps
    /// *below* it are their own axis, because A1 has just made those two buttons
    /// and a button and a decoration should not be forced to share a colour.
    case headerLamps
    /// The footer panel's phosphor.
    case marquee
    /// The two lamps over the marquee — the pin buttons (0.7.6, B1).
    ///
    /// Split from `headerLamps` for the reason above and from `buttons` for a
    /// different one: these are lamps, drawn with `RecessedLamp` off a
    /// lamp-shaped trio, where `buttons` is four moulded caps built from a
    /// six-stop lit ramp. They were the *same* colours until this batch —
    /// `indicatorPills` took `statusLights[0]` and `[2]`, the outer two of the
    /// trio upstairs — which is precisely why they need separating: a player who
    /// recolours the header lights should not silently repaint two buttons at the
    /// other end of the device.
    ///
    /// **This axis is the lamps' colour and nothing else.** Where each lamp
    /// *goes* is `QuickPinStore`, which is a different question with a different
    /// storage key; A1 and B1 land in the same batch and must not be allowed to
    /// become one setting.
    case marqueeLamps
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
    /// The eight added keys share a `devicePart` prefix so a defaults dump groups
    /// them, and so `SavedDataReset` can be read and checked at a glance.
    public var storageKey: String {
        switch self {
        case .shell: "chassisSkin"
        case .buttons: "devicePartButtons"
        case .orb: "devicePartOrb"
        case .headerLamps: "devicePartHeaderLamps"
        case .marquee: "devicePartMarquee"
        case .marqueeLamps: "devicePartMarqueeLamps"
        case .grilleColor: "devicePartGrille"
        case .grilleShape: "devicePartGrilleShape"
        case .screen: "lcdMode"
        case .font: "devicePartFont"
        }
    }

    /// What the workshop calls this row.
    ///
    /// **BUTTONS became FOOTER BUTTONS in 0.7.6 (B1)**, and it is a rename with a
    /// point rather than a tidy-up. B1 asks for three additions and names one of
    /// them "footer button colour" — which has been settable since 0.7.3b, under
    /// a heading so general that reading the workshop's own row list does not tell
    /// you so. Two of the three are genuinely new (`headerLamps`, `marqueeLamps`)
    /// and the third was there all along; saying *which* buttons is what makes
    /// that visible on the screen where it matters. Labels are free to move — it
    /// is `storageKey` that is persisted, not this.
    public var title: String {
        switch self {
        case .shell: "SHELL"
        case .buttons: "FOOTER BUTTONS"
        case .orb: "ORB"
        case .headerLamps: "HEADER LIGHTS"
        case .marquee: "MARQUEE"
        case .marqueeLamps: "MARQUEE LIGHTS"
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
        // A bulb for the lamps that only ever light, and the pill's own outline
        // for the two that are buttons — the shapes on the device, which is what
        // distinguishes the two lamp rows at a glance in a ten-row list. Both SF
        // Symbols 1 / iOS 13. `axesAreDistinct` gates the collisions.
        case .headerLamps: "lightbulb.fill"
        case .marquee: "text.alignleft"
        case .marqueeLamps: "capsule.fill"
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
/// never opens the workshop has ten empty axes and gets a byte-identical
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
/// live device is the ten defaults keys and nothing else, `active(in:)` reads
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
    /// A `PartColor` raw value for the island trio, or empty to follow the shell
    /// (0.7.6, B1).
    public var headerLamps: String
    public var marquee: String
    /// A `PartColor` raw value for the two marquee lamps, or empty to follow the
    /// shell (0.7.6, B1).
    public var marqueeLamps: String
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
        headerLamps: String = "",
        marquee: String = "",
        marqueeLamps: String = "",
        grilleColor: String = "",
        grilleShape: String = "",
        screen: String = "",
        font: String = ""
    ) {
        self.shell = shell
        self.buttons = buttons
        self.orb = orb
        self.headerLamps = headerLamps
        self.marquee = marquee
        self.marqueeLamps = marqueeLamps
        self.grilleColor = grilleColor
        self.grilleShape = grilleShape
        self.screen = screen
        self.font = font
    }

    // MARK: Coding

    private enum CodingKeys: String, CodingKey {
        case shell, buttons, orb, headerLamps, marquee, marqueeLamps
        case grilleColor, grilleShape, screen, font
    }

    /// **Hand-written, and it has to be** (0.7.6, B1).
    ///
    /// A `CustomDevice` stores one of these as JSON under `customDevices`, and the
    /// synthesised decoder throws on a key it does not find. So the two axes this
    /// batch adds would have made every build saved under 0.7.3b–0.7.5 fail to
    /// decode — and `CustomDeviceStore`'s `try?` would have swallowed the failure
    /// and returned an *empty list*, silently deleting every saved device on
    /// first launch of the update. That is a data loss nothing in this project
    /// would have reported: the store's own defensive `sanitize` never runs,
    /// because there is nothing left to sanitise.
    ///
    /// Every field is therefore `decodeIfPresent`, defaulting to `""` — which is
    /// the type's own "as the device ships" state, so an old build decodes to
    /// exactly the device it described plus two axes nobody had chosen. It is
    /// written for *all ten* rather than only the two new ones, so an eleventh
    /// axis is free rather than being the next release's version of this note.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func read(_ key: CodingKeys) -> String {
            ((try? container.decodeIfPresent(String.self, forKey: key)) ?? nil) ?? ""
        }
        self.init(
            shell: read(.shell),
            buttons: read(.buttons),
            orb: read(.orb),
            headerLamps: read(.headerLamps),
            marquee: read(.marquee),
            marqueeLamps: read(.marqueeLamps),
            grilleColor: read(.grilleColor),
            grilleShape: read(.grilleShape),
            screen: read(.screen),
            font: read(.font)
        )
    }

    /// Read and write an axis by name.
    ///
    /// The workshop draws ten rows that differ only in which axis they set,
    /// and without this each row would carry its own `\.orb` key path — ten
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
            case .headerLamps: headerLamps
            case .marquee: marquee
            case .marqueeLamps: marqueeLamps
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
            case .headerLamps: headerLamps = value
            case .marquee: marquee = value
            case .marqueeLamps: marqueeLamps = value
            case .grilleColor: grilleColor = value
            case .grilleShape: grilleShape = value
            case .screen: screen = value
            case .font: font = value
            }
        }
    }

    /// Whether this is the device as it ships.
    public var isStock: Bool { self == .stock }

    /// How many axes have been chosen. The workshop's "3 OF 10 PARTS" readout,
    /// and the thing that tells a saved build apart from an empty one. Ten since
    /// 0.7.6 (B1); the readout counts `DeviceAxis.allCases` rather than a literal,
    /// so it moved on its own.
    public var chosenCount: Int {
        DeviceAxis.allCases.filter { !self[$0].isEmpty }.count
    }

    // MARK: The live device

    /// The device as it looks right now.
    ///
    /// The ten keys are the source of truth for what the user is holding —
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
