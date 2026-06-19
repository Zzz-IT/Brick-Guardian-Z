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
[ -n "$boot_id" ] && printf '1\n' > "$MODDIR/state/post_fs_seen_$boot_id"
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
attempts="$(normalize_positive_int "$attempts" 0)"

if [ "$(get_config ENABLE_EARLY_RESCUE 1)" = "1" ]; then
  if [ -f "$MODDIR/scripts/boot_mode.sh" ]; then
    . "$MODDIR/scripts/boot_mode.sh"
    
    boot_mode="$(get_boot_mode)"

    case "$boot_mode" in
      first_baseline)
        log_info "post-fs-data: 首次基线启动，跳过 early rescue。"
        ;;
      ota_like)
        log_info "post-fs-data: OTA-like 启动，固定跳过 early rescue。"
        ;;
      normal)
        targeted_threshold="$(normalize_positive_int "$(get_config TARGETED_RECOVERY_THRESHOLD 2)" 2)"
        if [ "$attempts" -ge "$targeted_threshold" ]; then
          if [ -f "$MODDIR/scripts/recovery.sh" ]; then
            . "$MODDIR/scripts/recovery.sh"
            if try_rescue_actions "$attempts" "early"; then
              exit 0
            else
              log_warn "post-fs-data: early rescue 未执行任何动作，等待 service/boot-completed 后续判定。"
            fi
          fi
        fi
        ;;
    esac
  fi
fi

exit 0
