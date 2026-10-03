#!/bin/bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"
out="$repo/.build/decoupling-final"
mkdir -p "$out"
bash DopamineCore/Tests/run.sh > "$out/core-contracts.jsonl"
bash LaoHeMa/Tests/run.sh > "$out/controller.jsonl"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I DopamineCore \
  DopamineCore/DOCore.m DopamineCore/DOCommandLine.m DopamineCore/Tests/cli.m -o "$out/cli-contracts" > "$out/cli-build.log" 2>&1
"$out/cli-contracts" > "$out/cli-contracts.jsonl"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I LabSupport \
  LabSupport/LabSupport.m LabSupport/Tests/contracts.m -o "$out/lab-contracts" > "$out/lab-contracts-build.log" 2>&1
"$out/lab-contracts" > "$out/lab-contracts.json"
python3 DopamineCore/Tests/check_boundaries.py --library .build/sdk/DopamineSDK/Lib/libDopamineCore.a > "$out/boundaries.json"
python3 LaoHeMa/Tests/check_compatibility.py --baseline 16ca07b > "$out/compatibility.json"
python3 DopamineCore/Tests/standalone_sdk.py > "$out/isolated.log" 2>&1
printf 'Desktop regression passed. Device regression is separate.\n'
