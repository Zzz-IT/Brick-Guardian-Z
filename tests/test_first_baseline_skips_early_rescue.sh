#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

# 模拟首次基线启动 (无 last_healthy_build_incremental)
# 即使 attempts=2，应该也不做 early rescue
rm -f "$MODDIR/state/last_healthy_build_incremental"
_set_state_unlocked "boot_attempts" "2"

export MOCK_BOOT_ID_FILE="$TEST_DIR/boot_id"
echo "boot_first_baseline" > "$MOCK_BOOT_ID_FILE"

# 创建一个非白名单模块，用于验证如果执行了 rescue 会禁用它
mkdir -p "$ADB_ROOT/modules/bad-module"
echo "versionCode=1" > "$ADB_ROOT/modules/bad-module/module.prop"

# 执行 post-fs-data.sh
sh "$MODDIR/post-fs-data.sh"

# 验证模块未被禁用，即 early rescue 被跳过了
if [ -f "$ADB_ROOT/modules/bad-module/disable" ]; then
  echo "FAIL: first_baseline 启动中误触发了 early rescue 禁用动作"
  exit 1
fi

echo "PASS: test_first_baseline_skips_early_rescue 成功"
exit 0
