#!/usr/bin/env bash
# Clean xtool build with the log kept, for dexbot's verification gate.
#
# A file rather than a `bash -lc` one-liner: PowerShell eats `$?` and quoted
# alternations on the way through `wsl.exe`, which is the trap KNOWN-ISSUES
# records. This keeps the exit code honest and the log where the next command
# can read it.
set -u
REPO=/root/projects/vinodex-ios
LOG=$REPO/build.log

cd "$REPO" || exit 90
if [ "${1:-}" = "clean" ]; then
  rm -rf .build
fi

xtool dev build > "$LOG" 2>&1
code=$?
echo "XTOOL_EXIT=$code"
echo "ERRORS=$(grep -c 'error:' "$LOG")"
grep 'error:' "$LOG" | sed "s|$REPO/||" | sort -u | head -40
exit $code
