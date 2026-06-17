#!/system/bin/sh
# Brick Guardian Z recovery.sh

if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

apply_recovery_and_reboot() {
  log_info "执行恢复动作后准备重启..."
  sync
  sleep 2
  reboot
  # 如果常规 reboot 失败，强制重启
  sleep 5
  reboot -f
}

_mark_testing_success_unlocked() {
  local module
  module="$(get_state "testing_module")"

  if [ -n "$module" ]; then
    log_info "测试模块启动成功: $module"
    _clear_state_unlocked "testing_module"
    _set_state_unlocked "last_restored_module" "$module"
    _set_state_unlocked "last_action" "成功恢复模块: $module"
  fi

  _set_state_unlocked "last_health_status" "healthy"
  _set_state_unlocked "boot_attempts" "0"
}

handle_healthy_boot() {
  acquire_lock

  local boot_id_file="${MOCK_BOOT_ID_FILE:-/proc/sys/kernel/random/boot_id}"
  local boot_id="$(cat "$boot_id_file" 2>/dev/null)"
  local decision="$(get_state "decision_$boot_id")"

  if [ -n "$boot_id" ] && [ -n "$decision" ]; then
    release_lock
    return 0
  fi

  log_info "系统健康，开始执行健康的守护任务。 (Boot ID: $boot_id)"

  if [ -n "$boot_id" ]; then
    _set_state_unlocked "decision_$boot_id" "healthy"
  fi

  _mark_testing_success_unlocked

  if [ -f "$MODDIR/scripts/restore_queue.sh" ]; then
    . "$MODDIR/scripts/restore_queue.sh"
    save_good_snapshot
    restore_next_item
  fi

  release_lock
}

get_suspect_modules() {
  local suspect_list="$MODDIR/state/suspect_modules.tsv"
  : > "$suspect_list"
  
  local good_snap="$MODDIR/state/good_modules.tsv"
  if [ ! -f "$good_snap" ]; then
    return 1
  fi

  for dir in "$ADB_ROOT/modules"/*; do
    [ -d "$dir" ] || continue
    local id="${dir##*/}"
    is_guardian_self "$id" && continue
    [ -f "$dir/module.prop" ] || continue
    [ -f "$dir/disable" ] && continue

    local vc="$(grep '^versionCode=' "$dir/module.prop" 2>/dev/null | cut -d= -f2)"
    local hash="$(sha256sum "$dir/module.prop" 2>/dev/null | awk '{print $1}')"
    
    # 使用 awk 精确匹配模块 ID，避免点号被当做正则
    local snap_record="$(awk -F '\t' -v id="$id" '$1 == id {print; exit}' "$good_snap")"
    if [ -z "$snap_record" ]; then
      # 新安装的模块
      echo "$id" >> "$suspect_list"
      continue
    fi
    
    local snap_vc="$(echo "$snap_record" | cut -f2)"
    local snap_hash="$(echo "$snap_record" | cut -f3)"
    local snap_disabled="$(echo "$snap_record" | cut -f4)"
    
    if [ "$snap_disabled" = "1" ]; then
      # 刚被启用的模块
      echo "$id" >> "$suspect_list"
    elif [ "$vc" != "$snap_vc" ] || [ "$hash" != "$snap_hash" ]; then
      # 刚更新或被修改过的模块
      echo "$id" >> "$suspect_list"
    fi
  done
}

handle_bootloop() {
  acquire_lock

  local boot_id_file="${MOCK_BOOT_ID_FILE:-/proc/sys/kernel/random/boot_id}"
  local boot_id="$(cat "$boot_id_file" 2>/dev/null)"
  local decision="$(get_state "decision_$boot_id")"

  if [ -n "$boot_id" ] && [ -n "$decision" ]; then
    release_lock
    return 0
  fi

  if [ -n "$boot_id" ]; then
    if [ "$(get_state "boot_completed_seen_$boot_id")" = "1" ]; then
      log_warn "Service 超时，但检测到 boot-completed 已执行，取消 Bootloop 判定。"
      release_lock
      return 0
    fi
    _set_state_unlocked "decision_$boot_id" "bootloop"
  fi

  _set_state_unlocked "last_health_status" "bootloop"
  
  # 仅读取 post-fs-data 维护的失败次数，并增加救砖执行计数
  local attempts="$(get_state "boot_attempts")"
  attempts="${attempts:-1}"
  _increment_state_unlocked "rescue_count" >/dev/null

  log_error "检测到启动卡死（Bootloop）。当前失败尝试次数: $attempts"

  # 1. 如果存在测试项，则回滚
  local module=$(get_state "testing_module")
  if [ -n "$module" ]; then
    if ! is_valid_module_id "$module"; then
      log_error "testing_module 状态非法，已清除并继续普通救砖流程: $module"
      _clear_state_unlocked "testing_module"
      module=""
    fi
  fi

  if [ -n "$module" ]; then
    touch "$ADB_ROOT/modules/$module/disable" 2>/dev/null
    mv "$MODDIR/state/testing_module" "$MODDIR/state/failed_module.$module"
    log_error "测试模块导致了 Bootloop，已被重新禁用: $module"
    _set_state_unlocked "last_action" "拦截启动卡死！已重新禁用测试模块: $module"
    release_lock
    apply_recovery_and_reboot
    return 0
  fi

  local script=$(get_state "testing_script")
  if [ -n "$script" ]; then
    case "$script" in
      "$ADB_ROOT/service.d/"* | "$ADB_ROOT/boot-completed.d/"*)
        ;;
      *)
        log_error "testing_script 状态非法或属于早期脚本，已清除并继续普通救砖流程: $script"
        _clear_state_unlocked "testing_script"
        script=""
        ;;
    esac
  fi

  if [ -n "$script" ]; then
    [ -e "$script" ] && chmod 000 "$script"
    mv "$MODDIR/state/testing_script" "$MODDIR/state/failed_script"
    log_error "测试脚本导致了 Bootloop，已重新取消执行权限: $script"
    _set_state_unlocked "last_action" "拦截启动卡死！已重新禁用测试脚本: $script"
    release_lock
    apply_recovery_and_reboot
    return 0
  fi

  local targeted_threshold="$(get_config TARGETED_RECOVERY_THRESHOLD 2)"
  local broad_threshold="$(get_config BROAD_RECOVERY_THRESHOLD 4)"
  local self_disable_threshold="$(get_config SELF_DISABLE_THRESHOLD 5)"

  # 2. 精准禁用嫌疑模块（新安装、刚更新、刚启用的模块）
  if [ "$attempts" -ge "$targeted_threshold" ] && [ "$attempts" -lt "$broad_threshold" ]; then
    log_error "达到精准禁用阈值，正在识别并禁用嫌疑模块..."
    get_suspect_modules || true
    local suspect_list="$MODDIR/state/suspect_modules.tsv"
    local disabled_any=0
    
    if [ -s "$suspect_list" ]; then
      while read id; do
        is_valid_module_id "$id" || continue
        is_guardian_self "$id" && continue
        if ! is_whitelisted "$id"; then
          touch "$ADB_ROOT/modules/$id/disable"
          echo "$id" >> "$MODDIR/state/guardian_disabled_modules.list"
          log_info "精准禁用嫌疑模块: $id"
          disabled_any=1
        fi
      done < "$suspect_list"
    fi
    
    if [ "$disabled_any" = "1" ]; then
      _set_state_unlocked "last_action" "拦截启动卡死！已精准禁用最近变更的嫌疑模块。"
      release_lock
      apply_recovery_and_reboot
      return 0
    fi
  fi

  # 3. 达到自我禁用阈值
  if [ "$attempts" -ge "$self_disable_threshold" ] && [ "$(get_config ALLOW_SELF_DISABLE 1)" = "1" ]; then
    touch "$MODDIR/disable"
    log_error "达到自我禁用阈值。守护模块已自我禁用，以防止陷入无限循环。"
    _set_state_unlocked "last_action" "拦截启动卡死！由于多次失败，守护模块已自我禁用。"
    release_lock
    apply_recovery_and_reboot
    return 0
  fi

  # 4. 如果精准禁用未生效，执行大范围禁用逻辑
  if [ "$attempts" -ge "$broad_threshold" ] && [ "$(get_config ALLOW_BROAD_DISABLE 1)" = "1" ]; then
    log_error "达到大范围禁用阈值。正在禁用所有非白名单模块。"
    
    local disabled_any=0
    
    for dir in "$ADB_ROOT/modules"/*; do
      [ -d "$dir" ] || continue
      local id="${dir##*/}"
      
      is_valid_module_id "$id" || continue
      is_guardian_self "$id" && continue
      [ -f "$dir/remove" ] && continue
      [ -f "$dir/disable" ] && continue

      if ! is_whitelisted "$id"; then
        touch "$dir/disable"
        echo "$id" >> "$MODDIR/state/guardian_disabled_modules.list"
        log_info "大范围禁用: $id"
        disabled_any=1
      fi
    done
    
    if [ "$disabled_any" = "1" ]; then
      _set_state_unlocked "last_action" "拦截启动卡死！已执行大范围禁用（非白名单模块）。"
      release_lock
      apply_recovery_and_reboot
      return 0
    else
      log_warn "达到大范围禁用阈值，但没有可禁用模块，跳过重启。"
    fi
  fi

  release_lock
}
