#!/system/bin/sh
# KSU Safe Guardian post-fs-data.sh

MODDIR=${0%/*}

# 用于早期启动阶段的简单日志记录函数
log_info() {
  echo "[INFO] $1" >> "$MODDIR/logs/guardian.log"
}

# 如果存在待处理的迁移任务，我们几乎不执行任何操作，避免在首次启动时产生误判
if [ -f "$MODDIR/state/migration_pending" ]; then
  # 仅确保旧模块被禁用
  touch /data/adb/modules/magisk-brick-guardian/disable 2>/dev/null
  log_info "存在待处理的迁移任务：post-fs-data 阶段保持静默"
  exit 0
fi

# 在标准模式下，post-fs-data 仅执行极少的检查，将主要工作留给 late_start 服务处理。
log_info "post-fs-data 阶段已执行"
exit 0
