#!/usr/bin/env bash
set -euo pipefail
# 测试 whitelist parser

. "$(dirname "$0")/mock_env.sh"
setup_env
. "$MODDIR/scripts/lib.sh"

# 准备 whitelist
cat > "$MODDIR/config/whitelist.conf" <<EOF
# 这是一个注释
 
  # 空白和注释
  
module_a
 module_b 
EOF

# 测试是否生效
if is_whitelisted "module_a"; then
  echo "PASS: module_a 被正确识别"
else
  echo "FAIL: module_a 未被识别"
  exit 1
fi

# 测试注释是否被忽略
if is_whitelisted "# 这是一个注释"; then
  echo "FAIL: 注释被错误识别为白名单"
  exit 1
fi

if is_whitelisted "module_c"; then
  echo "FAIL: 未配置的 module_c 被误认"
  exit 1
fi

echo "[TEST] test_whitelist 成功！"
exit 0
