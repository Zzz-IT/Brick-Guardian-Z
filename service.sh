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

  curr_ver="$(getprop ro.system.build.version.incremental)"
  prev_ver="$(get_state "last_system_version")"
  timeout=""

  if [ -n "$prev_ver" ] && [ "$curr_ver" != "$prev_ver" ]; then
    log_info "检测到系统版本更新 (OTA)。应用较长的超时时间..."
    timeout="$(get_config OTA_BOOT_TIMEOUT_SEC 900)"
  else
    timeout="$(get_config NORMAL_BOOT_TIMEOUT_SEC 300)"
  fi

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
