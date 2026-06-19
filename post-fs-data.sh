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
  if [ "$(cat "$MODDIR/state/last_health_status" 2>/dev/null)" = "healthy" ]; then
    rm -f "$MODDIR/logs/guardian.log"* 2>/dev/null
  fi

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

# Early Rescue 早期救砖逻辑
attempts="$(cat "$MODDIR/state/boot_attempts" 2>/dev/null)"
case "$attempts" in
  ''|*[!0-9]*) attempts=0 ;;
esac

if [ "$(get_config ENABLE_EARLY_RESCUE 1)" = "1" ]; then
  if [ -f "$MODDIR/scripts/boot_mode.sh" ]; then
    . "$MODDIR/scripts/boot_mode.sh"
    
    # 无论是否为 OTA 启动，如果达到或超过自我禁用阈值，都在早期执行自我禁用
    self_disable_threshold="$(get_config SELF_DISABLE_THRESHOLD 5)"
    if [ "$attempts" -ge "$self_disable_threshold" ] && [ "$(get_config ALLOW_SELF_DISABLE 1)" = "1" ]; then
      log_warn "post-fs-data: 达到自我禁用阈值 ($attempts)，执行早期自我禁用。"
      if [ -f "$MODDIR/scripts/recovery.sh" ]; then
        . "$MODDIR/scripts/recovery.sh"
        handle_bootloop
        exit 0
      fi
    fi

    # 对于 targeted 和 broad 救砖，非 OTA 启动时在早期执行
    if ! is_ota_like_boot; then
      targeted_threshold="$(get_config TARGETED_RECOVERY_THRESHOLD 2)"
      if [ "$attempts" -ge "$targeted_threshold" ]; then
        log_warn "post-fs-data: 检测到异常启动次数为 $attempts，触发早期救砖流程。"
        if [ -f "$MODDIR/scripts/recovery.sh" ]; then
          . "$MODDIR/scripts/recovery.sh"
          handle_bootloop
          exit 0
        fi
      fi
    fi
  fi
fi

exit 0
