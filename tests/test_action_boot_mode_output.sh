#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

# 设定 boot_mode 为 ota_like 并模拟写入
_set_state_unlocked "boot_mode" "ota_like"

output="$(sh "$MODDIR/action.sh")"

# 验证输出中是否包含了 "启动模式: ota_like"
if ! echo "$output" | grep -q "启动模式: ota_like"; then
  echo "FAIL: Action UI 没有正确输出当前启动模式。输出内容：$output"
  exit 1
fi

echo "PASS: test_action_boot_mode_output 成功"
exit 0
