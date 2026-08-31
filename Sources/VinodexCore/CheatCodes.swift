import Foundation

/// One unlock code (0.7.3, A4).
public struct CheatCode: Sendable, Hashable, Identifiable {
    /// What you type. Uppercase A–Z in the table; matching is forgiving — see
    /// `CheatCode.match(_:)`.
    public let code: String
    /// What entering it grants, written through `AccessStore` like any other
    /// unlock (F1).
    public let grants: Entitlement
    /// The console's success line. Short — it is printed in the retro face.
    public let reveal: String

    public var id: String { code }

    public init(code: String, grants: Entitlement, reveal: String) {
        self.code = code
        self.grants = grants
        self.reveal = reveal
    }
}

/// The code table (0.7.3, A4; emptied 0.9.4).
///
/// **Empty on purpose, and the console's door went with it.** The first
/// version build carries no unlockables a code could grant: the shop is off
/// the shell until StoreKit backs it, the workshop is shopward-bound with it,
/// and the cosmetics the wine-word codes granted are free or trimmed to the
/// starter set. A table of codes against surfaces that are not on the device
/// would be exactly the failure mode this type's original note warned
/// against — a code that is documented, accepted, reported as unlocked, and
/// changes nothing. The CHEAT CODES row left SETTINGS > DEVICE in the same
/// batch, so nothing routes here; the console screen and this machinery stay
/// because the StoreKit phase gets its unlock story back, and `match` over an
/// empty table is honestly nil rather than a door that lies.
///
/// The five wine-word codes (CELLARDOOR, PHOSPHOR, GRANDCRU, MAINFRAME,
/// GARAGISTE) are recoverable at tag v0.9.3, granting rules and all.
public enum CheatCodes: Sendable {
    public static let all: [CheatCode] = []

    /// The egg id the boot screen checks for its extra POST lines (A1).
    ///
    /// A constant rather than a string literal in two files, because an egg
    /// whose id is misspelled at one of its two ends is granted, persisted, and
    /// silently inert — the failure this whole type is written to avoid.
    public static let verboseBoot = "verboseBoot"

    /// The egg id that puts the SHOP tile on the settings grid (0.9.4).
    ///
    /// A constant for the reason `verboseBoot` is: the grid, the lamp chooser
    /// and the chassis lamps all check it through `AccessStore.shopIsRevealed`.
    /// **Nothing in this build grants it** — the code table above is empty and
    /// the DEV panel's door is gone — so the shop is hidden unconditionally
    /// until the StoreKit phase wires a reveal back up. The seam is kept
    /// rather than the check hard-coded to false, because that phase's first
    /// job would otherwise be re-threading three surfaces this one already
    /// threads.
    public static let shopfront = "shopfront"

    /// The code a typed string is, if any.
    ///
    /// **Forgiving on purpose.** Someone typing a cheat code on a phone keyboard
    /// gets autocapitalisation, an autocorrect space, and a trailing one from the
    /// space bar; rejecting `"cellar door "` when `CELLARDOOR` was clearly meant
    /// makes the console feel broken rather than strict. Case, whitespace and
    /// punctuation are all discarded, so `cellar-door` works too. What is *not*
    /// forgiven is a wrong word: there is no fuzzy matching, because "did you
    /// mean" on a secret is not a secret.
    public static func match(_ typed: String) -> CheatCode? {
        let key = normalize(typed)
        guard !key.isEmpty else { return nil }
        return all.first { normalize($0.code) == key }
    }

    /// Letters and digits only, uppercased.
    ///
    /// Not `TextNormalize.key`: that one is built for matching catalog prose and
    /// folds diacritics and collapses runs of whitespace into single spaces,
    /// which is the right normalisation for `Château` and the wrong one for a
    /// password-shaped string where a space is simply noise.
    static func normalize(_ value: String) -> String {
        String(value.uppercased().filter { $0.isLetter || $0.isNumber })
    }
}
