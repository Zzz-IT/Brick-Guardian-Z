#!/system/bin/sh
# KSU Safe Guardian customize.sh

ui_print "- 正在安装 KSU Safe Guardian..."

# 确保模块基础目录结构存在
mkdir -p "$MODPATH/state"
mkdir -p "$MODPATH/logs"
mkdir -p "$MODPATH/quarantine"
mkdir -p "$MODPATH/config"

# 如果配置文件不存在，写入默认配置
if [ ! -f "$MODPATH/config/default.conf" ]; then
  cat <<EOF > "$MODPATH/config/default.conf"
ENABLED=1
MIGRATE_LEGACY=1
DISABLE_LEGACY_MODULE=1
IMPORT_LEGACY_WHITELIST=1
IMPORT_LEGACY_GOOD_MODULES=1
AUTO_RESTORE_DISABLED_MODULES=1
MODULE_RESTORE_BATCH_SIZE=1
AUTO_RESTORE_LATE_GLOBAL_SCRIPTS=1
AUTO_RESTORE_EARLY_GLOBAL_SCRIPTS=0
AUTO_QUARANTINE_MODULES_UPDATE_BAK=1
NORMAL_BOOT_TIMEOUT_SEC=300
OTA_BOOT_TIMEOUT_SEC=900
HEALTH_STABLE_SAMPLES=3
HEALTH_SAMPLE_INTERVAL_SEC=5
TARGETED_RECOVERY_THRESHOLD=3
BROAD_RECOVERY_THRESHOLD=5
SELF_DISABLE_THRESHOLD=6
ALLOW_BROAD_DISABLE=1
ALLOW_SELF_DISABLE=1
ALLOW_PACKAGE_RESTRICTION_RESET=0
ALLOW_GLOBAL_CHMOD_000=0
ALLOW_MODULES_UPDATE_INTERCEPT=0
EOF
fi

# 为模块及其脚本设置合适的权限
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755

# 自动接管旧模块
legacy="/data/adb/modules/magisk-brick-guardian"
if [ -d "$legacy" ]; then
  ui_print "- 检测到旧版 magisk-brick-guardian 模块"
  
  # 自动禁用旧模块
  touch "$legacy/disable"
  ui_print "  -> 已禁用旧模块"

  # 将旧版配置归档到隔离区
  mkdir -p "$MODPATH/quarantine/legacy"
  [ -f "$legacy/good_modules.list" ] && cp -af "$legacy/good_modules.list" "$MODPATH/quarantine/legacy/" 2>/dev/null
  [ -f "$legacy/suspect_modules.log" ] && cp -af "$legacy/suspect_modules.log" "$MODPATH/quarantine/legacy/" 2>/dev/null
  [ -f "$legacy/白名单.conf" ] && cp -af "$legacy/白名单.conf" "$MODPATH/quarantine/legacy/whitelist.conf" 2>/dev/null
  cp -af "$legacy"/*.log "$MODPATH/quarantine/legacy/" 2>/dev/null
  
  ui_print "  -> 已归档旧版状态与配置数据"
  
  # 标记 MIGRATION_PENDING=1（等待下次启动执行迁移逻辑）
  echo "1" > "$MODPATH/state/migration_pending"
  ui_print "- 迁移准备完成，将在下次启动时执行"
fi

ui_print "- KSU Safe Guardian 安装完成"
