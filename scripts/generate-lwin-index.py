#!/usr/bin/env python3
"""Generates Sources/VinodexCore/Resources/lwin.tsv from the LWIN database.

The LWIN database (Liv-ex Wine Identification Number) is the wine trade's
open identification standard: https://www.liv-ex.com/lwin/ — 200k+ wines and
spirits, free forever under a Creative Commons licence (CC BY 4.0).

RAW SOURCE — deliberately NOT committed (25MB of spreadsheet the app never
reads). To regenerate, download `LWINdatabase.xlsx` and pass its path:

  python3 scripts/generate-lwin-index.py /path/to/LWINdatabase.xlsx

Provenance of the snapshot this resource was first generated from:
  * Official download: https://www.liv-ex.com/lwin/ — gated behind a HubSpot
    registration form (no direct URL), licence stated as Creative Commons at
    https://liv-ex.com/lwin-creative-commons-licence/
  * Snapshot actually used (public CC BY 4.0 redistribution, byte-identical
    official file `LWINdatabase.xlsx`):
    https://raw.githubusercontent.com/leohubert/floc/HEAD/dataset/data/LWINdatabase.xlsx
    fetched 2026-09-08; committed upstream 2026-06-05;
    sha256 8a80fd1baf92d2738396d21102ebae233b6480065016f506849c27f377961fbc;
    25,470,777 bytes; 211,786 data rows; newest DATE_UPDATED ≈ 2026-01.

WHAT IS KEPT (the trim). The raw sheet is 211,786 rows and ~263MB of XML.
The app needs the wine-shaped subset, compact:
  * STATUS == Live only — `Combined` rows point at another LWIN and `Deleted`
    rows are retractions; matching either would identify a bottle as a record
    Liv-ex itself no longer stands behind.
  * TYPE in {Wine, Fortified Wine} only — Vinodex is a wine encyclopedia, so
    the 19k whiskies/gins/rums, plus beer, cider and sake, are dead weight.
  * Fields kept per record: LWIN (7 digits), display name (split into a
    shared producer head + per-wine tail), country+region (as a small pair
    table), colour and category (one code character). SUB_REGION, SITE,
    PARCEL, vintages and dates are dropped — the display name already carries
    the identifying text, and the matcher matches text.

OUTPUT FORMAT (`lwin.tsv`, UTF-8, LF), designed so the Swift loader is a
single byte scan with no per-record string folding:

  line 1        LWIN1<TAB>records<TAB>producers<TAB>regionPairs
  next N lines  country<TAB>region            (regionPairs rows; region may
                                               be empty where LWIN says NA)
  then, per producer group (producers sorted by name):
    >producerHead[<TAB>foldedKey]
    one line per wine, sorted by LWIN:
      lllll rr c tail[<TAB>foldedKey]         (no spaces — fixed width:
                                               lwin base36 ×5, regionPair
                                               base36 ×2, code ×1, then the
                                               display tail to end of line)

  Display name reconstructs as `head, tail` (or `head` when the tail is
  empty). foldedKey columns appear ONLY where a plain ASCII fold of the text
  (lowercase a–z/0–9, everything else → space, collapsed) would differ from
  `TextNormalize.key` — i.e. where the text carries accents or other
  non-ASCII. That is ~500 of 185k records, so the file stays small while the
  Swift side never calls the (slow) String.folding path at load.

  Code characters (colour × category):
      still:      r/w/p/m/n  = red/white/rosé/mixed/unknown
      sparkling:  R/W/P/M/N
      fortified:  f/g/h/i/j  (same colour order)

The head/tail split follows the data's own convention: DISPLAY_NAME is
`PRODUCER_NAME, wine…` for 82% of rows and `PRODUCER_TITLE PRODUCER_NAME,
wine…` for most of the rest; the fallback is the text before the first
comma. The head is what a label prints largest, the tail is the cuvée.
"""

import sys
import os
import unicodedata
import zipfile
import xml.etree.ElementTree as ET
from collections import defaultdict

NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
COLUMNS = 22  # LWIN … REFERENCE
BASE36 = "0123456789abcdefghijklmnopqrstuvwxyz"

CODE = {
    ("Still", "Red"): "r", ("Still", "White"): "w", ("Still", "Rose"): "p",
    ("Still", "Mixed"): "m", ("Still", "NA"): "n",
    ("Sparkling", "Red"): "R", ("Sparkling", "White"): "W",
    ("Sparkling", "Rose"): "P", ("Sparkling", "Mixed"): "M",
    ("Sparkling", "NA"): "N",
    ("Fortified", "Red"): "f", ("Fortified", "White"): "g",
    ("Fortified", "Rose"): "h", ("Fortified", "Mixed"): "i",
    ("Fortified", "NA"): "j",
}


def b36(value, width):
    out = []
    for _ in range(width):
        value, rem = divmod(value, 36)
        out.append(BASE36[rem])
    assert value == 0
    return "".join(reversed(out))


def true_key(text):
    """Port of Swift `TextNormalize.key`: diacritic/case fold, then
    non-alphanumerics to spaces, collapsed. NFD + strip combining marks is
    the same transform `String.folding(.diacriticInsensitive)` performs for
    the Latin script this data is written in; the sampled-agreement test in
    `LWINIndexTests` holds the two implementations equal on the shipped
    records."""
    decomposed = unicodedata.normalize("NFD", text)
    stripped = "".join(c for c in decomposed if unicodedata.category(c) != "Mn")
    lowered = stripped.lower()
    spaced = "".join(c if c.isalnum() else " " for c in lowered)
    return " ".join(spaced.split())


def ascii_key(text):
    """The fold the Swift loader applies to every line: byte-level, ASCII
    only. Where this disagrees with `true_key` the file stores the true key
    explicitly, so the loader never needs the slow path."""
    out = []
    for ch in text:
        if "a" <= ch <= "z" or "0" <= ch <= "9":
            out.append(ch)
        elif "A" <= ch <= "Z":
            out.append(chr(ord(ch) + 32))
        else:
            out.append(" ")
    return " ".join("".join(out).split())


def rows(xlsx_path):
    """Streams the sheet without loading 263MB of XML at once. Cells carry
    their column in the `r` attribute, so absent cells cannot shift a row."""
    archive = zipfile.ZipFile(xlsx_path)
    with archive.open("xl/worksheets/sheet1.xml") as handle:
        for _, element in ET.iterparse(handle):
            if element.tag != NS + "row":
                continue
            row = [""] * COLUMNS
            for cell in element.findall(NS + "c"):
                column = 0
                for ch in cell.get("r", ""):
                    if ch.isalpha():
                        column = column * 26 + (ord(ch) - 64)
                    else:
                        break
                inline = cell.find(NS + "is")
                value = cell.find(NS + "v")
                if inline is not None:
                    text = "".join(t.text or "" for t in inline.iter(NS + "t"))
                elif value is not None:
                    text = value.text or ""
                else:
                    text = ""
                if 0 < column <= COLUMNS:
                    row[column - 1] = text
            element.clear()
            yield row


def split_display(display, title, producer):
    """Head/tail split, preferring the data's own producer columns so the
    head groups correctly, with the first comma as the honest fallback."""
    heads = []
    if title and title != "NA":
        heads.append(f"{title} {producer}")
    heads.append(producer)
    for head in heads:
        if display == head:
            return head, ""
        if display.startswith(head + ", "):
            return head, display[len(head) + 2:]
    cut = display.find(", ")
    if cut > 0:
        return display[:cut], display[cut + 2:]
    return display, ""


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    out_path = os.path.join(
        script_dir, "..", "Sources", "VinodexCore", "Resources", "lwin.tsv"
    )
    if len(sys.argv) != 2:
        sys.exit("usage: generate-lwin-index.py /path/to/LWINdatabase.xlsx")
    xlsx = sys.argv[1]

    groups = defaultdict(list)   # head -> [(lwin, country, region, code, tail)]
    pairs = {}                   # (country, region) -> index, insertion order
    header_seen = False
    kept = 0
    for row in rows(xlsx):
        if not header_seen:
            assert row[0] == "LWIN" and row[12] == "TYPE", "unexpected sheet layout"
            header_seen = True
            continue
        (lwin, status, display, title, producer, _wine, country, region,
         *_rest) = row[:8] + [None]
        colour, wine_type, sub_type = row[11], row[12], row[13]
        if status != "Live" or wine_type not in ("Wine", "Fortified Wine"):
            continue
        lwin = lwin.split(".")[0]  # Excel floats: '1000001.0'
        display = " ".join(display.split())
        if len(lwin) != 7 or not lwin.isdigit() or not display:
            continue
        kept += 1

        if wine_type == "Fortified Wine":
            category = "Fortified"
        elif sub_type == "Sparkling":
            category = "Sparkling"
        else:
            category = "Still"
        colour = colour if colour in ("Red", "White", "Rose", "Mixed") else "NA"
        code = CODE[(category, colour)]

        pair = (country if country != "NA" else "", region if region != "NA" else "")
        pair_index = pairs.setdefault(pair, len(pairs))

        head, tail = split_display(display, title, producer)
        groups[head].append((int(lwin), pair_index, code, tail))

    lines = []
    lines.append(f"LWIN1\t{kept}\t{len(groups)}\t{len(pairs)}")
    for country, region in pairs:  # dict preserves insertion order
        lines.append(f"{country}\t{region}")

    needs_key = 0
    for head in sorted(groups):
        head_line = ">" + head
        if ascii_key(head) != true_key(head):
            head_line += "\t" + true_key(head)
            needs_key += 1
        lines.append(head_line)
        for lwin, pair_index, code, tail in sorted(groups[head]):
            line = b36(lwin, 5) + b36(pair_index, 2) + code + tail
            if ascii_key(tail) != true_key(tail):
                line += "\t" + true_key(tail)
                needs_key += 1
            lines.append(line)

    payload = ("\n".join(lines) + "\n").encode("utf-8")
    out_path = os.path.normpath(out_path)
    with open(out_path, "wb") as handle:
        handle.write(payload)
    print(
        f"lwin.tsv: {kept} records, {len(groups)} producers, "
        f"{len(pairs)} country/region pairs, {needs_key} stored keys, "
        f"{len(payload) / 1e6:.2f} MB -> {out_path}"
    )


if __name__ == "__main__":
    main()
