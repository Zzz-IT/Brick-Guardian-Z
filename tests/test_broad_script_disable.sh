#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/script_guard.sh"

# Create executable scripts in different folders
mkdir -p "$ADB_ROOT/service.d"
mkdir -p "$ADB_ROOT/post-fs-data.d"
mkdir -p "$ADB_ROOT/post-mount.d"
mkdir -p "$ADB_ROOT/boot-completed.d"

touch "$ADB_ROOT/service.d/s1.sh" && chmod +x "$ADB_ROOT/service.d/s1.sh"
touch "$ADB_ROOT/post-fs-data.d/s2.sh" && chmod +x "$ADB_ROOT/post-fs-data.d/s2.sh"
touch "$ADB_ROOT/post-mount.d/s3.sh" && chmod +x "$ADB_ROOT/post-mount.d/s3.sh"
touch "$ADB_ROOT/boot-completed.d/s4.sh" && chmod +x "$ADB_ROOT/boot-completed.d/s4.sh"

# Run broad script disable
broad_disable_scripts

# Check all are chmod 0644 (not executable)
for f in \
  "service.d/s1.sh" \
  "post-fs-data.d/s2.sh" \
  "post-mount.d/s3.sh" \
  "boot-completed.d/s4.sh"; do
  if ! is_executable "$ADB_ROOT/$f"; then
    echo "PASS: $f disabled"
  else
    echo "FAIL: $f still executable"
    exit 1
  fi
done

echo "PASS: test_broad_script_disable 成功"
exit 0
