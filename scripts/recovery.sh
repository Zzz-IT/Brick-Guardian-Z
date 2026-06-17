#!/system/bin/sh
# KSU Safe Guardian recovery.sh

if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

source "$MODDIR/scripts/lib.sh"
source "$MODDIR/scripts/state.sh"

mark_testing_success() {
  local module=$(get_state "testing_module")
  if [ -n "$module" ]; then
    log_info "测试模块启动成功: $module"
    clear_state "testing_module"
    set_state "last_action" "成功恢复模块: $module"
  fi

  local script=$(get_state "testing_script")
  if [ -n "$script" ]; then
    log_info "测试脚本启动成功: $script"
    clear_state "testing_script"
    set_state "last_action" "成功恢复脚本: $script"
  fi

  set_state "last_health_status" "healthy"
  set_state "boot_attempts" "0"
}

handle_bootloop() {
  set_state "last_health_status" "bootloop"
  local attempts=$(increment_state "boot_attempts")
  increment_state "rescue_count"

  log_error "检测到启动卡死（Bootloop）。当前尝试次数: $attempts"

  # 1. 如果存在测试项，则回滚
  local module=$(get_state "testing_module")
  if [ -n "$module" ]; then
    touch "/data/adb/modules/$module/disable" 2>/dev/null
    mv "$MODDIR/state/testing_module" "$MODDIR/state/failed_module.$module"
    log_error "测试模块导致了 Bootloop，已被重新禁用: $module"
    set_state "last_action" "拦截启动卡死！已重新禁用测试模块: $module"
    return 0
  fi

  local script=$(get_state "testing_script")
  if [ -n "$script" ]; then
    [ -e "$script" ] && chmod 000 "$script"
    mv "$MODDIR/state/testing_script" "$MODDIR/state/failed_script"
    log_error "测试脚本导致了 Bootloop，已重新取消执行权限: $script"
    set_state "last_action" "拦截启动卡死！已重新禁用测试脚本: $script"
    return 0
  fi

  # 2. 如果不是特定测试项导致的卡死，执行大范围禁用逻辑
  local broad_threshold=$(get_config BROAD_RECOVERY_THRESHOLD 5)
  local self_disable_threshold=$(get_config SELF_DISABLE_THRESHOLD 6)

  if [ "$attempts" -ge "$self_disable_threshold" ] && [ "$(get_config ALLOW_SELF_DISABLE 1)" = "1" ]; then
    touch "$MODDIR/disable"
    log_error "达到自我禁用阈值。守护模块已自我禁用，以防止陷入无限循环。"
    set_state "last_action" "拦截启动卡死！由于多次失败，守护模块已自我禁用。"
    return 0
  fi

  if [ "$attempts" -ge "$broad_threshold" ] && [ "$(get_config ALLOW_BROAD_DISABLE 1)" = "1" ]; then
    log_error "达到大范围禁用阈值。正在禁用所有非白名单模块。"
    for dir in /data/adb/modules/*; do
      [ -d "$dir" ] || continue
      local id="${dir##*/}"
      
      is_valid_module_id "$id" || continue
      [ "$id" = "ksu-safe-guardian" ] && continue
      [ -f "$dir/remove" ] && continue
      [ -f "$dir/disable" ] && continue

      if ! is_whitelisted "$id"; then
        touch "$dir/disable"
        log_info "大范围禁用: $id"
      fi
    done
    set_state "last_action" "拦截启动卡死！已执行大范围禁用（非白名单模块）。"
    return 0
  fi
}
