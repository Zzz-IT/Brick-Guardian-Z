#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "    KSU Safe Guardian 测试套件启动    "
echo "======================================"

shopt -s nullglob
tests=( "$DIR"/test_*.sh )

if [ "${#tests[@]}" -eq 0 ]; then
  echo "FAIL: 未找到任何测试脚本"
  exit 1
fi

fail_count=0
pass_count=0

for test_script in "${tests[@]}"; do
  test_name="$(basename "$test_script")"
  echo ">>> 运行: $test_name"

  if [ ! -r "$test_script" ]; then
    echo "[$test_name] 结果: FAIL (not readable)"
    fail_count=$((fail_count + 1))
    echo "--------------------------------------"
    continue
  fi

  if ! grep -q "PASS:" "$test_script"; then
    echo "[$test_name] 结果: FAIL (empty or no assertions)"
    fail_count=$((fail_count + 1))
    echo "--------------------------------------"
    continue
  fi

  if bash "$test_script"; then
    echo "[$test_name] 结果: PASS"
    pass_count=$((pass_count + 1))
  else
    echo "[$test_name] 结果: FAIL"
    fail_count=$((fail_count + 1))
  fi

  echo "--------------------------------------"
done

echo "测试总览: $pass_count 成功, $fail_count 失败"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi

exit 0
