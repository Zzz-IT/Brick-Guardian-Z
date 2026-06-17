#!/system/bin/sh
# Brick Guardian Z restore_queue.sh

if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

save_good_snapshot() {
  local out="$MODDIR/state/good_modules.tsv"
  local tmp="$out.tmp.$$"

  : > "$tmp"
  for dir in "$ADB_ROOT/modules"/*; do
    [ -d "$dir" ] || continue
    local id="${dir##*/}"
    is_guardian_self "$id" && continue
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

  local guardian_disabled="$MODDIR/state/guardian_disabled_modules.list"

  for dir in "$ADB_ROOT/modules"/*; do
    [ -d "$dir" ] || continue
    local id="${dir##*/}"

    is_valid_module_id "$id" || continue
    is_guardian_self "$id" && continue
    [ -f "$dir/remove" ] && continue
    [ -f "$dir/disable" ] || continue
    [ -f "$dir/module.prop" ] || continue

    # 检查是否是我们守护程序为了救砖而禁用的
    local is_guardian_disabled=0
    if [ -f "$guardian_disabled" ] && grep -Fxq "$id" "$guardian_disabled"; then
      is_guardian_disabled=1
    fi

    # 如果不是我们禁用的，则不加入自动恢复队列
    if [ "$is_guardian_disabled" = "0" ]; then
      continue
    fi

    local priority="P2"

    if is_whitelisted "$id"; then
      priority="P1"
    fi

    echo "$priority	$id" >> "$queue"
  done

  sort "$queue" -o "$queue"
}

restore_one_module_for_testing() {
  local queue="$MODDIR/state/module_restore.queue"
  local testing="$MODDIR/state/testing_module"

  [ -f "$testing" ] && return 0
  [ -s "$queue" ] || return 0

  # 使用 awk 处理制表符
  local id="$(head -n 1 "$queue" | awk -F '\t' '{print $2}')"
  [ -n "$id" ] || return 0

  if [ -f "$ADB_ROOT/modules/$id/disable" ]; then
    rm -f "$ADB_ROOT/modules/$id/disable"
    _set_state_unlocked "testing_module" "$id"
    sed -i '1d' "$queue"
    log_info "已恢复测试模块（将在下一次启动时验证）: $id"
    _set_state_unlocked "last_action" "已尝试恢复并测试模块: $id"
  fi
}

restore_next_item() {
  # 注意：此函数假定已被外部锁定（在 handle_healthy_boot 内调用）
  if [ -f "$MODDIR/state/testing_module" ]; then
    return 0
  fi

  if [ -s "$MODDIR/state/module_restore.queue" ] && [ "$(get_config AUTO_RESTORE_DISABLED_MODULES 1)" = "1" ]; then
    restore_one_module_for_testing
    return 0
  fi
}
