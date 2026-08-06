import Foundation
import Testing
@testable import VinodexCore

/// The cartridge art table maps two vocabularies onto each other (0.8.2).
///
/// **This is the gate that makes `CartridgeArt` a table rather than a guess.**
/// The art is named by the illustrator (`displayvintage`, `screenmodes`) and the
/// app is keyed on persisted entitlement ids (`pack:display-retro`,
/// `lightMode`). Nothing in Swift's type system connects a string in that
/// dictionary to a file on disk or to a product in the shop, so a typo on either
/// side is a cartridge that silently falls back to the drawn one — which looks
/// fine, which is the whole problem. `IconLoader.image` returning nil in silence
/// is the fault this repo has shipped three times; a missing cartridge is the
/// same fault wearing a different name.
///
/// Reached through `#filePath` exactly as `ArtPipelineRosterTests` reaches the
/// importers, because the source art is the authority and it is not in the
/// bundle at test time.
@Suite("Cartridge art")
struct CartridgeArtTests {
    /// `Tests/VinodexCoreTests/<this file>` -> the package root.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// The stems on disk under `art/icons/cartridges/`, less the extension.
    private static var stemsOnDisk: Set<String> {
        get throws {
            let dir = repoRoot
                .appendingPathComponent("art")
                .appendingPathComponent("icons")
                .appendingPathComponent("cartridges")
            let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            return Set(
                names.filter { $0.lowercased().hasSuffix(".png") }
                    .map { String($0.dropLast(4)) }
            )
        }
    }

    /// Everything the shop can put a cartridge under: the twelve packs and the
    /// five standalone upgrades. Country packs are excluded — there is one per
    /// country with regions and no art was ever drawn for them.
    private static var sellableIDs: Set<String> {
        var ids = Set(ExpansionPacks.all.map { Entitlement.expansion($0.id).id })
        for entitlement: Entitlement in [.pro, .flavors, .skins, .lightMode, .workshop, .lineage] {
            ids.insert(entitlement.id)
        }
        return ids
    }

    @Test("every mapped stem has a file behind it")
    func stemsResolveToArt() throws {
        let onDisk = try Self.stemsOnDisk
        for (id, stem) in CartridgeArt.stems {
            #expect(onDisk.contains(stem), "\(id) names cartridge art '\(stem)' that is not in art/icons/cartridges/")
        }
    }

    /// The other direction, which is the one that rots. A stem with no product
    /// is art nobody can reach, and it is invisible from inside the app — the
    /// shop simply never asks for it.
    @Test("every drawn cartridge is claimed by something on sale")
    func artIsAllClaimed() throws {
        let mapped = Set(CartridgeArt.stems.values)
        for stem in try Self.stemsOnDisk {
            #expect(mapped.contains(stem), "art/icons/cartridges/\(stem).png is drawn but nothing in the shop claims it")
        }
    }

    @Test("every mapped id is a thing the shop actually sells")
    func idsAreSellable() {
        let sellable = Self.sellableIDs
        for id in CartridgeArt.stems.keys {
            #expect(sellable.contains(id), "'\(id)' has cartridge art but is not on sale")
        }
    }

    /// **The two known gaps, pinned as gaps.** Both fall back to the code-drawn
    /// cartridge, which is correct and must stay correct — the fallback is the
    /// only thing standing between an unmapped product and an empty tile. Pinned
    /// rather than left implicit so that art arriving for either one is a
    /// deliberate edit here and not a surprise.
    @Test("the flavour wheel and the country packs have no cartridge, and fall back")
    func knownGapsFallBack() {
        #expect(CartridgeArt.stem(for: .flavors) == nil)
        #expect(CartridgeArt.stem(for: .country("France")) == nil)
        // …and the seventeen that do have one all resolve, prefix included.
        #expect(CartridgeArt.stems.count == 17)
        #expect(CartridgeArt.stem(for: .pro) == "cartridge-vinodexpro")
        #expect(CartridgeArt.stem(for: .lineage) == "cartridge-grapelineage")
    }

    /// The three rows where the art's word and the code's word differ. Spelled
    /// out because each one is a rename somebody will eventually propose, and
    /// each one is load-bearing in the opposite direction.
    @Test("the three vocabulary collisions map the way CartridgeArt documents")
    func documentedCollisions() {
        // 0.7.1's C1: the section is RETRO, the mode is VINTAGE, the art took
        // the mode's word.
        #expect(CartridgeArt.stem(for: .expansion("display-retro")) == "cartridge-displayvintage")
        // The entitlement id is `lightMode` and cannot change — it is persisted.
        #expect(CartridgeArt.stem(for: .lightMode) == "cartridge-screenmodes")
        // The file arrived misspelled `godforksaken.png` and was renamed rather
        // than mapped. If this fails with a missing file, the rename was lost.
        #expect(CartridgeArt.stem(for: .expansion("godforsaken")) == "cartridge-godforsaken")
    }
}
