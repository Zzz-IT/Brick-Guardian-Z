#!/bin/bash
# Mock Environment for testing KSU Safe Guardian

# 设置基础目录
MOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$MOCK_DIR/test_env"
export ADB_ROOT="$TEST_DIR/data/adb"
export MOCK_BOOT_ID_FILE="$TEST_DIR/boot_id"
export MODDIR="$ADB_ROOT/modules/ksu-safe-guardian"

# 清理并重建测试环境
setup_env() {
  rm -rf "$TEST_DIR"
  mkdir -p "$ADB_ROOT/modules"
  mkdir -p "$ADB_ROOT/service.d"
  mkdir -p "$ADB_ROOT/post-fs-data.d"
  mkdir -p "$ADB_ROOT/boot-completed.d"
  
  # 初始化 guardian 目录
  mkdir -p "$MODDIR/state"
  mkdir -p "$MODDIR/logs"
  mkdir -p "$MODDIR/scripts"
  mkdir -p "$MODDIR/config"
  
  # 复制必须的脚本到 mock 环境
  cp "$MOCK_DIR/../scripts/"*.sh "$MODDIR/scripts/" 2>/dev/null || true
  cp "$MOCK_DIR/../"*.sh "$MODDIR/" 2>/dev/null || true
  cp "$MOCK_DIR/../config/default.conf" "$MODDIR/config/default.conf" 2>/dev/null || true
  
  echo "mock-boot-id-001" > "$MOCK_BOOT_ID_FILE"
}

# Mock getprop
export MOCK_GETPROP_INCREMENTAL="v1.0.0"
getprop() {
  if [ "$1" = "ro.system.build.version.incremental" ]; then
    echo "$MOCK_GETPROP_INCREMENTAL"
  fi
}

# 导出函数，以便在被 source 的脚本中可以被调用
export -f getprop
