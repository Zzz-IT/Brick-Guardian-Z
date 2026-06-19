#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/recovery.sh"

# 配置阈值
cat > "$MODDIR/config/default.conf" <<EOF
ENABLED=1
TARGETED_RECOVERY_THRESHOLD=2
BROAD_RECOVERY_THRESHOLD=4
SELF_DISABLE_THRESHOLD=5
EOF

# 正常建立
_set_state_unlocked "last_healthy_build_incremental" "v1.0.0"
export MOCK_GETPROP_INCREMENTAL="v1.0.0"

_set_state_unlocked "boot_attempts" "2"
_set_state_unlocked "rescue_count" "0"

# 创建嫌疑模块
mkdir -p "$ADB_ROOT/modules/suspect"
echo "versionCode=2" > "$ADB_ROOT/modules/suspect/module.prop"
echo -e "suspect\t1\thash\t0" > "$MODDIR/state/good_modules.tsv"

# 模拟通过 handle_bootloop 触发救砖，它会调用 mark_bootloop_decision 并接着运行 try_rescue_actions
handle_bootloop

# 检查 rescue_count 应该正好只加了 1
count="$(get_state "rescue_count")"
if [ "$count" != "1" ]; then
  echo "FAIL: rescue_count 发生重复递增，预期为 1，实际为 $count"
  exit 1
fi

echo "PASS: test_rescue_count_single_increment 成功"
exit 0
