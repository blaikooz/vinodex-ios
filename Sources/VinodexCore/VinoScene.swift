import Foundation

/// **Vinobot's dialogue scenes** (V1 of the rework, 2026-09-01).
///
/// The rework spec (`horizon-md/vinodex-vino-rework.md`) turns his page from
/// a diagram into a place: a dialogue graph the player walks by tapping
/// choices, in the RPG register the maintainer chose. This file is the
/// graph's vocabulary and the V1 scenes — TODAY and HELP — with the
/// same discipline `VinoDialogue` established for the bubbles: the copy is
/// data, the rules are executable, and `problems()` is what keeps his voice
/// from drifting when the next batch adds nodes.
///
/// ## Why the scene cap is 34 words when the bubble cap is 20
///
/// A bubble interrupts; a scene was asked for. The player tapped his tile
/// and then tapped a question, so he has earned a fuller answer — but not a
/// paragraph: the LCD is small, the typewriter makes every word cost time,
/// and the voice bible's whole finding is that he is funnier short. 34 is
/// two bubble-lengths less the greeting he no longer needs.
///
/// `{name}` follows the bubble contract exactly — resolved through
/// `VinoName`, at most one per node, never sentence-initial — and the text
/// is printable ASCII for the same VT323/Press Start 2P reason. Imported
/// text (a `ToolIntro` body replayed on demand) is displayed verbatim and
/// deliberately NOT gated here: that copy already shipped under its own
/// rules, and re-litigating it in a scene test would make replaying it a
/// copy-edit. `problems()` gates only what this file authors.
///
/// ## Scenes are composed, not stored
///
/// TODAY reads the moon, the streak and the shelf, so its nodes are built
/// per visit by `compose(_:)` from a `VinoSceneInput` the UI fills from the
/// live stores. Core takes values, never stores — same Linux-testability
/// rule as everything else here — so the tests can walk every day type and
/// streak state without a simulator.
public struct VinoSceneChoice: Sendable, Hashable {
    /// The pill's label. Uppercase, short — it is a button on an LCD.
    public let label: String
    /// The node this choice reveals. Every destination must resolve within
    /// the composed graph; `problems()` walks it.
    public let goes: String

    public init(_ label: String, goes: String) {
        self.label = label
        self.goes = goes
    }
}

public struct VinoSceneNode: Sendable, Hashable, Identifiable {
    public let id: String
    /// What he says, after `{name}` resolution. Authored here; gated.
    public let text: String
    /// The face he says it with.
    public let expression: VinoExpression
    /// Pre-shipped copy replayed verbatim under this node (a `ToolIntro`
    /// body). Shown after `text`, exempt from the scene cap — see the
    /// module note.
    public let importedBody: String?
    /// 1–4 choices. A node with no way onward would strand the player —
    /// `problems()` requires every non-root node to offer a route that
    /// reaches "root" again.
    public let choices: [VinoSceneChoice]

    public init(
        id: String,
        text: String,
        expression: VinoExpression,
        importedBody: String? = nil,
        choices: [VinoSceneChoice]
    ) {
        self.id = id
        self.text = text
        self.expression = expression
        self.importedBody = importedBody
        self.choices = choices
    }
}

/// What the UI hands Core to compose a visit. Values, not stores.
public struct VinoSceneInput: Sendable {
    public let name: String?
    public let moonDay: MoonDay
    public let goodDay: Bool
    public let bestStreak: Int
    public let triedCount: Int
    public let silenced: Bool

    public init(
        name: String?,
        moonDay: MoonDay,
        goodDay: Bool,
        bestStreak: Int,
        triedCount: Int,
        silenced: Bool
    ) {
        self.name = name
        self.moonDay = moonDay
        self.goodDay = goodDay
        self.bestStreak = bestStreak
        self.triedCount = triedCount
        self.silenced = silenced
    }
}

public enum VinoScenes {
    /// The whole graph for one visit, keyed by node id. Root is `"root"`.
    public static func compose(_ input: VinoSceneInput) -> [String: VinoSceneNode] {
        let name = VinoName.clean(input.name) ?? VinoName.fallback
        var nodes: [VinoSceneNode] = []

        // --- Root. His greeting carries the rename: he introduces himself
        // as what he now is. Gag 1 of the scene budget (2).
        nodes.append(VinoSceneNode(
            id: "root",
            text: "Vinobot online, \(name). Fully charged, mildly opinionated. What are we doing?",
            expression: .smiling,
            choices: [
                VinoSceneChoice("TODAY", goes: "today"),
                VinoSceneChoice("HELP", goes: "help"),
                VinoSceneChoice(input.silenced ? "SPEAK MORE" : "SPEAK LESS", goes: "quiet"),
            ]
        ))

        // --- TODAY: the moon, then the shelf. Composed per visit.
        let dayWord = input.moonDay.rawValue.lowercased()
        let moonLine = input.goodDay
            ? "A \(dayWord) day on the moon dial, and a good one to drink. My sensors envy you."
            : "A \(dayWord) day on the moon dial. The old calendar says hold off - your call, not mine."
        nodes.append(VinoSceneNode(
            id: "today",
            text: moonLine,
            expression: input.goodDay ? .goodjob : .thinking,
            choices: [
                VinoSceneChoice("AND MY SHELF?", goes: "today.shelf"),
                VinoSceneChoice("BACK", goes: "root"),
            ]
        ))
        let shelfLine: String
        if input.triedCount == 0 {
            shelfLine = "Nothing marked TRIED yet. Every catalogue starts empty - find one bottle and press the button."
        } else if input.bestStreak > 1 {
            shelfLine = "\(input.triedCount) tried, best streak \(input.bestStreak). The Vinodex fills, one glass at a time."
        } else {
            shelfLine = "\(input.triedCount) marked TRIED so far. The Vinodex fills, one glass at a time."
        }
        nodes.append(VinoSceneNode(
            id: "today.shelf",
            text: shelfLine,
            expression: input.triedCount == 0 ? .neutral : .goodjob,
            choices: [VinoSceneChoice("BACK", goes: "root")]
        ))

        // --- HELP: his old one-time tips, replayable at last — the WHOLE
        // roster (checkpoint V1: "expand the device section"), paginated in
        // threes because a menu is pills on an LCD, not a scroll. Page one
        // carries MORE; the last page carries only BACK.
        let intros = Array(ToolRoster.all)
        let pages = stride(from: 0, to: intros.count, by: 3).map {
            Array(intros[$0..<min($0 + 3, intros.count)])
        }
        for (index, page) in pages.enumerated() {
            let pageID = index == 0 ? "help" : "help.\(index + 1)"
            var choices = page.map { VinoSceneChoice($0.title, goes: "help.\($0.id)") }
            if index + 1 < pages.count {
                choices.append(VinoSceneChoice("MORE", goes: "help.\(index + 2)"))
            }
            choices.append(VinoSceneChoice("BACK", goes: "root"))
            nodes.append(VinoSceneNode(
                id: pageID,
                text: index == 0
                    ? "Ask away. I contain multitudes, alphabetised."
                    : "There is more of me. Take your pick.",
                expression: .neutral,
                choices: choices
            ))
        }
        for intro in intros {
            nodes.append(VinoSceneNode(
                id: "help.\(intro.id)",
                text: "My file on \(intro.title):",
                expression: .thinking,
                importedBody: intro.body,
                choices: [
                    VinoSceneChoice("ANOTHER", goes: "help"),
                    VinoSceneChoice("BACK", goes: "root"),
                ]
            ))
        }

        // --- QUIET: the silence switch as a conversation. The UI performs
        // the toggle before showing this node, so the text states the NEW
        // truth. Gag 2 of 2.
        nodes.append(VinoSceneNode(
            id: "quiet",
            text: input.silenced
                ? "Voice restored. I promise to use it responsibly. Mostly."
                : "Quiet mode on. I will still answer when you press my buttons.",
            expression: input.silenced ? .smiling : .neutral,
            choices: [VinoSceneChoice("BACK", goes: "root")]
        ))

        return Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    }

    /// The executable rules, `VinoDialogue.problems()`'s sibling. Empty
    /// means the scene passes; each string is one violation, named.
    public static func problems(in graph: [String: VinoSceneNode]) -> [String] {
        var out: [String] = []
        if graph["root"] == nil { out.append("no root node") }
        for node in graph.values.sorted(by: { $0.id < $1.id }) {
            let words = node.text.split(separator: " ").count
            if words > 34 {
                out.append("\(node.id): \(words) words, over the 34 scene cap")
            }
            if node.text.contains(where: { !$0.isASCII }) {
                out.append("\(node.id): non-ASCII in authored text")
            }
            // Five, not four, since checkpoint V1: a HELP menu page is
            // three topics + MORE + BACK, and five short pills still fit
            // the LCD. Six would not.
            if node.choices.isEmpty || node.choices.count > 5 {
                out.append("\(node.id): \(node.choices.count) choices, need 1-5")
            }
            for choice in node.choices where graph[choice.goes] == nil {
                out.append("\(node.id): choice '\(choice.label)' goes to missing '\(choice.goes)'")
            }
            if node.id != "root",
               !node.choices.contains(where: { $0.goes == "root" || $0.goes.hasPrefix("help") || $0.goes == "today" }) {
                out.append("\(node.id): no route back toward root")
            }
            for choice in node.choices where choice.label != choice.label.uppercased() {
                out.append("\(node.id): choice '\(choice.label)' is not uppercase")
            }
        }
        return out
    }
}
