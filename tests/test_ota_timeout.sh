#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

echo "[TEST] Running test_ota_timeout..."

# 1. 模拟第一次启动，没有 last_system_version
# 在 service.sh 中逻辑：
curr_ver="$(getprop ro.system.build.version.incremental)"
prev_ver="$(get_state "last_system_version")"
timeout=""
if [ -n "$prev_ver" ] && [ "$curr_ver" != "$prev_ver" ]; then
  timeout="$(get_config OTA_BOOT_TIMEOUT_SEC 900)"
else
  timeout="$(get_config NORMAL_BOOT_TIMEOUT_SEC 300)"
fi

if [ "$timeout" != "300" ]; then
  echo "FAIL: 没有前置版本号时，超时时间不是 300！"
  exit 1
fi
echo "PASS: 非 OTA 启动时采用正常超时"

# 2. 模拟写入上一次的版本号，且不一样
_set_state_unlocked "last_system_version" "v0.9.0"
prev_ver="$(get_state "last_system_version")"

if [ -n "$prev_ver" ] && [ "$curr_ver" != "$prev_ver" ]; then
  timeout="$(get_config OTA_BOOT_TIMEOUT_SEC 900)"
else
  timeout="$(get_config NORMAL_BOOT_TIMEOUT_SEC 300)"
fi

if [ "$timeout" != "900" ]; then
  echo "FAIL: 存在不同版本号时，超时时间不是 900！"
  exit 1
fi
echo "PASS: 检测到 OTA 时采用延长超时"

echo "[TEST] test_ota_timeout 成功！"
exit 0
