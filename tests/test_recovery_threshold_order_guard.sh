#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/recovery.sh"

# 配置阈值顺序错误：Targeted > Broad > Self-Disable
cat > "$MODDIR/config/default.conf" <<EOF
ENABLED=1
TARGETED_RECOVERY_THRESHOLD=4
BROAD_RECOVERY_THRESHOLD=2
SELF_DISABLE_THRESHOLD=1
EOF

# 设 attempts = 1。如果顺序不修正，可能会直接触发 self_disable！
# 如果修正了，attempts=1 时什么动作都不应当触发。
_set_state_unlocked "boot_attempts" "1"

# 制造嫌疑项以防万一
mkdir -p "$ADB_ROOT/modules/suspect"
echo "versionCode=2" > "$ADB_ROOT/modules/suspect/module.prop"
echo -e "suspect\t1\thash\t0" > "$MODDIR/state/good_modules.tsv"

try_rescue_actions "1" "early" || true

# 检查是否误触发了 self-disable 或模块禁用
if [ -f "$MODDIR/disable" ]; then
  echo "FAIL: 阈值顺序错误，但在第一次启动尝试时就误触发了自我禁用！"
  exit 1
fi
if [ -f "$ADB_ROOT/modules/suspect/disable" ]; then
  echo "FAIL: 阈值顺序错误，但在第一次启动尝试时就误触发了精准禁用！"
  exit 1
fi

echo "PASS: test_recovery_threshold_order_guard 成功"
exit 0
