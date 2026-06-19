#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export MSYS=winsymlinks:lnk
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

# 创建一个真正的脚本和一个 symlink 脚本
mkdir -p "$ADB_ROOT/service.d"
echo "echo true" > "$ADB_ROOT/service.d/real_script.sh"
chmod 755 "$ADB_ROOT/service.d/real_script.sh"

ln -sf "$ADB_ROOT/service.d/real_script.sh" "$ADB_ROOT/service.d/symlink_script.sh"

# 1. 验证 save_good_script_snapshot 跳过了 symlink
. "$MODDIR/scripts/snapshot.sh"
save_good_script_snapshot

if [ ! -f "$MODDIR/state/good_scripts.tsv" ]; then
  echo "FAIL: good_scripts.tsv 未生成"
  exit 1
fi

snap_content="$(cat "$MODDIR/state/good_scripts.tsv")"
if echo "$snap_content" | grep -q "symlink_script.sh"; then
  echo "FAIL: 脚本快照录入了软链接"
  exit 1
fi

if ! echo "$snap_content" | grep -q "real_script.sh"; then
  echo "FAIL: 脚本快照未录入真实脚本"
  exit 1
fi

# 2. 验证 broad_disable_scripts 跳过了 symlink
# 移除软链接的安全可执行状态（在 mock 环境下其实是看 mock_exec，但我们直接看 chmod 能否避开软链接）
# 这里我们在 broad 禁用下，真实脚本应该被 0644 禁用，而软链接不应处理。
# 注意：在 mock_env 中，chmod 会更新 .mock_exec/ 下的文件。
# 软链接在 mock_exec 里不应该被去除可执行，更不应该在 list 中。
. "$MODDIR/scripts/script_guard.sh"
broad_disable_scripts

disabled_list="$(cat "$MODDIR/state/guardian_disabled_scripts.list" 2>/dev/null || echo "")"
if echo "$disabled_list" | grep -q "symlink_script.sh"; then
  echo "FAIL: 禁用脚本列表误包含了软链接"
  exit 1
fi

echo "PASS: test_script_symlink_ignored 成功"
exit 0
