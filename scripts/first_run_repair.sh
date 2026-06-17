#!/system/bin/sh
# KSU Safe Guardian first_run_repair.sh

if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

GLOBAL_QUARANTINE="$ADB_ROOT/ksu-safe-guardian/quarantine"

repair_modules_update_bak() {
  local bak="$ADB_ROOT/modules_update.bak"
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

run_first_run_repair() {
  log_info "开始首次启动清理与擦屁股流程..."

  # 归档旧的状态日志记录，只作为历史参考，不参与决策
  mkdir -p "$GLOBAL_QUARANTINE/legacy-state"
  cp -af "$ADB_ROOT/modules/magisk-brick-guardian/startup_count.log" "$GLOBAL_QUARANTINE/legacy-state/" 2>/dev/null
  cp -af "$ADB_ROOT/modules/magisk-brick-guardian/rescue_count.log" "$GLOBAL_QUARANTINE/legacy-state/" 2>/dev/null

  # 隔离被挟持的模块更新备份目录
  if [ "$(get_config AUTO_QUARANTINE_MODULES_UPDATE_BAK 1)" = "1" ]; then
    repair_modules_update_bak || return 1
  fi

  # 为系统中已被禁用的模块或脚本生成恢复队列
  . "$MODDIR/scripts/restore_queue.sh"
  build_module_restore_queue || return 1
  build_script_restore_queue || return 1

  set_state "last_action" "首次安装系统清理与修复已完成。"
  log_info "首次安装系统清理与修复已完成。"
  return 0
}
