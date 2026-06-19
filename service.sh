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

  # 获取有效超时时间与健康状态稳定样本参数
  timeout="$(get_effective_boot_timeout)"
  stable="$(get_config HEALTH_STABLE_SAMPLES 3)"
  interval="$(get_config HEALTH_SAMPLE_INTERVAL_SEC 5)"

  # 如果 zygote 反复重启，提前进入救砖判定
  if monitor_zygote_unstable; then
    log_error "检测到 zygote 反复重启且非 OTA 启动，提前进入救砖判定。"
    handle_bootloop
    exit 0
  fi

  if wait_healthy "$timeout" "$stable" "$interval"; then
    # 系统已健康，由统一回调函数处理，避免与 boot-completed 冲突
    handle_healthy_boot
  else
    # 系统未能在超时时间内达到健康状态
    log_error "系统未能达到健康状态，怀疑发生 Bootloop（启动卡死）。"
    handle_bootloop
  fi
) &
