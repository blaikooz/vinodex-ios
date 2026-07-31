#!/usr/bin/env python3
"""Generates the Oaked and Stainless Steel chassis pattern tiles (0.5.7, A1).

`oak-grain.png` and `steel-brush.png` under Resources/Chassis were hand-made
in 0.5.3/0.5.6 and read flat — the steel was four uniform vertical bars, the
oak a low-contrast smear with two knots on an obvious 192pt repeat. These are
drawn instead: every term is periodic in the tile size, so the tiles stay
seamless under `resizable(resizingMode: .tile)`, and everything is
deterministic (fixed seed, no clock) so a re-run is byte-stable.

The tiles are opaque and carry their own colour; the skin's base colour
underneath (`DexTheme.bodyBase`) only shows if a pattern fails to load.
`xmas-wrap.png` stays hand-made.

Usage: python3 scripts/make-chassis-patterns.py
Requires Pillow.
"""
import math
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DST = os.path.join(os.path.dirname(HERE), "Sources", "VinodexUI", "Resources", "Chassis")

TAU = 2 * math.pi


def hash2(x, y, seed=0):
    """Deterministic 0..1 noise, stable across runs and platforms."""
    n = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 0xFFFF


# --- Oaked: walnut woodgrain, 192x192 --------------------------------------

# Dark seams to warm highlights — wider range than the old tile, which sat
# in a 62..117 band and read as one brown.
OAK_PALETTE = [
    (40, 25, 14), (52, 33, 19), (64, 42, 24), (76, 51, 30),
    (88, 60, 36), (100, 70, 43), (113, 81, 51), (126, 92, 59),
]

# Knot centres, placed off-grid so the repeat is not obvious at a glance.
OAK_KNOTS = [(38, 52, 1.0), (150, 148, 0.8), (104, 10, 0.6)]


def smooth_noise(x, y, size, cells, seed):
    """Periodic value noise: bilinear over a coarse hash grid, 0..1."""
    gx = x / size * cells
    gy = y / size * cells
    x0, y0 = int(gx) % cells, int(gy) % cells
    x1, y1 = (x0 + 1) % cells, (y0 + 1) % cells
    fx, fy = gx - int(gx), gy - int(gy)
    # Smoothstep, so cell boundaries do not print as a grid.
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    top = hash2(x0, y0, seed) * (1 - fx) + hash2(x1, y0, seed) * fx
    bot = hash2(x0, y1, seed) * (1 - fx) + hash2(x1, y1, seed) * fx
    return top * (1 - fy) + bot * fy


def oak_tile(size=192):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            # The grain runs vertically; noise warps each streak's course
            # independently instead of waving the whole field in sync.
            warp = (
                9.0 * (smooth_noise(x, y, size, 4, 3) - 0.5)
                + 4.0 * (smooth_noise(x, y, size, 9, 17) - 0.5)
            )
            u = x + warp
            # Two grain frequencies, each phase-shifted by coarse noise so the
            # streak spacing pinches and spreads the way real figure does,
            # plus a broad lightness drift.
            tone = (
                3.5
                + 1.9 * math.sin(TAU * (u / size * 7 + 2.2 * smooth_noise(x, y, size, 2, 41)))
                + 0.9 * math.sin(TAU * (u / size * 19 + 3.1 * smooth_noise(x, y, size, 3, 43)))
                + 1.3 * (smooth_noise(x, y, size, 3, 29) - 0.5)
            )
            # Knots: concentric rings, elliptical along the grain, computed on
            # wrapped deltas so a knot near an edge tiles cleanly.
            for kx, ky, strength in OAK_KNOTS:
                dx = min(abs(x - kx), size - abs(x - kx))
                dy = min(abs(y - ky), size - abs(y - ky))
                d = math.sqrt(dx * dx * 2.6 + dy * dy)
                if d < 22:
                    tone -= strength * (1.2 * math.cos(d * 0.75) + (22 - d) * 0.06)
            tone += (hash2(x, y) - 0.5) * 0.9
            idx = max(0, min(len(OAK_PALETTE) - 1, int(round(tone))))
            px[x, y] = OAK_PALETTE[idx]
    return img


# --- Stainless Steel: brushed aluminium, 96x96 ------------------------------

def steel_tile(size=96):
    img = Image.new("RGB", (size, size))
    px = img.load()

    # Horizontal brush streaks: per row, a handful of strokes with wrapped
    # extents and their own lightness, over a gently banded base.
    strokes = []
    for y in range(size):
        row = []
        for s in range(5):
            if hash2(y, s, 11) < 0.75:
                start = int(hash2(y, s, 23) * size)
                length = 10 + int(hash2(y, s, 37) * 42)
                delta = (hash2(y, s, 53) - 0.45) * 26
                row.append((start, length, delta))
        strokes.append(row)

    for y in range(size):
        base = 202 + 5 * math.sin(TAU * y / size * 3 + 1.2)
        # The odd full-width scratch and dark seam keep it from banding.
        r = hash2(0, y, 71)
        if r > 0.94:
            base += 12
        elif r < 0.05:
            base -= 11
        for x in range(size):
            v = base
            for start, length, delta in strokes[y]:
                if (x - start) % size < length:
                    v += delta
            v += (hash2(x, y, 5) - 0.5) * 5
            # Quantized to 4-value steps for the pixel look; cool cast like
            # the rest of the chassis greys.
            q = max(180, min(238, int(v) & ~3))
            px[x, y] = (q - 4, q, q + 6)
    return img


def main():
    os.makedirs(DST, exist_ok=True)
    for name, tile in (("oak-grain.png", oak_tile()), ("steel-brush.png", steel_tile())):
        out = os.path.join(DST, name)
        tile.save(out, optimize=True)
        print(f"wrote {out} ({os.path.getsize(out)} bytes)")


if __name__ == "__main__":
    main()
