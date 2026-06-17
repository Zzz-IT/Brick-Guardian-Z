#!/system/bin/sh
# KSU Safe Guardian service.sh

MODDIR=${0%/*}

# 在后台运行守护程序的主逻辑，以免阻塞 service 的执行
(
  # 等待系统达到健康状态
  source "$MODDIR/scripts/healthcheck.sh"
  
  if wait_healthy 300; then
    # 系统已健康
    source "$MODDIR/scripts/lib.sh"
    log_info "系统健康，开始执行守护任务。"
    
    # 检查是否存在待处理的迁移任务
    if [ -f "$MODDIR/state/migration_pending" ]; then
      log_info "正在执行旧版修复与迁移任务..."
      source "$MODDIR/scripts/legacy_repair.sh"
      run_legacy_repair
      rm -f "$MODDIR/state/migration_pending"
    fi

    # 检查我们是否在恢复某个测试模块/脚本后成功启动
    source "$MODDIR/scripts/recovery.sh"
    mark_testing_success

    # 尝试恢复队列中的下一项
    source "$MODDIR/scripts/restore_queue.sh"
    restore_next_item

  else
    # 系统未能在超时时间内达到健康状态
    source "$MODDIR/scripts/lib.sh"
    log_error "系统未能达到健康状态，怀疑发生 Bootloop（启动卡死）。"
    
    source "$MODDIR/scripts/recovery.sh"
    handle_bootloop
  fi
) &
