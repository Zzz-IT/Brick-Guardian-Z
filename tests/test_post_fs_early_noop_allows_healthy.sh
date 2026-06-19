#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

# 模拟第二次异常启动 (normal boot)，已经有快照
_set_state_unlocked "last_healthy_build_incremental" "v1.0.0"
export MOCK_GETPROP_INCREMENTAL="v1.0.0"

_set_state_unlocked "boot_attempts" "2"

# 写入模块和脚本快照
touch "$MODDIR/state/good_modules.tsv"
touch "$MODDIR/state/good_scripts.tsv"

# 没有新增或变动的模块/脚本，应该不采取任何动作，也不写 decision=bootloop
# 模拟执行 post-fs-data.sh 触发 early rescue
export MOCK_BOOT_ID_FILE="$TEST_DIR/boot_id"
echo "boot_early_noop" > "$MOCK_BOOT_ID_FILE"

sh "$MODDIR/post-fs-data.sh"

# 检查 decision 状态：应该为空，不被污染
dec="$(get_state "decision_boot_early_noop")"
if [ "$dec" = "bootloop" ]; then
  echo "FAIL: early rescue 无动作却标记了 bootloop"
  exit 1
fi

# 检查 last_health_status 状态：应该为空或不为 bootloop
lhs="$(get_state "last_health_status")"
if [ "$lhs" = "bootloop" ]; then
  echo "FAIL: early rescue 无动作却将 last_health_status 设为 bootloop"
  exit 1
fi

# 模拟系统成功启动健康，调用 handle_healthy_boot
. "$MODDIR/scripts/recovery.sh"
handle_healthy_boot

# 检查是否成功恢复 healthy，且 attempts 清零
dec="$(get_state "decision_boot_early_noop")"
lhs="$(get_state "last_health_status")"
attempts="$(get_state "boot_attempts")"

if [ "$dec" != "healthy" ] || [ "$lhs" != "healthy" ] || [ "$attempts" != "0" ]; then
  echo "FAIL: 无污染的早期 noop 应该能使后续成功标记为 healthy。dec=$dec, lhs=$lhs, attempts=$attempts"
  exit 1
fi

echo "PASS: test_post_fs_early_noop_allows_healthy 成功"
exit 0
