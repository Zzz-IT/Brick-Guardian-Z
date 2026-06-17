#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

output="$(bash "$MODDIR/action.sh" 2>&1 || true)"

for bad in \
  "恢复队列" \
  "待恢复" \
  "试恢复" \
  "恢复成功" \
  "恢复失败" \
  "testing_module" \
  "module_restore.queue"; do
  if echo "$output" | grep -q "$bad"; then
    echo "FAIL: Action 出现恢复相关文案: $bad"
    exit 1
  fi
done

echo "PASS: Action 无恢复相关文案"
exit 0
