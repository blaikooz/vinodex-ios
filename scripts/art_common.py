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
"""
from collections import deque

WHITE_FLOOR = 240


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
