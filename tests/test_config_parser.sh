#!/usr/bin/env bash
set -euo pipefail
# 测试 config parser

. "$(dirname "$0")/mock_env.sh"
setup_env
. "$MODDIR/scripts/lib.sh"

cat > "$MODDIR/config/default.conf" <<EOF_CONF
# 测试注释
BOOT_TIMEOUT_SEC=600
  # 缩进注释
BROAD_RECOVERY_THRESHOLD=6

# 带空格的写法
SELF_DISABLE_THRESHOLD = 8

# 明确不支持 inline comment
INLINE_COMMENT_TEST=600 # bad
ENABLED=1
EOF_CONF

if [ "$(get_config BOOT_TIMEOUT_SEC)" = "600" ]; then
  echo "PASS: BOOT_TIMEOUT_SEC 正确"
else
  echo "FAIL: BOOT_TIMEOUT_SEC 不正确"
  exit 1
fi

if [ "$(get_config BROAD_RECOVERY_THRESHOLD)" = "6" ]; then
  echo "PASS: BROAD_RECOVERY_THRESHOLD 正确"
else
  echo "FAIL: BROAD_RECOVERY_THRESHOLD 不正确"
  exit 1
fi

if [ "$(get_config SELF_DISABLE_THRESHOLD)" = "8" ]; then
  echo "PASS: KEY = VALUE 格式被正确解析"
else
  echo "FAIL: KEY = VALUE 格式解析失败"
  exit 1
fi

if [ "$(get_config NOT_EXIST 99)" = "99" ]; then
  echo "PASS: fallback 默认值正确生效"
else
  echo "FAIL: fallback 失败"
  exit 1
fi

if [ "$(get_config INLINE_COMMENT_TEST)" != "600" ]; then
  echo "PASS: inline comment 未被错误当成纯数值支持"
else
  echo "FAIL: inline comment 被错误解析成纯数值"
  exit 1
fi

echo "[TEST] test_config_parser 成功！"
exit 0
