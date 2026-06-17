#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"

echo "[TEST] Running test_state_lock..."

# 测试 1: 正常加锁和释放
acquire_lock
if [ ! -d "$MODDIR/state/.lock" ]; then
  echo "FAIL: 正常加锁失败"
  exit 1
fi
release_lock
if [ -d "$MODDIR/state/.lock" ]; then
  echo "FAIL: 正常释放锁失败"
  exit 1
fi
echo "PASS: 正常加锁和释放"

# 测试 2: 锁缺失 time 文件被强删
mkdir -p "$MODDIR/state/.lock"
echo "1234" > "$MODDIR/state/.lock/pid"
# 不写 time 文件
acquire_lock
if [ ! -d "$MODDIR/state/.lock" ] || [ ! -f "$MODDIR/state/.lock/time" ]; then
  echo "FAIL: 损坏的锁未被成功强删和重建"
  exit 1
fi
release_lock
echo "PASS: 损坏的死锁(缺失time)被成功强删"

# 测试 3: 锁 time 文件超过 60 秒被强删
mkdir -p "$MODDIR/state/.lock"
echo "1234" > "$MODDIR/state/.lock/pid"
# 模拟 70 秒前的死锁
past_time=$(( $(date +%s) - 70 ))
echo "$past_time" > "$MODDIR/state/.lock/time"

acquire_lock
if [ ! -d "$MODDIR/state/.lock" ] || [ ! -f "$MODDIR/state/.lock/time" ]; then
  echo "FAIL: 超时的旧锁未被成功强删和重建"
  exit 1
fi
new_time=$(cat "$MODDIR/state/.lock/time")
if [ "$new_time" = "$past_time" ]; then
  echo "FAIL: 锁时间未被更新"
  exit 1
fi
release_lock
echo "PASS: 超时的死锁被成功强删"

echo "[TEST] test_state_lock 成功！"
exit 0
