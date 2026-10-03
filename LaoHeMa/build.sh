#!/bin/bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
out="$repo/.build/laohema"
mkdir -p "$out"
"$repo/DopamineCore/build-sdk.sh"
python3 "$repo/LaoHeMa/tools/project.py"
xcodebuild -project "$repo/LaoHeMa/LaoHeMa.xcodeproj" -scheme LaoHeMa \
  -configuration Release -derivedDataPath "$out/DerivedData" \
  -clonedSourcePackagesDirPath "$repo/Application/build/SourcePackages" \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  > "$out/build.log" 2>&1
python3 "$repo/LaoHeMa/tools/package.py"
