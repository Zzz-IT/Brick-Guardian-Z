#!/system/bin/sh
# Brick Guardian Z healthcheck.sh

is_healthy_once() {
  [ "$(getprop sys.boot_completed)" = "1" ] || return 1
  pidof system_server >/dev/null 2>&1 || return 1

  bootanim="$(getprop init.svc.bootanim)"
  dev_done="$(getprop dev.bootcomplete)"

  [ "$bootanim" = "stopped" ] || [ "$dev_done" = "1" ] || return 1
  return 0
}

wait_healthy() {
  local timeout="${1:-600}"
  local stable_samples="${2:-3}"
  local sample_interval="${3:-5}"
  local stable=0
  local elapsed=0

  while [ "$elapsed" -lt "$timeout" ]; do
    if is_healthy_once; then
      stable=$((stable + 1))
      if [ "$stable" -ge "$stable_samples" ]; then
        return 0
      fi
    else
      stable=0
    fi

    sleep "$sample_interval"
    elapsed=$((elapsed + sample_interval))
  done

  return 1
}

wait_healthy_or_zygote_unstable() {
  local timeout="${1:-600}"
  local stable_samples="${2:-3}"
  local sample_interval="${3:-5}"
  
  timeout="$(normalize_positive_int "$timeout" 600)"
  stable_samples="$(normalize_positive_int "$stable_samples" 3)"
  sample_interval="$(normalize_positive_int "$sample_interval" 5)"

  local elapsed=0
  local stable=0
  local z_changes=0
  local old_z=""
  local new_z=""

  local z_enabled=0
  if command -v should_monitor_zygote >/dev/null 2>&1; then
    if should_monitor_zygote; then
      z_enabled=1
      local zygote_threshold
      zygote_threshold="$(normalize_positive_int "$(get_config ZYGOTE_RESTART_THRESHOLD 4)" 4)"
      local zygote_window
      zygote_window="$(normalize_positive_int "$(get_config ZYGOTE_MONITOR_WINDOW_SEC 60)" 60)"
      old_z="$(get_zygote_pid_snapshot 2>/dev/null || true)"
    fi
  fi

  while [ "$elapsed" -lt "$timeout" ]; do
    if is_healthy_once; then
      stable=$((stable + 1))
      if [ "$stable" -ge "$stable_samples" ]; then
        return 0
      fi
    else
      stable=0
    fi

    if [ "$z_enabled" = "1" ] && [ "$elapsed" -lt "$zygote_window" ]; then
      new_z="$(get_zygote_pid_snapshot 2>/dev/null || true)"
      if [ -n "$old_z" ] && [ -n "$new_z" ] && [ "$old_z" != "$new_z" ]; then
        z_changes=$((z_changes + 1))
        old_z="$new_z"
      elif [ -z "$old_z" ] && [ -n "$new_z" ]; then
        old_z="$new_z"
      fi

      if [ "$z_changes" -ge "$zygote_threshold" ]; then
        return 2
      fi
    fi

    sleep "$sample_interval"
    elapsed=$((elapsed + sample_interval))
  done

  return 1
}
