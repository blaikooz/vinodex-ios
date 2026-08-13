import Foundation

/// A heading in the chassis-skin picker (0.7.0, B2).
///
/// Twenty-two shells in one flat grid is a swatch book, not a range. These six
/// headings are the six *arguments* the range actually makes: the house
/// colourways, the ones named for a wine's colour, the ones named for what wine
/// is kept in, the ones quoting consumer hardware, the see-through ones, and the
/// seasonal ones.
///
/// `allCases` order is picker order. Membership is not declared here — see
/// `ChassisSkin.section`.
///
/// Declared in Core beside `LcdModeSection`, and for its reason (arch **A6**): a
/// picker heading is a raw string and a *rule* about `ChassisSkin.allCases`,
/// with no `Color` in it anywhere, which is exactly the kind of claim that wants
/// asserting from `swift test` and cannot be asserted about anything in
/// VinodexUI. What reads it — the grouped picker in `SettingsPanel`, the
/// cartridge join in `Sources/VinodexUI/ExpansionPackMembers.swift` — is still
/// UI, which is the arrangement A6 asks for.
public enum ChassisSkinSection: String, CaseIterable, Identifiable, Sendable {
    /// The house device and the two shells that are variations on it.
    case classic = "CLASSIC"
    /// Named for what is in the glass.
    case wines = "WINES"
    /// Named for what the wine is kept in — cask, tank, bottle.
    case vessel = "VESSEL"
    /// The consumer-hardware homages. Never anybody's mark — see `drawnMark`.
    case retrofit = "RETROFIT"
    /// The translucent shells, mock internals showing through.
    case clearTech = "CLEARTECH"
    /// Seasonal in theme only. A skin that vanished in January would read as a
    /// bug, not as a gift — see `.christmas`.
    case festive = "FESTIVE"

    public var id: String { rawValue }

    /// The skins under this heading, in `ChassisSkin.allCases` order.
    ///
    /// Derived rather than declared, so the six sections are provably a
    /// partition of `allCases`: no skin can be dropped from the picker by being
    /// left off a list, and none can appear twice.
    public var skins: [ChassisSkin] { ChassisSkin.allCases.filter { $0.section == self } }
}

/// Chassis colourway. The LCD itself never changes — only the moulding around
/// it — so a skin swap cannot affect legibility of the content.
///
/// Moved here from VinodexUI by arch **A6**, with only the persisted half: the
/// raw values, the storage key, the label, the picker heading and the emblem.
/// Every colour this skin wears — `body`, `panel`, `orb`, `accent`, `control`,
/// `buttonSet`, `backPlate`, `sketch`, the marquee phosphor and the status
/// lamps — is still declared in `Sources/VinodexUI/Chassis/ChassisSkins.swift`,
/// now as an extension. See the note at the top of `ScreenMode.swift` for why
/// the split falls there.
///
/// A skin used to be four greys and a body colour: swap it and you got the same
/// cyan orb, the same amber Home button and the same green marquee in a
/// different-coloured tray. The moulding changed and none of the *parts* did,
/// which is why four of the five read as recolours of one device rather than as
/// five devices. Each now carries its own orb, its own lit-button ramp and its
/// own marquee phosphor.
///
/// **Vinodex Classic is deliberately untouched** — every value for `.classic`
/// is what the whole chassis used before this existed. It is the house device
/// and the reference the others are variations on; changing it would move the
/// baseline rather than add to it.
public enum ChassisSkin: String, CaseIterable, Identifiable, Sendable {
    case classic = "CLASSIC"
    case midnight = "MIDNIGHT"
    /// The original grey-and-white shell rather than the red one.
    case original = "ORIGINAL"
    /// Velvet purple.
    case burgundy = "BURGUNDY"
    /// Vintage Walkman yellow.
    case riesling = "RIESLING"
    /// Forest-green DMG homage: pea-green screen tint, grey/black buttons,
    /// dark brown accents.
    case vinhoVerde = "VINHO VERDE"
    /// The clear-technology shell — translucent smoke plastic over mock
    /// internals, with bright orange for everything powered.
    case glouglou = "GLOUGLOU"
    /// The iPhone calculator's livery: near-black shell, warm dark-grey keys
    /// with a brown cast, and calculator-orange for everything powered.
    case smartGrape = "SMART GRAPE"
    /// Pale champagne-gold shell with gold-leaf powered parts — elegant, not
    /// garish; the dressing-table of the range.
    case champagne = "CHAMPAGNE"
    /// Pine shell, snow panel, red caps and gold lights. Seasonal in theme
    /// only — a skin that vanished in January would read as a bug, not a gift.
    case christmas = "CHRISTMAS"
    /// Atomic-purple clear shell — the second translucent colourway. Grape-
    /// juice gloss for everything powered, the guts faintly visible through it.
    case nouveau = "NOUVEAU"
    /// Walnut woodgrain deck, cream faceplate, brass for the powered parts.
    case oaked = "OAKED"
    /// Glow-in-the-dark pale luminous green with a softly glowing rim.
    case nocturne = "NOCTURNE"
    /// Brushed aluminium: mirror highlights, crisp dark seams.
    case steel = "STEEL"
    /// Rose-pink shell with a pale blush faceplate and pearl-pink lights —
    /// unapologetically pink and girly (v0.6, D1).
    case blush = "BLUSH"
    /// The DualShock 2 livery (0.6.5, item 9): matte charcoal moulding, a
    /// darker console-grey faceplate, and the four face-button colours doing
    /// all the talking — lights run triangle/circle/cross, the powered parts
    /// run the cross's blue. Subtle on purpose; the reference hardware was.
    case psvino = "PSVINO"
    /// The original handheld brick (0.6.7, J1): warm grey moulding with red
    /// face buttons, the pea-green screen surviving only as the marquee's
    /// phosphor.
    ///
    /// Named for the wine, not the console — `gris de gris` is a real style
    /// (pale grey-pink rosé pressed from Gris grapes), and "grey shell, red
    /// buttons" is the same sentence. The house has done this twice before:
    /// the forest-green DMG homage ships as BOX WINE and the calculator livery
    /// as FIELD BLEND. Naming a skin after someone else's hardware is the one
    /// thing this range does not do.
    case grisDeGris = "GRIS DE GRIS"
    /// Warning-orange moulding with black buttons (0.6.7, J2) — hazard livery,
    /// and the only skin in the range whose powered parts are *darker* than its
    /// shell.
    ///
    /// Orange wine is a real category (skin-contact white), which makes it the
    /// obvious name for the one orange device.
    case orangeWine = "ORANGE WINE"
    /// **The hand-drawn shell** (0.6.9, M1): cartridge paper with a fibre
    /// tooth, every rim inked by hand, and a blue-black pen doing all the work
    /// the other skins give to a colour ramp. See `sketch`.
    ///
    /// Named for the wine whose bottles look like this. Pét-nat is a real style
    /// — méthode ancestrale, bottled before the first fermentation finishes —
    /// and the hand-drawn label is so nearly universal on it that it is the
    /// category's visual signature. The house rule holds: a wine name, not a
    /// description, and nobody else's mark. The rawValue is ASCII on purpose
    /// (it persists); the accent lives in `displayName`, exactly as GRUNER BOY
    /// does.
    case petNat = "PET NAT"
    /// **Forest glass** (0.7.0, B2) — the green translucent shell, and the only
    /// skin in the range whose reference is older than electricity.
    ///
    /// *Waldglas* is genuine: the potash glass blown in the German and Bohemian
    /// forests from the middle ages on, coloured a pale olive-green by the iron
    /// in the wood ash that fluxed it. Bottle green is not a design choice, it is
    /// what glass does when nobody decolourises it — which makes this the most
    /// literal possible reading of "clear plastic shell" and lands it squarely in
    /// CLEARTECH beside EMPTY BOTTLE and RETROVIN.
    ///
    /// The house naming rule holds without straining: a real glass name, not a
    /// description, and nobody's mark.
    case waldglas = "WALDGLAS"
    /// **Black and orange** (0.7.0, B2) — the one skin in the range that is a
    /// night rather than a wine or a material.
    ///
    /// Seasonal in theme only, exactly as WINE XMAS is: it is always available,
    /// because a skin that appeared for a fortnight in October and then vanished
    /// would read as a bug. It carries the range's only per-skin *control* glyph
    /// — the user button is a drawn pumpkin, see `userMark`.
    case halloween = "HALLOWEEN"
    /// **The purple deck** (0.7.6, D1) — a violet shell with four face-button
    /// colours doing all the talking, in the manner of the mid-nineties consoles
    /// that made a coloured moulded brick a mainstream object.
    ///
    /// **Inspired-by only, and the boundary is drawn where the house has always
    /// drawn it.** `buttonSet`'s own note has said since 0.6.7 (K2/K3) that a
    /// console livery takes *colours* and nothing else: the glyphs stay Vinodex's
    /// own chevron, house, person and cog, no silhouette is reproduced, and no
    /// mark of anybody's appears anywhere on the device or in this file. That is
    /// the same discipline the bouncing-mark screensaver was built under — see
    /// `VinodexV`, drawn from scratch precisely so the most-looked-at thing on an
    /// idle screen is unambiguously ours.
    ///
    /// **The rawValue is three separate commitments and was chosen once,
    /// carefully.** It is the `chassisSkin` `@AppStorage` value, the FNV-1a seed
    /// `WornSeed.of(skin.rawValue)` draws the back plate's procedural wear
    /// from, and the stem `stickerStem` derives (`sticker-w64`). Moving it later
    /// resets the shell, repaints the wear on the devices that survive, and
    /// orphans the sticker — the three costs FIBERGLASS's and HALLOWINE's rename
    /// notes were written up to avoid. It is ASCII, and it collides with nothing
    /// in `shared/`, the generated JSON or the art scripts. It was the label as
    /// well until 0.9.2, when the label moved to 1964 (trademark hygiene, per
    /// the `displayName` note) and this rawValue stayed exactly where every
    /// rename note in this file says a rawValue stays.
    case w64 = "W64"

    /// Derived, not restated — the literal is `"chassisSkin"` and it is written
    /// down once, in `SavedDataKey` (AUDIT **M35**), because that registry is
    /// what `SavedDataArchiver` switches over to build an export.
    ///
    /// 0.7.3's B1 makes the same argument from the other end and points at
    /// `DeviceAxis.shell.storageKey`: the key holds real choices on real
    /// installs, so a tidier spelling anywhere would reset every device in the
    /// field back to the default shell — and the workshop needs the same key
    /// from a file that cannot see this enum. Both registries need it for their
    /// own reason — M35 to *enumerate* it, `DeviceBuild` to read and write it
    /// beside nine others — and `SavedDataArchiveTests` and `DeviceWorkshopTests`
    /// each pin their side to the same string, so the two cannot drift apart in
    /// silence. `LcdMode.storageKey` resolves the same way for the same pair of
    /// reasons.
    public static let storageKey = SavedDataKey.chassisSkin.rawValue

    public var id: String { rawValue }

    /// Which heading this skin sits under in the picker (0.7.0, B2).
    ///
    /// An exhaustive switch, for `LcdMode.section`'s reason: written the other
    /// way round — six declared lists of skins — a skin could be left off every
    /// list and would simply stop appearing in the picker, with nothing failing
    /// to say so. This way the compiler refuses to build a skin with no home.
    ///
    /// Note that several skins sit under a heading their *case name* does not
    /// suggest, because the case name is the persisted raw value and the label
    /// has moved since: `.nocturne` is VINHO VERDE, `.vinhoVerde` is BOX WINE,
    /// `.riesling` is VIN JAUNE, `.nouveau` is RETROVIN, `.glouglou` is EMPTY
    /// BOTTLE. Read `displayName` before moving anything here.
    public var section: ChassisSkinSection {
        switch self {
        case .classic, .midnight, .original: .classic
        case .burgundy, .nocturne, .champagne: .wines
        case .oaked, .steel, .petNat: .vessel
        case .vinhoVerde, .psvino, .grisDeGris, .riesling, .smartGrape, .orangeWine, .w64: .retrofit
        case .glouglou, .nouveau, .waldglas: .clearTech
        case .christmas, .blush, .halloween: .festive
        }
    }

    /// Whether the shell is see-through — `DeviceChassis`'s cue to mount the
    /// mock internals behind it. A flag rather than sniffing alpha out of a
    /// `Color`, which SwiftUI does not expose anyway.
    public var isTranslucent: Bool {
        self == .glouglou || self == .nouveau || self == .waldglas
    }

    /// What the picker calls this skin.
    ///
    /// Deliberately separate from `rawValue`: the raw value is the persisted
    /// key, so renaming ORIGINAL to "Blanc de Blancs" by editing the case would
    /// silently reset every device already storing "ORIGINAL" back to the
    /// default shell. The stored vocabulary stays put and only the label moves.
    public var displayName: String {
        switch self {
        // The house colourway, named for the house rather than described as
        // "classic" — every other skin here has a wine name, and the default
        // was the only one still labelled by category.
        case .classic: "VINODEX CLASSIC"
        case .midnight: "CÔTE DE NUITS"
        case .original: "BLANC DE BLANCS"
        case .burgundy: "BURGUNDY"
        // Renamed from ELECTRIC RIESLING (0.6.x) — label only, per the note
        // above; the yellow Walkman shell suits Jura's yellow wine as well.
        case .riesling: "VIN JAUNE"
        // Renamed labels only — the raw values are the persisted vocabulary
        // and stay put, per the note above. "VINHO VERDE" moved houses in
        // two steps: the forest-green skin became BOX WINE in 0.5.1, which
        // freed the name for the glow-green skin in 0.5.4.
        case .vinhoVerde: "BOX WINE"
        case .glouglou: "EMPTY BOTTLE"
        // SMART GRAPE → FIELD BLEND (0.9.2, item 1). Label only, per the note
        // above — the rawValue "SMART GRAPE" is the stored key, the WornSeed
        // input and the sticker stem (`sticker-smart-grape`), and all three
        // stay put. The old label read as a riff on a phone brand; a field
        // blend is a real wine (many varieties grown and vinified together),
        // which puts this back on the house rule: a wine name, nobody's mark.
        case .smartGrape: "FIELD BLEND"
        case .champagne: "CHAMPAGNE GOLD"
        case .christmas: "WINE XMAS"
        // Renamed from NOUVEAU (v0.5.9, A1) — label only, per the note above.
        case .nouveau: "RETROVIN"
        case .oaked: "OAKED"
        case .nocturne: "VINHO VERDE"
        case .steel: "STAINLESS STEEL"
        case .blush: "BLUSH"
        // PSVINO → PX (0.9.2, item 1). Label only, per the note above — the
        // rawValue "PSVINO" is the stored key, the WornSeed input and the
        // sticker stem (`sticker-psvino`), and renaming any of those revokes
        // real state, so they stay. The old label kept a console's initials in
        // it; PX is Pedro Ximénez, the sherry grape — dark as this shell, and
        // a wine name per the house rule.
        case .psvino: "PX"
        case .grisDeGris: "GRIS DE GRIS"
        case .orangeWine: "ORANGE WINE"
        // PÉT-NAT → FIBERGLASS (0.7.5, A4). Label only, per the note above,
        // and the note is load-bearing on this case in particular: the rawValue
        // `"PET NAT"` is the `chassisSkin` stored value on every install
        // wearing this shell, the FNV-1a seed `WornSeed.of(skin.rawValue)`
        // draws the back plate's procedural wear from, and the stem
        // `stickerStem` derives (`sticker-pet-nat`). Moving it would reset the
        // shell, repaint the wear on the devices that survived, and orphan the
        // sticker — the exact three costs HALLOWINE's rename was written up to
        // avoid. Checked rather than assumed: `"PET NAT"` appears nowhere in
        // `shared/`, the generated JSON or the art scripts. (The `petnat`
        // hits in `icons.json` and `art/icons/entries/styles/` are the *wine style*
        // Pétillant Naturel and have nothing to do with this skin.)
        case .petNat: "FIBERGLASS"
        case .waldglas: "WALDGLAS"
        // HALLOWEEN → HALLOWINE (0.7.1, C4). Label only — the rawValue is the
        // stored key *and* the seed for the back plate's procedural wear
        // (see `WornSeed.of`), so moving it would both reset every device
        // wearing this shell and repaint the ones that survived.
        case .halloween: "HALLOWINE"
        // W64 → 1964 (0.9.2, item 1). 0.7.6 (D1) chose "W64" precisely so the
        // label could restate the rawValue forever; the label still leaned on
        // a console's numerals, so it drifts after all — label only, per the
        // note above. The rawValue "W64" is the stored key, the WornSeed input
        // and the sticker stem (`sticker-w64`), and all three stay put. 1964
        // is just a vintage year — nobody's mark, and the four-colour deck
        // reads as mid-sixties pop besides.
        case .w64: "1964"
        }
    }

    /// A tileable pixel-art pattern drawn over the shell colour, or nil for a
    /// plain moulding. WINE XMAS wraps the chassis in wrapping paper, OAKED
    /// in walnut grain, STEEL in brushed aluminium; the pattern sits under
    /// the panel and footer wash like any other body.
    ///
    /// Read from both faces since 0.7.0 (F1): `ChassisSkin.backPlate` resolves
    /// its finish through this rather than declaring a second table, so a walnut
    /// device is walnut front and back or it is two devices.
    public var bodyPatternAsset: String? {
        switch self {
        case .christmas: "xmas-wrap"
        case .oaked: "oak-grain"
        case .steel: "steel-brush"
        default: nil
        }
    }

    /// Emblem glyph — the picker tile carries it the way screen-mode tiles
    /// carry theirs, and the back plate wears it as an enamel badge.
    ///
    /// For two skins this is only the *fallback*: their emblem is a drawing.
    /// See `drawnMark`, and `SkinMarkView` for what resolves the pair.
    public var symbol: String {
        switch self {
        case .classic: "gamecontroller.fill"
        case .midnight: "moon.fill"
        case .original: "sparkles"
        case .burgundy: "diamond.fill"
        case .riesling: "bolt.fill"
        case .vinhoVerde: "shippingbox.fill"
        case .glouglou: "wineglass.empty"
        case .smartGrape: "plus.forwardslash.minus"
        case .champagne: "party.popper.fill"
        case .christmas: "gift.fill"
        case .nouveau: "cpu.fill"
        case .oaked: "tree.fill"
        case .nocturne: "moon.zzz.fill"
        case .steel: "gearshape.2.fill"
        case .blush: "heart.fill"
        // The console emblem is gone (0.6.7, K1) — see `drawnMark`. This is
        // only the fallback for anything that still wants a plain symbol.
        case .psvino: "seal.fill"
        // The brick's own control: a d-pad.
        case .grisDeGris: "dpad.fill"
        case .orangeWine: "exclamationmark.triangle.fill"
        // The pen that drew the shell.
        case .petNat: "pencil.and.outline"
        // Forest glass, named for the woods it was blown in.
        case .waldglas: "leaf.circle.fill"
        // The neutral fallback only. This skin's emblem is a drawing —
        // SF Symbols has no pumpkin at the iOS 17 floor. See `drawnMark`.
        case .halloween: "moon.haze.fill"
        // Four coloured points around a centre: what this livery *is*, taken
        // from the house's own symbol set rather than quoted from anyone's
        // hardware. SF Symbols 2 / iOS 14, well under the floor, and it
        // collides with nothing — `circle.grid.2x2.fill` is a workshop axis
        // glyph and `circle.grid.3x3.fill` is GRAPES.
        case .w64: "circle.grid.cross.fill"
        }
    }

    // `next` retired in 0.7.6 (A1), with `LcdMode.next` and `ChassisLook.next`
    // beside it — see the note where `LcdMode.next` was, in `ScreenMode.swift`.
    // All three existed for one caller, the marquee drawer's NEXT SKIN and NEXT
    // SCREEN tiles (0.7.1, B5), and the Decision retires the drawer. Both
    // pickers still choose either axis directly.

    /// Via `SettingsCache`, like `LcdMode.current` — see the note there.
    public static var current: ChassisSkin {
        ChassisSkin(rawValue: SettingsCache.string(forKey: storageKey) ?? "")
            ?? SettingsDefault.chassisSkin
    }

    /// The injected-store form — see `UIScale.current(in:)`.
    public static func current(in defaults: UserDefaults) -> ChassisSkin {
        ChassisSkin(rawValue: defaults.string(forKey: storageKey) ?? "")
            ?? SettingsDefault.chassisSkin
    }
}
