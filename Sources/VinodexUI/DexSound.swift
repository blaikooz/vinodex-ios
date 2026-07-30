#if canImport(UIKit) && canImport(AVFoundation)
import AVFoundation
import UIKit

/// The device's voice: a synthesized chiptune sound pack.
///
/// Synthesized rather than bundled, deliberately — short square waves with a
/// decay envelope *are* the period-correct sound for this hardware, they cost
/// no asset files, and every parameter is a number in this file rather than a
/// .wav somebody has to re-produce to tweak.
///
/// Gated at the choke point like `Haptics`, and for the same reason: a call
/// site that checked the setting itself would be the one that forgets to.
/// Button clicks arrive by piggybacking on `Haptics.tap()`/`select()` — the
/// two systems share call sites but not a toggle.
@MainActor
public enum Sounds {
    /// Missing key = on: the clicks are part of the device's character, so
    /// only an explicit opt-out disables them. The mute switch still wins —
    /// the audio session is `.ambient`.
    public static let storageKey = "soundsEnabled"

    private static var enabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: storageKey) == nil || defaults.bool(forKey: storageKey)
    }

    /// The power-on arpeggio.
    public static func boot() { play(.boot) }
    /// The percussive button click.
    public static func tap() { play(.tap) }
    /// The softer selection blip.
    public static func select() { play(.select) }
    /// The screen-change sweep.
    public static func page() { play(.page) }
    /// The quiz's right-answer sting.
    public static func correct() { play(.correct) }
    /// The quiz's wrong-answer buzz.
    public static func wrong() { play(.wrong) }

    private static func play(_ kind: SoundEngine.Kind) {
        guard enabled else { return }
        SoundEngine.shared.play(kind)
    }
}

/// The machinery behind `Sounds`: one engine, a few pre-rendered buffers.
///
/// Everything is lazy — nothing is created until the first enabled play — so
/// the app's launch pays nothing for having a voice. Every AVFoundation call
/// is `try?` behind a `broken` flag: a device that refuses an audio session
/// gets a silent app, not a crashed one.
@MainActor
private final class SoundEngine {
    static let shared = SoundEngine()

    enum Kind: CaseIterable {
        case boot, tap, select, page, correct, wrong
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
        case .tap:
            [Note(frequency: 1100, duration: 0.03, decay: 0.008, sweepTo: nil)]
        case .select:
            [Note(frequency: 1568, duration: 0.06, decay: 0.02, sweepTo: nil)]
        case .boot:
            // C5-E5-G5-C6, the classic power-on arpeggio.
            [
                Note(frequency: 523.25, duration: 0.09, decay: 0.06, sweepTo: nil),
                Note(frequency: 659.25, duration: 0.09, decay: 0.06, sweepTo: nil),
                Note(frequency: 783.99, duration: 0.09, decay: 0.06, sweepTo: nil),
                Note(frequency: 1046.50, duration: 0.16, decay: 0.10, sweepTo: nil),
            ]
        case .page:
            [Note(frequency: 1200, duration: 0.12, decay: 0.08, sweepTo: 300)]
        case .correct:
            // C6-E6-G6, a major sting.
            [
                Note(frequency: 1046.50, duration: 0.08, decay: 0.05, sweepTo: nil),
                Note(frequency: 1318.51, duration: 0.08, decay: 0.05, sweepTo: nil),
                Note(frequency: 1567.98, duration: 0.14, decay: 0.09, sweepTo: nil),
            ]
        case .wrong:
            [Note(frequency: 110, duration: 0.25, decay: 0.18, sweepTo: nil)]
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
