#!/usr/bin/env bash
set -euo pipefail
# 测试 testing_module 状态合法性校验

. "$(dirname "$0")/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/recovery.sh"

_set_state_unlocked "boot_attempts" "3"
_set_state_unlocked "testing_module" "../../bad"

handle_bootloop

if [ ! -f "$MODDIR/state/testing_module" ]; then
  echo "PASS: 非法 testing_module 已被清除"
else
  echo "FAIL: 非法 testing_module 未被清除"
  exit 1
fi

if [ ! -e "$ADB_ROOT/modules/../../bad/disable" ]; then
  echo "PASS: 非法 testing_module 未造成路径污染"
else
  echo "FAIL: 非法 testing_module 造成了路径污染"
  exit 1
fi

echo "[TEST] test_testing_module_validation 成功！"
exit 0
