#!/system/bin/sh
# KSU Safe Guardian state.sh

# 如果 MODDIR 尚未设置，则基于脚本当前位置推断
if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

get_state() {
  local key="$1"
  if [ -f "$MODDIR/state/$key" ]; then
    cat "$MODDIR/state/$key"
  fi
}

set_state() {
  local key="$1"
  local val="$2"
  echo "$val" > "$MODDIR/state/$key"
}

clear_state() {
  local key="$1"
  rm -f "$MODDIR/state/$key"
}

increment_state() {
  local key="$1"
  local val
  val=$(get_state "$key")
  val=${val:-0}
  val=$((val + 1))
  set_state "$key" "$val"
  echo "$val"
}
