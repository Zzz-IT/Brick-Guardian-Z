#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/recovery.sh"

mkdir -p "$ADB_ROOT/modules/disabled_mod"
cat > "$ADB_ROOT/modules/disabled_mod/module.prop" <<EOF
id=disabled_mod
versionCode=1
EOF
touch "$ADB_ROOT/modules/disabled_mod/disable"

handle_healthy_boot

if [ -f "$MODDIR/state/module_restore.queue" ]; then
  echo "FAIL: 健康启动不应生成恢复队列"
  exit 1
fi

if [ -f "$MODDIR/state/testing_module" ]; then
  echo "FAIL: 健康启动不应试恢复模块"
  exit 1
fi

echo "PASS: 无自动恢复队列"
exit 0
