#!/usr/bin/env bash
set -euo pipefail
# 测试 testing_script 路径合法性校验

. "$(dirname "$0")/mock_env.sh"

run_invalid_path_case() {
  setup_env
  . "$MODDIR/scripts/lib.sh"
  . "$MODDIR/scripts/state.sh"
  . "$MODDIR/scripts/recovery.sh"

  _set_state_unlocked "boot_attempts" "3"
  _set_state_unlocked "testing_script" "/tmp/bad.sh"

  handle_bootloop

  if [ ! -f "$MODDIR/state/testing_script" ]; then
    echo "PASS: 非法 testing_script 路径已被清除"
  else
    echo "FAIL: 非法 testing_script 路径未被清除"
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

  handle_bootloop

  if [ ! -f "$MODDIR/state/testing_script" ]; then
    echo "PASS: post-fs-data.d 早期脚本默认不自动回滚"
  else
    echo "FAIL: post-fs-data.d 早期脚本被错误保留为 testing_script"
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
    echo "PASS: service.d testing_script 被正确回滚 chmod 000"
  else
    echo "FAIL: service.d testing_script 未被正确回滚"
    exit 1
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
    echo "PASS: boot-completed.d testing_script 被正确回滚 chmod 000"
  else
    echo "FAIL: boot-completed.d testing_script 未被正确回滚"
    exit 1
  fi
}

run_invalid_path_case
run_early_path_case
run_service_path_case
run_boot_completed_path_case

echo "[TEST] test_testing_script_validation 成功！"
exit 0
