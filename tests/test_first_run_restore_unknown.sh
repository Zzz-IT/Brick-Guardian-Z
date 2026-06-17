#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/restore_queue.sh"

echo "[TEST] Running test_first_run_restore_unknown..."

# 准备测试模块
mkdir -p "$ADB_ROOT/modules/test_unknown"
echo "id=test_unknown" > "$ADB_ROOT/modules/test_unknown/module.prop"
touch "$ADB_ROOT/modules/test_unknown/disable"

# 1. 普通情况下（没有 first run pending），不会恢复未知 disable
rm -f "$MODDIR/state/first_run_repair_pending"
rm -f "$MODDIR/state/first_run_repair_running"

# 注意需要设置 AUTO_RESTORE_DISABLED_MODULES=1 才能生成恢复队列
sed -i 's/AUTO_RESTORE_DISABLED_MODULES=0/AUTO_RESTORE_DISABLED_MODULES=1/g' "$MODDIR/config/default.conf"

build_module_restore_queue
queue_file="$MODDIR/state/module_restore.queue"

if [ -f "$queue_file" ] && grep -q "test_unknown" "$queue_file"; then
  echo "FAIL: 普通运行时居然把未知 disable 模块加入了队列！"
  exit 1
fi
echo "PASS: 普通运行正确跳过未知 disable 模块"

# 2. 模拟首次运行（存在 pending 标志）
touch "$MODDIR/state/first_run_repair_running"
rm -f "$queue_file"
build_module_restore_queue

if ! grep -q "test_unknown" "$queue_file"; then
  echo "FAIL: 首次运行特权开启时，未能把未知 disable 模块加入队列！"
  exit 1
fi
echo "PASS: 首次运行特权正确捕获未知 disable 模块"

echo "[TEST] test_first_run_restore_unknown 成功！"
exit 0
