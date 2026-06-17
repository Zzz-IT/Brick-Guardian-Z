#!/system/bin/sh
# KSU Safe Guardian post-fs-data.sh

MODDIR=${0%/*}

# 早期启动阶段简单的日志记录函数
log_info() {
  echo "[INFO] $1" >> "$MODDIR/logs/guardian.log"
}

# 早期追踪 Boot ID 以便即使卡死在 post-fs-data 后也能计数
mkdir -p "$MODDIR/state" "$MODDIR/logs" 2>/dev/null

# 无论任何启动条件，首先记录早期启动尝试
boot_id_file="${MOCK_BOOT_ID_FILE:-/proc/sys/kernel/random/boot_id}"
boot_id="$(cat "$boot_id_file" 2>/dev/null)"
last_seen="$(cat "$MODDIR/state/last_seen_boot_id" 2>/dev/null)"

if [ -n "$boot_id" ] && [ "$boot_id" != "$last_seen" ]; then
  # 使用原子写入的方式记录
  tmp="$MODDIR/state/.last_seen_boot_id.tmp.$$"
  printf '%s\n' "$boot_id" > "$tmp" && mv -f "$tmp" "$MODDIR/state/last_seen_boot_id"
  
  attempts="$(cat "$MODDIR/state/boot_attempts" 2>/dev/null)"
  attempts=${attempts:-0}
  attempts=$((attempts + 1))
  
  tmp_att="$MODDIR/state/.boot_attempts.tmp.$$"
  printf '%s\n' "$attempts" > "$tmp_att" && mv -f "$tmp_att" "$MODDIR/state/boot_attempts"
fi

# 如果存在待处理的迁移任务，我们几乎不执行任何操作，避免在首次启动时产生误判
if [ -f "$MODDIR/state/migration_pending" ]; then
  # 仅确保旧模块被禁用
  touch /data/adb/modules/magisk-brick-guardian/disable 2>/dev/null
  log_info "存在待处理的迁移任务：post-fs-data 阶段保持静默"
  exit 0
fi

log_info "post-fs-data 阶段已执行"
exit 0
