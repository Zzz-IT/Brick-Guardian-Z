#!/usr/bin/env bash
# Mock Environment for testing Brick Guardian Z

# 设置基础目录
MOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TEST_DIR="$MOCK_DIR/test_env"
export ADB_ROOT="$TEST_DIR/data/adb"
export MOCK_BOOT_ID_FILE="$TEST_DIR/boot_id"
export MODDIR="$ADB_ROOT/modules/brick-guardian-z"

# 清理并重建测试环境
setup_env() {
  rm -rf "$TEST_DIR"
  mkdir -p "$ADB_ROOT/modules"
  mkdir -p "$ADB_ROOT/service.d"
  mkdir -p "$ADB_ROOT/post-fs-data.d"
  mkdir -p "$ADB_ROOT/post-mount.d"
  mkdir -p "$ADB_ROOT/boot-completed.d"
  
  # 初始化 guardian 目录
  mkdir -p "$MODDIR/state"
  mkdir -p "$MODDIR/logs"
  mkdir -p "$MODDIR/scripts"
  mkdir -p "$MODDIR/config"
  
  # 复制必须的脚本到 mock 环境
  cp "$MOCK_DIR/../scripts/"*.sh "$MODDIR/scripts/" 2>/dev/null || true
  cp "$MOCK_DIR/../"*.sh "$MODDIR/" 2>/dev/null || true
  cp "$MOCK_DIR/../config/"*.conf "$MODDIR/config/" 2>/dev/null || true
  
  echo "mock-boot-id-001" > "$MOCK_BOOT_ID_FILE"
}

# Mock getprop
export MOCK_GETPROP_INCREMENTAL="v1.0.0"
getprop() {
  if [ "$1" = "ro.system.build.version.incremental" ]; then
    echo "$MOCK_GETPROP_INCREMENTAL"
  fi
}

# Mock reboot
reboot() {
  echo "MOCK REBOOT"
}

# Mock sleep
sleep() {
  :
}

chmod() {
  local perm="$1"
  local file="$2"
  local abs_file
  abs_file="$(readlink -f "$file" 2>/dev/null || echo "$file")"
  
  local rel="${abs_file#$ADB_ROOT/}"
  local safe_rel="$(echo "$rel" | tr '/' '_')"
  local mock_dir="$MODDIR/state/.mock_exec"
  mkdir -p "$mock_dir" 2>/dev/null || true
  
  if [ "$perm" = "+x" ] || [ "$perm" = "0755" ] || [ "$perm" = "755" ]; then
    touch "$mock_dir/$safe_rel" 2>/dev/null || true
  elif [ "$perm" = "0644" ] || [ "$perm" = "644" ]; then
    rm -f "$mock_dir/$safe_rel" 2>/dev/null || true
  fi
  command chmod "$@" 2>/dev/null || true
}

# 导出函数，以便在被 source 的脚本中可以被调用
export -f getprop
export -f reboot
export -f sleep
export -f chmod
