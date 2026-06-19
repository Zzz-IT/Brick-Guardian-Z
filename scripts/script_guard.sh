#!/system/bin/sh
# Brick Guardian Z script_guard.sh

if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

get_suspect_scripts() {
  local suspect_list="$MODDIR/state/suspect_scripts.tsv"
  : > "$suspect_list"

  local good_snap="$MODDIR/state/good_scripts.tsv"
  if [ ! -f "$good_snap" ]; then
    return 1
  fi

  local dirs="service.d post-fs-data.d post-mount.d boot-completed.d"
  for sub in $dirs; do
    local dpath="$ADB_ROOT/$sub"
    [ -d "$dpath" ] || continue

    for fpath in "$dpath"/*; do
      [ -f "$fpath" ] || continue
      [ -L "$fpath" ] && continue
      
      local fname="${fpath##*/}"
      local relpath="$sub/$fname"
      
      is_valid_script_relpath "$relpath" || continue
      
      local hash
      hash="$(sha256sum "$fpath" 2>/dev/null | awk '{print $1}')"
      
      local exec=0
      is_executable "$fpath" && exec=1
      
      local snap_record
      snap_record="$(awk -F '\t' -v relpath="$relpath" '$1 == relpath {print; exit}' "$good_snap")"
      if [ -z "$snap_record" ]; then
        # 新增的脚本
        echo "$relpath" >> "$suspect_list"
        continue
      fi
      
      local snap_hash
      local snap_exec
      snap_hash="$(echo "$snap_record" | cut -f2)"
      snap_exec="$(echo "$snap_record" | cut -f3)"
      
      if [ "$snap_exec" = "0" ] && [ "$exec" = "1" ]; then
        # 刚被赋予可执行权限的脚本
        echo "$relpath" >> "$suspect_list"
      elif [ "$hash" != "$snap_hash" ]; then
        # 被修改过的脚本
        echo "$relpath" >> "$suspect_list"
      fi
    done
  done
  return 0
}

disable_script_by_relpath() {
  local relpath="$1"
  local reason="${2:-targeted}"
  local fpath="$ADB_ROOT/$relpath"

  is_valid_script_relpath "$relpath" || return 1
  [ -f "$fpath" ] || return 1
  [ -L "$fpath" ] && return 1
  is_script_whitelisted "$relpath" && return 2

  chmod 0644 "$fpath" 2>/dev/null || return 1
  append_unique_line "$MODDIR/state/guardian_disabled_scripts.list" "$relpath"

  case "$reason" in
    broad) log_info "大范围禁用脚本: $relpath" ;;
    *) log_info "精准禁用嫌疑脚本: $relpath" ;;
  esac

  return 0
}

targeted_disable_scripts() {
  local suspect_list="$MODDIR/state/suspect_scripts.tsv"
  local disabled_any=0

  if get_suspect_scripts; then
    if [ -s "$suspect_list" ]; then
      while IFS= read -r relpath; do
        is_valid_script_relpath "$relpath" || continue
        if ! is_script_whitelisted "$relpath"; then
          if disable_script_by_relpath "$relpath" "targeted"; then
            disabled_any=1
          fi
        else
          log_info "嫌疑脚本受白名单保护，已跳过: $relpath"
        fi
      done < "$suspect_list"
    fi
  fi
  if [ "$disabled_any" = "1" ]; then
    return 0
  fi
  return 1
}

broad_disable_scripts() {
  local disabled_any=0
  local dirs="service.d post-fs-data.d post-mount.d boot-completed.d"
  for sub in $dirs; do
    local dpath="$ADB_ROOT/$sub"
    [ -d "$dpath" ] || continue

    for fpath in "$dpath"/*; do
      [ -f "$fpath" ] || continue
      [ -L "$fpath" ] && continue
      is_executable "$fpath" || continue
      
      local fname="${fpath##*/}"
      local relpath="$sub/$fname"
      
      is_valid_script_relpath "$relpath" || continue
      if ! is_script_whitelisted "$relpath"; then
        if disable_script_by_relpath "$relpath" "broad"; then
          disabled_any=1
        fi
      fi
    done
  done
  if [ "$disabled_any" = "1" ]; then
    return 0
  fi
  return 1
}
