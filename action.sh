#!/system/bin/sh
# KSU Safe Guardian action.sh

MODDIR=${0%/*}
. "$MODDIR/scripts/lib.sh"

echo "KSU Safe Guardian (安全守护)"
echo ""
echo "状态 (Status):"

# Root 管理器检测
if [ -d "$ADB_ROOT/ksu" ]; then
  echo "- Root 管理器: KernelSU"
elif [ -d "$ADB_ROOT/ap" ]; then
  echo "- Root 管理器: APatch"
else
  echo "- Root 管理器: Magisk"
fi

if [ -f "$MODDIR/state/first_run_repair_pending" ]; then
  echo "- 首次开机清理状态: 待处理 (pending)"
else
  echo "- 首次开机清理状态: 已完成 (completed)"
fi

if [ -f "$ADB_ROOT/modules/magisk-brick-guardian/disable" ]; then
  echo "- 旧版遗留模块: 已禁用 (disabled)"
else
  echo "- 旧版遗留模块: 未找到或正处于激活状态"
fi

# 基本健康与测试统计
if [ -f "$MODDIR/state/last_health_status" ]; then
  echo "- 上次启动健康度: $(cat "$MODDIR/state/last_health_status")"
else
  echo "- 上次启动健康度: 未知 (unknown)"
fi

if [ -f "$MODDIR/state/boot_attempts" ]; then
  echo "- 当前未健康启动次数 (boot_attempts): $(cat "$MODDIR/state/boot_attempts")"
else
  echo "- 当前未健康启动次数 (boot_attempts): 0"
fi

echo ""
echo "自动修复与接管队列 (Repair queue):"
if [ -f "$MODDIR/state/quarantined_modules_update" ]; then
  echo "- modules_update.bak (更新拦截残留): 已隔离"
else
  echo "- modules_update.bak (更新拦截残留): 无"
fi

if [ -f "$MODDIR/state/module_restore.queue" ]; then
  q_len=$(wc -l < "$MODDIR/state/module_restore.queue")
  echo "- 队列中等待恢复的模块数: $q_len"
else
  echo "- 队列中等待恢复的模块数: 0"
fi

if [ -f "$MODDIR/state/script_restore.queue" ]; then
  s_len=$(wc -l < "$MODDIR/state/script_restore.queue")
  echo "- 队列中等待恢复的脚本数: $s_len"
else
  echo "- 队列中等待恢复的脚本数: 0"
fi

echo "- package restrictions (应用冻结限制): 无法验证/无备份"

echo ""
echo "当前恢复测试项 (Current testing):"
if [ -f "$MODDIR/state/testing_module" ]; then
  echo "- 测试中模块: $(cat "$MODDIR/state/testing_module")"
else
  echo "- 测试中模块: 无"
fi

if [ -f "$MODDIR/state/testing_script" ]; then
  echo "- 测试中脚本: $(cat "$MODDIR/state/testing_script")"
else
  echo "- 测试中脚本: 无"
fi

echo ""
if [ -f "$MODDIR/state/last_action" ]; then
  echo "最后执行的动作 (Last action):"
  cat "$MODDIR/state/last_action"
else
  echo "最后执行的动作 (Last action): 无"
fi

echo ""
echo "白名单状态 (Whitelist):"
whitelist_conf="$MODDIR/config/whitelist.conf"
if [ -f "$whitelist_conf" ]; then
  whitelist_count=$(awk '/^[[:space:]]*$/ {next} /^[[:space:]]*#/ {next} {count++} END {print count+0}' "$whitelist_conf")
  echo "- 路径: $whitelist_conf"
  echo "- 数量: $whitelist_count 个"
else
  echo "- 数量: 0 (未找到配置)"
fi

echo ""
echo "=============================="
echo "    最近运行日志 (Last Logs)  "
echo "=============================="
if [ -f "$MODDIR/logs/guardian.log" ]; then
  tail -n 20 "$MODDIR/logs/guardian.log"
else
  echo "暂无日志"
fi
