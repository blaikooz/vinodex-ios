# Vinodex beta outreach — plan for the posting session

Paste this whole file into a new Claude chat that has **Claude in Chrome** (for
Reddit, Hacker News, forums and App Store Connect in the browser) and, if you
want replies handled, **Gmail**. This chat is the poster; the iOS terminal
session stays the builder. Everything the poster needs to know is here; it
should not have to open the repo.

Written 14 Sep 2026 by the iOS terminal. Dates are real; re-check anything
about a community's rules on the day, because those change.

---

## 0. What Vinodex is, in the words the posts should use

A **retro-handheld wine encyclopedia for iPhone and iPad** — the whole thing is
drawn as a pocket device with a chassis, an LCD and a marquee. 592 entries:
224 grapes, 216 regions, 40 styles, 106 flavours, six continents, 39 wine
countries, all on the device with no account, no sign-in and no signal needed.

Three things nothing else does:

- **A label reader.** Point the camera at a bottle and it matches the label
  against a 185,000-wine index carried on the device — offline, on a mountain.
- **A globe you can open.** Every one of the 39 wine countries has a painted
  region map laid onto the sphere: tap Italy, tap again, and its regions are
  painted where they belong; tap Bordeaux and you get Bordeaux.
- **An exam in three tiers**, a question a day, and a Passport that keeps score
  of every wine you mark as tried.

Do **not** promise: a launch date more specific than "October", a price, in-app
purchases (that's 1.1), Android or web availability (undecided), or that
anything is "final".

---

## 1. Prerequisite — the public TestFlight link (do this first, once)

Nothing below works without it. External testing is already approved (build
0.9.54 passed beta review), so this is a switch, not a submission.

In Chrome, signed in to App Store Connect as the maintainer:

1. App Store Connect → Apps → Vinodex → **TestFlight** tab.
2. Under **External Testing**, either use the existing external group or
   **+** a new group named `Public beta` — a separate group is better, so it
   can be capped or turned off without touching the friends-and-family group.
3. Add the current build to the group (0.9.58, build 356 today; whichever is
   newest when you post).
4. Open the group → **Enable Public Link**. Set a tester limit — 500 is a
   sensible first cap; it can be raised later.
5. Copy the link (`https://testflight.apple.com/join/XXXXXXXX`). This is the
   only URL any post carries. Never link the repo.

Sanity: open the link in a private window on an iPhone or the simulator — it
should show the app's TestFlight page, not "This beta isn't accepting any new
testers."

If the terminal is asked instead, it can create the group with the public
link through the ASC API; either way the link ends up in this doc under
"Link:" below, and every post reads it from here.

**Link:** _(paste here once created)_

---

## 2. Where to post, in order, and what each one is for

Post in this order — wine people first, because their feedback is the useful
kind — and leave at least a day between the first three so the tester cap
and the crash reports stay readable.

| # | Place | What it gets you | Before posting, check |
|---|---|---|---|
| 1 | **Wine study communities** — WSET / CMS study Discords and Facebook groups, GuildSomm forums | Testers who will use the exam and catch wrong facts. The best feedback available. | Each has its own self-promo norm; ask a mod or read pinned rules. Frame as *asking for expertise*, not launching. |
| 2 | **r/wine** | Reach among enthusiasts. Strict on self-promotion. | Read the sidebar rules on the day. Post as a question to the community ("I built this, would people who study wine try it and tell me what's wrong?"), engage in every reply, and link only the TestFlight page. If the rules forbid it outright, skip — do not argue with mods. |
| 3 | **r/TestFlight**, **r/betatests**, **r/AlphaandBetausers** | Fast, low-friction testers; shallow feedback. Public links are what these subs are for. | Each wants the link and a one-line description in the post body; some want a flair. |
| 4 | **Local, in person** — the nearest WSET course provider, two or three wine shops | A handful of testers who'll talk to you. Costs a conversation. | Bring the link as a QR code (the poster can make one). |
| 5 | **r/iosapps**, **r/SideProject**, r/apple's weekly self-promotion thread, IndieHackers, #buildinpublic on X | Wide, cheap, shallow. | Weekly-thread subs only allow it in the thread. |
| 6 | **Show HN** | The serious audience, and the thread *is* the feedback. **Hold until the 1.0 candidate — around 2 October** — a beta with rough edges gets judged as the product. | Show HN rules: it must be something people can try (a TestFlight link qualifies), title starts "Show HN:", no marketing language. |

Skip the paid tester marketplaces (BetaTesting.com, BetaList's expedite tier)
— the free queues are slow and the paid ones aren't worth it for a free app.

---

## 3. What every post asks testers to do

The ask decides the quality of what comes back. Every post carries the same
short list — it is the maintainer's own device walk, condensed:

1. Spin the globe, tap a country, tap it again, tap a region. Does it fill the
   glass and stay on the map when you pinch and pan?
2. Point the label reader at three real bottles. What did it get right, wrong,
   or miss?
3. Take the exam once. Was any question wrong, or any answer wrong?
4. Open a region's page — does the map highlight the right place?
5. Anything that looked broken, slow, or confusing — screenshot it.

And how to send it: **a screenshot in TestFlight** (shake the phone or use the
TestFlight app's "Send Beta Feedback") goes straight to App Store Connect and
is the lowest-friction channel there is. Offer a reply email only in
communities where that's the norm.

---

## 4. The drafts

Adjust tone to the venue; keep the facts. `LINK` is the public TestFlight URL.

### 4a. Wine community (Discord / Facebook study group / GuildSomm / r/wine)

> I've spent the last year building a wine encyclopedia as a pocket retro
> handheld — think a little drawn device with an LCD — and I'm at the point
> where I need people who actually study wine to tell me what's wrong with it.
>
> 592 entries (224 grapes, 216 regions, 40 styles), all offline. Every one of
> the 39 wine countries has a region map on a globe you can tap into. There's
> a three-tier exam with a question a day, a Passport for wines you've tried,
> and a label reader that matches a bottle against a 185,000-wine index on the
> device with no signal.
>
> It's free and it's a beta — iPhone and iPad, via TestFlight: LINK
>
> What I'd most like from people here: take the exam and tell me if any
> question or answer is wrong; open a region you know well and tell me if the
> prose is right; and try the label reader on bottles you own. Screenshots
> through TestFlight reach me directly. I'll answer everything in this thread.

### 4b. Tester subreddits (r/TestFlight, r/betatests, r/AlphaandBetausers)

> **Vinodex — a retro-handheld wine encyclopedia (iPhone/iPad) — public beta**
>
> LINK
>
> Free, offline, no account. 592 entries, region maps on a globe you tap
> into, a label reader that identifies a bottle from the camera with no
> signal, a three-tier exam and a Passport.
>
> Looking for: globe maps (tap a country twice, pinch and pan — does it ever
> show the bare globe?), the label reader on real bottles, and the exam.
> Screenshots via TestFlight's feedback are ideal. Thanks.

### 4c. Show HN — hold for the 1.0 candidate, ~2 October

> **Show HN: Vinodex – a wine encyclopedia drawn as a retro handheld, fully offline**
>
> I built a wine encyclopedia for iPhone and iPad as a pocket device — a
> drawn chassis, an LCD, a marquee — because I wanted studying wine to feel
> like a Game Boy rather than a textbook.
>
> Everything is on the device: 592 entries, and a label reader that matches a
> photographed bottle against a 185,000-wine index with no network at all.
> Each of the 39 wine countries has a painted region map laid onto a globe
> you can tap into; the region maps are rendered from Natural Earth
> polygons with a per-cell index raster, so a tap resolves to a region by
> data rather than by colour.
>
> It's in TestFlight ahead of an App Store release next month: LINK
>
> Things I'd value a critical eye on: the label reader's matching, the globe
> interaction, and the catalog's facts — I've had a wine-data pass on it but
> I'm one person.

(For HN, the technical sentence is the hook; keep it. No "excited to share".)

---

## 5. Calendar, against the 1.0 dates

| When | Do |
|---|---|
| Now | Create the public link (§1). Post 4a in one study community. Watch a day. |
| +1–2 days | r/wine (if rules allow), second study community. |
| +3 days | Tester subreddits (4b), one per day. Local shops the same week. |
| Weekly | Read TestFlight feedback + crash reports; hand findings to the iOS terminal as a list (it triages). |
| **2 Oct** | Feature freeze, 1.0 candidate build. Post Show HN (4c) that week. |
| 10 Oct | App Store submission. Reply to every open thread with "it's live" when it is. |

Cap at ~500 testers for the first wave; raise it when the crash rate and the
feedback volume are both manageable.

---

## 6. Feedback intake

- TestFlight screenshots and crash reports land in App Store Connect →
  TestFlight → the build → Feedback. Check daily for the first week.
- Thread replies: answer within a day; thank, ask one clarifying question, and
  never argue about taste.
- Hand the iOS terminal a **flat list** each week: what, where, how to
  reproduce, screenshot if any. It triages into TickTick and fixes in batches;
  it does not need the raw threads.
- Facts disputed by testers (a grape's origin, a region's classification) go
  to **sommbot** through the terminal, with the tester's source if they gave
  one. Do not "fix" prose from a thread.

---

## 7. What the poster must not do

- Post the repo, the GitHub, or any screenshot of code or of the terminal.
- Promise dates, prices, or platforms (see §0).
- Post the same text in two places on the same day — mods notice.
- Enable the public link on the friends-and-family group; use a separate one.
- Reply to a bug report with a fix estimate; say "logged" and hand it over.
