#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/mock_env.sh"

echo "Running customize.sh default config test..."

# 运行 customize.sh
export MODPATH="$ADB_ROOT/brick-guardian-z"
mkdir -p "$MODPATH"

# 覆盖 ui_print
ui_print() {
  echo "$1"
}
export -f ui_print

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

echo "PASS: customize.sh 默认配置写入正确 (2/4/5)"
exit 0
