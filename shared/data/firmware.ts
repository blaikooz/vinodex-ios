import type { FirmwareRelease } from '../types';

/**
 * The device's firmware history (iOS 0.7.3, F3).
 *
 * **This file is the version number.** Until 0.7.3 the authored version lived in
 * `AppVersion.fallback`, a Swift literal, and the changelog lived nowhere at all
 * -- it was forty lines of doc comment above that literal. F3 asks for one data
 * source that both the boot POST (A1) and the FIRMWARE HISTORY panel (A3) read,
 * and `shared/` is where this project's data lives, so it is here.
 *
 * `AppVersion` did not go away and did not become a second source of truth: it
 * still owns the *resolution* rule (a version the bundle genuinely declares beats
 * the authored one, and xtool's stamped `1.0.0` placeholder beats neither), and
 * its `fallback` now reads `FIRMWARE_VERSION` through the generated
 * `firmware.json` instead of restating it.
 *
 * **Bumping a version is editing `CURRENT` below**, moving the release it
 * displaces to the head of `PREVIOUS`, and running `npm run generate`.
 *
 * The long "why does this build carry this number" notes stay in
 * `AppVersion.swift`. They are the engineering record and answer a question no
 * player asks; what is here is what the device is willing to say about itself.
 *
 * **Newest first**, which is both the order the panel prints and the reason
 * `FIRMWARE_VERSION` can be derived rather than declared. The generator asserts
 * the ordering, the three-component shape, the ASCII/length rules and that no
 * version appears twice.
 */

/**
 * The build this source tree produces.
 *
 * Named rather than written as the first element of the array below, so
 * `FIRMWARE_VERSION` can be derived without indexing — `vinodex-web` compiles
 * `shared/` under `noUncheckedIndexedAccess`, where `FIRMWARE_RELEASES[0]` is
 * `FirmwareRelease | undefined` and the whole "one source of truth" arrangement
 * would have hung off a non-null assertion. This also gives the thing you edit
 * each batch a name, which is the file's entire job.
 */
const CURRENT: FirmwareRelease = {
  version: "0.7.5",
  date: "2026-08-04",
  // "THE SHOP" through the A/B sitting, and it stopped being the biggest thing
  // in this release when D landed. The headline names the release on the
  // FIRMWARE panel; a 407-question exam under a heading about a storefront was
  // the panel describing the second-largest feature.
  headline: "THE WINE EXAM",
  notes: [
    "The Wine Exam is rebuilt: 407 written questions across 16 subjects, from grapes to wine law.",
    "Seven kinds of question. Multiple choice, true or false, select all, matching, ordering, aromas and outlines.",
    "Every answer is explained. Right or wrong, you are told why before the next question.",
    "Each paper draws evenly across the subjects, so one sitting is never ten questions about grapes.",
    "Statistics: papers sat, accuracy, full marks, pass streak, and the subject you should study.",
    "The Daily Challenge is unchanged and still built from the catalogue.",
    "New: Grape Lineage. Parents, offspring, mutations and half-siblings, drawn as a family tree.",
    "68 grapes have a pedigree. Where two sources disagree, the tree shows both and says so.",
    "Body bars were reading Medium-Full as Full. Sixteen grapes now show the body they were given.",
    "Expansion Packs move out of Customize. They live in the Shop now.",
    "Access is renamed Shop: one storefront for everything you can own.",
    "Every cartridge opens to a splash screen with its mockups and what is in it.",
    "The whole shop is drawn as cartridges. The toggle rows are gone.",
    "The status lights on the marquee are bigger, and their glyphs darker.",
    "The orb is a rounded key rather than a bead, to match the shell.",
    "Monochrome screens flash as they redraw when you change page.",
    "The startup BIOS fills the display. Still under two seconds, still skippable.",
    "The screensaver bounces the real Vinodex mark instead of a drawn stand-in.",
    "The PET-NAT shell is now FIBERGLASS.",
    "438 entries, unchanged: 171 grapes, 124 regions, 31 styles, 106 flavours, 26 countries.",
  ],
};

/** Everything before `CURRENT`, newest first. */
const PREVIOUS: FirmwareRelease[] = [
  {
    version: "0.7.4",
    date: "2026-08-04",
    headline: "GRAPE OVERHAUL",
    notes: [
      "25 grapes join the catalog, most of them grown almost nowhere else.",
      "Pais and Cinsault from Itata, Callet from Mallorca, Babic from Dalmatia.",
      "Cabernet Pfeffer: about four hectares exist, and nobody agrees what it is.",
      "Six regions added so those grapes point at a real home, not a famous neighbour.",
      "Ribeiro, Mallorca, the Azores, South West France, San Benito, Itata Valley.",
      "Marselan and Cabernet Gernischt are French by birth. Both entries rewritten.",
      "Cabernet Gernischt is Carmenere. The card now says so.",
      "White grapes show an empty tannin bar. It had read half full since the import.",
      "438 entries: 171 grapes, 124 regions, 31 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.3",
    date: "2026-08-04",
    headline: "DEVICE EXPERIENCE",
    notes: [
      "Boot POST: memory check, database init and the firmware version. Tap to skip.",
      "Demo mode cycles the tools unattended. Any input drops you back out.",
      "FIRMWARE HISTORY: this panel. The changelog now ships as data.",
      "CHEAT CODES console for unlock codes.",
      "Screensaver: the Vinodex V bounces the LCD after 15 seconds idle.",
      "One idle timer behind the marquee toast and the screensaver both.",
      "Ownership moved behind one entitlement store, ready for a real storefront.",
      "DEVICE WORKSHOP: build your own handheld from eight parts, and save the results.",
      "Buttons, orb, marquee, grille colour and grille pattern are parts you can fit.",
      "Five grille patterns where there was one, and the font colour is yours to set.",
      "EXPANSION PACKS: twelve collectible cartridges, on a shelf of their own.",
      "Atlas packs group the catalog by where it comes from. Nothing is locked away.",
      "Each cartridge tracks how much of it you have drunk.",
      "Brazil joins the catalog: Serra Gaucha and Campanha Gaucha, in Rio Grande do Sul.",
      "407 entries: 146 grapes, 118 regions, 31 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.2",
    date: "2026-08-03",
    headline: "LABEL SCAN",
    notes: [
      "LABEL SCAN: point the camera at a bottle and match it against the catalog.",
      "Reading is on-device. No network, no account, no key.",
      "An appellation off the label resolves to its region, country, grapes and styles.",
      "Back-plate stamps are draggable again. They had not been since 0.7.0.",
      "The marquee is a control surface: its lamps are TOOLS and CUSTOMIZE.",
      "Pinned sections sit in the marquee's corners; tapping it opens PINS.",
      "The idle toast rotates through nine languages, one per idle period.",
      "Africa and Oceania have their own globe marker colours at last.",
    ],
  },
  {
    version: "0.7.1",
    date: "2026-08-03",
    headline: "MARQUEE + POLISH",
    notes: [
      "FILTER SEARCH is MASTER SEARCH, and every search affordance is one magnifier.",
      "The marquee is scripted: WELCOME, then MENU, then a toast once you go quiet.",
      "It is also a button, opening a swipeable drawer with a two-slot pin bar.",
      "Every lamp on the device sits in a milled recess.",
      "Passport gained a per-day activity graph and a four-rung rank ladder.",
      "The Emulator screen modes repaint the app's coloured chrome in their own ramps.",
      "IDENTIFY became BLIND TASTING; the daily challenge's fire became a target.",
      "South America's globe marker turned Malbec violet to part it from North America.",
    ],
  },
  {
    version: "0.7.0",
    date: "2026-08-02",
    headline: "SKINS + FACETS",
    notes: [
      "Skin and screen-mode pickers grouped into sections on both axes.",
      "WALDGLAS and HALLOWINE join the chassis skins.",
      "Three new filter facets, plus chips on the world, style and flavour scans.",
      "A back plate per skin.",
      "The tools shelf re-cut, and three fixed pages grown into their measured slack.",
    ],
  },
  {
    version: "0.6.9",
    date: "2026-08-02",
    headline: "STILL MARQUEE",
    notes: [
      "The marquee stopped scrolling in favour of a glyph and a cycling greeting.",
      "The LCD back swipe removed outright.",
      "Footer controls down a quarter and re-paired.",
      "A hand-drawn skin and a matching screen mode.",
    ],
  },
  {
    version: "0.6.8",
    date: "2026-08-02",
    headline: "FOOTER + STAMPS",
    notes: [
      "Footer controls at 1.74x and the red lamps back on the white bezel.",
      "Press and hold to drag a back-plate stamp.",
      "An app-wide LCD back swipe (removed again the following build).",
    ],
  },
  {
    version: "0.6.7",
    date: "2026-08-02",
    headline: "CHASSIS PASS TWO",
    notes: [
      "The button band rebuilt as two recessed diagonal bundles.",
      "The wordmark out of the grille and into the bottom strip.",
      "Red lamps anchored to the bezel.",
      "Two new skins, per-button console palettes and draggable back-plate stamps.",
    ],
  },
  {
    version: "0.6.6",
    date: "2026-08-01",
    headline: "CHASSIS PASS ONE",
    notes: [
      "Per-mode globe tint.",
      "The diagonal button cluster.",
      "The wordmark moved into the grille.",
    ],
  },
  {
    version: "0.6.5",
    date: "2026-08-01",
    headline: "BUTTON BAND",
    notes: [
      "A new button band, top-bar chrome and the bezel chamfer.",
      "The settings cog moved into the band.",
    ],
  },
  {
    version: "0.6.4",
    date: "2026-08-01",
    headline: "CATALOG WAVE",
    notes: [
      "The catalog reached 405 entries.",
      "Blind tasting steps back through its own questionnaire before leaving.",
      "TEXT SIZE seeds itself from the system setting on first launch.",
    ],
  },
  {
    version: "0.6.3",
    date: "2026-07-30",
    headline: "ROBUSTNESS",
    notes: [
      "The database decodes entry by entry, so one bad record costs one record.",
      "A schema stamp ships beside the data and is checked at load.",
      "Load problems raise a notice instead of an unexplained empty catalog.",
    ],
  },
  {
    version: "0.6.2",
    date: "2026-07-30",
    headline: "375 ENTRIES",
    notes: [
      "375 entries: 128 grapes, 104 regions, 31 styles, 106 flavours, 25 countries.",
      "Five rarity tiers, fifteen skins, geographic region dots and passport stamps.",
    ],
  },
];

/** Newest first — see the note on the interface. */
export const FIRMWARE_RELEASES: FirmwareRelease[] = [CURRENT, ...PREVIOUS];

/**
 * The firmware this build reports.
 *
 * Read off `CURRENT` rather than declared separately: two places naming the
 * current version is the exact failure this file was created to end. The
 * generator still asserts that the list is strictly newest-first, so `CURRENT`
 * being the head is a checked invariant rather than an authoring convention.
 */
export const FIRMWARE_VERSION: string = CURRENT.version;
