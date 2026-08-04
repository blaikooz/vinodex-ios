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


def save_stable(img, out):
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
    img.save(out)
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
