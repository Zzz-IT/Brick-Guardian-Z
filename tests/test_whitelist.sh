#!/usr/bin/env bash
set -euo pipefail
# 测试 whitelist parser

. "$(dirname "$0")/mock_env.sh"
setup_env
. "$MODDIR/scripts/lib.sh"

cat > "$MODDIR/config/whitelist.conf" <<EOF_CONF
# 这是一个注释
 
  # 空白和注释
  
module_a
 module_b 
bad/module
123bad
EOF_CONF

if is_whitelisted "module_a"; then
  echo "PASS: module_a 被正确识别"
else
  echo "FAIL: module_a 未被识别"
  exit 1
fi

if is_whitelisted "module_b"; then
  echo "PASS: module_b 前后空格被正确 trim"
else
  echo "FAIL: module_b 前后空格未被正确处理"
  exit 1
fi

if is_whitelisted "# 这是一个注释"; then
  echo "FAIL: 注释被错误识别为白名单"
  exit 1
else
  echo "PASS: 注释被正确忽略"
fi

if is_whitelisted "module_c"; then
  echo "FAIL: 未配置的 module_c 被误认"
  exit 1
else
  echo "PASS: 未配置模块不会被误认"
fi

if is_whitelisted "bad/module"; then
  echo "FAIL: 非法模块 ID bad/module 被误认为白名单"
  exit 1
else
  echo "PASS: 非法模块 ID bad/module 被正确拒绝"
fi

if is_whitelisted "123bad"; then
  echo "FAIL: 非法模块 ID 123bad 被误认为白名单"
  exit 1
else
  echo "PASS: 非法模块 ID 123bad 被正确拒绝"
fi

echo "[TEST] test_whitelist 成功！"
exit 0
