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

handle_healthy_boot() {
  acquire_lock

  local boot_id_file="${MOCK_BOOT_ID_FILE:-/proc/sys/kernel/random/boot_id}"
  local boot_id
  local decision

  boot_id="$(cat "$boot_id_file" 2>/dev/null)"
  decision="$(get_state "decision_$boot_id")"

  if [ -n "$boot_id" ] && [ -n "$decision" ]; then
    release_lock
    return 0
  fi

  log_info "系统健康，保存健康快照。 (Boot ID: $boot_id)"

  if [ -n "$boot_id" ]; then
    _set_state_unlocked "decision_$boot_id" "healthy"
  fi

  _set_state_unlocked "last_health_status" "healthy"
  _set_state_unlocked "boot_attempts" "0"
  _set_state_unlocked "last_action" "系统健康，已更新健康快照。"

  if [ -f "$MODDIR/scripts/snapshot.sh" ]; then
    . "$MODDIR/scripts/snapshot.sh"
    save_good_snapshot
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

    is_valid_module_id "$id" || continue
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
  local boot_id
  local decision

  boot_id="$(cat "$boot_id_file" 2>/dev/null)"
  decision="$(get_state "decision_$boot_id")"

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

  local attempts
  attempts="$(get_state "boot_attempts")"
  case "$attempts" in
    ''|*[!0-9]*) attempts=1 ;;
  esac

  _increment_state_unlocked "rescue_count" >/dev/null

  log_error "检测到启动异常。当前异常启动次数: $attempts"

  local targeted_threshold
  local broad_threshold
  local self_disable_threshold

  targeted_threshold="$(get_config TARGETED_RECOVERY_THRESHOLD 2)"
  broad_threshold="$(get_config BROAD_RECOVERY_THRESHOLD 4)"
  self_disable_threshold="$(get_config SELF_DISABLE_THRESHOLD 5)"

  # 1. 精准禁用嫌疑模块
  if [ "$attempts" -ge "$targeted_threshold" ] && [ "$attempts" -lt "$broad_threshold" ]; then
    log_error "达到精准禁用阈值，正在识别并禁用嫌疑模块..."

    local suspect_list="$MODDIR/state/suspect_modules.tsv"
    local disabled_any=0

    if get_suspect_modules; then
      if [ -s "$suspect_list" ]; then
        while IFS= read -r id; do
          is_valid_module_id "$id" || continue
          is_guardian_self "$id" && continue

          if ! is_whitelisted "$id"; then
            touch "$ADB_ROOT/modules/$id/disable"
            append_unique_line "$MODDIR/state/guardian_disabled_modules.list" "$id"
            log_info "精准禁用嫌疑模块: $id"
            disabled_any=1
          else
            log_info "嫌疑模块受白名单保护，跳过禁用: $id"
          fi
        done < "$suspect_list"
      fi

      if [ "$disabled_any" = "1" ]; then
        _set_state_unlocked "last_action" "已禁用嫌疑模块。"
        release_lock
        apply_recovery_and_reboot
        return 0
      else
        _set_state_unlocked "last_action" "已检查嫌疑模块，但没有可禁用项。"
        log_warn "已检查嫌疑模块，但没有可禁用项。"
      fi
    else
      _set_state_unlocked "last_action" "缺少健康快照，无法精准识别嫌疑模块。"
      log_warn "缺少健康快照，无法精准识别嫌疑模块。"
    fi
  fi

  # 2. 自我禁用
  if [ "$attempts" -ge "$self_disable_threshold" ] && [ "$(get_config ALLOW_SELF_DISABLE 1)" = "1" ]; then
    touch "$MODDIR/disable"
    log_error "达到自我禁用阈值，Brick Guardian Z 已自我禁用。"
    _set_state_unlocked "last_action" "由于多次异常启动，Brick Guardian Z 已自我禁用。"
    release_lock
    apply_recovery_and_reboot
    return 0
  fi

  # 3. 大范围禁用
  if [ "$attempts" -ge "$broad_threshold" ] && [ "$(get_config ALLOW_BROAD_DISABLE 1)" = "1" ]; then
    log_error "达到大范围禁用阈值，正在禁用所有非白名单模块。"

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
        append_unique_line "$MODDIR/state/guardian_disabled_modules.list" "$id"
        log_info "大范围禁用: $id"
        disabled_any=1
      fi
    done

    if [ "$disabled_any" = "1" ]; then
      _set_state_unlocked "last_action" "已执行大范围禁用。"
      release_lock
      apply_recovery_and_reboot
      return 0
    else
      _set_state_unlocked "last_action" "达到大范围禁用阈值，但没有可禁用模块，已跳过重启。"
      log_warn "达到大范围禁用阈值，但没有可禁用模块，跳过重启。"
    fi
  fi

  release_lock
}
