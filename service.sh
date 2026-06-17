#!/system/bin/sh
# KSU Safe Guardian service.sh

MODDIR=${0%/*}

# 在后台运行守护程序的主逻辑，以免阻塞 service 的执行
(
  # 等待系统达到健康状态
  . "$MODDIR/scripts/healthcheck.sh"
  . "$MODDIR/scripts/lib.sh"
  . "$MODDIR/scripts/state.sh"
  
  [ "$(get_config ENABLED 1)" = "1" ] || exit 0

  timeout="$(get_config NORMAL_BOOT_TIMEOUT_SEC 300)"
  stable="$(get_config HEALTH_STABLE_SAMPLES 3)"
  interval="$(get_config HEALTH_SAMPLE_INTERVAL_SEC 5)"

  # 获取锁，防止和 boot-completed.sh 冲突
  acquire_lock

  if wait_healthy "$timeout" "$stable" "$interval"; then
    # 系统已健康
    log_info "系统健康，开始执行守护任务。"
    
    # 检查是否存在待处理的迁移任务
    if [ -f "$MODDIR/state/migration_pending" ]; then
      log_info "正在执行旧版修复与迁移任务..."
      . "$MODDIR/scripts/legacy_repair.sh"
      run_legacy_repair
      rm -f "$MODDIR/state/migration_pending"
    fi

    # 检查我们是否在恢复某个测试模块/脚本后成功启动
    . "$MODDIR/scripts/recovery.sh"
    mark_testing_success

    # 保存当前健康的模块快照
    if [ -f "$MODDIR/scripts/restore_queue.sh" ]; then
      . "$MODDIR/scripts/restore_queue.sh"
      save_good_snapshot
    fi

    # 尝试恢复队列中的下一项
    if [ -f "$MODDIR/scripts/restore_queue.sh" ]; then
      restore_next_item
    fi

  else
    # 系统未能在超时时间内达到健康状态
    log_error "系统未能达到健康状态，怀疑发生 Bootloop（启动卡死）。"
    
    . "$MODDIR/scripts/recovery.sh"
    handle_bootloop
  fi

  release_lock
) &
