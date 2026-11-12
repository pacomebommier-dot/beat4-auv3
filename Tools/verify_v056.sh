#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TASK_ROOT"
bash Tests/run.sh
BEAT4_SANITIZE=1 bash Tests/run.sh
git diff --check
python3 - <<'PY'
import plistlib
for name in ('Beat4AU/Info.plist','Beat4App/Info.plist'):
    with open(name,'rb') as stream: p=plistlib.load(stream)
    assert p['CFBundleShortVersionString']=='0.5.6', name
print('Version/plist PASS: 0.5.6 app + extension')
PY
if command -v xcodebuild >/dev/null; then
  xcodebuild -project Beat4.xcodeproj -scheme Beat4App -configuration Release \
    -sdk iphoneos -destination 'generic/platform=iOS' \
    -derivedDataPath "${TMPDIR:-/tmp}/Beat4V056Derived" CODE_SIGNING_ALLOWED=NO build
else
  echo 'iOS native build NOT RUN: xcodebuild absent (run GitHub macOS CI).'
fi
