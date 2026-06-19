#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

# 1. 模拟一个健康快照，不含嫌疑项
mkdir -p "$ADB_ROOT/modules/module_ok"
echo "versionCode=1" > "$ADB_ROOT/modules/module_ok/module.prop"
mkdir -p "$ADB_ROOT/service.d"
touch "$ADB_ROOT/service.d/script_ok.sh"
chmod +x "$ADB_ROOT/service.d/script_ok.sh"

. "$MODDIR/scripts/snapshot.sh"
save_good_snapshot
save_good_script_snapshot

# 2. 模拟新安装的嫌疑模块与新放入的嫌疑脚本
mkdir -p "$ADB_ROOT/modules/module_bad"
echo "versionCode=1" > "$ADB_ROOT/modules/module_bad/module.prop"
touch "$ADB_ROOT/service.d/script_bad.sh"
chmod +x "$ADB_ROOT/service.d/script_bad.sh"

# 3. 设置 attempts=1 且不是 OTA 启动 (执行 post-fs-data.sh 时会递增至 2)
_set_state_unlocked "last_healthy_build_incremental" "v1.0.0"
export MOCK_GETPROP_INCREMENTAL="v1.0.0"
_set_state_unlocked "last_seen_boot_id" "boot-id-old"
_set_state_unlocked "boot_attempts" "1"

# 4. 执行 post-fs-data.sh 并捕获输出 (它应该执行 reboot 并 exit 0)
output="$(bash "$MODDIR/post-fs-data.sh" 2>&1)"

if echo "$output" | grep -q "MOCK REBOOT"; then
  echo "PASS: early rescue reboot triggered"
else
  echo "FAIL: early rescue reboot not triggered, output: $output"
  exit 1
fi

if [ -f "$ADB_ROOT/modules/module_bad/disable" ]; then
  echo "PASS: suspect module disabled"
else
  echo "FAIL: suspect module not disabled"
  exit 1
fi

if ! is_executable "$ADB_ROOT/service.d/script_bad.sh"; then
  echo "PASS: suspect script disabled (chmod 0644)"
else
  echo "FAIL: suspect script still executable"
  exit 1
fi

if [ -f "$ADB_ROOT/modules/module_ok/disable" ]; then
  echo "FAIL: good module disabled"
  exit 1
fi

if ! is_executable "$ADB_ROOT/service.d/script_ok.sh"; then
  echo "FAIL: good script disabled"
  exit 1
fi

echo "PASS: test_post_fs_early_targeted_rescue 成功"
exit 0
