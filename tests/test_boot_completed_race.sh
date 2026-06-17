#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/recovery.sh"

# Mock reboot
reboot() {
  echo "MOCK_REBOOT"
}
export -f reboot

echo "[TEST] Running test_boot_completed_race..."

boot_id="mock-boot-id-001"

# 模拟 boot-completed 先打入标记
_set_state_unlocked "boot_completed_seen_$boot_id" "1"

# 触发 service timeout 的 handle_bootloop
handle_bootloop

# 验证不会生成 decision_$boot_id=bootloop
decision="$(get_state "decision_$boot_id")"
if [ "$decision" = "bootloop" ]; then
  echo "FAIL: boot_completed_seen 标记存在时，handle_bootloop 依然写入了 bootloop 决策！"
  exit 1
fi

echo "PASS: 并发竞态防御成功"
echo "[TEST] test_boot_completed_race 成功！"
exit 0
