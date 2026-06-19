#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/snapshot.sh"
. "$MODDIR/scripts/script_guard.sh"

# 1. 模拟健康快照
mkdir -p "$ADB_ROOT/service.d"
touch "$ADB_ROOT/service.d/s1.sh"
chmod +x "$ADB_ROOT/service.d/s1.sh"
save_good_script_snapshot

# 2. 模拟新加入的嫌疑脚本 (当前可执行)
touch "$ADB_ROOT/service.d/s2.sh"
chmod +x "$ADB_ROOT/service.d/s2.sh"

# 3. 运行 targeted recovery 逻辑
targeted_disable_scripts

# 4. 验证 s2.sh 权限变为不可执行 (0644), 且记录在 state
if ! is_executable "$ADB_ROOT/service.d/s2.sh"; then
  echo "PASS: suspect script disabled"
else
  echo "FAIL: suspect script still executable"
  exit 1
fi

if grep -q "service.d/s2.sh" "$MODDIR/state/guardian_disabled_scripts.list"; then
  echo "PASS: script logged in guardian_disabled_scripts.list"
else
  echo "FAIL: script not logged in disabled list"
  exit 1
fi

# s1 应该仍然是可执行的
if is_executable "$ADB_ROOT/service.d/s1.sh"; then
  echo "PASS: healthy script not touched"
else
  echo "FAIL: healthy script modified"
  exit 1
fi

echo "PASS: test_targeted_script_disable 成功"
exit 0
