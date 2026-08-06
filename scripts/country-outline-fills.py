#!/usr/bin/env python3
"""The colour every country outline is inked in (0.8.4, F1).

**Moved here from `country-outline-rings.py`, and that move is the point.** In
0.8.0 the fill was one argument to a rasteriser: the script drew the silhouette
*and* chose its colour, so the two lived together. 0.8.4 replaces the drawn
half with hand-made art -- 46 masters under `art/icons/countries/`, each a flat
cream silhouette on a magenta key -- and the colour is now applied at import
time by `import-class-art.py` over art it did not draw. One table, one reader,
and the rings file keeps only the geometry it is named for.

The values are 0.8.0's, unchanged, for the reason its own note gives:
flag-dominant mid-tones, deliberately *not* `palette.json`'s `countryChips`,
which are tuned to sit as text on a dark chip and several of which (Brazil's
yellow, Switzerland's near-white) are unreadable as a silhouette.

**Every master has a row, including the sixteen the catalog does not name yet.**
`import-class-art.py` converts only the stems `icons.json` asks for, so a
drawn-ahead outline costs nothing until a region lands in it -- but the day one
does, the wiring is a single `COUNTRY_SHAPE_ICONS` row rather than a row plus a
colour nobody has chosen. `OutlineArtTests.everyMasterHasAFill` fails both ways,
so this cannot drift from the directory in either direction.
"""

# The ink. Flag-dominant, mid-tone, one per master stem.
FILL = {
    # --- Europe -----------------------------------------------------------
    "austria": "#D14B4B",
    "bosnia": "#2E52A0",
    "croatia": "#2E62B0",
    "czechia": "#2E62B0",
    "france": "#2E5AA8",
    "georgia": "#C8342E",
    "germany": "#D9A420",
    "greece": "#3C8DD9",
    "hungary": "#3E8E4F",
    "italy": "#2E9E58",
    "portugal": "#1E7A45",
    "romania": "#2B4C9B",
    "serbia": "#2E52A0",
    "slovakia": "#2E62B0",
    "slovenia": "#2E7DB8",
    "spain": "#C8102E",
    "switzerland": "#D0342C",
    "ukraine": "#3C8DD9",
    "united-kingdom": "#2F4F9E",
    # --- Africa and the Levant --------------------------------------------
    "israel": "#3C8DD9",
    "lebanon": "#C8342E",
    "morocco": "#C8342E",
    "south-africa": "#2E8B57",
    # --- The Americas ------------------------------------------------------
    "argentina": "#6CA8E0",
    "brazil": "#2EA04F",
    "canada": "#D0342C",
    "chile": "#2E62B0",
    "mexico": "#D64837",
    "uruguay": "#4E86C6",
    "usa": "#3B5BA5",
    # US states. Each takes its own flag or seal rather than the federal blue,
    # so a state page does not read as a small USA.
    "arizona": "#C1522E",
    "california": "#C1522E",
    "idaho": "#24408E",
    "michigan": "#24408E",
    "missouri": "#2F4F9E",
    "new-mexico": "#E08A2E",
    "new-york": "#2F4F9E",
    "oregon": "#24408E",
    "texas": "#2B4C9B",
    "virginia": "#2B4C9B",
    "washington": "#2E7D4F",
    # --- Asia and Oceania ---------------------------------------------------
    "australia": "#1F4E9C",
    "china": "#D33A2E",
    "india": "#E08A2E",
    "japan": "#D64A57",
    "new-zealand": "#2E7DB8",
}

# The cel ring drawn around every silhouette, and how thick it is in source
# pixels. One pixel would disappear under `.aspectRatio(.fit)` at list-row size
# (the outline is drawn into ~5pt there); three closes the thin necks on Chile
# and Italy into a solid black worm. Two is what 0.8.0's rasteriser drew and
# what these were measured against.
RING = "#000000"
RING_WIDTH = 2
