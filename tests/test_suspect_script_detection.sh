#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/snapshot.sh"
. "$MODDIR/scripts/script_guard.sh"

# 1. 准备初始状态并建立快照
mkdir -p "$ADB_ROOT/service.d"
mkdir -p "$ADB_ROOT/post-fs-data.d"

# s1: 内容将被修改
echo "s1 old" > "$ADB_ROOT/service.d/s1.sh"
# s2: 状态将被更改为可执行
echo "s2 old" > "$ADB_ROOT/service.d/s2.sh"
# s3: 保持原样不作改动
echo "s3 old" > "$ADB_ROOT/service.d/s3.sh"
chmod +x "$ADB_ROOT/service.d/s3.sh"

save_good_script_snapshot

# 2. 制造变更
# 修改 s1 内容
echo "s1 new" > "$ADB_ROOT/service.d/s1.sh"
# 赋予 s2 可执行权限
chmod +x "$ADB_ROOT/service.d/s2.sh"
# 增加一个全新的脚本 s4
echo "s4 new" > "$ADB_ROOT/post-fs-data.d/s4.sh"
chmod +x "$ADB_ROOT/post-fs-data.d/s4.sh"

# 3. 运行识别嫌疑脚本
get_suspect_scripts

suspects_file="$MODDIR/state/suspect_scripts.tsv"

if [ -f "$suspects_file" ]; then
  echo "PASS: suspect_scripts.tsv file generated"
else
  echo "FAIL: suspect_scripts.tsv not generated"
  exit 1
fi

# 断言 s1.sh (被修改), s2.sh (新启用), s4.sh (全新增加) 为嫌疑脚本，而 s3.sh (未改动) 不是
if grep -q "service.d/s1.sh" "$suspects_file" && \
   grep -q "service.d/s2.sh" "$suspects_file" && \
   grep -q "post-fs-data.d/s4.sh" "$suspects_file"; then
  echo "PASS: correct suspect scripts identified"
else
  echo "FAIL: suspect scripts verification mismatch, list: $(cat "$suspects_file")"
  exit 1
fi

if grep -q "service.d/s3.sh" "$suspects_file"; then
  echo "FAIL: unmodified script s3.sh marked as suspect"
  exit 1
else
  echo "PASS: unmodified script correctly skipped"
fi

echo "PASS: test_suspect_script_detection 成功"
exit 0
