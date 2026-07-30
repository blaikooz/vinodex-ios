"""Shared background-removal for the pixel-art importers (0.5.6, item B).

The 0.5.4 pass flood-filled near-white in from the borders only, which left
every *enclosed* white region opaque — the gap between the cherry stems, the
loops of glasses and handles. This pass:

  1. **Chroma key first.** If the source carries a magenta key (any real
     amount of ~#FF00FF), background is exactly the keyed colour — cleared
     everywhere, no white heuristics needed. Re-exporting sources on magenta
     is the robust path for future art.
  2. Otherwise: border flood-fill of near-white, then **enclosed** white
     components are judged by what surrounds them. A background gap is
     bounded by the art's near-black *outline*; a specular highlight sits
     inside coloured fill. Components mostly bordered by outline are
     cleared, as is anything so large it cannot be a highlight. Small
     white clusters inside colour — the speculars — survive.

Used by import-flavor-art.py, import-grape-art.py and import-style-art.py.
"""
from collections import deque

WHITE_FLOOR = 240
# A component whose non-white neighbours are mostly this dark is ringed by
# outline — a gap, not a shine.
OUTLINE_CEIL = 90
OUTLINE_FRACTION = 0.5
# Nothing this big is a specular, whatever surrounds it.
GIANT_AREA = 1500


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

    # --- Path 2: white background ------------------------------------------
    def is_white(x, y):
        r, g, b, a = px[x, y]
        return a > 0 and r >= WHITE_FLOOR and g >= WHITE_FLOOR and b >= WHITE_FLOOR

    def clear(cells):
        for x, y in cells:
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, 0)

    # Border flood.
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
    clear(outside)

    # Enclosed white components, judged by their surroundings.
    seen = set(outside)
    for sy in range(h):
        for sx in range(w):
            if (sx, sy) in seen or not is_white(sx, sy):
                continue
            component = []
            border_dark = 0
            border_total = 0
            queue = deque([(sx, sy)])
            seen.add((sx, sy))
            while queue:
                x, y = queue.popleft()
                component.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if not (0 <= nx < w and 0 <= ny < h):
                        continue
                    if is_white(nx, ny):
                        if (nx, ny) not in seen:
                            seen.add((nx, ny))
                            queue.append((nx, ny))
                    else:
                        r, g, b, a = px[nx, ny]
                        if a > 0:
                            border_total += 1
                            if max(r, g, b) <= OUTLINE_CEIL:
                                border_dark += 1
            ringed_by_outline = border_total > 0 and border_dark / border_total >= OUTLINE_FRACTION
            if ringed_by_outline or len(component) >= GIANT_AREA:
                clear(component)

    return img
