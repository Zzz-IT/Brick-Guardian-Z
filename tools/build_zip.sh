#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/dist"

version="$(awk -F= '$1=="version"{print $2; exit}' "$ROOT/module.prop")"
version="${version:-v1.0.0}"

name="Brick-Guardian-Z-${version}.zip"

rm -rf "$OUT"
mkdir -p "$OUT"

cd "$ROOT"

required=(
  module.prop
  skip_mount
  customize.sh
  post-fs-data.sh
  service.sh
  boot-completed.sh
  action.sh
  uninstall.sh
  config/default.conf
  config/whitelist.conf
  scripts/lib.sh
  scripts/state.sh
  scripts/healthcheck.sh
  scripts/recovery.sh
  scripts/snapshot.sh
)

for f in "${required[@]}"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: missing required file: $f"
    exit 1
  fi
done

zip -r "$OUT/$name" \
  module.prop \
  skip_mount \
  customize.sh \
  post-fs-data.sh \
  service.sh \
  boot-completed.sh \
  action.sh \
  uninstall.sh \
  config \
  scripts \
  -x "*.git*" \
  -x "tests/*" \
  -x "dist/*" \
  -x "tools/*" \
  -x "phone_logs/*" \
  -x "test_env/*"

echo "Built: $OUT/$name"
