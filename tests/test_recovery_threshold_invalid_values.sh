#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/recovery.sh"

# 配置阈值为非法字符
cat > "$MODDIR/config/default.conf" <<EOF
ENABLED=1
TARGETED_RECOVERY_THRESHOLD=abc
BROAD_RECOVERY_THRESHOLD=0
SELF_DISABLE_THRESHOLD=bad
EOF

# 运行 try_rescue_actions 并确认它运行成功（应该能成功 fallback 且顺序校验也生效，即不会 crash 且正常退出/执行）
# 我们检查函数能否在 boot_attempts 为 2 时正常工作（使用默认的 targeted_threshold=2）
_set_state_unlocked "boot_attempts" "2"

# 制造嫌疑模块以便能够触发动作
mkdir -p "$ADB_ROOT/modules/suspect"
echo "versionCode=2" > "$ADB_ROOT/modules/suspect/module.prop"

# 建立健康快照（版本号为 1）
echo -e "suspect\t1\thash\t0" > "$MODDIR/state/good_modules.tsv"

try_rescue_actions "2" "early" || true

# 模块应当成功被精准禁用（说明 abc 成功 fallback 到 2）
if [ ! -f "$ADB_ROOT/modules/suspect/disable" ]; then
  echo "FAIL: 非法阈值 fallback 失败，模块未被禁用"
  exit 1
fi

echo "PASS: test_recovery_threshold_invalid_values 成功"
exit 0
