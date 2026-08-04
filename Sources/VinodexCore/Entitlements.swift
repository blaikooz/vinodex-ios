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
        case .easterEgg: "Unlocked."
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
        case .skins, .lightMode, .workshop, .easterEgg:
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
    /// Flavours get the flavour wheel; anything with an origin gets its country;
    /// everything else falls back to Pro. Offering Pro for a single Bordeaux
    /// region is technically correct and commercially tin-eared.
    public static func offer(for entry: WineEntry) -> Entitlement {
        if entry.category == .flavors { return .flavors }
        if let origin = entry.origin, !origin.isEmpty { return .country(origin) }
        return .pro
    }
}
