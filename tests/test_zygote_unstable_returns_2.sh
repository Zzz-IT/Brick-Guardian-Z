#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

# Mock pidof to return changing PIDs to simulate zygote instability
pidof() {
  case "$1" in
    zygote64)
      # 使用文件来跨进程/跨调用追踪计数
      local count_file="$MODDIR/state/.zygote_counter"
      local c
      c="$(cat "$count_file" 2>/dev/null || echo 0)"
      c=$((c + 1))
      echo "$c" > "$count_file"
      echo "$c"
      ;;
    zygote)
      echo ""
      ;;
    system_server)
      return 1
      ;;
  esac
}
export -f pidof

_set_state_unlocked "boot_attempts" "2"
_set_state_unlocked "boot_mode" "normal"

# 配置 zygote monitor
cat > "$MODDIR/config/default.conf" <<EOF
ENABLED=1
HEALTH_SAMPLE_INTERVAL_SEC=1
ENABLE_ZYGOTE_MONITOR=1
ZYGOTE_RESTART_THRESHOLD=2
ZYGOTE_MIN_ATTEMPT=2
ZYGOTE_MONITOR_WINDOW_SEC=10
EOF

. "$MODDIR/scripts/zygote_monitor.sh"
. "$MODDIR/scripts/healthcheck.sh"

# 运行 wait_healthy_or_zygote_unstable
# timeout=10, stable_samples=3, interval=1
result=0
wait_healthy_or_zygote_unstable 10 3 1 || result=$?

if [ "$result" -ne 2 ]; then
  echo "FAIL: wait_healthy_or_zygote_unstable 应该返回 2 (zygote unstable)，实际返回 $result"
  exit 1
fi

echo "PASS: test_zygote_unstable_returns_2 成功"
exit 0
