#!/system/bin/sh
# Brick Guardian Z boot-completed.sh

MODDIR=${0%/*}

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/recovery.sh"

log_info "boot-completed 阶段已确认执行"

boot_id_file="${MOCK_BOOT_ID_FILE:-/proc/sys/kernel/random/boot_id}"
boot_id="$(cat "$boot_id_file" 2>/dev/null)"
if [ -n "$boot_id" ]; then
  # 使用无锁方式尽早打入标记，防止与 service timeout 竞态
  _set_state_unlocked "boot_completed_seen_$boot_id" "1"
fi

# 由统一回调函数处理，内置并发锁与已处理标志，防止与 service 重复执行
handle_healthy_boot
