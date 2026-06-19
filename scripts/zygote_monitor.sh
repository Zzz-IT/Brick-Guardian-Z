#!/system/bin/sh
# Brick Guardian Z zygote_monitor.sh

if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

zygote_name() {
  case "$(getprop ro.product.cpu.abi 2>/dev/null)" in
    arm64-v8a|x86_64) echo "zygote64" ;;
    *) echo "zygote" ;;
  esac
}

monitor_zygote_unstable() {
  [ "$(get_config ENABLE_ZYGOTE_MONITOR 1)" = "1" ] || return 1

  local boot_mode
  boot_mode="$(get_state "boot_mode")"
  [ "$boot_mode" = "ota_like" ] && return 1

  local attempts
  attempts="$(get_state "boot_attempts")"
  case "$attempts" in
    ''|*[!0-9]*) attempts=1 ;;
  esac

  local min_attempt
  min_attempt="$(get_config ZYGOTE_MIN_ATTEMPT 2)"
  [ "$attempts" -ge "$min_attempt" ] || return 1

  local window
  local interval
  local threshold
  local elapsed=0
  local changes=0
  local proc
  local old_pid
  local new_pid

  window="$(get_config ZYGOTE_MONITOR_WINDOW_SEC 60)"
  interval="$(get_config ZYGOTE_MONITOR_INTERVAL_SEC 5)"
  threshold="$(get_config ZYGOTE_RESTART_THRESHOLD 4)"

  proc="$(zygote_name)"
  old_pid="$(pidof "$proc" 2>/dev/null | awk '{print $1}')"

  while [ "$elapsed" -lt "$window" ]; do
    [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ] && return 1

    sleep "$interval"
    elapsed=$((elapsed + interval))

    new_pid="$(pidof "$proc" 2>/dev/null | awk '{print $1}')"

    if [ -n "$old_pid" ] && [ -n "$new_pid" ] && [ "$old_pid" != "$new_pid" ]; then
      changes=$((changes + 1))
      old_pid="$new_pid"
    elif [ -z "$old_pid" ] && [ -n "$new_pid" ]; then
      old_pid="$new_pid"
    fi

    if [ "$changes" -ge "$threshold" ]; then
      log_warn "检测到 zygote 不稳定，提前进入救砖判定。"
      _set_state_unlocked "last_action" "检测到 zygote 不稳定，提前进入救砖判定。"
      return 0
    fi
  done

  return 1
}
