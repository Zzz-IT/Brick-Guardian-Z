#!/system/bin/sh
# KSU Safe Guardian restore_queue.sh

if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

save_good_snapshot() {
  local out="$MODDIR/state/good_modules.tsv"
  local tmp="$out.tmp.$$"

  : > "$tmp"
  for dir in /data/adb/modules/*; do
    [ -d "$dir" ] || continue
    local id="${dir##*/}"
    [ -f "$dir/module.prop" ] || continue

    local vc="$(grep '^versionCode=' "$dir/module.prop" 2>/dev/null | cut -d= -f2)"
    local hash="$(sha256sum "$dir/module.prop" 2>/dev/null | awk '{print $1}')"
    local disabled=0
    [ -f "$dir/disable" ] && disabled=1

    echo "$id	$vc	$hash	$disabled" >> "$tmp"
  done

  mv -f "$tmp" "$out"
  sync
}

build_module_restore_queue() {
  local queue="$MODDIR/state/module_restore.queue"
  : > "$queue"

  # 如果全局开关关闭，不生成恢复队列
  if [ "$(get_config AUTO_RESTORE_DISABLED_MODULES 1)" != "1" ]; then
    return 0
  fi

  for dir in /data/adb/modules/*; do
    [ -d "$dir" ] || continue
    local id="${dir##*/}"

    is_valid_module_id "$id" || continue
    [ "$id" = "magisk-brick-guardian" ] && continue
    [ "$id" = "ksu-safe-guardian" ] && continue
    [ -f "$dir/remove" ] && continue
    [ -f "$dir/disable" ] || continue
    [ -f "$dir/module.prop" ] || continue

    local priority="P2"

    if is_whitelisted "$id"; then
      priority="P1"
    fi

    echo "$priority	$id" >> "$queue"
  done

  sort "$queue" -o "$queue"
}

build_script_restore_queue() {
  local queue="$MODDIR/state/script_restore.queue"
  : > "$queue"

  # 如果全局开关关闭，不生成恢复队列
  if [ "$(get_config AUTO_RESTORE_LATE_GLOBAL_SCRIPTS 1)" != "1" ]; then
    return 0
  fi

  for d in /data/adb/service.d /data/adb/boot-completed.d; do
    [ -d "$d" ] || continue

    for f in "$d"/*; do
      [ -e "$f" ] || continue
      local mode="$(stat -c %a "$f" 2>/dev/null)"
      [ "$mode" = "0" ] || [ "$mode" = "000" ] || continue

      echo "AUTO	$f	755" >> "$queue"
    done
  done

  for d in /data/adb/post-fs-data.d /data/adb/post-mount.d; do
    [ -d "$d" ] || continue

    for f in "$d"/*; do
      [ -e "$f" ] || continue
      local mode="$(stat -c %a "$f" 2>/dev/null)"
      [ "$mode" = "0" ] || [ "$mode" = "000" ] || continue

      echo "MANUAL	$f	755" >> "$MODDIR/state/script_manual_review.queue"
    done
  done
}

restore_one_module_for_testing() {
  local queue="$MODDIR/state/module_restore.queue"
  local testing="$MODDIR/state/testing_module"

  [ -f "$testing" ] && return 0
  [ -s "$queue" ] || return 0

  # 使用 awk 处理制表符
  local id="$(head -n 1 "$queue" | awk -F '\t' '{print $2}')"
  [ -n "$id" ] || return 0

  if [ -f "/data/adb/modules/$id/disable" ]; then
    rm -f "/data/adb/modules/$id/disable"
    _set_state_unlocked "testing_module" "$id"
    sed -i '1d' "$queue"
    log_info "已恢复测试模块（将在下一次启动时验证）: $id"
    _set_state_unlocked "last_action" "已尝试恢复并测试模块: $id"
  fi
}

restore_one_script_for_testing() {
  local queue="$MODDIR/state/script_restore.queue"
  local testing="$MODDIR/state/testing_script"

  [ -f "$testing" ] && return 0
  [ -s "$queue" ] || return 0

  # 使用 awk 处理带有制表符分隔的行，防止空格被吞或解析错误
  local path="$(head -n 1 "$queue" | awk -F '\t' '{print $2}')"
  local mode="$(head -n 1 "$queue" | awk -F '\t' '{print $3}')"

  [ -e "$path" ] || {
    sed -i '1d' "$queue"
    return 0
  }

  chmod "$mode" "$path"
  _set_state_unlocked "testing_script" "$path"
  sed -i '1d' "$queue"
  log_info "已恢复测试脚本（将在下一次启动时验证）: $path"
  _set_state_unlocked "last_action" "已尝试恢复并测试全局脚本: $path"
}

restore_next_item() {
  # 注意：此函数假定已被外部锁定（在 handle_healthy_boot 内调用）
  if [ -f "$MODDIR/state/testing_module" ] || [ -f "$MODDIR/state/testing_script" ]; then
    return 0
  fi

  if [ -s "$MODDIR/state/module_restore.queue" ] && [ "$(get_config AUTO_RESTORE_DISABLED_MODULES 1)" = "1" ]; then
    restore_one_module_for_testing
    return 0
  fi

  if [ -s "$MODDIR/state/script_restore.queue" ] && [ "$(get_config AUTO_RESTORE_LATE_GLOBAL_SCRIPTS 1)" = "1" ]; then
    restore_one_script_for_testing
    return 0
  fi
}
