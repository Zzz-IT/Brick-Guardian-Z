#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "    KSU Safe Guardian 测试套件启动    "
echo "======================================"

fail_count=0
pass_count=0

for test_script in "$DIR"/test_*.sh; do
  test_name=$(basename "$test_script")
  echo ">>> 运行: $test_name"
  
  if bash "$test_script"; then
    echo "[$test_name] 结果: \033[32mPASS\033[0m"
    pass_count=$((pass_count + 1))
  else
    echo "[$test_name] 结果: \033[31mFAIL\033[0m"
    fail_count=$((fail_count + 1))
  fi
  echo "--------------------------------------"
done

echo "测试总览: $pass_count 成功, $fail_count 失败"

if [ "$fail_count" -gt 0 ]; then
  exit 1
else
  exit 0
fi
