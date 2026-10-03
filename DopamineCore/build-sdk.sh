#!/bin/bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
out="$repo/.build/sdk"
mkdir -p "$out"
python3 "$repo/DopamineCore/tools/project.py"
xcodebuild -project "$repo/DopamineCore/DopamineCore.xcodeproj" -scheme DopamineSDK \
  -configuration Release -derivedDataPath "$out/DerivedData" \
  -clonedSourcePackagesDirPath "$repo/Application/build/SourcePackages" \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO > "$out/build.log" 2>&1
python3 "$repo/DopamineCore/tools/export.py"
