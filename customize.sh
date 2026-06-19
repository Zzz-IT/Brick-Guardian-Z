#!/system/bin/sh
# Brick Guardian Z customize.sh

print_modname() {
  ui_print "*******************************"
  ui_print "       Brick Guardian Z        "
  ui_print "*******************************"
}

print_modname

mkdir -p "$MODPATH/state"
mkdir -p "$MODPATH/logs"
mkdir -p "$MODPATH/config"

if [ ! -f "$MODPATH/config/default.conf" ]; then
  cat > "$MODPATH/config/default.conf" <<'EOF'
ENABLED=1

# 启动健康等待
BOOT_TIMEOUT_SEC=180
FIRST_BOOT_TIMEOUT_SEC=420
OTA_BOOT_TIMEOUT_SEC=900
OTA_RESCUE_TIMEOUT_SEC=420

HEALTH_STABLE_SAMPLES=3
HEALTH_SAMPLE_INTERVAL_SEC=5

# 救砖配置
ENABLE_EARLY_RESCUE=1
SKIP_EARLY_RESCUE_ON_OTA=1

# zygote 监控
ENABLE_ZYGOTE_MONITOR=1
ZYGOTE_MONITOR_WINDOW_SEC=60
ZYGOTE_MONITOR_INTERVAL_SEC=5
ZYGOTE_RESTART_THRESHOLD=4
ZYGOTE_MIN_ATTEMPT=2

# 救砖阈值
TARGETED_RECOVERY_THRESHOLD=2
BROAD_RECOVERY_THRESHOLD=4
SELF_DISABLE_THRESHOLD=5

# 兜底开关
ALLOW_BROAD_DISABLE=1
ALLOW_SELF_DISABLE=1
EOF
fi

if [ ! -f "$MODPATH/config/whitelist.conf" ]; then
  cat > "$MODPATH/config/whitelist.conf" <<'EOF'
# 每行一个模块 ID
# 示例:
# zygisk_lsposed
EOF
fi

if [ ! -f "$MODPATH/config/script_whitelist.conf" ]; then
  cat > "$MODPATH/config/script_whitelist.conf" <<'EOF'
# 每行一个脚本相对路径，用于在大范围禁用与精准禁用时排除保护该脚本
# 相对路径格式为: 目录名/文件名
# 示例:
# service.d/keep_service.sh
# post-fs-data.d/keep_early.sh
EOF
fi

# 清理旧版内部恢复/手动日志状态，仅限本模块 state 目录
rm -f "$MODPATH/state/module_restore.queue" \
      "$MODPATH/state/testing_module" \
      "$MODPATH/state/last_restored_module" \
      "$MODPATH/state/failed_script" \
      "$MODPATH/state/testing_script" \
      "$MODPATH/state/script_restore.queue" \
      "$MODPATH/state/script_manual_review.queue" \
      "$MODPATH/state/clear_logs" 2>/dev/null

rm -f "$MODPATH"/state/failed_module.* 2>/dev/null

ui_print "- Brick Guardian Z 已安装完成！"
ui_print "- 重启后，模块将自动在后台守护系统启动。"
