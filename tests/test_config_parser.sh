#!/system/bin/sh
# 测试 config parser

. "$(dirname "$0")/mock_env.sh"
setup_env
. "$MODDIR/scripts/lib.sh"

# 准备 default.conf
cat > "$MODDIR/config/default.conf" <<EOF
# 测试注释
BOOT_TIMEOUT_SEC=600
  # 缩进注释
BROAD_RECOVERY_THRESHOLD=6

ENABLED=1
EOF

# 测试是否生效
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

# 测试 fallback
if [ "$(get_config NOT_EXIST 99)" = "99" ]; then
  echo "PASS: fallback 默认值正确生效"
else
  echo "FAIL: fallback 失败"
  exit 1
fi

echo "[TEST] test_config_parser 成功！"
exit 0
