#!/bin/bash
cd /root/projects/vinodex-ios 2>/dev/null && rm -rf .build
rsync -a --delete --exclude '.build/' --exclude 'xtool/' --exclude '.git/' \
  /mnt/h/vscode-projects/HGapps/vinodex-ios/ /root/projects/vinodex-ios/
cd /root/projects/vinodex-ios || exit 1
echo "=== SWIFT TEST ==="
swift test 2>&1 | grep -E "recorded an issue|error:|Test run" | head -80
echo "=== XTOOL CLEAN BUILD ==="
rm -rf .build
xtool dev build 2>&1 | grep -E "error:|Build complete" | head -60
echo "=== DONE ==="
