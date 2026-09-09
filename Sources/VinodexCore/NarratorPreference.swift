import Foundation

/// **Who reads the entries aloud** — the choosing rule, separated from
/// `AVFoundation` so it can be tested on a machine whose voice inventory is
/// not the phone's (0.9.54, the maintainer's narrator ask).
///
/// The background: Siri's own voice is not exposed to third-party apps at
/// all, so "use the Siri voice" is not writable. What *is* writable is the
/// next best thing the maintainer approved instead — prefer the
/// highest-quality voice actually installed (a Premium or Enhanced voice the
/// user downloaded in iOS Settings ▸ Accessibility ▸ Spoken Content), and a
/// NARRATOR picker in Settings for choosing any installed voice explicitly.
///
/// `VinoVoice` maps the live `AVSpeechSynthesisVoice` inventory into
/// `NarratorCandidate` values and asks this type to choose; the rule itself
/// never touches the synthesizer.
public struct NarratorCandidate: Sendable, Equatable {
    public let id: String
    public let language: String
    /// 1 = default, 2 = enhanced, 3 = premium — `AVSpeechSynthesisVoiceQuality`
    /// flattened to something comparable.
    public let quality: Int
    public let isMale: Bool

    public init(id: String, language: String, quality: Int, isMale: Bool) {
        self.id = id
        self.language = language
        self.quality = quality
        self.isMale = isMale
    }
}

public enum NarratorPreference {
    /// The stored value that means "no explicit pick" — the ladder decides.
    /// Stored as an *absent key* rather than a stored empty string; see
    /// `AppSettings.narratorVoice`.
    public static let automatic = ""

    /// The 0.9.53 ladder, preserved verbatim as the tie-break among
    /// default-quality voices: Reed (en-US Eloquence, every real device),
    /// then Daniel and Ralph (what the simulator runtime actually ships —
    /// the in-sim query of 2026-09-08 proved Eloquence absent there).
    public static let ladder = [
        "com.apple.eloquence.en-US.Reed",
        "com.apple.voice.super-compact.en-GB.Daniel",
        "com.apple.speech.synthesis.voice.Ralph",
    ]

    /// The identifier to hand the synthesizer, or nil for the system default.
    ///
    /// Order of authority:
    /// 1. An explicit pick that is still installed. A pick that has been
    ///    deleted (voices can be removed in iOS Settings) falls through to
    ///    automatic rather than going silent — but is *not* erased, so
    ///    reinstalling the voice brings the narrator back.
    /// 2. The best *upgraded* English voice: highest quality above default,
    ///    male first within a quality (Vinobot is male-charactered),
    ///    identifier order as the final deterministic tie-break.
    ///    English regardless of device locale, because the text he reads is
    ///    the catalog's, and the catalog is written in English.
    /// 3. The ladder, in order.
    /// 4. Any English male at default quality, then any male in the player's
    ///    language, then nil — the system default voice, which never fails.
    public static func choose(
        from candidates: [NarratorCandidate],
        preferredID: String?,
        languageCode: String
    ) -> String? {
        if let preferredID, !preferredID.isEmpty,
           candidates.contains(where: { $0.id == preferredID }) {
            return preferredID
        }

        let english = candidates.filter { $0.language.hasPrefix("en") }
        if let upgraded = english
            .filter({ $0.quality > 1 })
            .sorted(by: { a, b in
                if a.quality != b.quality { return a.quality > b.quality }
                if a.isMale != b.isMale { return a.isMale }
                return a.id < b.id
            })
            .first {
            return upgraded.id
        }

        for id in ladder where candidates.contains(where: { $0.id == id }) {
            return id
        }

        if let fallback = english.first(where: { $0.isMale }) {
            return fallback.id
        }
        let prefix = languageCode.prefix(2)
        return candidates.first { $0.language.hasPrefix(prefix) && $0.isMale }?.id
    }
}
