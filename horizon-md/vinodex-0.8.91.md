# Vinodex v0.8.91 - batch

iOS SwiftUI app in `Sources/`. **Branch off `testing`.**

**Conventions**: data & icons generate from `shared/` + `art/icons/` (`npm run generate`,
`npm run icons`) - never hand-edit generated JSON (CI drift check). New UI chrome = SF Symbols.
Skin/mode colors are code-driven. **User state (tried/saved/wanted) is NOT content** - persist it
in the user store, never in generated JSON.

---

## A. Shop / pack cartridges
A1. **Pack title on the cartridge image:** overlay the pack's title in the **top burgundy band** of
its cartridge art, for **Atlas packs, Device packs, and Display packs** (all three pack screens).
Title sits in that top area, legible over the burgundy.

## B. Search & discovery filters
B1. **Add Saved / Wanted / Tried filters** to all search screens where appropriate.
- **Tried** comes from the discovery system (v9.0).
- **Saved** and **Wanted** are **new user states** - add persisted per-entry flags + a way to set
  them (e.g. on an entry), then expose all three as filters. *(User state, not content.)*
B2. **Green border on tried entries:** give the container of any entry you've **Tried** a **green
border** (list rows + tiles), so tried items read at a glance.
B3. **"You Might Like" - show 5 + Show All:** the recommendation strip shows **5 entries** then a
**"Show All"** button - a full **"You Might Like"** page listing all suggested entries.

## C. Icons - wiring & size
C1. **Wire `hammericon`** -> Workshop.
C2. **Wire `labelscannerglyph`** (new icon) -> the Label Scanner.
C3. **Add the bell icon** for the **Daily Reminder toggle** in Settings.
C4. **Make icons generally bigger** across the UI (bump the standard icon size - sweep for icons
that read too small now).

## D. Footer buttons
D1. **Home button clipping:** the Home footer button is still **clipped/scrubbed on the bottom lip**
on some chassis skins - fix so the full button (incl. its lower edge) renders on every skin.
D2. **Vinodex Classic footer buttons:** make all **four** footer buttons **grey glyphs on black**
buttons for the Classic skin.

## E. Passport
E1. **Change the activity graph range to one week.**

## F. System - Support
F1. **Add a Support button to the System screen** - wire in **`sealicon`**. It opens a **brief
contact screen** with a **mail contact button** (wire **`mailicon`**) that opens a mail composer to
**hello@vinodex.com** (temporary placeholder address).

## G. Professor Vino, marquee, startup
G1. **Make the Professor Vino UI larger** (bubble + portrait).
G2. **Center the marquee screensaver text.**
G3. **New startup screen** - mount the new BIOS boot animation *(already dropped in at
`Sources/VinodexUI/VinodexBootView.swift`)* in the launch flow; call its `onFinish` to route into
the app. Reconcile with the existing `BootScreen.swift` - don't leave two boot paths running.

## H. Firmware
H1. **Condense the firmware info text** - summarize each version's major updates in a **short,
concise sentence** (for devs, testers, and users alike); **not verbose**. Apply the same concise
treatment to the **firmware title.**

## I. First-run walkthrough bubbles
I1. **The first-open walkthrough bubbles are all over the place** - positioning is wrong/erratic
(bubbles land off-target, off-screen, or over the thing they're pointing at). Fix the placement so
each bubble anchors sensibly to what it's describing on every chassis skin and screen size.
I2. **Professor Vino should be the one telling you what to do** during that first walkthrough -
the guidance comes from Vino (portrait + bubble voice), not anonymous chrome. Make the first-run
flow read as Vino walking a new user through the device.

---

## Confirm against current code
- The pack-cartridge layout, to overlay the title in the top burgundy band (A1).
- The search filter model + where Tried lives; add Saved/Wanted user flags + setters (B1); the
  entry-container style, to add the tried green border (B2); the recommendation strip, to cap at 5
  + a Show-All page (B3).
- Icon wiring points for hammer/labelscanner/bell (C1-C3) and the global icon-size constant (C4).
- The Home button clip on skins (D1) and the Classic skin's footer button colors (D2).
- The passport activity range (E1).
- The System screen, to add Support -> contact screen -> mail composer (F1).
- The Vino presenter size (G1), marquee screensaver text alignment (G2), and launch flow for the
  boot view (G3).
- The firmware changelog + title copy, to condense (H1).
- `WalkthroughScreen.swift` / `CoachmarkOverlay.swift` / `VinoBubble.swift` for the first-run
  bubble anchoring and who narrates it (I1-I2).
