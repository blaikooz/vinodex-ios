#!/usr/bin/env bash
# Core-only pass: rsync + swift test, no clean build. For catching Core
# compile/test failures before spending a full xtool build. `gate.sh` is
# still the gate; this is a faster inner loop.
set -u
SRC=/mnt/h/vscode-projects/HGapps/vinodex-ios/
DST=/root/projects/vinodex-ios

rsync -a --delete --exclude '.build/' --exclude 'xtool/' --exclude '.git/' "$SRC" "$DST/"
cd "$DST" || exit 9

echo "=== swift test ==="
swift test 2>&1 | grep -E 'recorded an issue|error:|Test run'
