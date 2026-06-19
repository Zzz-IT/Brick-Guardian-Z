#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/mock_env.sh"
setup_env

. "$MODDIR/scripts/lib.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/snapshot.sh"

# Create some test scripts
mkdir -p "$ADB_ROOT/service.d"
echo "echo hello" > "$ADB_ROOT/service.d/s1.sh"
chmod +x "$ADB_ROOT/service.d/s1.sh"

mkdir -p "$ADB_ROOT/post-fs-data.d"
echo "echo world" > "$ADB_ROOT/post-fs-data.d/s2.sh"
# s2 is NOT executable

# Run script snapshot saving
save_good_script_snapshot

snapshot_file="$MODDIR/state/good_scripts.tsv"
if [ -f "$snapshot_file" ]; then
  echo "PASS: script snapshot file created"
else
  echo "FAIL: script snapshot file not created"
  exit 1
fi

# Verify counts
count="$(cat "$MODDIR/state/good_scripts_count" 2>/dev/null)"
if [ "$count" -eq 2 ]; then
  echo "PASS: good_scripts_count is 2"
else
  echo "FAIL: expected 2, got $count"
  exit 1
fi

# Verify contents
if grep -qE "service.d/s1.sh" "$snapshot_file" && grep -qE "post-fs-data.d/s2.sh" "$snapshot_file"; then
  echo "PASS: correct script relative paths found in snapshot"
else
  echo "FAIL: relative paths missing or incorrect"
  exit 1
fi

# Verify executable status (s1 is 1, s2 is 0)
s1_exec="$(grep "service.d/s1.sh" "$snapshot_file" | cut -f3)"
s2_exec="$(grep "post-fs-data.d/s2.sh" "$snapshot_file" | cut -f3)"

if [ "$s1_exec" = "1" ] && [ "$s2_exec" = "0" ]; then
  echo "PASS: executable status tracked correctly"
else
  echo "FAIL: executable status mismatch, s1=$s1_exec, s2=$s2_exec"
  exit 1
fi

echo "PASS: test_script_snapshot 成功"
exit 0
