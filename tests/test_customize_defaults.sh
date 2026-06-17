#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

echo "Running customize.sh default config test..."

export MODPATH="$MODDIR"

ui_print() {
  echo "$1"
}
export -f ui_print

rm -f "$MODPATH/config/default.conf"
bash "$MODDIR/customize.sh" > /dev/null

conf="$MODPATH/config/default.conf"
if [ ! -f "$conf" ]; then
  echo "FAIL: default.conf 未生成"
  exit 1
fi

t_target="$(grep '^TARGETED_RECOVERY_THRESHOLD=' "$conf" | cut -d= -f2)"
t_broad="$(grep '^BROAD_RECOVERY_THRESHOLD=' "$conf" | cut -d= -f2)"
t_self="$(grep '^SELF_DISABLE_THRESHOLD=' "$conf" | cut -d= -f2)"

if [ "$t_target" != "2" ] || [ "$t_broad" != "4" ] || [ "$t_self" != "5" ]; then
  echo "FAIL: 默认阈值不匹配 2/4/5 (得到 $t_target/$t_broad/$t_self)"
  exit 1
fi

if grep -qE 'magisk-brick-guardian|first_run_repair|modules_update|quarantine' "$MODDIR/customize.sh"; then
  echo "FAIL: customize.sh 仍包含旧版处理逻辑"
  exit 1
fi

echo "PASS: customize.sh 默认配置写入正确且无旧版逻辑"
exit 0
