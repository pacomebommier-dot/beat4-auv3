#!/usr/bin/env bash
set -euo pipefail
BUILD="$RUNNER_TEMP/Beat4Snapshots"
mkdir -p "$BUILD/BEAT4Snapshot.app"
APP="$BUILD/BEAT4Snapshot.app"
xcrun --sdk iphonesimulator clang++ -std=c++17 -fobjc-arc -fblocks \
  -target x86_64-apple-ios15.0-simulator Tests/ui_snapshot_host.mm \
  Beat4AU/Beat4AudioUnit.mm Beat4AU/Beat4ViewController.mm \
  -framework UIKit -framework Foundation -framework CoreAudioKit \
  -framework AVFoundation -framework AudioToolbox -framework QuartzCore -framework CoreGraphics \
  -o "$APP/BEAT4Snapshot"
python3 - "$APP/Info.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1],'wb') as f:
 plistlib.dump({'CFBundleIdentifier':'com.beat4.r10.snapshot-tests','CFBundleExecutable':'BEAT4Snapshot','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','LSRequiresIPhoneOS':True,'MinimumOSVersion':'15.0','UIDeviceFamily':[1,2],'UILaunchScreen':{}},f)
PY
codesign --force --sign - "$APP"
xcrun simctl list devices available --json > "$BUILD/devices.json"
DEVICE=$(python3 - "$BUILD/devices.json" <<'PY'
import json,sys
for devices in json.load(open(sys.argv[1]))['devices'].values():
 for d in devices:
  if d['name'].startswith('iPhone'):
   print(d['udid']);sys.exit(0)
raise SystemExit('No available iPhone simulator')
PY
)
xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" com.beat4.r10.snapshot-tests
CONTAINER=$(xcrun simctl get_app_container "$DEVICE" com.beat4.r10.snapshot-tests data)
python3 - "$CONTAINER/Documents/R10/DONE.txt" <<'PY'
import pathlib,sys,time
p=pathlib.Path(sys.argv[1])
for _ in range(90):
 if p.exists(): print(p.read_text());break
 time.sleep(1)
else: raise SystemExit('Native snapshot host did not produce DONE.txt')
PY
mkdir -p "$GITHUB_WORKSPACE/native-snapshots"
cp -a "$CONTAINER/Documents/R10/." "$GITHUB_WORKSPACE/native-snapshots/"
xcrun simctl shutdown "$DEVICE"
