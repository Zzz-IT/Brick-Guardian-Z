#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/boot_mode.sh"

# 配置超时参数为非法字符
cat > "$MODDIR/config/default.conf" <<EOF
ENABLED=1
BOOT_TIMEOUT_SEC=abc
FIRST_BOOT_TIMEOUT_SEC=0
OTA_BOOT_TIMEOUT_SEC=xyz
OTA_RESCUE_TIMEOUT_SEC=
EOF

_set_state_unlocked "boot_attempts" "1"

# 验证 get_effective_boot_timeout 能成功 fallback
# 首次启动基线时，FIRST_BOOT_TIMEOUT_SEC=0 应 fallback 为 420
rm -f "$MODDIR/state/last_healthy_build_incremental"
timeout="$(get_effective_boot_timeout)"
if [ "$timeout" != "420" ]; then
  echo "FAIL: 首次启动基线 timeout 非法值 fallback 失败，预期 420，实际 $timeout"
  exit 1
fi

# 正常启动时，BOOT_TIMEOUT_SEC=abc 应 fallback 为 180
_set_state_unlocked "last_healthy_build_incremental" "v1.0.0"
export MOCK_GETPROP_INCREMENTAL="v1.0.0"
timeout="$(get_effective_boot_timeout)"
if [ "$timeout" != "180" ]; then
  echo "FAIL: 正常启动 timeout 非法值 fallback 失败，预期 180，实际 $timeout"
  exit 1
fi

echo "PASS: test_timeout_invalid_config 成功"
exit 0
