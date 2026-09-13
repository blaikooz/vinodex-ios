# Spaced repetition — a plan

Written against the code as it stands at v0.9.56, not from a blank page. Every
count below was measured; where something already exists it is named, because
most of this plan is wiring existing parts together rather than building new
ones.

This is the engineering half. The content half — the six subjects the exam
tests and the catalog never teaches — is sommbot's, and is planned separately
in `data-review/`.

---

## 1. The thing that blocks everything

**The app has no per-question history.** `ExamProgress.ExamResult` records the
*paper*:

```swift
public struct ExamResult { tier, correct, length, passed, day, categories }
```

`categories` is `[String: ExamCategoryTally]` and a tally is `(right, asked)`.
So the app knows you scored 24/30 and that you went 3/5 on FAULTS. It does not
know **which** question you missed, and it never has — a grep across
`VinodexCore` for `questionID`, `perQuestion`, `missedQuestions` and their
neighbours returns nothing.

A scheduler needs the opposite: one row per *answer*, forever. Nothing in the
current model can be upgraded into that, so this is step one and everything
else waits on it.

The good news is that the hard part of the surrounding machinery is already
built. `DailyPick.dayIndex(for:calendar:)` returns days since epoch and is
already the unit `ExamResult.day` is stored in — which is exactly the unit
FSRS schedules in, so no new time model is needed.

---

## 2. What a card is

Two decks exist today and they answer different problems.

**The hand-authored bank** — `shared/data/exam.ts`, 437 questions, sixteen
categories, three tiers, seven formats. Authored, anchored to catalog ids,
and finite.

**The generator** — `TastingQuiz` in Core already builds questions *from* the
catalog: `grapeQuestion`, `regionQuestion`, `styleQuestion`, each behind a
tier-eligibility filter. Its own note is the reason it exists: a generated
question "cannot contradict an entry", where a hand-authored one can.

Use both, and the deck-exhaustion problem solves itself. 437 authored cards is
perhaps six weeks for a keen user; 530 entries through the generator is an
order of magnitude more, and it grows every time sommbot lands a batch.

**Card identity** is the thing to get right on day one, because it is what the
review history is keyed on and it is expensive to change later:

- authored: the question's own `id` from the bank.
- generated: a stable composite of `(entryID, axis)` — *not* the generated
  prompt text, which changes whenever the catalog prose is edited. The entry
  and the thing being asked about it are the durable pair.

A card's history must survive the catalog being regenerated. Keying on prose
would silently reset everyone's progress on the next data batch.

---

## 3. The algorithm: FSRS-6, implemented here

**Choose FSRS over SM-2 or Leitner.** FSRS models three variables per card
(stability, difficulty, retrievability) against 17–21 trained weights, fit on
700M+ real reviews; benchmarks put it at 20–30% fewer reviews than SM-2 for the
same retention. Anki has shipped it as the default for new profiles since
23.12. SM-2's rigidity is the specific thing that makes it worse: one set of
curves for every learner.

**Implement it in `VinodexCore` rather than adding a dependency.** Three
reasons, all of them house constraints rather than preference:

1. The package is deliberately dependency-free, and `VinodexCore` is
   Foundation-only precisely so it builds and tests on Linux without a Darwin
   SDK. That is what makes the free CI runners possible.
2. FSRS is a short algorithm — a handful of formulas plus a table of default
   weights. There is far less of it than there is of the `LWINIndex` loader
   already in Core.
3. In Core it is unit-testable on every CI job, which a dependency's internals
   would not be.

**Ship the published default weights and do not train.** FSRS with defaults
already beats SM-2, and per-user optimisation would mean either a training
implementation or a network call — the app does neither, and the label reader's
whole design argument is that 185,000 wines match with no network at all.

**Licensing — check the conditions, not just the permission.** The reference
implementations are MIT. An algorithm is not copyrightable, so a clean-room
implementation from the published spec carries no obligation at all. Cite the
FSRS project and its paper in `ATTRIBUTION.md` regardless: it costs one
paragraph, and 0.9.54 shipped LWIN with no attribution because someone checked
that a licence *permitted* use without reading what it *conditioned* use on.

**Grade mapping.** FSRS takes four grades (Again / Hard / Good / Easy); the
bank has seven formats. Binary formats (`multipleChoice`, `trueFalse`,
`imageIdentification`, `aromaIdentification`) map wrong → Again, right → Good.
The partial-credit formats (`selectAll` 37, `matching` 21, `ordering` 18) are
where Hard comes from honestly: all-but-one correct is a Hard, not a pass and
not a failure. Reserve Easy for a correct answer on a card whose interval is
already long, rather than asking the user to self-rate — self-rating is the
part of Anki that beginners get wrong, and this app has no reason to import it.

---

## 4. Storage

One new `SavedDataKey`, holding a compact per-card record:

```
cardID · stability · difficulty · lastReviewDay · dueDay · reps · lapses
```

Seven small values per seen card. A heavy user might see a few thousand cards;
that is tens of kilobytes, which is the same order as `scanRecords` already in
UserDefaults.

**Register it for BACK UP in the same commit.** `SavedDataArchive` is
exhaustive by hand, and 0.9.54's B1 finding was that backup silently dropped 25
keys nobody had registered. A review history is the single least replaceable
thing the app would ever hold — losing a month of scheduling is worse than
losing a shelf, because a shelf can be rebuilt from memory and a forgetting
curve cannot.

Do **not** store a review log of every answer forever. FSRS needs only the
current state per card; the full log is needed only to *retrain* weights, which
this plan does not do. If training is ever wanted, add the log then.

---

## 5. The surface

The app already has the furniture; none of this needs a new screen.

- **Due count on the main menu.** `DailyChallenge` and `dailyStreak` /
  `dailyLastDay` / `dailyBestStreak` already exist and already own the "come
  back today" slot. Extend that rather than adding a second streak — two
  competing streaks is the fastest way to make both feel worthless.
- **A review session** reusing the exam's own question views, since the cards
  are exam questions.
- **Weakness view.** Per-category accuracy already exists in
  `ExamCategoryTally`; per-card lapses make it specific. "You keep missing
  Nebbiolo" is the sentence the whole feature exists to be able to say.
- **Reminders.** `dailyRemindersEnabled` is already a stored key.
- **Respect the tier gates.** `quizTierUnlocked` and `starterTierOnly` exist;
  a scheduler must not serve advanced cards to a beginner tier, or it will
  teach failure.

---

## 6. Sequence

**A — the review log.** Per-card state, the new key, backup registration, card
identity. No scheduler, no UI. Pin card identity with a test that survives a
catalog regeneration. Nothing is user-visible; this is the foundation and it is
the part that cannot be changed later.

**B — FSRS in Core.** The algorithm, default weights, grade mapping, tests
against the published reference vectors so a transcription slip in a weight
fails a test rather than quietly scheduling badly. Still no UI.

**C — the review session.** Due list, session, grading, streak integration.
First user-visible batch.

**D — generated cards.** Widen the deck through `TastingQuiz` so it scales
with the catalog. Deliberately after C: the authored bank is enough to prove
the loop, and generated cards add a second variable to debug.

**E — the weakness view**, once there is enough history to say anything true.

---

## 7. Risks

- **Card identity churn.** The one genuinely expensive mistake. Key on ids,
  never on prose, and test it.
- **Two streaks.** Integrate with `dailyStreak`; do not compete with it.
- **Deck exhaustion** before D lands. 437 authored cards; a keen user reaches
  the end. Acceptable for C, not for long.
- **Tier leakage** — see the gates above.
- **Backup.** The 0.9.54 lesson, and the highest-cost data in the app.
- **Scope adjacency.** Spaced repetition makes the content gap *worse* before
  better: the scheduler will faithfully resurface a FAULTS question the app
  cannot teach. Sommbot's expansion and this should land close together, and if
  only one can go first it should be the content.

---

## Sources

- FSRS vs SM-2, benchmark methodology and the 20–30% figure —
  <https://expertium.github.io/Benchmark.html>
- FSRS in Anki (default for new profiles since 23.12) —
  <https://github.com/open-spaced-repetition/fsrs4anki>
- MIT licensing of the reference implementation —
  <https://github.com/open-spaced-repetition/fsrs4anki>
- Swift implementations, for cross-checking a clean-room port —
  <https://github.com/4rays/swift-fsrs> (MIT)
