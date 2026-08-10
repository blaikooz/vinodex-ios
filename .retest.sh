#!/bin/bash
# Wait for the in-flight clean build to finish, then re-run the test target with
# the fixed Package.swift parser. The xtool build does not compile Tests/, so a
# test-only edit cannot invalidate its result.
while pgrep -f 'xtoo[l] dev build' >/dev/null; do sleep 10; done
echo "=== BUILD RESULT ==="
tail -3 /tmp/vinodex-gates.log 2>/dev/null
rsync -a --exclude '.build/' --exclude 'xtool/' --exclude '.git/' \
  /mnt/h/vscode-projects/HGapps/vinodex-ios/ /root/projects/vinodex-ios/
cd /root/projects/vinodex-ios || exit 1
echo "=== SWIFT TEST ==="
swift test 2>&1 | grep -E "recorded an issue|error:|Test run" | head -40
echo "=== DONE ==="
