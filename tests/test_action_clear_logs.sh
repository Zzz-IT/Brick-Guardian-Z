#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

echo "old log" > "$MODDIR/logs/guardian.log"
echo "old log 1" > "$MODDIR/logs/guardian.log.1"
touch "$MODDIR/state/clear_logs"

bash "$MODDIR/action.sh" >/dev/null

if grep -q "日志已由用户手动清除" "$MODDIR/logs/guardian.log"; then
  echo "PASS: action 清除日志成功"
else
  echo "FAIL: action 未清除日志"
  exit 1
fi

if [ -f "$MODDIR/state/clear_logs" ]; then
  echo "FAIL: clear_logs 标记未清除"
  exit 1
fi

echo "PASS: test_action_clear_logs 成功"
exit 0
