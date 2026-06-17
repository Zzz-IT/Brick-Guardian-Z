#!/system/bin/sh
# Brick Guardian Z action.sh

MODDIR=${0%/*}
. "$MODDIR/scripts/lib.sh"

root_manager="Magisk"
if [ -d "$ADB_ROOT/ksu" ]; then
  root_manager="KernelSU"
elif [ -d "$ADB_ROOT/ap" ]; then
  root_manager="APatch"
fi

echo "Brick Guardian Z"
echo ""

echo "状态概览:"
echo "- Root 管理器: $root_manager"

health="未知"
if [ -f "$MODDIR/state/last_health_status" ]; then
  raw_health="$(cat "$MODDIR/state/last_health_status" 2>/dev/null)"
  case "$raw_health" in
    healthy) health="正常" ;;
    bootloop) health="异常" ;;
    *) health="未知" ;;
  esac
fi
echo "- 上次启动状态: $health"

if [ -f "$MODDIR/state/good_modules.tsv" ]; then
  snap_count="$(cat "$MODDIR/state/good_modules_count" 2>/dev/null)"
  case "$snap_count" in
    ''|*[!0-9]*) snap_count="$(wc -l < "$MODDIR/state/good_modules.tsv" 2>/dev/null || echo 0)" ;;
  esac
  echo "- 健康快照: 存在 (${snap_count:-0} 个模块)"
elif [ "$(cat "$MODDIR/state/last_health_status" 2>/dev/null)" = "healthy" ]; then
  echo "- 健康快照: 异常"
else
  echo "- 健康快照: 未生成"
fi

if [ -f "$MODDIR/state/boot_attempts" ]; then
  echo "- 异常启动次数: $(cat "$MODDIR/state/boot_attempts" 2>/dev/null)"
else
  echo "- 异常启动次数: 0"
fi

if [ -f "$MODDIR/state/last_action" ]; then
  echo "- 最后动作: $(cat "$MODDIR/state/last_action" 2>/dev/null)"
else
  echo "- 最后动作: 无"
fi

echo ""
echo "模块保护:"

if [ -f "$MODDIR/state/rescue_count" ]; then
  echo "- 已救砖次数: $(cat "$MODDIR/state/rescue_count" 2>/dev/null)"
else
  echo "- 已救砖次数: 0"
fi

echo "- 白名单模块:"
whitelist_conf="$MODDIR/config/whitelist.conf"
whitelist_printed=0
if [ -f "$whitelist_conf" ]; then
  while IFS= read -r line; do
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$line" ] || continue
    case "$line" in \#*) continue ;; esac
    if is_valid_module_id "$line"; then
      echo "   $line"
      whitelist_printed=1
    fi
  done < "$whitelist_conf"
fi
if [ "$whitelist_printed" = "0" ]; then
  echo "   无"
fi

echo "- 最近异常禁用模块:"
tmp_disabled="$MODDIR/state/.action_disabled.tmp.$$"
: > "$tmp_disabled"

if [ -f "$MODDIR/state/guardian_disabled_modules.list" ]; then
  awk 'NF && !seen[$0]++ {print $0}' "$MODDIR/state/guardian_disabled_modules.list" 2>/dev/null \
    | tail -n 10 > "$tmp_disabled"
fi

printed=0
if [ -s "$tmp_disabled" ]; then
  while IFS= read -r id; do
    if is_valid_module_id "$id"; then
      echo "   $id"
      printed=1
    fi
  done < "$tmp_disabled"
fi

if [ "$printed" = "0" ]; then
  echo "   无"
fi

rm -f "$tmp_disabled"

echo ""
echo "最近日志:"
if [ -f "$MODDIR/logs/guardian.log" ]; then
  tail -n 20 "$MODDIR/logs/guardian.log"
else
  echo "暂无日志"
fi

case "$root_manager" in
  KernelSU|APatch)
    sleep 10
    ;;
esac

exit 0
