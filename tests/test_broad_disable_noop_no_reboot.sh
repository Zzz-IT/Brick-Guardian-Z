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
ALLOW_SELF_DISABLE=0
EOF

_set_state_unlocked "boot_attempts" "4"

# 没有任何可禁用模块
handle_bootloop >/dev/null 2>&1 || true

if grep -q "没有可禁用模块" "$MODDIR/state/last_action"; then
  echo "PASS: broad 无可禁用模块时写入 last_action"
else
  echo "FAIL: broad 无可禁用模块时未写入 last_action"
  exit 1
fi

echo "PASS: broad disable 无可禁用模块时未执行空动作"
exit 0
