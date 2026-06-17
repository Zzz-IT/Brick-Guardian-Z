#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/recovery.sh"

id="bad_module"
mkdir -p "$ADB_ROOT/modules/$id"
echo "id=$id" > "$ADB_ROOT/modules/$id/module.prop"
echo "$id" > "$MODDIR/state/testing_module"
_set_state_unlocked "boot_attempts" "2"

handle_bootloop

if [ -f "$ADB_ROOT/modules/$id/disable" ]; then
  echo "PASS: testing_module bootloop 后被重新禁用"
else
  echo "FAIL: testing_module bootloop 后未被重新禁用"
  exit 1
fi

if [ -f "$MODDIR/state/failed_module.$id" ]; then
  echo "PASS: failed_module 已记录"
else
  echo "FAIL: failed_module 未记录"
  exit 1
fi

echo "PASS: test_testing_module_rollback 成功"
exit 0
