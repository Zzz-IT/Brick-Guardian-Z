#!/system/bin/sh
# Brick Guardian Z post-fs-data.sh

MODDIR=${0%/*}

mkdir -p "$MODDIR/state" "$MODDIR/logs" 2>/dev/null

if [ -f "$MODDIR/scripts/lib.sh" ]; then
  . "$MODDIR/scripts/lib.sh"
else
  log_info() {
    echo "[INFO] $1" >> "$MODDIR/logs/guardian.log"
  }
fi

# 无论任何启动条件，首先记录早期启动尝试
boot_id_file="${MOCK_BOOT_ID_FILE:-/proc/sys/kernel/random/boot_id}"
boot_id="$(cat "$boot_id_file" 2>/dev/null)"
last_seen="$(cat "$MODDIR/state/last_seen_boot_id" 2>/dev/null)"

if [ -n "$boot_id" ] && [ "$boot_id" != "$last_seen" ]; then
  # 使用原子写入的方式记录
  tmp="$MODDIR/state/.last_seen_boot_id.tmp.$$"
  printf '%s\n' "$boot_id" > "$tmp" && mv -f "$tmp" "$MODDIR/state/last_seen_boot_id"
  
  attempts="$(cat "$MODDIR/state/boot_attempts" 2>/dev/null)"
  case "$attempts" in
    ''|*[!0-9]*) attempts=0 ;;
  esac
  attempts=$((attempts + 1))
  
  tmp_att="$MODDIR/state/.boot_attempts.tmp.$$"
  printf '%s\n' "$attempts" > "$tmp_att" && mv -f "$tmp_att" "$MODDIR/state/boot_attempts"
fi

# 开始新的启动生命周期处理
log_info "post-fs-data 阶段已执行"
exit 0
