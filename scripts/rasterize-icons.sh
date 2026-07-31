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
# Also runs the drawn-art importers over art/icons/** (see the final section),
# so this script is the single icons entry point: Iconify glyphs + flags +
# pixel art, source to bundle.
#
# Usage: bash rasterize-icons.sh [manifest] [outdir]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"

# The Swift package is this repo. This used to probe for `ios/Package.swift`,
# because the same script was published into a mirror whose package sat at the
# root while the monorepo kept it under `ios/`; there is one layout now.
MANIFEST="${1:-$REPO_ROOT/Sources/VinodexCore/Resources/icons.json}"
OUTDIR="${2:-$REPO_ROOT/Sources/VinodexUI/Resources/Icons}"
BASE=64   # @1x edge in points; @2x and @3x are multiples

command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found (Linux: apt install librsvg2-bin  •  macOS: brew install librsvg)"; exit 1; }
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

  # Portable mktemp — GNU-only `--suffix` breaks on macOS/BSD (audit M43). The
  # extension is cosmetic: rsvg-convert reads by content, not filename.
  tmp=$(mktemp "${TMPDIR:-/tmp}/vinodex-icon.XXXXXX")
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

  # Render every scale to a temp name first and only move them into place once
  # all three succeed (audit L23). A failure mid-way otherwise left a partial
  # scale set (e.g. @1x present, @3x missing) that could be committed unnoticed.
  ok=1
  moves=()
  for scale in 1 2 3; do
    px=$((BASE * scale))
    suffix=""
    [ "$scale" -gt 1 ] && suffix="@${scale}x"
    out="$OUTDIR/${slug}${suffix}.png"
    tmpout="${out}.tmp.$$"
    if rsvg-convert -w "$px" -h "$px" -o "$tmpout" "$tmp" 2>/dev/null; then
      moves+=("$tmpout|$out")
    else
      ok=0
      break
    fi
  done
  rm -f "$tmp"

  if [ "$ok" -eq 1 ]; then
    for pair in "${moves[@]}"; do mv -f "${pair%%|*}" "${pair##*|}"; done
    total=$((total + 1))
  else
    for pair in "${moves[@]}"; do rm -f "${pair%%|*}"; done
    echo "  FAIL rasterize $icon"
    failed=$((failed + 1))
  fi
done <<< "$ICONS"

# Prune orphans: any Icons/*.png whose slug is no longer in the manifest's
# `unique` list. Without this the rasteriser only ever adds, so a renamed or
# removed icon leaves dead PNGs shipping forever (audit L17). Flags live in a
# sibling dir and are not touched here.
UNIQUE_SLUGS=$(python3 -c "
import json,sys
with open(sys.argv[1]) as fh:
    print('\n'.join(i.replace(':','--') for i in json.load(fh)['unique']))
" "$MANIFEST")
pruned=0
shopt -s nullglob
for png in "$OUTDIR"/*.png; do
  base=$(basename "$png" .png)
  slug="${base%@*x}"   # strip @2x / @3x
  if ! grep -qxF -- "$slug" <<< "$UNIQUE_SLUGS"; then
    rm -f "$png"
    pruned=$((pruned + 1))
  fi
done
shopt -u nullglob
[ "$pruned" -gt 0 ] && echo "pruned $pruned orphan PNGs from $OUTDIR"

echo "rasterized $total icons -> $OUTDIR"
echo "failed: $failed"

# ---------------------------------------------------------------------------
# Flags are already pixel-art PNGs in the web repo, so they are copied rather
# than rendered. Only the countries present in the current selection ship.
# ---------------------------------------------------------------------------

FLAGDIR="$(dirname "$OUTDIR")/Flags"
# Pixelflags live in the shared assets tree since 0.6.5 (batch 3, item 2):
# shared/newicons/ is the icons folder that also carries sfx/, and the master
# lives in HGapps\shared — this repo's copy arrives via sync-shared.ps1, so
# the flags ride the same master->mirror path as the data.
PIXELFLAGS="${PIXELFLAGS:-$REPO_ROOT/shared/newicons/pixelflags}"
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
elif [ "${SKIP_FLAGS:-0}" = "1" ]; then
  echo "  pixelflags dir not found at $PIXELFLAGS — skipping flags (SKIP_FLAGS=1)"
else
  # A silent skip that still exits 0 could ship a build with no flags (audit
  # L24). Fail unless the skip is explicit.
  echo "  pixelflags dir not found at $PIXELFLAGS — set SKIP_FLAGS=1 to skip intentionally"
  failed=$((failed + 1))
fi

# ---------------------------------------------------------------------------
# The drawn pixel art (0.5.8, A1): everything under art/icons/** — flavour
# portraits, grape bunches, style portraits, and the taxonomy/outline/globe
# set — imported by the Python passes into their Resources/*Art directories.
# Chained here so `npm run icons` is the one entry point that takes the whole
# icon surface from source to bundle. Requires Pillow (apt: python3-pil).
# SKIP_ART=1 runs the Iconify/flag half alone.
# ---------------------------------------------------------------------------

if [ "${SKIP_ART:-0}" != "1" ]; then
  for importer in import-flavor-art.py import-grape-art.py import-style-art.py import-class-art.py import-stamp-art.py; do
    if ! python3 "$HERE/$importer"; then
      echo "  FAIL $importer"
      failed=$((failed + 1))
    fi
  done
fi

[ "$failed" -eq 0 ] || exit 1
