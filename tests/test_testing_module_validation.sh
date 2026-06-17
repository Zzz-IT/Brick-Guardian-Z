#!/usr/bin/env bash
set -euo pipefail
# 测试 testing_module 状态合法性校验

. "$(dirname "$0")/mock_env.sh"

run_invalid_module_basic() {
  setup_env
  . "$MODDIR/scripts/lib.sh"
  . "$MODDIR/scripts/state.sh"
  . "$MODDIR/scripts/recovery.sh"

  _set_state_unlocked "boot_attempts" "3"
  _set_state_unlocked "testing_module" "../../bad"

  handle_bootloop

  if [ ! -f "$MODDIR/state/testing_module" ]; then
    echo "PASS: 非法 testing_module 已被清除"
  else
    echo "FAIL: 非法 testing_module 未被清除"
    exit 1
  fi

  if [ ! -e "$ADB_ROOT/modules/../../bad/disable" ]; then
    echo "PASS: 非法 testing_module 未造成路径污染"
  else
    echo "FAIL: 非法 testing_module 造成了路径污染"
    exit 1
  fi
}

run_invalid_module_continues_rescue() {
  setup_env
  . "$MODDIR/scripts/lib.sh"
  . "$MODDIR/scripts/state.sh"
  . "$MODDIR/scripts/recovery.sh"

  # 设置 boot_attempts=3 达到 targeted 阈值
  _set_state_unlocked "boot_attempts" "3"
  _set_state_unlocked "testing_module" "../escape"

  # 创建一个健康快照，以便 get_suspect_modules 能识别嫌疑模块
  : > "$MODDIR/state/good_modules.tsv"

  # 创建一个新安装的嫌疑模块（不在快照中）
  local suspect_id="suspect-mod"
  mkdir -p "$ADB_ROOT/modules/$suspect_id"
  echo "id=$suspect_id" > "$ADB_ROOT/modules/$suspect_id/module.prop"
  echo "versionCode=1" >> "$ADB_ROOT/modules/$suspect_id/module.prop"

  handle_bootloop

  # 非法 testing_module 应已清除
  if [ -f "$MODDIR/state/testing_module" ]; then
    echo "FAIL: 非法 testing_module 未被清除"
    exit 1
  fi

  # 清除后应继续执行 targeted disable，嫌疑模块应被禁用
  if [ -f "$ADB_ROOT/modules/$suspect_id/disable" ]; then
    echo "PASS: 非法 testing_module 清除后继续触发 targeted disable"
  else
    echo "FAIL: 非法 testing_module 清除后未继续触发 targeted disable"
    exit 1
  fi
}

run_invalid_module_basic
run_invalid_module_continues_rescue

echo "[TEST] test_testing_module_validation 成功！"
exit 0
