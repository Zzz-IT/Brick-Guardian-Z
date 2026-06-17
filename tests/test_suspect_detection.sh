#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/recovery.sh"

echo "[TEST] Running test_suspect_detection..."

# 创建测试模块
mkdir -p "$ADB_ROOT/modules/module_a"
echo "id=module_a" > "$ADB_ROOT/modules/module_a/module.prop"
echo "versionCode=1" >> "$ADB_ROOT/modules/module_a/module.prop"

# 创建自身模块
mkdir -p "$ADB_ROOT/modules/brick-guardian-z"
echo "id=brick-guardian-z" > "$ADB_ROOT/modules/brick-guardian-z/module.prop"

# 准备空的 good_modules.tsv 以便所有模块都被当做"新安装"（嫌疑犯）
touch "$MODDIR/state/good_modules.tsv"

get_suspect_modules

suspect_list="$MODDIR/state/suspect_modules.tsv"

if ! grep -q "module_a" "$suspect_list"; then
  echo "FAIL: 普通新模块未被识别为嫌疑犯！"
  exit 1
fi

if grep -q "brick-guardian-z" "$suspect_list"; then
  echo "FAIL: 自身模块被错误地识别为了嫌疑犯！"
  exit 1
fi

echo "PASS: 嫌疑检测排除了自身"
echo "[TEST] test_suspect_detection 成功！"
exit 0
