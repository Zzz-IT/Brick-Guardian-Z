#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/boot_mode.sh"

# 模拟不是首次启动，记录上一次健康的 incremental
_set_state_unlocked "last_healthy_build_incremental" "v1.0.0"
export MOCK_GETPROP_INCREMENTAL="v1.0.0"

_set_state_unlocked "boot_attempts" "1"

timeout="$(get_effective_boot_timeout)"

if [ "$timeout" -eq 180 ]; then
  echo "PASS: normal boot timeout correctly set to 180"
else
  echo "FAIL: expected 180, got $timeout"
  exit 1
fi

echo "PASS: test_effective_timeout_normal 成功"
exit 0
