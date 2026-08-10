#if canImport(UIKit) && canImport(AVFoundation)
import AVFoundation
import UIKit
import VinodexCore

/// The device's voice — the authored SFX pack (v0.5.6).
///
/// The 0.5.3 single synthesized ping grew back into a small pack, but from
/// *files* this time: the sounds are authored in `art/sfx`,
/// labeled by their intended use, and bundled under `Resources/SFX`. Events
/// without an authored sound (page sweeps, boot) stay deliberately silent until
/// a labeled file arrives — their entry points remain so call sites do not
/// churn. The wrong-answer buzz was one of those; its file arrived in 0.6.8
/// (J3) and `wrong()` plays it.
///
/// Gated at the choke point like `Haptics`, and for the same reason: a call
/// site that checked the setting itself would be the one that forgets to.
/// Button clicks arrive by piggybacking on `Haptics.tap()`, `screenTap()` and
/// `select()` — the two systems share call sites but not a toggle.
///
/// **Which sound goes where is `Haptics`' business, not this file's** (0.6.8,
/// J1/J2). `Sounds.tap()` is Button Tap and `Sounds.select()` is Warm Ping;
/// the rule that the first belongs to the chassis's own buttons and the second
/// to everything the finger does to the LCD is expressed by which `Haptics`
/// entry point a call site uses, because that is where the ~75 call sites
/// already are.
@MainActor
public enum Sounds {
    /// Missing key = **off**: sounds are opt-in (since 0.5.1). The mute
    /// switch still wins — the audio session is `.ambient`.
    public static let storageKey = SavedDataKey.soundsEnabled.rawValue

    /// Via `SettingsCache` (AUDIT **L16**) — this is consulted on every one of
    /// the ~78 feedback call sites, most of which ride a button press.
    private static var enabled: Bool {
        SettingsCache.bool(forKey: storageKey) ?? SettingsDefault.soundsEnabled
    }

    /// Launch is not an interaction; no authored boot chime yet. But launch
    /// *is* where the engine warms up (v0.5.7, F1): the first enabled play
    /// used to pay session activation + decoding all four files + engine
    /// start, synchronously, which landed the first click audibly after its
    /// tap. Priming here moves that cost to the splash moment.
    public static func boot() {
        guard enabled else { return }
        SoundEngine.shared.prime()
    }
    /// The percussive button click.
    public static func tap() { play(.tap) }
    /// The softer selection blip — the warm ping.
    public static func select() { play(.select) }
    /// The quiz's right-answer sting.
    public static func correct() { play(.correct) }
    /// The quiz's wrong-answer sting (0.6.8, J3).
    ///
    /// Silent since 0.5.6 on the argument that silence read better than reusing
    /// a cheerful sound — which was true, and was always a placeholder for the
    /// authored file. It exists now, so the exam's two outcomes have two
    /// voices; a wrong answer that sounded like nothing was the only moment in
    /// the app where a deliberate press produced no feedback at all.
    ///
    /// The call site did not change: `TastingQuizScreen.choose(_:in:)` has
    /// called this on the wrong branch since 0.5.6, which is exactly what
    /// keeping the silent entry point was for.
    public static func wrong() { play(.wrong) }
    /// The orb pressing in — the flip gesture's own voice.
    public static func orb() { play(.orb) }

    private static func play(_ kind: SoundEngine.Kind) {
        guard enabled else { return }
        SoundEngine.shared.play(kind)
    }
}

/// The machinery behind `Sounds`: one engine, the bundled buffers.
///
/// Everything is lazy — nothing is created until the first enabled play — so
/// the app's launch pays nothing for having a voice. Every AVFoundation call
/// is `try?` behind a `broken` flag: a device that refuses an audio session
/// gets a silent app, not a crashed one.
@MainActor
private final class SoundEngine {
    static let shared = SoundEngine()

    /// Raw values are the bundled file stems under `Resources/SFX` — the
    /// artist's labels, kebabed.
    enum Kind: String, CaseIterable {
        case tap = "button-tap"
        case select = "warm-ping"
        case correct = "correct-answer"
        case wrong = "incorrect-answer"
        case orb = "orb-depress"
    }

    private var engine: AVAudioEngine?
    /// Round-robin players so a sting does not cut a click short.
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [Kind: AVAudioPCMBuffer] = [:]
    private var broken = false

    /// Builds the engine ahead of the first play — see `Sounds.boot()`.
    func prime() {
        guard !broken, engine == nil else { return }
        start()
    }

    func play(_ kind: Kind) {
        guard !broken else { return }
        if engine == nil { start() }
        guard let buffer = buffers[kind], !players.isEmpty else { return }

        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        // Nil completion handler on purpose: a handler is a Sendable closure
        // called off the main actor, which is a Swift 6 fight this fire-and-
        // forget playback does not need to have.
        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
    }

    private func start() {
        // Ambient: respects the ring/silent switch and mixes with whatever
        // the user is already listening to — a reference app must never
        // interrupt someone's music to click at them.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        for kind in Kind.allCases {
            guard let url = DexResources.url(named: kind.rawValue, ext: "mp3", in: .sfx),
                  let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: AVAudioFrameCount(file.length)
                  ),
                  (try? file.read(into: buffer)) != nil
            else { continue }
            buffers[kind] = buffer
        }

        // The files come off one production pipeline, so one format serves
        // every connection; a missing set leaves the engine unstarted and the
        // app silent rather than wrong. A single missing file is skipped by the
        // loop above and simply never plays — which is why adding
        // `incorrect-answer` in 0.6.8 needed no other change here.
        guard let format = buffers.values.first?.format else {
            broken = true
            return
        }

        let engine = AVAudioEngine()
        for _ in 0..<3 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        do {
            try engine.start()
        } catch {
            broken = true
            players.removeAll()
            return
        }
        self.engine = engine
    }
}
#endif
