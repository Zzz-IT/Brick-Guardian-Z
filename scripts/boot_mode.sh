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

get_boot_mode() {
  local current_build
  local last_healthy_build

  current_build="$(getprop ro.system.build.version.incremental 2>/dev/null)"
  last_healthy_build="$(get_state "last_healthy_build_incremental")"

  if [ -z "$last_healthy_build" ]; then
    echo "first_baseline"
    return 0
  fi

  if [ -n "$current_build" ] && [ "$current_build" != "$last_healthy_build" ]; then
    echo "ota_like"
    return 0
  fi

  echo "normal"
}

is_ota_like_boot() {
  [ "$(get_boot_mode)" = "ota_like" ]
}

get_effective_boot_timeout() {
  local attempts
  local mode

  attempts="$(get_state "boot_attempts")"
  attempts="$(normalize_positive_int "$attempts" 1)"

  mode="$(get_boot_mode)"

  case "$mode" in
    first_baseline)
      _set_state_unlocked "boot_mode" "first_baseline"
      normalize_positive_int "$(get_config FIRST_BOOT_TIMEOUT_SEC 420)" 420
      ;;
    ota_like)
      _set_state_unlocked "boot_mode" "ota_like"
      if [ "$attempts" -le 1 ]; then
        normalize_positive_int "$(get_config OTA_BOOT_TIMEOUT_SEC 900)" 900
      else
        normalize_positive_int "$(get_config OTA_RESCUE_TIMEOUT_SEC 420)" 420
      fi
      ;;
    *)
      _set_state_unlocked "boot_mode" "normal"
      normalize_positive_int "$(get_config BOOT_TIMEOUT_SEC 180)" 180
      ;;
  esac
}
