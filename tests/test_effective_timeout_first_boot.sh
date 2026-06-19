#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/boot_mode.sh"

# 模拟无历史健康启动记录 (首次开机)
_clear_state_unlocked "last_healthy_build_incremental"
export MOCK_GETPROP_INCREMENTAL="v1.0.0"

timeout="$(get_effective_boot_timeout)"

if [ "$timeout" -eq 420 ]; then
  echo "PASS: first boot timeout correctly set to 420"
else
  echo "FAIL: expected 420, got $timeout"
  exit 1
fi

echo "PASS: test_effective_timeout_first_boot 成功"
exit 0
