# For the web session — what the iOS side did on 13–14 Sep, and what it means for you

Written 14 Sep 2026 from the iOS terminal. Read this before your next batch.
Your data is already current: every `shared/data/*.ts` in `vinodex-web` matches
the hub byte-for-byte, and your `coverage.test.ts` already reads 224 grapes /
216 regions / 592 entries, so nothing below is a delta you have to apply — it
is the *reasoning* behind the data you now carry, the rules that were decided,
and four findings that affect only you.

**Standing rule, unchanged:** the iOS terminal never commits or pushes
`vinodex-web`. Your tree has a 543-file uncommitted batch in it right now
(v0.6.64: OG regeneration, pins, changelog); it is yours, and it has not been
touched.

---

## 1. Where the two apps stand

| | iOS | web |
|---|---|---|
| shipped | **0.9.58 (356)** to TestFlight internal, 14 Sep — "THE MAP FILLS IN" | 0.6.63 |
| in flight | 0.9.59 on `fixes-0.9.59`: ten device-test fixes, South Africa re-cut | 0.6.64, uncommitted |
| catalog | 592 entries: 224 grapes, 216 regions, 40 styles, 106 flavors, 6 continents, 39 countries | same |
| 1.0 | feature freeze **2 Oct**, tag v1.0.0 5 Oct, submit 10 Oct | — |

**The hub is master.** `HGapps/shared/data/*.ts` is the only place data is
edited; both apps' `shared/` are generated copies. `sync-shared.sh` copies
hub → mirrors. On 13 Sep it deleted three firmware releases from the iOS
mirror because the hub's `firmware.ts` was stale at 0.9.54 while iOS was at
0.9.57 — the hub has been forward-ported and is current (0.9.58 at head), so
a sync is safe today. **Before any sync, `diff` the hub's `firmware.ts`
against yours**; the script does not check direction.

---

## 2. What landed in the catalog, and why (sommbot, four batches, 14 Sep)

**+49 regions (R168–R216), +3 grapes (G223–G225).** The ruling behind them:
*every painted area on a region map has a catalog entry that IS the area — the
region or the state — never a list of the appellations inside it.*

- **25 dead painted areas** got entries: San Juan, Catamarca, Córdoba; Coquimbo,
  Rapel, Maule, Bío Bío, Malleco; Valle d'Aosta, Liguria, Molise; seven New
  Zealand GIs; Beira Interior, Setúbal, Algarve; Aragón, Madrid (as "Vinos de
  Madrid"), Andalucía, Extremadura.
- **Seven containers** that only had children got parents: Galicia, Catalonia,
  Ningxia, Aconcagua, Lisboa, Levante, Baleares.
- **Six provinces** that had been wearing the name of the one appellation inside
  them: British Columbia, Ontario, South Australia, Western Australia, New South
  Wales, South Aegean. Plus the **Western Cape** for the same reason (see §5).
- **Islands, by order:** Tasmania, Crete; Canary Islands / Madeira / Azores
  already existed and are now painted.
- **US regions the state gates named without having:** Columbia Valley, Yakima
  Valley, Rogue Valley, Umpqua Valley, Long Island, Hudson River Region — all
  with `details.state`, and restored to the four state gates' `keyRegions`.
- **Hokkaido**, and **the Golan Heights** under Israel with its status stated in
  the prose in one plain clause (maintainer's ruling; the sentence is
  deliberate — do not soften or strip it).
- **Crete's natives** Vidiano, Liatiko, Kotsifali, notes from the closed
  vocabulary, so flavors stay at 106.

**Rueda & Toro** was *not* authored: sommbot ruled no region by that name
exists; the painted area was split on the art side instead.

Two catalog findings you should know about, both still open in
`data-review/FINDINGS.md`: VIVC now gives **Vidiano** a marker-confirmed parent
(Albanello × ?), contradicting its `parentageUnknown`; and **Liatiko**'s skin is
red-to-violet, a berry-hue row if you carry one.

---

## 3. Four findings that affect only you

1. **`keyRegions` dead links were web-only.** iOS's `CountryInfo` carries only
   `description` and `appellationSystem`; `keyRegions` and `notableGrapes` on
   gates never reach the device. Six of the twelve `keyRegions` on the four
   shipping state gates pointed at regions the catalog did not have — Oregon
   claimed Rogue and Umpqua, Washington claimed Yakima and Columbia Valley, New
   York claimed Long Island and the Hudson. They exist now, but **your
   `find-missing-refs.ts` skips `classification: 'STATE'` gates at line 52**,
   same as the iOS checker did, so it never told you. Across all fifty gates,
   196 names had never been checked by anything. Consider lifting that
   exclusion.
2. **The Georgia collision.** `countries.json` on iOS was keyed by bare gate
   name, and the US state Georgia collided with the country Georgia — the
   country won only because states are written first in `countries.ts`. iOS
   now emits states under a `state:` prefix. **Check how your gate lookup is
   keyed**; if it is by name, the same collision exists and will surface the
   day someone authors a Georgia (US) region.
3. **Washington's blurb was wrong.** "High-altitude freshness" is not the
   mechanism; it is desert farming on 6–8 in. of rain with latitude and a
   30–40°F diurnal swing. Rewritten in the hub, with California, Oregon and
   New York's blurbs — you carry the new text already; if you cache rendered
   gate copy anywhere (OG cards?), regenerate.
4. **The four state gates now carry `keyRegions` that resolve**, including
   San Benito under California, which had been missing.

---

## 4. Behaviours decided on iOS that you may want to mirror

None of these are data; all are rulings the maintainer made while walking the
device. Where web has an equivalent surface, parity is worth considering.

- **A place's card is one tile.** Tapping a painted state or province shows the
  state/province tile alone; what is inside it lives on its page. iOS: the
  globe card. Web equivalent: country-gate drill-down rows.
- **Province pages list what the map put inside them.** British Columbia's page
  carries an INSIDE IT section with Okanagan Valley; Galicia's lists Rías
  Baixas and three more; Bordeaux reaches Sauternes. On iOS this is derived
  from the region map's pins (`RegionMap.regionsInside`), which you do not
  have. **If you want it, the honest source is the same one:** the province's
  `appellations` strings, or a parent field sommbot could author. Ask before
  inventing a join.
- **State pages show the state's authored blurb.** iOS's `StateScreen` never
  read `countries.json`'s state description until this week. Check yours does.
- **A painted area is named after itself.** Oregon is OREGON, not WILLAMETTE
  VALLEY; British Columbia is not OKANAGAN VALLEY. If any web label derives a
  province's name from the appellation inside it, it is wrong the same way.
- **Screensaver is 120 s** (was 60). Web has no equivalent; noted for parity of
  the firmware notes.

---

## 5. The map campaign, in one paragraph, so the words in the notes mean something

39 wine countries now have painted region maps on the iOS globe (7 → 39 this
week), 172 painted areas, **0 dead, 0 unpinned**. Every backdrop draws its real
neighbours (a 108-country European extract had been reused for all 39). The
Canaries, Madeira, Azores, Tasmania, Crete, Alaska and Hawaii are on their
maps; Crimea is painted as Ukraine by ruling (a deliberate Natural Earth
override, recorded); the Golan is cut out of HaZafon (Natural Earth files it
under Israel — not, as everyone assumed, Syria); the Wachau is on Austria's
second index plane, its boundary the eight Gemeinden Weingesetz 2009 §21(3)
names. South Africa was re-cut from four axis-cut districts that read as
stripes to one honest Western Cape, because the Wine of Origin districts are
gazetted as a *register of names* with no boundary text, and municipal
boundaries are open, tempting and wrong (WO Paarl ≠ Drakenstein LM). None of
this exists on web and none of it needs to; it is why the catalog grew the way
it did.

---

## 6. The firmware notes for 0.9.58, verbatim, if your changelog mirrors them

> THE MAP FILLS IN
> - Every painted area on every region map has its own entry now: forty-eight regions joined, and not one tap on a map lands on nothing.
> - Provinces and states name themselves: British Columbia is British Columbia, and what sits inside it lives on its page.
> - The Canaries, Madeira, the Azores, Tasmania and Crete are on their maps, and Alaska and Hawaii are back on the USA's.
> - Every map draws its real neighbours: the USA has Canada and Mexico beside it instead of open sea.
> - A country's map fills the glass and stays on the art: pinch and pan as you like, it will not show you the globe underneath.

(0.9.59 will add the Western Cape, making forty-nine.)

---

## 7. On the web app's future — the research, not a decision

The maintainer asked whether Apple's rules kill the web app. They do not:
guideline 4.2 rejects a *submitted* WKWebView wrapper, and `vinodex-web` was
never scaffolded to be one — it was built as the funnel *into* the native app
(`InstallBanner.tsx`). The real question is the mirror cost per batch versus
the share-link funnel, SEO and non-Apple reach. The sourced note is at
`horizon-md/web-app-viability.md`. The decision is the maintainer's and has
not been made; until it is, you are a maintained mirror.

---

## 8. Where things are

- `horizon-md/art-session-prompt.md` — the art pipeline's working agreement,
  rev 2, rewritten this week. §3 "the art is not the catalog" and §7 "gates,
  and how gates lie" apply to any pipeline, yours included.
- `data-review/FINDINGS.md` and `CANDIDATES.md` in the hub — sommbot's
  ledgers; the 14 Sep sections (a)–(d) are this week's batches.
- `art/inbox/region-maps/DROP-2026-09-13.md` — the campaign record.
- The iOS train: branch → CI → `testing` → CI → PR → merge. Poll runs by SHA,
  never by "latest"; guard the checkout with `git diff --quiet`; expect a stale
  `.git/index.lock` when two sessions touch one repo.
