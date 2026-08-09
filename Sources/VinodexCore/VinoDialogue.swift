import Foundation

/// **What Professor Vino says, and the rules that keep him in character**
/// (0.8.9c, E3).
///
/// ## Why this is Swift and not `shared/`
///
/// Spec §E3 offers two homes: a resource JSON, or `shared/` generated like
/// everything else. It is neither generated nor shared, and the reasoning is
/// worth stating because the spec's default was the other way.
///
/// `shared/` is the **catalog** — grapes, regions, styles, countries — and it is
/// master-synced into `vinodex-web`, which has no Professor Vino and no plan for
/// one. Two authored-copy files already sit there for historical reasons
/// (`firmware.ts`, `exam.ts`) and `vinodex-web` reads neither; they are dead
/// weight in the mirror and a standing drift surface. Adding a third would be
/// extending a wart rather than following a pattern.
///
/// The pattern this actually belongs to is `ToolRoster` — authored,
/// player-facing, first-run, one-shot copy, with persisted ids, living in Core
/// and guarded by a test. `sommbot` named `ToolIntro` as the structural
/// precedent for `FirstTimeTriggers` and it is the right one for the copy too.
///
/// The deciding argument is where the gates can run. Every invariant below is a
/// statement about strings *and* about the Swift vocabulary that consumes
/// them — key/enum parity, expression coverage, the `{name}` substitution
/// contract. A generator assert could only see the JSON and would still need a
/// second Swift test for the half that matters. `problems` is one function, in
/// the module the consumers live in, and `VinoDialogueTests` is what runs it.
///
/// ## ASCII, and why it bit four lines
///
/// The bubble draws in VT323 over Press Start 2P, both of which have partial
/// Latin-1 coverage — the same faces `assertFirmware` and `assertExam` assert
/// printable ASCII for, because a curly apostrophe or an em dash renders as a
/// blank box on the device and nothing says so.
///
/// `sommbot`'s reviewed set carries em dashes in four lines and a `U+25B9`
/// arrow plus an em dash in the two chirps. All are converted to ASCII here:
/// the dashes to a spaced hyphen, and the chirps into `VinoChirp`, which is a
/// separate field for exactly this reason — the sentence never has to carry
/// punctuation the font cannot draw.
///
/// The assert is scoped to *this* copy rather than to all shipped strings,
/// because `ToolRoster` ships `WHAT'S THAT...?` with a real `U+2026` ellipsis in
/// a title that has been on screen since 0.8.8. Widening the ASCII rule would
/// mean changing that title as a side effect of a dialogue batch. The retired-
/// term denylist *is* widened to `ToolRoster` (see `RetiredTerms`), because that
/// one costs nothing and catches the failure it was written for.
public struct VinoLine: Sendable, Hashable, Identifiable {
    public var id: String { trigger.rawValue }

    /// The action this line answers. Raw value is persisted — see
    /// `FirstTimeTrigger`.
    public let trigger: FirstTimeTrigger

    /// The bubble text. <= 20 words, printable ASCII, may contain exactly one
    /// `{name}` and never in sentence-initial position. See `VinoName`.
    public let line: String

    /// Which of the six portraits fronts it. See `VinoExpression` (0.8.9a, A3).
    public let expression: VinoExpression

    /// The boot chirp, drawn as its own run above the sentence.
    public let chirp: VinoChirp?

    /// Carries the can't-drink/no-body gag.
    ///
    /// **This field is the whole reason the voice bible's cap is enforceable.**
    /// The bible says "roughly 1 in 4 lines, at most" and the first draft set
    /// ran at 50% — eight of sixteen — because nothing could count. `problems`
    /// counts.
    public let gag: Bool

    /// Nil when this line is live. Non-nil names what it is waiting for, and
    /// suppresses `fireOnce` so the key can ship, be tested and be reachable
    /// without the sentence appearing on screen.
    ///
    /// A deferred line is not a commented-out line: it keeps its key reserved
    /// (raw values are storage and cannot be minted twice), it is checked by
    /// every rule below, and turning it on is deleting one string.
    public let deferredUntil: String?

    public var isDeferred: Bool { deferredUntil != nil }

    /// True when `line` interpolates the player's name.
    public var usesName: Bool { line.contains(VinoName.placeholder) }

    public init(
        trigger: FirstTimeTrigger,
        line: String,
        expression: VinoExpression,
        chirp: VinoChirp? = nil,
        gag: Bool = false,
        deferredUntil: String? = nil
    ) {
        self.trigger = trigger
        self.line = line
        self.expression = expression
        self.chirp = chirp
        self.gag = gag
        self.deferredUntil = deferredUntil
    }

    /// The sentence with the player's name substituted.
    ///
    /// The only place `{name}` is resolved, so the fallback and the
    /// sentence-initial rule have exactly one enforcement point. See `VinoName`.
    public func rendered(name: String? = nil) -> String {
        VinoName.substitute(into: line, name: name)
    }

    /// Whitespace-separated tokens, which is what the <= 20 rule counts.
    /// `{name}` is one token by construction; the chirp is not counted because
    /// it is not part of the sentence.
    public var wordCount: Int {
        line.split(whereSeparator: \.isWhitespace).count
    }
}

/// The boot chirp, ASCII-only.
///
/// Its own field rather than a prefix inside `line` (`sommbot` §8.2): the drafts
/// wrote it as `> BOOP.` with a `U+25B9` arrow and `*whirr-BEEP!*` with an em
/// dash, so leaving it in the sentence would have put two un-renderable
/// characters into the one string the ASCII rule exists to protect.
public enum VinoChirp: String, CaseIterable, Sendable {
    case boop
    case whirr
    case bzzt

    /// Drawn above the sentence in the retro face. Printable ASCII, asserted.
    public var text: String {
        switch self {
        case .boop: "BOOP."
        case .whirr: "*whirr-BEEP!*"
        case .bzzt: "bzzt-online."
        }
    }
}

// MARK: - The name

/// The player's name, and the substitution contract around it.
///
/// ## The fallback is `explorer`, lowercase, and that is load-bearing
///
/// `firstLaunch` asks *"What do I call you, explorer?"*, which establishes the
/// word as his term of address — so a skipped name reads as deliberate rather
/// than as a missing variable. No generic ("friend", "user") has that property.
///
/// Lowercase, because **every `{name}` in the set sits in vocative position
/// after a comma or a colon** — "Pleasure, {name}.", "Exam time, {name}.". None
/// is sentence-initial, and if one ever were, `explorer` would need a
/// capitalised variant and the substitution would stop being a single string.
///
/// That constraint is cheaper to hold than to solve, so it is not held by
/// memory: `VinoDialogue.problems` fails the build on any line that opens with
/// the placeholder. The rule and its enforcement are three lines apart.
public enum VinoName {
    /// The one token substituted. Public so the rule that checks it and the
    /// data that contains it cannot disagree about spelling.
    public static let placeholder = "{name}"

    /// What he calls someone who skipped the question. See the type's note.
    public static let fallback = "explorer"

    /// The persisted key — **and it is the one the app already had.**
    ///
    /// `sommbot` §6.3 asked for a new key treated as immutable once shipped.
    /// There is no need to mint one: the USER screen has offered a display name
    /// since well before this batch, stored at `userDisplayName`, editable in
    /// place, wiped by CLEAR SAVED DATA, and already drawn onto share cards by
    /// `ProfileShareCard`. Adding `vinoPlayerName` beside it would have created
    /// two names for one person and a drift surface between them — precisely the
    /// class of fault the rest of this batch is building gates against — and
    /// would have made Vino ask a player who had already answered.
    ///
    /// Two consequences worth stating, because they are decisions rather than
    /// conveniences:
    ///
    /// - **Phase 3's capture writes this key**, so "editable from Settings"
    ///   (§6.3) is already satisfied by the USER screen's own field, and a player
    ///   who named themselves in 0.7.x is greeted by name on first launch after
    ///   this batch rather than being asked again.
    /// - **The share-card exposure §6.3 flagged is pre-existing, not introduced
    ///   here.** `ProfileShareCard` has been rendering this string onto images
    ///   that leave the device for several releases. This batch does not widen
    ///   that; it is noted so the flag is not raised against Vino later.
    ///
    /// The literal lives here rather than in `VinodexUI`'s `UserProfile`, which
    /// now forwards to it, so there is exactly one spelling of a key that
    /// `ACCESS` taught us cannot be renamed.
    public static let storageKey = "userDisplayName"

    /// A stored name reduced to something a 320pt LCD can draw, or nil.
    ///
    /// Trim first, then treat empty as skipped — whitespace-only must land on
    /// the fallback rather than render "Pleasure, .". The 14-character cap is
    /// the house's own marquee precedent, the one that produced `STAMPS` rather
    /// than `STAMP COLLECTION`: a 20-word line with a 40-character name in it is
    /// no longer a 20-word line.
    public static func clean(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }

    public static let maxLength = 14

    /// Resolve to what actually goes on screen.
    public static func resolved(_ raw: String?) -> String {
        clean(raw) ?? fallback
    }

    public static func substitute(into line: String, name: String?) -> String {
        line.replacingOccurrences(of: placeholder, with: resolved(name))
    }
}

// MARK: - Retired labels

/// Player-facing words that used to be right and are not now (0.8.9c).
///
/// **This converts terminology drift from a review finding into a build gate.**
/// It is here because the failure has now happened twice on the same surface:
/// `paper` survived 0.8.0's rename of the concept and stayed on the WINE EXAM
/// first-run card until `sommbot` read the shipped strings against the spec in
/// 0.8.9b, and `ACCESS` was still being written as a label years after it became
/// storage. Both were found by a person reading carefully. Neither had to be.
///
/// Asserted over `VinoDialogue.all` and over `ToolRoster.all` — the two authored
/// copy sets in Core. Widening it to a third set is adding a call to `problems`.
///
/// **Stored raw values are a separate matter and are not covered.**
/// `SettingsSection.access` must keep spelling itself `"ACCESS"` on disk
/// forever; what this forbids is a *sentence* using the word.
public enum RetiredTerms {
    /// Each retired term with what replaced it, for the failure message.
    ///
    /// Matched on word boundaries and case-insensitively, so `ACCESS` does not
    /// fire on "accessible" and `paper` does not fire on "paperwork" — a
    /// substring match here would be a gate nobody could keep green.
    public static let all: [(term: String, replacement: String)] = [
        ("ACCESS", "SHOP"),
        ("paper", "exam"),
        ("SCANNER", "BLIND TASTING"),
        ("IDENTIFY", "BLIND TASTING"),
        ("TASTING QUIZ", "WINE EXAM"),
        ("FILTER SEARCH", "MASTER SEARCH"),
        ("MINIGAMES", "TOOLS"),
        ("SAVED", "USER"),
        // Not a rename but the same class of error: the SHOP has never sold
        // cartridges, it sells PACKS, and the first draft of `firstShop` said
        // otherwise. A word for a thing that does not exist fails the same way a
        // word for a thing that was renamed does.
        ("cartridge", "pack"),
        ("cartridges", "packs"),
        // `sommbot` found the bible using this throughout. The shipped strings
        // are LABEL SCAN (tile) and READ A LABEL (screen hero); "Label Scanner"
        // is neither.
        ("Label Scanner", "LABEL SCAN"),
    ]

    /// Word-boundary, case-insensitive containment.
    ///
    /// Hand-rolled rather than `NSRegularExpression`, which is what keeps this
    /// file Foundation-only and Linux-testable — the whole reason the copy is in
    /// Core. A "word" here is a run of letters; everything else is a boundary,
    /// which makes "TASTING QUIZ" match across its space correctly.
    static func contains(_ term: String, in text: String) -> Bool {
        let haystack = Array(text.lowercased())
        let needle = Array(term.lowercased())
        guard !needle.isEmpty, haystack.count >= needle.count else { return false }

        let isWord: (Character) -> Bool = { $0.isLetter || $0.isNumber }

        for start in 0...(haystack.count - needle.count) {
            guard Array(haystack[start..<(start + needle.count)]) == needle else { continue }
            let before = start > 0 ? haystack[start - 1] : " "
            let afterIndex = start + needle.count
            let after = afterIndex < haystack.count ? haystack[afterIndex] : " "
            // A boundary on both sides, judged against the needle's own edges:
            // a needle starting with a letter needs a non-letter before it.
            let leftOK = !(isWord(before) && isWord(needle[0]))
            let rightOK = !(isWord(after) && isWord(needle[needle.count - 1]))
            if leftOK && rightOK { return true }
        }
        return false
    }

    /// Every retired term found in `text`, described.
    public static func problems(in text: String, where context: String) -> [String] {
        all.compactMap { entry in
            guard contains(entry.term, in: text) else { return nil }
            return "\(context): uses retired term \"\(entry.term)\" (now \(entry.replacement)) - \(text)"
        }
    }
}

// MARK: - The roster

/// Professor Vino's first-time lines, one per trigger (0.8.9c, E3).
///
/// The copy is `sommbot`'s reviewed set (`data-review/VINO-DIALOGUE.md`), not the
/// voice bible's drafts, which it supersedes. Three changes were made on top of
/// it and each is noted at its line: the four em dashes and two chirps became
/// ASCII, and `firstInsight` says INSIGHT in the panel's own casing.
public enum VinoDialogue {
    /// The seventeen, in the order they are met.
    ///
    /// Fifteen from spec §E2 (with "first app open" split in two, because the
    /// ask and the after-name are two bubbles with a stored answer between them)
    /// plus `firstFlavorViewed`, which `sommbot` added: FLAVORS is one of the
    /// four main-menu tiles with 100+ entries behind it and was the only one of
    /// the four with no line.
    public static let all: [VinoLine] = [
        // --- The two launch bubbles. Deferred to Phase 3, which owns the ask.
        //
        // These are the name-capture flow, and a bubble that asks a question
        // needs a field to answer it in — that is spec §F1's, not this
        // sub-batch's. They ship as data now so that Phase 3 is a call to
        // `fireOnce` plus a text field rather than a copy pass: the keys are
        // reserved, the lines are gated, and `VinoName` already resolves the
        // fallback they depend on.
        VinoLine(
            trigger: .firstLaunch,
            // The one bubble with no {name}, because it is the one asking for
            // it. `problems` exempts exactly this trigger and nothing else.
            //
            // ASCII: "online - vintage" was an em dash; the leading "> BOOP."
            // arrow is now `chirp`.
            line: "Professor Vino online - vintage intelligence, no taste buds. What do I call you, explorer?",
            expression: .neutral,
            chirp: .boop,
            // Gag 1 of 4. The character premise: without it he is a database.
            gag: true
            // Live from 0.8.9d. The capture field it was waiting for is
            // `VinoIntroCard`, which draws this line above a text box; Phase 2
            // predicted "a text field plus two `fireOnce` calls" and that is
            // exactly what it cost.
        ),
        VinoLine(
            trigger: .firstLaunchNamed,
            line: "Pleasure, {name}. You taste the world; I catalogue it. Together we fill the Vinodex.",
            // Fires on submit **or** on skip, with the fallback substituted:
            // this line carries the division of labour every later line assumes,
            // so suppressing it on skip means the player who skips never learns
            // what he is for. Live from 0.8.9d, and `VinoIntroCard` honours the
            // both-ways rule literally - SKIP goes to this page too.
            expression: .smiling
        ),

        // --- The four catalog categories.
        VinoLine(
            trigger: .firstGrapeViewed,
            // ASCII: "lineage - the whole file" was an em dash.
            line: "A grape entry, {name}. Origin, body, tannin, lineage - the whole file. Mark it TRIED when you have.",
            expression: .neutral
        ),
        VinoLine(
            trigger: .firstRegionViewed,
            line: "A region, {name}: soil, climate, and law. Three things that decide what the grapes taste like.",
            expression: .thinking
        ),
        VinoLine(
            trigger: .firstStyleViewed,
            // ASCII: "not a place - a way" was an em dash.
            line: "A style, {name}. Not a grape and not a place - a way of making the wine.",
            expression: .thinking
        ),
        VinoLine(
            trigger: .firstFlavorViewed,
            line: "A tasting note, {name}. Every grape that shows it is one tap away. Learn the word first.",
            expression: .thinking,
            // `sommbot` declared this one itself: flavour INFO text is currently
            // template-generated and none of it is authored
            // (`FLAVOR-REWORK-PLAN.md` §4.1), so a line telling the player to
            // "learn the word" writes a cheque that plan's Batch C has to cash.
            deferredUntil: "flavour rework Batch C - flavour INFO text is not authored yet"
        ),

        // --- The discovery loop.
        VinoLine(
            trigger: .firstScan,
            line: "Feed me a label, {name}. I read wine beautifully. Drinking it remains outside my specification.",
            expression: .neutral,
            // Gag 2 of 4. The scanner is the mechanism by which he lives through
            // the player, so here the gag explains the core loop rather than
            // decorating it. Deliberately does not name the screen: the tile says
            // LABEL SCAN and the hero says READ A LABEL, so any name is
            // half-wrong.
            gag: true
        ),
        VinoLine(
            trigger: .firstTried,
            line: "Marked TRIED, {name}. It joins your Passport tastings. Bring me another when you find one.",
            expression: .goodjob
        ),
        VinoLine(
            trigger: .firstInsight,
            // INSIGHT, uppercase — `sommbot` wrote "Insight" while the panel did
            // not exist yet and flagged the line to be re-checked against
            // whatever §B shipped. §B shipped the header as INSIGHT
            // (`EntryDetailScreen.insightSection`), and this set's own rule is to
            // use the shipped string: it already writes TRIED, SHOP and
            // GODFORSAKEN in the app's casing. Phase 1 chose this word
            // deliberately over a prettier synonym; the copy says it too.
            line: "INSIGHT unlocked, {name}. The more you mark TRIED, the more of this I can show you.",
            expression: .goodjob
        ),
        VinoLine(
            trigger: .firstGodforsaken,
            // The wine fix. GODFORSAKEN is a rarity band meaning vanishingly rare
            // plantings; it does not assert a single site, and the tier's
            // membership drives an expansion pack, so its meaning must stay the
            // game's meaning. The draft's "one place on Earth makes this" is
            // contradicted the first time a player opens two Godforsaken grapes
            // from different countries. This is true of every member.
            line: "GODFORSAKEN, {name}. Almost nobody grows this one. I am almost emotional.",
            expression: .surprised,
            // ASCII: the draft's "*whirr-BEEP!*" carried an em dash.
            chirp: .whirr
        ),

        // --- The three tools that collide with a ToolIntro card. See
        // `VinoPresenter.isSuspended` for the sequencing; these lines are
        // written to be the voice half only, with the explaining left to the
        // card that arrives first.
        VinoLine(
            trigger: .firstDailyChallenge,
            // The factual fix: the draft said "one puzzle". It is five questions,
            // one sitting a day, the same five for everybody. "Build a streak" is
            // dropped deliberately - the ToolIntro card already says the streak
            // is the only thing the mode is for, and Vino must not repeat it.
            line: "The Daily Challenge, {name}: five questions, the same for everybody, once a day.",
            expression: .neutral
        ),
        VinoLine(
            trigger: .firstWineExam,
            line: "Exam time, {name}. I ask, you answer. Fair warning: I grade like a French appellation board.",
            expression: .neutral
        ),
        VinoLine(
            trigger: .firstBlindTasting,
            line: "Blind Tasting, {name}: no label, just your palate. If I had a nose I would help.",
            expression: .thinking,
            // Gag 3 of 4. The sharpest instance and the only topically
            // load-bearing one - blind tasting is nose-work.
            gag: true
        ),

        // --- Milestones and chrome.
        VinoLine(
            trigger: .firstStamp,
            // Avoids naming the stamp screen, which answers to three different
            // strings (STAMPS marquee / COLLECTION heading / STAMP COLLECTION
            // link).
            line: "Stamp earned, {name}. It sticks to your Passport. Collect them all; I am absolutely not counting.",
            expression: .goodjob
        ),
        VinoLine(
            trigger: .firstCustomize,
            // ASCII: "away - new shell" was an em dash. "lights" are the real
            // marquee lamps, "shell" is the chassis, and CUSTOMIZE is the shipped
            // American spelling.
            line: "Customize away - new shell, new lights. Same genius inside. You're welcome, {name}.",
            expression: .smiling
        ),
        VinoLine(
            trigger: .firstShop,
            // The terminology fix: the SHOP sells PACKS, never "cartridges" —
            // and `RetiredTerms` now fails the build on the old word. The
            // replacement joke is his transparent self-interest, which is dry and
            // in character and does not spend the gag.
            line: "The SHOP, {name}. Packs of grapes and regions you have not met. I recommend all of them.",
            expression: .smiling
        ),
        VinoLine(
            trigger: .firstPassport,
            // Gag 4 of 4. The envy variant, saved for a milestone screen, is the
            // emotional payoff and the last one the player meets. All three nouns
            // are real Passport sections.
            line: "Your Passport, {name}: tastings, stamps, rank. Proof you went outside. I stayed here. Enviously.",
            expression: .raiseaglass,
            gag: true
        ),
    ]

    public static func line(for trigger: FirstTimeTrigger) -> VinoLine? {
        all.first { $0.trigger == trigger }
    }

    /// The bible's cap, as a number: a gag line for every four lines shipped.
    public static let gagBudgetDivisor = 4

    /// The word cap from the bible's Do-list.
    public static let maxWords = 20

    // MARK: The gate

    /// Everything wrong with the copy, or an empty array.
    ///
    /// **One function rather than eight test methods** so that the rules and the
    /// data are readable together and a new rule is one `append` — the same shape
    /// `assertFirmware` and `assertExam` use on the generator side, moved to
    /// where the consumers are. `VinoDialogueTests` asserts this is empty.
    ///
    /// Deferred lines are checked exactly like live ones. A line that is going to
    /// ship one day should not be allowed to rot in the meantime, which is the
    /// only thing that makes deferral cheaper than deletion.
    public static func problems() -> [String] {
        var problems: [String] = []

        // Key/enum parity, both ways. A trigger with no line is a bubble that
        // fires empty; a line with no trigger is copy nothing can raise.
        let triggered = Set(all.map(\.trigger))
        for trigger in FirstTimeTrigger.allCases where !triggered.contains(trigger) {
            problems.append("FirstTimeTrigger.\(trigger.rawValue) has no line")
        }
        if triggered.count != all.count {
            problems.append("two lines share a trigger")
        }

        for entry in all {
            let where_ = "VinoDialogue.\(entry.trigger.rawValue)"

            // Printable ASCII on every shipped string. See the type note: the
            // bubble's faces render anything else as a blank box.
            if let bad = firstNonASCII(in: entry.line) {
                problems.append("\(where_): line is not printable ASCII - found \(bad)")
            }
            if let chirp = entry.chirp, let bad = firstNonASCII(in: chirp.text) {
                problems.append("\(where_): chirp is not printable ASCII - found \(bad)")
            }

            if entry.line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                problems.append("\(where_): line is empty")
            }
            if entry.wordCount > maxWords {
                problems.append("\(where_): \(entry.wordCount) words; the bubble takes \(maxWords)")
            }

            // The name contract. `firstLaunch` is the one exemption and it is
            // named, not inferred from "has no placeholder" - which would let any
            // future line drop the name silently, the drift that took the draft
            // set down to 4 of 16.
            let occurrences = entry.line.components(separatedBy: VinoName.placeholder).count - 1
            if entry.trigger == .firstLaunch {
                if occurrences != 0 {
                    problems.append("\(where_): the ask cannot use \(VinoName.placeholder) - it is what asks for it")
                }
            } else if occurrences != 1 {
                problems.append("\(where_): uses \(VinoName.placeholder) \(occurrences) times; every line but the ask uses it exactly once")
            }

            // The sentence-initial ban (`sommbot` §6.2). This is what keeps the
            // lowercase `explorer` fallback grammatical forever - the moment a
            // line opens with the placeholder, the fallback needs a capitalised
            // variant and the substitution stops being a single string.
            if entry.line.hasPrefix(VinoName.placeholder) {
                problems.append("\(where_): starts with \(VinoName.placeholder); the fallback \"\(VinoName.fallback)\" is lowercase and would open a sentence")
            }

            problems.append(contentsOf: RetiredTerms.problems(in: entry.line, where: where_))

            if let reason = entry.deferredUntil, reason.trimmingCharacters(in: .whitespaces).isEmpty {
                problems.append("\(where_): deferred with no reason")
            }
        }

        // The gag budget, mechanically. The bible says "roughly 1 in 4 lines, at
        // most" and the first draft ran at 50% because nothing counted.
        let gags = all.filter(\.gag).count
        if gags * gagBudgetDivisor > all.count {
            problems.append(
                "gag budget: \(gags) of \(all.count) lines carry the can't-drink gag; "
                    + "the cap is 1 in \(gagBudgetDivisor), so \(all.count) lines allow \(all.count / gagBudgetDivisor)"
            )
        }

        // Every portrait earns its place. Six sprites were cut and wired in
        // 0.8.9a on the promise that Phase 2 would map triggers onto them; an
        // expression nothing uses is a file in a folder.
        let used = Set(all.map(\.expression))
        for expression in VinoExpression.allCases where !used.contains(expression) {
            problems.append("VinoExpression.\(expression.rawValue) is drawn by no line")
        }

        return problems
    }

    /// The first character outside printable ASCII, described for the message.
    ///
    /// Internal rather than private since 0.8.9d: `CoachmarkWalkthrough.problems`
    /// applies the same rule to the same bubble in the same two fonts, and two
    /// copies of this loop is how one of them comes to allow a curly apostrophe.
    static func firstNonASCII(in text: String) -> String? {
        for scalar in text.unicodeScalars where scalar.value < 0x20 || scalar.value > 0x7E {
            return "U+" + String(format: "%04X", scalar.value) + " (\(Character(scalar)))"
        }
        return nil
    }
}
