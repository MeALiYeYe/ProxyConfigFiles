#!/usr/bin/env bash
set -e

# 保证从仓库根目录执行
cd "$(dirname "$0")/../.."

echo "== Expand =="
bash scripts/sync-rule/expand.sh

echo "== Normalize =="
bash scripts/sync-rule/normalize.sh

echo "== Generate =="
bash scripts/sync-rule/generate.sh

echo "== Mihomo Core & MRS =="
bash scripts/sync-rule/tomrs.sh

echo "== DONE =="
