#!/bin/bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
out="$repo/.build/laohema/tests"
mkdir -p "$out"
xcrun clang -fobjc-arc -fblocks -Wall -Werror -framework Foundation \
  -I"$repo/LaoHeMa/Tests/Fakes" -I"$repo/LaoHeMa/App" -I"$repo/DopamineCore" \
  "$repo/LaoHeMa/App/LMJailbreakController.m" "$repo/DopamineCore/DOCore.m" "$repo/DopamineCore/DOEngine.m" \
  "$repo/LaoHeMa/Tests/controller.m" -o "$out/controller"
"$out/controller" | tee "$out/controller.json"
