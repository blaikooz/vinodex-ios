#if canImport(UIKit) && canImport(AVFoundation)
import AVFoundation
import UIKit

/// The device's voice — for v0.5.1, a single synthesized ping.
///
/// Synthesized rather than bundled, deliberately — short square waves with a
/// decay envelope *are* the period-correct sound for this hardware, they cost
/// no asset files, and every parameter is a number in this file rather than a
/// .wav somebody has to re-produce to tweak.
///
/// The full pack (boot arpeggio, page sweep, quiz stings) is deliberately
/// parked: one interaction sound is the ship decision until the pack earns
/// its way back note by note. The per-event entry points stay so the ~60
/// call sites do not churn when it does.
///
/// Gated at the choke point like `Haptics`, and for the same reason: a call
/// site that checked the setting itself would be the one that forgets to.
/// Button clicks arrive by piggybacking on `Haptics.tap()`/`select()` — the
/// two systems share call sites but not a toggle.
@MainActor
public enum Sounds {
    /// Missing key = **off**: sounds are opt-in from v0.5.1 (they shipped
    /// opt-out in 0.5.0 and the default was wrong). The mute switch still
    /// wins — the audio session is `.ambient`.
    public static let storageKey = "soundsEnabled"

    private static var enabled: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }

    /// Launch is not an interaction; the boot chime is parked with the rest
    /// of the pack.
    public static func boot() {}
    /// The percussive button click.
    public static func tap() { play(.ping) }
    /// The softer selection blip.
    public static func select() { play(.ping) }
    /// The screen-change sweep.
    public static func page() { play(.ping) }
    /// The quiz's right-answer sting.
    public static func correct() { play(.ping) }
    /// The quiz's wrong-answer buzz.
    public static func wrong() { play(.ping) }

    private static func play(_ kind: SoundEngine.Kind) {
        guard enabled else { return }
        SoundEngine.shared.play(kind)
    }
}

/// The machinery behind `Sounds`: one engine, one pre-rendered buffer.
///
/// Everything is lazy — nothing is created until the first enabled play — so
/// the app's launch pays nothing for having a voice. Every AVFoundation call
/// is `try?` behind a `broken` flag: a device that refuses an audio session
/// gets a silent app, not a crashed one.
@MainActor
private final class SoundEngine {
    static let shared = SoundEngine()

    enum Kind: CaseIterable {
        case ping
    }

    private static let sampleRate = 44_100.0

    private var engine: AVAudioEngine?
    /// Round-robin players so a page sweep does not cut a click short.
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [Kind: AVAudioPCMBuffer] = [:]
    private var broken = false

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

        let engine = AVAudioEngine()
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: Self.sampleRate, channels: 1
        ) else {
            broken = true
            return
        }
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

        for kind in Kind.allCases {
            buffers[kind] = render(kind, format: format)
        }
    }

    // MARK: Synthesis

    /// A note in the pack: square wave at `frequency`, `duration` seconds,
    /// exponential decay with time constant `decay`. A nil `sweepTo` holds
    /// the pitch; otherwise the frequency glides there over the note.
    private struct Note {
        var frequency: Double
        var duration: Double
        var decay: Double
        var sweepTo: Double?
    }

    private func score(_ kind: Kind) -> [Note] {
        switch kind {
        // The slider ping — G6, short, with a fast decay. This was the pack's
        // `select` blip, kept because it is the one that read as the device's
        // own voice rather than as a sound effect.
        case .ping:
            [Note(frequency: 1568, duration: 0.06, decay: 0.02, sweepTo: nil)]
        }
    }

    private func render(_ kind: Kind, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let notes = score(kind)
        let totalFrames = notes.reduce(0) { $0 + Int($1.duration * Self.sampleRate) }
        guard totalFrames > 0,
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)
              ),
              let samples = buffer.floatChannelData?[0]
        else { return nil }

        let amplitude: Float = 0.18
        var frame = 0
        for note in notes {
            let frames = Int(note.duration * Self.sampleRate)
            // Integrated phase rather than f(t)·t, so a sweep glides instead
            // of chirping.
            var phase = 0.0
            for i in 0..<frames {
                let t = Double(i) / Self.sampleRate
                let progress = Double(i) / Double(frames)
                let frequency = note.sweepTo.map {
                    note.frequency + (($0 - note.frequency) * progress)
                } ?? note.frequency
                phase += frequency / Self.sampleRate
                let square: Float = sin(2 * .pi * phase) >= 0 ? 1 : -1
                let envelope = Float(exp(-t / note.decay))
                samples[frame + i] = square * envelope * amplitude
            }
            frame += frames
        }
        buffer.frameLength = AVAudioFrameCount(totalFrames)
        return buffer
    }
}
#endif
