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
_set_state_unlocked "last_healthy_build_incremental" "v1.0.0"
export MOCK_GETPROP_INCREMENTAL="v1.0.0"

# 配置 zygote monitor
cat > "$MODDIR/config/default.conf" <<EOF
ENABLED=1
HEALTH_SAMPLE_INTERVAL_SEC=1
ENABLE_ZYGOTE_MONITOR=1
ZYGOTE_RESTART_THRESHOLD=2
ZYGOTE_MIN_ATTEMPT=2
ZYGOTE_MONITOR_WINDOW_SEC=10
TARGETED_RECOVERY_THRESHOLD=2
BROAD_RECOVERY_THRESHOLD=4
SELF_DISABLE_THRESHOLD=5
EOF

# 运行 service.sh
bash "$MODDIR/service.sh"

# 轮询等待后台进程执行完毕 (最长 5 秒)
for i in {1..50}; do
  lhs="$(get_state "last_health_status")"
  [ -n "$lhs" ] && break
  command sleep 0.1 2>/dev/null || true
done

if [ "$lhs" != "bootloop" ]; then
  echo "FAIL: Zygote 异常未触发 bootloop 流程，当前状态为: $lhs"
  exit 1
fi

echo "PASS: test_service_zygote_unstable_triggers_bootloop 成功"
exit 0
