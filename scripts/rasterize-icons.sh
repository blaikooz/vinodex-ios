#!/usr/bin/env bash
#
# Rasterises the icon set listed in icons.json to PNGs bundled with the app.
#
# iOS cannot render SVG at runtime, and `actool` (the asset-catalog compiler) is
# macOS-only, so vector assets have to become plain PNG resources loaded by path.
#
# Icons are rendered as flat WHITE glyphs rather than in their final colours, so
# SwiftUI can tint them per entry via `.renderingMode(.template)`. The 1px black
# outline the web app fakes with eight stacked `drop-shadow()` filters is added
# at runtime with stacked zero-radius `.shadow()` modifiers, which compose the
# same way — baking it here would prevent tinting.
#
# Usage: bash rasterize-icons.sh [manifest] [outdir]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${1:-$HERE/../Sources/VinodexCore/Resources/icons.json}"
OUTDIR="${2:-$HERE/../Sources/VinodexUI/Resources/Icons}"
BASE=64   # @1x edge in points; @2x and @3x are multiples

command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found (apt install librsvg2-bin)"; exit 1; }
[ -f "$MANIFEST" ] || { echo "manifest not found: $MANIFEST"; exit 1; }

mkdir -p "$OUTDIR"

# Pull the unique icon list without needing jq.
ICONS=$(python3 -c "
import json,sys
with open(sys.argv[1]) as fh:
    print('\n'.join(json.load(fh)['unique']))
" "$MANIFEST")

total=0
failed=0

while IFS= read -r icon; do
  [ -z "$icon" ] && continue
  prefix="${icon%%:*}"
  name="${icon#*:}"
  slug="${prefix}--${name}"

  tmp=$(mktemp --suffix=.svg)
  # `color=white` resolves `currentColor` so the glyph rasterises as a tintable mask.
  url="https://api.iconify.design/${prefix}/${name}.svg?color=white"

  if ! curl -sSfL --max-time 25 -o "$tmp" "$url"; then
    echo "  FAIL download $icon"
    failed=$((failed + 1))
    rm -f "$tmp"
    continue
  fi

  # The API returns a 404 body as text rather than an error status in some cases.
  if ! head -c 200 "$tmp" | grep -qi "<svg"; then
    echo "  FAIL not svg  $icon"
    failed=$((failed + 1))
    rm -f "$tmp"
    continue
  fi

  ok=1
  for scale in 1 2 3; do
    px=$((BASE * scale))
    suffix=""
    [ "$scale" -gt 1 ] && suffix="@${scale}x"
    if ! rsvg-convert -w "$px" -h "$px" -o "$OUTDIR/${slug}${suffix}.png" "$tmp" 2>/dev/null; then
      ok=0
    fi
  done
  rm -f "$tmp"

  if [ "$ok" -eq 1 ]; then
    total=$((total + 1))
  else
    echo "  FAIL rasterize $icon"
    failed=$((failed + 1))
  fi
done <<< "$ICONS"

echo "rasterized $total icons -> $OUTDIR"
echo "failed: $failed"

# ---------------------------------------------------------------------------
# Flags are already pixel-art PNGs in the web repo, so they are copied rather
# than rendered. Only the countries present in the current selection ship.
# ---------------------------------------------------------------------------

FLAGDIR="$(dirname "$OUTDIR")/Flags"
PIXELFLAGS="${PIXELFLAGS:-$HERE/../../pixelflags}"
mkdir -p "$FLAGDIR"

if [ -d "$PIXELFLAGS" ]; then
  copied=0
  while IFS=$'\t' read -r country relpath; do
    [ -z "$country" ] && continue
    src="$PIXELFLAGS/$relpath"
    slug=$(printf '%s' "$country" | tr '[:upper:] ' '[:lower:]-')
    if [ -f "$src" ]; then
      cp "$src" "$FLAGDIR/$slug.png"
      copied=$((copied + 1))
    else
      echo "  MISSING flag $country ($relpath)"
      failed=$((failed + 1))
    fi
  done < <(python3 -c "
import json,sys
with open(sys.argv[1]) as fh:
    for country, path in json.load(fh).get('flags', {}).items():
        print(f'{country}\t{path}')
" "$MANIFEST")
  echo "copied $copied flags -> $FLAGDIR"
else
  echo "  pixelflags dir not found at $PIXELFLAGS — skipping flags"
fi

[ "$failed" -eq 0 ] || exit 1
