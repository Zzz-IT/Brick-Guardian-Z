#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v zip >/dev/null 2>&1 || { echo "FAIL: zip not found"; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "FAIL: unzip not found"; exit 1; }

ALLOW_TEST_SKIP=0 bash tests/run_all.sh
bash tools/build_zip.sh

zip_file="$(ls dist/*.zip | head -n 1)"
test -n "$zip_file"

unzip -l "$zip_file" >/dev/null

if unzip -l "$zip_file" | awk '{print $4}' | grep -E '^(tests|tools|dist|phone_logs|test_env)/' >/dev/null; then
  echo "FAIL: zip contains development files"
  exit 1
fi

echo "PASS: release check passed"
