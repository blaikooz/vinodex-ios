#if canImport(SwiftUI) && canImport(UIKit)
import AVFoundation
import Observation
import VinodexCore

/// **Vinobot's literal voice** (checkpoint V3, round three): the system
/// speech synthesizer reading his take aloud on an entry page.
///
/// On-device and offline, like everything else here — `AVSpeechSynthesizer`
/// ships with the OS and costs nothing at rest. One shared instance because
/// two robots talking over each other is a bug wearing a feature's clothes:
/// starting a new line stops the old one, and `stop()` is idempotent.
///
/// The delivery is tuned, lightly, to the character: a touch under the
/// default rate (he reads a pokedex entry, he does not race it) and a
/// touch up in pitch. Deliberately no exotic voice selection — the
/// player's own language/voice settings win, which also keeps VoiceOver
/// users' expectations intact.
///
/// This is a player-summoned voice, so the QUIET switch does not gate it:
/// silence governs what he volunteers, not what he is asked.
@MainActor
@Observable
public final class VinoVoice: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = VinoVoice()

    private let synthesizer = AVSpeechSynthesizer()
    /// True while he is reading — the button flips to a stop glyph.
    public private(set) var speaking = false

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    public func speak(_ text: String) {
        if speaking {
            stop()
            return
        }
        startUtterance(text)
    }

    /// The picker's audition: always (re)starts, never toggles off — tapping
    /// a second voice while the first is still talking should switch, not
    /// silence.
    public func preview(_ text: String) {
        if speaking { synthesizer.stopSpeaking(at: .immediate) }
        startUtterance(text)
    }

    private func startUtterance(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.narratorVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.02
        synthesizer.speak(utterance)
        speaking = true
    }

    /// The reading voice, resolved **per utterance** since 0.9.54 — the
    /// NARRATOR picker can change it mid-session, and Spoken Content
    /// downloads can land while the app is open.
    ///
    /// The rule lives in `NarratorPreference` (Core, testable): an explicit
    /// pick that is still installed wins; otherwise the best downloaded
    /// English voice (Premium over Enhanced — the maintainer's
    /// highest-quality-installed ruling, 2026-09-08, standing in for the
    /// unreachable Siri voice); otherwise the 0.9.53 ladder — Reed
    /// (en-US Eloquence, every real device), Daniel then Ralph (what the
    /// simulator runtime actually ships), male-in-language, then nil, which
    /// never fails. Fred is deliberately no rung: the maintainer retired the
    /// robot delivery.
    static func narratorVoice() -> AVSpeechSynthesisVoice? {
        let chosen = NarratorPreference.choose(
            from: AVSpeechSynthesisVoice.speechVoices().map(NarratorCandidate.init),
            preferredID: AppSettings.shared.narratorVoice,
            languageCode: AVSpeechSynthesisVoice.currentLanguageCode()
        )
        return chosen.flatMap(AVSpeechSynthesisVoice.init(identifier:))
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speaking = false
    }

    // MARK: AVSpeechSynthesizerDelegate

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in self.speaking = false }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in self.speaking = false }
    }
}

extension NarratorCandidate {
    /// The live inventory, flattened to what the choosing rule compares.
    init(_ voice: AVSpeechSynthesisVoice) {
        let quality: Int
        switch voice.quality {
        case .premium: quality = 3
        case .enhanced: quality = 2
        default: quality = 1
        }
        self.init(
            id: voice.identifier,
            language: voice.language,
            quality: quality,
            isMale: voice.gender == .male
        )
    }
}

/// One row of the SETTINGS ▸ NARRATOR picker — the installed inventory,
/// pre-shaped so the panel never touches `AVFoundation` itself.
public struct NarratorOption: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    /// "EN-US", "EN-GB", … — the label the row wears beside the name.
    public let language: String
    /// "ENHANCED" or "PREMIUM" for downloaded voices; nil for the built-ins.
    public let qualityLabel: String?

    /// The pickable voices: English first (the catalog's language), best
    /// quality at the top so a downloaded voice is the first thing seen,
    /// then name order. Novelty voices (Bells, Zarvox and their circus —
    /// `isNoveltyVoice`) are left out; a wine encyclopedia read by Bubbles
    /// is a screenshot, not a setting.
    @MainActor
    public static func installed() -> [NarratorOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && !$0.isNoveltyVoice }
            .sorted { a, b in
                if a.quality.rawValue != b.quality.rawValue {
                    return a.quality.rawValue > b.quality.rawValue
                }
                if a.name != b.name { return a.name < b.name }
                return a.identifier < b.identifier
            }
            .map { voice in
                let quality: String?
                switch voice.quality {
                case .premium: quality = "PREMIUM"
                case .enhanced: quality = "ENHANCED"
                default: quality = nil
                }
                return NarratorOption(
                    id: voice.identifier,
                    name: voice.name.uppercased(),
                    language: voice.language.uppercased(),
                    qualityLabel: quality
                )
            }
    }

    /// What the NARRATOR row says when AUTOMATIC is in charge: the voice the
    /// ladder would pick right now, by name.
    @MainActor
    public static func automaticChoiceName() -> String? {
        VinoVoice.narratorVoice()?.name.uppercased()
    }
}

private extension AVSpeechSynthesisVoice {
    /// The legacy MacinTalk novelty set shares one identifier prefix and a
    /// `.default` quality; the real voices live elsewhere. Eloquence's Ralph
    /// (a ladder rung) is NOT under this prefix, so the filter cannot cost
    /// him — see `NarratorPreference.ladder`.
    var isNoveltyVoice: Bool {
        identifier.hasPrefix("com.apple.speech.synthesis.voice.")
            && identifier != "com.apple.speech.synthesis.voice.Ralph"
    }
}
#endif
