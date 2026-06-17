#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/recovery.sh"

cat > "$MODDIR/config/default.conf" <<EOF
TARGETED_RECOVERY_THRESHOLD=2
BROAD_RECOVERY_THRESHOLD=4
SELF_DISABLE_THRESHOLD=5
ALLOW_BROAD_DISABLE=1
ALLOW_SELF_DISABLE=1
EOF

: > "$MODDIR/state/good_modules.tsv"

test_id="new_module"
mkdir -p "$ADB_ROOT/modules/$test_id"
cat > "$ADB_ROOT/modules/$test_id/module.prop" <<EOF
id=$test_id
versionCode=1
EOF

_set_state_unlocked "boot_attempts" "2"

handle_bootloop

if [ -f "$ADB_ROOT/modules/$test_id/disable" ]; then
  echo "PASS: targeted disable 禁用了新安装嫌疑模块"
else
  echo "FAIL: targeted disable 未禁用嫌疑模块"
  exit 1
fi

if grep -Fxq "$test_id" "$MODDIR/state/guardian_disabled_modules.list"; then
  echo "PASS: 已记录异常禁用模块"
else
  echo "FAIL: 未记录异常禁用模块"
  exit 1
fi

echo "PASS: test_targeted_disable 成功！"
exit 0
