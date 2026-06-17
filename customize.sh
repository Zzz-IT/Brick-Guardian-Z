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
BOOT_TIMEOUT_SEC=600
HEALTH_STABLE_SAMPLES=3
HEALTH_SAMPLE_INTERVAL_SEC=5

# 救砖阈值
TARGETED_RECOVERY_THRESHOLD=2
BROAD_RECOVERY_THRESHOLD=4
SELF_DISABLE_THRESHOLD=5

# 自动恢复守护禁用过的模块
AUTO_RESTORE_DISABLED_MODULES=1

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

ui_print "- Brick Guardian Z 已安装完成！"
ui_print "- 重启后，模块将自动在后台守护系统启动。"
