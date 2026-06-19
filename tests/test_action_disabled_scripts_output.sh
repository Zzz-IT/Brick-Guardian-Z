#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

# Setup states
_set_state_unlocked "last_health_status" "healthy"
_set_state_unlocked "boot_attempts" "0"

# Setup snapshots
echo -e "module_a\t100\thash1\t0" > "$MODDIR/state/good_modules.tsv"
echo "1" > "$MODDIR/state/good_modules_count"

echo -e "service.d/s1.sh\thash2\t1\npost-fs-data.d/s2.sh\thash3\t0" > "$MODDIR/state/good_scripts.tsv"
echo "2" > "$MODDIR/state/good_scripts_count"

# Setup recently disabled scripts
echo "service.d/s_bad.sh" > "$MODDIR/state/guardian_disabled_scripts.list"

# Run action.sh and capture output
output="$(bash "$MODDIR/action.sh" 2>&1 || true)"

# Assertions
if echo "$output" | grep -q "健康快照: 存在 (1 个模块 / 2 个脚本)"; then
  echo "PASS: snapshot counts correctly displayed"
else
  echo "FAIL: snapshot counts not displayed or wrong, output: $output"
  exit 1
fi

if echo "$output" | grep -q "service.d/s_bad.sh"; then
  echo "PASS: recently disabled script listed"
else
  echo "FAIL: recently disabled script missing, output: $output"
  exit 1
fi

echo "PASS: test_action_disabled_scripts_output 成功"
exit 0
