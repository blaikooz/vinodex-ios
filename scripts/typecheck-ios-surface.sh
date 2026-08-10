#!/bin/bash
#
# Type-check VinodexUI and VinodexApp — the code no other check in this repo can
# see. Run it before pushing.
#
# WHY THIS EXISTS
#
# `swift build` on this Mac reports "Build complete!" with a type error sitting
# in VinodexUI, because UIKit does not exist on macOS, so every file guarded
# `#if canImport(SwiftUI) && canImport(UIKit)` compiles to *nothing*. Same on
# Linux. `swift test` needs full Xcode, which neither maintainer has. `xtool`
# has no test subcommand. So the whole UI layer — two-thirds of the app — is
# checked by nothing at all until CI runs, and CI's iOS compile stops after its
# first batch of files, so one error hides every file alphabetically after it.
#
# This script closes that. It copies the tree, rewrites the handful of
# constructs that are genuinely iOS-only, compiles the whole thing against the
# macOS SDK with typecheck-shim.swift standing in for UIKit, and reports what
# comes out. It reproduced all six of the BookmarksScreen actor-isolation errors
# that broke every CI run from 2026-07-31, at identical file:line:col.
#
# WHAT IT IS NOT
#
#  * Not a Linux tool. It needs AppKit and SwiftUI, so it runs on a Mac only —
#    on the WSL box, CI is still the first real check.
#  * Not a substitute for CI. SceneKit, Core Image and the real UIKit are not
#    what the shim says they are, and nothing here runs a single line of code.
#  * Not free of upkeep. New UIKit surface in the app needs a new stand-in in
#    typecheck-shim.swift, and until it gets one the script reports an error
#    that is not real. When that happens, fix the shim — do not fix the app.
#
# WHY THE BASELINE FILE MATTERS
#
# swiftc skips function-body type-checking in *every* file once any
# declaration-level error exists anywhere. Five stale shim errors are therefore
# not "five known issues" — they are a script that silently checks nothing. The
# baseline exists so that stays visible: anything in typecheck-baseline.txt is
# accepted, anything new fails the run.
#
# USAGE
#
#   scripts/typecheck-ios-surface.sh              # the working tree
#   scripts/typecheck-ios-surface.sh HEAD~1       # any git ref
#   scripts/typecheck-ios-surface.sh --update-baseline
#   KEEP=1 scripts/typecheck-ios-surface.sh       # leave the copied tree behind
#
set -uo pipefail

ROOT=$(git rev-parse --show-toplevel) || { echo "not a git repository" >&2; exit 2; }
cd "$ROOT" || exit 2

SHIM="$ROOT/scripts/typecheck-shim.swift"
BASELINE="$ROOT/scripts/typecheck-baseline.txt"
TARGET=arm64-apple-macos14.0

UPDATE=0
REF=""
for arg in "$@"; do
    case "$arg" in
        --update-baseline) UPDATE=1 ;;
        -h|--help) sed -n '2,/^set -/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) REF="$arg" ;;
    esac
done

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This script needs AppKit and SwiftUI, so it only runs on macOS." >&2
    echo "On Linux, CI's 'iOS compile (Xcode)' job is the first real check." >&2
    exit 2
fi
command -v swiftc >/dev/null || { echo "swiftc not found" >&2; exit 2; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/vinodex-typecheck.XXXXXX") || exit 2
[ "${KEEP:-0}" = "1" ] || trap 'rm -rf "$WORK"' EXIT

if [ -n "$REF" ]; then
    echo "Checking $REF"
    git archive "$REF" Sources | tar -x -C "$WORK" || exit 2
else
    echo "Checking the working tree"
    mkdir -p "$WORK/Sources" && cp -R Sources/. "$WORK/Sources/" || exit 2
fi

cd "$WORK" || exit 2
find Sources -name '*.swift' > files.txt

while read -r f; do
    # Open the `#if canImport(...)` gate. Two spellings exist — SwiftUI &&
    # UIKit, and UIKit && AVFoundation in DexSound.swift — so match the
    # prefix, not any one of them, or a file silently stays empty.
    if head -1 "$f" | grep -q '^#if canImport(' && [ "$(tail -1 "$f")" = "#endif" ]; then
        t=$(wc -l < "$f")
        perl -i -pe "s{^.*\$}{// ungated} if \$. == 1 || \$. == $t" "$f"
    fi
    # Everything below is a *spelling* difference between the two SDKs, not a
    # behavioural one. Intra-package imports go because this is one compilation
    # unit. `import UIKit` becomes `import Foundation` rather than a comment:
    # Haptics.swift imports no Foundation of its own and needs UserDefaults.
    perl -i -pe 's{^import (VinodexCore|VinodexUI)\b}{// import $1};
                 s{^import UIKit\b}{import Foundation};
                 s{\.statusBarHidden\(\)}{/* statusBarHidden */};
                 # `fullScreenCover` is iOS-only SwiftUI with no macOS spelling.
                 # `sheet` takes the identical (isPresented:onDismiss:content:)
                 # signature, so the body still type-checks against the same
                 # closure — which is all this harness is asking.
                 s{\.fullScreenCover\(}{.sheet(}g;
                 s{\bmakeUIView\b}{makeNSView}g;
                 s{\bupdateUIView\b}{updateNSView}g;
                 s{\bdismantleUIView\b}{dismantleNSView}g;
                 s{\bmakeUIViewController\b}{makeNSViewController}g;
                 s{\bupdateUIViewController\b}{updateNSViewController}g;
                 s{\bdismantleUIViewController\b}{dismantleNSViewController}g;
                 s{\bCADisplayLink\b}{ShimDisplayLink}g;
                 s{^(\s*)try\? AVAudioSession.*$}{$1// AVAudioSession: iOS-only};
                 s{\.cgImage\b}{.shimCGImage}g;
                 s{\.getRed\(}{.shimGetRed(}g;
                 # `ImageRenderer` spells its output `uiImage` on iOS and
                 # `nsImage` here. A property access only — `Image(uiImage:)`
                 # is an argument label and keeps its spelling.
                 s{\.uiImage\b}{.nsImage}g' "$f"
done < files.txt

# Warnings, not only errors. Under `swiftc -swift-version 6` the actor-isolation
# diagnostics come out as warnings; SwiftPM's Swift 6 mode — which is what
# `swift-tools-version: 6.0` gives CI — makes the same ones fatal. Dropping
# warnings here would have missed the six errors that broke CI for a fortnight.
swiftc -target "$TARGET" -swift-version 6 -typecheck "$SHIM" @files.txt 2>&1 \
    | grep -E '\.swift:[0-9]+:[0-9]+: (error|warning):' \
    | sed "s|$WORK/||; s|$SHIM|scripts/typecheck-shim.swift|" \
    | sed 's/:[0-9]*:[0-9]*:/:/' \
    | sort -u > diagnostics.txt

cd "$ROOT" || exit 2

if [ "$UPDATE" = "1" ]; then
    # Keep whatever `#` notes the file already carries — they say *why* each
    # line is tolerated, which is the only thing that stops a baseline rotting
    # into a list nobody reads.
    { [ -f "$BASELINE" ] && grep '^#' "$BASELINE"; cat "$WORK/diagnostics.txt"; } > "$BASELINE.tmp"
    mv "$BASELINE.tmp" "$BASELINE"
    echo "Baseline updated: $(grep -cv '^#' "$BASELINE" | tr -d ' ') accepted diagnostics."
    exit 0
fi

[ -f "$BASELINE" ] || : > "$BASELINE"
grep -v '^#' "$BASELINE" | grep -v '^$' | sort -u > "$WORK/baseline.txt"
NEW=$(comm -23 "$WORK/diagnostics.txt" "$WORK/baseline.txt")
GONE=$(comm -13 "$WORK/diagnostics.txt" "$WORK/baseline.txt")

if [ -n "$GONE" ]; then
    echo
    echo "Fixed since the baseline was taken — rerun with --update-baseline:"
    echo "$GONE" | sed 's/^/  - /'
fi

if [ -n "$NEW" ]; then
    echo
    echo "NEW diagnostics:"
    echo "$NEW" | sed 's/^/  /'
    echo
    echo "An 'error:' fails CI. So does a 'main actor-isolated' warning — CI"
    echo "compiles in SwiftPM's Swift 6 mode, where those are errors."
    echo "If it names a UIKit member the shim lacks, fix the shim, not the app."
    exit 1
fi

echo "No new diagnostics ($(wc -l < "$WORK/diagnostics.txt" | tr -d ' ') accepted by the baseline)."
