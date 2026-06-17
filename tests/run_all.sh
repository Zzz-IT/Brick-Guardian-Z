#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "    Brick Guardian Z 测试套件启动    "
echo "======================================"

shopt -s nullglob
tests=( "$DIR"/test_*.sh )

if [ "${#tests[@]}" -eq 0 ]; then
  echo "FAIL: 未找到任何测试脚本"
  exit 1
fi

fail_count=0
pass_count=0
skip_count=0
ALLOW_TEST_SKIP="${ALLOW_TEST_SKIP:-0}"

for test_path in "${tests[@]}"; do
  test_name="$(basename "$test_path")"
  echo ">>> 运行: $test_name"

  if [ ! -r "$test_path" ]; then
    echo "[$test_name] 结果: FAIL (not readable)"
    fail_count=$((fail_count + 1))
    echo "--------------------------------------"
    continue
  fi

  if ! grep -qE "PASS:|SKIP:" "$test_path"; then
    echo "[$test_name] 结果: FAIL (empty or no assertions)"
    fail_count=$((fail_count + 1))
    echo "--------------------------------------"
    continue
  fi

  local_exit=0
  bash "$test_path" || local_exit=$?

  if [ "$local_exit" -eq 0 ]; then
    echo "[$test_name] 结果: PASS"
    pass_count=$((pass_count + 1))
  elif [ "$local_exit" -eq 2 ]; then
    echo "[$test_name] 结果: SKIP"
    skip_count=$((skip_count + 1))
    if [ "$ALLOW_TEST_SKIP" != "1" ]; then
      echo "[$test_name] 结果: FAIL (skip not allowed)"
      fail_count=$((fail_count + 1))
    fi
  else
    echo "[$test_name] 结果: FAIL"
    fail_count=$((fail_count + 1))
  fi

  echo "--------------------------------------"
done

echo "测试总览: $pass_count 成功, $fail_count 失败, $skip_count 跳过"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi

exit 0
