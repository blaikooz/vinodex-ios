"""Shared background-removal for the pixel-art importers (0.5.7, item B2).

Two paths:

  1. **Chroma key first.** If the source carries a magenta key (any real
     amount of ~#FF00FF), background is exactly the keyed colour — cleared
     everywhere, no white heuristics needed. Re-exporting sources on magenta
     is the robust path for future art.
  2. Otherwise: flood-fill near-white in from the borders, and clear **only
     that**. Interior white is subject — White Blossom's petals, Chalk's
     sticks, every specular highlight — and stays opaque unconditionally.

The 0.5.6 version added a second stage that judged *enclosed* white
components by their surroundings (mostly-dark ring → background gap; big →
background) to clear the gaps between cherry stems and inside handles. In
this art style a white subject is drawn inside the same near-black cel
outline a gap is, so the heuristic could not tell petal from gap and
shredded every legitimately white subject. Enclosed background gaps staying
white is the cheaper defect; art where it matters should re-export on a
magenta key (path 1).

Used by import-flavor-art.py, import-grape-art.py and import-style-art.py.

Also holds `resolve_source_dir()`, the one place that knows where the drawn-art
sources live. Four copies of that lookup are how the path assumption drifted
away from the tree in the first place (AUDIT H12).
"""
import os
import shutil
import sys
from collections import deque

from PIL import Image

WHITE_FLOOR = 240


def resolve_source_dir(root, *parts):
    """The drawn-art source directory, or a named exit.

    `argv[1]` wins so a fresh artist drop can be imported without moving it in.
    Otherwise it is `art/icons/<parts>` — a tracked tree, so a miss means the
    checkout is wrong rather than that the caller forgot an argument. The old
    message ("no source dir found; pass it explicitly") named neither the path
    it wanted nor the remedy, which is what made H12 hard to diagnose.
    """
    if len(sys.argv) > 1:
        candidate = sys.argv[1]
        if not os.path.isdir(candidate):
            sys.exit(f"source dir does not exist: {candidate}")
        return candidate
    candidate = os.path.join(root, "art", "icons", *parts)
    if os.path.isdir(candidate):
        return candidate
    sys.exit(
        f"no drawn-art source at {candidate}\n"
        "  art/ is tracked in this repo — check out the branch, or pass a source dir:\n"
        f"    python3 {os.path.basename(sys.argv[0])} <source-dir>"
    )


def output_dir(root, name):
    """Where an importer writes. `ART_OUT` redirects the whole set.

    Only `scripts/verify-art.py` sets it, so that a *verification* run can
    regenerate into a temp tree instead of overwriting the working copy. A
    command called `icons:verify` that silently rewrites 254 tracked binaries
    would be a trap, not a check.

    `root` may be a `str` or a `Path` — `import-logo-art.py` is written in
    pathlib and would otherwise have to launder its root through `str()`, which
    puts a nested paren in the one call `ArtPipelineRosterTests` parses to learn
    where each importer writes.
    """
    base = os.environ.get("ART_OUT") or os.path.join(root, "Sources", "VinodexUI", "Resources")
    return os.path.join(base, name)


def quantize_stable(img, colors=256):
    """Palette-reduce `img` with nothing left to a library default (0.8.0, A0b).

    Every importer used to call `img.quantize(colors=256)` and take three
    unnamed defaults:

      1. `method=None`, which Pillow resolves *by mode* -- MEDIANCUT normally,
         FASTOCTREE for RGBA. Every source here is RGBA after
         `strip_background`, so the effective method has always been FASTOCTREE.
         "Has always been" is a property of a version, not a contract, and a
         Pillow that moved that branch would silently re-quantise the whole
         bundle.
      2. `dither=FLOYDSTEINBERG`. Error diffusion is wrong for cel-shaded pixel
         art on principle -- it stipples flat fills. (Pillow ignores it on the
         FASTOCTREE path today, which is another default worth not relying on.)
      3. That a reduction runs at all, even when there is nothing to reduce.

    **(3) is the clause section A needs.** An octree that terminates without
    reducing maps every colour to itself, so an image already inside the budget
    is exact under any build -- but "exact under any build" should be a
    guarantee, not an inference about an implementation, so a source that fits is
    returned before any quantiser sees it. The 30 country outlines carry three
    colours each and take that path, which is what lets A1's art be bit-identical
    on a machine that is not this one.

    **What this does not fix, measured rather than hoped.** 301 of the 307 drawn
    sources carry more than 256 distinct colours after background removal -- they
    are painted, not indexed -- so the reduction is genuinely lossy for almost
    the whole bundle and cannot be skipped: shipping them unreduced was measured
    at roughly 13MB against the current 2.5MB. For those, FASTOCTREE still
    *chooses* a palette, and different builds choose slightly differently. The
    sixteen files where that choice currently lands differently are exactly
    `verify-art.py`'s TOLERANCE table, which stays and is the record of it.
    Closing that would mean supplying the palette ourselves rather than asking
    for one; it is a real option and it is not this batch's.

    PNG *bytes* differ between zlib and zlib-ng builds regardless, and always
    did. `save_stable` is what makes that moot.
    """
    rgba = img.convert("RGBA")
    # `getcolors` returns None above `maxcolors` rather than raising. The ceiling
    # is generous because the only question is "does it fit" -- a source with
    # four million distinct pixels answers no either way.
    counts = rgba.getcolors(maxcolors=max(colors, 1 << 16))
    if counts is not None and len(counts) <= colors:
        return rgba
    return rgba.quantize(
        colors=colors,
        method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE,
    )


def save_stable(img, out, **save_kwargs):
    """Write `img` to `out`, but only if the pixels there are different.

    **The churn this exists to stop, and why it is not a reproducibility bug.**
    `npm run icons` was rewriting `Logo/vinodex-mark-face.png` and
    `vinodex-mark-shade.png` with different bytes on every machine, with no
    change to the master and no change to the script -- and 0.7.6 reverted them
    rather than commit a diff nobody could explain. Measured in 0.7.7: the
    importer is bit-for-bit deterministic *within* an environment (two runs,
    identical hashes) and the two environments disagree because they ship
    different PNG encoders. WSL has Pillow 10.2 against zlib 1.3 and writes 2087
    bytes; Windows has Pillow 12.3, which bundles zlib-ng, and writes 1968. The
    decoded images are identical -- `Image.tobytes()` matches exactly.

    So there was never a difference in the art, only in the deflate stream, and
    no encoder argument fixes that: the two builds compress differently at every
    level. `verify-art.py` already knew this and compares pixels, which is why
    `icons:verify` stayed green throughout and the parked note's worry that the
    churn "undermines icons:verify" turned out to be the one thing it did not do.

    What was actually costing time was the *working tree*: a modified binary
    after every icon run, on a file the batch had not touched, which has to be
    inspected and reverted before it can be committed by accident. Comparing
    pixels before writing removes it at the source. An importer that changes the
    art still writes; an importer whose output decodes identically leaves the
    file alone, mtime and all.

    **Every importer writes through this since 0.8.0 (A0b).** Only
    `import-logo-art.py` did, and 0.7.9 measured the cost: re-running the set on
    Windows rewrote all 123 tracked PNGs, of which 11 differed in decoded pixels
    and the rest differed only in the deflate stream. A batch then cannot tell
    "the art changed" from "the encoder is a different build", which is exactly
    the state section A must not start the 30 country outlines in. Comparing
    pixels before writing makes a re-run a no-op on the working tree, so
    `git status` after `npm run icons` is the answer to whether anything moved.

    `**save_kwargs` passes through to `Image.save` -- the importers ship
    `optimize=True` and would otherwise have silently dropped it on the files
    they do rewrite, which is how a skip-if-identical helper quietly inflates
    the bundle one file at a time.

    Returns True if the file was written.
    """
    out = str(out)
    if os.path.exists(out):
        try:
            with Image.open(out) as existing:
                same = (
                    existing.size == img.size
                    and existing.convert("RGBA").tobytes() == img.convert("RGBA").tobytes()
                )
        except OSError:
            # Unreadable or not an image: write over it. A corrupt destination
            # is exactly the case that must not be preserved by a skip.
            same = False
        if same:
            return False
    img.save(out, **save_kwargs)
    return True


def copy_master(path, out):
    """Ship a hand-authored master verbatim.

    A handful of assets never went through an importer: they are per-colour
    recolours of a sibling, done by hand, with no generating script. They ship
    as RGBA, and re-running `strip_background` + `quantize(colors=256)` over
    them is *lossy* — measured at 49-62% of opaque pixels moved on the two
    style portraits — so the pipeline copies them instead of reprocessing
    them. Listed per importer in a `MASTERS` set (AUDIT H12).
    """
    shutil.copyfile(path, out)


def _is_magenta(px):
    r, g, b, a = px
    return a > 0 and r >= 200 and b >= 200 and g <= 80


def strip_background(img):
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size

    # --- Path 1: chroma key -------------------------------------------------
    keyed = [(x, y) for y in range(h) for x in range(w) if _is_magenta(px[x, y])]
    if len(keyed) > (w * h) // 100:
        for x, y in keyed:
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, 0)
        return img

    # --- Path 2: border-connected white background --------------------------
    def is_white(x, y):
        r, g, b, a = px[x, y]
        return a > 0 and r >= WHITE_FLOOR and g >= WHITE_FLOOR and b >= WHITE_FLOOR

    outside = set()
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_white(x, y):
                queue.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_white(x, y):
                queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        if (x, y) in outside or not is_white(x, y):
            continue
        outside.add((x, y))
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in outside:
                queue.append((nx, ny))
    for x, y in outside:
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)

    return img
