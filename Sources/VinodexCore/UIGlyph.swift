/// The painted UI glyphs (0.8.9a, A2) — `art/icons/chrome/glyphs/` as a type.
///
/// **Why these are a type and the button faces are not.** `import-button-art.py`
/// argues, correctly for its own drop, that there is no roster to check a button
/// face against: "the roster of buttons is whatever the UI puts a button on, and
/// the gate on a missing one is the view that draws nothing". That held while
/// every face was drawn *for* a control that already existed. This drop arrived
/// the other way round — twenty pictures, delivered together, ahead of the
/// screens for most of them — so the interesting question is not "does this
/// control have art" but "does this art have a control", and only a named set
/// can answer it. `unwired` below is that answer, written down rather than
/// inferred from the absence of call sites.
///
/// Raw values are the file stems under `art/icons/chrome/glyphs/`, and
/// `artStem` prefixes them for `PixelArtLoader`'s flat namespace. Nothing
/// persists a `UIGlyph`, so these are display plumbing and free to rename —
/// unlike `ChassisSkin`, whose raw value is simultaneously an `@AppStorage`
/// key, a wear seed and an art stem.
public enum UIGlyph: String, CaseIterable, Sendable {
    case battery
    case bookmark
    case cog
    case firmware
    case gaming
    case hammer
    case heart
    case level1
    case level2
    case level3
    case level4
    case level5
    case mail
    case seal
    case soundsOff = "sounds-off"
    case soundsOn = "sounds-on"
    case stamp
    case star
    case tools
    case trophy

    /// The stem `PixelArtLoader` resolves, prefix included.
    public var artStem: String { "glyph-" + rawValue }

    /// **Drawn, imported, and reaching no screen yet — named, not inferred.**
    ///
    /// The two-way discipline `drawnAheadOutlines` and `undrawnStampStems`
    /// established: a glyph here that acquires a call site has to come out, and
    /// a glyph here with no master on disk means art was deleted. Without the
    /// list, "the screen does not exist yet" and "somebody forgot to wire it"
    /// are the same observation — which is precisely how three silent
    /// missing-asset bugs shipped in three consecutive batches.
    ///
    /// Ten of twenty, and each for one of three reasons:
    ///
    /// - **A sprite cannot serve.** `battery` — `BiosBatteryGlyph` makes its
    ///   fill a function of `UIDevice.batteryLevel`, so a static PNG would have
    ///   to be eleven PNGs. `BootScreen`'s own note already says so; this drop
    ///   does not change the argument.
    /// - **The subject is already drawn, in the register that ships.** `tools`
    ///   (`chrome/buttons/tools.png`, on the SETTINGS grid's TOOLS door),
    ///   `hammer` (`chrome/buttons/workshop.png`, on DEVICE WORKSHOP) and
    ///   `trophy` (the stamp collection is the trophy shelf and its button
    ///   takes `stamp` below). Adopting a second drawing of a live control is a
    ///   look decision, not a wiring one.
    /// - **The screen does not exist.** `bookmark`, `gaming`, `heart`, `mail`,
    ///   `seal`, `star` — favourites, notifications, mini-games and a verified
    ///   seal are all features nothing in the app has yet. The wiring spec
    ///   marks exactly these rows as best-guess and asks for them to be parked
    ///   until their screen exists.
    /// **`level5` came out in 0.8.9b.** It was parked here for one batch with
    /// the note that the fifth shield needed "a threshold, a name and a blurb,
    /// which is content design and not this sub-batch's". It got all three —
    /// the ladder is now APPRENTICE, MASTER, GRANDMASTER, LEGENDARY, WINE MONK —
    /// so `PassportTier.glyph` draws all five shields and the list is one
    /// shorter. That is the move this set was built to make legible: a glyph
    /// leaves by acquiring a call site, not by being deleted from a list.
    ///
    /// Nothing was adopted for this batch's own chrome. The INSIGHT panel takes
    /// an SF Symbol, per the house rule that new UI chrome does — and because
    /// none of the parked candidates depicts the thing: `heart` and `star` read
    /// as favourite, `bookmark` as save, `seal` as verified, and a derived
    /// palate readout is none of those. Adopting one to avoid drawing a new
    /// picture would put the wrong picture on a shipping screen, which is worse
    /// than the list staying long.
    public static let unwired: Set<UIGlyph> = [
        .battery, .bookmark, .gaming, .hammer, .heart,
        .mail, .seal, .star, .tools, .trophy,
    ]
}

/// Professor Vino's six expressions (0.8.9a, A3) — `art/icons/chrome/vino/`.
///
/// Named in Core ahead of the presenter that draws them (0.8.9 phase 2) for the
/// reason `UIGlyph` exists: art with no type is art no roster can check, and the
/// alternative to naming them now is leaving six files in a delivery folder.
///
/// The expression vocabulary is the wiring spec's, one line each:
/// `neutral` is the default talking face, `smiling` is happy, `goodjob` praises
/// an unlock, `raiseaglass` toasts a milestone, `surprised` is a rare find, and
/// `thinking` fronts a hint. Phase 2 maps triggers onto these; this type only
/// promises that each one has a picture.
public enum VinoExpression: String, CaseIterable, Sendable {
    case neutral
    case smiling
    case goodjob
    case raiseaglass
    case surprised
    case thinking

    /// The stem `PixelArtLoader` resolves, prefix included.
    public var artStem: String { "vino-" + rawValue }
}
