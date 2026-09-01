import Foundation
import Testing
@testable import VinodexCore

/// Vinobot's dialogue scenes (rework V1): the graph rules, run over every
/// composition the inputs can produce — `VinoDialogueTests`' sibling, one
/// layer up. The scenes are composed from live values, so the sweep here is
/// what a simulator walk cannot be: every day type, both verdicts, the
/// empty shelf and the full one, silenced and speaking.
@Suite("Vino scenes")
struct VinoSceneTests {
    private func inputs() -> [VinoSceneInput] {
        var out: [VinoSceneInput] = []
        for day in MoonDay.allCases {
            for good in [true, false] {
                for (tried, streak) in [(0, 0), (1, 1), (37, 6)] {
                    for silenced in [true, false] {
                        out.append(VinoSceneInput(
                            name: tried == 0 ? nil : "Harrison",
                            moonDay: day, goodDay: good,
                            bestStreak: streak, triedCount: tried,
                            silenced: silenced
                        ))
                    }
                }
            }
        }
        return out
    }

    /// **The voice rules and the graph rules, as one gate.** Word caps,
    /// ASCII, choice counts, resolving destinations, a route back toward
    /// root from everywhere — `VinoScenes.problems` holds the rules; this
    /// runs them over all 48 compositions.
    @Test("every composition passes every scene rule")
    func allCompositionsClean() {
        for input in inputs() {
            let graph = VinoScenes.compose(input)
            let problems = VinoScenes.problems(in: graph)
            #expect(problems.isEmpty, "\(problems)")
        }
    }

    /// The root greeting resolves the name through `VinoName` — the
    /// fallback for a nameless device, the cleaned name otherwise, never a
    /// bare `{name}` and never an empty vocative.
    @Test("the greeting names the player or the fallback")
    func greetingResolves() {
        let named = VinoScenes.compose(inputs().first { $0.name != nil }!)
        #expect(named["root"]!.text.contains("Harrison"))
        let nameless = VinoScenes.compose(inputs().first { $0.name == nil }!)
        #expect(nameless["root"]!.text.contains(VinoName.fallback))
        #expect(!nameless["root"]!.text.contains("{name}"))
    }

    /// The quiet door's label and node state OPPOSITE truths: the label
    /// offers the change, the node (shown after the UI toggles) confirms
    /// it. A silenced device offers SPEAK MORE and, once tapped, the node
    /// speaks as the un-silenced truth — see the UI's advance().
    @Test("the quiet door offers the change and confirms the new truth")
    func quietDoorIsHonest() {
        let silenced = VinoScenes.compose(inputs().first { $0.silenced }!)
        #expect(silenced["root"]!.choices.contains { $0.label == "SPEAK MORE" })
        #expect(silenced["quiet"]!.text.contains("Voice restored"))

        let speaking = VinoScenes.compose(inputs().first { !$0.silenced }!)
        #expect(speaking["root"]!.choices.contains { $0.label == "SPEAK LESS" })
        #expect(speaking["quiet"]!.text.contains("Quiet mode on"))
    }

    /// THIS DEVICE replays shipped `ToolIntro` copy verbatim — imported,
    /// not re-authored, so the scene cap deliberately does not gate it.
    @Test("the device door replays tool intros verbatim")
    func deviceDoorImports() {
        let graph = VinoScenes.compose(inputs()[0])
        for intro in ToolRoster.all.prefix(3) {
            let node = graph["device.\(intro.id)"]
            #expect(node?.importedBody == intro.body)
        }
    }

    /// The empty shelf gets the beginner line; a shelf with a streak gets
    /// the streak; a shelf without one gets the plain count. Three
    /// branches, all reachable, none contradicting the stores they mirror.
    @Test("the shelf line matches the shelf")
    func shelfBranches() {
        let empty = VinoScenes.compose(VinoSceneInput(
            name: nil, moonDay: .fruit, goodDay: true,
            bestStreak: 0, triedCount: 0, silenced: false))
        #expect(empty["today.shelf"]!.text.contains("Nothing marked TRIED"))

        let streaky = VinoScenes.compose(VinoSceneInput(
            name: nil, moonDay: .fruit, goodDay: true,
            bestStreak: 6, triedCount: 37, silenced: false))
        #expect(streaky["today.shelf"]!.text.contains("best streak 6"))

        let plain = VinoScenes.compose(VinoSceneInput(
            name: nil, moonDay: .fruit, goodDay: true,
            bestStreak: 1, triedCount: 1, silenced: false))
        #expect(plain["today.shelf"]!.text.contains("1 marked TRIED"))
    }
}
