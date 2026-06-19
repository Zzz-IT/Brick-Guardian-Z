#!/system/bin/sh
# Brick Guardian Z boot_mode.sh

if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

record_healthy_build() {
  local build
  build="$(getprop ro.system.build.version.incremental 2>/dev/null)"
  [ -n "$build" ] || return 0
  _set_state_unlocked "last_healthy_build_incremental" "$build"
}

is_ota_like_boot() {
  local current_build
  local last_healthy_build

  current_build="$(getprop ro.system.build.version.incremental 2>/dev/null)"
  last_healthy_build="$(get_state "last_healthy_build_incremental")"

  if [ -z "$last_healthy_build" ]; then
    return 1 # baseline boot is not an OTA boot
  fi

  if [ -n "$current_build" ] && [ "$current_build" != "$last_healthy_build" ]; then
    return 0 # OTA-like boot detected
  fi

  return 1 # normal boot
}

get_effective_boot_timeout() {
  local attempts
  local default_timeout
  local first_timeout
  local ota_timeout
  local ota_rescue_timeout
  local current_build
  local last_healthy_build

  attempts="$(get_state "boot_attempts")"
  case "$attempts" in
    ''|*[!0-9]*) attempts=1 ;;
  esac

  default_timeout="$(get_config BOOT_TIMEOUT_SEC 180)"
  first_timeout="$(get_config FIRST_BOOT_TIMEOUT_SEC 420)"
  ota_timeout="$(get_config OTA_BOOT_TIMEOUT_SEC 900)"
  ota_rescue_timeout="$(get_config OTA_RESCUE_TIMEOUT_SEC 420)"

  current_build="$(getprop ro.system.build.version.incremental 2>/dev/null)"
  last_healthy_build="$(get_state "last_healthy_build_incremental")"

  if [ -z "$last_healthy_build" ]; then
    _set_state_unlocked "boot_mode" "first_baseline"
    echo "$first_timeout"
    return 0
  fi

  if [ -n "$current_build" ] && [ "$current_build" != "$last_healthy_build" ]; then
    _set_state_unlocked "boot_mode" "ota_like"
    if [ "$attempts" -le 1 ]; then
      echo "$ota_timeout"
    else
      echo "$ota_rescue_timeout"
    fi
    return 0
  fi

  _set_state_unlocked "boot_mode" "normal"
  echo "$default_timeout"
}
