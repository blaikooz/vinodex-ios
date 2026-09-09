import Testing
@testable import VinodexCore

/// The narrator-choosing rule (0.9.54). `VinoVoice` cannot be tested from
/// here — it is UIKit-gated and the Mac's voice inventory is not the
/// phone's — which is exactly why the rule lives in Core over plain values.
@Suite("Narrator preference")
struct NarratorPreferenceTests {
    // The device inventory as fixtures. IDs are the real ones where reality
    // has one, because the ladder matches on them.
    private let reed = NarratorCandidate(
        id: "com.apple.eloquence.en-US.Reed", language: "en-US", quality: 1, isMale: true)
    private let daniel = NarratorCandidate(
        id: "com.apple.voice.super-compact.en-GB.Daniel", language: "en-GB", quality: 1, isMale: true)
    private let ralph = NarratorCandidate(
        id: "com.apple.speech.synthesis.voice.Ralph", language: "en-US", quality: 1, isMale: true)
    private let tomEnhanced = NarratorCandidate(
        id: "com.apple.voice.enhanced.en-US.Tom", language: "en-US", quality: 2, isMale: true)
    private let avaPremium = NarratorCandidate(
        id: "com.apple.voice.premium.en-US.Ava", language: "en-US", quality: 3, isMale: false)
    private let samanthaDefault = NarratorCandidate(
        id: "com.apple.voice.compact.en-US.Samantha", language: "en-US", quality: 1, isMale: false)
    private let thomasFrench = NarratorCandidate(
        id: "com.apple.voice.compact.fr-FR.Thomas", language: "fr-FR", quality: 1, isMale: true)

    @Test("an explicit pick that is installed always wins")
    func explicitPickWins() {
        // Even over a premium voice — a pick is a pick.
        let chosen = NarratorPreference.choose(
            from: [reed, avaPremium, samanthaDefault],
            preferredID: samanthaDefault.id, languageCode: "en-US")
        #expect(chosen == samanthaDefault.id)
    }

    @Test("a pick whose voice was deleted falls back to automatic, not silence")
    func deletedPickFallsBack() {
        let chosen = NarratorPreference.choose(
            from: [reed, daniel],
            preferredID: "com.apple.voice.premium.en-US.Gone", languageCode: "en-US")
        #expect(chosen == reed.id)
    }

    @Test("automatic prefers downloaded quality: premium over enhanced over the ladder")
    func qualityLadder() {
        #expect(NarratorPreference.choose(
            from: [reed, tomEnhanced, avaPremium], preferredID: nil, languageCode: "en-US")
            == avaPremium.id)
        #expect(NarratorPreference.choose(
            from: [reed, tomEnhanced], preferredID: nil, languageCode: "en-US")
            == tomEnhanced.id)
    }

    @Test("within a quality tier, a male voice wins the tie — Vinobot's register")
    func maleTieBreak() {
        let ivyPremium = NarratorCandidate(
            id: "com.apple.voice.premium.en-US.Ivy", language: "en-US", quality: 3, isMale: false)
        let leePremium = NarratorCandidate(
            id: "com.apple.voice.premium.en-AU.Lee", language: "en-AU", quality: 3, isMale: true)
        #expect(NarratorPreference.choose(
            from: [ivyPremium, leePremium, reed], preferredID: nil, languageCode: "en-US")
            == leePremium.id)
    }

    @Test("with nothing downloaded, the 0.9.53 ladder holds: Reed, then Daniel, then Ralph")
    func defaultLadderHolds() {
        #expect(NarratorPreference.choose(
            from: [ralph, daniel, reed, samanthaDefault], preferredID: "", languageCode: "en-US")
            == reed.id)
        // The simulator's shelf — no Eloquence at all.
        #expect(NarratorPreference.choose(
            from: [ralph, daniel, samanthaDefault], preferredID: nil, languageCode: "en-US")
            == daniel.id)
        #expect(NarratorPreference.choose(
            from: [ralph, samanthaDefault], preferredID: nil, languageCode: "en-US")
            == ralph.id)
    }

    @Test("english outranks the device locale — the catalog is written in english")
    func englishOverLocale() {
        // A French device with Tom downloaded still hears Tom read English text.
        #expect(NarratorPreference.choose(
            from: [thomasFrench, tomEnhanced], preferredID: nil, languageCode: "fr-FR")
            == tomEnhanced.id)
        // But with no English voice at all, a male voice in the player's
        // language beats silence.
        #expect(NarratorPreference.choose(
            from: [thomasFrench], preferredID: nil, languageCode: "fr-FR")
            == thomasFrench.id)
    }

    @Test("an empty shelf yields nil — the system default voice, which never fails")
    func emptyShelf() {
        #expect(NarratorPreference.choose(from: [], preferredID: nil, languageCode: "en-US") == nil)
    }
}
