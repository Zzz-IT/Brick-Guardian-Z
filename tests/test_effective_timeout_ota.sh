#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/boot_mode.sh"

# 模拟 OTA 启动
_set_state_unlocked "last_healthy_build_incremental" "v1.0.0"
export MOCK_GETPROP_INCREMENTAL="v1.1.0"

# 尝试次数 = 1
_set_state_unlocked "boot_attempts" "1"
timeout1="$(get_effective_boot_timeout)"

# 尝试次数 = 2 (第二次重启)
_set_state_unlocked "boot_attempts" "2"
timeout2="$(get_effective_boot_timeout)"

if [ "$timeout1" -eq 900 ] && [ "$timeout2" -eq 420 ]; then
  echo "PASS: OTA initial boot timeout is 900, rescue boot timeout is 420"
else
  echo "FAIL: expected 900 and 420, got $timeout1 and $timeout2"
  exit 1
fi

echo "PASS: test_effective_timeout_ota 成功"
exit 0
