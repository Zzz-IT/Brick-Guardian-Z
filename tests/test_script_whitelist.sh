#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/snapshot.sh"
. "$MODDIR/scripts/script_guard.sh"

# Setup directories
mkdir -p "$ADB_ROOT/service.d"
mkdir -p "$ADB_ROOT/post-fs-data.d"

# s_white is whitelisted, s_normal is normal
touch "$ADB_ROOT/service.d/s_white.sh" && chmod +x "$ADB_ROOT/service.d/s_white.sh"
touch "$ADB_ROOT/post-fs-data.d/s_normal.sh" && chmod +x "$ADB_ROOT/post-fs-data.d/s_normal.sh"

# Create whitelist config
echo "service.d/s_white.sh" > "$MODDIR/config/script_whitelist.conf"

# Verify is_script_whitelisted
if is_script_whitelisted "service.d/s_white.sh"; then
  echo "PASS: s_white is whitelisted"
else
  echo "FAIL: s_white not identified as whitelisted"
  exit 1
fi

if ! is_script_whitelisted "post-fs-data.d/s_normal.sh"; then
  echo "PASS: s_normal is not whitelisted"
else
  echo "FAIL: s_normal identified as whitelisted"
  exit 1
fi

# Run snapshot
save_good_script_snapshot

# Simulate changes making both of them suspect (modify content)
echo "new white" > "$ADB_ROOT/service.d/s_white.sh"
echo "new normal" > "$ADB_ROOT/post-fs-data.d/s_normal.sh"

# Run targeted disable
targeted_disable_scripts

if is_executable "$ADB_ROOT/service.d/s_white.sh"; then
  echo "PASS: whitelisted script preserved in targeted recovery"
else
  echo "FAIL: whitelisted script disabled in targeted recovery"
  exit 1
fi

if ! is_executable "$ADB_ROOT/post-fs-data.d/s_normal.sh"; then
  echo "PASS: normal suspect script disabled in targeted recovery"
else
  echo "FAIL: normal suspect script not disabled"
  exit 1
fi

# Restore s_normal to executable for broad test
chmod +x "$ADB_ROOT/post-fs-data.d/s_normal.sh"

# Run broad disable
broad_disable_scripts

if is_executable "$ADB_ROOT/service.d/s_white.sh"; then
  echo "PASS: whitelisted script preserved in broad recovery"
else
  echo "FAIL: whitelisted script disabled in broad recovery"
  exit 1
fi

if ! is_executable "$ADB_ROOT/post-fs-data.d/s_normal.sh"; then
  echo "PASS: normal script disabled in broad recovery"
else
  echo "FAIL: normal script not disabled"
  exit 1
fi

echo "PASS: test_script_whitelist 成功"
exit 0
