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
 *
 * ## One sentence a note, one line a change (0.8.91, H1)
 *
 * The whole file was rewritten to that rule in 0.8.91. The notes had grown from
 * 83 characters at 0.6.6 to 2,398 at 0.8.9, where a single line ran 340 -- three
 * sentences explaining a feature, its reasoning and its edge cases, in a panel
 * whose readers are trying to find out what changed. The 28 entries carried
 * 26,931 characters of notes and now carry 15,791, and the longest single note
 * is 139 characters where it was 340.
 *
 * **What was cut is the second and third sentence of each note, not the notes.**
 * Every change that was listed is still listed; what went is the argument for
 * it, which is what the doc comments in the source are for. `H1` also asks for
 * the same treatment on the titles, and the ones that went were the editorial
 * ones -- A DIAL, NOT A LIST and PROSECCO IS NOT A ROSE are good sentences and
 * bad headings, because a heading in a list of twenty-nine has to say which
 * release you are looking at.
 *
 * The gate is unchanged and is what bounds the rewrite: headlines are uppercase
 * ASCII and at most 24 characters, and every release keeps at least one note.
 * Nothing caps a note's length, so the rule below is a discipline rather than a
 * check -- if it slips again, that is the thing to add.
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
  version: "0.9.2",
  date: "2026-08-13",
  headline: "ORIGINAL NAMES",
  // Trademark hygiene (0.9.2, item 1): four labels that leaned on somebody
  // else's hardware get names of our own. Labels only — every rawValue,
  // entitlement id and art stem stays put, so no stored choice or purchase
  // moves. PX is a wine (Pedro Ximénez); FIELD BLEND is a wine; 1964 is a
  // year; GROOVEE is nobody's.
  notes: [
    "Four names of our own: the charcoal deck is PX, the purple deck is 1964, the dot-matrix screen is GROOVEE and the calculator shell is FIELD BLEND.",
    "Renames are labels only -- every saved shell, screen and purchase keeps working untouched.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const PREVIOUS_0901: FirmwareRelease = {
  version: "0.9.1",
  date: "2026-08-10",
  headline: "TWELVE SHELVES",
  // 0.9.0's port carried five of the pixel-art loader's twelve directories;
  // the art shipped, unreachable. One list restored, one test made two-way.
  notes: [
    "The drawn chrome is back -- footer caps, marquee glyphs, button faces, cartridges, stickers and the Professor all draw again.",
    "The art roster test now reads both ways, so a shelf the loader forgets fails a gate instead of a device check.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const PREVIOUS_0900: FirmwareRelease = {
  version: "0.9.0",
  date: "2026-08-10",
  headline: "THE AUDIT CLOSES",
  // PR13: the mirror line's audit closures land -- backup, the bigger type
  // scale, and the licence record, merged over the 0.8.9x button saga.
  notes: [
    "STORED DATA backs the whole device up now -- every shelf, rating, streak and setting to one file you keep, and restores from it.",
    "HUGE text got huger: 1.30x, and nothing draws smaller than 11pt on the default step.",
    "Rose and Orange Wine's COLOR chip opens onto the grapes they are made from, and Prosecco is a white again.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const PREVIOUS_0899: FirmwareRelease = {
  version: "0.8.99",
  date: "2026-08-10",
  headline: "ONE DRAWING",
  // The terse register, kept. 0.8.98 made the code one pass; this makes the
  // art one drawing — there is nothing home-specific left to disagree.
  notes: [
    "HOME's cap is BACK's drawing now, with the house incised in place of the chevron -- same face, same bezel, same everything, on every shell.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const PREVIOUS_0898: FirmwareRelease = {
  version: "0.8.98",
  date: "2026-08-10",
  headline: "ONE BUTTON PASS",
  // The end of §A in code: not "resolves to the same colour" but "is the
  // same code" — the buttons cannot be told apart.
  notes: [
    "HOME is drawn by the exact pass the other caps wear -- no ramp, no lip, no special case -- and a lit console Home is just a brighter cap, on every shell.",
    "The walkthrough's diagram stops lighting HOME from the accent -- the last accent-read is gone.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const PREVIOUS_0897: FirmwareRelease = {
  version: "0.8.97",
  date: "2026-08-10",
  headline: "AND THEN THE SEAM",
  // 0.8.96's graft printed its own join as a line across the cap; the band
  // now blends in over ten rows, aligned row-for-row.
  notes: [
    "The skirt graft lost its seam: HOME's band fades into its siblings' shading instead of switching in one line, and the rows align exactly.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const PREVIOUS_0896: FirmwareRelease = {
  version: "0.8.96",
  date: "2026-08-10",
  headline: "ONE MOULDED SKIRT",
  // The HOME saga's last chapter was never colour: the drawing's bottom wall
  // was 21 pixels where its siblings carry 120.
  notes: [
    "HOME's bottom bezel was thin in the drawing itself; it is grafted from its siblings now -- one moulded skirt on all four caps, on every shell.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const PREVIOUS_0895: FirmwareRelease = {
  version: "0.8.95",
  date: "2026-08-09",
  headline: "PREVIEWS TELL TRUTH",
  // A patch on 0.8.94's A: the device was fixed, the pickers were still
  // drawing the old button.
  notes: [
    "CUSTOMIZE's skin tiles and the workshop schematic draw HOME in the material it actually wears.",
    "The lit-Home roster is pinned in test: exactly the four console liveries, so the fallback can never go unexercised again.",
    "If HOME still looks lit on an ordinary shell, check this page's number -- builds before 0.8.94 drew the old button.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const PREVIOUS_0894: FirmwareRelease = {
  version: "0.8.94",
  date: "2026-08-09",
  headline: "HOME, AT THE ROOT",
  // The terse register, kept.
  notes: [
    "The HOME button is fixed at the root: it was the one cap on its own colour path, and now all four resolve through one -- with a test so it cannot fork again.",
    "The boot screen waits for your tap. It no longer opens the app by itself.",
    "Pack names stop truncating: the label was asking for sizes the font quietly refused to render.",
    "Sharing an entry prefills 'Check this out on Vinodex' with a link to its page on the web app.",
    "The share card carries the entry's whole description; the canvas grows instead of the text cutting.",
    "Flavour pages describe the flavour family itself, in a line, instead of the sip.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const PREVIOUS_0893: FirmwareRelease = {
  version: "0.8.93",
  date: "2026-08-09",
  headline: "PROF. VINO",
  // The terse register 0.8.92 tested, kept by request.
  notes: [
    "WHAT'S THAT...? is gone; PROF. VINO takes its square -- his page, his faces, his ledger.",
    "His quiet switch moved from SETTINGS > DEVICE onto that page.",
    "A region's CLIMATE, SOIL and APPELLATION SYSTEM sections are buttons now, each opening its matching scan.",
    "A region's header is two bars: KEY GRAPE, and COUNTRY in ORIGIN's shape.",
    "Style and flavour attributes wear the grape card's round chips.",
    "Dark button liveries finally render dark -- ONYX, CLASSIC's black set and HALLOWINE included, white glyphs and all.",
    "The HOME cap's lip takes the button colour, not the shell's.",
    "MASTER SEARCH heads with the numbered stack; the sliders moved down onto FILTER.",
    "Long pack names fit their cartridge label at every size.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const PREVIOUS_0892: FirmwareRelease = {
  version: "0.8.92",
  date: "2026-08-09",
  headline: "PROFILES + POLISH",
  // Deliberately terse (0.8.92, item 12): this release doubles as the test of
  // H1's one-sentence rule at its shortest useful length.
  notes: [
    "Save and load up to five user profiles in STORED DATA; FRESH is a factory-new device every time.",
    "FIRMWARE is a tile beside SHOP; its settings row is gone.",
    "DAILY REMINDER moved into its own NOTIFICATIONS section.",
    "Shop cartridges print their shelf on the band and their name in the well, here and on the pack pages.",
    "A grape's COLOR and TYPE wear ORIGIN's shape, two to a line.",
    "Origin names read correctly in the light themes.",
    "INSIGHT reads at INFO's size, on INFO's plate.",
    "Globe markers are simply there when the globe opens.",
    "LABEL SCAN wears its tile's face, and its two buttons wear drawn faces.",
    "The HOME cap's bottom lip finally takes the shell colour.",
    "MASTER SEARCH's head wears the sliders, and the chip row just says FILTER.",
    "Backend: the chassis and theme files split apart, seventeen palette switches became one table, and 396 theme combinations now build under test.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const PREVIOUS: FirmwareRelease[] = [
  PREVIOUS_0901,
  PREVIOUS_0900,
  PREVIOUS_0899,
  PREVIOUS_0898,
  PREVIOUS_0897,
  PREVIOUS_0896,
  PREVIOUS_0895,
  PREVIOUS_0894,
  PREVIOUS_0893,
  PREVIOUS_0892,
  {
    version: "0.8.91",
    date: "2026-08-07",
    headline: "BOOT + FIRST RUN",
    notes: [
      "A new startup screen: the tube powers on, the checks run, and the logo settles over scanlines.",
      "Professor Vino narrates the whole tutorial now, at a size you can see him at.",
      "The first-run coaching bubbles land on what they point at instead of above it, past it or over it.",
      "SAVED, WANTED and TRIED are filter chips on every search screen.",
      "Anything you have tried wears a green border, in every list.",
      "YOU MIGHT LIKE shows five suggestions with a SHOW ALL page behind them.",
      "SUPPORT joins SETTINGS > DEVICE: a contact screen with a mail button.",
      "Pack cartridges print their name in the top band, on all three shop shelves.",
      "Drawn faces for the workshop, the label scanner and the daily reminder, and icons are larger throughout.",
      "The HOME button keeps its bottom lip on every shell.",
      "VINODEX CLASSIC wears four grey glyphs on four black footer buttons.",
      "The passport's activity graph covers a week instead of a month.",
      "The screensaver toast sits in the middle of the marquee.",
      "This history is a sentence a change instead of a paragraph.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.8.9",
    date: "2026-08-07",
    headline: "PROFESSOR VINO",
    notes: [
      "The device has somebody in it: Professor Vino introduces himself, asks your name, and says one useful thing the first time you do anything.",
      "He walks you through your first tasting, one lit control at a time, and picks up where you left off.",
      "TUTORIAL in SETTINGS > DEVICE is now the diagram tour and that guided run.",
      "PROFESSOR VINO in SETTINGS > DEVICE silences the tips without spending them.",
      "Every grape and style has an INSIGHT panel: what your own tastings say about it, deepening as your shelf grows.",
      "The Passport counts tried against total and suggests what to drink next.",
      "A fifth rank, APPRENTICE, and a numbered shield for each one.",
      "LABEL SCAN can mark everything it recognised as TRIED, after asking.",
      "Thirty-two drawn pictures: twenty glyphs, five marquee faces and six expressions for Vino.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.8.8",
    date: "2026-08-06",
    headline: "WHAT'S THAT REWORK",
    notes: [
      "WHAT'S THAT...? is a game: every clue is priced by how much it gives away, and you choose which to buy.",
      "It keeps score on disk -- rounds, solves, best and a run of consecutive solves.",
      "Each tool explains itself the first time you open it.",
      "The tour covers the passport, the workshop and the shop, and its tool list is built from the shelf.",
      "STYLE SCAN is gone; a grape's TYPE tile lands on FILTER SEARCH with a STYLE chip lit.",
      "A style's COLOR tile goes to styles of that colour instead of to grapes.",
      "Sharing a stamp sends the drawn stamp rather than a plain symbol.",
      "The DATA screen's six counts wear their drawn faces, and REGIONS and CONTINENTS had been swapped.",
      "SAVE THIS BUILD and SAVED BUILDS sit at the top of the workshop.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.8.7",
    date: "2026-08-06",
    headline: "STAMPS YOU CAN MOVE",
    notes: [
      "TRIED ALL GRAPES and TRIED ALL STYLES are real stamps now, drawn and earnable.",
      "The shell's artifact drags around the back plate like a stamp, and one tap opens a stamp's story.",
      "The faint brown rectangle behind every stamp is gone.",
      "The stamps live in one place: the passport counts them, the collection holds them.",
      "Crossing a rank raises a card, the way a new stamp does.",
      "Every cross-link into a filtered list says FILTER SEARCH, with its chip lit and switchable.",
      "The colour bleeding under the HOME button is gone.",
      "The four glyphs in TASTINGS take their row's colour.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.8.6",
    date: "2026-08-06",
    headline: "THE STAMP COLLECTION",
    notes: [
      "The shell's artifact is printed on the back plate at the size of the barcode beside it.",
      "The six stamps are their own drawings, and smaller.",
      "STAMPS sits first under your rank and opens a collection page.",
      "Two new stamps: TRIED ALL GRAPES and TRIED ALL STYLES, the two dearest in the series.",
      "TASTINGS wears the drawn marquee glyphs.",
      "The settings cog stops wearing two colours.",
      "Nothing on the four footer caps is trimmed off any more.",
      "TOOLS and CUSTOMIZE are the same size on the two lamps.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.8.5",
    date: "2026-08-06",
    headline: "USER PROFILE",
    notes: [
      "SAVED is USER: the page the chassis figure opens is called what the button is called.",
      "The two lamps above the marquee say where they go, cut into the cap.",
      "The marquee pixelates on every change, not only on the greeting.",
      "Every filtered list has its drawn glyph -- STYLE, SECTOR, FLAVOR and REGION SCAN.",
      "The four menu buttons are larger and their contents sit on the curve.",
      "FIBERGLASS gets the drawn buttons, the last shell without them.",
      "The footer buttons are a tenth larger and the dark fringe around them is gone.",
      "The back plate wears twenty hand-drawn artifacts, one per shell.",
      "Shared cards carry the entry's attributes, flag, rarity and flavours -- or your name, photo and streak.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.8.4",
    date: "2026-08-06",
    headline: "MENU DIAL + MARQUEE",
    notes: [
      "The four category buttons are one moulded cluster around MASTER SEARCH.",
      "The search button is larger and sits at the centre of them.",
      "Every page's marquee glyph is a dot-matrix icon, and there are eighteen more of them.",
      "Marquee glyphs take the marquee's own lettering colour and change with the shell.",
      "SYSTEM and SETTINGS stop sharing a glyph.",
      "Opening a pack from the shop is a page BACK returns you from.",
      "The screensaver keeps the screen's grid behind the bouncing V.",
      "The incised symbol on each footer button takes the shell's glyph colour.",
      "The footer buttons stop painting outside themselves.",
      "Every country and state outline is hand-drawn: 33 places on real coastlines.",
      "Six region dots moved a fraction onto their new maps.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.8.3",
    date: "2026-08-06",
    headline: "SHOP CARTRIDGES",
    notes: [
      "Four things left the shop -- the FLAVOR WHEEL and the ITALY, FRANCE and SPAIN packs -- and nothing left the dex with them.",
      "If you already own one, you still own it.",
      "Every shelf is drawn cartridges now.",
      "A pack's page is the cartridge, centred and much larger, with its name on the label.",
      "The file card behind each cartridge is gone, so the packs are a step larger.",
      "The SCREEN MODES packs preview the actual screen.",
      "The marquee's page glyph is the drawn button face, in black.",
      "The two lamps above the marquee wear their drawn faces, in colour.",
      "The footer buttons have lost their cast shadow and depress when you press them.",
      "A style's ORIGIN sits on its own bar, the way a grape's does.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.8.2",
    date: "2026-08-06",
    headline: "GRAPE LINEAGE DATA",
    notes: [
      "A hundred and two more grapes are traced: 121 of 177 open a family tree, up from 75.",
      "Seventy-four say PARENTAGE UNRECORDED, which is a fact about the wine rather than about this app.",
      "Seven Spanish and Catalan whites turn out to share one parent, Heben.",
      "Roussanne and Marsanne are first-degree relatives, and both trees say so.",
      "Mencia is not Cabernet Franc, and Hondarrabi Zuri is Courbu Blanc.",
      "Madeira and Cava file under ORIGIN, beside Champagne, Port and Sherry.",
      "Madeira is a white wine; it had been showing no colour at all.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.8.1",
    date: "2026-08-06",
    headline: "STYLE COLOURS FIXED",
    notes: [
      "Prosecco is a white wine again, and fifteen other styles had been reading wrong with it.",
      "The styles list filters by COLOUR and COUNTRY as well as STYLE CLASS.",
      "Six flavour families stop being grey chips: GAME, SAVOURY, BREAD, SMOKY, SALTY and BRINY.",
      "A flavour's CLASS and SUBCLASS are FLAVOR and FAMILY, and both glyphs are half again as large.",
      "TYPE YOUR GUESS is a proper search bar, still suggesting only wines you have met.",
      "The family tree draws its lines to the boxes.",
      "A parent with no page here is a box like every other node.",
      "The marquee's glyph sits above its word on the menu and pixelates away with it.",
      "The screensaver toast changes language every five seconds.",
      "The bouncing V is half again as large.",
      "The chassis mockup in CUSTOMIZE has its orb back at the right size.",
      "DEVICE PACKS and DISPLAY PACKS preview the actual chassis.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.8.0",
    date: "2026-08-06",
    headline: "NEW MAPS",
    notes: [
      "Every country and state outline is redrawn -- all thirty, from the same rings, at the same weight.",
      "Seven region dots that had been sitting in open water are on land.",
      "Corsica and Mallorca are drawn, so the regions on them have somewhere to be.",
      "The boot screen is by HORIZON/GODOT, centred and a size larger.",
      "\"Paper\" is \"exam\" everywhere you read it.",
      "WHAT'S THAT...? suggests names as you type, but only ones you have met.",
      "GIVE UP is a button, and the whole screen is a size larger.",
      "Europe's globe marker is blue; it and North America were two dark reds.",
      "The rose chip is pink instead of falling through to grey.",
      "The four menu tiles share a baseline.",
      "Search boxes say what they are searching.",
      "The screensaver waits a full minute instead of thirty seconds.",
      "The orb is as tall as the lamps opposite it and lit the same way.",
      "A grape's origin moved onto its own bar.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.9",
    date: "2026-08-06",
    headline: "NAME THAT WINE",
    notes: [
      "WHAT'S THAT...? is a guessing game: clues arrive one at a time and you name the wine.",
      "The clues go from vague to specific -- colour, then country, then the flavour that gives it away.",
      "Guess early for more credit; every clue you take is one you did not need.",
      "It understands synonyms and near-misses, so Steen is Chenin Blanc.",
      "A wrong guess tells you what you actually named.",
      "Everyone gets the same wine on a given day, and reopening deals the next one.",
      "The daily challenge is untouched and keeps its own streak.",
      "Eight new entries: Madeira and Cava, and six grapes including Sercial and Plavac Mali.",
      "Thirteen new exam questions, mostly on fortified wine.",
      "Brazil and Mexico have outlines at last.",
      "The family tree is bigger, and long tiers collapse to six with a SHOW ALL.",
      "A grape whose parents are genuinely unknown says so.",
      "Label scan reads appellations that run across two or three lines.",
      "A bottle it narrows but cannot settle comes back as a shortlist.",
      "The orb is the full width of the lamps opposite it.",
      "Blaufrankisch is filed under Slovenia, with Burgenland still named.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.8",
    date: "2026-08-05",
    headline: "SHARE CARDS",
    notes: [
      "Every entry has a share button, exporting a pixel-art card framed in your device.",
      "Your passport shares too: rank, completion, counts and streak, in your own colours.",
      "Earned stamps are shareable one at a time.",
      "The daily challenge gives you a result to post, and its tiles never show the answers.",
      "Copy it or send it straight on.",
      "New in SETTINGS > DEVICE: DAILY REMINDER, off until you turn it on.",
      "At most two a day, and neither arrives if you have already played.",
      "Turn notifications off in iOS Settings and the switch says so.",
      "The BIOS boots inside the display, with the device around it.",
      "Its drawn border, rails and brackets are gone; the chassis does the framing.",
      "Any touch still carries on, and nothing on the device can be pressed by accident.",
      "The sticker on the back is a sticker again -- die-cut, glossy, one corner lifting.",
      "Choosing a shell or screen in CUSTOMIZE overrides the parts you fitted in the workshop.",
      "Builds you saved are untouched.",
      "438 entries, unchanged: 171 grapes, 124 regions, 31 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.7",
    date: "2026-08-04",
    headline: "VINODEX BIOS",
    notes: [
      "The startup screen is rebuilt edge to edge: a proper BIOS boot instead of a panel of text.",
      "The V and the wordmark sit at the centre, framed by a terminal border.",
      "Scanlines and a faint glow, like a CRT warming up.",
      "The checks resolve into the composition rather than cutting away.",
      "It waits on PRESS ANY BUTTON TO CONTINUE, and answers itself after a few seconds.",
      "The corner reads your real battery level.",
      "The version in the top corner is the firmware's.",
      "438 entries, unchanged: 171 grapes, 124 regions, 31 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.6",
    date: "2026-08-04",
    headline: "MARQUEE SHORTCUTS",
    notes: [
      "The two lights on the marquee are the shortcuts now: always there, one tap.",
      "Hold either to point it at tools, customize, settings, data or the shop.",
      "The drawer behind the panel and the pin buttons in its corners are gone.",
      "Your pinned shortcuts carry over.",
      "The screensaver waits 30 seconds and starts from a different spot each time.",
      "The marquee says cheers on every screen, at the same moment the screensaver arrives.",
      "The orb is an elongated pill, matching the notch above it.",
      "Three more workshop parts: header lights, marquee lights and footer buttons.",
      // Shipped as "W64"; the shell was renamed to 1964 in 0.9.2 and this
      // page draws the label a user sees today, not the one that shipped.
      "New shell: 1964, purple deck with four coloured face buttons.",
      "Shop splash screens are bigger and show what is in the box.",
      "The tutorial moves into SETTINGS > DEVICE, with a new page about the two lights.",
      "438 entries, unchanged: 171 grapes, 124 regions, 31 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.5",
    date: "2026-08-04",
    headline: "THE WINE EXAM",
    notes: [
      "The Wine Exam is rebuilt: 407 written questions across 16 subjects.",
      "Seven kinds of question, from multiple choice to aromas and outlines.",
      "Every answer is explained, right or wrong, before the next question.",
      "Each paper draws evenly across the subjects.",
      "Statistics: papers sat, accuracy, full marks, pass streak and what to study.",
      "New: Grape Lineage -- parents, offspring, mutations and half-siblings, as a family tree.",
      "68 grapes have a pedigree, and the tree shows both readings where sources disagree.",
      "Sixteen grapes stop showing a full body bar they had not earned.",
      "ACCESS is the SHOP, and the expansion packs move into it.",
      "Every cartridge opens to a splash screen with its mockups and contents.",
      "The status lights on the marquee are bigger, with darker glyphs.",
      "Monochrome screens flash as they redraw.",
      "The startup BIOS fills the display, still under two seconds and still skippable.",
      "The screensaver bounces the real Vinodex mark.",
      "The PET-NAT shell is now FIBERGLASS.",
      "438 entries, unchanged: 171 grapes, 124 regions, 31 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.4",
    date: "2026-08-04",
    headline: "GRAPE OVERHAUL",
    notes: [
      "25 grapes join the catalog, most of them grown almost nowhere else.",
      "Six regions join with them, so those grapes point at a real home.",
      "Marselan and Cabernet Gernischt are French by birth, and both entries are rewritten.",
      "Cabernet Gernischt is Carmenere, and the card now says so.",
      "White grapes show an empty tannin bar; it had read half full since the import.",
      "438 entries: 171 grapes, 124 regions, 31 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.3",
    date: "2026-08-04",
    headline: "DEVICE EXPERIENCE",
    notes: [
      "Boot POST: memory check, database init and the firmware version. Tap to skip.",
      "Demo mode cycles the tools unattended; any input drops you back out.",
      "FIRMWARE HISTORY, and the changelog ships as data.",
      "CHEAT CODES console for unlock codes.",
      "The screensaver bounces the Vinodex V after fifteen seconds idle.",
      "Ownership moved behind one entitlement store.",
      "DEVICE WORKSHOP: build your own handheld from eight parts and save the results.",
      "Five grille patterns where there was one, and the font colour is yours to set.",
      "EXPANSION PACKS: twelve collectible cartridges, and nothing is locked away.",
      "Each cartridge tracks how much of it you have drunk.",
      "Brazil joins the catalog: Serra Gaucha and Campanha Gaucha.",
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
      "Back-plate stamps are draggable again.",
      "The marquee is a control surface: its lamps are TOOLS and CUSTOMIZE.",
      "The idle toast rotates through nine languages.",
      "Africa and Oceania have their own globe marker colours.",
    ],
  },
  {
    version: "0.7.1",
    date: "2026-08-03",
    headline: "MARQUEE + POLISH",
    notes: [
      "FILTER SEARCH is MASTER SEARCH, and every search affordance is one magnifier.",
      "The marquee is scripted: WELCOME, then MENU, then a toast once you go quiet.",
      "Every lamp on the device sits in a milled recess.",
      "Passport gained a per-day activity graph and a four-rung rank ladder.",
      "The Emulator screen modes repaint the app's coloured chrome in their own ramps.",
      "IDENTIFY became BLIND TASTING; the daily challenge's fire became a target.",
      "South America's globe marker turned violet to part it from North America.",
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
