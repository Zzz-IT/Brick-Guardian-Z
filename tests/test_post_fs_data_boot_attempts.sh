#!/usr/bin/env bash
set -euo pipefail
# 测试 post-fs-data 能够精准捕捉 boot_id 变化并递增 boot_attempts

. "$(dirname "$0")/mock_env.sh"
setup_env

# 确保脚本存在
POST_FS="$MODDIR/post-fs-data.sh"
[ -f "$POST_FS" ] || exit 1

# 第一次启动
echo "boot-id-001" > "$MOCK_BOOT_ID_FILE"
sh "$POST_FS"

if [ "$(cat "$MODDIR/state/boot_attempts" 2>/dev/null)" = "1" ]; then
  echo "PASS: 第一次启动 boot_attempts 正确记录为 1"
else
  echo "FAIL: 第一次启动 boot_attempts 不为 1"
  exit 1
fi

if [ "$(cat "$MODDIR/state/last_seen_boot_id" 2>/dev/null)" = "boot-id-001" ]; then
  echo "PASS: last_seen_boot_id 记录正确"
else
  echo "FAIL: last_seen_boot_id 记录错误"
  exit 1
fi

# 同一次启动，再次运行（模拟被重复调用）
sh "$POST_FS"

if [ "$(cat "$MODDIR/state/boot_attempts" 2>/dev/null)" = "1" ]; then
  echo "PASS: 同一 boot_id 下不重复递增"
else
  echo "FAIL: 同一 boot_id 下错误递增了 boot_attempts"
  exit 1
fi

# 第二次启动
echo "boot-id-002" > "$MOCK_BOOT_ID_FILE"
sh "$POST_FS"

if [ "$(cat "$MODDIR/state/boot_attempts" 2>/dev/null)" = "2" ]; then
  echo "PASS: 第二次启动 boot_attempts 递增为 2"
else
  echo "FAIL: 第二次启动 boot_attempts 不为 2"
  exit 1
fi

echo "[TEST] test_post_fs_data_boot_attempts 成功！"
exit 0
