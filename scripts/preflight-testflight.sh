#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "== LiDARForge TestFlight preflight =="
xcodebuild -version
swift --version

plutil -lint LiDARForge/Info.plist
plutil -lint LiDARForge/PrivacyInfo.xcprivacy
plutil -lint LiDARForge/Resources/en.lproj/InfoPlist.strings
plutil -lint LiDARForge/Resources/es.lproj/InfoPlist.strings
python3 Tests/validate-release-contract.py

xcodebuild \
  -project LiDARForge.xcodeproj \
  -scheme LiDARForge \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  build

xcodebuild \
  -project LiDARForge.xcodeproj \
  -scheme LiDARForge \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  build

echo "PASS: source-level TestFlight preflight completed."
echo "Next: signed Archive/Validate App and the physical LiDAR device plan."
