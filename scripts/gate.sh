#!/usr/bin/env bash
# The three verification gates, in one file so nothing has to survive
# wsl.exe -> bash -lc quoting (KNOWN-ISSUES: $(...) and $? are mangled).
set -u
SRC=/mnt/h/vscode-projects/HGapps/vinodex-ios/
DST=/root/projects/vinodex-ios

rsync -a --delete --exclude '.build/' --exclude 'xtool/' --exclude '.git/' "$SRC" "$DST/"
cd "$DST" || exit 9

if [ "${1:-all}" != "buildonly" ]; then
  echo "=== swift test ==="
  swift test 2>&1 | grep -E 'recorded an issue|error:|Test run'
fi

echo "=== clean xtool dev build ==="
rm -rf .build
xtool dev build > /tmp/xb.log 2>&1
rc=$?
echo "xtool exit: $rc"
echo "error lines: $(grep -cE 'error:' /tmp/xb.log)"
grep -B2 -A6 'error:' /tmp/xb.log | head -120
tail -4 /tmp/xb.log
