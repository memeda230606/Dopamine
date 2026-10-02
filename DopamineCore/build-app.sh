#!/bin/bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
out="$repo/.build/decoupling"
mkdir -p "$out"
xcodebuild -project "$repo/Application/Dopamine.xcodeproj" -scheme Dopamine \
  -derivedDataPath "$repo/Application/build" -destination 'generic/platform=iOS' \
  -xcconfig "$repo/DopamineCore/no-reboot.xcconfig" \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO > "$out/build-final.log" 2>&1
python3 "$repo/DopamineCore/package.py"
