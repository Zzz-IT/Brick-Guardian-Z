#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"

export LOG_MAX_BYTES=128
export LOG_MAX_BACKUPS=3

mkdir -p "$MODDIR/logs"

# 写一个超过阈值的日志 (使用 dd 和 tr 生成 256 字节 A)
dd if=/dev/zero bs=256 count=1 2>/dev/null | tr '\0' A > "$MODDIR/logs/guardian.log"

log_info "trigger rotation"

if [ -f "$MODDIR/logs/guardian.log.1" ]; then
  echo "PASS: 日志超过阈值后已轮转"
else
  echo "FAIL: 日志未轮转"
  exit 1
fi

# 连续触发多轮，确保最多保留 .1 .2 .3
for i in 1 2 3 4 5; do
  dd if=/dev/zero bs=256 count=1 2>/dev/null | tr '\0' B > "$MODDIR/logs/guardian.log"
  log_info "trigger rotation $i"
done

if [ -f "$MODDIR/logs/guardian.log.4" ]; then
  echo "FAIL: 日志备份超过上限"
  exit 1
fi

echo "PASS: 日志自动循环轮转并限制备份数量"
exit 0
