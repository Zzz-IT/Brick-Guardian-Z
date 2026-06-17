#!/system/bin/sh
# Brick Guardian Z state.sh

if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

acquire_lock() {
  local lockdir="$MODDIR/state/.lock"
  local now="$(date +%s)"
  while ! mkdir "$lockdir" 2>/dev/null; do
    local old="$(cat "$lockdir/time" 2>/dev/null)"
    case "$old" in
      ''|*[!0-9]*)
        rm -rf "$lockdir"
        continue
        ;;
    esac
    if [ $((now - old)) -gt 60 ]; then
      rm -rf "$lockdir"
      continue
    fi
    sleep 1
    now="$(date +%s)"
  done
  echo "$$" > "$lockdir/pid"
  date +%s > "$lockdir/time"
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
