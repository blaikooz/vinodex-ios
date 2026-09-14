# Is vinodex-web viable on iOS? — a sourced note

Research note, 2026-09-14. Premise under test: *"vinodex-web probably will die as
Apple doesn't allow web apps packaged as iOS."* Sources fetched today; quotes verbatim.

## 1. What the App Store Review Guidelines actually prohibit

From https://developer.apple.com/app-store/review/guidelines/ (fetched 2026-09-14):

> **4.2 Minimum Functionality** — Your app should include features, content, and UI
> that elevate it beyond a repackaged website. If your app is not particularly useful,
> unique, or "app-like," it doesn't belong on the App Store. If your App doesn't provide
> some sort of lasting entertainment value or adequate utility, it may not be accepted.

> **4.2.2** — Other than catalogs, apps shouldn't primarily be marketing materials,
> advertisements, web clippings, content aggregators, or a collection of links.

> **4.2.3 (i)** — Your app should work on its own without requiring installation of
> another app to function.

> **2.5.6** — Apps that browse the web must use the appropriate WebKit framework and
> WebKit JavaScript. You may apply for an entitlement to use an alternative web browser
> engine in your app [EU and Japan].

What these rule on is a **binary submitted to the App Store**. Concretely:

- **Would be rejected:** a second app that is a `WKWebView` pointed at
  `horizongodot.com/dex` (or the same React bundle loaded locally) and submitted as
  "Vinodex". That is the "repackaged website" 4.2 names. It would also be redundant
  with the native app already in review, which reviewers flag under 4.3 (spam).
- **Not affected at all:** a website that is never submitted. The guidelines govern
  App Store distribution; they have no jurisdiction over what Safari opens or what a
  user adds to their Home Screen. Nothing in 4.2, 4.2.2, or 2.5.6 restricts a PWA.

Note 4.2.2's exception — *"Other than catalogs"* — is exactly Vinodex's shape; even
the wrapper case is less clear-cut than "not allowed". But it is moot: a wrapper was
never proposed, and the native app already exists.

## 2. What a PWA can do on iOS today

Apple's own documentation, not third-party summaries:

- **Add to Home Screen / standalone.** Supported since iPhone OS 1; vinodex-web already
  ships `display: 'standalone'` and `apple-mobile-web-app-capable`. Since iOS 16.4,
  "Third-party browsers can now offer their users the ability to add websites and web
  apps to the Home Screen from the Share menu."
  — https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/
- **Push notifications and badging.** Same post, iOS/iPadOS 16.4: "Web Push makes it
  possible for web developers to send push notifications to their users through the
  use of Push API, Notifications API, and Service Workers all working together" —
  only for web apps added to the Home Screen. Badging API (`setAppBadge`) shipped
  alongside.
- **Service workers and storage.** WebKit's storage policy (Safari 17 / iOS 17):
  "For a browser app, the origin quota is up to 60% of the total disk space" and
  "When a web app is running standalone (as Home Screen Web App on iOS …), it has the
  same origin quota and overall quota as when it is opened in a browser app."
  — https://webkit.org/blog/14403/updates-to-storage-policy/
  Safari's 7-day script-storage eviction applies to sites in the browser with no
  interaction; Home Screen web apps with a standalone manifest keep their own
  counter and are not the target of it.
- **Camera.** `getUserMedia` in standalone Home Screen web apps was broken in iOS 11–13
  and fixed in iOS 13.4 (WebKit bug 185448, RESOLVED FIXED:
  https://bugs.webkit.org/show_bug.cgi?id=185448). Works, but through the browser
  permission model, not `AVFoundation` — no fine control, no ProRAW, no Vision.

What a PWA **cannot** do: appear in the App Store or in Spotlight app search; use
StoreKit (no IAP, no subscriptions via Apple, no family sharing); use native
frameworks (Vision, Core ML on-device, widgets, App Intents, Live Activities); ship
under the app's own bundle identity for ratings and reviews.

**The EU DMA wobble (stability of the route).** In February 2024 Apple announced
Home Screen web apps would be removed in the EU under iOS 17.4, citing "complex
security and privacy concerns associated with web apps using alternative browser
engines." On 1 March 2024 it reversed: "We have received requests to continue to
offer support for Home Screen web apps in iOS, therefore we will continue to offer
the existing Home Screen web apps capability in the EU," adding that "Home Screen web
apps continue to be built directly on WebKit and its security architecture."
— https://9to5mac.com/2024/03/01/apple-home-screen-web-apps-ios-17-eu/ ;
https://techcrunch.com/2024/03/01/apple-reverses-decision-about-blocking-web-apps-on-iphones-in-the-eu/
Reading: the PWA route survived a direct test, but it was Apple's discretion (and
regulator pressure) that saved it, not a guarantee. That is the real fragility — not
the review guidelines.

## 3. What vinodex-web is, concretely

Read from `/Users/hsmini/Developer/HGapps/vinodex-web` (unmodified):

- **Vite 6 + React 19 + TypeScript + Tailwind v4**, `package.json` v0.6.62, deployed
  on Vercel as `www.horizongodot.com` (`vercel.json` SPA rewrite).
- **It is a real PWA.** `vite.config.ts` uses `vite-plugin-pwa` with a full manifest
  (`name: 'VINODEX'`, `display: 'standalone'`, `start_url: '/dex'`, maskable icon),
  `registerType: 'autoUpdate'`, a deferred `registerSW.js`, a Workbox precache of the
  shell (~5 MB) and runtime `CacheFirst` for the 254 art PNGs. `web/index.html` sets
  `apple-mobile-web-app-capable` and `apple-touch-icon`. `vercel.json` sets no-cache
  on `sw.js` and `manifest.webmanifest`.
- **It is also the studio site.** `/` is Horizon/Godot's four-page site; the dex
  opens from inside it. 524 prerendered `/detail/<id>` OG cards; `/entry/<id>` alias
  added in v0.6.62 so iOS share-sheet links unfurl.
- **Was it ever meant to be packaged as an iOS app? No.** The repo's history runs
  the other way: it *generated* the Swift package until 2026-07-29, then the iOS app
  "moved out and owns its source". There is no Capacitor, Cordova, or WKWebView
  scaffolding anywhere. The opposite intent is explicit: `web/components/InstallBanner.tsx`
  is "the 'get the iOS app' nudge — the bottom half of the funnel. The web PWA is
  the surface people arrive on from a shared link; once they've played in the browser,
  this slim bar points them at the native install." `index.html` has a placeholder
  for the `apple-itunes-app` smart-app banner "once the App Store listing is live".
  The website was designed as the funnel *into* the native app, not a substitute for it.

## 4. The real question, stated as a cost

**The Apple-rules premise does not hold.** Nothing in the guidelines touches a
website that is not submitted; vinodex-web is not submitted and was never scaffolded
to be. If it dies, it dies for a maintenance reason, not a policy one.

**Keeping it** costs, per catalogue batch: run `sync-shared` to mirror
`HGapps/shared` into `vinodex-web/shared/` (README: "mirrored — do not edit here";
a sync overwrites the copy), move the coverage pins, run the five gates
(`typecheck`, `test`, `build`, `check:refs`, `test:e2e`), bump and deploy. Today
that is a hand-off to a separate session each time, and the web lags the iOS
catalogue by weeks (v0.6.61 was "the iOS 0.9.44–0.9.53 catalogue catch-up"). It
also keeps two implementations of every rule that can disagree, with Swift as
reference. What it buys: the share-link funnel (`/entry/<id>` unfurls; a link
opens something without an install), the studio site, SEO for 524 entries, and an
Android/desktop surface the native app cannot reach.

**Retiring it** means one front-end, one catalogue, no mirror step, and no
parity docs. What it loses: shared links land on nothing playable (or a bare
landing page), the install-banner funnel, and any non-Apple reach. The studio
site at `/` would need to survive separately or be reduced to a landing page.

Both are defensible. The decision should be made on that ledger — mirror cost
versus link-funnel and reach — not on a rule that does not apply.
