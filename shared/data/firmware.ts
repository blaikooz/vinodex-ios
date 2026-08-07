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
  version: "0.8.8",
  date: "2026-08-06",
  // The guessing game gets an economy and a memory, six tools learn to
  // introduce themselves, and the tour stops describing a device that changed
  // underneath it.
  headline: "EVERY CLUE HAS A PRICE",
  notes: [
    "WHAT'S THAT...? is a game now. Every clue is priced by how much it gives away and you choose which to buy; naming the wrong wine turns over the cheapest one left, and running out of clues loses the round. Guessing used to be free, which made spamming names the best way to play.",
    "It keeps score. Rounds played, solves, best score and a run of consecutive solves, on the screen and on disk -- the old score was thrown away the moment you left.",
    "Each tool explains itself the first time you open it: what it is, how it works, and what it costs you. One card per tool, and one control on the card that dismisses all six.",
    "The tour covers the passport, the workshop and the shop, and no longer lists a tool that is not on the shelf while omitting one that is. Its device is a fixed size on every step instead of growing and shrinking with the paragraph beside it.",
    "STYLE SCAN is gone. A grape's TYPE tile lands on FILTER SEARCH with a STYLE chip lit -- ten values the catalog already carried, none of which the BODY and COLOUR chips could say between them.",
    "A style's COLOR tile goes to styles of that colour instead of to grapes. It used to send you to every red grape, to all 177 grapes from a dual style, or to nothing at all from a rose or an orange one.",
    "Sharing a stamp sends the stamp. The card drew a plain symbol in the screen's colour for an object the app draws properly in three other places.",
    "The DATA screen's six counts wear their drawn faces, each in its own row's colour -- and REGIONS and CONTINENTS had their symbols the wrong way round.",
    "SAVE THIS BUILD and SAVED BUILDS sit above SHELL in the workshop, next to the device they save rather than ten sections below it.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const DISPLACED_0_8_7: FirmwareRelease = {
  version: "0.8.7",
  date: "2026-08-06",
  // The two stamps nobody could earn find their pictures, the plate lets you
  // move everything on it, and the ladder finally says something when you
  // climb it.
  headline: "PICK IT UP AND MOVE IT",
  notes: [
    "TRIED ALL GRAPES and TRIED ALL STYLES are drawn. The two pictures were printed on the back of the device as decoration; they are the two stamps now, and the decoration is gone.",
    "The shell's artifact can be dragged around the back plate like the stamps, and one tap on a stamp opens its story however long you hold it.",
    "The faint brown rectangle behind every stamp and behind the artifact is gone. The ageing was being painted over the whole box a drawing sits in rather than over the drawing.",
    "The stamps are in one place. The passport says how many of the series you hold and opens the collection; the collection is where all eight are, and where you share one.",
    "Levelling up says so. Crossing into VINODEX MASTER, GRANDMASTER, LEGEND or IMMORTAL raises the same kind of card a new stamp does -- and never for a rank you already held.",
    "Every cross-link that lands in a filtered list now says FILTER SEARCH under a magnifying glass, with the chip you arrived on already lit and switchable. Seven differently-named scans were one screen.",
    "The colour bleeding under the HOME button is gone. It was the cast shadow's own outline, welded to the bottom of the cap.",
    "The four glyphs in TASTINGS take their row's colour instead of arriving in one ink.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const DISPLACED_0_8_6: FirmwareRelease = {
  version: "0.8.6",
  date: "2026-08-06",
  // The plate stops framing things that are already framed, the cog finally
  // takes one colour, and the stamps get a room of their own.
  headline: "A STICKER, NOT A FRAME",
  notes: [
    "The shell's artifact is printed on the back plate at the size of the barcode beside it. It had been a drawn sticker mounted inside a drawn sticker, at a third of the space.",
    "The six stamps are their own drawings too, and smaller. The frame the app used to build around each one is now only what a stamp nobody has drawn yet falls back to.",
    "STAMPS is the first thing under your rank, above the counting, with a way into the collection: every stamp in the series at a size worth looking at, the unearned ones drained rather than hidden, each one tappable for its story.",
    "Two new stamps. TRIED ALL GRAPES and TRIED ALL STYLES -- the two hardest in the series, and the two dearest.",
    "TASTINGS wears the drawn marquee glyphs. Grapes, styles, countries and continents each had one and none of them was being used here.",
    "The settings cog stops wearing two colours. The bottom of its knurled rim was being painted in the glyph's ink -- a near-white on most shells, which is why it read as grey plastic on a coloured button.",
    "Nothing on the four footer caps is trimmed off any more. They are clipped to their own outline instead of to a fitted circle, which is what was fraying the dark line around the edge of the cog and the house.",
    "TOOLS and CUSTOMIZE are the same size on the two lamps. Every word up there was being fitted separately, so the short ones came out bigger.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const DISPLACED_0_8_5: FirmwareRelease = {
  version: "0.8.5",
  date: "2026-08-06",
  // The panel starts saying who you are, the four buttons finally sit still in
  // the middle of themselves, and the back plate stops being drawn by the app.
  headline: "IT KNOWS WHO YOU ARE",
  notes: [
    "SAVED is USER. The page the figure on the chassis opens is finally called what that button is called, and it has the figure's own glyph.",
    "The two lamps above the marquee say where they go. TOOLS, CUSTOMIZE, SETTINGS, DATA or SHOP, cut into the cap like the START and SELECT on a controller, on a lamp a little taller to hold the word.",
    "The marquee pixelates on every change now, not only on the greeting. A page title takes 0.42 seconds where a greeting takes 1.4.",
    "STYLE SCAN has its glyph. So do SECTOR SCAN, FLAVOR SCAN and REGION SCAN -- every filtered list had been falling back to a plain symbol while its drawn one sat unused.",
    "The four menu buttons are larger and their contents sit in the middle of the curve rather than shoved into the corner. Where the middle is now depends on the size of the button, which is why it was wrong before.",
    "FIBERGLASS gets the drawn buttons. It was the last shell still on the painted ones.",
    "The footer buttons are a tenth larger, and the dark fringe around them is gone: the cast shadow was eating holes through the caps at import, and the recolour was painting the bottom of each one in the glyph's colour.",
    "The back plate wears twenty hand-drawn artifacts, one per shell, and a drawn barcode, price tag and two loose stamps in place of the ones the app used to draw itself.",
    "A shared entry card now carries the entry's attributes, its country's flag, its rarity and its flavours. A shared profile carries your photo, your name and six coloured stats.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const DISPLACED_0_8_4: FirmwareRelease = {
  version: "0.8.4",
  date: "2026-08-06",
  // The menu becomes a dial and the marquee gets its own alphabet of pictures.
  // Underneath both, forty-six hand-drawn coastlines replace the thirty the
  // 0.8.0 rasteriser produced -- real outlines, not 30-vertex approximations.
  headline: "A DIAL, NOT A LIST",
  notes: [
    "The four category buttons are one cluster now: a moulded plate with GRAPES, REGIONS, STYLES and FLAVORS in its corners, each scooped around MASTER SEARCH in the middle.",
    "The search button is larger and sits at the centre of them rather than in a row of its own.",
    "Every page's marquee glyph is redrawn as a dot-matrix icon, and there are eighteen more of them -- the globe, a country, a continent, the family tree, both searches and the menu itself all had none.",
    "Marquee glyphs take the colour of the marquee's own lettering, and change with the shell.",
    "SYSTEM and SETTINGS stop sharing a glyph on the panel.",
    "Opening a pack from the shop is a page you can come back from. BACK returned you to SYSTEM; it returns you to the shop.",
    "The screen keeps its grid behind the bouncing V. The screensaver had been blanking to a flat panel, and a lighter one than the app on three of the screen modes.",
    "The incised symbol on each of the four footer buttons takes the shell's glyph colour instead of the shell's button colour, so the house, the chevron, the cog and the figure read as marks rather than as grooves.",
    "The footer buttons stop painting outside themselves. A ring of shell-coloured pixels around each cap is clipped away, and the last of the cast shadow the art carried has gone.",
    "Every country and state outline is hand-drawn: 33 places, on real coastlines. UNITED KINGDOM, SLOVENIA and LEBANON have shapes for the first time, and thirteen more are drawn and waiting for the wine.",
    "Six regions moved a fraction on their new maps -- Margaret River, Maipo, Santorini, Niagara, the Basque Country and Itata.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const DISPLACED_0_8_3: FirmwareRelease = {
  version: "0.8.3",
  date: "2026-08-06",
  // Four things came off the shop and nothing came off the dex. The shelves are
  // drawn cartridges throughout now, the marquee wears the drawn faces, and the
  // footer caps lost the shadow that was painted into them.
  headline: "SHELVES OF CARTRIDGES",
  notes: [
    "Four things have left the shop: the FLAVOR WHEEL and the ITALY, FRANCE and SPAIN packs. Nothing left the dex with them -- every grape, region and style they covered is exactly where it was.",
    "If you already own one of those, you still own it, and it still opens what it always opened.",
    "Every shelf is drawn cartridges now. The four that had no picture were the four that left.",
    "A pack's page is the cartridge, centred and much larger, with the pack's name printed on its label.",
    "The file card that used to sit behind each cartridge is gone, on the shelf and on the page. The packs are a step larger for it.",
    "The SCREEN MODES packs preview the actual screen -- glyph, lines and all -- instead of a reduced version. AMBER and VINTAGE had been previewing in green.",
    "The marquee's page glyph is the drawn button face, in black.",
    "The two lamps above the marquee wear their drawn faces too, in colour.",
    "The four footer buttons have lost their cast shadow, and they depress when you press them.",
    "A style's ORIGIN sits on its own bar under the tiles, the way a grape's already did.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const DISPLACED_0_8_2: FirmwareRelease = {
  version: "0.8.2",
  date: "2026-08-06",
  // The lineage dataset stops being a sample. 102 more grapes were researched
  // against the variety register, which takes the number with a tree from 75 to
  // 121 -- and gives 74 of them the one thing an empty tree could never say,
  // which is that the parentage is genuinely unrecorded rather than unwritten.
  headline: "WHERE GRAPES COME FROM",
  notes: [
    "A hundred and two more grapes have been traced. 121 of the 177 now open a family tree, up from 75.",
    "Seventy-four grapes say PARENTAGE UNRECORDED. That is a statement about the wine, not about this app: Nebbiolo, Zinfandel, Aglianico, Assyrtiko and Garganega have no established parents, and the dex now says so instead of showing nothing.",
    "Seven Spanish and Catalan whites turn out to share one parent, Heben -- Airen, Macabeo, Xarel-lo, Parellada, Pedro Ximenez, Trepat and Sumoll. Macabeo and Xarel-lo are full siblings.",
    "Roussanne and Marsanne are first-degree relatives, and each one's tree now says so.",
    "Mencia is not Cabernet Franc, and its real parents are on its page. Hondarrabi Zuri is Courbu Blanc.",
    "Madeira and Cava file under ORIGIN, beside Champagne, Port and Sherry. They are places before they are styles.",
    "Madeira is a white wine. It had been showing no colour at all.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

const DISPLACED_0_8_1: FirmwareRelease = {
  version: "0.8.1",
  date: "2026-08-06",
  // Prosecco. Sixteen of the thirty-three styles were reporting a colour the
  // data does not give them, and Prosecco was the one that reported a wrong
  // one loudly enough to be seen -- the word "rose" is inside it.
  headline: "PROSECCO IS NOT A ROSE",
  notes: [
    "Prosecco is a white wine again. It had been reading as rose, and fifteen other styles -- Champagne, Port, Sherry, Cava and the rest -- were quietly reporting no colour at all.",
    "The styles list can now be filtered by COLOUR and by COUNTRY, alongside STYLE CLASS.",
    "Six flavour families were grey chips: GAME, SAVOURY, BREAD, SMOKY, SALTY and BRINY all have their own colour now, on the chip and on the glyph.",
    "A flavour's CLASS and SUBCLASS are its FLAVOR and its FAMILY, and both glyphs are half again as large.",
    "TYPE YOUR GUESS is a proper search bar. It still only suggests wines you have already met.",
    "The family tree draws its lines to the boxes. They had been aimed at a tile size two releases old, and stopping short of the labels.",
    "A parent that is a real grape but has no page here is a box like every other node, instead of loose text in a row of tiles.",
    "The marquee's glyph sits above its word on the menu, and pixelates away with it when you come home.",
    "The screensaver toast changes language every five seconds instead of once per idle, so an idle minute gets through most of the nine.",
    "The bouncing V is half again as large.",
    "The chassis mockup in CUSTOMIZE has its orb back at the size the rest of the mockup is drawn at.",
    "The shop shows the device: DEVICE PACKS and DISPLAY PACKS preview the actual chassis instead of a coloured disc.",
    "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
  ],
};

/** Everything before `CURRENT`, newest first. */
const PREVIOUS: FirmwareRelease[] = [
  DISPLACED_0_8_7,
  DISPLACED_0_8_6,
  DISPLACED_0_8_5,
  DISPLACED_0_8_4,
  DISPLACED_0_8_3,
  DISPLACED_0_8_2,
  DISPLACED_0_8_1,
  {
    version: "0.8.0",
    date: "2026-08-06",
    // A minor bump rather than 0.7.10, for the two changes a player cannot miss:
    // every country outline in the app is redrawn, and the boot screen stops
    // saying the machine was made by itself.
    headline: "NEW MAPS, NEW MAKER",
    notes: [
      "Every country and state outline is redrawn -- all thirty, from the same rings, at the same weight. The old set was hand-drawn one at a time and it showed.",
      "Every region dot was checked against its new map. Seven had been sitting in open water for releases and are now on land: Margaret River, Santorini, Shandong, Okanagan Valley, Guerrouane, Calabria and Mallorca.",
      "Corsica and Mallorca are drawn now, so the regions on them have somewhere to be.",
      "The boot screen is by HORIZON/GODOT, centred, and a size larger. The VINODEX HANDHELD SYSTEM line is gone.",
      "\"Paper\" is \"exam\" everywhere you read it -- on the exam screen, in the daily challenge, and in the reminders.",
      "WHAT'S THAT...? suggests names as you type, but only ones you have already met in the dex. It will not hand you a wine you have never seen.",
      "GIVE UP is a button now instead of a line of grey text, and the whole screen is a size larger.",
      "Europe's marker on the globe is blue. It and North America were two dark reds a few points apart.",
      "The rose chip is pink. It had been falling through to grey on every rose style since the chip table shipped.",
      "The four menu tiles finally share a baseline. STYLES and FLAVORS were sitting low against the other two.",
      "Search boxes say what they are searching -- SEARCH GRAPES, SEARCH FLAVORS, and so on.",
      "The screensaver waits a full minute instead of thirty seconds. Thirty was still inside the time it takes to read a page.",
      "The orb on the notch row is as tall as the lamps opposite it and lit the same way, which finishes the job 0.7.9 started on its width.",
      "A grape's origin moved out of the three-tile row onto its own bar, the way a region names its key grape.",
      "The back plate no longer explains how to move a sticker.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.9",
    date: "2026-08-06",
    // The batch's own headline was the orb, but the orb is a bead on the chassis
    // and WHAT'S THAT...? is a tool that stopped being a reveal and became a game
    // you can lose. That is the one a player notices.
    //
    // **There was a second 0.7.9, and it is not in this list on purpose.** A
    // parallel session on `testing` (Aug 5) shipped an entry called XCODE BUILD
    // under this same number: an Xcode/simulator build target plus the codesign
    // fix that stopped bundling `Resources` as a folder. Its *code* is merged --
    // `Package.swift`, every `Bundle.module` subdirectory lookup, and the
    // `FirmwareTests` bundle-leak fix all came across intact. The changelog
    // entry did not, by the user's ruling, for the reason this file states in
    // its own header: it holds what the device is willing to say about itself,
    // and "resource folders are bundled one by one" is not a sentence a player
    // has any use for. Two entries under one number would also have broken the
    // generator's no-duplicates assertion, which is what surfaced the collision.
    headline: "NAME THAT WINE",
    notes: [
      "WHAT'S THAT...? is a guessing game now. Clues arrive one at a time and you name the wine.",
      "It deals a grape or a region, and the clues go from vague to specific: the colour, then the country, then the flavour that gives it away.",
      "Guess early for more credit. Every clue you take is one you did not need.",
      "Type your answer -- it understands synonyms and near-misses, so Steen is Chenin Blanc and a slipped letter still counts.",
      "A wrong guess tells you what you actually named, so the miss narrows the field instead of just saying no.",
      "It still deals the same wine to everyone on a given day, and reopening it deals the next one.",
      "The daily challenge is untouched and keeps its own streak.",
      "Eight new entries: Madeira and Cava as styles, and the grapes Sercial, Boal, Malvasia de Sao Jorge, Gouais Blanc, Plavac Mali and Manto Negro.",
      "Thirteen new exam questions, and fortified wine is no longer the thinnest exam on the beginner tier.",
      "Brazil and Mexico have outlines at last. Serra Gaucha, Campanha and Valle de Guadalupe drew nothing on the map before this.",
      "The family tree is bigger and easier to read. Long tiers collapse to six with a SHOW ALL, so a grape with ten children fits on the screen.",
      "A grape whose parents are genuinely unknown now says so, which is different from one nobody has written down yet.",
      "Label scan reads appellations that run across two or three lines. It could not see those at all before.",
      "When it narrows a bottle down without settling it, it shows you the shortlist instead of reporting no match.",
      "The orb is the full width of the lamps opposite it, so the two ends of the notch row read as a matched pair.",
      "Blaufrankisch is filed under Slovenia now, with Burgenland still named as where it made its reputation.",
      "446 entries: 177 grapes, 124 regions, 33 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.8",
    date: "2026-08-05",
    // Sections B-D landed after A, and they are the bigger story: the device can
    // now put something of yours in front of someone else. A's headline was BACK
    // IN THE SCREEN -- its four items are still listed below, under the new one.
    headline: "SHOW SOMEBODY",
    notes: [
      "Every encyclopedia entry has a share button. It exports the entry as a pixel-art card, framed in your device.",
      "Your passport shares too: rank, completion, the counts and your streak, on a card in your own shell and screen colours.",
      "Earned stamps are shareable one at a time. Tap any stamp you have to send just that one.",
      "Finish the daily challenge and you get a result to post: a row of tiles, your score and your streak.",
      "The tiles say how you did and never what the answers were, so sharing yours cannot spoil anyone else's paper.",
      "Copy it or send it straight on. Both, because pasting into a thread and picking an app are different jobs.",
      "New in Settings > Device: DAILY REMINDER. Off until you turn it on, and it only asks permission at that moment.",
      "It sends at most two a day -- today's paper is live, and a streak about to break -- and neither one arrives if you have already played.",
      "Turn notifications off for Vinodex in iOS Settings and the switch says so instead of pretending it is on.",
      "The BIOS boots inside the display again, with the device around it instead of covering it.",
      "Its drawn border, rails and corner brackets are gone. The chassis does the framing now.",
      "The version, the copyright, the scanlines and the glow all stay. The two top lines stack, so neither is squeezed.",
      "Any touch anywhere still carries on, and nothing on the device can be pressed by accident while it starts up.",
      "The sticker on the back is a sticker again: die-cut, glossy, one corner lifting. It stopped being a seventh postage stamp.",
      "The six passport stamps are the collection. The sticker is decoration, and it cannot be picked up or moved.",
      "Choosing a shell or a screen in Customise now overrides parts you fitted in the Workshop, so the one you picked is what you see.",
      "Builds you saved are untouched. Fit one again from the Workshop whenever you like.",
      "The orb is a longer pill again, closer to the shape of the notch above it.",
      "438 entries, unchanged: 171 grapes, 124 regions, 31 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.7",
    date: "2026-08-04",
    // A whole batch on one screen, and it is the first screen -- so the headline
    // is what the screen now calls itself rather than what changed about it.
    headline: "VINODEX BIOS",
    notes: [
      "The startup screen is rebuilt, edge to edge: a proper BIOS boot instead of a panel of text.",
      "The V and the wordmark sit at the centre, framed by a terminal border with corner brackets and side rails.",
      "Scanlines and a faint glow behind the logo, like a CRT warming up.",
      "The checks still run first. They resolve, and the screen settles rather than cutting away.",
      "It then waits on PRESS ANY BUTTON TO CONTINUE. Any touch carries on, and so does it, after a few seconds.",
      "The corner reads your real battery level.",
      "The version in the top corner is the firmware's, so this screen always says what you are actually running.",
      "438 entries, unchanged: 171 grapes, 124 regions, 31 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.6",
    date: "2026-08-04",
    headline: "TWO BUTTONS",
    notes: [
      "The two lights on the marquee are the shortcuts now. Always there, one tap.",
      "Hold either light to point it somewhere else: tools, customise, settings, data or the shop.",
      "The swipe-out drawer behind the panel is gone, and so are the small pin buttons in its corners.",
      "Your pinned shortcuts carry over. If you had none, the lights stay on Tools and Customise.",
      "The screensaver waits 30 seconds instead of 15, and starts from a different spot each time.",
      "The marquee says cheers on every screen now, not just the menu, and at the same moment the screensaver arrives.",
      "Nine languages still, one per idle.",
      "The orb is an elongated pill, matching the notch above it.",
      "Three more parts in the Workshop: the header lights, the marquee lights, and the footer buttons.",
      "Ten parts in all. Builds you have already saved are untouched.",
      "New shell: W64. Purple deck, four coloured face buttons.",
      "Shop splash screens are bigger, and show what is in the box: the shells, the screens, or a look at the entries.",
      "The tutorial moves into Settings, under Device, beside firmware and the cheat console.",
      "The tour has a new page about the two lights.",
      "438 entries, unchanged: 171 grapes, 124 regions, 31 styles, 106 flavours, 26 countries.",
    ],
  },
  {
    version: "0.7.5",
    date: "2026-08-04",
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
  },
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
