#!/usr/bin/env bash
set -euo pipefail
# 测试大范围禁用时是否受白名单保护

. "$(dirname "$0")/mock_env.sh"
setup_env
. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

# 创建一些模拟模块
mkdir -p "$ADB_ROOT/modules/module_normal"
mkdir -p "$ADB_ROOT/modules/module_whitelisted"
mkdir -p "$ADB_ROOT/modules/module_remove"

touch "$ADB_ROOT/modules/module_normal/module.prop"
touch "$ADB_ROOT/modules/module_whitelisted/module.prop"
touch "$ADB_ROOT/modules/module_remove/module.prop"

# 标记为卸载
touch "$ADB_ROOT/modules/module_remove/remove"

# 配置白名单
cat > "$MODDIR/config/whitelist.conf" <<EOF
module_whitelisted
EOF

# 配置 BROAD_RECOVERY_THRESHOLD = 6
cat > "$MODDIR/config/default.conf" <<EOF
BROAD_RECOVERY_THRESHOLD=6
EOF

# 模拟多次失败启动直到触发 broad disable
_set_state_unlocked "boot_attempts" "6"

# 执行 recovery.sh (会触发 broad disable)
# 因为我们要测试 handle_bootloop 的效果，我们直接调用 handle_bootloop
. "$MODDIR/scripts/recovery.sh"
handle_bootloop

# 验证
if [ -f "$ADB_ROOT/modules/module_normal/disable" ]; then
  echo "PASS: 普通模块被禁用"
else
  echo "FAIL: 普通模块未被禁用"
  exit 1
fi

if [ ! -f "$ADB_ROOT/modules/module_whitelisted/disable" ]; then
  echo "PASS: 白名单模块未被禁用"
else
  echo "FAIL: 白名单模块被错误禁用！"
  exit 1
fi

if [ ! -f "$ADB_ROOT/modules/module_remove/disable" ]; then
  echo "PASS: 卸载标记模块被跳过"
else
  echo "FAIL: 卸载标记模块被错误禁用"
  exit 1
fi

if [ ! -f "$ADB_ROOT/modules/ksu-safe-guardian/disable" ]; then
  echo "PASS: 自身模块被跳过"
else
  echo "FAIL: 自身模块被错误禁用"
  exit 1
fi

echo "[TEST] test_broad_disable_respects_whitelist 成功！"
exit 0
