# g-features

Features dropped, deferred or superseded while integrating `upstream/testing`
into this branch, so that nothing is lost silently. One entry per item, with
enough detail to re-implement without re-deriving it.

Status values: **DROPPED** (gone, re-add wanted) · **SUPERSEDED** (upstream ships
a better version, no action) · **DEFERRED** (deliberately postponed).

---

## G1 · TODAY strip on the main menu — **DROPPED**

**What it was.** A two-button strip under the four category tiles on
`MainMenuScreen`, carrying WHAT'S THAT? and the daily CHALLENGE. The challenge
pill showed a tick when the day's paper was already passed and a badge with the
current streak count.

**Why it existed.** AUDIT **M23**. Both daily features were reachable only
through the cog, then TOOLS, then a tile — three taps down a path nobody walks
daily — so the app's only two reasons to come back tomorrow were invisible from
the screen you land on. The streak was worse: it was printed on the profile, so
the number counting your consecutive days could not be seen without going
looking for it.

**Why it went.** Upstream's 0.8.4 redesign rebuilt the menu as a four-tile
cluster set into a moulded housing plate (`housing`, `Self.channel`,
`contentShift`), and the merge took that side because this branch's version
referenced a `Livery` type the redesign deleted.

**How to re-add.** Below the housing, not inside it — the original reasoning
still holds and is worth preserving verbatim: *a strip rather than a fifth tile,
because the four categories are what this app is, and demoting one of them to
make room for a minigame would trade a worse problem for this one.* Every
dependency survives upstream: `StreakStore` (in `DailyChallenge.swift`),
`DexRoute.dailyGrape`, `DexRoute.dailyChallenge`. The old implementation is
`todayStrip` + `dailyPill` at `wip-local:Sources/VinodexUI/Screens/MainMenuScreen.swift`.
Roughly 20 lines plus the pill helper.

**Note.** The WHAT'S THAT? pill routed to `.dailyGrape`. Upstream replaced
`DailyGrapeScreen` with `WhatsThatScreen` (see G2); the route id is unchanged, so
the pill's action does not need editing.

---

## G2 · `DailyGrapeScreen` — **SUPERSEDED**

Upstream deleted `Sources/VinodexUI/Screens/DailyGrapeScreen.swift` and ships
`WhatsThatScreen.swift` in its place. This branch's local edits to the old screen
were discarded by decision on integration. `DexRoute.dailyGrape` survives, so
nothing that links to it needs changing. No action wanted.

---

## G3 · `SavedDataKey` registry no longer covers every persisted key — **DROPPED**

**What it was.** `Sources/VinodexCore/SavedData.swift` — a 20-case enum that is
the single registry of every `UserDefaults` key the app writes, with
`SavedDataArchiver.export`/`.apply` switching over it with no `default:` so that
adding a key is a compile error until the archive handles it. It exists only on
this branch; upstream has no `SavedData.swift` at all.

**What happened.** Upstream introduced keys the registry does not know about,
and declares them as string literals in their own types:

| Key | Declared at |
|---|---|
| `grantedEntitlements` | `LocalEntitlementStore.storageKey` — same string the registry already holds, now written from two places |
| `triedEntryDays` | `BookmarkStore.triedDaysKey` |
| `quizTiersCompleted` | `QuizProgress.completedKey` |

The merge took upstream's declarations, because they carry new behaviour the
registry cannot supply. Values are unchanged, so nothing a user has stored is
affected and there is no migration to write.

**Why it matters.** Two of these are now outside BACK UP / RESTORE, so a restore
silently loses a tried-day history and a completed-exam list. And
`grantedEntitlements` having two independent declarations of the same literal is
exactly the drift the registry was built to prevent.

**How to re-add.** Add `triedEntryDays` and `quizTiersCompleted` as
`SavedDataKey` cases — the archive's `default`-less switches will refuse to
compile until `export` and `apply` both handle them, which is the mechanism
working as designed. Then point `LocalEntitlementStore.storageKey` at
`SavedDataKey.grantedEntitlements.rawValue` so there is one source of truth
again. Note `apply` must keep refusing to import entitlements — a restorable
grant is a free unlock for anyone with a text editor.
