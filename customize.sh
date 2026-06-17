#!/system/bin/sh
# KSU Safe Guardian customize.sh

# UI Print 封装
print_modname() {
  ui_print "*******************************"
  ui_print "       KSU Safe Guardian       "
  ui_print "*******************************"
}

print_modname

# 初始化基础目录
mkdir -p "$MODPATH/state"
mkdir -p "$MODPATH/logs"
mkdir -p "$MODPATH/config"
mkdir -p "$MODPATH/quarantine"

# 仅作为保险，如果检测到旧模块正在运行，临时禁用它，但不作为迁移的必须条件
legacy="/data/adb/modules/magisk-brick-guardian"
if [ -d "$legacy" ]; then
  ui_print "- 检测到旧版 magisk-brick-guardian 模块！"
  ui_print "- 为防止冲突，正在临时禁用旧模块..."
  touch "$legacy/disable" 2>/dev/null
fi

# 无论如何，都写入第一次启动修复标志，用于扫描并隔离遗留的拦截数据
echo "1" > "$MODPATH/state/first_run_repair_pending"

# 生成默认配置
if [ ! -f "/data/adb/modules/ksu-safe-guardian/config/default.conf" ]; then
  cp "$MODPATH/config/default.conf" "$MODPATH/config/default.conf.new" 2>/dev/null
fi

ui_print "- KSU Safe Guardian 已安装完成！"
ui_print "- 重启后，模块将自动在后台守护系统启动。"
