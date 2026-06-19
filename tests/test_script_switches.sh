#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

# 创建一个嫌疑脚本
mkdir -p "$ADB_ROOT/service.d"
echo "echo test" > "$ADB_ROOT/service.d/suspect_script.sh"
chmod 755 "$ADB_ROOT/service.d/suspect_script.sh"

# 建立健康快照（空快照，相当于任何脚本都是新增的嫌疑项）
touch "$MODDIR/state/good_scripts.tsv"
touch "$MODDIR/state/good_modules.tsv"

# 1. 验证 ALLOW_TARGETED_SCRIPT_DISABLE=0 时，精准救砖不禁用脚本
cat > "$MODDIR/config/default.conf" <<EOF
ENABLED=1
ALLOW_TARGETED_MODULE_DISABLE=1
ALLOW_TARGETED_SCRIPT_DISABLE=0
ALLOW_BROAD_DISABLE=1
ALLOW_SELF_DISABLE=1
TARGETED_RECOVERY_THRESHOLD=2
EOF

_set_state_unlocked "boot_attempts" "2"

. "$MODDIR/scripts/recovery.sh"
try_rescue_actions "2" "early" || true

# 校验脚本应该依然是可执行的（在 mock 环境中代表它没有被 chmod 0644 并且未进入禁用列表）
disabled_list="$(cat "$MODDIR/state/guardian_disabled_scripts.list" 2>/dev/null || echo "")"
if echo "$disabled_list" | grep -q "suspect_script.sh"; then
  echo "FAIL: 设定了 ALLOW_TARGETED_SCRIPT_DISABLE=0 但脚本仍被精准禁用"
  exit 1
fi

# 重置环境
setup_env

cat > "$MODDIR/config/default.conf" <<EOF
ENABLED=1
ALLOW_BROAD_DISABLE=1
ALLOW_BROAD_MODULE_DISABLE=1
ALLOW_BROAD_SCRIPT_DISABLE=0
ALLOW_SELF_DISABLE=1
BROAD_RECOVERY_THRESHOLD=4
EOF

mkdir -p "$ADB_ROOT/service.d"
echo "echo test" > "$ADB_ROOT/service.d/suspect_script.sh"
chmod 755 "$ADB_ROOT/service.d/suspect_script.sh"

. "$MODDIR/scripts/recovery.sh"
try_rescue_actions "4" "early" || true

disabled_list="$(cat "$MODDIR/state/guardian_disabled_scripts.list" 2>/dev/null || echo "")"
if echo "$disabled_list" | grep -q "suspect_script.sh"; then
  echo "FAIL: 设定了 ALLOW_BROAD_SCRIPT_DISABLE=0 但脚本仍被大范围禁用"
  exit 1
fi

echo "PASS: test_script_switches 成功"
exit 0
