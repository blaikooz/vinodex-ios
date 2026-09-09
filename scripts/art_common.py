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

The 0.9.54 Day-1 icon-repass pass (icon-repass-plan.md §5) adds two edge
passes and a gate:

  * `snap_key_fringe` — path 1 leaves anti-aliased key/outline blends as
    opaque magenta-tinted edge pixels (the whiteground audit's side finding:
    glyph-cog's (174,6,172) rim and friends). One edge pass clears them,
    using the same key-blend test the campaign slicer already snapped new
    crops with.
  * `dehalo` — path 2's border flood clears only pixels with every channel
    >= 240, so the 200-239 white/ground AA band survives as a 1px near-white
    halo hugging the silhouette. One guarded erosion removes it; the
    thin-component guard is what keeps genuine white subjects (Chalk's
    sticks, White Blossom's petals) untouched.
  * `assert_magenta_keyed` — the importers refuse a white-ground master
    outright, so the root cause the audit documents cannot re-enter the
    bundle silently. The named exemptions live in the importers, not here.

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


# The near-white floor for the de-halo erode. Deliberately above the flood's
# WHITE_FLOOR band's bottom: the halo the audit measured is the 230-255 rim
# (min(r,g,b) >= 230 is the audit's own metric), and reaching lower would put
# genuinely shaded edge pixels in play.
HALO_FLOOR = 230

# The key-blend test the campaign slicer (slice-sheets.py) snaps new crops
# with: strong red AND blue with green far below both is magenta ground
# bleeding into the outline, never a shipped palette colour (measured across
# every campaign sheet without an incident — icon-repass-plan.md §5).
FRINGE_RB_FLOOR = 120
FRINGE_G_RATIO = 0.35


def _is_key_fringe(px):
    r, g, b, a = px
    return (
        a > 0
        and r > FRINGE_RB_FLOOR
        and b > FRINGE_RB_FLOOR
        and g < min(r, b) * FRINGE_G_RATIO
    )


def magenta_coverage(img):
    """(key pixel count, canvas area), by the exact test `strip_background`
    gates its path choice on — so callers asking "would this take path 1"
    and the strip itself can never disagree."""
    rgba = img.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    count = 0
    for y in range(h):
        for x in range(w):
            if _is_magenta(px[x, y]):
                count += 1
    return count, w * h


def assert_magenta_keyed(img, name):
    """Refuse a white-ground master, loudly and by name.

    The whiteground audit's root cause was 310 sources generated on a white
    ground, each silently taking the flood-fill fallback and shipping a 1px
    near-white halo. Post-repass, every master an importer ingests is drawn
    on the magenta key `#EE03E1`; this makes that a contract rather than a
    campaign: a source whose key covers less than the 1% gate (the same gate
    `strip_background` switches paths on) exits nonzero with the filename,
    so a white-ground regeneration can never be imported by accident.

    Importers that legitimately ingest non-keyed masters exempt themselves
    explicitly at their call site, with the reason — never by skipping the
    call in silence.
    """
    count, area = magenta_coverage(img)
    if count <= area // 100:
        sys.exit(
            f"{name}: magenta key #EE03E1 covers {100.0 * count / area:.2f}% of "
            "pixels (gate: >=1%) — this master looks white-ground. Regenerate it "
            "on the flat magenta key (icon-repass-plan.md §2), or exempt it by "
            "name at the importer's call site if it is deliberate."
        )


def snap_key_fringe(img):
    """Clear the magenta AA fringe on keyed art — path 1's edge pass.

    One iteration over opaque pixels 4-adjacent to transparency: a pixel that
    passes `_is_key_fringe` there is key bleed into the cel outline, not art,
    and goes transparent. This is the fringe-snap the campaign slicer already
    performs on new crops, moved to import time so the pre-campaign keyed
    chrome cleans up on re-import with no art touched (plan §5, side finding).

    Single pass by design — the candidates are collected before anything is
    cleared, so the snap cannot eat inward through its own writes.
    """
    px = img.load()
    w, h = img.size
    doomed = []
    for y in range(h):
        for x in range(w):
            if not _is_key_fringe(px[x, y]):
                continue
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
                    doomed.append((x, y))
                    break
    for x, y in doomed:
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)
    return img, len(doomed)


def dehalo(img):
    """Erode the 1px white halo on white-ground art — path 2's edge pass.

    The border flood clears only pixels with every channel >= WHITE_FLOOR;
    the white/outline AA band below that survives as a near-white ring hugging
    the whole silhouette (measured at 0.16-0.26 of the edge across the
    white-ground sets — whiteground-audit.md). One conservative erosion:

      * a candidate is opaque, near-white (min(r,g,b) >= HALO_FLOOR), and
        4-adjacent to transparency;
      * the **thin-component guard**: a candidate is cleared only when every
        pixel of its near-white connected component sits within 1px of
        transparency. A halo is a 1px string along the silhouette; a chalk
        stick or a petal is a blob with an interior, and the guard leaves
        blobs alone (plan §5 calls this a requirement, not polish);
      * one pass, candidates collected before clearing — genuine white art
        can lose at most nothing, and even a guard failure could cost one
        edge pixel, never a cascade.
    """
    px = img.load()
    w, h = img.size

    def near_white(x, y):
        r, g, b, a = px[x, y]
        return a > 0 and min(r, g, b) >= HALO_FLOOR

    def borders_transparency(x, y, diagonal):
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                if not diagonal and dx != 0 and dy != 0:
                    continue
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
                    return True
        return False

    seen = set()
    doomed = []
    for sy in range(h):
        for sx in range(w):
            if (sx, sy) in seen or not near_white(sx, sy):
                continue
            # Flood the whole near-white component before judging any of it.
            component = []
            stack = [(sx, sy)]
            seen.add((sx, sy))
            while stack:
                cx, cy = stack.pop()
                component.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and near_white(nx, ny):
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if not all(borders_transparency(x, y, diagonal=True) for x, y in component):
                continue  # a blob with interior is subject, not halo
            doomed.extend(
                (x, y) for x, y in component if borders_transparency(x, y, diagonal=False)
            )
    for x, y in doomed:
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)
    return img, len(doomed)


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
        # The AA blends of key and outline fall below `_is_magenta`'s
        # thresholds and would survive as an opaque magenta-tinted rim
        # (0.9.54, icon-repass Day 1). See `snap_key_fringe`.
        img, _ = snap_key_fringe(img)
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

    # The 200-239 white/AA band fails `is_white` and would survive as the 1px
    # halo the whiteground audit measured (0.9.54, icon-repass Day 1). See
    # `dehalo` — guarded, so interior white subjects stay whole.
    img, _ = dehalo(img)
    return img
