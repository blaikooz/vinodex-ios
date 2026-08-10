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
#   Flags: the default run writes them beside the default outdir
#   (Resources/Flags); a custom [outdir] keeps them inside it
#   ([outdir]/Flags); FLAGDIR overrides either.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"

# The Swift package is this repo. This used to probe for `ios/Package.swift`,
# because the same script was published into a mirror whose package sat at the
# root while the monorepo kept it under `ios/`; there is one layout now.
MANIFEST="${1:-$REPO_ROOT/Sources/VinodexCore/Resources/icons.json}"
OUTDIR="${2:-$REPO_ROOT/Sources/VinodexUI/Resources/Icons}"
BASE=64   # @1x edge in points; @2x and @3x are multiples

[ -f "$MANIFEST" ] || { echo "manifest not found: $MANIFEST"; exit 1; }

# python3 parses the icon list and runs every importer, so its absence is fatal.
# Checked above the Pillow probe, which would otherwise swallow the real error
# and misreport a missing python3 as "Pillow not found" (auditS L9).
command -v python3 >/dev/null || { echo "python3 not found (Linux: apt install python3  •  macOS: brew install python)"; exit 1; }

total=0
failed=0

# Preflight the drawn-art half BEFORE the network rasterize, so a missing
# prerequisite is named in the first second rather than after minutes of work
# (audit H12). Deliberately does not exit here: a machine with rsvg-convert but
# no Pillow should still regenerate every Iconify glyph and copy the flags —
# that is the common case for anyone adding an icon id. It records the failure
# and the run exits non-zero at the end, same as any other partial failure.
art_ready=1
if [ "${SKIP_ART:-0}" != "1" ]; then
  if ! python3 -c 'import PIL' 2>/dev/null; then
    echo "  Pillow not found — the drawn-art importers will be skipped."
    echo "    pip install -r $HERE/requirements.txt   (or set SKIP_ART=1 to skip intentionally)"
    art_ready=0
    failed=$((failed + 1))
  fi
  if [ ! -d "$REPO_ROOT/art/icons" ]; then
    echo "  drawn-art sources not found at $REPO_ROOT/art/icons — the importers will be skipped."
    echo "    art/ is tracked in this repo; check out the branch, or set SKIP_ART=1."
    art_ready=0
    failed=$((failed + 1))
  fi
fi

command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found (Linux: apt install librsvg2-bin  •  macOS: brew install librsvg)"; exit 1; }

mkdir -p "$OUTDIR"

# Pull the unique icon list without needing jq.
ICONS=$(python3 -c "
import json,sys
with open(sys.argv[1]) as fh:
    print('\n'.join(json.load(fh)['unique']))
" "$MANIFEST")


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

  # The API returns a 404 body as text rather than an error status in some
  # cases — and an HTML error page can *embed* an inline `<svg` logo, so the
  # presence sniff alone is trivially satisfiable (audit B15 / auditS L5).
  # Three checks, cheapest first: a real glyph is never tiny (measured
  # 2026-08-04: a small lucide glyph is 371 bytes; the API's "Not found" body
  # is 9), is never an HTML document, and must still contain `<svg` near the
  # start.
  bytes=$(wc -c < "$tmp" | tr -d ' ')
  if [ "$bytes" -lt 100 ]; then
    echo "  FAIL not svg  $icon (body is ${bytes} bytes — too small for a glyph)"
    failed=$((failed + 1))
    rm -f "$tmp"
    continue
  fi
  if head -c 200 "$tmp" | grep -qi "<!DOCTYPE html\|<html"; then
    echo "  FAIL not svg  $icon (HTML error page)"
    failed=$((failed + 1))
    rm -f "$tmp"
    continue
  fi
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
  rast_err=""
  for scale in 1 2 3; do
    px=$((BASE * scale))
    suffix=""
    [ "$scale" -gt 1 ] && suffix="@${scale}x"
    out="$OUTDIR/${slug}${suffix}.png"
    tmpout="${out}.tmp.$$"
    # stderr is kept for the failure report below — discarding it reduced a
    # systemic failure (broken librsvg, malformed SVG) to a bare icon name
    # repeated 68 times (audit B14).
    if rast_err=$(rsvg-convert -w "$px" -h "$px" -o "$tmpout" "$tmp" 2>&1); then
      moves+=("$tmpout|$out")
    else
      rast_err="rsvg-convert @${scale}x exit $?: ${rast_err:-<no stderr>}"
      ok=0
      break
    fi
  done
  rm -f "$tmp"

  if [ "$ok" -eq 1 ]; then
    for pair in "${moves[@]}"; do mv -f "${pair%%|*}" "${pair##*|}"; done
    total=$((total + 1))
  else
    # `${moves[@]+...}` and not a bare `"${moves[@]}"`: an @1x failure leaves
    # the array empty, and macOS's bash 3.2 treats expanding an empty array as
    # unbound under `set -u`, killing the run before the report below prints.
    for pair in ${moves[@]+"${moves[@]}"}; do rm -f "${pair%%|*}"; done
    echo "  FAIL rasterize $icon"
    sed 's/^/    /' <<< "$rast_err"
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
#
# The shipped set is R74n's PixelFlags (licenses/LICENSE-r74n.txt: credit
# given in NOTICE.md, non-commercial without explicit permission) — fine while
# development builds are non-commercial, and the owner has emailed R74n for
# permission ahead of the paid release (2026-08-06). If that answer is no, a
# complete first-party replacement already exists: art/flags/, drawn in code
# from the official flag constructions by scripts/generate-flag-art.py
# (2026-08-05, same slugs and canvas) — flipping this block's source to
# art/flags/<slug>.png is the whole swap (auditS H2).
# ---------------------------------------------------------------------------

# Flags sit beside Icons under Resources/, so the default run writes to the
# default outdir's sibling. A custom [outdir] keeps them inside it instead:
# deriving the sibling from $2 silently scattered the 33 flag PNGs into an
# unrelated directory next to whatever path was passed (audit B13). FLAGDIR
# overrides either choice.
if [ -n "${2:-}" ]; then
  FLAGDIR="${FLAGDIR:-$OUTDIR/Flags}"
else
  FLAGDIR="${FLAGDIR:-$(dirname "$OUTDIR")/Flags}"
fi
# Pixelflags live at shared/pixelflags since 0.6.5 (batch 4, phase 1). They sit
# in the cross-repo master rather than in this repo's art/ tree because they are
# the one art asset BOTH apps consume — here, and the web app's flagImages.ts —
# and art/ is iOS-only. The master is HGapps\shared; this repo's copy arrives
# via sync-shared.ps1, so the flags ride the same master->mirror path as the
# data. (The old shared/newicons/ nesting went away with the drawn-art masters,
# which now live in art/.)
PIXELFLAGS="${PIXELFLAGS:-$REPO_ROOT/shared/pixelflags}"
mkdir -p "$FLAGDIR"

if [ -d "$PIXELFLAGS" ]; then
  copied=0
  while IFS=$'\t' read -r country relpath slug; do
    [ -z "$country" ] && continue
    src="$PIXELFLAGS/$relpath"
    # The slug comes from the manifest, not from `tr` (audit L25). The rule was
    # written twice — here, naming the file that gets copied, and in Swift's
    # `IconManifest.flagSlug(for:)`, naming the file the app asks for — with no
    # shared test. They agree on every ASCII name and would part company on the
    # first accented or punctuated one, which ships as a flag that is present in
    # the bundle and unreachable from the app. `generate-ios-data.ts` decides it
    # once and both sides read it.
    if [ -z "$slug" ]; then
      echo "  MISSING flagSlugs entry for $country — regenerate icons.json (npm run generate)"
      failed=$((failed + 1))
      continue
    fi
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
    manifest = json.load(fh)
slugs = manifest.get('flagSlugs') or {}
for country, path in manifest.get('flags', {}).items():
    print(f'{country}\t{path}\t{slugs.get(country, \"\")}')
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

# Merged (testing): PR #10's preflight/skip arms (H12) around the 0.6.4
# importer roster, which includes import-stamp-art.py.
#
# `import-logo-art.py` joined the roster in 0.7.5 (A026). It shipped in A5 wired
# into nothing at all — not here, not in package.json, not in verify-art.py — so
# `npm run icons` never regenerated the screensaver wordmark and the only way to
# reproduce it from art/icons/chrome/logo/ was to know the script existed and run it by
# hand. This roster and `verify-art.py`'s `IMPORTERS` are asserted equal by
# ArtPipelineRosterTests, so the next importer cannot land in one and not the
# other.
if [ "${SKIP_ART:-0}" = "1" ]; then
  # SKIP_FLAGS echoes its acknowledgement; this arm used to be missing entirely,
  # so an inherited SKIP_ART produced a log indistinguishable from a full run.
  echo "  skipping drawn-art importers (SKIP_ART=1)"
elif [ "$art_ready" -eq 0 ]; then
  echo "  skipping drawn-art importers — see the preflight message above"
else
  for importer in import-flavor-art.py import-grape-art.py import-style-art.py import-class-art.py import-stamp-art.py import-sticker-art.py import-logo-art.py import-button-art.py import-footer-art.py import-cartridge-art.py import-marquee-art.py import-glyph-art.py import-vino-art.py; do
    if ! python3 "$HERE/$importer"; then
      echo "  FAIL $importer"
      failed=$((failed + 1))
    fi
  done
fi

[ "$failed" -eq 0 ] || exit 1
