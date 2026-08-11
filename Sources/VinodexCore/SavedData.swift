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
    case hapticsEnabled      = "hapticsEnabled"
    case soundsEnabled       = "soundsEnabled"
    case keepAwakeEnabled    = "keepAwakeEnabled"
}
