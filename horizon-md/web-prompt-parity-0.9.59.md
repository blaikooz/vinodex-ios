# Paste this into the web session — parity with iOS 0.9.59

> iOS 0.9.59 (build 368, "UNDER YOUR FINGER") went to internal testers on
> 15 Sep. Your data is already current — the hub and both mirrors agree, and
> the only catalog change in this build is one you already carry (`R216`
> Western Cape, plus your own `berryColor` fix, which reached iOS unchanged).
> What follows is what changed on the iOS *surface*, sorted by whether web
> should mirror it. The standing rule holds: the iOS terminal never commits
> or pushes `vinodex-web`; this is yours.
>
> ## 1. Mirror these — they are obligations or already-ruled behaviour
>
> **A credits page, following NOTICE.md line for line.** iOS moved its credits
> off the FIRMWARE screen to a page of their own (SETTINGS ▸ CREDITS). Two of
> the entries are licence *conditions*, not courtesies, and web ships the same
> assets: R74n's pixel flags (permission of 7 Sep 2026, credit requested),
> the fifty-five game-icons.net glyphs (**CC BY 3.0 — attribution to each
> artist is required**), Lucide (ISC), Material Design Icons (Apache 2.0),
> Press Start 2P and VT323 (OFL). If web ships the LWIN index anywhere it also
> owes the CC BY 4.0 line with the modification stated. **Check whether web
> has an attribution page at all**; if not, this is the gap, and NOTICE.md in
> the iOS repo is the text — iOS's `CreditsScreen.swift` is the same content
> laid out, if you want the order.
>
> **States come from the data** — the prompt you already have
> (`horizon-md/web-prompt-states-from-data.md`). Unchanged; still open.
>
> **The DATA readout order**, if web has an equivalent stats view: grapes,
> continents, styles, countries, flavors, regions — read as a two-column grid
> top-left to bottom-right. Pinned by a test on iOS.
>
> ## 2. Consider mirroring — behaviour the maintainer ruled on iOS
>
> **A region's icon is its country's flag with the region lit.** On iOS every
> region tile and hero now draws the country's flag as the ground, the
> country's silhouette over it, the region's own area lit, a white ring. iOS
> derives the silhouette from the region maps' index rasters, which web does
> not carry. Three honest options, in rising cost: keep web's flag-plus-
> outline icon (the shape is the same, minus the lit region); ship the 39
> logical-scale index rasters to web (they are small — a few hundred cells a
> side — and would let web draw the identical silhouette); or ask the art
> session for a web-specific asset. Say which you'd take before doing any of
> it; the maintainer may rule "iOS-only" for the maps.
>
> **A place's card is one tile; what's inside it lives on its page.** Web's
> country-gate drill-down is the analogue. Unchanged from the last prompt.
>
> **South Africa** — the Western Cape (`R216`) is now the province the four
> districts sit inside; on web that is a data fact you already have, and the
> country page should list all five.
>
> ## 3. Do not mirror — iOS-only mechanics
>
> Drag scaled by zoom, the sea skirt for island maps, the Wachau catchment,
> the globe's nearest-texel magnification, the opening-view gap rule, the
> 120-second screensaver: all globe or device behaviours with no web surface.
>
> ## 4. The firmware notes, verbatim, if your changelog mirrors them
>
> > UNDER YOUR FINGER
> > - A country's map moves at the speed you move it, and a tap that misses a region no longer throws you back to the globe.
> > - The Canaries, Madeira and the Azores are drawn on their maps, and Spain and Portugal open wide enough to show them.
> > - Every region wears its country on its flag with the region lit, on its own page and in every list.
> > - South Africa is one honest Western Cape with its districts inside it, instead of stripes cut across the map.
> > - The credits have a page of their own under SETTINGS, naming every licence the device carries.
>
> ## 5. Two findings from the audit that are yours
>
> - `find-missing-refs.ts:52` skips `classification: 'STATE'` gates; the
>   fifty state gates' `keyRegions` and `notableGrapes` have never been
>   checked by anything. Lifting the exclusion is cheap.
> - If your gate lookup is keyed by bare name, the US state Georgia collides
>   with the country Georgia; iOS fixed it with a `state:` key prefix and two
>   reachability sets (a state is reachable only through a region's `state`).
>
> ## 6. Where things stand
>
> iOS: 0.9.59 with internal testers; App Store release **blocked until the LLC
> exists** (Horizon Godot LLC, New York) and the app is re-created under the
> organisation's Apple account — Apple's App Transfer requires a released
> version, which Vinodex has never had. Provisional freeze 23 Oct, submit
> 31 Oct. Web: 0.6.64 uncommitted in your tree as of 14 Sep; whether web
> continues at all is the maintainer's open decision
> (`horizon-md/web-app-viability.md`) — until he rules, you are a maintained
> mirror and this prompt applies.
