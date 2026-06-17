#!/system/bin/sh
# KSU Safe Guardian service.sh

MODDIR=${0%/*}

# 在后台运行守护程序的主逻辑，以免阻塞 service 的执行
(
  # 等待系统达到健康状态
  . "$MODDIR/scripts/healthcheck.sh"
  . "$MODDIR/scripts/lib.sh"
  . "$MODDIR/scripts/state.sh"
  . "$MODDIR/scripts/recovery.sh"
  
  [ "$(get_config ENABLED 1)" = "1" ] || exit 0

  # 统一慢启动超时时间（不再区分 OTA 与否）
  timeout="$(get_config BOOT_TIMEOUT_SEC 600)"

  stable="$(get_config HEALTH_STABLE_SAMPLES 3)"
  interval="$(get_config HEALTH_SAMPLE_INTERVAL_SEC 5)"

  if wait_healthy "$timeout" "$stable" "$interval"; then
    # 系统已健康，由统一回调函数处理，避免与 boot-completed 冲突
    handle_healthy_boot
  else
    # 系统未能在超时时间内达到健康状态
    log_error "系统未能达到健康状态，怀疑发生 Bootloop（启动卡死）。"
    handle_bootloop
  fi
) &
