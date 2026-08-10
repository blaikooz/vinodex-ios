#!/usr/bin/env python3
"""Losslessly re-deflate PNGs, verifying pixel-for-pixel that nothing changed.

AUDIT L20. Every PNG in this repo is written by something that had no reason to
care about compression — an export from a drawing tool, `rsvg-convert`, a
Python importer — so most of them carry a deflate stream several tens of
percent larger than the same pixels need. `AppIcon.png` was 951,285 bytes and
is 675,776 for the identical image.

Lossless in the strict sense: the decoded pixel buffer and the colour mode are
compared before anything is written, and a file that does not round-trip
exactly is skipped and reported. Nothing here quantises, palettises or strips a
channel — those are all *visible* changes wearing the word "optimise", and a
regenerated asset must be byte-comparable against the importer's output.

    scripts/recompress-png.py --check AppIcon.png Sources/**/Resources
    scripts/recompress-png.py AppIcon.png

Without `--check` it rewrites in place. Paths may be files or directories;
directories are walked for `*.png`.

`oxipng` or `zopflipng` will beat this — they search filter strategies this
does not. Pillow is used because it is already a dependency of the art
importers (`scripts/import-*.py`), so the repo gains no new prerequisite for a
housekeeping tool.
"""
import argparse
import io
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required: pip install -r scripts/requirements.txt")


def recompress(path: Path) -> tuple[int, int, bool, bytes | None]:
    """Returns (before, after, verified, data).

    `after == before` and `data is None` mean there is nothing worth writing —
    either the re-encode came out no smaller, or it did not round-trip.
    """
    before = path.stat().st_size
    with Image.open(path) as original:
        original.load()
        buf = io.BytesIO()
        # `optimize=True` runs Pillow's own filter/level search; the explicit
        # level is belt and braces, since optimize already implies 9.
        original.save(buf, format="PNG", optimize=True, compress_level=9)
        data = buf.getvalue()

        with Image.open(io.BytesIO(data)) as rewritten:
            rewritten.load()
            verified = (
                rewritten.mode == original.mode
                and rewritten.size == original.size
                and rewritten.tobytes() == original.tobytes()
            )

    if not verified or len(data) >= before:
        return before, before, verified, None
    return before, len(data), True, data


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument(
        "--check",
        action="store_true",
        help="report what would be saved and change nothing; exits 1 if anything can be.",
    )
    args = parser.parse_args()

    targets: list[Path] = []
    for path in args.paths:
        if path.is_dir():
            targets.extend(sorted(path.rglob("*.png")))
        elif path.suffix.lower() == ".png":
            targets.append(path)

    saved = 0
    total = 0
    failures: list[Path] = []
    changed: list[Path] = []

    for target in targets:
        before, after, verified, data = recompress(target)
        total += before
        if not verified:
            failures.append(target)
            continue
        if data is None:
            continue
        saved += before - after
        changed.append(target)
        if not args.check:
            target.write_bytes(data)
        print(f"{'would save' if args.check else 'saved'} {before - after:>8,} B  {target}")

    if total:
        print(
            f"\n{len(targets)} file(s), {total:,} B; "
            f"{len(changed)} recompressible, {saved:,} B "
            f"({100 * saved / total:.1f}%)"
        )
    else:
        print("no PNGs found")

    if failures:
        print("\nNOT byte-verifiable — left alone:", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        return 2

    return 1 if args.check and changed else 0


if __name__ == "__main__":
    raise SystemExit(main())
