#!/usr/bin/env bash
set -euo pipefail
# 测试 testing_script 路径合法性校验

. "$(dirname "$0")/mock_env.sh"

# 检查平台是否支持 chmod 000
check_chmod_support() {
  local tmpf="$TEST_DIR/.chmod_test_$$"
  echo "test" > "$tmpf"
  chmod 000 "$tmpf" 2>/dev/null
  local mode
  mode="$(stat -c %a "$tmpf" 2>/dev/null || echo unknown)"
  rm -f "$tmpf"
  if [ "$mode" = "0" ] || [ "$mode" = "000" ]; then
    return 0
  else
    return 1
  fi
}

run_invalid_path_case() {
  setup_env
  . "$MODDIR/scripts/lib.sh"
  . "$MODDIR/scripts/state.sh"
  . "$MODDIR/scripts/recovery.sh"

  _set_state_unlocked "boot_attempts" "3"
  _set_state_unlocked "testing_script" "/tmp/bad.sh"

  # 创建健康快照和嫌疑模块，验证清除后继续救砖
  : > "$MODDIR/state/good_modules.tsv"
  local suspect_id="suspect-from-invalid-script"
  mkdir -p "$ADB_ROOT/modules/$suspect_id"
  echo "id=$suspect_id" > "$ADB_ROOT/modules/$suspect_id/module.prop"
  echo "versionCode=1" >> "$ADB_ROOT/modules/$suspect_id/module.prop"

  handle_bootloop

  if [ ! -f "$MODDIR/state/testing_script" ]; then
    echo "PASS: 非法 testing_script 路径已被清除"
  else
    echo "FAIL: 非法 testing_script 路径未被清除"
    exit 1
  fi

  # 清除后应继续 targeted disable
  if [ -f "$ADB_ROOT/modules/$suspect_id/disable" ]; then
    echo "PASS: 非法 testing_script 清除后继续触发 targeted disable"
  else
    echo "FAIL: 非法 testing_script 清除后未继续触发 targeted disable"
    exit 1
  fi
}

run_early_path_case() {
  setup_env
  . "$MODDIR/scripts/lib.sh"
  . "$MODDIR/scripts/state.sh"
  . "$MODDIR/scripts/recovery.sh"

  mkdir -p "$ADB_ROOT/post-fs-data.d"
  script="$ADB_ROOT/post-fs-data.d/early.sh"
  echo '#!/system/bin/sh' > "$script"
  chmod 755 "$script"

  _set_state_unlocked "boot_attempts" "3"
  _set_state_unlocked "testing_script" "$script"

  # 创建健康快照和嫌疑模块
  : > "$MODDIR/state/good_modules.tsv"
  local suspect_id="suspect-from-early-script"
  mkdir -p "$ADB_ROOT/modules/$suspect_id"
  echo "id=$suspect_id" > "$ADB_ROOT/modules/$suspect_id/module.prop"
  echo "versionCode=1" >> "$ADB_ROOT/modules/$suspect_id/module.prop"

  handle_bootloop

  if [ ! -f "$MODDIR/state/testing_script" ]; then
    echo "PASS: post-fs-data.d 早期脚本默认不自动回滚"
  else
    echo "FAIL: post-fs-data.d 早期脚本被错误保留为 testing_script"
    exit 1
  fi

  # 清除后应继续 targeted disable
  if [ -f "$ADB_ROOT/modules/$suspect_id/disable" ]; then
    echo "PASS: 早期脚本清除后继续触发 targeted disable"
  else
    echo "FAIL: 早期脚本清除后未继续触发 targeted disable"
    exit 1
  fi
}

run_service_path_case() {
  setup_env
  . "$MODDIR/scripts/lib.sh"
  . "$MODDIR/scripts/state.sh"
  . "$MODDIR/scripts/recovery.sh"

  mkdir -p "$ADB_ROOT/service.d"
  script="$ADB_ROOT/service.d/good.sh"
  echo '#!/system/bin/sh' > "$script"
  chmod 755 "$script"

  _set_state_unlocked "boot_attempts" "3"
  _set_state_unlocked "testing_script" "$script"

  handle_bootloop

  if [ -f "$MODDIR/state/failed_script" ]; then
    echo "PASS: service.d testing_script 被正确回滚"
  else
    echo "FAIL: service.d testing_script 未被正确回滚"
    exit 1
  fi

  # 验证 chmod 000（仅在支持的平台上检查）
  if check_chmod_support; then
    local mode
    mode="$(stat -c %a "$script" 2>/dev/null || echo missing)"
    if [ "$mode" = "0" ] || [ "$mode" = "000" ]; then
      echo "PASS: service.d testing_script 被 chmod 000"
    else
      echo "FAIL: service.d testing_script 未被 chmod 000, mode=$mode"
      exit 1
    fi
  else
    echo "PASS: service.d chmod 000 验证跳过（平台不支持 POSIX 权限）"
  fi
}

run_boot_completed_path_case() {
  setup_env
  . "$MODDIR/scripts/lib.sh"
  . "$MODDIR/scripts/state.sh"
  . "$MODDIR/scripts/recovery.sh"

  mkdir -p "$ADB_ROOT/boot-completed.d"
  script="$ADB_ROOT/boot-completed.d/good.sh"
  echo '#!/system/bin/sh' > "$script"
  chmod 755 "$script"

  _set_state_unlocked "boot_attempts" "3"
  _set_state_unlocked "testing_script" "$script"

  handle_bootloop

  if [ -f "$MODDIR/state/failed_script" ]; then
    echo "PASS: boot-completed.d testing_script 被正确回滚"
  else
    echo "FAIL: boot-completed.d testing_script 未被正确回滚"
    exit 1
  fi

  # 验证 chmod 000（仅在支持的平台上检查）
  if check_chmod_support; then
    local mode
    mode="$(stat -c %a "$script" 2>/dev/null || echo missing)"
    if [ "$mode" = "0" ] || [ "$mode" = "000" ]; then
      echo "PASS: boot-completed.d testing_script 被 chmod 000"
    else
      echo "FAIL: boot-completed.d testing_script 未被 chmod 000, mode=$mode"
      exit 1
    fi
  else
    echo "PASS: boot-completed.d chmod 000 验证跳过（平台不支持 POSIX 权限）"
  fi
}

run_invalid_path_case
run_early_path_case
run_service_path_case
run_boot_completed_path_case

echo "[TEST] test_testing_script_validation 成功！"
exit 0
