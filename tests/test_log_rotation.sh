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

# ==========================================
# 测试非法非数字值输入时的防御回滚与正常运行
# ==========================================
export LOG_MAX_BYTES=abc
export LOG_MAX_BACKUPS=abc

setup_env

# 模拟写入 300KB 日志以触发默认 256KB LOG_MAX_BYTES 限制下的轮转
dd if=/dev/zero bs=1000 count=300 2>/dev/null | tr '\0' C > "$MODDIR/logs/guardian.log"
log_info "trigger rotation under illegal parameters"

if [ -f "$MODDIR/logs/guardian.log.1" ]; then
  echo "PASS: 非法日志参数防御回退并成功轮转"
else
  echo "FAIL: 非法日志参数防御失败，未生成轮转备份"
  exit 1
fi

echo "PASS: 日志自动循环轮转并限制备份数量"
exit 0
