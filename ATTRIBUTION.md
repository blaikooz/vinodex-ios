# Attribution

## Pixel flag art — R74n

- **What is used:** the R74n collective's pixel flag art
  ([PixelFlags](https://r74n.com/pixelflags/)). 34 of the app's 35 bundled
  flags (`Sources/VinodexUI/Resources/Flags/`, copied from the
  `shared/pixelflags/` mirror by `scripts/rasterize-icons.sh`) are R74n's
  work; the `Various` pennant is first-party.
- **Source:** https://r74n.com
- **Permission:** granted 2026-09-07 by the creators, with the request
  "for now please provide credit somewhere."
- **Where credit appears:** in-app, on the Settings panel's FIRMWARE screen
  ("PIXEL FLAGS BY R74N (R74N.COM)"), and in [NOTICE.md](NOTICE.md).
- **License text:** [licenses/LICENSE-r74n.txt](licenses/LICENSE-r74n.txt)
  ([original](https://r74n.com/license.txt)).
- The maintainer holds the permission record.

## Wine index — LWIN, by Liv-ex

- **What is used:** the Liv-ex Wine Identification Number (LWIN) database,
  bundled as `Sources/VinodexCore/Resources/lwin.tsv` and read by
  `LWINIndex` so the label reader can name a bottle with no network. It is
  what the scan card's **THE BOTTLE** section reports (0.9.54).
- **Source:** https://www.liv-ex.com/lwin/
- **License:** Creative Commons Attribution 4.0 International (CC BY 4.0) —
  [licenses/LICENSE-lwin.txt](licenses/LICENSE-lwin.txt)
  ([original](https://creativecommons.org/licenses/by/4.0/legalcode)).
- **Modified: yes**, and CC BY requires this be stated. The import keeps
  only `STATUS = Live` rows of `TYPE = Wine` or `Fortified Wine` — dropping
  spirits, beer, cider, sake, and the combined and deleted records — which
  takes 211,786 rows to **184,968**. Of each surviving row it keeps the
  LWIN-7, the display name, country, region, colour and category, and drops
  sub-region, site, parcel, vintages and dates. The result is re-encoded
  into the packed producer-grouped format `LWINIndex` reads. No row's
  meaning was altered; the database was subsetted and re-encoded, not
  rewritten. `scripts/generate-lwin-index.py` carries the full provenance
  in its header, including the source hash and snapshot date.
- **Where credit appears:** in-app, on the Settings panel's FIRMWARE screen
  ("WINE INDEX: LWIN BY LIV-EX, CC BY 4.0, MODIFIED"), and in
  [NOTICE.md](NOTICE.md).
- **Note on the download:** Liv-ex publishes LWIN behind a registration
  form. The bundled snapshot came from a public CC mirror of the
  byte-identical official file rather than through that form; the licence
  is what grants redistribution, and it does so regardless of the route the
  file travelled. If Liv-ex ever asks that the file be taken only from
  them, re-pull it and keep this section honest about which snapshot ships.
