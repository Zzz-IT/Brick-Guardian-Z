#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/dist"

version="$(awk -F= '$1=="version"{print $2; exit}' "$ROOT/module.prop")"
version="${version:-v1.0.0}"

name="Brick-Guardian-Z-${version}.zip"

rm -rf "$OUT"
mkdir -p "$OUT"

cd "$ROOT"

required=(
  module.prop
  skip_mount
  customize.sh
  post-fs-data.sh
  service.sh
  boot-completed.sh
  action.sh
  uninstall.sh
  config/default.conf
  config/whitelist.conf
  config/script_whitelist.conf
  scripts/lib.sh
  scripts/state.sh
  scripts/healthcheck.sh
  scripts/recovery.sh
  scripts/snapshot.sh
  scripts/script_guard.sh
  scripts/boot_mode.sh
  scripts/zygote_monitor.sh
)

for f in "${required[@]}"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: missing required file: $f"
    exit 1
  fi
done

if command -v zip >/dev/null 2>&1; then
  zip -r "$OUT/$name" \
    module.prop \
    skip_mount \
    customize.sh \
    post-fs-data.sh \
    service.sh \
    boot-completed.sh \
    action.sh \
    uninstall.sh \
    config \
    scripts \
    -x "*.git*" \
    -x "tests/*" \
    -x "dist/*" \
    -x "tools/*" \
    -x "phone_logs/*" \
    -x "test_env/*"
elif command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1 || command -v py >/dev/null 2>&1; then
  if command -v python >/dev/null 2>&1; then
    PY_CMD="python"
  elif command -v python3 >/dev/null 2>&1; then
    PY_CMD="python3"
  else
    PY_CMD="py"
  fi
  echo "zip not found, falling back to Python ($PY_CMD) zipfile module..."
  $PY_CMD -c "
import sys, zipfile
zip_path = sys.argv[1]
files = sys.argv[2:]
with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
    for f in files:
        archive_name = f.replace(chr(92), '/')
        zipf.write(f, archive_name)
" "$OUT/$name" "${required[@]}"
elif command -v powershell.exe >/dev/null 2>&1; then
  echo "zip and python not found, falling back to powershell.exe Compress-Archive..."
  tmp_dir="$OUT/tmp_zip"
  rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"
  
  cp -r module.prop skip_mount customize.sh post-fs-data.sh service.sh boot-completed.sh action.sh uninstall.sh "$tmp_dir/"
  mkdir -p "$tmp_dir/config" "$tmp_dir/scripts"
  cp -r config/* "$tmp_dir/config/"
  cp -r scripts/* "$tmp_dir/scripts/"
  
  abs_tmp_dir="$(cygpath -w "$(cd "$tmp_dir" && pwd)")"
  abs_out_file="$(cygpath -w "$(mkdir -p "$OUT" && cd "$OUT" && pwd)/$name")"
  
  powershell.exe -Command "Compress-Archive -Path '$abs_tmp_dir\\*' -DestinationPath '$abs_out_file' -Force"
  rm -rf "$tmp_dir"
else
  echo "FAIL: Neither zip, python, nor powershell.exe found."
  exit 1
fi

echo "Built: $OUT/$name"
