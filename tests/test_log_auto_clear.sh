#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

# 模拟之前的启动是 healthy
mkdir -p "$MODDIR/state" "$MODDIR/logs"
echo "healthy" > "$MODDIR/state/last_health_status"

# 模拟一些日志文件
echo "old log 1" > "$MODDIR/logs/guardian.log"
echo "old log 2" > "$MODDIR/logs/guardian.log.1"

# 执行 post-fs-data.sh 触发新启动逻辑
export MOCK_BOOT_ID_FILE="$TEST_DIR/proc/sys/kernel/random/boot_id"
mkdir -p "$(dirname "$MOCK_BOOT_ID_FILE")"
echo "new_boot_123" > "$MOCK_BOOT_ID_FILE"
echo "old_boot_456" > "$MODDIR/state/last_seen_boot_id"

sh "$MODDIR/post-fs-data.sh"

if [ -f "$MODDIR/logs/guardian.log.1" ]; then
  echo "FAIL: 旧的 guardian.log.1 未被清除"
  exit 1
fi

# 检查当前日志是否只有新的内容
log_content="$(cat "$MODDIR/logs/guardian.log" 2>/dev/null || echo "")"
if echo "$log_content" | grep -q "old log 1"; then
  echo "FAIL: 旧的 guardian.log 未被清除"
  exit 1
fi

if ! echo "$log_content" | grep -q "post-fs-data 阶段已执行"; then
  echo "FAIL: 新日志未正确写入"
  exit 1
fi

echo "PASS: 健康启动后日志被自动清除"
exit 0
