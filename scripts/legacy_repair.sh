#!/system/bin/sh
# KSU Safe Guardian legacy_repair.sh

if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

GLOBAL_QUARANTINE="/data/adb/ksu-safe-guardian/quarantine"

repair_modules_update_bak() {
  local bak="/data/adb/modules_update.bak"
  [ -d "$bak" ] || return 0

  mkdir -p "$GLOBAL_QUARANTINE"
  local dst="$GLOBAL_QUARANTINE/modules_update.bak.$(date +%Y%m%d_%H%M%S)"
  if mv "$bak" "$dst"; then
    log_warn "旧版 modules_update.bak 拦截残留已被隔离到: $dst"
    set_state "quarantined_modules_update" "$dst"
  else
    log_error "隔离 modules_update.bak 失败"
    return 1
  fi
}

run_legacy_repair() {
  log_info "开始旧版数据清理与修复流程..."

  # 归档旧的状态日志记录
  mkdir -p "$GLOBAL_QUARANTINE/legacy-state"
  cp -af /data/adb/modules/magisk-brick-guardian/startup_count.log "$GLOBAL_QUARANTINE/legacy-state/" 2>/dev/null
  cp -af /data/adb/modules/magisk-brick-guardian/rescue_count.log "$GLOBAL_QUARANTINE/legacy-state/" 2>/dev/null

  # 隔离模块更新的备份目录
  if [ "$(get_config AUTO_QUARANTINE_MODULES_UPDATE_BAK 1)" = "1" ]; then
    repair_modules_update_bak
  fi

  # 为被禁用模块或脚本生成恢复队列
  . "$MODDIR/scripts/restore_queue.sh"
  build_module_restore_queue
  build_script_restore_queue

  set_state "last_action" "旧版迁移与修复流程已完成。"
  log_info "旧版迁移与修复流程已完成。"
}
