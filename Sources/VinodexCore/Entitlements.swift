import Foundation

/// One purchasable thing.
///
/// The paywall used to be a single boolean: free tier, or everything. That is
/// one edge case out of many, and it made the interesting states untestable —
/// there was no way to see what the app looks like to someone who bought the
/// flavour wheel but not the atlas, or who owns one country and nothing else.
///
/// Bundles are identified by a **string** rather than by case alone so a
/// country bundle can name its country. `id` is what gets persisted, so the
/// spellings here are load-bearing: renaming one silently revokes it on every
/// device that already stored it.
public enum Entitlement: Hashable, Sendable {
    /// Everything, forever. Supersedes every other bundle.
    case pro
    /// Every grape and region belonging to one country.
    case country(String)
    /// The whole flavour wheel.
    case flavors
    /// Chassis skins beyond the default.
    case skins
    /// The light LCD mode.
    case lightMode
    /// One expansion pack of catalog content (0.7.3, F1 — for 0.7.3c).
    ///
    /// Named by pack id rather than by case for the same reason `country` is:
    /// packs are content, content ships on its own schedule, and an enum case
    /// per pack would mean a Swift change for every one.
    case expansion(String)
    /// The premium workshop (0.7.3, F1 — for 0.7.3b).
    case workshop
    /// The interactive pedigree graph (0.7.5, E1).
    ///
    /// A case of its own rather than a fold into `.pro`, for the reason
    /// `.workshop` is one: E1 asks for a premium *feature*, and the shop can
    /// only sell what the entitlement set can name. It behaves like `.workshop`
    /// throughout — it gates a door, covers no entry, and `.pro` supersedes it.
    ///
    /// Note what it does **not** gate: the lineage *data* travels on every grape
    /// entry and costs nothing to read, exactly as the workshop's eight axes
    /// exist for everyone. What is bought is the screen that draws it.
    case lineage
    /// One hidden feature, unlocked rather than bought (0.7.3, F1).
    ///
    /// The odd one out: nothing about an easter egg is for sale, and it is here
    /// anyway because F1 is explicit that ownership is *one* question. An egg
    /// unlocked by a cheat code and a bundle unlocked by a purchase are the same
    /// question asked of the same store — a second store for "things you have
    /// but did not pay for" is precisely the parallel store F1 forbids.
    case easterEgg(String)

    public var id: String {
        switch self {
        case .pro: "pro"
        case .country(let name): "country:" + name
        case .flavors: "flavors"
        case .skins: "skins"
        case .lightMode: "lightMode"
        case .expansion(let pack): "pack:" + pack
        case .workshop: "workshop"
        case .lineage: "lineage"
        case .easterEgg(let egg): "egg:" + egg
        }
    }

    public init?(id: String) {
        switch id {
        case "pro": self = .pro
        case "flavors": self = .flavors
        case "skins": self = .skins
        case "lightMode": self = .lightMode
        case "workshop": self = .workshop
        case "lineage": self = .lineage
        default:
            // The namespaced forms. A table rather than a chain of `hasPrefix`
            // guards because there are three of them now and a fourth would
            // have been another copy-paste of the empty-name check below —
            // which is the one part of this that is easy to forget and silently
            // mints an entitlement nobody can name.
            //
            // A local rather than a `static let`: an array of tuples holding
            // closures is not `Sendable`, so at file scope it is a strict-
            // concurrency error under Swift 6. Building three of them per call
            // costs nothing next to the string work already happening here.
            let namespaces: [(prefix: String, make: (String) -> Entitlement)] = [
                ("country:", Entitlement.country),
                ("pack:", Entitlement.expansion),
                ("egg:", Entitlement.easterEgg),
            ]
            // First match wins, and the prefixes are disjoint.
            for (prefix, make) in namespaces where id.hasPrefix(prefix) {
                let name = String(id.dropFirst(prefix.count))
                guard !name.isEmpty else { return nil }
                self = make(name)
                return
            }
            return nil
        }
    }

    /// What the store listing calls it.
    public var title: String {
        switch self {
        case .pro: "VINODEX PRO"
        // BUNDLE -> PACK (0.7.3c, A1). A1 renames the concept, and this is the
        // only other place in the app that printed the old word at a user; the
        // ACCESS heading saying EXPANSION PACKS over a row saying FRANCE BUNDLE
        // is exactly the two-vocabularies state a rename is for. Display copy
        // only — `id` stays `"country:" + name`, which is the storage.
        case .country(let name): "\(name.uppercased()) PACK"
        case .flavors: "FLAVOR WHEEL"
        case .skins: "CHASSIS SKINS"
        // The id stays "lightMode" — it is persisted, and renaming it would
        // silently revoke the bundle. Only the shopfront copy widened when
        // the vintage and amber modes joined the paper-white one.
        case .lightMode: "SCREEN MODES"
        // Through the catalog, so the shopfront and the cartridge cannot
        // disagree about what a pack is called. The fallback matters: an id from
        // a later build has no pack here, and `"OLD-WORLD PACK"` — the raw id,
        // uppercased, hyphen and all — is what this arm used to print for every
        // pack including the ones that do exist.
        case .expansion(let pack):
            ExpansionPacks.pack(id: pack).map { "\($0.title) PACK" }
                ?? "\(pack.uppercased()) PACK"
        case .workshop: "WORKSHOP"
        case .lineage: "GRAPE LINEAGE"
        // Never shown in a storefront — nothing here is for sale. The title
        // exists so an unlock *confirmation* has something to print, which is
        // what the cheat console does with it.
        case .easterEgg(let egg): egg.uppercased()
        }
    }

    public var blurb: String {
        switch self {
        case .pro: "Every grape, region, style and flavour, plus every skin."
        case .country(let name): "Every grape and region from \(name)."
        case .flavors: "All flavour entries and the full tasting wheel."
        case .skins: "All chassis colourways beyond the default."
        case .lightMode: "Nine alternate LCDs — paper-white, three phosphors, and themed consoles."
        case .expansion(let pack):
            ExpansionPacks.pack(id: pack)?.blurb ?? "The \(pack) expansion pack."
        case .workshop: "The full workshop, with every tool unlocked."
        case .lineage: "Every grape's parents, offspring and mutations, drawn as a family tree."
        case .easterEgg: "Unlocked."
        }
    }

    /// Whether this bundle is still sold (0.8.3, D).
    ///
    /// **Retired, not deleted, and the distinction is the whole of D.** D asks
    /// for the flavour wheel and the Italy, France and Spain packs to come off
    /// the shop. Deleting the cases would have been the obvious reading and is
    /// unshippable: `"country:France"` and `"flavors"` are strings in
    /// `grantedEntitlements` on real devices — `LocalEntitlementStore` reads
    /// them through `Entitlement.init(id:)` — and a case that stopped existing
    /// would make `init(id:)` return nil, `compactMap` drop it in silence, and
    /// somebody's purchase disappear on update. That is the exact failure
    /// `Entitlement`'s own note about load-bearing spellings warns about, one
    /// level up.
    ///
    /// So the three things that keep an existing owner whole are all untouched:
    /// `init(id:)` still parses both forms, `id` still writes them back, and
    /// `covers(_:in:)` still opens exactly what it always opened. What changes
    /// is only what the app will *sell*, which is what a paywall coming down
    /// means:
    ///
    /// - `LocalPurchaseProvider.canPurchase` refuses a retired bundle, so
    ///   nothing can newly grant one.
    /// - `offer(for:)` never names one, so a locked entry cannot raise a
    ///   prompt for a product with no storefront behind it.
    /// - `SettingsPanel.shopUpgrades` no longer lists them, so an owner of
    ///   `country:France` sees no phantom FRANCE PACK row on a shelf where the
    ///   pack no longer exists.
    ///
    /// `.country` is retired as a *family*, not three named countries. The shop
    /// only ever listed the three largest by region count — see the `topCountries`
    /// that used to compute them — while `offer(for:)` handed out a bundle for
    /// any of the twenty-six. Retiring the three the shop happened to feature and
    /// leaving twenty-three sellable only through a paywall prompt would be a
    /// storefront with a secret half.
    public var isRetired: Bool {
        switch self {
        case .flavors, .country: true
        case .pro, .skins, .lightMode, .expansion, .workshop, .lineage, .easterEgg: false
        }
    }

    /// Whether this bundle covers a given entry.
    ///
    /// Cosmetic bundles cover nothing — they gate a setting, not a page — so
    /// they answer `false` and the caller falls through to the next bundle.
    public func covers(_ entry: WineEntry, in db: WineDatabase) -> Bool {
        switch self {
        case .pro:
            return true
        case .flavors:
            return entry.category == .flavors
        case .country(let name):
            let target = TextNormalize.label(name)
            guard !target.isEmpty else { return false }
            return TextNormalize.label(entry.origin ?? "") == target
        case .skins, .lightMode, .workshop, .lineage, .easterEgg:
            return false
        // **0.7.3c fills this in, and it can only ever unlock.** The arm stood
        // at `false` through 0.7.3a and 0.7.3b because no pack existed; packs
        // exist now, so an owner of one reaches its entries the way an owner of
        // `.country("France")` reaches France's.
        //
        // Worth being exact about what this does *not* do, since "packs gate
        // content" was a live reading of the spec: nothing here locks anything.
        // `covers` is only ever consulted by `AccessStore.isLocked`, which
        // returns `false` outright unless `starterOnly` is set — and under
        // `starterOnly` these entries were already locked, because they are not
        // in `tiers.json`'s free list. Adding an arm that answers `true` more
        // often strictly widens what an owner can read. See `ExpansionPack` for
        // the passport regression that ruled the other reading out.
        //
        // An unrecognised id covers nothing: a grant written by a later build
        // and read back by this one is a pack this build has never heard of, and
        // guessing at its membership is worse than declining to.
        case .expansion(let pack):
            return ExpansionPacks.pack(id: pack)?.contains(entry) ?? false
        }
    }

    /// The bundle a locked entry most naturally belongs to — what the paywall
    /// prompt should offer to sell.
    ///
    /// **Pro for everything since 0.8.3 (D), and the narrowing is the point.**
    /// This used to read: flavours get the flavour wheel, anything with an origin
    /// gets its country, everything else falls back to Pro — with a note calling
    /// the Pro fallback "technically correct and commercially tin-eared". D
    /// retires both of the narrower answers, and an offer is not a matter of
    /// taste: it is the one promise the app makes that a locked entry can be
    /// unlocked. Naming a bundle no storefront lists would leave the prompt
    /// selling a product that does not exist, which is precisely the orphaned
    /// content D exists to prevent.
    ///
    /// **This function is total and must stay total**, which is what
    /// `AccessTests.everyLockedEntryHasABuyableOffer` pins: for every entry in
    /// the database the answer must be purchasable *and* must cover that entry.
    /// A future bundle may narrow this again — that test is what makes narrowing
    /// safe, because a bundle that covers less than the entry it is offered for
    /// fails it.
    ///
    /// Note what does *not* change: `.pro` has always been the fallback and has
    /// always covered everything, so no entry that was reachable becomes
    /// unreachable. What is lost is granularity in the offer, and `starterOnly`
    /// — the developer switch this whole path sits behind — is off on every real
    /// install, so nobody has ever been shown one of the narrow offers in
    /// anger.
    public static func offer(for entry: WineEntry) -> Entitlement {
        .pro
    }
}
