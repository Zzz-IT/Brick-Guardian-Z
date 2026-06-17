#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

mkdir -p "$MODDIR/logs"

export LOG_MAX_BYTES=128
export LOG_MAX_BACKUPS=3

# 模拟一个超大的日志文件
dd if=/dev/zero bs=256 count=1 2>/dev/null | tr '\0' A > "$MODDIR/logs/guardian.log"

# 运行 post-fs-data.sh
bash "$MODDIR/post-fs-data.sh"

if [ -f "$MODDIR/logs/guardian.log.1" ]; then
  echo "PASS: post-fs-data 触发早期日志轮转成功"
else
  echo "FAIL: post-fs-data 未能触发日志轮转"
  exit 1
fi

echo "PASS: test_post_fs_data_uses_rotating_log 成功"
exit 0
