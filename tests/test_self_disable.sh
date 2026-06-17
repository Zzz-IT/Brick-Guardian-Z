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
ALLOW_SELF_DISABLE=1
ALLOW_BROAD_DISABLE=1
EOF

_set_state_unlocked "boot_attempts" "5"

handle_bootloop

if [ -f "$MODDIR/disable" ]; then
  echo "PASS: 达到 self-disable 阈值后模块自我禁用"
else
  echo "FAIL: 未触发自我禁用"
  exit 1
fi

echo "PASS: test_self_disable 成功"
exit 0
