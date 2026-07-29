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

    public var id: String {
        switch self {
        case .pro: "pro"
        case .country(let name): "country:" + name
        case .flavors: "flavors"
        case .skins: "skins"
        case .lightMode: "lightMode"
        }
    }

    public init?(id: String) {
        switch id {
        case "pro": self = .pro
        case "flavors": self = .flavors
        case "skins": self = .skins
        case "lightMode": self = .lightMode
        default:
            guard id.hasPrefix("country:") else { return nil }
            let name = String(id.dropFirst("country:".count))
            guard !name.isEmpty else { return nil }
            self = .country(name)
        }
    }

    /// What the store listing calls it.
    public var title: String {
        switch self {
        case .pro: "VINODEX PRO"
        case .country(let name): "\(name.uppercased()) BUNDLE"
        case .flavors: "FLAVOR WHEEL"
        case .skins: "CHASSIS SKINS"
        case .lightMode: "LIGHT MODE"
        }
    }

    public var blurb: String {
        switch self {
        case .pro: "Every grape, region, style and flavour, plus every skin."
        case .country(let name): "Every grape and region from \(name)."
        case .flavors: "All flavour entries and the full tasting wheel."
        case .skins: "All chassis colourways beyond the default."
        case .lightMode: "The paper-white LCD, for reading in daylight."
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
        case .skins, .lightMode:
            return false
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
