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

/// The code table (0.7.3, A4).
///
/// **Every code here does something today.** The temptation in a cheat console
/// is to ship a long list against features that do not exist yet, which produces
/// the one failure mode a cheat console cannot survive: a code that is
/// documented, accepted, reported as unlocked, and changes nothing. Four codes,
/// four visible effects. 0.7.3b and 0.7.3c add theirs when they add the things
/// they unlock.
///
/// **They grant real entitlements, not a separate "cheats" flag.** That is F1's
/// whole argument — an unlock and a purchase are the same question asked of the
/// same store — and it has a practical edge here: CELLARDOOR and the shopfront
/// grant the identical `.skins` bundle, so the picker cannot end up with two
/// notions of whether you have it.
///
/// The codes are wine words rather than `IDDQD`-style nonsense: this device is a
/// wine encyclopedia pretending to be a handheld, and a code you can half-guess
/// from the subject matter is a better easter egg than one you can only be told.
public enum CheatCodes: Sendable {
    public static let all: [CheatCode] = [
        CheatCode(
            code: "CELLARDOOR",
            grants: .skins,
            reveal: "ALL CHASSIS SKINS"
        ),
        CheatCode(
            code: "PHOSPHOR",
            grants: .lightMode,
            reveal: "ALL SCREEN MODES"
        ),
        CheatCode(
            code: "GRANDCRU",
            grants: .pro,
            reveal: "EVERYTHING UNLOCKED"
        ),
        CheatCode(
            code: "MAINFRAME",
            grants: .easterEgg(CheatCodes.verboseBoot),
            reveal: "VERBOSE BOOT"
        ),
    ]

    /// The egg id the boot screen checks for its extra POST lines (A1).
    ///
    /// A constant rather than a string literal in two files, because an egg
    /// whose id is misspelled at one of its two ends is granted, persisted, and
    /// silently inert — the failure this whole type is written to avoid.
    public static let verboseBoot = "verboseBoot"

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
