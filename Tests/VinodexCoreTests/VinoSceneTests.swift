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
                            silenced: silenced,
                            picks: tried == 0 ? [] : [
                                VinoScenePick(id: "G001", name: "Cabernet Sauvignon"),
                                VinoScenePick(id: "S002", name: "Orange Wine"),
                            ],
                            favoriteOrigin: tried > 1 ? "France" : nil,
                            study: streak > 1
                                ? VinoStudyReading(categoryLabel: "FLAVOR PROFILES", right: 2, asked: 5)
                                : nil
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

    /// HELP replays shipped `ToolIntro` copy verbatim — imported, not
    /// re-authored, so the scene cap deliberately does not gate it — and
    /// since checkpoint V1 it lists the WHOLE roster, paginated: every
    /// intro is reachable, and page one's MORE chains to page two.
    @Test("help lists the whole roster, paginated, verbatim")
    func helpListsEverything() {
        let graph = VinoScenes.compose(inputs()[0])
        for intro in ToolRoster.all {
            let node = graph["help.\(intro.id)"]
            #expect(node?.importedBody == intro.body, "missing \(intro.id)")
        }
        #expect(graph["help"]!.choices.contains { $0.label == "MORE" })
        #expect(graph["help.2"] != nil)
    }

    /// MY PICKS (V2): thin profile gets the honest nudge; a real one gets
    /// the reason line and pick pills whose destinations leave the scene
    /// through the `open:` prefix — which `problems()` must accept.
    @Test("picks door: honest when thin, evidenced when not")
    func picksDoor() {
        let thin = VinoScenes.compose(VinoSceneInput(
            name: nil, moonDay: .leaf, goodDay: true,
            bestStreak: 0, triedCount: 0, silenced: false))
        #expect(thin["picks"]!.text.contains("More data required"))

        let rich = VinoScenes.compose(VinoSceneInput(
            name: "Harrison", moonDay: .leaf, goodDay: true,
            bestStreak: 3, triedCount: 20, silenced: false,
            picks: [VinoScenePick(id: "G001", name: "Cabernet Sauvignon")],
            favoriteOrigin: "France"))
        #expect(rich["picks"]!.text.contains("returning to France"))
        #expect(rich["picks"]!.choices.contains {
            $0.label == "CABERNET SAUVIGNON" && $0.goes == "open:G001"
        })
    }

    /// STUDY (V2): the weakest-category rule's honesty carries through —
    /// no papers means no claimed blind spot, and both states offer the
    /// paper through the `exam:` external.
    @Test("study door: names the blind spot only when the ledger can")
    func studyDoor() {
        let fresh = VinoScenes.compose(VinoSceneInput(
            name: nil, moonDay: .root, goodDay: false,
            bestStreak: 0, triedCount: 0, silenced: false))
        #expect(fresh["study"]!.text.contains("No meaningful papers"))
        #expect(fresh["study"]!.choices.contains { $0.goes == "exam:" })

        let read = VinoScenes.compose(VinoSceneInput(
            name: nil, moonDay: .root, goodDay: false,
            bestStreak: 2, triedCount: 5, silenced: false,
            study: VinoStudyReading(categoryLabel: "REGIONS", right: 1, asked: 4)))
        #expect(read["study"]!.text.contains("REGIONS: 1 of 4"))
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
