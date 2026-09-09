#!/usr/bin/env python3
"""Imports the Professor Vino expression set into the app bundle (0.8.9a, A3).

Sources are individual PNGs in art/icons/chrome/vino, one per expression
(`neutral`, `smiling`, `goodjob`, `raiseaglass`, `surprised`, `thinking`),
written to Sources/VinodexUI/Resources/VinoArt with a `vino-` prefix.

**These arrived already cut, which is why there is no key here.** Every other
chrome drop lands on a magenta chroma key and goes through
`art_common.strip_background`; measured on this one, the six portraits carry a
genuine alpha channel already (17-21% of each canvas is alpha 0, the corner
pixel included) and no magenta at all. `strip_background` is still called
rather than skipped, and on these files it is a provable no-op: path 1 needs a
magenta key covering more than 1% of the canvas and finds none, and path 2
seeds its flood from border pixels that are near-white *and opaque*, of which
these have zero. Calling it keeps one code path for every importer and costs
nothing; special-casing it would be a second path nobody re-checks when the
next expression is drawn on a key like the rest of the set.

**The seventh delivered file is not a seventh expression.** `profvino.png` is
the 1536x1024 contact sheet the six were cut from — the same six faces in a
row, in the same order the filenames name them. It is a *source* sheet, so it
lives in `art/icons/reference/` with the other contact sheets (`newpass-sheet-1`,
`classesicons`, `grapelist`) and ships nowhere, exactly as those do. Recording
it here because "the drop had seven files and the bundle has six" is a question
somebody will ask again.

**Ahead of its consumer, on purpose.** Nothing draws these yet: the
`ProfessorVinoPresenter` is 0.8.9's phase 2. The art lands now because the
alternative is leaving it in a delivery folder, which is the state this whole
sub-batch exists to end. `VinoExpression` in Core names the six so the
directory, the type and the bundle can be held equal by
`ArtPipelineRosterTests` from today rather than from whenever the presenter
arrives — the roster is what turns "the art is here" into a check.

Usage: python3 scripts/import-vino-art.py [source-dir]
Requires Pillow.
"""
import os
import sys

from PIL import Image

from art_common import magenta_coverage, output_dir, quantize_stable, save_stable, strip_background

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
# `ART_OUT`-aware like every other importer — see import-glyph-art.py.
DST = output_dir(ROOT, "VinoArt")

# Restated by `VinoExpression.artStem` on the Swift side. `PixelArtLoader`'s
# namespace is flat and global, so every set added since `ButtonArt` carries
# one of these.
PREFIX = "vino-"


def source_dir():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.path.join(ROOT, "art", "icons", "chrome", "vino")


def main():
    src = source_dir()
    if not os.path.isdir(src):
        print(f"no Professor Vino art yet ({src} absent) — the presenter has no portrait")
        return

    stems = sorted(
        os.path.splitext(name)[0]
        for name in os.listdir(src)
        if name.lower().endswith(".png")
    )
    if not stems:
        print(f"no Professor Vino art yet ({src} empty) — the presenter has no portrait")
        return

    os.makedirs(DST, exist_ok=True)
    total_out = 0
    for stem in stems:
        path = os.path.join(src, stem + ".png")
        img = Image.open(path)
        # **Exempt from `assert_magenta_keyed`, deliberately** (0.9.54,
        # icon-repass Day 1): these six arrived pre-cut with a real alpha
        # channel and no key, as the module note explains, so the white-ground
        # gate every other importer carries would refuse the whole set.
        #
        # What is asserted instead is the inverse — the latent trap the
        # whiteground audit measured: the faces carry 0.3-0.5% embedded
        # magenta-passing pixels, *under* strip_background's 1% gate. A future
        # touch that nudges past it (a tighter crop, a magenta-ish edit) would
        # silently flip them onto the chroma-key path, which punches holes
        # wherever those in-art pixels sit. Fail loudly instead, per
        # icon-repass-plan.md §6.2. TODO(icon-repass §3.5): the optional V1
        # sheet re-exports the set on a clean key; when it lands, replace this
        # guard with the standard assert_magenta_keyed.
        count, area = magenta_coverage(img)
        if count > area // 100:
            sys.exit(
                f"{path}: magenta-passing pixels now cover {100.0 * count / area:.2f}% "
                "of the canvas — over strip_background's 1% key gate. This source is "
                "pre-cut art with embedded magenta, and the key path would punch holes "
                "in it. Re-export the face on a clean key (icon-repass-plan.md §3.5) "
                "before importing."
            )
        img = strip_background(img)
        out = os.path.join(DST, PREFIX + stem + ".png")
        save_stable(quantize_stable(img), out, optimize=True)
        total_out += os.path.getsize(out)

    print(f"converted {len(stems)} Vino expressions -> {DST} ({total_out // 1024}KB)")


if __name__ == "__main__":
    main()
