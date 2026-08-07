import Foundation
import Observation

/// **The actions Professor Vino has something to say about, once** (0.8.9c, E1).
///
/// ## Raw values are storage
///
/// Spec §E1 asks for "a persisted set of seen keys", so these inherit the rule
/// `SettingsSection`, `MarqueePin` and `ToolIntro.id` all carry and the `ACCESS`
/// lesson taught: **once shipped, never renamed.** A rename does not fail
/// loudly — `FirstTimeTriggerStore` drops unknown keys on read, exactly as
/// `QuickPinStore` does — it silently re-fires a bubble the player has already
/// dismissed.
///
/// They are therefore named after the **concept**, never after the current
/// screen label, because the label is the thing that has moved twice already:
/// ACCESS became SHOP and the written paper became the exam. `firstShop` is
/// named for the shop, not for `SettingsSection.access`, and survives the next
/// rename of either.
///
/// ## Adding one
///
/// Append a case, add its line to `VinoDialogue.all`, and either give it a route
/// arm in `triggers(for:entry:)` or fire it by hand from the event that means
/// it. `VinoDialogueTests` fails until it has a line and until its `source` is
/// declared, so the two halves cannot drift.
public enum FirstTimeTrigger: String, CaseIterable, Sendable, Hashable {
    // The launch pair. One §E2 trigger ("first app open"), two bubbles, because
    // the ask and the after-name have a stored answer between them.
    case firstLaunch
    case firstLaunchNamed

    // The four catalog categories.
    case firstGrapeViewed
    case firstRegionViewed
    case firstStyleViewed
    case firstFlavorViewed

    // The discovery loop.
    case firstScan
    case firstTried
    case firstInsight
    case firstGodforsaken

    // The tools.
    case firstDailyChallenge
    case firstWineExam
    case firstBlindTasting

    // Milestones and chrome.
    case firstStamp
    case firstCustomize
    case firstShop
    case firstPassport

    /// How this trigger reaches `fireOnce`.
    ///
    /// **Declared rather than inferred, because Core cannot see half the answer.**
    /// `VinodexUI` and `VinodexApp` are invisible to Linux tests, so a trigger
    /// fired from a view is a trigger no test can prove is reachable. What a test
    /// *can* prove is that every trigger claiming to be route-driven really is
    /// produced by `triggers(for:entry:)` — which is the same trick
    /// `ToolRoster.intro(for:)` plays, and for the same reason: it moves the one
    /// checkable half into the module that can check it, and makes the
    /// unverifiable half an explicit claim instead of an omission.
    public enum Source: Sendable, Equatable {
        /// Fires on arriving somewhere. Verified against `triggers(for:entry:)`.
        case route
        /// Fires on something happening. The string names the site, so a grep
        /// has somewhere to start; it is documentation, not a check.
        case event(String)
    }

    public var source: Source {
        switch self {
        case .firstLaunch: .event("VinodexApp - after the BIOS (Phase 3)")
        case .firstLaunchNamed: .event("VinodexApp - name submit or skip (Phase 3)")
        case .firstGrapeViewed, .firstRegionViewed, .firstStyleViewed, .firstFlavorViewed: .route
        case .firstGodforsaken: .route
        case .firstDailyChallenge, .firstWineExam, .firstBlindTasting: .route
        case .firstCustomize, .firstShop, .firstPassport: .route
        case .firstScan: .event("LabelReaderView - a successful identified read")
        case .firstTried: .event("EntryDetailScreen and LabelReaderView - markTried returned true")
        case .firstInsight: .event("EntryDetailScreen - the INSIGHT panel drew a line")
        case .firstStamp: .event("StampUnlockedPrompt hosts - a stamp was announced")
        }
    }

    /// Whether an existing user's history can make this true retroactively.
    ///
    /// **This is the whole of the first-run trap, and it is a property of the
    /// trigger rather than a decision about the feature.** See
    /// `FirstTimeTriggerStore.seed(triedCount:hasAnnouncedStamps:)`.
    var isDerivedFromHistory: Bool {
        switch self {
        case .firstTried, .firstInsight, .firstStamp: true
        default: false
        }
    }

    // MARK: Route arms

    /// What arriving at `route` is worth saying, in the order it should be said.
    ///
    /// **A list rather than an optional**, unlike `ToolRoster.intro(for:)`,
    /// because one arrival can legitimately be two firsts: opening a Godforsaken
    /// grape as your first grape is both `firstGrapeViewed` and
    /// `firstGodforsaken`. Collapsing that to one would silently drop whichever
    /// lost the tie, and the queue exists precisely so it does not have to be a
    /// tie. Category first, rarity second — "this is a grape entry" is the
    /// orientation and "this one is vanishingly rare" is the remark about it.
    ///
    /// `entry` is nil for every route that does not name one; the caller
    /// resolves it because only the app holds the database's identity map.
    public static func triggers(for route: DexRoute, entry: WineEntry? = nil) -> [FirstTimeTrigger] {
        switch route {
        case .detail:
            guard let entry else { return [] }
            var found: [FirstTimeTrigger] = []
            switch entry.category {
            case .grapes: found.append(.firstGrapeViewed)
            case .regions: found.append(.firstRegionViewed)
            case .styles: found.append(.firstStyleViewed)
            case .flavors: found.append(.firstFlavorViewed)
            // Continents have their own route and no line - `sommbot`'s
            // backlog, not the starter set.
            case .continents: break
            }
            if entry.rarity == .godforsaken { found.append(.firstGodforsaken) }
            return found

        case .dailyChallenge: return [.firstDailyChallenge]
        case .wsetQuiz: return [.firstWineExam]
        // BLIND TASTING is `DexRoute.scanner` - the route case kept its old name
        // through 0.7.9's rename of the screen behind it, which is exactly why
        // these keys are named after concepts and not after route cases.
        case .scanner: return [.firstBlindTasting]
        case .passport: return [.firstPassport]

        case .settingsSection(let section):
            switch section {
            case .customization: return [.firstCustomize]
            // Stored as `"ACCESS"`, displayed as SHOP. The key says shop.
            case .access: return [.firstShop]
            default: return []
            }
        // A pack splash is the shop with a shelf open (0.8.4, C1), and it is
        // reachable without passing through the grid - a marquee pin lands here
        // directly. Without this arm the shop line would be skippable by
        // shortcut.
        case .pack: return [.firstShop]

        default: return []
        }
    }
}

// MARK: - The store

/// Which first-time lines have already been shown (0.8.9c, E1).
///
/// ## The shape is `ToolIntroStore`'s, deliberately
///
/// One `UserDefaults` key holding comma-joined ids, unknown ids dropped on read,
/// the set only ever added to. That makes widening the vocabulary a **strict
/// superset** — the rule `QuickPinStore` states — so a new trigger shows its
/// bubble because its key is simply absent, and nobody loses a stored value.
///
/// ## The first-run trap, and which way this went
///
/// **Three consecutive batches hit this**: 0.8.7's D1 and 0.8.8's D1/D2 both
/// shipped a one-shot that fired for everything an existing user had already
/// done. `ToolIntroStore` shipped *without* a seed flag and was right to, with
/// stated reasoning: a tool card is raised one navigation at a time and opening
/// the TOOLS shelf opens no tool, so the burst it would have guarded against
/// could not occur.
///
/// Fifteen triggers instrumented across the whole app does **not** get that for
/// free, and the reason is that they are not all the same shape. Sorting them by
/// what can make them true tells you which need seeding and which do not:
///
/// - **Navigation and action triggers** — the four categories, the three tools,
///   CUSTOMIZE, SHOP, PASSPORT, the scan, the Godforsaken find. Every one of
///   these becomes true by the player *doing something now*, one navigation or
///   one action at a time. `ToolIntroStore`'s argument applies verbatim and its
///   conclusion is inherited: no seed. The worst case for a returning player is
///   one bubble, once, at the moment they open a thing.
/// - **History-derived triggers** — `firstTried`, `firstInsight`, `firstStamp`.
///   These are computed from state an existing user *already has on disk*. A
///   player who has been marking wines since 0.8.9a opens any grape and fires
///   two at once for things they did weeks ago. That is a burst, it is
///   `PassportProgress.seed(with:)`'s exact failure mode, and it gets
///   `PassportProgress`'s exact answer.
///
/// So: **seeded, but only the three that can be true retroactively.** The other
/// fourteen are unseeded and keep 0.8.8's reasoning. Splitting by shape rather
/// than seeding the lot matters — seeding everything would silently rob every
/// existing player of the entire character, which is the opposite failure and a
/// much quieter one.
///
/// The seeded flag is separate from the emptiness of the set, for the reason
/// `PassportProgress` gives at length: a genuinely new user must also be seeded,
/// and their seed is empty, so "seeded to empty" and "never seeded" are
/// different states and the first must not decode as the second.
@MainActor
@Observable
public final class FirstTimeTriggerStore {
    public static let shared = FirstTimeTriggerStore()

    public nonisolated static let storageKey = "firstTimeTriggersSeen"
    public nonisolated static let seededKey = "firstTimeTriggersSeeded"

    private let defaults: UserDefaults
    private(set) public var seen: Set<String>

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.storageKey) ?? ""
        let known = Set(FirstTimeTrigger.allCases.map(\.rawValue))
        // Unknown keys dropped: a trigger retired in a later release should not
        // keep a slot in the stored set forever.
        seen = Set(raw.split(separator: ",").map(String.init)).intersection(known)
    }

    public func hasFired(_ trigger: FirstTimeTrigger) -> Bool {
        seen.contains(trigger.rawValue)
    }

    /// The line owed for this action, or nil if it has already been said.
    ///
    /// **Marks seen on the way out, not on dismissal.** `ToolIntroCard` marks on
    /// dismissal because it is raised from a route and re-derived every render —
    /// re-entering the same route with the flag unwritten simply re-raises the
    /// same card. This is queued, so an un-marked line could be enqueued twice
    /// before the first copy is ever seen. Marking here makes "once" a property
    /// of the request rather than of the presentation.
    ///
    /// Returns nil for a deferred line (`VinoLine.deferredUntil`) **without**
    /// marking it seen, so switching one on later still shows it.
    @discardableResult
    public func fireOnce(_ trigger: FirstTimeTrigger) -> VinoLine? {
        guard let line = VinoDialogue.line(for: trigger), !line.isDeferred else { return nil }
        guard seen.insert(trigger.rawValue).inserted else { return nil }
        persist()
        return line
    }

    /// Suppress the bubbles an existing player has already earned.
    ///
    /// Runs once ever, on the first launch after this batch. Takes plain values
    /// rather than the stores themselves so the decision is testable on Linux
    /// without standing up a database — the stores are read at the one call site
    /// in `RootView`.
    ///
    /// A new install passes zero and false, seeds to empty, and gets every line.
    /// See the type's note for why "seeded to empty" needs its own flag.
    public func seed(triedCount: Int, hasAnnouncedStamps: Bool) {
        guard !defaults.bool(forKey: Self.seededKey) else { return }

        var earned: Set<FirstTimeTrigger> = []
        // INSIGHT deepens with the tried count and `InsightDepth.first` is one
        // tasting, so a single tried entry means the panel has already been
        // showing derived lines. Read through `InsightDepth` rather than
        // hardcoding 1, so a change to the ladder moves this with it.
        if InsightDepth.earned(by: triedCount) > .teaser {
            earned.insert(.firstTried)
            earned.insert(.firstInsight)
        }
        // `PassportProgress` has been recording announced badges since 0.7.1 and
        // seeded itself then, so a non-empty ledger is proof of stamps earned
        // without building a `Passport` on the launch path.
        if hasAnnouncedStamps { earned.insert(.firstStamp) }

        seen.formUnion(earned.map(\.rawValue))
        defaults.set(true, forKey: Self.seededKey)
        persist()
    }

    /// **There is deliberately no `silenceAll` yet**, and the contrast with
    /// `ToolIntroStore.markAllSeen` is the reason.
    ///
    /// That method exists because `ToolIntroStore` has no seed flag, so a
    /// returning player is the problem it has no other answer to. This store
    /// *does* seed, so the returning player is already handled and a
    /// silence-everything control would be answering a question nobody is left
    /// asking. What remains — "hide him entirely, I am a power user" — is a
    /// preference with a home in SETTINGS > DEVICE beside the re-runnable
    /// tutorial, which is spec §G2's, not this sub-batch's.
    ///
    /// Adding it here would have shipped a public method and a test with no call
    /// site, which is the "written, shipped, never raised" fault the rest of this
    /// batch builds gates against. Phase 3 adds the control and the one line that
    /// backs it.
    public func reset() {
        seen = []
        defaults.removeObject(forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.seededKey)
    }

    private func persist() {
        if seen.isEmpty {
            defaults.removeObject(forKey: Self.storageKey)
        } else {
            defaults.set(seen.sorted().joined(separator: ","), forKey: Self.storageKey)
        }
    }
}

// MARK: - The presenter

/// Professor Vino's bubble queue (0.8.9c, D1).
///
/// ## Why the queue is in Core
///
/// Spec D1 asks for "queued if several would fire", and one arrival really can
/// owe two lines — the Godforsaken-grape-as-first-grape case in
/// `FirstTimeTrigger.triggers(for:entry:)`. Queue order, dedupe and the
/// suspension rule below are the parts of this feature that can be *wrong*, and
/// `VinodexUI` has no test target. The view draws `current` and calls `dismiss`;
/// everything that decides which line that is lives here where `swift test` can
/// see it.
///
/// ## `isSuspended` is the ToolIntro collision, solved
///
/// Four triggers fire on screens that already raise a first-run explainer card:
/// LABEL SCAN, WINE EXAM, DAILY CHALLENGE and BLIND TASTING all have a
/// `ToolIntro`. Un-sequenced, the player meets **two first-run interruptions on
/// the same screen**, one explaining the mode and one explaining it again in a
/// funnier voice — worse than either alone.
///
/// The copy half is already handled: `sommbot`'s rewrites for those four drop
/// the explaining and keep the voice, so `firstDailyChallenge` does not repeat
/// the streak line the card has just given. This is the sequencing half, and it
/// is one boolean rather than a per-screen rule: while any modal owns the
/// screen, the presenter holds its queue and shows nothing. The line is not
/// dropped and not re-fired — it waits, and lands as the card leaves.
///
/// A boolean the host sets, rather than the presenter knowing about
/// `ToolIntroStore`, because the thing being expressed is "something else is
/// talking" and the next modal that qualifies should not have to teach this type
/// about itself. `RootView` owns the composition and is the only place that
/// knows what is currently on screen.
@MainActor
@Observable
public final class VinoPresenter {
    public static let shared = VinoPresenter()

    /// Waiting lines, oldest first. `current` is `queue.first`.
    private(set) public var queue: [VinoLine] = []

    /// Who is currently talking instead of him.
    ///
    /// **A set of reasons rather than a boolean, because there are two hosts.**
    /// `RootView` owns the chrome overlays — the BIOS, the tool card, the upgrade
    /// prompt, the data notice — but the stamp celebration and the rating prompt
    /// are raised *inside* `EntryDetailScreen`, which is exactly where
    /// `firstTried`, `firstInsight` and `firstStamp` all fire. Two independent
    /// writers to one boolean is a race: whichever rendered last wins, and the
    /// losing case is a bubble drawn over the celebration it was congratulating.
    ///
    /// Keyed by reason so each host clears only its own, and so a failure to
    /// resume is greppable rather than anonymous.
    private(set) public var suspensions: Set<String> = []

    public init() {}

    /// `true` while anything is holding the queue.
    public var isSuspended: Bool { !suspensions.isEmpty }

    /// Declare (or withdraw) one host's claim on the screen. Idempotent, so it
    /// can be called from a SwiftUI body-adjacent modifier on every render.
    public func setSuspended(_ suspended: Bool, by reason: String) {
        if suspended {
            suspensions.insert(reason)
        } else {
            suspensions.remove(reason)
        }
    }

    /// The bubble to draw, or nil.
    public var current: VinoLine? { isSuspended ? nil : queue.first }

    /// Whether anything is waiting, regardless of suspension — so a host can
    /// tell "nothing to say" from "not now".
    public var isEmpty: Bool { queue.isEmpty }

    /// Enqueue a line. Idempotent per trigger: `fireOnce` already guarantees one
    /// call per key, and this guarantees one copy per queue even if a caller
    /// double-fires — a bubble shown twice is the failure this whole file is
    /// named after.
    public func present(_ line: VinoLine) {
        guard !queue.contains(where: { $0.trigger == line.trigger }) else { return }
        queue.append(line)
    }

    /// Fire and enqueue in one call — the shape the instrumentation sites use.
    ///
    /// `fireOnce(.firstScan)` in spec §E1's words, except that the spec's version
    /// both records and shows. Splitting them would give every one of the
    /// fifteen call sites two lines and a chance to forget the second.
    public func fireOnce(_ trigger: FirstTimeTrigger, in store: FirstTimeTriggerStore = .shared) {
        guard let line = store.fireOnce(trigger) else { return }
        present(line)
    }

    /// Every line a route arrival owes, in order.
    public func fireOnce(
        for route: DexRoute,
        entry: WineEntry? = nil,
        in store: FirstTimeTriggerStore = .shared
    ) {
        for trigger in FirstTimeTrigger.triggers(for: route, entry: entry) {
            fireOnce(trigger, in: store)
        }
    }

    /// Tap to dismiss. Advances to the next waiting line, if any.
    public func dismiss() {
        guard !queue.isEmpty else { return }
        queue.removeFirst()
    }

    /// Drop everything waiting — the SILENCE control, and what the host calls
    /// when the player navigates away from the screen a line was about.
    public func clear() {
        queue.removeAll()
    }
}
