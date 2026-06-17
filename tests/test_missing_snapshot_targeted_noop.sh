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

rm -f "$MODDIR/state/good_modules.tsv"

mkdir -p "$ADB_ROOT/modules/new_module"
cat > "$ADB_ROOT/modules/new_module/module.prop" <<EOF
id=new_module
versionCode=1
EOF

_set_state_unlocked "boot_attempts" "2"

handle_bootloop

if [ -f "$ADB_ROOT/modules/new_module/disable" ]; then
  echo "FAIL: 缺少健康快照时不应盲目禁用模块"
  exit 1
fi

if grep -q "缺少健康快照" "$MODDIR/state/last_action"; then
  echo "PASS: 缺少健康快照时写入明确 last_action"
else
  echo "FAIL: 缺少健康快照时未写入明确 last_action"
  exit 1
fi

echo "PASS: test_missing_snapshot_targeted_noop 成功！"
exit 0
