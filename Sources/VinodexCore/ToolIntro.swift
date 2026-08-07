import Foundation
import Observation

/// **What a tool is, said once, the first time you open it** (0.8.8, D1).
///
/// ## The gap
///
/// Six tools sit on the TOOLS shelf behind six two-word tiles. BLIND TASTING,
/// LABEL SCAN, WINE EXAM, DAILY CHALLENGE, WHAT'S THAT…? and MOON DIAL are
/// names, not explanations, and until this batch the only place in the app that
/// said what any of them *did* was the walkthrough's eighth step — which listed
/// six tools, one of which (MASTER SEARCH) is not on this shelf and never has
/// been, and omitted WHAT'S THAT…? entirely. Opening MOON DIAL cold shows a dial
/// and a date and no statement of what a biodynamic drinking day is.
///
/// ## The roster is here, and that is the point
///
/// `ToolsScreen` draws six tiles from six literal calls and `Walkthrough` named
/// them again in prose. Two hand-maintained lists of the same six things drifted
/// within one release of each other, which is the drift `ArtPipelineRosterTests`
/// exists to prevent for art and nothing prevented for this. The roster lives in
/// Core now, `swift test` can see it, `Walkthrough` builds its sentence from it,
/// and `ToolRosterTests` fails if the two ever disagree again.
///
/// ## Ids are storage
///
/// `id` is written to `UserDefaults` by `ToolIntroStore`, so it is a stored
/// vocabulary and follows the house rule the `SettingsSection` and `MarqueePin`
/// enums both carry: **rename the `title`, never the `id`.** A seventh tool
/// appends an id and is a strict superset, so no stored value is lost and the
/// new tool's card shows because its id is simply absent from the set.
public struct ToolIntro: Sendable, Hashable, Identifiable {
    /// Persisted. See the type's note.
    public let id: String
    /// The shelf tile's own words, minus the line break.
    public let title: String
    /// One line: what this is.
    public let tagline: String
    /// How it works, and what it costs you if it costs anything.
    public let body: String
    /// Button-art stem — the same drawing the shelf tile wears.
    public let art: String
    public let symbol: String
    /// The tile's face colour, so the card is recognisably the tile you tapped.
    public let faceHex: String

    public init(
        id: String,
        title: String,
        tagline: String,
        body: String,
        art: String,
        symbol: String,
        faceHex: String
    ) {
        self.id = id
        self.title = title
        self.tagline = tagline
        self.body = body
        self.art = art
        self.symbol = symbol
        self.faceHex = faceHex
    }
}

public enum ToolRoster {
    /// The six, in shelf order — reading order across the 3x2 grid.
    ///
    /// The `art`, `symbol` and `faceHex` of each match `ToolsScreen`'s tile
    /// exactly, and `ToolRosterTests` is what keeps that true.
    public static let all: [ToolIntro] = [
        ToolIntro(
            id: "blindTasting",
            title: "BLIND TASTING",
            tagline: "Work out what is in the glass in front of you.",
            body: """
                Answer what you can see and taste — colour, body, where you think \
                it is from, the flavours you can pick out — and the dex narrows the \
                catalog down to what fits. Skip any step you are unsure of; fewer \
                answers just means a longer list.
                """,
            art: "blindtasting",
            symbol: "eye.slash.fill",
            faceHex: "#22c55e"
        ),
        ToolIntro(
            id: "labelScan",
            title: "LABEL SCAN",
            tagline: "Point the camera at a bottle.",
            body: """
                The label is read on the device — nothing is sent anywhere — and \
                matched against the catalog. It finds grapes, regions and \
                appellations, and will infer a grape from a region that is known \
                for one. Good light and a straight-on shot help most.
                """,
            art: "labelscanner",
            symbol: "camera.viewfinder",
            faceHex: "#3B82F6"
        ),
        ToolIntro(
            id: "wineExam",
            title: "WINE EXAM",
            tagline: "The written paper, in three tiers.",
            body: """
                Hundreds of authored questions across sixteen subjects, with an \
                explanation on every answer whether you got it right or not. Pass a \
                tier to unlock the next one. Nothing here is generated — these are \
                questions somebody wrote.
                """,
            art: "wineexam",
            symbol: "checkmark.seal.fill",
            faceHex: "#a855f7"
        ),
        ToolIntro(
            id: "dailyChallenge",
            title: "DAILY CHALLENGE",
            tagline: "Five questions. One sitting a day.",
            body: """
                The same five for everybody, cut fresh each day from the catalog. \
                Four right passes it and keeps your streak; the streak is the only \
                thing this one is really for. Come back tomorrow for the next.
                """,
            art: "dailychallenge",
            symbol: DexGlyph.challenge,
            faceHex: "#ef4444"
        ),
        ToolIntro(
            id: "whatsThat",
            title: "WHAT'S THAT…?",
            tagline: "Name the grape or region from its clues.",
            body: """
                You start with one free clue and a hundred points. Buy any of the \
                others whenever you like — each one is priced by how much it gives \
                away, and naming the wrong wine turns over the cheapest clue left. \
                Run out of clues and the round is lost. Solving keeps a run going.
                """,
            art: "whatsthat",
            symbol: "sparkles",
            faceHex: "#EAB308"
        ),
        ToolIntro(
            id: "moonDial",
            title: "MOON DIAL",
            tagline: "What kind of day the biodynamic calendar says it is.",
            body: """
                Fruit, flower, leaf or root, worked out from where the moon is. \
                Growers who follow the calendar taste on fruit and flower days and \
                leave the wine alone on the others. Nothing to answer here — it is \
                a readout.
                """,
            art: "moondial",
            symbol: "moon.stars.fill",
            faceHex: "#0891B2"
        ),
    ]

    public static func intro(id: String) -> ToolIntro? {
        all.first { $0.id == id }
    }

    /// The card owed for a route, if that route is a tool.
    ///
    /// **In Core rather than in `VinodexApp`, which is where it started.** The
    /// app shell is the natural place for a route switch and it is the one place
    /// no test can reach — `VinodexCoreTests` cannot see that module — so the
    /// pairing that decides whether a roster entry is ever *reachable* would have
    /// been unverifiable. Here, `everyToolIsReachable` walks the roster against
    /// this function and fails on an entry no route produces, which is the
    /// failure mode that matters: a card written, shipped, and never raised.
    public static func intro(for route: DexRoute) -> ToolIntro? {
        let id: String?
        switch route {
        case .scanner: id = "blindTasting"
        case .labelReader: id = "labelScan"
        case .wsetQuiz: id = "wineExam"
        case .dailyChallenge: id = "dailyChallenge"
        case .dailyGrape: id = "whatsThat"
        case .moonDial: id = "moonDial"
        default: id = nil
        }
        return id.flatMap(intro(id:))
    }

    /// The tool names as a sentence, for the walkthrough's tools step.
    ///
    /// Built rather than written out, which is the whole reason the roster
    /// moved into Core: the step said "blind tasting, label scan, master search,
    /// the wine exam, the daily challenge, and the moon dial" — six names, one
    /// of which is a main-menu button rather than a tool, with WHAT'S THAT…?
    /// missing. That sentence had been wrong since 0.7.9 and nothing could see
    /// it, because prose and a grid of literals cannot be compared.
    public static var sentence: String {
        let names = all.map { $0.title.lowercased() }
        guard let last = names.last, names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + ", and " + last
    }
}

/// Which tool cards have already been shown.
///
/// ## One key, comma-joined ids
///
/// The shape `PassportProgress.seen` uses, for its reason: ids rather than a
/// bitmask or indices, so inserting a tool cannot silently re-show every card
/// after it. Unknown ids are dropped on read and the set is only ever *added*
/// to, which makes widening the roster a strict superset — the rule
/// `QuickPinStore` states and the reason nobody loses a stored value.
///
/// ## Whether a returning player should see these at all
///
/// **Yes, and there is deliberately no seed flag.** The instinct is to copy
/// `PassportProgress.seed(with:)` — which exists because badges are computed
/// from a shelf, so a user who updates after a year of tasting is owed six
/// celebrations at once and must not get them. That failure mode is a *burst*,
/// and it cannot happen here: a tool card is raised when its tool is opened, one
/// navigation at a time, and opening the TOOLS shelf opens no tool. The worst
/// case for a returning player is one card, once, at the moment they open a
/// thing — which is when the information is wanted.
///
/// Seeding would also be wrong on the merits this batch: WHAT'S THAT…? has just
/// had its scoring rebuilt, and a returning player is precisely the one who
/// needs telling that guessing now costs something. A flag that suppressed the
/// card would have hidden the change from the only people who would notice it.
///
/// What returning players get instead is `markAllSeen` — one control on the card
/// itself. That answers "do not pester me" without the app pretending to know
/// who has used what, which it has no record of and would have had to guess.
@MainActor
@Observable
public final class ToolIntroStore {
    public static let shared = ToolIntroStore()

    public nonisolated static let storageKey = "toolIntrosSeen"

    private let defaults: UserDefaults
    private(set) public var seen: Set<String>

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.storageKey) ?? ""
        let ids = Set(ToolRoster.all.map(\.id))
        // Unknown ids dropped: a tool removed in a later release should not keep
        // a slot in the stored set forever.
        seen = Set(raw.split(separator: ",").map(String.init)).intersection(ids)
    }

    public func hasSeen(_ id: String) -> Bool { seen.contains(id) }

    /// The card to raise for a tool, or nil if it has already been shown.
    public func pending(_ id: String) -> ToolIntro? {
        guard !hasSeen(id), let intro = ToolRoster.intro(id: id) else { return nil }
        return intro
    }

    public func markSeen(_ id: String) {
        guard ToolRoster.intro(id: id) != nil, seen.insert(id).inserted else { return }
        persist()
    }

    /// Dismiss the whole set — the returning player's escape hatch. See the
    /// type's note for why this exists instead of a seed flag.
    public func markAllSeen() {
        let all = Set(ToolRoster.all.map(\.id))
        guard seen != all else { return }
        seen = all
        persist()
    }

    public func reset() {
        seen = []
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persist() {
        if seen.isEmpty {
            defaults.removeObject(forKey: Self.storageKey)
        } else {
            defaults.set(seen.sorted().joined(separator: ","), forKey: Self.storageKey)
        }
    }
}
