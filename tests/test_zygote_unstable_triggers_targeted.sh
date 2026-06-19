#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

# Mock pidof to return a changing PID every time it is called
pidof() {
  local count_file="$MODDIR/state/.pid_count"
  local c
  c="$(cat "$count_file" 2>/dev/null || echo 0)"
  c=$((c + 1))
  echo "$c" > "$count_file"
  echo "$c"
}
export -f pidof

# Set boot_attempts = 2 and simulate normal boot
_set_state_unlocked "boot_attempts" "2"
_set_state_unlocked "last_healthy_build_incremental" "v1.0.0"
export MOCK_GETPROP_INCREMENTAL="v1.0.0"

# Configure Zygote monitoring parameters for quick test execution
cat > "$MODDIR/config/default.conf" <<EOF
ENABLED=1
ENABLE_ZYGOTE_MONITOR=1
ZYGOTE_MONITOR_WINDOW_SEC=5
ZYGOTE_MONITOR_INTERVAL_SEC=1
ZYGOTE_RESTART_THRESHOLD=2
ZYGOTE_MIN_ATTEMPT=2
TARGETED_RECOVERY_THRESHOLD=2
BROAD_RECOVERY_THRESHOLD=4
SELF_DISABLE_THRESHOLD=5
EOF

# Create snapshots to allow targeted recovery to succeed
touch "$MODDIR/state/good_modules.tsv"
touch "$MODDIR/state/good_scripts.tsv"

# Execute service.sh. Since sleep is mocked as no-op, the background task executes synchronously.
output="$(bash "$MODDIR/service.sh" 2>&1)"

# Check if zygote instability was detected and handle_bootloop was triggered
if [ -f "$MODDIR/logs/guardian.log" ] && grep -q "检测到 zygote 不稳定" "$MODDIR/logs/guardian.log"; then
  echo "PASS: Zygote instability detected and early recovery triggered"
else
  echo "FAIL: Zygote instability not found in log, content: $(cat "$MODDIR/logs/guardian.log" 2>/dev/null)"
  exit 1
fi

echo "PASS: test_zygote_unstable_triggers_targeted 成功"
exit 0
