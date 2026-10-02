#!/bin/bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
out="$repo/.build/decoupling/tests"
mkdir -p "$out"
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror -framework Foundation \
  -I"$repo/DopamineCore" "$repo/DopamineCore/DOCore.m" "$repo/DopamineCore/Tests/contracts.m" \
  -o "$out/contracts"
"$out/contracts"
