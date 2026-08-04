import Foundation

/// One collectible pack (0.7.3, 0.7.3c).
///
/// **The decision this type encodes: packs collect and organise, they do not
/// lock.** The 0.7.3 plan left the choice open — an Atlas Pack could *gate* its
/// countries' entries until owned, or it could be a collectible frame around
/// content that stays free. It is the second, and the reason is not caution: it
/// is that gating would take back things a user has already earned.
///
/// `PassportTier`'s own doc comment argues the invariant in as many words —
/// "a rank you had already earned must not be taken back by a data batch" — and
/// the ladder is absolute counts of *tried* entries. `Passport.compute` resolves
/// the tried shelf against the whole database and divides by
/// `db.databaseStats.grapes`; nothing on that screen consults `AccessStore`. So a
/// pack that removed twenty countries' entries from the catalog until bought
/// would drop the tried count, demote a rank that had been held, empty the
/// ALL NOBLE and REGION COMPLETE badges, and move every denominator on the
/// passport — on a shipped app, for users who had already done the work. That is
/// the regression, and it is decisive on its own.
///
/// **What a pack still is to the entitlement store.** E1 asks for ownership to
/// live in F1's store and it does: `entitlement` is `.expansion(id)`, granted and
/// read exactly like `.skins`. `Entitlement.covers(_:in:)` reads pack membership
/// too, which fills in the honest `false` 0.7.3a shipped — but note what that
/// arm can and cannot do. `AccessStore.isLocked` returns early unless
/// `starterOnly` is set, and `starterOnly` is the *developer* switch, off on
/// every real install. Under it, a pack's countries were already locked (they are
/// not in `tiers.json`'s free list) and owning the pack is a new **key**, never a
/// new lock. There is no configuration of this type in which an entry that was
/// readable becomes unreadable.
///
/// A pack is therefore two independent facts, and the cartridge shows both:
/// whether you *own* it (the store) and how much of it you have *collected* (the
/// tried shelf). The second is the one that moves on a default install.
public struct ExpansionPack: Sendable, Hashable, Identifiable {

    /// Which shelf a cartridge sits on.
    ///
    /// Three kinds rather than one flat list because the three answer different
    /// questions — what is in the catalog, what the device is made of, what the
    /// screen looks like — and the picker this shelf is modelled on already
    /// groups by exactly that kind of distinction.
    public enum Kind: String, Sendable, Hashable, CaseIterable, Identifiable {
        /// Catalog content, grouped by where it comes from (B).
        case atlas = "ATLAS"
        /// A chassis-skin collection (C).
        case device = "DEVICE"
        /// A screen-mode family (D).
        case display = "DISPLAY"

        public var id: String { rawValue }
    }

    /// How a pack decides what belongs to it.
    ///
    /// A rule rather than a list of entry ids, so a data batch that adds a
    /// Brazilian region puts it in the New World pack without anybody editing
    /// this file. The same reasoning `Entitlement.country` already follows.
    public enum Contents: Sendable, Hashable {
        /// Every entry whose `origin` is one of these countries.
        ///
        /// Matched through `TextNormalize.label`, like every other origin
        /// comparison in the app — origins are hand-authored and disagree on
        /// case.
        case countries([String])
        /// Every entry at one rarity.
        case rarity(RarityLabel)
        /// Chassis skins or screen modes.
        ///
        /// Deliberately carries **no count**. The members live in
        /// `ChassisSkinSection` / `LcdModeSection` over in `VinodexUI`, which
        /// this module cannot see, and a number restated here would be a second
        /// source of truth for a fact the UI already computes — the exact defect
        /// F1 spent a batch removing one layer down. The UI counts its own
        /// members; Core owns only the pack's identity.
        case cosmetics
    }

    /// Persisted inside `Entitlement.expansion(id)` as `"pack:" + id`.
    ///
    /// **Load-bearing.** Renaming one silently revokes it on every device that
    /// stored it — the warning `Entitlement` carries about its own spellings
    /// applies here with the same force, because this *is* that spelling.
    public let id: String
    public let kind: Kind
    /// The cartridge label. Display copy; safe to reword.
    public let title: String
    public let blurb: String
    /// SF Symbol printed on the cartridge. All iOS 17-safe — see KNOWN-ISSUES on
    /// symbols with a later floor rendering blank rather than failing to build.
    ///
    /// Not on `DexRoute`'s glyph table, so `ChromeTests.glyphsAreDistinct` does
    /// not police these; a repeat between two cartridges would be a cosmetic
    /// smudge rather than the marquee lying about which page you are on.
    public let symbol: String
    public let contents: Contents

    /// A bundle that already implies this pack, or `nil`.
    ///
    /// **This is what stops the device and display packs revoking anything.**
    /// Every non-default skin has required `Entitlement.skins` since long before
    /// packs existed, and every non-default mode `.lightMode`. Giving each
    /// collection its own gate instead would mean a user who owns `.skins` no
    /// longer owns BURGUNDY — a purchase silently taken back, which is precisely
    /// what `Entitlement`'s note about persisted spellings is warning against one
    /// level down. So `ChassisSkin.requiredEntitlement` is untouched, the six
    /// device cartridges name `.skins` here, the three display cartridges name
    /// `.lightMode`, and owning the old bundle owns the new cartridges. A pack
    /// may additionally be granted on its own; ownership is the union, never the
    /// intersection.
    ///
    /// `nil` for the atlas packs: they are content, and no existing bundle
    /// covers a group of countries.
    public let impliedBy: Entitlement?

    /// The entitlement this pack is bought or unlocked as.
    public var entitlement: Entitlement { .expansion(id) }

    public init(
        id: String,
        kind: Kind,
        title: String,
        blurb: String,
        symbol: String,
        contents: Contents,
        impliedBy: Entitlement? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.blurb = blurb
        self.symbol = symbol
        self.contents = contents
        self.impliedBy = impliedBy
    }

    // MARK: Membership

    /// Every catalog entry in this pack, in database order.
    ///
    /// Empty for the cosmetic packs, which hold no entries at all — the same
    /// shape of answer `Entitlement.covers` gives for `.skins`.
    public func entries(in db: WineDatabase) -> [WineEntry] {
        switch contents {
        case .countries(let names):
            let wanted = Set(
                names.map { TextNormalize.label($0) }.filter { !$0.isEmpty }
            )
            guard !wanted.isEmpty else { return [] }
            return db.entries.filter { entry in
                guard let origin = entry.origin, !origin.isEmpty else { return false }
                return wanted.contains(TextNormalize.label(origin))
            }
        case .rarity(let tier):
            return db.entries.filter { $0.rarity == tier }
        case .cosmetics:
            return []
        }
    }

    /// Whether an entry belongs to this pack.
    ///
    /// The predicate `Entitlement.covers` calls. Written as a membership test on
    /// the entry rather than as `entries(in:).contains(entry)`, because `covers`
    /// runs once per entry per gate and the list form would rebuild the whole
    /// catalog scan each time.
    public func contains(_ entry: WineEntry) -> Bool {
        switch contents {
        case .countries(let names):
            guard let origin = entry.origin, !origin.isEmpty else { return false }
            let key = TextNormalize.label(origin)
            guard !key.isEmpty else { return false }
            return names.contains { TextNormalize.label($0) == key }
        case .rarity(let tier):
            return entry.rarity == tier
        case .cosmetics:
            return false
        }
    }

    /// The pack's entries that can actually be marked tried.
    ///
    /// Grapes and styles, because those are the only two the TRIED button is
    /// offered on ("Tap TRIED on a grape or style you've drunk") and the only two
    /// `Passport.compute` counts. A pack whose denominator included its regions
    /// could never be completed by anybody, which is a collectible that does not
    /// collect.
    public func collectibleEntries(in db: WineDatabase) -> [WineEntry] {
        entries(in: db).filter { $0.category == .grapes || $0.category == .styles }
    }

    /// How much of this pack has been drunk, or `nil` where the question does
    /// not apply — the cosmetic packs, which have nothing to try.
    public func progress(tried: Set<String>, in db: WineDatabase) -> PackProgress? {
        guard case .cosmetics = contents else {
            let members = collectibleEntries(in: db)
            let collected = members.reduce(into: 0) { total, entry in
                if tried.contains(entry.id) { total += 1 }
            }
            return PackProgress(collected: collected, total: members.count)
        }
        return nil
    }
}

/// How far through one pack a user is (0.7.3, 0.7.3c).
public struct PackProgress: Sendable, Hashable {
    public let collected: Int
    public let total: Int

    public init(collected: Int, total: Int) {
        self.collected = collected
        self.total = total
    }

    /// 0…1, and 0 for an empty pack rather than a division by zero.
    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(collected) / Double(total), 0), 1)
    }

    /// An empty pack is **not** complete. Nothing was achieved by it holding
    /// nothing — the same reasoning `Passport`'s REGION COMPLETE badge uses to
    /// refuse regions that name no resolvable grape.
    public var isComplete: Bool { total > 0 && collected >= total }
}

/// The pack catalog (0.7.3, 0.7.3c).
///
/// **In Swift rather than in `shared/`**, unlike almost every other list in this
/// app, and the reason is `id`. A pack id is persisted the moment somebody owns
/// the pack, so it is storage rather than content; `shared/` is edited by data
/// batches and by the `sommelier` agent, and a rename there that looks like
/// tidying prose would silently revoke purchases. The membership *rules* still
/// point at `shared/` — `.countries` names countries the catalog defines — and
/// `ExpansionPackTests` fails if any of them stops resolving, which is the same
/// promise `find-missing-refs.mjs` makes for the data itself.
public enum ExpansionPacks: Sendable {

    // MARK: Atlas (B)

    /// B1. The classical producing countries of Europe and the Caucasus.
    ///
    /// Georgia sits here rather than in the New World for the obvious reason:
    /// it is where wine was first made. The list is the spec's, verbatim.
    public static let oldWorld = ExpansionPack(
        id: "old-world",
        kind: .atlas,
        title: "OLD WORLD",
        blurb: "Europe and the Caucasus, from Bordeaux to Kakheti.",
        symbol: "building.columns.fill",
        contents: .countries([
            "France", "Italy", "Spain", "Portugal", "Germany",
            "Austria", "Greece", "Hungary", "Switzerland", "Georgia",
        ])
    )

    /// B2. The countries wine was carried to.
    ///
    /// Brazil is in this list and was not in the catalog when the list was
    /// written; the country and Serra Gaúcha were added in the same batch,
    /// before this line, so the pack has never referenced anything that did not
    /// exist. `ExpansionPackTests.atlasCountriesResolve` is what keeps that true
    /// for the next country somebody adds here.
    public static let newWorld = ExpansionPack(
        id: "new-world",
        kind: .atlas,
        title: "NEW WORLD",
        blurb: "The Americas, Africa and the Antipodes.",
        symbol: "sailboat.fill",
        contents: .countries([
            "USA", "Canada", "Mexico", "Argentina", "Chile", "Brazil",
            "Uruguay", "South Africa", "Australia", "New Zealand",
        ])
    )

    /// B3. Every grape at the bottom rung of the rarity ladder.
    ///
    /// Defined by rarity rather than by a list of names, so a data batch that
    /// promotes or demotes a variety moves it in and out of the pack on its own.
    /// The rule matches *any* entry at that tier; today only grapes carry
    /// GODFORSAKEN, which `ExpansionPackTests` records rather than assumes — a
    /// godforsaken style would be welcome in here, not a bug.
    ///
    /// An hourglass because that is what the tier means: varieties down to their
    /// last hectares. SF Symbols 1 / iOS 13, well under the floor.
    public static let godforsaken = ExpansionPack(
        id: "godforsaken",
        kind: .atlas,
        title: "GODFORSAKEN",
        blurb: "The rarest tier: varieties hanging on by a few hectares.",
        symbol: "hourglass",
        contents: .rarity(.godforsaken)
    )

    // MARK: Device (C)

    /// C1's six, one per `ChassisSkinSection`.
    ///
    /// **The spec's names are glosses, not the code's spellings.** It asks for
    /// "Transparent (clear tech)", "Retro Tech (retrofit)" and "Seasonal
    /// (festive)"; the sections have been CLEARTECH, RETROFIT and FESTIVE since
    /// 0.7.0 and those headings are already on screen in the CHASSIS SKINS
    /// picker. A cartridge whose name disagreed with the heading over the same
    /// three skins would read as two different groupings, so the cartridges take
    /// the picker's words. The parenthesised halves of the spec's names are in
    /// fact the code spellings, which reads as the spec glossing them rather than
    /// renaming them.
    public static let classicDevices = devicePack(
        id: "device-classic", title: "CLASSIC",
        blurb: "The house device and the two shells that vary it.",
        symbol: "gamecontroller.fill"
    )
    public static let wineDevices = devicePack(
        id: "device-wines", title: "WINES",
        blurb: "Shells named for what is in the glass.",
        symbol: "wineglass.fill"
    )
    public static let vesselDevices = devicePack(
        id: "device-vessel", title: "VESSEL",
        blurb: "Cask, tank and bottle — what the wine is kept in.",
        symbol: "cylinder.fill"
    )
    public static let retrofitDevices = devicePack(
        id: "device-retrofit", title: "RETROFIT",
        blurb: "The consumer-hardware homages. Never anybody's mark.",
        symbol: "radio.fill"
    )
    public static let clearTechDevices = devicePack(
        id: "device-cleartech", title: "CLEARTECH",
        blurb: "Translucent shells with the internals showing through.",
        symbol: "cube.transparent"
    )
    public static let festiveDevices = devicePack(
        id: "device-festive", title: "FESTIVE",
        blurb: "Seasonal in theme only. They never go away.",
        symbol: "gift.fill"
    )

    // MARK: Display (D)

    /// D1's three, one per `LcdModeSection`.
    ///
    /// **D1 spells the middle one "Vintage" and the code does not.** 0.7.1's C1
    /// renamed that section to RETRO precisely because a group called VINTAGE
    /// containing a mode called VINTAGE made the heading look like a mislabelled
    /// tile, and `LcdMode.vintage` — which is persisted — kept its own name. The
    /// cartridge follows the current heading; taking the spec's word literally
    /// would reintroduce the collision C1 removed.
    public static let classicDisplays = displayPack(
        id: "display-classic", title: "CLASSIC",
        blurb: "Light and dark. No conceit beyond that.",
        symbol: "circle.lefthalf.filled"
    )
    public static let retroDisplays = displayPack(
        id: "display-retro", title: "RETRO",
        blurb: "Phosphor and reflective LCD, monochrome by construction.",
        symbol: "tv.fill"
    )
    public static let emulatorDisplays = displayPack(
        id: "display-emulator", title: "EMULATOR",
        blurb: "Modes that quote one specific machine's screen.",
        symbol: "desktopcomputer"
    )

    // MARK: The shelves

    public static let atlas: [ExpansionPack] = [oldWorld, newWorld, godforsaken]

    public static let device: [ExpansionPack] = [
        classicDevices, wineDevices, vesselDevices,
        retrofitDevices, clearTechDevices, festiveDevices,
    ]

    public static let display: [ExpansionPack] = [
        classicDisplays, retroDisplays, emulatorDisplays,
    ]

    /// Every pack, in shelf order.
    public static let all: [ExpansionPack] = atlas + device + display

    /// The packs on one shelf.
    public static func packs(of kind: ExpansionPack.Kind) -> [ExpansionPack] {
        switch kind {
        case .atlas: atlas
        case .device: device
        case .display: display
        }
    }

    /// The pack an `Entitlement.expansion` id names, if any.
    ///
    /// `nil` for an id no build knows — a grant stored by a later version and
    /// read back by an earlier one, which must degrade to "covers nothing"
    /// rather than to a crash.
    public static func pack(id: String) -> ExpansionPack? {
        all.first { $0.id == id }
    }

    // MARK: Construction helpers

    /// Both helpers exist to keep `impliedBy` from being written out nine times.
    /// It is the one field on a cosmetic pack that must not vary, and nine
    /// hand-written copies of it is nine chances to give one collection a gate
    /// of its own — which is the revocation `ExpansionPack.impliedBy` documents.
    private static func devicePack(
        id: String, title: String, blurb: String, symbol: String
    ) -> ExpansionPack {
        ExpansionPack(
            id: id, kind: .device, title: title, blurb: blurb,
            symbol: symbol, contents: .cosmetics, impliedBy: .skins
        )
    }

    private static func displayPack(
        id: String, title: String, blurb: String, symbol: String
    ) -> ExpansionPack {
        ExpansionPack(
            id: id, kind: .display, title: title, blurb: blurb,
            symbol: symbol, contents: .cosmetics, impliedBy: .lightMode
        )
    }
}
