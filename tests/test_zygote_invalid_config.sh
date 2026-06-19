#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/zygote_monitor.sh"

# 配置 zygote 参数为非法字符
cat > "$MODDIR/config/default.conf" <<EOF
ENABLED=1
ENABLE_ZYGOTE_MONITOR=1
ZYGOTE_MIN_ATTEMPT=abc
ZYGOTE_RESTART_THRESHOLD=xyz
ZYGOTE_MONITOR_WINDOW_SEC=non_numeric
EOF

_set_state_unlocked "boot_attempts" "2"
_set_state_unlocked "boot_mode" "normal"

# 验证 should_monitor_zygote 会不会因为非法值报错崩溃，且使用默认 fallback 值
# ZYGOTE_MIN_ATTEMPT 默认值为 2
if ! should_monitor_zygote; then
  echo "FAIL: zygote 监控由于非法数值导致判定逻辑失败"
  exit 1
fi

echo "PASS: test_zygote_invalid_config 成功"
exit 0
