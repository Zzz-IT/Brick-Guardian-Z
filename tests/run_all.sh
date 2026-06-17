#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "    Brick Guardian Z 测试套件启动    "
echo "======================================"

shopt -s nullglob
TESTS=(
  "test_basic_recovery.sh"
  "test_testing_module_validation.sh"
  "test_testing_module_rollback.sh"
  "test_suspect_detection.sh"
  "test_broad_disable_respects_whitelist.sh"
  "test_self_disable.sh"
  "test_concurrent_lock.sh"
  "test_lock_timeout_override.sh"
  "test_customize_defaults.sh"
  "test_action_output.sh"
)

if [ "${#TESTS[@]}" -eq 0 ]; then
  echo "FAIL: 未找到任何测试脚本"
  exit 1
fi

fail_count=0
pass_count=0
skip_count=0

for test_script in "${TESTS[@]}"; do
  test_path="$DIR/$test_script"
  test_name="$(basename "$test_script")"
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
  bash "$test_script" || local_exit=$?

  if [ "$local_exit" -eq 0 ]; then
    echo "[$test_name] 结果: PASS"
    pass_count=$((pass_count + 1))
  elif [ "$local_exit" -eq 2 ]; then
    echo "[$test_name] 结果: SKIP"
    skip_count=$((skip_count + 1))
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
