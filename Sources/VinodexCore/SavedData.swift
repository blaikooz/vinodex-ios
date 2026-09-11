import Foundation

/// Every key this app writes to `UserDefaults`, in one place.
///
/// The literals used to live at their point of use — nine files, twenty
/// strings, no way to enumerate them. That was survivable while the answer to
/// "what would a bundle-ID change orphan?" was nobody's problem. It stopped
/// being survivable at AUDIT **M35**: on iOS the bundle ID *is* the container
/// identity, so a new App ID gets an empty defaults database and an empty
/// Application Support directory. There is no migration to write — only an
/// export the user carries across — and an export cannot be written against a
/// list that does not exist.
///
/// Declaring types keep their own `storageKey`, and every call site keeps
/// reading it; the declarations now *derive* from a case here, so the registry
/// and the app cannot disagree. Seven of these are declared in `VinodexUI` and
/// still resolve to a case below for the same reason.
///
/// **Adding a key means adding a case here.** `SavedDataArchiver.export` and
/// `.apply` both switch over `allCases` with no `default:`, so a new case fails
/// to compile in two places rather than silently shipping an archive that drops
/// it. That is the whole reason this type exists rather than twenty field
/// assignments.
public enum SavedDataKey: String, CaseIterable, Sendable {
    // Shelves and ratings — Bookmarks.swift
    case savedShelf          = "bookmarkedEntryIDs"
    case wantToTryShelf      = "wantToTryEntryIDs"
    case triedShelf          = "triedEntryIDs"
    case scannedShelf        = "scannedEntryIDs"
    case scanRecords         = "scanRecords"
    case triedRatings        = "triedRatings"
    // Trail — RecentlyViewed.swift
    case recentlyViewed      = "recentlyViewedEntryIDs"
    // Progress — TastingQuiz.swift, DailyChallenge.swift, DailyPick.swift
    case quizTierUnlocked    = "quizTierUnlocked"
    case dailyStreak         = "dailyStreak"
    case dailyLastDay        = "dailyLastDay"
    case dailyBestStreak     = "dailyBestStreak"
    case revealCursor        = "revealCursor"
    // Entitlements — EntryAccess.swift. Exported, never imported; see
    // `SavedDataArchiver.apply`.
    case starterTierOnly     = "starterTierOnly"
    case grantedEntitlements = "grantedEntitlements"
    // Profile — BookmarksScreen.swift (VinodexUI)
    case displayName         = "userDisplayName"
    // Settings — TypeScale.swift, DexTheme.swift, Haptics.swift, DexSound.swift
    case textScale           = "textScale"
    case uiScale             = "uiScale"
    case lcdMode             = "lcdMode"
    case chassisSkin         = "chassisSkin"

    // MARK: The 0.9.54 registration (release-readiness B1)
    //
    // Twenty-five keys had grown up outside this registry — exam history,
    // custom device builds, the tried-day log, quiz completions, passport
    // and walkthrough ledgers among them — and the backup/restore that is
    // the advertised migration path silently dropped every one. They are
    // archived through the OPAQUE lane (`SavedDataKey.opaque` below): each
    // value round-trips as a plist-coded blob, because its shape belongs to
    // its store and restating twenty-five schemas here would be the drift
    // this file exists to prevent.
    case examResults             = "examResults"
    case examBestPassStreak      = "examBestPassStreak"
    case quizTiersCompleted      = "quizTiersCompleted"
    case triedEntryDays          = "triedEntryDays"
    case customDevices           = "customDevices"
    case backPlateStampOffsets   = "backPlateStampOffsets"
    case marqueeQuickPins        = "marqueeQuickPins"
    case passportSeenBadges      = "passportSeenBadges"
    case passportSeenBadgesSeeded = "passportSeenBadgesSeeded"
    case passportSeenTierRank    = "passportSeenTierRank"
    case passportSeenTierSeeded  = "passportSeenTierSeeded"
    case toolIntrosSeen          = "toolIntrosSeen"
    case firstTimeTriggersSeen   = "firstTimeTriggersSeen"
    case firstTimeTriggersSeeded = "firstTimeTriggersSeeded"
    case vinoSilenced            = "vinoSilenced"
    case vinoMomentLastDay       = "vinoMomentLastDay"
    case vinoMomentStreakMarks   = "vinoMomentStreakMarks"
    case coachmarkReached        = "coachmarkReached"
    case coachmarkOffered        = "coachmarkOffered"
    case coachmarkCompleted      = "coachmarkCompleted"
    case dailyRemindersEnabled   = "dailyRemindersEnabled"
    case inputRVector            = "inputRVector"
    case inputGVector            = "inputGVector"
    case inputBVector            = "inputBVector"
    case inputAVector            = "inputAVector"

    /// The keys archived as opaque plist blobs — see the 0.9.54 block above.
    /// A key here still gets its own `export`/`apply` arm (the exhaustive
    /// switches demand it); the arm routes through the shared blob coder.
    public static let opaque: Set<SavedDataKey> = [
        .examResults, .examBestPassStreak, .quizTiersCompleted,
        .triedEntryDays, .customDevices, .backPlateStampOffsets,
        .marqueeQuickPins, .passportSeenBadges, .passportSeenBadgesSeeded,
        .passportSeenTierRank, .passportSeenTierSeeded, .toolIntrosSeen,
        .firstTimeTriggersSeen, .firstTimeTriggersSeeded, .vinoSilenced,
        .vinoMomentLastDay, .vinoMomentStreakMarks, .coachmarkReached,
        .coachmarkOffered, .coachmarkCompleted, .dailyRemindersEnabled,
        .inputRVector, .inputGVector, .inputBVector, .inputAVector,
    ]
    case hapticsEnabled      = "hapticsEnabled"
    case soundsEnabled       = "soundsEnabled"
    case keepAwakeEnabled    = "keepAwakeEnabled"
    /// The chosen narrator voice identifier (0.9.54). Absent = AUTOMATIC —
    /// the ladder in `NarratorPreference` picks the best installed voice.
    case narratorVoice       = "narratorVoice"
    /// The wine-country globe texture (0.9.55, a test behind a switch).
    case wineGlobe           = "wineGlobe"
}
