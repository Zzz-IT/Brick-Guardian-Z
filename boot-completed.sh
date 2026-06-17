#!/system/bin/sh
# KSU Safe Guardian boot-completed.sh

MODDIR=${0%/*}

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/recovery.sh"
. "$MODDIR/scripts/detector.sh"

log_info "boot-completed 阶段已确认执行"

set_state "last_health_status" "healthy"
set_state "boot_attempts" "0"

# 保存当前健康的模块快照
if [ -f "$MODDIR/scripts/restore_queue.sh" ]; then
  . "$MODDIR/scripts/restore_queue.sh"
  save_good_snapshot
fi

mark_testing_success

# 尝试恢复下一项
if [ -f "$MODDIR/scripts/restore_queue.sh" ]; then
  restore_next_item
fi
