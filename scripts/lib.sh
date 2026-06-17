#!/system/bin/sh
# KSU Safe Guardian 核心库函数

# 测试环境注入桩
export ADB_ROOT="${ADB_ROOT:-/data/adb}"

if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

rotate_log() {
  local log_file="$MODDIR/logs/guardian.log"
  if [ -f "$log_file" ]; then
    local size=$(stat -c %s "$log_file" 2>/dev/null || echo 0)
    if [ "$size" -gt 512000 ]; then
      mv -f "$log_file.2" "$log_file.3" 2>/dev/null
      mv -f "$log_file.1" "$log_file.2" 2>/dev/null
      mv -f "$log_file" "$log_file.1" 2>/dev/null
    fi
  fi
}

log_info() {
  rotate_log
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$MODDIR/logs/guardian.log"
}

log_warn() {
  rotate_log
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $1" >> "$MODDIR/logs/guardian.log"
}

log_error() {
  rotate_log
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$MODDIR/logs/guardian.log"
}

get_config() {
  local key="$1"
  local default_val="$2"
  local val=""

  if [ -f "$MODDIR/config/default.conf" ]; then
    val="$(
      awk -F= -v key="$key" '
        /^[[:space:]]*#/ {next}
        $1 == key {
          print $2
          exit
        }
      ' "$MODDIR/config/default.conf"
    )"
  fi

  if [ -n "$val" ]; then
    echo "$val"
  else
    echo "$default_val"
  fi
}

is_whitelisted() {
  local id="$1"
  local file="$MODDIR/config/whitelist.conf"

  is_valid_module_id "$id" || return 1
  [ -f "$file" ] || return 1

  awk -v id="$id" '
    /^[[:space:]]*$/ {next}
    /^[[:space:]]*#/ {next}
    $0 == id {found=1}
    END {exit found ? 0 : 1}
  ' "$file"
}

is_guardian_self() {
  local id="$1"
  [ "$id" = "ksu-safe-guardian" ] || [ "$id" = "magisk-brick-guardian" ]
}

is_valid_module_id() {
  local id="$1"
  echo "$id" | grep -Eq '^[a-zA-Z][a-zA-Z0-9._-]+$'
}
