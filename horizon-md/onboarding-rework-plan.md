# Onboarding rework — audit and spec

Written against v0.9.56. The audit is from source rather than from a walk: the
Simulator's device window would not reopen, so every screen below is read from
the code that draws it. The BIOS screenshot is real; nothing after it is.
Re-walk it on a device before building.

---

## 1. What a new user meets today

Five systems, none of which knows about the others.

**1. BIOS** (`VinodexBootView`) — logo, `DISCOVER · COLLECT · TASTE`,
`SYSTEM CHECK... OK`, `PRESS ANY BUTTON TO CONTINUE`. **It waits forever.**
The code says so: *"No ceiling any more (0.8.94, B1). The screen holds on the
blinking prompt until a touch."*

**2. Vino intro, page 1** (`VinoIntroCard`) —
> Vinobot online: vintage intelligence, no taste buds. What do I call you, explorer?

with a `YOUR NAME` field, SKIP or DONE.

**3. Vino intro, page 2** — fires on submit *or* skip:
> Pleasure, {name}. You taste the world; I catalogue it. Together we fill the Vinodex.

**4. Coachmark** (`Coachmark.steps`) — six live spotlight steps, auto-starting
only for a genuinely new install. Each waits on the user *doing* the thing:

| step | waits on | line |
|---|---|---|
| menu | opened a category | "Start here, {name}. Four shelves; press GRAPES…" |
| listing | opened an entry | "Every grape I hold, {name}. Start with Pinot Noir…" |
| tried | marked tried | "This is the one that matters. Press TRIED…" |
| vinobot | acknowledged | "Found me, {name}? Press the speaker…" |
| passport | opened passport | "Last one, {name}. Your Passport counts every tasting…" |
| done | acknowledged | "That is the whole loop, {name}. Next bottle, hand me the label…" |

**5. Walkthrough** (`Walkthrough`) — eleven static cards, opt-in from
SETTINGS ▸ DEVICE: START HERE, SEARCH ANYTHING, WHAT AN ENTRY LOOKS LIKE,
GOING BACK, STARTING OVER, THE TWO LIGHTS, MAKING IT YOURS, TOOLS, WHAT YOU'VE
TASTED, ASK THE ROBOT.

Plus two ongoing one-shots: `ToolIntro` (a tagline the first time each of six
tools opens) and `FirstTimeTriggers` (Vino bubbles, once each).

---

## 2. The four complaints, checked

**Two tutorials collide — confirmed, and the code already admits it.**
`Coachmark`'s own header: *"Shipping two tutorials in one menu would have
passed every gate in this repo."* They are both in SETTINGS ▸ DEVICE. Four of
the walkthrough's eleven cards restate a coachmark step outright — START HERE
against `menu`, TOOLS against the six tool intros, ASK THE ROBOT against
`vinobot`, WHAT YOU'VE TASTED against `passport`.

**It does not sell the app — confirmed.** The label reader is the strongest
thing in the product and onboarding mentions it exactly once, in the last
coachmark line, as a *promise about later*: "Next bottle, hand me the label."
The 185,000-wine offline index is never mentioned. A new user finishes
onboarding without seeing the feature that would make them keep the app.

**It teaches the old app — confirmed.** The six coachmark steps never mention
the globe, the exam, the daily challenge, read-aloud, master search, or three
of the four shelves. The walkthrough predates the globe rework, the LWIN
upgrade and read-aloud entirely.

**The BIOS holds forever — confirmed**, deliberately, since 0.8.94.

---

## 3. The ruling this is built on

**The first session should make someone understand what the app IS.**
Orientation, not a task. The current coachmark is the opposite — a *doing*
tour that will not advance until you press GRAPES, then press TRIED, then open
the passport. That is a fine second experience and a demanding first one.

So the two tutorials stop competing by becoming different things:

- **Orientation runs on first launch.** Short, tells rather than asks, names
  the pillars, ends at the menu.
- **The guided tour stays opt-in** in SETTINGS ▸ DEVICE for "show me how".

---

## 4. The spec

### 4.1 BIOS — keep the hold, make the prompt impossible to miss

The indefinite wait stays; it is the handheld fiction and it is the maintainer's
call. What changes is that nobody can mistake it for a hang:

- The prompt blinks harder — higher contrast, larger, and a slower, more
  deliberate cycle than the current one.
- After ~4 seconds with no touch, add a second line: `TAP THE SCREEN`. The
  first line is in character; the second is an instruction, and it only appears
  for someone who has not worked it out.

Nothing auto-advances. A reviewer who sits and stares still gets told what to do.

### 4.2 Name — unchanged

Two pages, SKIP lands on page two. It works, the copy is good, and
`firstLaunchNamed`'s note is right that skipping declines to be *named*, not to
be introduced. Leave it.

### 4.3 Orientation — four cards, replacing the auto-coachmark

One card per pillar, in this order. Each is a sentence of what it is, a
sentence of why it matters, and the screen behind it.

1. **THE ENCYCLOPEDIA** — 540 entries across grapes, regions, styles and
   flavours, all on the device, no account and no network.
2. **THE LABEL READER** — point the camera at a bottle and it names the wine
   from 185,000 in the trade's own index, offline. *This is the card that sells
   the app and it must not be last.*
3. **PRACTICE** — the exam in three tiers, the daily pick, the passport that
   counts what you have tasted.
4. **THE WORLD** — the globe: tap a country, tap again for its wine regions.

Then: "That is the whole device. Press MENU." — and it ends.

**Rules.** Skippable from card one, with SKIP always visible. Never re-runs.
Under 45 seconds read end to end. No step waits on the user doing anything.

### 4.4 The guided tour — the coachmark, promoted to the opt-in slot

The existing six steps become what SETTINGS ▸ DEVICE ▸ TUTORIAL runs. They are
good at what they do; they were only ever wrong as a *first* experience.

Two changes: it no longer auto-starts (`shouldAutoStart` goes, and with it the
`hasBeenOffered` seeding), and the closing line stops promising the scanner —
orientation has already shown it — and instead hands the user the globe, which
is the one pillar a doing-tour cannot easily walk.

### 4.5 Retire the eleven-card walkthrough

Its four duplicated cards die with it. The rest is not lost:

- SEARCH ANYTHING, GOING BACK, STARTING OVER, THE TWO LIGHTS, MAKING IT YOURS
  are *device* mechanics, not app orientation. They belong in SETTINGS ▸ DEVICE
  as a reference page — "HOW THE DEVICE WORKS" — that someone reads when they
  want it, not a tour anyone is walked through.
- TOOLS is already better served by the six `ToolIntro` taglines, which fire in
  context at the moment each tool is opened.

This is the single biggest simplification here: **five onboarding systems
become three** — orientation (first run), guided tour (opt-in), and the two
in-context one-shots that already work.

---

## 5. Copy to fix while in here

Two gate blurbs were deferred and belong in this pass, per the original phase
note: **C008 Switzerland** and **C009 Romania** both lead with international
grapes rather than with what makes the country worth knowing.

---

## 6. What this does not touch

`ToolIntro` and `FirstTimeTriggers` are working as designed and fire in
context. `BootSequence`'s POST content, the chassis, and the name card's two
pages all stay. Nothing here changes a saved-data key, so no backup migration.

---

## 7. Risks

- **`shouldAutoStart` removal must not orphan the seeding.**
  `seed(hasHistory:)` exists to stop a six-step spotlight ambushing an existing
  user after an update — the file notes that trap firing in four consecutive
  batches. Removing the auto-start removes the need, but the removal has to
  take the whole mechanism, not leave half of it writing state nothing reads.
- **Orientation is a new first-run one-shot**, which is exactly the shape that
  has misfired four times in this codebase. It needs the same
  `hasHistory` guard the coachmark has, for the same reason.
- **A new `SavedDataKey` must be registered for BACK UP in the same commit** —
  0.9.54's B1 found backup silently dropping 25 unregistered keys.
- The audit above is read from source. **Walk the real flow before building**,
  because the one thing I could not check is how it feels.
