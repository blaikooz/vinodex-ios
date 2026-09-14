# Paste this into the web session — states come from the data, not a list

> Maintainer's ruling, 14 Sep, after an id-for-id audit of what each app
> presents: **the entry catalog is identical on both sides** — 6 continents,
> 106 flavors, 224 grapes, 216 regions, 40 styles, every id matching — because
> both build from `shared/constants`. The one divergence is the state layer, and
> it goes iOS's way: **a state is shown when the catalog has a region with
> `details.state` naming it, and not otherwise.**
>
> ## What to change
>
> `web/src/services/entryFilter.ts:42` hard-codes
> `US_STATES = ['California', 'New York', 'Oregon', 'Virginia', 'Washington']`
> and line 193 hides every other STATE gate behind it. Replace the constant
> with a derivation: the set of `details.state` values carried by REGION
> entries. Today that is **California, New York, Oregon, Washington** — four,
> not five. Virginia has no region in the catalog and drops out of the USA
> gate's list until one exists; the day sommbot authors Monticello it comes
> back on its own, which is the point of deriving it.
>
> iOS made the mirror-image mistake and fixed it the same day: its generator
> kept one reachability set by name, so the *country* Georgia being reachable
> carried the *state* Georgia's gate along with it, and the device shipped a
> state page nothing could open. Two sets now — a country through an origin
> or a continent, a state only through a region's `state`. Worth checking
> that whatever keys your gate lookup cannot collide the same way: on iOS the
> fix was a `state:` prefix on state keys.
>
> ## While you are in that file
>
> `find-missing-refs.ts:52` skips `classification: 'STATE'` gates, so their
> `keyRegions` and `notableGrapes` have never been checked — 196 names across
> the fifty gates. Six of the twelve on the four shipping states were dead
> until this week (Oregon claimed Rogue and Umpqua, Washington claimed Yakima
> and Columbia Valley, New York claimed Long Island and the Hudson; all six
> exist now). Lifting the exclusion is cheap and the gate is the only thing
> that will ever notice the next one.
>
> ## What you do not need to do
>
> Your `berryColor` correction (Mavrodaphne typed white by the "red"-in-
> wineType derivation) reached iOS without any further change: hub and both
> mirrors agree, and the iOS generator derives `grapeType` through the same
> path, so the device's Mavrodaphne is red on regeneration. Good fix; nothing
> owed back.
>
> No data changes, no pins move. The iOS terminal does not commit or push
> `vinodex-web`; this is yours.
