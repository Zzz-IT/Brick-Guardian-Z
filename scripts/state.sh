#!/system/bin/sh
# KSU Safe Guardian state.sh

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

_set_state_unlocked() {
  atomic_write_state "$1" "$2"
}

_clear_state_unlocked() {
  rm -f "$MODDIR/state/$1"
}

_increment_state_unlocked() {
  local key="$1"
  local val=$(get_state "$key")
  val=${val:-0}
  val=$((val + 1))
  atomic_write_state "$key" "$val"
  echo "$val"
}

set_state() {
  acquire_lock
  _set_state_unlocked "$1" "$2"
  release_lock
}

clear_state() {
  acquire_lock
  _clear_state_unlocked "$1"
  release_lock
}

increment_state() {
  acquire_lock
  local val=$(_increment_state_unlocked "$1")
  release_lock
  echo "$val"
}
