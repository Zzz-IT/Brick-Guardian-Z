#!/system/bin/sh
# KSU Safe Guardian state.sh

# 如果 MODDIR 尚未设置，则基于脚本当前位置推断
if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

acquire_lock() {
  local lockdir="$MODDIR/state/.lock"
  local timeout=10
  local elapsed=0
  while ! mkdir "$lockdir" 2>/dev/null; do
    sleep 1
    elapsed=$((elapsed + 1))
    if [ "$elapsed" -ge "$timeout" ]; then
      # 锁超时，强行删除旧锁
      rm -rf "$lockdir"
    fi
  done
}

release_lock() {
  local lockdir="$MODDIR/state/.lock"
  rm -rf "$lockdir"
}

get_state() {
  local key="$1"
  if [ -f "$MODDIR/state/$key" ]; then
    cat "$MODDIR/state/$key"
  fi
}

atomic_write_state() {
  local key="$1"
  local val="$2"
  local tmp="$MODDIR/state/.$key.tmp.$$"
  printf '%s\n' "$val" > "$tmp" || return 1
  mv -f "$tmp" "$MODDIR/state/$key"
}

set_state() {
  local key="$1"
  local val="$2"
  acquire_lock
  atomic_write_state "$key" "$val"
  release_lock
}

clear_state() {
  local key="$1"
  acquire_lock
  rm -f "$MODDIR/state/$key"
  release_lock
}

increment_state() {
  local key="$1"
  acquire_lock
  local val
  val=$(get_state "$key")
  val=${val:-0}
  val=$((val + 1))
  atomic_write_state "$key" "$val"
  release_lock
  echo "$val"
}
