#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

# 模拟 OTA-like 启动 (current build != last healthy build)
_set_state_unlocked "last_healthy_build_incremental" "v1.0.0"
export MOCK_GETPROP_INCREMENTAL="v2.0.0"

_set_state_unlocked "boot_attempts" "2"

export MOCK_BOOT_ID_FILE="$TEST_DIR/boot_id"
echo "boot_ota" > "$MOCK_BOOT_ID_FILE"

# 创建一个非白名单模块，用于验证如果执行了 rescue 会禁用它
mkdir -p "$ADB_ROOT/modules/bad-module"
echo "versionCode=1" > "$ADB_ROOT/modules/bad-module/module.prop"

# 配置 SKIP_EARLY_RESCUE_ON_OTA=1
cat > "$MODDIR/config/default.conf" <<EOF
ENABLED=1
ENABLE_EARLY_RESCUE=1
SKIP_EARLY_RESCUE_ON_OTA=1
TARGETED_RECOVERY_THRESHOLD=2
EOF

# 执行 post-fs-data.sh
sh "$MODDIR/post-fs-data.sh"

# 验证模块没有被禁用，说明 early rescue 被跳过
if [ -f "$ADB_ROOT/modules/bad-module/disable" ]; then
  echo "FAIL: OTA-like 启动中误触发了 early rescue 禁用动作"
  exit 1
fi

echo "PASS: test_ota_skip_early_rescue 成功"
exit 0
