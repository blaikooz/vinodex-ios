import Foundation

/// Which drawn cartridge belongs to which thing in the shop (0.8.2).
///
/// **Two vocabularies meet here and neither gets renamed.**
///
/// The art under `art/icons/cartridges/` is named for the product as the
/// illustrator thinks of it: `oldworld`, `displayvintage`, `screenmodes`. The
/// app is keyed on `Entitlement.id`, which is *persisted* — `pack:old-world`,
/// `pack:display-retro`, `lightMode` — and whose spellings `Entitlement` itself
/// documents as load-bearing: "renaming one silently revokes it on every device
/// that already stored it." Renaming the files instead would put the app's
/// storage keys on an illustrator's disk, which is the same coupling pointing
/// the other way.
///
/// So this is a table, in `VinodexCore` rather than beside the views, because
/// that is what `swift test` can see and `CartridgeArtTests` is the gate: every
/// stem names a real product, every product with art names a real stem.
///
/// **Three rows where the two vocabularies genuinely disagree**, and all three
/// are already-documented collisions rather than new ones:
///
/// - `displayvintage` → `pack:display-retro`. 0.7.1's C1 renamed that section
///   to RETRO precisely because a group called VINTAGE containing a mode called
///   VINTAGE read as a mislabelled tile, and `LcdMode.vintage` is persisted and
///   kept its name. `ExpansionPacks.retroDisplays` carries the full argument.
///   The art uses the older word; the code keeps the newer one.
/// - `screenmodes` → `lightMode`. The entitlement id is `lightMode` and the
///   shopfront copy has said SCREEN MODES since the vintage and amber modes
///   joined the paper-white one — `Entitlement.title` explains that the id
///   stays because renaming it revokes the purchase. The art is named after
///   what the user sees, so it lands on the newer word and the id keeps the
///   older one, which is the previous bullet in mirror image.
/// - `godforsaken`. The file arrived spelled `godforksaken.png` and was renamed
///   on import rather than encoded here. A typo in a filename is a typo; a typo
///   in a mapping table is a permanent second spelling that every future reader
///   has to check is deliberate.
///
/// **Two things on sale have no cartridge**: `flavors` (the flavour wheel) and
/// every `country(_:)` pack. Both fall back to the code-drawn `PackCartridge`,
/// which is why that view keeps its whole rendering rather than being reduced
/// to an image well. Nothing here treats a missing stem as an error — `stem(for:)`
/// returns nil and the caller draws what it drew before.
public enum CartridgeArt {
    /// The prefix `import-cartridge-art.py` writes onto every stem, keeping
    /// `classic`, `vessel`, `festive` and `wines` out of `PixelArtLoader`'s flat
    /// global namespace.
    public static let prefix = "cartridge-"

    /// `Entitlement.id` -> the art stem, less the prefix.
    ///
    /// Keyed on the id rather than on the enum so a pack id from a later build
    /// resolves or does not, without a Swift change — the same argument
    /// `Entitlement.expansion` makes for being a string case.
    public static let stems: [String: String] = [
        // The three atlas packs.
        "pack:old-world": "oldworld",
        "pack:new-world": "newworld",
        "pack:godforsaken": "godforsaken",
        // The six device packs. The art drops the `device-` qualifier, which is
        // a shelf name rather than part of the product's own.
        "pack:device-classic": "classic",
        "pack:device-wines": "wines",
        "pack:device-vessel": "vessel",
        "pack:device-retrofit": "retrofit",
        "pack:device-cleartech": "cleartech",
        "pack:device-festive": "festive",
        // The three display packs. These *keep* the qualifier, because
        // `classic` is already taken by the device shelf — the two CLASSIC
        // packs are the reason the art is named this way at all.
        "pack:display-classic": "displayclassic",
        "pack:display-retro": "displayvintage",
        "pack:display-emulator": "displayemulator",
        // The five standalone upgrades.
        "pro": "vinodexpro",
        "skins": "chassisskins",
        "lightMode": "screenmodes",
        "workshop": "deviceworkshop",
        "lineage": "grapelineage",
    ]

    /// The drawn cartridge for one entitlement, prefix included, or nil where
    /// there is no art and the code-drawn cartridge stands in.
    public static func stem(for entitlement: Entitlement) -> String? {
        stems[entitlement.id].map { prefix + $0 }
    }
}
