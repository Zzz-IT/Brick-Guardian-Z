#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v zip >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "FAIL: zip or unzip not found in CI environment, required for release validation"
    exit 1
  else
    echo "SKIP: zip or unzip not found in local environment"
    exit 2
  fi
fi

bash "$ROOT/tools/build_zip.sh"

zip_file="$(ls "$ROOT"/dist/*.zip | head -n 1)"

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
  if unzip -l "$zip_file" | awk '{print $4}' | grep -Fxq "$f"; then
    echo "PASS: zip contains $f"
  else
    echo "FAIL: zip missing $f"
    exit 1
  fi
done

if unzip -l "$zip_file" | awk '{print $4}' | grep -E '^(tests|dist|tools|phone_logs|test_env)/' >/dev/null; then
  echo "FAIL: zip contains development files"
  exit 1
else
  echo "PASS: zip excludes development files"
fi

for forbidden in \
  "scripts/first_run_repair.sh" \
  "scripts/legacy_repair.sh" \
  "scripts/ota_detector.sh" \
  "scripts/rom_detector.sh" \
  "scripts/restore_queue.sh"; do
  if unzip -l "$zip_file" | awk '{print $4}' | grep -Fxq "$forbidden"; then
    echo "FAIL: zip contains forbidden legacy file: $forbidden"
    exit 1
  fi
done

echo "PASS: zip excludes legacy files"

echo "[TEST] test_zip_structure 成功！"
exit 0
