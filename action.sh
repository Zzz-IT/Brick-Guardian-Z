#!/system/bin/sh
# KSU Safe Guardian action.sh

MODDIR=${0%/*}
source "$MODDIR/scripts/lib.sh"

echo "KSU Safe Guardian (安全守护)"
echo ""
echo "状态 (Status):"

# Root 管理器检测
if [ -d "/data/adb/ksu" ]; then
  echo "- Root 管理器: KernelSU"
elif [ -d "/data/adb/ap" ]; then
  echo "- Root 管理器: APatch"
else
  echo "- Root 管理器: Magisk"
fi

if [ -f "$MODDIR/state/migration_pending" ]; then
  echo "- 旧版迁移状态: 待处理 (pending)"
else
  echo "- 旧版迁移状态: 已完成 (completed)"
fi

if [ -f "/data/adb/modules/magisk-brick-guardian/disable" ]; then
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

echo ""
echo "遗留修复 (Legacy repair):"
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
