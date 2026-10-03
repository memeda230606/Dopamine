#!/bin/bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
out="$repo/.build/decoupling/tests"
mkdir -p "$out"
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror -framework Foundation \
  -I"$repo/DopamineCore" "$repo/DopamineCore/DOCore.m" "$repo/DopamineCore/Tests/contracts.m" \
  -o "$out/contracts"
"$out/contracts"
xcrun clang -fobjc-arc -c "$repo/Application/Dopamine/Extensions/NSString+Version.m" -o "$out/version.o"
xcrun libtool -static -o "$out/libVersion.a" "$out/version.o"
xcrun clang -fobjc-arc -framework Foundation -ObjC \
  -I"$repo/Application/Dopamine/Extensions" "$repo/DopamineCore/Tests/version_category.m" \
  "$out/libVersion.a" -o "$out/version-category"
"$out/version-category" | tee "$out/version-category.json"
