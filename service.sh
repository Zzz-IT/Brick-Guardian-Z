#!/system/bin/sh
# Brick Guardian Z service.sh

MODDIR=${0%/*}

# 在后台运行守护程序的主逻辑，以免阻塞 service 的执行
(
  # 等待系统达到健康状态
  . "$MODDIR/scripts/healthcheck.sh"
  . "$MODDIR/scripts/lib.sh"
  . "$MODDIR/scripts/state.sh"
  . "$MODDIR/scripts/recovery.sh"
  . "$MODDIR/scripts/boot_mode.sh"
  . "$MODDIR/scripts/zygote_monitor.sh"
  
  [ "$(get_config ENABLED 1)" = "1" ] || exit 0

  boot_id="$(cat "${MOCK_BOOT_ID_FILE:-/proc/sys/kernel/random/boot_id}" 2>/dev/null)"
  [ -n "$boot_id" ] && _set_state_unlocked "service_seen_$boot_id" "1"

  # 获取有效超时时间与健康状态稳定样本参数
  timeout="$(normalize_positive_int "$(get_effective_boot_timeout)" 180)"
  stable="$(normalize_positive_int "$(get_config HEALTH_STABLE_SAMPLES 3)" 3)"
  interval="$(normalize_positive_int "$(get_config HEALTH_SAMPLE_INTERVAL_SEC 5)" 5)"

  wait_healthy_or_zygote_unstable "$timeout" "$stable" "$interval"
  result="$?"

  case "$result" in
    0)
      handle_healthy_boot
      ;;
    2)
      log_error "检测到 zygote 不稳定，提前进入救砖判定。"
      _set_state_unlocked "last_action" "检测到 zygote 不稳定，提前进入救砖判定。"
      handle_bootloop
      ;;
    *)
      log_error "系统未能达到健康状态，怀疑发生 Bootloop（启动卡死）。"
      handle_bootloop
      ;;
  esac
) &
