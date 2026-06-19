#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

# 1. 模拟两个普通模块与两个普通脚本 (一个在白名单，一个不在)
mkdir -p "$ADB_ROOT/modules/module_normal"
echo "versionCode=1" > "$ADB_ROOT/modules/module_normal/module.prop"
mkdir -p "$ADB_ROOT/modules/module_white"
echo "versionCode=1" > "$ADB_ROOT/modules/module_white/module.prop"

mkdir -p "$ADB_ROOT/service.d"
touch "$ADB_ROOT/service.d/script_normal.sh"
chmod +x "$ADB_ROOT/service.d/script_normal.sh"
touch "$ADB_ROOT/service.d/script_white.sh"
chmod +x "$ADB_ROOT/service.d/script_white.sh"

# 2. 设置白名单
echo "module_white" > "$MODDIR/config/whitelist.conf"
echo "service.d/script_white.sh" > "$MODDIR/config/script_whitelist.conf"

# 3. 设置 attempts=3 且不是 OTA 启动 (执行 post-fs-data.sh 时会递增至 4)
_set_state_unlocked "last_healthy_build_incremental" "v1.0.0"
export MOCK_GETPROP_INCREMENTAL="v1.0.0"
_set_state_unlocked "last_seen_boot_id" "boot-id-old"
_set_state_unlocked "boot_attempts" "3"

# 4. 执行 post-fs-data.sh 捕获输出并验证
output="$(bash "$MODDIR/post-fs-data.sh" 2>&1)"

if echo "$output" | grep -q "MOCK REBOOT"; then
  echo "PASS: early broad rescue reboot triggered"
else
  echo "FAIL: early broad rescue reboot not triggered"
  exit 1
fi

if [ -f "$ADB_ROOT/modules/module_normal/disable" ]; then
  echo "PASS: normal module disabled under broad rescue"
else
  echo "FAIL: normal module not disabled"
  exit 1
fi

if [ ! -f "$ADB_ROOT/modules/module_white/disable" ]; then
  echo "PASS: whitelisted module respected"
else
  echo "FAIL: whitelisted module disabled"
  exit 1
fi

if ! is_executable "$ADB_ROOT/service.d/script_normal.sh"; then
  echo "PASS: normal script disabled (chmod 0644)"
else
  echo "FAIL: normal script still executable"
  exit 1
fi

if is_executable "$ADB_ROOT/service.d/script_white.sh"; then
  echo "PASS: whitelisted script respected"
else
  echo "FAIL: whitelisted script disabled"
  exit 1
fi

echo "PASS: test_post_fs_early_broad_rescue 成功"
exit 0
