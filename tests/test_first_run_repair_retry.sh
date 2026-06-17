#!/usr/bin/env bash
set -euo pipefail
# 测试首次清理失败时，pending 标志是否被正确保留

. "$(dirname "$0")/mock_env.sh"
setup_env
. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

# 制造一个失败的 I/O 环境：
# repair_modules_update_bak 要求 modules_update.bak 是一个目录
mkdir -p "$ADB_ROOT/modules_update.bak"

# 制造目标目录无法创建的故障（将其变成一个文件）
mkdir -p "$ADB_ROOT/brick-guardian-z"
touch "$ADB_ROOT/brick-guardian-z/quarantine"

# 标记 pending
_set_state_unlocked "first_run_repair_pending" "1"
_set_state_unlocked "first_run_repair_running" "0"

# 包含 recovery.sh，不要调用 mock
. "$MODDIR/scripts/recovery.sh"

# 调用 handle_healthy_boot
handle_healthy_boot

# 断言
if [ -f "$MODDIR/state/first_run_repair_pending" ]; then
  echo "PASS: 发生异常时 pending 标志被正确保留"
else
  echo "FAIL: 发生异常时 pending 标志被错误清除！"
  exit 1
fi

if [ ! -f "$MODDIR/state/first_run_repair_running" ]; then
  echo "PASS: 发生异常时 running 标志已被清除"
else
  echo "FAIL: running 标志未被清除！"
  exit 1
fi

echo "[TEST] test_first_run_repair_retry 成功！"
exit 0
