#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

echo "Running action.sh pure output test..."

output="$(bash "$MODDIR/action.sh" 2>&1 || true)"

forbidden=(
  "首次开机清理"
  "旧版遗留"
  "modules_update.bak"
  "接管队列"
  "package restrictions"
  "全局脚本"
)

for f in "${forbidden[@]}"; do
  if echo "$output" | grep -q "$f"; then
    echo "FAIL: action.sh 包含了不该出现的文案: $f"
    exit 1
  fi
done

required=(
  "Brick Guardian Z"
  "状态概览"
  "模块保护"
  "已救砖次数"
  "白名单模块"
  "最近异常禁用模块"
  "最近日志"
  "手动清除日志"
)

for r in "${required[@]}"; do
  if ! echo "$output" | grep -q "$r"; then
    echo "FAIL: action.sh 缺少必须的核心文案: $r"
    exit 1
  fi
done

echo "PASS: action.sh 纯净版输出检测通过"
exit 0
