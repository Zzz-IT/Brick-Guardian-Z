#!/system/bin/sh
# Brick Guardian Z snapshot.sh

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

    is_valid_module_id "$id" || continue
    is_guardian_self "$id" && continue
    [ -f "$dir/module.prop" ] || continue

    local vc
    local hash
    local disabled

    vc="$(grep '^versionCode=' "$dir/module.prop" 2>/dev/null | cut -d= -f2)"
    hash="$(sha256sum "$dir/module.prop" 2>/dev/null | awk '{print $1}')"
    disabled=0
    [ -f "$dir/disable" ] && disabled=1

    printf '%s\t%s\t%s\t%s\n' "$id" "$vc" "$hash" "$disabled" >> "$tmp"
  done

  mv -f "$tmp" "$out"

  local count
  count="$(wc -l < "$out" 2>/dev/null || echo 0)"
  case "$count" in
    ''|*[!0-9]*) count=0 ;;
  esac
  printf '%s\n' "$count" > "$MODDIR/state/good_modules_count"

  sync
}

save_good_script_snapshot() {
  local out="$MODDIR/state/good_scripts.tsv"
  local tmp="$out.tmp.$$"

  : > "$tmp"

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
      
      printf '%s\t%s\t%s\n' "$relpath" "$hash" "$exec" >> "$tmp"
    done
  done

  mv -f "$tmp" "$out"

  local count
  count="$(wc -l < "$out" 2>/dev/null || echo 0)"
  case "$count" in
    ''|*[!0-9]*) count=0 ;;
  esac
  printf '%s\n' "$count" > "$MODDIR/state/good_scripts_count"

  sync
}
