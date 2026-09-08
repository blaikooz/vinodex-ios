#if canImport(SwiftUI) && canImport(UIKit)
import AVFoundation
import Observation

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
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.vinobotVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.02
        synthesizer.speak(utterance)
        speaking = true
    }

    /// The reading voice, chosen once. **Reed** by maintainer order
    /// (2026-09-08, superseding the same day's Tom ruling): a male
    /// Eloquence voice that ships in EVERY default install, so the narrator
    /// is identical on a fresh tester's phone, the sim, and this device —
    /// no download, no per-device drift. The ladder below it survives for
    /// non-English devices:
    ///
    /// 1. **Reed** (en-US Eloquence) — on every real iOS 17+ device.
    /// 2. **Daniel** (en-GB) then **Ralph** (en-US) — the natural male
    ///    voices the SIMULATOR runtime actually ships; an in-sim query
    ///    (2026-09-08) proved Eloquence is absent there, which is how the
    ///    robot kept talking after the Reed ruling.
    /// 3. Any male voice for the player's own language, then the system
    ///    default (nil), which never fails. Fred is deliberately no rung:
    ///    the maintainer retired the robot delivery.
    static let vinobotVoice: AVSpeechSynthesisVoice? = {
        for id in [
            "com.apple.eloquence.en-US.Reed",
            "com.apple.voice.super-compact.en-GB.Daniel",
            "com.apple.speech.synthesis.voice.Ralph",
        ] {
            if let voice = AVSpeechSynthesisVoice(identifier: id) { return voice }
        }
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        return AVSpeechSynthesisVoice.speechVoices().first {
            $0.language.hasPrefix(language.prefix(2)) && $0.gender == .male
        }
    }()

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
#endif
