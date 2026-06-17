#!/system/bin/sh
# KSU Safe Guardian boot-completed.sh

MODDIR=${0%/*}

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/recovery.sh"

log_info "boot-completed 阶段已确认执行"

# 由统一回调函数处理，内置并发锁与已处理标志，防止与 service 重复执行
handle_healthy_boot
