#!/system/bin/sh
# Brick Guardian Z zygote_monitor.sh

if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

get_zygote_pid_snapshot() {
  local p64
  local p32

  p64="$(pidof zygote64 2>/dev/null | awk '{print $1}')"
  p32="$(pidof zygote 2>/dev/null | awk '{print $1}')"

  [ -n "$p64$p32" ] || return 1

  echo "${p64:-none}:${p32:-none}"
}

should_monitor_zygote() {
  [ "$(get_config ENABLE_ZYGOTE_MONITOR 1)" = "1" ] || return 1

  local boot_mode
  boot_mode="$(get_state "boot_mode")"
  [ "$boot_mode" = "ota_like" ] && return 1

  local attempts
  attempts="$(get_state "boot_attempts")"
  attempts="$(normalize_positive_int "$attempts" 1)"

  local min_attempt
  min_attempt="$(normalize_positive_int "$(get_config ZYGOTE_MIN_ATTEMPT 2)" 2)"
  [ "$attempts" -ge "$min_attempt" ] || return 1

  return 0
}
